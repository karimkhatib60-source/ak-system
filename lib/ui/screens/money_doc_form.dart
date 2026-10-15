import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/boq_library.dart';
import '../../data/boq_paste.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../pdf_docs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'receipts.dart';

/// Opens a quotation for editing, or a new one when [quotation] is null.
Future<void> openQuotationForm(
  BuildContext context, {
  Quotation? quotation,
  String? projectId,
  String? clientId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => MoneyDocForm(
      quotation: quotation,
      projectId: projectId,
      clientId: clientId,
      isInvoice: false,
    ),
  ),
);

/// Opens an invoice for editing, or a new one when [invoice] is null.
/// [draft] pre-fills a new invoice, e.g. one made from a quotation.
Future<void> openInvoiceForm(
  BuildContext context, {
  Invoice? invoice,
  Invoice? draft,
  String? projectId,
  String? clientId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => MoneyDocForm(
      invoice: invoice,
      draft: draft,
      projectId: projectId,
      clientId: clientId,
      isInvoice: true,
    ),
  ),
);

class _Line {
  _Line(LineItem i)
    : section = TextEditingController(text: i.section),
      description = TextEditingController(text: i.description),
      quantity = TextEditingController(text: _plain(i.quantity)),
      unit = TextEditingController(text: i.unit),
      rate = TextEditingController(text: i.rate == 0 ? '' : _plain(i.rate));

  final TextEditingController section;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController rate;

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

  LineItem get item => LineItem(
    description: description.text.trim(),
    quantity: _parse(quantity.text) ?? 1,
    unit: unit.text.trim(),
    rate: _parse(rate.text) ?? 0,
    section: section.text.trim(),
  );

  bool get isBlank => item.description.isEmpty && item.rate == 0;

  void dispose() {
    section.dispose();
    description.dispose();
    quantity.dispose();
    unit.dispose();
    rate.dispose();
  }
}

double? _parse(String s) => double.tryParse(s.replaceAll(',', '').trim());

/// One editable row of a quotation's payment schedule.
class _TermRow {
  _TermRow(PaymentTerm t)
    : label = TextEditingController(text: t.label),
      percent = TextEditingController(
        text: t.percent == 0 ? '' : _Line._plain(t.percent),
      ),
      amount = TextEditingController(
        text: t.amount == 0 || t.percent != 0 ? '' : _Line._plain(t.amount),
      ),
      due = TextEditingController(text: t.due);

  final TextEditingController label;
  final TextEditingController percent;
  final TextEditingController amount;
  final TextEditingController due;

  PaymentTerm get term => PaymentTerm(
    label: label.text.trim(),
    percent: _parse(percent.text.replaceAll('%', '')) ?? 0,
    amount: _parse(amount.text) ?? 0,
    due: due.text.trim(),
  );

  bool get isBlank =>
      term.label.isEmpty && term.percent == 0 && term.amount == 0;

  void dispose() {
    label.dispose();
    percent.dispose();
    amount.dispose();
    due.dispose();
  }
}

/// One form for both quotations and invoices: the same priced lines,
/// discount and VAT, with the actions that fit each.
class MoneyDocForm extends StatefulWidget {
  const MoneyDocForm({
    super.key,
    this.quotation,
    this.invoice,
    this.draft,
    this.projectId,
    this.clientId,
    required this.isInvoice,
  });

  final Quotation? quotation;
  final Invoice? invoice;
  final Invoice? draft;
  final String? projectId;
  final String? clientId;
  final bool isInvoice;

  @override
  State<MoneyDocForm> createState() => _MoneyDocFormState();
}

class _MoneyDocFormState extends State<MoneyDocForm> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final DateTime _createdAt;
  late final TextEditingController _number;
  late final TextEditingController _title;
  late final TextEditingController _discount;
  late final TextEditingController _vat;
  late final TextEditingController _markup;
  bool _showMarkup = true;
  late final TextEditingController _terms;
  late final TextEditingController _notes;
  final _lines = <_Line>[];
  final _termRows = <_TermRow>[];
  String? _clientId;
  String? _projectId;
  String? _quotationId;
  String? _stageId;
  int? _termIndex;
  DateTime _date = DateTime.now();
  DateTime? _until;
  QuotationStatus _qStatus = QuotationStatus.draft;
  InvoiceStatus _iStatus = InvoiceStatus.draft;
  bool _saved = false;

  bool get _isNew => !_saved;

  @override
  void initState() {
    super.initState();
    final repo = context.read<Repository>();
    final now = repo.now();
    final q = widget.quotation;
    final i = widget.invoice ?? widget.draft;
    _saved = widget.quotation != null || widget.invoice != null;
    _id = q?.id ?? i?.id ?? repo.newId();
    _createdAt = q?.createdAt ?? i?.createdAt ?? now;
    _number = TextEditingController(
      text:
          q?.number ??
          i?.number ??
          (widget.isInvoice
              ? repo.nextInvoiceNumber()
              : repo.nextQuotationNumber()),
    );
    _projectId = q?.projectId ?? i?.projectId ?? widget.projectId;
    final project = repo.project(_projectId);
    _clientId = q?.clientId ?? i?.clientId ?? widget.clientId;
    _clientId ??= project?.clientId;
    _title = TextEditingController(
      text: q?.title ?? i?.title ?? (project == null ? '' : project.name),
    );
    _date = q?.date ?? i?.date ?? now;
    _until =
        q?.validUntil ??
        i?.dueDate ??
        (q == null && i == null
            ? now.add(Duration(days: widget.isInvoice ? 14 : 30))
            : null);
    final doc = (q ?? i) as PricedDocument?;
    _discount = TextEditingController(
      text: doc == null || doc.discount == 0 ? '' : _Line._plain(doc.discount),
    );
    _vat = TextEditingController(text: _Line._plain(doc?.vatRate ?? 11));
    final fee = doc?.markupRate ?? (doc == null ? project?.markupRate : null);
    _markup = TextEditingController(
      text: fee == null || fee == 0 ? '' : _Line._plain(fee),
    );
    _showMarkup = doc?.showMarkup ?? true;
    _terms = TextEditingController(
      text: q?.terms ?? (q == null ? repo.companyInfo['terms'] ?? '' : ''),
    );
    _notes = TextEditingController(text: q?.notes ?? i?.notes ?? '');
    for (final item in doc?.items ?? const [LineItem()]) {
      _lines.add(_Line(item));
    }
    _qStatus = q?.status ?? QuotationStatus.draft;
    _iStatus = i?.status ?? InvoiceStatus.draft;
    _quotationId = i?.quotationId;
    _termIndex = i?.termIndex;
    _stageId = i?.stageId ?? (i == null ? project?.stageId : null);
    if (!widget.isInvoice) {
      // A new quotation starts with the usual schedule for its service.
      final terms =
          q?.paymentTerms ??
          paymentTermPresets[project?.service ?? ServiceType.design]!;
      _termRows.addAll(terms.map(_TermRow.new));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _number,
      _title,
      _discount,
      _vat,
      _markup,
      _terms,
      _notes,
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    for (final t in _termRows) {
      t.dispose();
    }
    super.dispose();
  }

  List<LineItem> get _items => [
    for (final l in _lines)
      if (l.item.description.isNotEmpty || l.item.rate != 0) l.item,
  ];

  Quotation _quotation(DateTime now) => Quotation(
    id: _id,
    createdAt: _createdAt,
    updatedAt: now,
    number: _number.text.trim(),
    title: _title.text.trim(),
    clientId: _clientId,
    projectId: _projectId,
    date: _date,
    validUntil: _until,
    items: _items,
    discount: _parse(_discount.text) ?? 0,
    vatRate: _parse(_vat.text) ?? 0,
    markupRate: _parse(_markup.text.replaceAll('%', '')) ?? 0,
    showMarkup: _showMarkup,
    status: _qStatus,
    terms: _terms.text.trim(),
    notes: _notes.text.trim(),
    paymentTerms: [
      for (final t in _termRows)
        if (!t.isBlank) t.term,
    ],
  );

  Invoice _invoice(DateTime now) => Invoice(
    id: _id,
    createdAt: _createdAt,
    updatedAt: now,
    number: _number.text.trim(),
    title: _title.text.trim(),
    clientId: _clientId,
    projectId: _projectId,
    quotationId: _quotationId,
    stageId: _stageId,
    termIndex: _termIndex,
    date: _date,
    dueDate: _until,
    items: _items,
    discount: _parse(_discount.text) ?? 0,
    vatRate: _parse(_vat.text) ?? 0,
    markupRate: _parse(_markup.text.replaceAll('%', '')) ?? 0,
    showMarkup: _showMarkup,
    status: _iStatus,
    notes: _notes.text.trim(),
  );

  PricedDocument get _preview =>
      widget.isInvoice ? _invoice(_date) : _quotation(_date);

  Future<bool> _store({bool close = true}) async {
    if (!_form.currentState!.validate()) return false;
    final repo = context.read<Repository>();
    final now = repo.now();
    if (widget.isInvoice) {
      await repo.saveInvoice(_invoice(now));
    } else {
      await repo.saveQuotation(_quotation(now));
    }
    _saved = true;
    if (close && mounted) Navigator.pop(context);
    return true;
  }

  Future<void> _delete() async {
    final repo = context.read<Repository>();
    final what = widget.isInvoice ? 'this invoice' : 'this quotation';
    if (!await confirmDelete(context, what)) return;
    final now = repo.now();
    if (widget.isInvoice) {
      await repo.deleteInvoice(_invoice(now));
    } else {
      await repo.deleteQuotation(_quotation(now));
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pdf() async {
    // Sending an invoice issues it, so money held on account is set off
    // and the client sees the balance actually due.
    if (widget.isInvoice && _iStatus == InvoiceStatus.draft) {
      setState(() => _iStatus = InvoiceStatus.sent);
    }
    if (!await _store(close: false)) return;
    if (!mounted) return;
    final repo = context.read<Repository>();
    final now = repo.now();
    await sharePdf(repo, widget.isInvoice ? _invoice(now) : _quotation(now));
  }

  Future<void> _toInvoice() async {
    if (!await _store(close: false)) return;
    if (!mounted) return;
    final repo = context.read<Repository>();
    final q = _quotation(repo.now());
    if (_qStatus != QuotationStatus.accepted) {
      setState(() => _qStatus = QuotationStatus.accepted);
      await repo.saveQuotation(q.copyWith(status: QuotationStatus.accepted));
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await openInvoiceForm(nav.context, draft: repo.invoiceFromQuotation(q));
  }

  /// Bills a share of an accepted quotation, line by line, so every item
  /// can be followed on the project statement.
  Future<void> _progressInvoice() async {
    if (!await _store(close: false)) return;
    if (!mounted) return;
    final repo = context.read<Repository>();
    final pct = await _askPercent(context);
    if (pct == null || !mounted) return;
    var q = _quotation(repo.now());
    if (_qStatus != QuotationStatus.accepted) {
      setState(() => _qStatus = QuotationStatus.accepted);
      q = q.copyWith(status: QuotationStatus.accepted);
      await repo.saveQuotation(q);
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    await openInvoiceForm(nav.context, draft: repo.progressInvoice(q, pct));
  }

  /// Adds lines, replacing the single empty line a new document starts with.
  void _addItems(List<LineItem> items) {
    if (items.isEmpty) return;
    setState(() {
      if (_lines.length == 1 && _lines.first.isBlank) {
        _lines.removeAt(0).dispose();
      }
      _lines.addAll(items.map(_Line.new));
    });
  }

  void _addBlank() {
    final last = _lines.isEmpty ? '' : _lines.last.section.text;
    setState(() => _lines.add(_Line(LineItem(section: last))));
  }

  Future<void> _fromLibrary() async {
    final picked = await showBoqLibrary(context);
    if (picked != null) _addItems(picked);
  }

  Future<void> _paste() async {
    final items = await showPasteItems(context);
    if (items != null) _addItems(items);
  }

  void _projectChanged(Repository repo, String? id) {
    _projectId = id;
    final fee = repo.project(id)?.markupRate;
    if (_markup.text.trim().isEmpty && fee != null && fee != 0) {
      _markup.text = _Line._plain(fee);
    }
  }

  Future<void> _addPayment() async {
    if (!await _store(close: false)) return;
    if (!mounted) return;
    final repo = context.read<Repository>();
    final inv = _invoice(repo.now());
    if (inv.status == InvoiceStatus.draft) {
      setState(() => _iStatus = InvoiceStatus.sent);
      await repo.saveInvoice(inv.copyWith(status: InvoiceStatus.sent));
    }
    if (!mounted) return;
    await openReceiptForm(context, invoice: repo.invoice(inv.id) ?? inv);
  }

  /// Saves the quotation as accepted before invoicing or receiving on one
  /// of its payment terms.
  Future<bool> _acceptForTerms() async {
    if (_qStatus != QuotationStatus.accepted) {
      setState(() => _qStatus = QuotationStatus.accepted);
    }
    return _store(close: false);
  }

  void _usePreset(ServiceType service) => setState(() {
    for (final t in _termRows) {
      t.dispose();
    }
    _termRows
      ..clear()
      ..addAll(paymentTermPresets[service]!.map(_TermRow.new));
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = Theme.of(context).colorScheme;
    final ak = AkColors.of(context);
    const gap = SizedBox(height: 14);
    final kind = widget.isInvoice ? 'invoice' : 'quotation';
    final doc = _preview;
    final inv = widget.isInvoice ? repo.invoice(_id) : null;
    final payments = inv == null ? <Payment>[] : repo.paymentsFor(inv.id);
    final clientProjects = _clientId == null
        ? repo.projects
        : repo.projects.where((p) => p.clientId == _clientId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'New $kind' : _number.text),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'PDF to send or print',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _pdf,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: () => _store(),
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 760,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              // Status and next step.
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: ak.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.isInvoice)
                        SegmentedButton<InvoiceStatus>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: InvoiceStatus.draft,
                              label: Text('Draft'),
                            ),
                            ButtonSegment(
                              value: InvoiceStatus.sent,
                              label: Text('Issued'),
                            ),
                            ButtonSegment(
                              value: InvoiceStatus.cancelled,
                              label: Text('Cancelled'),
                            ),
                          ],
                          selected: {_iStatus},
                          onSelectionChanged: (v) =>
                              setState(() => _iStatus = v.first),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<QuotationStatus>(
                            showSelectedIcon: false,
                            segments: [
                              for (final s in QuotationStatus.values)
                                ButtonSegment(
                                  value: s,
                                  label: Text(quotationStatusLabel(s)),
                                ),
                            ],
                            selected: {_qStatus},
                            onSelectionChanged: (v) =>
                                setState(() => _qStatus = v.first),
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!widget.isInvoice)
                            FilledButton.icon(
                              onPressed: _toInvoice,
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Accept and invoice'),
                            ),
                          if (!widget.isInvoice)
                            OutlinedButton.icon(
                              onPressed: _progressInvoice,
                              icon: const Icon(Icons.percent),
                              label: const Text('Progress invoice'),
                            ),
                          if (widget.isInvoice &&
                              _iStatus != InvoiceStatus.cancelled)
                            FilledButton.icon(
                              onPressed: _addPayment,
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Record payment'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _pdf,
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Send PDF'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _number,
                      decoration: InputDecoration(
                        labelText: widget.isInvoice
                            ? 'Invoice number'
                            : 'Quotation number',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Date',
                      value: _date,
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g. Architectural design services, Villa Byblos',
                ),
              ),
              gap,
              DropdownButtonFormField<String?>(
                initialValue: repo.client(_clientId) == null ? null : _clientId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Client'),
                items: [
                  for (final cl in repo.clients)
                    DropdownMenuItem(value: cl.id, child: Text(cl.name)),
                ],
                onChanged: (v) => setState(() {
                  _clientId = v;
                  if (repo.project(_projectId)?.clientId != v) {
                    _projectId = null;
                  }
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
                    child: Text('No project yet'),
                  ),
                  for (final p in clientProjects)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} · ${p.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _projectChanged(repo, v)),
              ),
              gap,
              DateField(
                label: widget.isInvoice ? 'Payment due' : 'Valid until',
                value: _until,
                onChanged: (d) => setState(() => _until = d),
              ),
              if (widget.isInvoice && _projectId != null) ...[
                gap,
                DropdownButtonFormField<String?>(
                  key: ValueKey('ph$_projectId'),
                  initialValue:
                      repo.stagesOf(_projectId).any((s) => s.id == _stageId)
                      ? _stageId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Phase billed'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Not linked to a phase'),
                    ),
                    for (final st in repo.stagesOf(_projectId))
                      DropdownMenuItem(value: st.id, child: Text(st.name)),
                  ],
                  onChanged: (v) => setState(() => _stageId = v),
                ),
              ],
              if (widget.isInvoice &&
                  _termIndex != null &&
                  repo.quotation(_quotationId) != null &&
                  _termIndex! <
                      repo.quotation(_quotationId)!.paymentTerms.length) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Bills payment term ${_termIndex! + 1} of '
                    '${repo.quotation(_quotationId)!.number}: '
                    '${termLabel(repo.quotation(_quotationId)!, _termIndex!)}',
                    style: TextStyle(color: ak.muted, fontSize: 13),
                  ),
                ),
              ],
              const SectionHeader('Items'),
              for (var i = 0; i < _lines.length; i++)
                _LineEditor(
                  key: ObjectKey(_lines[i]),
                  line: _lines[i],
                  index: i,
                  onChanged: () => setState(() {}),
                  onRemove: _lines.length == 1
                      ? null
                      : () => setState(() => _lines.removeAt(i).dispose()),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _addBlank,
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                  TextButton.icon(
                    onPressed: _fromLibrary,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('From BOQ library'),
                  ),
                  TextButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: const Text('Paste items'),
                  ),
                ],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _markup,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Cost-plus fee',
                        suffixText: '%',
                        hintText: 'e.g. 15',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.only(left: 4),
                      dense: true,
                      value: _showMarkup,
                      onChanged: (v) => setState(() => _showMarkup = v),
                      title: const Text('Show fee on PDF'),
                      subtitle: Text(
                        _showMarkup
                            ? 'As its own line'
                            : 'Included in the rates',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Discount',
                        prefixText: '\$ ',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _vat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'VAT',
                        suffixText: '%',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              gap,
              _Totals(doc: doc),
              if (inv != null) ...[
                const SectionHeader('Payments received'),
                for (final (k, (a, applied)) in repo.advancesOn(inv).indexed)
                  GroupedRow(
                    index: k,
                    count: repo.advancesOn(inv).length,
                    child: ListTile(
                      leading: Icon(Icons.savings_outlined, color: ak.good),
                      title: Text(fmtMoney(applied)),
                      subtitle: Text(
                        [
                          if (a.number.isNotEmpty) a.number,
                          a.quotationId != null && a.termIndex != null
                              ? 'set off from advance on payment term'
                              : 'set off from money on account',
                          fmtDate(a.date),
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Send receipt',
                        icon: const Icon(Icons.receipt_outlined, size: 20),
                        onPressed: () => shareReceiptPdf(repo, a),
                      ),
                    ),
                  ),
                if (repo.advancesOn(inv).isNotEmpty && payments.isNotEmpty)
                  const SizedBox(height: 8),
                if (payments.isEmpty && repo.advancesOn(inv).isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'No payments yet.',
                      style: TextStyle(color: c.onSurfaceVariant),
                    ),
                  ),
                for (var k = 0; k < payments.length; k++)
                  GroupedRow(
                    index: k,
                    count: payments.length,
                    child: ListTile(
                      leading: Icon(Icons.payments_outlined, color: ak.good),
                      title: Text(fmtMoney(payments[k].amount)),
                      subtitle: Text(
                        [
                          if (payments[k].number.isNotEmpty) payments[k].number,
                          fmtDate(payments[k].date),
                          paymentMethodLabel(payments[k].method),
                          if (payments[k].reference.isNotEmpty)
                            payments[k].reference,
                        ].join(' · '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Send receipt',
                            icon: const Icon(Icons.receipt_outlined, size: 20),
                            onPressed: () => shareReceiptPdf(repo, payments[k]),
                          ),
                          IconButton(
                            tooltip: 'Remove payment',
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              if (await confirmDelete(
                                context,
                                'this payment',
                              )) {
                                await repo.deletePayment(payments[k]);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  'Balance due: ${fmtMoney(repo.balanceOf(inv))}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
              if (!widget.isInvoice) ..._termsSection(repo, doc),
              if (!widget.isInvoice) ...[
                gap,
                TextFormField(
                  controller: _terms,
                  minLines: 2,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Terms and conditions',
                  ),
                ),
              ],
              gap,
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notes (printed on the PDF)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The payment schedule: where each instalment stands once the
  /// quotation is accepted, and the editor for the instalments.
  List<Widget> _termsSection(Repository repo, PricedDocument doc) {
    final ak = AkColors.of(context);
    final saved = repo.quotation(_id);
    final accepted =
        saved != null &&
        saved.status == QuotationStatus.accepted &&
        saved.paymentTerms.isNotEmpty;
    bool used(int k) =>
        saved != null &&
        k < saved.paymentTerms.length &&
        (repo.termStatus(saved, k).received > 0 ||
            repo.termStatus(saved, k).invoices.isNotEmpty);
    // Removing a row shifts the ones after it, so a row is locked when it
    // or any later row already has money or an invoice on it.
    bool locked(int k) {
      for (var j = k; j < _termRows.length; j++) {
        if (used(j)) return true;
      }
      return false;
    }

    final anyLocked = _termRows.isNotEmpty && locked(0);
    final terms = [for (final t in _termRows) t.term];
    final pct = terms.fold(0.0, (s, t) => s + t.percent);
    final sum = terms.fold(0.0, (s, t) => s + t.valueOf(doc.total));
    final off = terms.isNotEmpty && (sum - doc.total).abs() > 0.5;
    const num = TextInputType.numberWithOptions(decimal: true);

    final editor = <Widget>[
      for (var k = 0; k < _termRows.length; k++)
        Card(
          key: ObjectKey(_termRows[k]),
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _termRows[k].label,
                        decoration: InputDecoration(
                          labelText: 'Instalment ${k + 1}',
                          hintText: 'e.g. Advance payment',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: locked(k)
                          ? 'Has receipts or invoices'
                          : 'Remove instalment',
                      icon: Icon(
                        locked(k) ? Icons.lock_outline : Icons.close,
                        size: 18,
                      ),
                      onPressed: locked(k)
                          ? null
                          : () =>
                                setState(() => _termRows.removeAt(k).dispose()),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _termRows[k].percent,
                          keyboardType: num,
                          decoration: const InputDecoration(
                            labelText: 'Share',
                            suffixText: '%',
                          ),
                          onChanged: (v) => setState(() {
                            if (v.trim().isNotEmpty) {
                              _termRows[k].amount.clear();
                            }
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _termRows[k].amount,
                          keyboardType: num,
                          decoration: const InputDecoration(
                            labelText: 'or fixed amount',
                            prefixText: '\$',
                          ),
                          onChanged: (v) => setState(() {
                            if (v.trim().isNotEmpty) {
                              _termRows[k].percent.clear();
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextFormField(
                    controller: _termRows[k].due,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'When due',
                      hintText: 'e.g. On signing the agreement',
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: Text(
                      fmtMoney(_termRows[k].term.valueOf(doc.total)),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      Row(
        children: [
          TextButton.icon(
            onPressed: () =>
                setState(() => _termRows.add(_TermRow(const PaymentTerm()))),
            icon: const Icon(Icons.add),
            label: const Text('Add instalment'),
          ),
          PopupMenuButton<ServiceType>(
            enabled: !anyLocked,
            tooltip: 'Standard payment terms',
            onSelected: _usePreset,
            itemBuilder: (_) => [
              for (final sv in ServiceType.values)
                PopupMenuItem(
                  value: sv,
                  child: Text(
                    '${serviceLabel(sv)}: '
                    '${paymentTermPresets[sv]!.map((t) => _Line._plain(t.percent)).join(' / ')}',
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: anyLocked ? ak.muted : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Standard',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: anyLocked
                          ? ak.muted
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      if (terms.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            off
                ? 'The instalments add up to ${fmtMoney(sum)}'
                      '${pct == 0 ? '' : ' (${_Line._plain(pct)}%)'}, not the '
                      'quotation total of ${fmtMoney(doc.total)}.'
                : 'Instalments add up to the quotation total'
                      '${pct == 0 ? '' : ' (${_Line._plain(pct)}%)'}.',
            style: TextStyle(
              fontSize: 13,
              color: off ? ak.bad : ak.muted,
              fontWeight: off ? FontWeight.w600 : null,
            ),
          ),
        ),
    ];

    return [
      const SectionHeader('Payment terms'),
      if (accepted) ...[
        for (var k = 0; k < saved.paymentTerms.length; k++)
          GroupedRow(
            index: k,
            count: saved.paymentTerms.length,
            child: TermStatusTile(
              quotation: saved,
              index: k,
              beforeAction: _acceptForTerms,
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: EdgeInsets.zero,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          title: const Text('Edit the instalments'),
          children: editor,
        ),
      ] else
        ...editor,
    ];
  }
}

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    super.key,
    required this.line,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final _Line line;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final num = TextInputType.numberWithOptions(decimal: true);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 10),
              child: DropdownButtonFormField<String>(
                initialValue: line.section.text,
                isExpanded: true,
                isDense: true,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('No section')),
                  for (final name in {
                    ...boqSections,
                    if (line.section.text.isNotEmpty) line.section.text,
                  })
                    DropdownMenuItem(value: name, child: Text(name)),
                ],
                onChanged: (v) {
                  line.section.text = v ?? '';
                  onChanged();
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: line.description,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Item ${index + 1}',
                      hintText: 'e.g. Concept design',
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: line.quantity,
                      keyboardType: num,
                      decoration: const InputDecoration(labelText: 'Qty'),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: line.unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: line.rate,
                      keyboardType: num,
                      decoration: const InputDecoration(
                        labelText: 'Rate',
                        prefixText: '\$',
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Text(
                  fmtMoney(line.item.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.doc});

  final PricedDocument doc;

  @override
  Widget build(BuildContext context) {
    Widget row(String label, double v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
            ),
          ),
          Text(
            fmtMoney(v),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 17 : null,
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            row(doc.markupRate == 0 ? 'Subtotal' : 'Cost', doc.subtotal),
            if (doc.markupRate != 0)
              row('Cost-plus fee ${_Line._plain(doc.markupRate)}%', doc.markup),
            if (doc.discount != 0) row('Discount', -doc.discount),
            row('VAT ${_Line._plain(doc.vatRate)}%', doc.vat),
            const Divider(height: 18),
            row('Total', doc.total, bold: true),
          ],
        ),
      ),
    );
  }
}

Future<double?> _askPercent(BuildContext context) async {
  final ctrl = TextEditingController(text: '30');
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Progress invoice'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bill a share of every item in this quotation. You can adjust '
            'each line on the invoice afterwards.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Percent to bill',
              suffixText: '%',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Create invoice'),
        ),
      ],
    ),
  );
  final pct = v == null ? null : _parse(v.replaceAll('%', ''));
  return pct == null || pct <= 0 ? null : pct;
}

/// The AK master library: search or browse by trade, tick items, and they
/// come back under their trade as the section. Items priced before keep
/// their last rate.
Future<List<LineItem>?> showBoqLibrary(BuildContext context) {
  final repo = context.read<Repository>();
  final lastRate = <String, double>{};
  final docs = <PricedDocument>[...repo.quotations, ...repo.invoices]
    ..sort((a, b) => _docDate(a).compareTo(_docDate(b)));
  for (final d in docs) {
    for (final i in d.items) {
      if (i.rate != 0) lastRate[i.description] = i.rate;
    }
  }
  final picked = <BoqItem, String>{};
  var query = '';
  return showModalBottomSheet<List<LineItem>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final ak = AkColors.of(ctx);
        final q = query.trim().toLowerCase();
        bool match(BoqTrade t, BoqItem i) =>
            q.isEmpty ||
            i.description.toLowerCase().contains(q) ||
            t.name.toLowerCase().contains(q);
        Widget tile(BoqTrade t, BoqItem item) {
          final rate = lastRate[item.description];
          return CheckboxListTile(
            dense: true,
            value: picked.containsKey(item),
            onChanged: (v) => set(() {
              if (v == true) {
                picked[item] = t.name;
              } else {
                picked.remove(item);
              }
            }),
            title: Text(item.description),
            subtitle: Text(
              rate == null
                  ? item.unit
                  : '${item.unit} · last rate ${fmtMoney(rate)}',
            ),
          );
        }

        Widget groupHead(String name) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            name.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w800,
              color: ak.muted,
            ),
          ),
        );

        return SizedBox(
          height: MediaQuery.of(ctx).size.height * .88,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AK BOQ library',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: picked.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, [
                              for (final e in picked.entries)
                                LineItem(
                                  description: e.key.description,
                                  unit: e.key.unit,
                                  section: e.value,
                                  rate: lastRate[e.key.description] ?? 0,
                                ),
                            ]),
                      child: Text(
                        picked.isEmpty ? 'Add' : 'Add ${picked.length}',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search, e.g. porcelain, block, AC',
                    isDense: true,
                  ),
                  onChanged: (v) => set(() => query = v),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    if (q.isNotEmpty)
                      for (final t in boqLibrary)
                        for (final i in t.items.where((i) => match(t, i)))
                          tile(t, i)
                    else
                      for (final t in boqLibrary)
                        ExpansionTile(
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          leading: Text(
                            t.code,
                            style: TextStyle(
                              color: ak.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          title: Text(t.name),
                          subtitle: Text(
                            '${t.items.where(picked.containsKey).length} of '
                            '${t.items.length} chosen',
                          ),
                          children: [
                            for (final g in t.groups) ...[
                              if (t.groups.length > 1) groupHead(g.name),
                              for (final i in g.items) tile(t, i),
                            ],
                          ],
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

DateTime _docDate(PricedDocument d) =>
    d is Invoice ? d.date : (d as Quotation).date;

/// Takes BOQ lines pasted from Excel or a message and turns them into items.
Future<List<LineItem>?> showPasteItems(BuildContext context) async {
  final ctrl = TextEditingController();
  final items = await showDialog<List<LineItem>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final found = parseBoq(ctrl.text);
        return AlertDialog(
          title: const Text('Paste items'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste rows from Excel, or a BOQ written for you in the '
                  'chat. One item per line: description, unit, quantity, '
                  'rate. A line with only a name starts a new section.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText:
                        'Masonry\n'
                        'Block wall 20 cm | m² | 120 | 18\n'
                        'Block wall 10 cm | m² | 85 | 14',
                  ),
                  onChanged: (_) => set(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  found.isEmpty
                      ? 'No items found yet.'
                      : '${found.length} item${found.length == 1 ? '' : 's'} '
                            'found',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: found.isEmpty ? null : () => Navigator.pop(ctx, found),
              child: const Text('Add items'),
            ),
          ],
        );
      },
    ),
  );
  return items;
}
