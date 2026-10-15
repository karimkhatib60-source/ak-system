import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../data/statement.dart';
import '../format.dart';
import '../pdf_docs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'money_doc_form.dart';

/// What money is received against.
enum ReceiptAgainst { invoice, term, account }

ReceiptAgainst receiptKind(Payment p) => p.onInvoice
    ? ReceiptAgainst.invoice
    : p.quotationId != null && p.termIndex != null
    ? ReceiptAgainst.term
    : ReceiptAgainst.account;

String termLabel(Quotation q, int index) {
  final t = q.paymentTerms[index];
  final pct = t.percent == 0 ? '' : ' · ${_plain(t.percent)}%';
  return '${t.label.isEmpty ? 'Payment ${index + 1}' : t.label}$pct';
}

String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

double? _parse(String s) => double.tryParse(s.replaceAll(',', '').trim());

/// Records money received, then offers to send the receipt.
Future<void> openReceiptForm(
  BuildContext context, {
  String? clientId,
  String? projectId,
  Invoice? invoice,
  Quotation? quotation,
  int? termIndex,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = context.read<Repository>();
  final saved = await Navigator.push<Payment>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ReceiptForm(
        clientId: clientId,
        projectId: projectId,
        invoice: invoice,
        quotation: quotation,
        termIndex: termIndex,
      ),
    ),
  );
  if (saved == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text('Receipt ${saved.number} saved'),
      action: SnackBarAction(
        label: 'Send receipt',
        onPressed: () => shareReceiptPdf(repo, saved),
      ),
    ),
  );
}

/// A new receipt: money received from a client against an invoice, a
/// payment term of an accepted quotation, or on account. Receipts are not
/// edited once saved; a wrong one is deleted and recorded again.
class ReceiptForm extends StatefulWidget {
  const ReceiptForm({
    super.key,
    this.clientId,
    this.projectId,
    this.invoice,
    this.quotation,
    this.termIndex,
  });

  final String? clientId;
  final String? projectId;
  final Invoice? invoice;
  final Quotation? quotation;
  final int? termIndex;

  @override
  State<ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends State<ReceiptForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  String? _clientId;
  String? _projectId;
  ReceiptAgainst _kind = ReceiptAgainst.invoice;
  String? _invoiceId;

  /// Selected term as "quotationId#index".
  String? _term;
  PaymentMethod _method = PaymentMethod.bankTransfer;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final repo = context.read<Repository>();
    _date = repo.now();
    final inv = widget.invoice;
    final q = widget.quotation;
    _projectId = inv?.projectId ?? q?.projectId ?? widget.projectId;
    _clientId =
        inv?.clientId ??
        q?.clientId ??
        widget.clientId ??
        repo.project(_projectId)?.clientId;
    if (inv != null) {
      _kind = ReceiptAgainst.invoice;
      _invoiceId = inv.id;
    } else if (q != null && widget.termIndex != null) {
      _kind = ReceiptAgainst.term;
      _term = '${q.id}#${widget.termIndex}';
    } else {
      // Start where there is something to collect.
      _kind = _invoices(repo).isNotEmpty
          ? ReceiptAgainst.invoice
          : _terms(repo).isNotEmpty
          ? ReceiptAgainst.term
          : ReceiptAgainst.account;
      if (_kind == ReceiptAgainst.invoice) {
        _invoiceId = _invoices(repo).first.id;
      } else if (_kind == ReceiptAgainst.term) {
        final t = _terms(repo).first;
        _term = '${t.$1.id}#${t.$2}';
      }
    }
    _prefill(repo);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _inScope(String? clientId, String? projectId) =>
      clientId == _clientId && (_projectId == null || projectId == _projectId);

  /// Invoices of the client (and project) with money still to collect.
  List<Invoice> _invoices(Repository repo) =>
      repo.invoices
          .where(
            (i) =>
                _inScope(i.clientId, i.projectId) &&
                i.status != InvoiceStatus.cancelled &&
                (repo.balanceOf(i) > 0.005 || i.id == widget.invoice?.id),
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

  /// Payment terms of accepted quotations not yet fully received.
  List<(Quotation, int, TermStatus)> _terms(Repository repo) => [
    for (final q in repo.quotations)
      if (_inScope(q.clientId, q.projectId) &&
          (q.status == QuotationStatus.accepted ||
              q.id == widget.quotation?.id))
        for (var k = 0; k < q.paymentTerms.length; k++)
          if (!repo.termStatus(q, k).settled ||
              (q.id == widget.quotation?.id && k == widget.termIndex))
            (q, k, repo.termStatus(q, k)),
  ];

  (Quotation, int, TermStatus)? _selectedTerm(Repository repo) {
    if (_term == null) return null;
    final parts = _term!.split('#');
    final q = repo.quotation(parts.first) ?? widget.quotation;
    final k = int.tryParse(parts.last);
    if (q == null || k == null || k >= q.paymentTerms.length) return null;
    return (q, k, repo.termStatus(q, k));
  }

  /// What is still to collect on the selected document; null on account.
  double? _remaining(Repository repo) => switch (_kind) {
    ReceiptAgainst.invoice =>
      repo.invoice(_invoiceId) == null
          ? null
          : repo.balanceOf(repo.invoice(_invoiceId)!),
    ReceiptAgainst.term => _selectedTerm(repo)?.$3.remaining,
    ReceiptAgainst.account => null,
  };

  void _prefill(Repository repo) {
    final r = _remaining(repo);
    _amount.text = r == null || r <= 0.005 ? '' : r.toStringAsFixed(2);
  }

  void _setKind(Repository repo, ReceiptAgainst k) {
    _kind = k;
    if (k == ReceiptAgainst.invoice &&
        !_invoices(repo).any((i) => i.id == _invoiceId)) {
      _invoiceId = _invoices(repo).firstOrNull?.id;
    }
    if (k == ReceiptAgainst.term &&
        !_terms(repo).any((t) => '${t.$1.id}#${t.$2}' == _term)) {
      final t = _terms(repo).firstOrNull;
      _term = t == null ? null : '${t.$1.id}#${t.$2}';
    }
    _prefill(repo);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final now = repo.now();
    final amount = _parse(_amount.text)!;
    var inv = _kind == ReceiptAgainst.invoice ? repo.invoice(_invoiceId) : null;
    final term = _kind == ReceiptAgainst.term ? _selectedTerm(repo) : null;
    if (term != null && term.$1.status != QuotationStatus.accepted) {
      // Money on a payment term means the quotation was accepted.
      await repo.saveQuotation(
        term.$1.copyWith(status: QuotationStatus.accepted),
      );
    }
    if (inv != null && inv.status == InvoiceStatus.draft) {
      inv = inv.copyWith(status: InvoiceStatus.sent);
      await repo.saveInvoice(inv);
    }
    final id = repo.newId();
    await repo.savePayment(
      Payment(
        id: id,
        createdAt: now,
        updatedAt: now,
        invoiceId: inv?.id ?? '',
        date: _date,
        amount: amount,
        method: _method,
        reference: _reference.text.trim(),
        clientId: inv == null ? _clientId : null,
        projectId: inv == null ? (term?.$1.projectId ?? _projectId) : null,
        quotationId: term?.$1.id,
        termIndex: term?.$2,
        notes: _notes.text.trim(),
      ),
    );
    final saved = repo.payments.where((p) => p.id == id).firstOrNull;
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    const gap = SizedBox(height: 14);
    final clientProjects = _clientId == null
        ? <Project>[]
        : repo.projectsFor(_clientId!);
    final invoices = _clientId == null ? <Invoice>[] : _invoices(repo);
    final terms = _clientId == null
        ? <(Quotation, int, TermStatus)>[]
        : _terms(repo);
    final remaining = _remaining(repo);

    Widget muted(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
      child: Text(s, style: TextStyle(color: ak.muted, fontSize: 13)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('New receipt'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              DropdownButtonFormField<String?>(
                initialValue: repo.client(_clientId) == null ? null : _clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Received from'),
                items: [
                  for (final cl in repo.clients)
                    DropdownMenuItem(value: cl.id, child: Text(cl.name)),
                ],
                onChanged: (v) => setState(() {
                  _clientId = v;
                  if (repo.project(_projectId)?.clientId != v) {
                    _projectId = null;
                  }
                  _setKind(repo, _kind);
                }),
                validator: (v) => v == null ? 'Choose the client' : null,
              ),
              gap,
              DropdownButtonFormField<String?>(
                key: ValueKey('p$_clientId'),
                initialValue: clientProjects.any((p) => p.id == _projectId)
                    ? _projectId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All projects of this client'),
                  ),
                  for (final p in clientProjects)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} · ${p.name}'),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _projectId = v;
                  _setKind(repo, _kind);
                }),
              ),
              const SectionHeader('Received against'),
              SegmentedButton<ReceiptAgainst>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ReceiptAgainst.invoice,
                    label: Text('Invoice'),
                  ),
                  ButtonSegment(
                    value: ReceiptAgainst.term,
                    label: Text('Payment term'),
                  ),
                  ButtonSegment(
                    value: ReceiptAgainst.account,
                    label: Text('On account'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (v) =>
                    setState(() => _setKind(repo, v.first)),
              ),
              const SizedBox(height: 12),
              if (_kind == ReceiptAgainst.invoice)
                invoices.isEmpty
                    ? muted('No unpaid invoices for this client.')
                    : DropdownButtonFormField<String>(
                        key: ValueKey('i$_clientId$_projectId'),
                        initialValue: invoices.any((i) => i.id == _invoiceId)
                            ? _invoiceId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Invoice'),
                        items: [
                          for (final i in invoices)
                            DropdownMenuItem(
                              value: i.id,
                              child: Text(
                                [
                                  i.number,
                                  '${fmtMoney(repo.balanceOf(i))} due',
                                  if (i.status == InvoiceStatus.draft) 'draft',
                                  if (i.title.isNotEmpty) i.title,
                                ].join(' · '),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _invoiceId = v;
                          _prefill(repo);
                        }),
                        validator: (v) =>
                            v == null ? 'Choose the invoice' : null,
                      ),
              if (_kind == ReceiptAgainst.term)
                terms.isEmpty
                    ? muted(
                        'No open payment terms. Add the payment terms on '
                        'the accepted quotation first.',
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey('t$_clientId$_projectId'),
                        initialValue:
                            terms.any((t) => '${t.$1.id}#${t.$2}' == _term)
                            ? _term
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Payment term',
                        ),
                        items: [
                          for (final t in terms)
                            DropdownMenuItem(
                              value: '${t.$1.id}#${t.$2}',
                              child: Text(
                                '${t.$1.number} · ${termLabel(t.$1, t.$2)} · '
                                '${fmtMoney(t.$3.remaining)} left',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _term = v;
                          _prefill(repo);
                        }),
                        validator: (v) =>
                            v == null ? 'Choose the payment term' : null,
                      ),
              if (_kind == ReceiptAgainst.account)
                muted(
                  'Money received without a specific invoice, for example a '
                  'deposit. It is set against this client\'s open invoices '
                  'automatically, oldest first, and the rest stays as '
                  'credit on the account.',
                ),
              _Position(
                kind: _kind,
                invoice: _kind == ReceiptAgainst.invoice
                    ? repo.invoice(_invoiceId)
                    : null,
                term: _kind == ReceiptAgainst.term ? _selectedTerm(repo) : null,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount received',
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        final a = _parse(v ?? '');
                        if (a == null || a <= 0) return 'Enter the amount';
                        if (remaining != null && a > remaining + 0.005) {
                          return remaining <= 0.005
                              ? 'Nothing left to collect here'
                              : 'Only ${fmtMoney(remaining)} is due. Record '
                                    'the extra on account.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Date received',
                      value: _date,
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ),
                ],
              ),
              gap,
              DropdownButtonFormField<PaymentMethod>(
                initialValue: _method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(paymentMethodLabel(m)),
                    ),
                ],
                onChanged: (v) => setState(() => _method = v!),
              ),
              gap,
              TextFormField(
                controller: _reference,
                decoration: InputDecoration(
                  labelText: switch (_method) {
                    PaymentMethod.cheque => 'Cheque number and bank',
                    PaymentMethod.bankTransfer => 'Transfer reference',
                    PaymentMethod.card => 'Card slip number',
                    _ => 'Reference (optional)',
                  },
                ),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _kind == ReceiptAgainst.account
                      ? 'Received for'
                      : 'Notes (printed on the receipt)',
                  hintText: _kind == ReceiptAgainst.account
                      ? 'e.g. Deposit before the design agreement'
                      : null,
                ),
                validator: (v) =>
                    _kind == ReceiptAgainst.account && (v ?? '').trim().isEmpty
                    ? 'Say what the money is for'
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the selected invoice or payment term stands before this receipt.
class _Position extends StatelessWidget {
  const _Position({required this.kind, this.invoice, this.term});

  final ReceiptAgainst kind;
  final Invoice? invoice;
  final (Quotation, int, TermStatus)? term;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final ak = AkColors.of(context);
    final List<(String, double)> rows;
    String? note;
    if (invoice != null) {
      final i = invoice!;
      rows = [
        ('Invoice total', i.total),
        ('Received so far', repo.paidOn(i)),
        ('Balance due', repo.balanceOf(i)),
      ];
      if (repo.advanceOn(i) > 0) {
        note =
            'Includes ${fmtMoney(repo.advanceOn(i))} set off from money '
            'received in advance.';
      }
    } else if (term != null) {
      final (q, _, st) = term!;
      rows = [
        ('Contract value (${q.number})', q.total),
        ('Instalment value', st.value),
        ('Received so far', st.received),
        ('Remaining', st.remaining),
      ];
      final open = st.invoices
          .where(
            (i) => i.status == InvoiceStatus.sent && repo.balanceOf(i) > 0.005,
          )
          .map((i) => i.number);
      if (open.isNotEmpty) {
        note =
            'Invoiced on ${open.join(', ')}. This receipt will be set '
            'against it.';
      } else if (st.term.due.isNotEmpty) {
        note = 'Due: ${st.term.due}.';
      }
    } else {
      return const SizedBox.shrink();
    }
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (k, (label, v)) in rows.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    Expanded(child: Text(label)),
                    Text(
                      fmtMoney(v),
                      style: TextStyle(
                        fontWeight: k == rows.length - 1
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (note != null) ...[
              const SizedBox(height: 6),
              Text(note, style: TextStyle(color: ak.muted, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Lists --

class ReceiptTile extends StatelessWidget {
  const ReceiptTile(
    this.p, {
    super.key,
    this.showProject = false,
    this.projectId,
  });

  final Payment p;
  final bool showProject;

  /// On a project's page: shows only the part of the receipt that went to
  /// that project when the rest is kept elsewhere.
  final String? projectId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final client = repo.client(repo.payerOf(p))?.name;
    final project = repo.project(repo.projectOfPayment(p));
    final kind = receiptKind(p);
    final credit = repo.unappliedOf(p);
    final advance = credit > 0.005;
    final used = repo.appliedTo(p);
    final share = projectId == null ? p.amount : repo.receivedFor(p, projectId);
    final part = (share - p.amount).abs() > 0.005;
    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: Text(
        client ?? p.number,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (p.number.isNotEmpty) p.number,
          if (showProject && project != null) project.code,
          if (part) '${fmtMoneyShort(share)} of ${fmtMoneyShort(p.amount)}',
          receiptPurpose(repo, p),
          if (used.isNotEmpty)
            'set against ${used.map((e) => e.$1.number).join(', ')}',
          if (advance && used.isNotEmpty)
            '${fmtMoneyShort(credit)} credit left',
          paymentMethodLabel(p.method),
          fmtDate(p.date),
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtMoneyShort(share),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Pill(
            advance
                ? 'Advance'
                : switch (kind) {
                    ReceiptAgainst.invoice => 'Invoice',
                    ReceiptAgainst.term => 'Term',
                    ReceiptAgainst.account => 'On account',
                  },
            color: advance ? AkPalette.info : AkPalette.good,
          ),
        ],
      ),
      onTap: () => showReceiptSheet(context, p),
    );
  }
}

/// Receipt details, with sending and deleting.
Future<void> showReceiptSheet(
  BuildContext context,
  Payment p,
) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (ctx) {
    final repo = ctx.watch<Repository>();
    final ak = AkColors.of(ctx);
    final client = repo.client(repo.payerOf(p));
    final project = repo.project(repo.projectOfPayment(p));
    final advance = repo.unappliedOf(p);
    final setAgainst = repo.appliedTo(p);
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(k, style: TextStyle(color: ak.muted)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'RECEIPT ${p.number}',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: ak.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fmtMoney(p.amount),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            row('Received from', client?.name ?? '—'),
            if (project != null)
              row('Project', '${project.code} · ${project.name}'),
            row('For', receiptPurpose(repo, p)),
            row('Date', fmtDate(p.date)),
            row('Method', paymentMethodLabel(p.method)),
            if (p.reference.isNotEmpty) row('Reference', p.reference),
            if (p.notes.isNotEmpty && receiptKind(p) != ReceiptAgainst.account)
              row('Notes', p.notes),
            for (final (i, a) in setAgainst)
              row(
                'Set against',
                '${i.number} · ${fmtMoney(a)}'
                    '${i.title.isEmpty ? '' : ' · ${i.title}'}',
              ),
            if (!p.onInvoice || advance > 0.005 || setAgainst.isNotEmpty)
              row(
                'Credit left',
                advance > 0.005
                    ? '${fmtMoney(advance)} on the account'
                    : 'None, fully set against invoices',
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => shareReceiptPdf(repo, p),
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Send receipt'),
                ),
                if (p.onInvoice && repo.invoice(p.invoiceId) != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      openInvoiceForm(
                        context,
                        invoice: repo.invoice(p.invoiceId),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Open invoice'),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: Text('Delete receipt ${p.number}?'),
                        content: const Text(
                          'A receipt is proof of money received. Delete '
                          'it only if it was recorded by mistake.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.deletePayment(p);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  },
);

/// One payment term of an accepted quotation: value, what was received,
/// what remains, and the next step.
class TermStatusTile extends StatelessWidget {
  const TermStatusTile({
    super.key,
    required this.quotation,
    required this.index,
    this.showQuotation = false,
    this.beforeAction,
  });

  final Quotation quotation;
  final int index;
  final bool showQuotation;

  /// Runs before invoicing or receiving, e.g. to save the quotation first.
  /// Returning false cancels.
  final Future<bool> Function()? beforeAction;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final q = quotation;
    final st = repo.termStatus(q, index);
    final live = st.invoices.where((i) => i.status != InvoiceStatus.cancelled);
    final open = live
        .where((i) => repo.balanceOf(i) > 0.005)
        .where((i) => i.status == InvoiceStatus.sent)
        .firstOrNull;
    final progress = st.value <= 0
        ? 0.0
        : (st.received / st.value).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${index + 1}. ${termLabel(q, index)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                fmtMoney(st.value),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (showQuotation || st.term.due.isNotEmpty)
            Text(
              [
                if (showQuotation) q.number,
                if (st.term.due.isNotEmpty) st.term.due,
              ].join(' · '),
              style: TextStyle(color: ak.muted, fontSize: 12.5),
            ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: st.settled ? ak.good : null,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              st.settled
                  ? 'Received in full'
                  : 'Received ${fmtMoney(st.received)} · '
                        'Remaining ${fmtMoney(st.remaining)}',
              if (live.isNotEmpty) live.map((i) => i.number).join(', '),
            ].join(' · '),
            style: TextStyle(
              fontSize: 12.5,
              color: st.settled ? ak.good : null,
              fontWeight: st.settled ? FontWeight.w600 : null,
            ),
          ),
          if (!st.settled)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 6,
                children: [
                  if (live.isEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        if (beforeAction != null && !await beforeAction!()) {
                          return;
                        }
                        if (!context.mounted) return;
                        final fresh = repo.quotation(q.id) ?? q;
                        await openInvoiceForm(
                          context,
                          draft: repo.invoiceForTerm(fresh, index),
                        );
                      },
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text('Invoice'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      if (beforeAction != null && !await beforeAction!()) {
                        return;
                      }
                      if (!context.mounted) return;
                      final fresh = repo.quotation(q.id) ?? q;
                      await openReceiptForm(
                        context,
                        invoice: open,
                        quotation: open == null ? fresh : null,
                        termIndex: open == null ? index : null,
                      );
                    },
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Receive'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
