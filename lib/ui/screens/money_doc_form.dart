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

/// A new empty line, with the default unit in the documents language.
LineItem _blankLine({String section = ''}) =>
    LineItem(section: section, unit: 'lump sum'.td);

/// A preset payment term as it is written into a new quotation: label and
/// due text in the documents language.
PaymentTerm _presetTerm(PaymentTerm t) => PaymentTerm(
  label: t.label.td,
  percent: t.percent,
  amount: t.amount,
  due: t.due.td,
);

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
  bool _extra = false;
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
      // The standard terms are written in the documents language while
      // they are still the app's default wording.
      text: q?.terms ?? (q == null ? repo.companyText('terms', docLang) : ''),
    );
    _notes = TextEditingController(text: q?.notes ?? i?.notes ?? '');
    for (final item in doc?.items ?? [_blankLine()]) {
      _lines.add(_Line(item));
    }
    _qStatus = q?.status ?? QuotationStatus.draft;
    _iStatus = i?.status ?? InvoiceStatus.draft;
    _quotationId = i?.quotationId;
    _termIndex = i?.termIndex;
    _extra = i?.extra ?? false;
    // A new invoice bills the project's approved quotation, so advances
    // received on it are deducted.
    if (widget.isInvoice && i == null) {
      _quotationId = _defaultQuotation(repo, _projectId);
    }
    _stageId = i?.stageId ?? (i == null ? project?.stageId : null);
    if (!widget.isInvoice) {
      // A new quotation starts with the usual schedule for its service.
      final terms =
          q?.paymentTerms ??
          paymentTermPresets[project?.service ?? ServiceType.design]!.map(
            _presetTerm,
          );
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
    extra: _extra,
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
    final what = widget.isInvoice ? 'this invoice'.tr : 'this quotation'.tr;
    if (!await confirmDelete(context, what)) return;
    final now = repo.now();
    // The saved document, not unsaved edits: an invoice's receipts move to
    // its saved project and term.
    if (widget.isInvoice) {
      await repo.deleteInvoice(repo.invoice(_id) ?? _invoice(now));
    } else {
      await repo.deleteQuotation(repo.quotation(_id) ?? _quotation(now));
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
    setState(() => _lines.add(_Line(_blankLine(section: last))));
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
    if (!widget.isInvoice) return;
    final linked = repo.quotation(_quotationId);
    if (linked != null && linked.projectId != id) {
      _quotationId = null;
      _termIndex = null;
    }
    if (_quotationId == null && !_extra) {
      _quotationId = _defaultQuotation(repo, id);
    }
  }

  /// The project's approved quotation, when it has exactly one.
  static String? _defaultQuotation(Repository repo, String? projectId) {
    if (projectId == null) return null;
    final approved = _approvedOf(repo, projectId);
    return approved.length == 1 ? approved.single.id : null;
  }

  static List<Quotation> _approvedOf(Repository repo, String? projectId) => [
    for (final q in repo.quotationsFor(projectId ?? ''))
      if (q.status == QuotationStatus.accepted) q,
  ];

  static const _extraWork = '__extra';

  /// What the invoice bills: an approved quotation (the contract) or extra
  /// work outside it.
  Widget _billingFor(Repository repo) {
    final linked = repo.quotation(_quotationId);
    final choices = [
      ..._approvedOf(repo, _projectId),
      if (linked != null && linked.status != QuotationStatus.accepted) linked,
    ];
    final value = _extra
        ? _extraWork
        : choices.any((q) => q.id == _quotationId)
        ? _quotationId
        : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('bf$_projectId'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Billing for'.tr,
        helperMaxLines: 3,
        helperText: _extra
            ? 'Not counted in the contract\'s progress. Money received is '
                      'set against invoices oldest first, extra work '
                      'included.'
                  .tr
            : value != null
            ? 'Money received is set against invoices oldest first, '
                      'advances included.'
                  .tr
            : null,
      ),
      items: [
        for (final q in choices)
          DropdownMenuItem(
            value: q.id,
            child: Text(
              '${q.number} · ${q.title.isEmpty ? 'contract'.tr : q.title}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (choices.isEmpty || value == null)
          DropdownMenuItem(
            value: null,
            child: Text(
              choices.isEmpty
                  ? 'Project work (no approved quotation yet)'.tr
                  : 'Not linked to a quotation'.tr,
            ),
          ),
        DropdownMenuItem(
          value: _extraWork,
          child: Text('Extra work, outside the contract'.tr),
        ),
      ],
      onChanged: (v) => setState(() {
        _extra = v == _extraWork;
        final q = _extra ? null : v;
        if (q != _quotationId) _termIndex = null;
        _quotationId = q;
      }),
    );
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
      ..addAll(paymentTermPresets[service]!.map(_presetTerm).map(_TermRow.new));
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = Theme.of(context).colorScheme;
    final ak = AkColors.of(context);
    const gap = SizedBox(height: 14);
    final doc = _preview;
    final inv = widget.isInvoice ? repo.invoice(_id) : null;
    final payments = inv == null ? <Payment>[] : repo.paymentsFor(inv.id);
    final clientProjects = _clientId == null
        ? repo.projects
        : repo.projects.where((p) => p.clientId == _clientId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          !_isNew
              ? _number.text
              : widget.isInvoice
              ? 'New invoice'.tr
              : 'New quotation'.tr,
        ),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Delete'.tr,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'PDF to send or print'.tr,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _pdf,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(
              onPressed: () => _store(),
              child: Text('Save'.tr),
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
                        'STATUS'.tr,
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
                          segments: [
                            ButtonSegment(
                              value: InvoiceStatus.draft,
                              label: Text('Draft'.tr),
                            ),
                            ButtonSegment(
                              value: InvoiceStatus.sent,
                              label: Text('Issued'.tr),
                            ),
                            ButtonSegment(
                              value: InvoiceStatus.cancelled,
                              label: Text('Cancelled@@invoice'.tr),
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
                              label: Text('Accept and invoice'.tr),
                            ),
                          if (!widget.isInvoice)
                            OutlinedButton.icon(
                              onPressed: _progressInvoice,
                              icon: const Icon(Icons.percent),
                              label: Text('Progress invoice'.tr),
                            ),
                          if (widget.isInvoice &&
                              _iStatus != InvoiceStatus.cancelled)
                            FilledButton.icon(
                              onPressed: _addPayment,
                              icon: const Icon(Icons.payments_outlined),
                              label: Text('Record payment'.tr),
                            ),
                          OutlinedButton.icon(
                            onPressed: _pdf,
                            icon: const Icon(Icons.ios_share),
                            label: Text('Send PDF'.tr),
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
                            ? 'Invoice number'.tr
                            : 'Quotation number'.tr,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required'.tr : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Date'.tr,
                      value: _date,
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Subject'.tr,
                  hintText:
                      'e.g. Architectural design services, Villa Byblos'.tr,
                ),
              ),
              gap,
              DropdownButtonFormField<String?>(
                initialValue: repo.client(_clientId) == null ? null : _clientId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Client'.tr),
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
                    child: Text('No project yet'.tr),
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
                label: widget.isInvoice ? 'Payment due'.tr : 'Valid until'.tr,
                value: _until,
                onChanged: (d) => setState(() => _until = d),
              ),
              if (widget.isInvoice && _projectId != null) ...[
                gap,
                _billingFor(repo),
                gap,
                DropdownButtonFormField<String?>(
                  key: ValueKey('ph$_projectId'),
                  initialValue:
                      repo.stagesOf(_projectId).any((s) => s.id == _stageId)
                      ? _stageId
                      : null,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Phase billed'.tr),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('Not linked to a phase'.tr),
                    ),
                    for (final st in repo.stagesOf(_projectId))
                      DropdownMenuItem(value: st.id, child: Text(st.name.tr)),
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
                    'Bills payment term {0} of {1}: {2}'.trArgs([
                      _termIndex! + 1,
                      repo.quotation(_quotationId)!.number,
                      termLabel(repo.quotation(_quotationId)!, _termIndex!),
                    ]),
                    style: TextStyle(color: ak.muted, fontSize: 13),
                  ),
                ),
              ],
              SectionHeader('Items'.tr),
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
                    label: Text('Add item'.tr),
                  ),
                  TextButton.icon(
                    onPressed: _fromLibrary,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text('From BOQ library'.tr),
                  ),
                  TextButton.icon(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste),
                    label: Text('Paste items'.tr),
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
                      decoration: InputDecoration(
                        labelText: 'Cost-plus fee'.tr,
                        suffixText: '%',
                        hintText: 'e.g. 15'.tr,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SwitchListTile(
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 4,
                      ),
                      dense: true,
                      value: _showMarkup,
                      onChanged: (v) => setState(() => _showMarkup = v),
                      title: Text('Show fee on PDF'.tr),
                      subtitle: Text(
                        _showMarkup
                            ? 'As its own line'.tr
                            : 'Included in the rates'.tr,
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
                      decoration: InputDecoration(
                        labelText: 'Discount'.tr,
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
                      decoration: InputDecoration(
                        labelText: 'VAT'.tr,
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
                SectionHeader('Payments received'.tr),
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
                          a.onInvoice
                              ? 'from payment on {0}'.trArgs([
                                  repo.invoice(a.invoiceId)?.number ??
                                      'another invoice'.tr,
                                ])
                              : a.quotationId != null && a.termIndex != null
                              ? 'set off from advance on payment term'.tr
                              : 'set off from money on account'.tr,
                          fmtDate(a.date),
                        ].dots(),
                      ),
                      trailing: IconButton(
                        tooltip: 'Send receipt'.tr,
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
                      'No payments yet.'.tr,
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
                          ?_elsewhere(repo, payments[k], inv),
                        ].dots(),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Send receipt'.tr,
                            icon: const Icon(Icons.receipt_outlined, size: 20),
                            onPressed: () => shareReceiptPdf(repo, payments[k]),
                          ),
                          IconButton(
                            tooltip: 'Remove payment'.tr,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () async {
                              if (await confirmDelete(
                                context,
                                'this payment'.tr,
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
                  'Balance due: {0}'.trArgs([fmtMoney(repo.balanceOf(inv))]),
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
                  decoration: InputDecoration(
                    labelText: 'Terms and conditions'.tr,
                  ),
                ),
              ],
              gap,
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Notes (printed on the PDF)'.tr,
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
        (repo.payments.any(
              (p) =>
                  !p.onInvoice && p.quotationId == saved.id && p.termIndex == k,
            ) ||
            repo.termStatus(saved, k).received > 0 ||
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
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _termRows[k].label,
                        decoration: InputDecoration(
                          labelText: 'Instalment {0}'.trArgs([k + 1]),
                          hintText: 'e.g. Advance payment'.tr,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      tooltip: locked(k)
                          ? 'Has receipts or invoices'.tr
                          : 'Remove instalment'.tr,
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
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _termRows[k].percent,
                          keyboardType: num,
                          decoration: InputDecoration(
                            labelText: 'Share'.tr,
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
                          decoration: InputDecoration(
                            labelText: 'or fixed amount'.tr,
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
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: TextFormField(
                    controller: _termRows[k].due,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'When due'.tr,
                      hintText: 'e.g. On signing the agreement'.tr,
                    ),
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
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
            label: Text('Add instalment'.tr),
          ),
          PopupMenuButton<ServiceType>(
            enabled: !anyLocked,
            tooltip: 'Standard payment terms'.tr,
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
                    'Standard'.tr,
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
                ? 'The instalments add up to {0}, not the quotation total '
                          'of {1}.'
                      .trArgs([
                        '${fmtMoney(sum)}'
                            '${pct == 0 ? '' : ' (${_Line._plain(pct)}%)'}',
                        fmtMoney(doc.total),
                      ])
                : 'Instalments add up to the quotation total{0}.'.trArgs([
                    pct == 0 ? '' : ' (${_Line._plain(pct)}%)',
                  ]),
            style: TextStyle(
              fontSize: 13,
              color: off ? ak.bad : ak.muted,
              fontWeight: off ? FontWeight.w600 : null,
            ),
          ),
        ),
    ];

    return [
      SectionHeader('Payment terms'.tr),
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
          title: Text('Edit the instalments'.tr),
          children: editor,
        ),
      ] else
        ...editor,
    ];
  }
}

/// Where the rest of a payment taken on [inv] went, when part of it
/// settled other invoices or is still held as credit.
String? _elsewhere(Repository repo, Payment p, Invoice inv) {
  final other = [
    for (final (i, used) in repo.appliedTo(p))
      if (i.id != inv.id) '{0} to {1}'.trArgs([fmtMoney(used), i.number]),
  ];
  final credit = repo.unappliedOf(p);
  if (credit > 0) {
    other.add('{0} held as credit'.trArgs([fmtMoney(credit)]));
  }
  return other.isEmpty ? null : other.join(', ');
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
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, bottom: 10),
              child: DropdownButtonFormField<String>(
                initialValue: line.section.text,
                isExpanded: true,
                isDense: true,
                decoration: InputDecoration(
                  labelText: 'Section'.tr,
                  isDense: true,
                ),
                items: [
                  DropdownMenuItem(value: '', child: Text('No section'.tr)),
                  for (final name in {
                    ...boqSections,
                    if (line.section.text.isNotEmpty) line.section.text,
                  })
                    DropdownMenuItem(value: name, child: Text(name.tr)),
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
                      labelText: 'Item {0}'.trArgs([index + 1]),
                      hintText: 'e.g. Concept design'.tr,
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item'.tr,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: line.quantity,
                      keyboardType: num,
                      decoration: InputDecoration(labelText: 'Qty'.tr),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: line.unit,
                      decoration: InputDecoration(labelText: 'Unit'.tr),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: line.rate,
                      keyboardType: num,
                      decoration: InputDecoration(
                        labelText: 'Rate'.tr,
                        prefixText: '\$',
                      ),
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: 8, end: 8),
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
            row(doc.markupRate == 0 ? 'Subtotal'.tr : 'Cost'.tr, doc.subtotal),
            if (doc.markupRate != 0)
              row(
                'Cost-plus fee {0}%'.trArgs([_Line._plain(doc.markupRate)]),
                doc.markup,
              ),
            if (doc.discount != 0) row('Discount'.tr, -doc.discount),
            row('VAT {0}%'.trArgs([_Line._plain(doc.vatRate)]), doc.vat),
            const Divider(height: 18),
            row('Total'.tr, doc.total, bold: true),
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
      title: Text('Progress invoice'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill a share of every item in this quotation. You can adjust '
                    'each line on the invoice afterwards.'
                .tr,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Percent to bill'.tr,
              suffixText: '%',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text('Create invoice'.tr),
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
        // Matches the English wording and the wording on screen.
        bool match(BoqTrade t, BoqItem i) =>
            q.isEmpty ||
            i.description.toLowerCase().contains(q) ||
            t.name.toLowerCase().contains(q) ||
            i.description.tr.toLowerCase().contains(q) ||
            t.name.tr.toLowerCase().contains(q);
        Widget tile(BoqTrade t, BoqItem item) {
          final rate = _lastRateOf(lastRate, item);
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
            title: Text(item.description.tr),
            subtitle: Text(
              rate == null
                  ? item.unit.tr
                  : '${item.unit.tr} · '
                        '${'last rate {0}'.trArgs([fmtMoney(rate)])}',
            ),
          );
        }

        Widget groupHead(String name) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
          child: Text(
            name.tr.toUpperCase(),
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
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AK BOQ library'.tr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: picked.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, [
                              // Lines are written in the documents
                              // language; the section stays the trade's
                              // English name, which sets the BOQ order.
                              for (final e in picked.entries)
                                LineItem(
                                  description: e.key.description.td,
                                  unit: e.key.unit.td,
                                  section: e.value,
                                  rate: _lastRateOf(lastRate, e.key) ?? 0,
                                ),
                            ]),
                      child: Text(
                        picked.isEmpty
                            ? 'Add'.tr
                            : 'Add {0}'.trArgs([picked.length]),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search, e.g. porcelain, block, AC'.tr,
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
                          title: Text(t.name.tr),
                          subtitle: Text(
                            '{0} of {1} chosen'.trArgs([
                              t.items.where(picked.containsKey).length,
                              t.items.length,
                            ]),
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

/// The rate a library item was last priced at, under the wording it is
/// inserted with now or its English wording.
double? _lastRateOf(Map<String, double> lastRate, BoqItem item) =>
    lastRate[item.description.td] ?? lastRate[item.description];

/// Takes BOQ lines pasted from Excel or a message and turns them into items.
Future<List<LineItem>?> showPasteItems(
  BuildContext context, {
  String? intro,
  String? example,
}) async {
  final introText =
      intro ??
      'Paste rows from Excel, or a BOQ written for you in the '
              'chat. One item per line: description, unit, quantity, '
              'rate. A line with only a name starts a new section.'
          .tr;
  final exampleText =
      example ??
      'Masonry\n'
              'Block wall 20 cm | m² | 120 | 18\n'
              'Block wall 10 cm | m² | 85 | 14'
          .tr;
  final ctrl = TextEditingController();
  final items = await showDialog<List<LineItem>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final found = parseBoq(ctrl.text);
        return AlertDialog(
          title: Text('Paste items'.tr),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(introText),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  minLines: 6,
                  maxLines: 12,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(hintText: exampleText),
                  onChanged: (_) => set(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  found.isEmpty
                      ? 'No items found yet.'.tr
                      : found.length == 1
                      ? '1 item found'.tr
                      : '{0} items found'.trArgs([found.length]),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'.tr),
            ),
            FilledButton(
              onPressed: found.isEmpty ? null : () => Navigator.pop(ctx, found),
              child: Text('Add items'.tr),
            ),
          ],
        );
      },
    ),
  );
  return items;
}
