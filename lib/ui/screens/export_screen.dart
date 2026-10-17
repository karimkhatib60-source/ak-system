import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../data/statement.dart';
import '../export.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens the export of a project's money documents, or of every project's
/// when [projectId] is null. [internal] starts with the expenses chosen.
Future<void> openExportScreen(
  BuildContext context, {
  String? projectId,
  DateTime? from,
  bool internal = false,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) =>
        ExportScreen(projectId: projectId, from: from, internal: internal),
  ),
);

/// Choose which quotations, invoices, receipts, statement and (for AK
/// only) expenses to export, and save them as one PDF, a ZIP of separate
/// files with an Excel list, or an Excel workbook. Owner only.
class ExportScreen extends StatefulWidget {
  const ExportScreen({
    super.key,
    this.projectId,
    this.from,
    this.internal = false,
  });

  final String? projectId;
  final DateTime? from;
  final bool internal;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

enum _Kind { quotations, invoices, receipts, expenses }

class _ExportScreenState extends State<ExportScreen> {
  DateTime? _from;
  DateTime? _to;
  late ExportChoice _choice;
  var _format = ExportFormat.pdf;
  var _busy = false;
  final _open = <_Kind>{};

  /// Documents that have been on the list: what the user chose or left
  /// for them stays when a period hides them and brings them back.
  final _seen = <String>{};

  /// Kinds the user wants: a kind they cleared gets nothing added when a
  /// new period brings in more of it.
  late final Map<_Kind, bool> _inUse;

  ExportSource _source(Repository repo) =>
      ExportSource(repo, projectId: widget.projectId, from: _from, to: _to);

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    final s = _source(context.read<Repository>());
    _choice = ExportChoice.client(s);
    if (widget.internal) _choice.expenses.addAll(s.expenses.map((e) => e.id));
    _inUse = {for (final k in _Kind.values) k: k != _Kind.expenses};
    _inUse[_Kind.expenses] = widget.internal;
    for (final k in _Kind.values) {
      _seen.addAll(_listed(s, k));
    }
  }

  /// After the user ticks or unticks documents of a kind.
  void _changed(_Kind k, Iterable<String> listed) =>
      _inUse[k] = listed.any(_ids(k).contains);

  /// A new period. Documents already chosen or left out stay so, even
  /// those the period now hides (only the ones in the period are
  /// exported); documents it brings in for the first time are chosen as
  /// at the start, for each kind still in use.
  void _setPeriod(DateTime? from, DateTime? to) {
    final repo = context.read<Repository>();
    _from = from;
    _to = to;
    final s = _source(repo);
    final fresh = ExportChoice.client(s);
    for (final k in _Kind.values) {
      final suggested = k == _Kind.expenses
          ? _listed(s, k).toSet()
          : _idsOf(fresh, k);
      for (final id in _listed(s, k)) {
        if (_seen.add(id) && _inUse[k]! && suggested.contains(id)) {
          _ids(k).add(id);
        }
      }
    }
  }

  static List<String> _listed(ExportSource s, _Kind k) => switch (k) {
    _Kind.quotations => [for (final q in s.quotations) q.id],
    _Kind.invoices => [for (final i in s.invoices) i.id],
    _Kind.receipts => [for (final p in s.receipts) p.id],
    _Kind.expenses => [for (final e in s.expenses) e.id],
  };

  static Set<String> _idsOf(ExportChoice c, _Kind k) => switch (k) {
    _Kind.quotations => c.quotations,
    _Kind.invoices => c.invoices,
    _Kind.receipts => c.receipts,
    _Kind.expenses => c.expenses,
  };

  Set<String> _ids(_Kind k) => _idsOf(_choice, k);

  /// The chosen documents within the period: what is exported.
  ExportChoice _inPeriod(ExportSource s) => ExportChoice(
    quotations: {..._listed(s, _Kind.quotations)}
      ..retainAll(_choice.quotations),
    invoices: {..._listed(s, _Kind.invoices)}..retainAll(_choice.invoices),
    receipts: {..._listed(s, _Kind.receipts)}..retainAll(_choice.receipts),
    expenses: {..._listed(s, _Kind.expenses)}..retainAll(_choice.expenses),
    statement: _choice.statement && s.hasStatement,
    billFiles: _choice.billFiles,
  );

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final s = _source(repo);
    final project = s.project;
    final quotations = s.quotations;
    final invoices = s.invoices;
    final receipts = s.receipts;
    final expenses = s.expenses;
    final chosen = _inPeriod(s);
    final count = chosen.count;
    // Arrived meanwhile (a sync): left out, as the list shows them.
    for (final k in _Kind.values) {
      _seen.addAll(_listed(s, k));
    }

    String clientOf(String? id) => repo.client(id)?.name ?? '';
    String code(String? id) => repo.project(id)?.code ?? '';

    Widget kind(
      _Kind k,
      String title,
      IconData icon,
      List<(String id, String title, String subtitle, String amount)> docs,
    ) {
      final ids = _ids(k);
      final chosen = docs.where((d) => ids.contains(d.$1)).length;
      final open = _open.contains(k);
      return Card(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          children: [
            ListTile(
              leading: Checkbox(
                tristate: true,
                value: chosen == 0
                    ? false
                    : chosen == docs.length
                    ? true
                    : null,
                onChanged: docs.isEmpty
                    ? null
                    : (_) => setState(() {
                        if (chosen == docs.length) {
                          ids.removeAll(docs.map((d) => d.$1));
                        } else {
                          ids.addAll(docs.map((d) => d.$1));
                        }
                        _changed(k, docs.map((d) => d.$1));
                      }),
              ),
              title: Row(
                children: [
                  Icon(icon, size: 18, color: ak.muted),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title)),
                ],
              ),
              subtitle: Text(
                docs.isEmpty
                    ? 'None in this period'.tr
                    : '{0} of {1} chosen'.trArgs([chosen, docs.length]),
              ),
              trailing: docs.isEmpty
                  ? null
                  : IconButton(
                      tooltip: open
                          ? 'Hide the list'.tr
                          : 'Choose one by one'.tr,
                      icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                      onPressed: () =>
                          setState(() => open ? _open.remove(k) : _open.add(k)),
                    ),
              onTap: docs.isEmpty
                  ? null
                  : () => setState(() => open ? _open.remove(k) : _open.add(k)),
            ),
            if (open)
              for (final d in docs)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 28,
                    end: 16,
                  ),
                  value: ids.contains(d.$1),
                  onChanged: (v) => setState(() {
                    v == true ? ids.add(d.$1) : ids.remove(d.$1);
                    _changed(k, docs.map((d) => d.$1));
                  }),
                  title: Text(
                    d.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    d.$3,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: Text(
                    d.$4,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
          ],
        ),
      );
    }

    final format = <(ExportFormat, IconData, String, String)>[
      (
        ExportFormat.pdf,
        Icons.picture_as_pdf_outlined,
        'One PDF file'.tr,
        'Every document one after the other, each with its own page '
                'numbers. Easy to print or send in one go.'
            .tr,
      ),
      (
        ExportFormat.zip,
        Icons.folder_zip_outlined,
        'Separate files (ZIP)'.tr,
        'One PDF per document in folders, with an Excel list of '
                'everything.'
            .tr,
      ),
      (
        ExportFormat.excel,
        Icons.table_chart_outlined,
        'Excel list'.tr,
        'A sheet for each kind of document, with amounts, VAT, money '
                'received and balances.'
            .tr,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export'.tr),
            Text(
              project == null
                  ? 'All projects'.tr
                  : [
                      project.code,
                      project.name,
                    ].where((x) => x.isNotEmpty).dots(),
              style: TextStyle(fontSize: 12.5, color: ak.onChromeMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: count == 0 || _busy ? null : () => _export(s, chosen),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
            label: Text(
              _busy
                  ? 'Preparing…'.tr
                  : count == 1
                  ? 'Export 1 document'.tr
                  : 'Export {0} documents'.trArgs([count]),
            ),
          ),
        ),
      ),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionHeader('Period'.tr),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'From'.tr,
                      value: _from,
                      onChanged: (d) => setState(() => _setPeriod(d, _to)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'To'.tr,
                      value: _to,
                      onChanged: (d) => setState(() => _setPeriod(_from, d)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 16, 0),
              child: Text(
                'Leave both empty for every date.'.tr,
                style: TextStyle(color: ak.muted, fontSize: 12.5),
              ),
            ),
            SectionHeader('Client documents'.tr),
            if (s.hasStatement)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _choice.statement,
                  onChanged: (v) =>
                      setState(() => _choice.statement = v ?? false),
                  title: Text('Project statement'.tr),
                  subtitle: Text(
                    'Contract, payment schedule, invoices and money '
                            'received, as of today'
                        .tr,
                  ),
                ),
              ),
            kind(
              _Kind.quotations,
              'Quotations'.tr,
              Icons.request_quote_outlined,
              [
                for (final q in quotations)
                  (
                    q.id,
                    [q.number, q.title].where((x) => x.isNotEmpty).dots(),
                    [
                      fmtDate(q.date),
                      quotationStatusLabel(q.status),
                      if (project == null) code(q.projectId),
                      clientOf(q.clientId),
                    ].where((x) => x.isNotEmpty).dots(),
                    fmtMoneyShort(q.total),
                  ),
              ],
            ),
            kind(_Kind.invoices, 'Invoices'.tr, Icons.receipt_long_outlined, [
              for (final i in invoices)
                (
                  i.id,
                  [i.number, i.title].where((x) => x.isNotEmpty).dots(),
                  [
                    fmtDate(i.date),
                    paymentStateLabel(repo.paymentState(i)),
                    if (i.extra) 'Extra work'.tr,
                    if (project == null) code(i.projectId),
                    clientOf(i.clientId),
                  ].where((x) => x.isNotEmpty).dots(),
                  fmtMoneyShort(i.total),
                ),
            ]),
            kind(_Kind.receipts, 'Receipts'.tr, Icons.payments_outlined, [
              for (final p in receipts)
                (
                  p.id,
                  [
                    if (p.number.isNotEmpty) p.number,
                    clientOf(repo.payerOf(p)),
                  ].where((x) => x.isNotEmpty).dots(),
                  [
                    fmtDate(p.date),
                    receiptPurpose(repo, p),
                    paymentMethodLabel(p.method),
                  ].dots(),
                  fmtMoneyShort(p.amount),
                ),
            ]),
            SectionHeader('AK internal'.tr),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: ak.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Expenses come with a cost and profit report by '
                              'contract. Never send them to the client.'
                          .tr,
                      style: TextStyle(color: ak.muted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            kind(_Kind.expenses, 'Expenses'.tr, Icons.receipt_outlined, [
              for (final e in expenses)
                (
                  e.id,
                  [
                    if (e.number.isNotEmpty) e.number,
                    e.vendor.isNotEmpty ? e.vendor : e.title,
                  ].where((x) => x.isNotEmpty).dots(),
                  [
                    fmtDate(e.date),
                    if (project == null) code(e.projectId),
                    expenseCategoryLabel(e.category),
                    if (!e.paid) 'Unpaid'.tr,
                  ].where((x) => x.isNotEmpty).dots(),
                  fmtMoneyShort(e.amount),
                ),
            ]),
            if (chosen.expenses.isNotEmpty)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SwitchListTile(
                  value: _choice.billFiles && _format == ExportFormat.zip,
                  onChanged: _format == ExportFormat.zip
                      ? (v) => setState(() => _choice.billFiles = v)
                      : null,
                  title: Text("Add the suppliers' files".tr),
                  subtitle: Text(
                    _format == ExportFormat.zip
                        ? 'The bills and receipts attached to these expenses'.tr
                        : 'In the ZIP only'.tr,
                  ),
                ),
              ),
            SectionHeader('Save as'.tr),
            for (final (f, icon, title, note) in format)
              Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _format == f ? ak.accent : ak.line,
                    width: _format == f ? 1.6 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Icon(icon, color: _format == f ? ak.accent : null),
                  title: Text(title),
                  subtitle: Text(note),
                  trailing: _format == f
                      ? Icon(Icons.check_circle, color: ak.accent)
                      : null,
                  onTap: _busy ? null : () => setState(() => _format = f),
                ),
              ),
            if (chosen.hasInternal)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: ak.warn),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(switch (_format) {
                        ExportFormat.pdf =>
                          'This PDF includes the internal cost and profit '
                                  'report. Keep it inside AK.'
                              .tr,
                        ExportFormat.zip =>
                          'The ZIP includes the internal cost and profit '
                                  'report. Keep it inside AK.'
                              .tr,
                        ExportFormat.excel =>
                          'This Excel list includes the expenses and the '
                                  'profit by work. Keep it inside AK.'
                              .tr,
                      }, style: TextStyle(color: ak.muted, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(ExportSource s, ExportChoice chosen) async {
    final format = _format;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await buildExport(s, chosen, format);
      if (format == ExportFormat.pdf) {
        await Printing.sharePdf(bytes: file.bytes, filename: file.name);
      } else {
        final saved = await FilePicker.saveFile(
          dialogTitle: 'Save the export'.tr,
          fileName: file.name,
          bytes: file.bytes,
          mimeType: file.mime,
        );
        // On the web the browser downloads it and no path comes back.
        if (saved != null || kIsWeb) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                file.missing == 0
                    ? 'Saved {0}'.trArgs([file.name])
                    : file.missing == 1
                    ? 'Saved {0}. One supplier file is not on this device '
                              'and was left out; open its expense when '
                              'online, then export again.'
                          .trArgs([file.name])
                    : 'Saved {0}. {1} supplier files are not on this '
                              'device and were left out; open their expenses '
                              'when online, then export again.'
                          .trArgs([file.name, file.missing]),
              ),
            ),
          );
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export: {0}'.trArgs(['$e']))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
