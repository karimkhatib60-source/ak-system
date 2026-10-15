import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'money_doc_form.dart' show showPasteItems;

/// Files above this size are refused: they would make the app and the
/// cloud copy slow.
const maxAttachmentBytes = 10 * 1024 * 1024;

String fmtSize(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).ceil()} KB'
    : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

double? _parse(String s) {
  final t = s.replaceAll(RegExp(r'[,\s$]'), '');
  return t.isEmpty ? null : double.tryParse(t);
}

/// Full precision, so opening and saving a bill never changes it.
String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';

double _cents(double v) => (v * 100).round() / 100;

// ------------------------------------------------------------- Lists --

class ExpenseTile extends StatelessWidget {
  const ExpenseTile(this.e, {super.key, this.showProject = false});

  final Expense e;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final ak = AkColors.of(context);
    final project = repo.project(e.projectId);
    final files = repo.attachmentsOf(e.id).length;
    final title = e.title.isNotEmpty
        ? e.title
        : e.vendor.isNotEmpty
        ? e.vendor
        : expenseCategoryLabel(e.category);
    return ListTile(
      leading: Icon(expenseCategoryIcon(e.category)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (e.number.isNotEmpty) e.number,
          if (e.title.isNotEmpty && e.vendor.isNotEmpty) e.vendor,
          expenseCategoryLabel(e.category),
          if (showProject) project?.code ?? 'Company',
          if (e.items.isNotEmpty)
            '${e.items.length} item${e.items.length == 1 ? '' : 's'}',
          fmtDate(e.date),
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (files > 0) ...[
                Icon(Icons.attach_file, size: 15, color: ak.muted),
                const SizedBox(width: 2),
              ],
              Text(
                fmtMoneyShort(e.amount),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (!e.paid) ...[
            const SizedBox(height: 4),
            const Pill('Unpaid', color: AkPalette.warn),
          ],
        ],
      ),
      onTap: () => openExpenseForm(context, expense: e),
    );
  }
}

/// Where the money went, by type of cost, largest first.
class CostBreakdown extends StatelessWidget {
  const CostBreakdown(this.expenses, {super.key});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final by = <ExpenseCategory, double>{};
    for (final e in expenses) {
      by[e.category] = (by[e.category] ?? 0) + e.net;
    }
    final total = by.values.fold(0.0, (s, v) => s + v);
    if (total.abs() < .005) return const SizedBox.shrink();
    final rows = by.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COSTS BY TYPE · WITHOUT VAT',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: ak.muted,
              ),
            ),
            const SizedBox(height: 8),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(expenseCategoryIcon(r.key), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(expenseCategoryLabel(r.key))),
                        Text(
                          '${(r.value / total * 100).round()}%',
                          style: TextStyle(color: ak.muted, fontSize: 12),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          fmtMoney(r.value),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (r.value / total).clamp(0.0, 1.0),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- Form --

Future<void> openExpenseForm(
  BuildContext context, {
  Expense? expense,
  String? projectId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ExpenseForm(expense: expense, projectId: projectId),
  ),
);

/// One line of a supplier's bill being edited.
class _Row {
  _Row([LineItem? i])
    : description = TextEditingController(text: i?.description ?? ''),
      quantity = TextEditingController(
        text: i == null ? '1' : _plain(i.quantity),
      ),
      unit = TextEditingController(text: i?.unit ?? ''),
      rate = TextEditingController(
        text: i == null || i.rate == 0 ? '' : _plain(i.rate),
      );

  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unit;
  final TextEditingController rate;

  LineItem get item => LineItem(
    description: description.text.trim(),
    quantity: _parse(quantity.text) ?? 0,
    unit: unit.text.trim(),
    rate: _parse(rate.text) ?? 0,
  );

  bool get isBlank =>
      description.text.trim().isEmpty && (_parse(rate.text) ?? 0) == 0;

  void dispose() {
    description.dispose();
    quantity.dispose();
    unit.dispose();
    rate.dispose();
  }
}

/// An expense as a supplier's bill: who, what for, the lines or the total,
/// VAT, whether it is paid, and the supplier's invoice kept with it.
class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, this.expense, this.projectId});

  final Expense? expense;
  final String? projectId;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final String _id;
  late final TextEditingController _title;
  late final TextEditingController _vendor;
  late final TextEditingController _reference;
  late final TextEditingController _amount;
  late final TextEditingController _vat;
  late final TextEditingController _notes;
  final _vendorFocus = FocusNode();
  final _rows = <_Row>[];
  late bool _itemized;
  late bool _hasVat;
  late bool _paid;
  PaymentMethod? _method;
  String? _projectId;
  late ExpenseCategory _category;
  late DateTime _date;
  final _added = <(Attachment, Uint8List)>[];
  final _removed = <Attachment>[];
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final repo = context.read<Repository>();
    _id = e?.id ?? repo.newId();
    _title = TextEditingController(text: e?.title ?? '');
    _vendor = TextEditingController(text: e?.vendor ?? '');
    _reference = TextEditingController(text: e?.reference ?? '');
    _amount = TextEditingController(
      text: e == null || e.items.isNotEmpty ? '' : _plain(e.amount),
    );
    _vat = TextEditingController(
      text: e == null || e.vatRate == 0 ? '11' : _plain(e.vatRate),
    );
    _notes = TextEditingController(text: e?.notes ?? '');
    _projectId = e?.projectId ?? widget.projectId;
    _category =
        e?.category ??
        (_projectId == null ? ExpenseCategory.rent : ExpenseCategory.materials);
    _date = e?.date ?? repo.now();
    // New bills are entered line by line; older totals stay totals.
    _itemized = e == null || e.items.isNotEmpty;
    _hasVat = (e?.vatRate ?? 0) != 0;
    _paid = e?.paid ?? true;
    _method = e?.method ?? (e == null ? PaymentMethod.cash : null);
    for (final i in e?.items ?? const <LineItem>[]) {
      _rows.add(_Row(i));
    }
    if (_rows.isEmpty) _rows.add(_Row());
  }

  @override
  void dispose() {
    for (final c in [_title, _vendor, _reference, _amount, _vat, _notes]) {
      c.dispose();
    }
    _vendorFocus.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  double get _vatRate => _hasVat ? _parse(_vat.text) ?? 0 : 0;

  List<LineItem> get _items => [
    for (final r in _rows)
      if (!r.isBlank) r.item,
  ];

  /// Subtotal, VAT and total as they will be saved.
  (double, double, double) get _totals {
    if (_itemized) {
      final sub = _cents(_items.fold(0.0, (s, i) => s + i.amount));
      final vat = _cents(sub * _vatRate / 100);
      return (sub, vat, sub + vat);
    }
    final total = _parse(_amount.text) ?? 0;
    final net = _vatRate == 0 ? total : _cents(total / (1 + _vatRate / 100));
    return (net, total - net, total);
  }

  void _addRows(List<LineItem> items) => setState(() {
    if (_rows.length == 1 && _rows.first.isBlank) {
      _rows.removeAt(0).dispose();
    }
    for (final i in items) {
      _rows.add(_Row(i.copyWith(section: '')));
    }
  });

  Future<void> _attach() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
        'xlsx',
        'xls',
        'csv',
        'docx',
      ],
      compressionQuality: 70,
    );
    if (files.isEmpty || !mounted) return;
    final repo = context.read<Repository>();
    final tooBig = <String>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      if (bytes.length > maxAttachmentBytes) {
        tooBig.add(f.name);
        continue;
      }
      final now = repo.now();
      _added.add((
        Attachment(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          ownerId: _id,
          name: f.name,
          mime: mimeOf(f.name),
          size: bytes.length,
        ),
        bytes,
      ));
    }
    if (!mounted) return;
    setState(() {});
    if (tooBig.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tooBig.join(', ')} is over ${fmtSize(maxAttachmentBytes)}. '
            'Please attach a smaller copy, for example a photo instead of a '
            'scan.',
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    final (_, _, total) = _totals;
    final items = _itemized ? _items : const <LineItem>[];
    if (_itemized && (items.isEmpty || total <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one item with a rate, or switch to Total only.',
          ),
        ),
      );
      return;
    }
    _saving = true;
    final repo = context.read<Repository>();
    final e = widget.expense;
    final now = repo.now();
    await repo.saveExpense(
      Expense(
        id: _id,
        createdAt: e?.createdAt ?? now,
        updatedAt: now,
        number: e?.number ?? '',
        projectId: _projectId,
        date: _date,
        category: _category,
        title: _title.text.trim(),
        vendor: _vendor.text.trim(),
        reference: _reference.text.trim(),
        items: items,
        vatRate: _vatRate,
        amount: total,
        paid: _paid,
        method: _paid ? _method : null,
        notes: _notes.text.trim(),
      ),
      attach: _added,
      detach: _removed,
    );
    if (mounted) Navigator.pop(context);
  }

  /// Fills in the category last used with a supplier.
  void _pickedVendor(String name) {
    _vendor.text = name;
    if (widget.expense != null) return;
    final repo = context.read<Repository>();
    final last = repo.expenses.where((e) => e.vendor == name).firstOrNull;
    if (last != null) setState(() => _category = last.category);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    const gap = SizedBox(height: 14);
    final (sub, vat, total) = _totals;
    final suppliers = {
      for (final e in repo.expenses)
        if (e.vendor.isNotEmpty) e.vendor,
    }.toList();
    final saved = [
      for (final a in repo.attachmentsOf(_id))
        if (!_removed.any((r) => r.id == a.id)) a,
    ];

    Widget totalRow(String label, double v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? null : ak.muted,
                fontWeight: bold ? FontWeight.w800 : null,
              ),
            ),
          ),
          Text(
            fmtMoney(v),
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : null,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.expense == null
              ? 'New expense'
              : widget.expense!.number.isEmpty
              ? 'Expense'
              : widget.expense!.number,
        ),
        actions: [
          if (widget.expense != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, 'this expense')) return;
                await repo.deleteExpense(widget.expense!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: ak.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Internal to AK. Expenses never appear on client '
                      'documents.',
                      style: TextStyle(color: ak.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SectionHeader('Bill'),
              RawAutocomplete<String>(
                textEditingController: _vendor,
                focusNode: _vendorFocus,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  if (q.isEmpty) return const [];
                  return suppliers.where(
                    (s) => s.toLowerCase().contains(q) && s != v.text,
                  );
                },
                onSelected: _pickedVendor,
                fieldViewBuilder: (context, ctrl, focus, onSubmit) =>
                    TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Supplier',
                        hintText: 'Company, subcontractor or person paid',
                      ),
                    ),
                optionsViewBuilder: (context, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 420,
                      ),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        children: [
                          for (final o in options)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.storefront_outlined),
                              title: Text(o),
                              onTap: () => onSelected(o),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _reference,
                      decoration: const InputDecoration(
                        labelText: 'Supplier invoice no.',
                        hintText: 'As on their bill',
                      ),
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
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Porcelain tiles, kitchen and bathrooms',
                ),
              ),
              gap,
              DropdownButtonFormField<String?>(
                initialValue: repo.project(_projectId) == null
                    ? null
                    : _projectId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'For',
                  helperText: _projectId == null
                      ? 'Company running cost (overheads), not on a project'
                      : "It lowers this project's profit",
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Company (overheads)'),
                  ),
                  for (final p in repo.projects)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.code} · ${p.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _projectId = v),
              ),
              gap,
              DropdownButtonFormField<ExpenseCategory>(
                key: ValueKey(_category),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type of cost'),
                items: [
                  for (final c in ExpenseCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(expenseCategoryIcon(c), size: 18),
                          const SizedBox(width: 10),
                          Text(expenseCategoryLabel(c)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              SectionHeader(
                'Amount',
                trailing: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: const [
                    ButtonSegment(value: true, label: Text('Items')),
                    ButtonSegment(value: false, label: Text('Total only')),
                  ],
                  selected: {_itemized},
                  onSelectionChanged: (v) {
                    setState(() {
                      // Keep the figure when switching to a total.
                      if (!v.first &&
                          _amount.text.trim().isEmpty &&
                          total > 0) {
                        _amount.text = _plain(total);
                      }
                      _itemized = v.first;
                    });
                  },
                ),
              ),
              if (_itemized) ...[
                for (final (k, r) in _rows.indexed) _itemCard(k, r),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _rows.add(_Row())),
                      icon: const Icon(Icons.add),
                      label: const Text('Item'),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final items = await showPasteItems(
                          context,
                          intro:
                              'Paste the lines of the supplier\'s bill, from '
                              'Excel or written for you in the chat. One item '
                              'per line: description, unit, quantity, rate.',
                          example:
                              'Porcelain tiles 60x60 | m² | 85 | 22\n'
                              'Tile adhesive | bag | 40 | 6.5',
                        );
                        if (items != null) _addRows(items);
                      },
                      icon: const Icon(Icons.content_paste),
                      label: const Text('Paste items'),
                    ),
                  ],
                ),
              ] else
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: _hasVat ? 'Total, VAT included' : 'Total',
                    prefixText: '\$ ',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      (_parse(v ?? '') ?? 0) <= 0 ? 'Enter the amount' : null,
                ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _hasVat,
                onChanged: (v) => setState(() => _hasVat = v),
                title: const Text('The supplier charged VAT'),
                subtitle: const Text(
                  'VAT you pay suppliers is deducted from the VAT on your '
                  'invoices, so profit counts the cost without it.',
                ),
              ),
              if (_hasVat)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SizedBox(
                      width: 140,
                      child: TextFormField(
                        controller: _vat,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'VAT rate',
                          suffixText: '%',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    children: [
                      totalRow(_hasVat ? 'Cost without VAT' : 'Subtotal', sub),
                      if (_hasVat) totalRow('VAT ${_plain(_vatRate)}%', vat),
                      const Divider(height: 12),
                      totalRow('Total of the bill', total, bold: true),
                    ],
                  ),
                ),
              ),
              const SectionHeader('Payment'),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Paid'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.schedule),
                    label: Text('Not paid yet'),
                  ),
                ],
                selected: {_paid},
                onSelectionChanged: (v) => setState(() {
                  _paid = v.first;
                  if (_paid) _method ??= PaymentMethod.cash;
                }),
              ),
              const SizedBox(height: 12),
              if (_paid)
                DropdownButtonFormField<PaymentMethod?>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: [
                    for (final m in PaymentMethod.values)
                      DropdownMenuItem(
                        value: m,
                        child: Text(paymentMethodLabel(m)),
                      ),
                  ],
                  onChanged: (v) => setState(() => _method = v),
                )
              else
                Text(
                  'Shown as a bill still to pay to the supplier. Open it and '
                  'mark it paid when you pay.',
                  style: TextStyle(color: ak.muted),
                ),
              SectionHeader(
                'Supplier invoice',
                trailing: TextButton.icon(
                  onPressed: _attach,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                ),
              ),
              if (saved.isEmpty && _added.isEmpty)
                Text(
                  'Attach the supplier\'s invoice or receipt (PDF or photo) '
                  'to keep it with this expense. The amounts are not read '
                  'from the file: enter the items or the total above.',
                  style: TextStyle(color: ak.muted),
                ),
              for (final a in saved)
                _fileTile(
                  a,
                  open: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    String? problem;
                    try {
                      final bytes = await repo.attachmentBytes(a.id);
                      if (bytes == null) {
                        problem =
                            'This file is not on this device yet. It opens '
                            'once the device that added it has synced.';
                      } else if (context.mounted) {
                        await openAttachment(context, a, bytes);
                      }
                    } on Exception catch (_) {
                      problem =
                          'The file could not be opened. Check the internet '
                          'connection and try again.';
                    }
                    if (problem != null) {
                      messenger.showSnackBar(SnackBar(content: Text(problem)));
                    }
                  },
                  remove: () => setState(() => _removed.add(a)),
                ),
              for (final (a, bytes) in _added)
                _fileTile(
                  a,
                  open: () => openAttachment(context, a, bytes),
                  remove: () => setState(
                    () => _added.removeWhere((x) => x.$1.id == a.id),
                  ),
                ),
              const SectionHeader('Notes'),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Anything to remember about this bill',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemCard(int k, _Row r) {
    final ak = AkColors.of(context);
    final item = r.item;
    InputDecoration small(String label) =>
        InputDecoration(labelText: label, isDense: true);
    const figures = TextStyle(fontSize: 14);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '${k + 1}',
                  style: TextStyle(
                    color: ak.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: r.description,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: small('Item'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove item',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() {
                    _rows.removeAt(k).dispose();
                    if (_rows.isEmpty) _rows.add(_Row());
                  }),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: r.quantity,
                      style: figures,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: small('Qty'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: r.unit,
                      style: figures,
                      decoration: small('Unit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: TextFormField(
                      controller: r.rate,
                      style: figures,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: small('Rate').copyWith(prefixText: '\$'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        fmtMoney(item.amount),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileTile(
    Attachment a, {
    required VoidCallback open,
    required VoidCallback remove,
  }) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Icon(
        a.isPdf
            ? Icons.picture_as_pdf_outlined
            : a.isImage
            ? Icons.image_outlined
            : Icons.insert_drive_file_outlined,
      ),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(fmtSize(a.size)),
      onTap: open,
      trailing: IconButton(
        tooltip: 'Remove file',
        icon: const Icon(Icons.close),
        onPressed: remove,
      ),
    ),
  );
}

/// Shows a photo in the app; a PDF or other file goes to the phone's or
/// computer's own viewer.
Future<void> openAttachment(
  BuildContext context,
  Attachment a,
  Uint8List bytes,
) async {
  final viewable = const {
    'image/jpeg',
    'image/png',
    'image/webp',
  }.contains(a.mime);
  if (viewable) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(a.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                tooltip: 'Save a copy',
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _saveCopy(a, bytes),
              ),
            ],
          ),
          body: InteractiveViewer(
            maxScale: 6,
            child: Center(child: Image.memory(bytes)),
          ),
        ),
      ),
    );
  } else if (a.isPdf) {
    // A name of its own, so two files called "invoice.pdf" never open as
    // each other.
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${a.id.length > 8 ? a.id.substring(0, 8) : a.id}-${a.name}',
    );
  } else {
    await _saveCopy(a, bytes);
  }
}

Future<void> _saveCopy(Attachment a, Uint8List bytes) =>
    FilePicker.saveFile(fileName: a.name, bytes: bytes, mimeType: a.mime);
