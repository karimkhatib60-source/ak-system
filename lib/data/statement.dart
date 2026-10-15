import 'models.dart';
import 'repository.dart';

/// One movement on a client's account: an issued invoice (debit) or a
/// payment received (credit), with the running balance after it.
class StatementLine {
  const StatementLine({
    required this.date,
    required this.reference,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    required this.balance,
  });

  final DateTime date;
  final String reference;
  final String description;
  final double debit;
  final double credit;
  final double balance;
}

/// An invoice that still has money to collect.
class OpenInvoice {
  const OpenInvoice(this.invoice, this.paid, this.daysOverdue);

  final Invoice invoice;
  final double paid;
  final int daysOverdue;

  double get balance => invoice.total - paid;
}

/// Statement of account for one client over a period, optionally for one
/// project only.
class Statement {
  const Statement({
    required this.client,
    required this.project,
    required this.from,
    required this.to,
    required this.opening,
    required this.lines,
    required this.open,
    required this.contractValue,
    this.advances = 0,
  });

  final Client client;
  final Project? project;
  final DateTime? from;
  final DateTime to;
  final double opening;
  final List<StatementLine> lines;
  final List<OpenInvoice> open;

  /// Accepted quotations for the same client (or project).
  final double contractValue;

  /// Money received on payment terms or on account and not yet set
  /// against an invoice, as of [to].
  final double advances;

  double get invoiced => lines.fold(0, (s, l) => s + l.debit);
  double get received => lines.fold(0, (s, l) => s + l.credit);
  double get closing => opening + invoiced - received;

  /// Still to collect on issued invoices, before setting off advances.
  double get dueOnInvoices => open.fold(0, (s, o) => s + o.balance);
  double get overdue =>
      open.where((o) => o.daysOverdue > 0).fold(0, (s, o) => s + o.balance);

  /// Outstanding split by how late it is: current, 1-30, 31-60, 61-90, 90+.
  List<double> get aging {
    final out = List<double>.filled(5, 0);
    for (final o in open) {
      final d = o.daysOverdue;
      final k = d <= 0
          ? 0
          : d <= 30
          ? 1
          : d <= 60
          ? 2
          : d <= 90
          ? 3
          : 4;
      out[k] += o.balance;
    }
    return out;
  }
}

Statement buildStatement(
  Repository repo,
  String clientId, {
  DateTime? from,
  DateTime? to,
  String? projectId,
}) {
  final client = repo.client(clientId)!;
  final now = repo.now();
  final today = DateTime(now.year, now.month, now.day);
  final end = to ?? today;
  final endDay = DateTime(end.year, end.month, end.day);
  bool mine(String? cid, String? pid) =>
      cid == clientId && (projectId == null || pid == projectId);
  bool after(DateTime d) => DateTime(d.year, d.month, d.day).isAfter(endDay);
  bool before(DateTime d) =>
      from != null && DateTime(d.year, d.month, d.day).isBefore(from);

  final invoices = repo.invoices
      .where(
        (i) =>
            mine(i.clientId, i.projectId) &&
            i.status == InvoiceStatus.sent &&
            !after(i.date),
      )
      .toList();

  final moves =
      <
        ({
          DateTime date,
          int order,
          String ref,
          String text,
          double debit,
          double credit,
        })
      >[];
  for (final i in invoices) {
    final code = repo.project(i.projectId)?.code ?? '';
    moves.add((
      date: i.date,
      order: 0,
      ref: i.number,
      text: [
        'Invoice',
        if (i.title.isNotEmpty) i.title,
        if (projectId == null && code.isNotEmpty) code,
      ].join(' · '),
      debit: i.total,
      credit: 0,
    ));
  }
  // Every receipt from this client: on an invoice, on a payment term of a
  // quotation, or on account.
  var advances = 0.0;
  for (final p in repo.payments) {
    if (!mine(repo.payerOf(p), repo.projectOfPayment(p)) || after(p.date)) {
      continue;
    }
    advances += repo.unappliedOf(p, until: endDay);
    moves.add((
      date: p.date,
      order: 1,
      ref: p.number.isNotEmpty ? p.number : p.reference,
      text: 'Receipt · ${_method(p.method)} · ${receiptPurpose(repo, p)}',
      debit: 0,
      credit: p.amount,
    ));
  }
  moves.sort((a, b) {
    final c = a.date.compareTo(b.date);
    return c != 0 ? c : a.order.compareTo(b.order);
  });

  var opening = 0.0;
  var balance = 0.0;
  final lines = <StatementLine>[];
  for (final m in moves) {
    if (before(m.date)) {
      opening = ((opening + m.debit - m.credit) * 100).round() / 100;
      continue;
    }
    if (lines.isEmpty) balance = opening;
    balance += m.debit - m.credit;
    balance = (balance * 100).round() / 100; // no -0.00 from cents
    lines.add(
      StatementLine(
        date: m.date,
        reference: m.ref,
        description: m.text,
        debit: m.debit,
        credit: m.credit,
        balance: balance,
      ),
    );
  }

  final open = <OpenInvoice>[];
  for (final i in invoices) {
    final paid = repo.paidOn(i, until: endDay);
    if (i.total - paid > 0.005) {
      final due = i.dueDate ?? i.date;
      final days = endDay
          .difference(DateTime(due.year, due.month, due.day))
          .inDays;
      open.add(OpenInvoice(i, paid, days));
    }
  }
  open.sort((a, b) => a.invoice.date.compareTo(b.invoice.date));

  final contract = repo.quotations
      .where(
        (q) =>
            mine(q.clientId, q.projectId) &&
            q.status == QuotationStatus.accepted,
      )
      .fold(0.0, (s, q) => s + q.total);

  return Statement(
    client: client,
    project: repo.project(projectId),
    from: from,
    to: endDay,
    opening: opening,
    lines: lines,
    open: open,
    contractValue: contract,
    advances: advances,
  );
}

String _method(PaymentMethod m) => switch (m) {
  PaymentMethod.bankTransfer => 'bank transfer',
  PaymentMethod.cash => 'cash',
  PaymentMethod.cheque => 'cheque',
  PaymentMethod.card => 'card',
  PaymentMethod.other => 'other',
};

/// What a receipt pays for, in words: "on INV-26-003", "Advance 30% of
/// QT-26-002" or "on account".
String receiptPurpose(Repository repo, Payment p) {
  if (p.onInvoice) {
    return 'on ${repo.invoice(p.invoiceId)?.number ?? 'invoice'}';
  }
  final q = repo.quotation(p.quotationId);
  if (q != null &&
      p.termIndex != null &&
      p.termIndex! < q.paymentTerms.length) {
    final t = q.paymentTerms[p.termIndex!];
    final label = t.label.isEmpty ? 'Payment ${p.termIndex! + 1}' : t.label;
    return '$label of ${q.number}';
  }
  return p.notes.isNotEmpty ? 'on account · ${p.notes}' : 'on account';
}
