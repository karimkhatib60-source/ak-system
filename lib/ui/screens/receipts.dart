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

String termLabel(Quotation q, int index, [AppLang? lang]) {
  final l = lang ?? appLang;
  final t = q.paymentTerms[index];
  final pct = t.percent == 0 ? '' : ' · ${_plain(t.percent)}%';
  final label = t.label.isEmpty
      ? 'Payment {0}'.inLang(l, [index + 1])
      : t.label.inLang(l);
  return '$label$pct';
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
      content: Text('Receipt {0} saved'.trArgs([saved.number])),
      action: SnackBarAction(
        label: 'Send receipt'.tr,
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
        title: Text('New receipt'.tr),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(onPressed: _save, child: Text('Save'.tr)),
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
                decoration: InputDecoration(labelText: 'Received from'.tr),
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
                validator: (v) => v == null ? 'Choose the client'.tr : null,
              ),
              gap,
              DropdownButtonFormField<String?>(
                key: ValueKey('p$_clientId'),
                initialValue: clientProjects.any((p) => p.id == _projectId)
                    ? _projectId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Project'.tr),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text('All projects of this client'.tr),
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
              SectionHeader('Received against'.tr),
              SegmentedButton<ReceiptAgainst>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: ReceiptAgainst.invoice,
                    label: Text('Invoice'.tr),
                  ),
                  ButtonSegment(
                    value: ReceiptAgainst.term,
                    label: Text('Payment term'.tr),
                  ),
                  ButtonSegment(
                    value: ReceiptAgainst.account,
                    label: Text('On account'.tr),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (v) =>
                    setState(() => _setKind(repo, v.first)),
              ),
              const SizedBox(height: 12),
              if (_kind == ReceiptAgainst.invoice)
                invoices.isEmpty
                    ? muted('No unpaid invoices for this client.'.tr)
                    : DropdownButtonFormField<String>(
                        key: ValueKey('i$_clientId$_projectId'),
                        initialValue: invoices.any((i) => i.id == _invoiceId)
                            ? _invoiceId
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(labelText: 'Invoice'.tr),
                        items: [
                          for (final i in invoices)
                            DropdownMenuItem(
                              value: i.id,
                              child: Text(
                                [
                                  i.number,
                                  '{0} due'.trArgs([
                                    fmtMoney(repo.balanceOf(i)),
                                  ]),
                                  if (i.status == InvoiceStatus.draft)
                                    'draft'.tr,
                                  if (i.title.isNotEmpty) i.title,
                                ].dots(),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _invoiceId = v;
                          _prefill(repo);
                        }),
                        validator: (v) =>
                            v == null ? 'Choose the invoice'.tr : null,
                      ),
              if (_kind == ReceiptAgainst.term)
                terms.isEmpty
                    ? muted(
                        'No open payment terms. Add the payment terms on '
                                'the approved quotation first.'
                            .tr,
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey('t$_clientId$_projectId'),
                        initialValue:
                            terms.any((t) => '${t.$1.id}#${t.$2}' == _term)
                            ? _term
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Payment term'.tr,
                        ),
                        items: [
                          for (final t in terms)
                            DropdownMenuItem(
                              value: '${t.$1.id}#${t.$2}',
                              child: Text(
                                '${t.$1.number} · ${termLabel(t.$1, t.$2)} · '
                                '${'{0} left'.trArgs([fmtMoney(t.$3.remaining)])}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _term = v;
                          _prefill(repo);
                        }),
                        validator: (v) =>
                            v == null ? 'Choose the payment term'.tr : null,
                      ),
              if (_kind == ReceiptAgainst.account)
                muted(
                  'Money received without a specific invoice, for example a '
                          'deposit. It is set against this client\'s open '
                          'invoices automatically, oldest first, and the rest '
                          'stays as credit on the account.'
                      .tr,
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
                      decoration: InputDecoration(
                        labelText: 'Amount received'.tr,
                        prefixText: '\$ ',
                      ),
                      validator: (v) {
                        final a = _parse(v ?? '');
                        if (a == null || a <= 0) return 'Enter the amount'.tr;
                        if (remaining != null && a > remaining + 0.005) {
                          return remaining <= 0.005
                              ? 'Nothing left to collect here'.tr
                              : 'Only {0} is due. Record the extra on account.'
                                    .trArgs([fmtMoney(remaining)]);
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Date received'.tr,
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
                decoration: InputDecoration(labelText: 'Method'.tr),
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
                    PaymentMethod.cheque => 'Cheque number and bank'.tr,
                    PaymentMethod.bankTransfer => 'Transfer reference'.tr,
                    PaymentMethod.card => 'Card slip number'.tr,
                    _ => 'Reference (optional)'.tr,
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
                      ? 'Received for'.tr
                      : 'Notes (printed on the receipt)'.tr,
                  hintText: _kind == ReceiptAgainst.account
                      ? 'e.g. Deposit before the design agreement'.tr
                      : null,
                ),
                validator: (v) =>
                    _kind == ReceiptAgainst.account && (v ?? '').trim().isEmpty
                    ? 'Say what the money is for'.tr
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
        ('Invoice total'.tr, i.total),
        ('Received so far'.tr, repo.paidOn(i)),
        ('Balance due'.tr, repo.balanceOf(i)),
      ];
      final older = [
        for (final o in repo.openInvoices(i.clientId, projectId: i.projectId))
          if (o.id != i.id && Repository.invoiceOrder(o, i) < 0) o.number,
      ];
      note = [
        if (repo.advanceOn(i) > 0)
          'Includes {0} set off from other payments of the client.'.trArgs([
            fmtMoney(repo.advanceOn(i)),
          ]),
        if (older.length == 1)
          'Payments settle the oldest invoices first, so {0} is paid '
                  'before {1}.'
              .trArgs([older.single, i.number])
        else if (older.isNotEmpty)
          'Payments settle the oldest invoices first, so {0} are paid '
                  'before {1}.'
              .trArgs([older.join(', '), i.number]),
      ].join(' ');
      if (note.isEmpty) note = null;
    } else if (term != null) {
      final (q, _, st) = term!;
      rows = [
        ('Contract value ({0})'.trArgs([q.number]), q.total),
        ('Instalment value'.tr, st.value),
        ('Received so far'.tr, st.received),
        ('Remaining'.tr, st.remaining),
      ];
      final open = repo
          .openInvoices(q.clientId, projectId: q.projectId)
          .map((i) => i.number);
      if (open.isNotEmpty) {
        note = 'This receipt settles the open invoices oldest first: {0}.'
            .trArgs([open.join(', ')]);
      } else if (st.term.due.isNotEmpty) {
        note = 'Due: {0}.'.trArgs([st.term.due.tr]);
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
          if (part)
            '{0} of {1}'.trArgs([
              fmtMoneyShort(share),
              fmtMoneyShort(p.amount),
            ]),
          receiptPurpose(repo, p),
          if (used.any((e) => e.$1.id != p.invoiceId))
            'set against {0}'.trArgs([used.map((e) => e.$1.number).join(', ')]),
          if (advance && used.isNotEmpty)
            '{0} credit left'.trArgs([fmtMoneyShort(credit)]),
          paymentMethodLabel(p.method),
          fmtDate(p.date),
        ].dots(),
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
                ? 'Advance'.tr
                : switch (kind) {
                    ReceiptAgainst.invoice => 'Invoice'.tr,
                    ReceiptAgainst.term => 'Term'.tr,
                    ReceiptAgainst.account => 'On account'.tr,
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
              'RECEIPT {0}'.trArgs([p.number]),
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
            row('Received from'.tr, client?.name ?? '—'),
            if (project != null)
              row('Project'.tr, '${project.code} · ${project.name}'),
            row('Received for'.tr, receiptPurpose(repo, p)),
            row('Date'.tr, fmtDate(p.date)),
            row('Method'.tr, paymentMethodLabel(p.method)),
            if (p.reference.isNotEmpty) row('Reference'.tr, p.reference),
            if (p.notes.isNotEmpty && receiptKind(p) != ReceiptAgainst.account)
              row('Notes'.tr, p.notes),
            for (final (i, a) in setAgainst)
              row(
                'Set against'.tr,
                '${i.number} · ${fmtMoney(a)}'
                '${i.title.isEmpty ? '' : ' · ${i.title}'}',
              ),
            if (!p.onInvoice ||
                advance > 0.005 ||
                setAgainst.any((e) => e.$1.id != p.invoiceId))
              row(
                'Credit left'.tr,
                advance > 0.005
                    ? '{0} on the account'.trArgs([fmtMoney(advance)])
                    : 'None, fully set against invoices'.tr,
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => shareReceiptPdf(repo, p),
                  icon: const Icon(Icons.ios_share),
                  label: Text('Send receipt'.tr),
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
                    label: Text('Open invoice'.tr),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: ctx,
                      builder: (d) => AlertDialog(
                        title: Text('Delete receipt {0}?'.trArgs([p.number])),
                        content: Text(
                          'A receipt is proof of money received. Delete '
                                  'it only if it was recorded by mistake.'
                              .tr,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: Text('Cancel'.tr),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: Text('Delete'.tr),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await repo.deletePayment(p);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Delete'.tr),
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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 10),
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
                if (st.term.due.isNotEmpty) st.term.due.tr,
              ].dots(),
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
                  ? 'Received in full'.tr
                  : 'Received {0} · Remaining {1}'.trArgs([
                      fmtMoney(st.received),
                      fmtMoney(st.remaining),
                    ]),
              if (live.isNotEmpty) live.map((i) => i.number).join(', '),
            ].dots(),
            style: TextStyle(
              fontSize: 12.5,
              color: st.settled ? ak.good : null,
              fontWeight: st.settled ? FontWeight.w600 : null,
            ),
          ),
          if (!st.settled)
            Align(
              alignment: AlignmentDirectional.centerEnd,
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
                      label: Text('Invoice'.tr),
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
                    label: Text('Receive'.tr),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
