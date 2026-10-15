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
  String? _clientId;
  String? _projectId;
  String? _quotationId;
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
    await showPaymentDialog(context, inv, repo.balanceOf(inv));
  }

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
                if (payments.isEmpty)
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
                          fmtDate(payments[k].date),
                          paymentMethodLabel(payments[k].method),
                          if (payments[k].reference.isNotEmpty)
                            payments[k].reference,
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove payment',
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () async {
                          if (await confirmDelete(context, 'this payment')) {
                            await repo.deletePayment(payments[k]);
                          }
                        },
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
              child: TextFormField(
                controller: line.section,
                decoration: const InputDecoration(
                  labelText: 'Section',
                  hintText: 'e.g. Masonry (optional)',
                  isDense: true,
                ),
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

/// Records money received against an invoice.
Future<void> showPaymentDialog(
  BuildContext context,
  Invoice invoice,
  double balance,
) async {
  final repo = context.read<Repository>();
  final amount = TextEditingController(
    text: balance > 0 ? balance.toStringAsFixed(2) : '',
  );
  final ref = TextEditingController();
  var method = PaymentMethod.bankTransfer;
  var date = repo.now();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text('Payment on ${invoice.number}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount received',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 12),
              DateField(
                label: 'Date received',
                value: date,
                onChanged: (d) => set(() => date = d ?? date),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Method'),
                items: [
                  for (final m in PaymentMethod.values)
                    DropdownMenuItem(
                      value: m,
                      child: Text(paymentMethodLabel(m)),
                    ),
                ],
                onChanged: (v) => set(() => method = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ref,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save payment'),
          ),
        ],
      ),
    ),
  );
  final v = _parse(amount.text);
  if (ok == true && v != null && v > 0) {
    final now = repo.now();
    await repo.savePayment(
      Payment(
        id: repo.newId(),
        createdAt: now,
        updatedAt: now,
        invoiceId: invoice.id,
        date: date,
        amount: v,
        method: method,
        reference: ref.text.trim(),
      ),
    );
  }
}

/// Lets the user tick standard BOQ items by trade. Returns the chosen items
/// with quantity 1 and no rate, each under its trade as the section.
Future<List<LineItem>?> showBoqLibrary(BuildContext context) {
  final picked = <BoqItem, String>{};
  return showModalBottomSheet<List<LineItem>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => SizedBox(
        height: MediaQuery.of(ctx).size.height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'BOQ library',
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
                              ),
                          ]),
                    child: Text(
                      picked.isEmpty ? 'Add' : 'Add ${picked.length}',
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final t in boqLibrary)
                    ExpansionTile(
                      title: Text(t.name),
                      subtitle: Text(
                        '${t.items.where(picked.containsKey).length} of '
                        '${t.items.length} chosen',
                      ),
                      children: [
                        for (final item in t.items)
                          CheckboxListTile(
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
                            subtitle: Text(item.unit),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
