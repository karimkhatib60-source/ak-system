import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/models.dart';
import '../data/profit.dart';
import '../data/project_statement.dart';
import '../data/repository.dart';
import '../data/statement.dart';
import '../data/xlsx.dart';
import 'format.dart';
import 'pdf_docs.dart';

/// What an export is saved as.
enum ExportFormat {
  /// Every chosen document in one PDF, each with its own page numbers.
  pdf,

  /// A folder of separate PDFs, with the Excel register and, if chosen,
  /// the suppliers' files.
  zip,

  /// One Excel workbook listing the chosen documents.
  excel,
}

/// The money documents of one project, or of every project, dated within
/// a range.
class ExportSource {
  ExportSource(this.repo, {this.projectId, this.from, this.to});

  final Repository repo;

  /// Null for every project.
  final String? projectId;
  final DateTime? from;
  final DateTime? to;

  Project? get project => repo.project(projectId);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool inRange(DateTime d) =>
      (from == null || !_day(d).isBefore(_day(from!))) &&
      (to == null || !_day(d).isAfter(_day(to!)));

  static int _byDate(DateTime a, String an, DateTime b, String bn) {
    final c = _day(a).compareTo(_day(b));
    return c != 0 ? c : an.compareTo(bn);
  }

  List<Quotation> get quotations => [
    for (final q
        in projectId == null ? repo.quotations : repo.quotationsFor(projectId!))
      if (inRange(q.date)) q,
  ]..sort((a, b) => _byDate(a.date, a.number, b.date, b.number));

  List<Invoice> get invoices => [
    for (final i
        in projectId == null ? repo.invoices : repo.invoicesFor(projectId!))
      if (inRange(i.date)) i,
  ]..sort((a, b) => _byDate(a.date, a.number, b.date, b.number));

  List<Payment> get receipts => [
    for (final p in repo.receipts(projectId: projectId))
      if (inRange(p.date)) p,
  ]..sort((a, b) => _byDate(a.date, a.number, b.date, b.number));

  List<Expense> get expenses => [
    for (final e
        in projectId == null ? repo.expenses : repo.expensesFor(projectId!))
      if (inRange(e.date)) e,
  ]..sort((a, b) => _byDate(a.date, a.number, b.date, b.number));

  /// A project statement can be added for a project with a client.
  bool get hasStatement =>
      project != null && repo.client(project!.clientId) != null;
}

/// The documents chosen for an export, by id.
class ExportChoice {
  ExportChoice({
    Set<String>? quotations,
    Set<String>? invoices,
    Set<String>? receipts,
    Set<String>? expenses,
    this.statement = false,
    this.billFiles = false,
  }) : quotations = quotations ?? {},
       invoices = invoices ?? {},
       receipts = receipts ?? {},
       expenses = expenses ?? {};

  /// What is usually wanted: every document the client has seen (no
  /// drafts, no cancelled invoices), the receipts and the statement.
  /// Expenses are internal and are added only on purpose.
  factory ExportChoice.client(ExportSource s) => ExportChoice(
    quotations: {
      for (final q in s.quotations)
        if (q.status != QuotationStatus.draft) q.id,
    },
    invoices: {
      for (final i in s.invoices)
        if (i.status == InvoiceStatus.sent) i.id,
    },
    receipts: {for (final p in s.receipts) p.id},
    statement: s.hasStatement,
  );

  final Set<String> quotations;
  final Set<String> invoices;
  final Set<String> receipts;
  final Set<String> expenses;

  /// The project statement (one project only).
  bool statement;

  /// The suppliers' own files kept with the chosen expenses (ZIP only).
  bool billFiles;

  int get count =>
      quotations.length +
      invoices.length +
      receipts.length +
      expenses.length +
      (statement ? 1 : 0);

  bool get hasInternal => expenses.isNotEmpty;
}

/// A file ready to save or share.
class ExportFile {
  const ExportFile(this.name, this.bytes, this.mime, {this.missing = 0});

  final String name;
  final Uint8List bytes;
  final String mime;

  /// Suppliers' files left out because they are not on this device and
  /// could not be downloaded.
  final int missing;
}

/// Builds the export. Receipts recorded before receipt numbers existed are
/// numbered first, as when one is printed.
Future<ExportFile> buildExport(
  ExportSource s,
  ExportChoice c,
  ExportFormat format,
) async {
  final repo = s.repo;
  final quotations = [
    for (final q in s.quotations)
      if (c.quotations.contains(q.id)) q,
  ];
  final invoices = [
    for (final i in s.invoices)
      if (c.invoices.contains(i.id)) i,
  ];
  final receipts = [
    for (final p in s.receipts)
      if (c.receipts.contains(p.id)) await repo.withReceiptNumber(p),
  ];
  final expenses = [
    for (final e in s.expenses)
      if (c.expenses.contains(e.id)) e,
  ];
  final statement = c.statement && s.hasStatement
      ? buildProjectStatement(repo, s.projectId!, lang: docLang)
      : null;
  final report = expenses.isEmpty
      ? null
      : CostReport(
          repo,
          expenses,
          projectId: s.projectId,
          from: s.from,
          to: s.to,
        );
  final base = exportName(s, repo.now());

  switch (format) {
    case ExportFormat.pdf:
      final bytes = await buildBundlePdf(repo, [
        ?statement,
        ...quotations,
        ...invoices,
        ...receipts,
        ?report,
      ], title: base);
      return ExportFile('$base.pdf', bytes, 'application/pdf');
    case ExportFormat.excel:
      return ExportFile(
        '$base.xlsx',
        exportWorkbook(
          s,
          quotations,
          invoices,
          receipts,
          expenses,
          statement: statement,
        ),
        xlsxMime,
      );
    case ExportFormat.zip:
      final zip = Archive();
      var missing = 0;
      void add(String path, List<int> bytes) =>
          zip.add(ArchiveFile.bytes('$base/$path', bytes));
      final used = <String>{};
      String unique(String folder, String name, String ext) {
        // Short enough for Windows, which refuses names over 255.
        var stem = fileSafe(name);
        if (stem.length > 80) stem = stem.substring(0, 80);
        if (stem.isEmpty) stem = 'file';
        var path = '$folder/$stem.$ext';
        for (var n = 2; !used.add(path.toLowerCase()); n++) {
          path = '$folder/$stem-$n.$ext';
        }
        return path;
      }

      if (statement != null) {
        add(
          unique(
            fileSafe('Statement@@file'.td),
            '${statement.project.code}-${isoDay(statement.account.to)}',
            'pdf',
          ),
          await buildProjectStatementPdf(repo, statement),
        );
      }
      for (final q in quotations) {
        add(
          unique(fileSafe('Quotations'.td), _docName(q.number, q.title), 'pdf'),
          await buildPdf(repo, q),
        );
      }
      for (final i in invoices) {
        add(
          unique(fileSafe('Invoices'.td), _docName(i.number, i.title), 'pdf'),
          await buildPdf(repo, i),
        );
      }
      for (final p in receipts) {
        add(
          unique(
            fileSafe('Receipts'.td),
            _docName(p.number, repo.client(repo.payerOf(p))?.name ?? ''),
            'pdf',
          ),
          await buildReceiptPdf(repo, p),
        );
      }
      if (report != null) {
        final folder = fileSafe('AK internal'.td);
        add(
          unique(folder, 'Cost and profit report'.td, 'pdf'),
          await buildBundlePdf(repo, [report], title: base),
        );
        if (c.billFiles) {
          for (final e in expenses) {
            for (final a in repo.attachmentsOf(e.id)) {
              Uint8List? bytes;
              try {
                bytes = await repo.attachmentBytes(a.id);
              } catch (_) {
                // Offline, or the file never reached the cloud.
              }
              if (bytes == null) {
                missing++;
                continue;
              }
              final dot = a.name.lastIndexOf('.');
              final ext = dot > 0 ? fileSafe(a.name.substring(dot + 1)) : '';
              final stem = dot > 0 ? a.name.substring(0, dot) : a.name;
              add(
                unique(
                  '$folder/${fileSafe('Supplier files'.td)}',
                  '${e.number}-$stem',
                  ext.isEmpty || ext.length > 10 ? 'bin' : ext,
                ),
                bytes,
              );
            }
          }
        }
      }
      add(
        '${fileSafe('Register'.td)}.xlsx',
        exportWorkbook(
          s,
          quotations,
          invoices,
          receipts,
          expenses,
          statement: statement,
        ),
      );
      return ExportFile(
        '$base.zip',
        ZipEncoder().encodeBytes(zip),
        'application/zip',
        missing: missing,
      );
  }
}

const xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

String isoDay(DateTime d) => d.toIso8601String().substring(0, 10);

String _docName(String number, String title) {
  final t = title.trim();
  if (number.isEmpty) return t.isEmpty ? 'document' : t;
  if (t.isEmpty) return number;
  return '$number ${t.length > 40 ? t.substring(0, 40) : t}';
}

/// The file name of an export: the project's code (or "Finance") and the
/// day it was made.
String exportName(ExportSource s, DateTime now) {
  final what = s.project?.code.isNotEmpty == true
      ? s.project!.code
      : s.project?.name ?? 'Finance'.td;
  return fileSafe('${'Export'.td}-$what-${isoDay(now)}');
}

/// The Excel register of the chosen documents: one sheet per kind, in the
/// document language.
Uint8List exportWorkbook(
  ExportSource s,
  List<Quotation> quotations,
  List<Invoice> invoices,
  List<Payment> receipts,
  List<Expense> expenses, {
  ProjectStatement? statement,
}) {
  final repo = s.repo;
  final rtl = docLang == AppLang.ar;
  String projectOf(String? id) {
    final p = repo.project(id);
    return p == null ? '' : (p.code.isEmpty ? p.name : p.code);
  }

  String clientOf(String? id) => repo.client(id)?.name ?? '';
  final scope = s.project == null
      ? 'All projects'.td
      : [
          s.project!.code,
          s.project!.name,
        ].where((x) => x.isNotEmpty).join(' · ');
  final period = s.from == null && s.to == null
      ? 'All dates'.td
      : '{0} to {1}'.tdArgs([
          s.from == null ? '…' : fmtDocDate(s.from),
          s.to == null ? '…' : fmtDocDate(s.to),
        ]);
  String title(String what) => '$what · $scope · $period';

  final account = statement?.account;
  final sheets = <XlsxSheet>[
    if (account != null)
      XlsxSheet(
        'Project statement'.td,
        rtl: rtl,
        title:
            '${'Project statement'.td} · $scope · '
            '${account.client.name} · ${fmtDocDate(account.to)}',
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Date'.td, XlsxType.date),
          XlsxColumn('Reference'.td, XlsxType.text, width: 16),
          XlsxColumn('Description'.td, XlsxType.text, width: 44),
          XlsxColumn('Debit'.td, XlsxType.money),
          XlsxColumn('Credit@@column'.td, XlsxType.money),
          XlsxColumn('Balance'.td, XlsxType.money, total: false),
        ],
        rows: [
          if (account.from != null)
            [
              account.from,
              '',
              'Opening balance'.td,
              null,
              null,
              _c(account.opening),
            ],
          for (final l in account.lines)
            [
              l.date,
              l.reference,
              l.description,
              l.debit.abs() < .005 ? null : _c(l.debit),
              l.credit.abs() < .005 ? null : _c(l.credit),
              _c(l.balance),
            ],
        ],
      ),
    if (quotations.isNotEmpty)
      XlsxSheet(
        'Quotations'.td,
        rtl: rtl,
        title: title('Quotations'.td),
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Number'.td, XlsxType.text, width: 16),
          XlsxColumn('Date'.td, XlsxType.date),
          XlsxColumn('Client'.td, XlsxType.text),
          XlsxColumn('Project'.td, XlsxType.text, width: 14),
          XlsxColumn('Title'.td, XlsxType.text, width: 32),
          XlsxColumn('Status'.td, XlsxType.text, width: 12),
          XlsxColumn('Without VAT'.td, XlsxType.money),
          XlsxColumn('VAT'.td, XlsxType.money),
          XlsxColumn('Total'.td, XlsxType.money),
        ],
        rows: [
          for (final q in quotations)
            [
              q.number,
              q.date,
              clientOf(q.clientId),
              projectOf(q.projectId),
              q.title,
              quotationStatusLabel(q.status, docLang),
              _c(q.net),
              _c(q.vat),
              _c(q.total),
            ],
        ],
      ),
    if (invoices.isNotEmpty)
      XlsxSheet(
        'Invoices'.td,
        rtl: rtl,
        title: title('Invoices'.td),
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Number'.td, XlsxType.text, width: 16),
          XlsxColumn('Date'.td, XlsxType.date),
          XlsxColumn('Due date'.td, XlsxType.date),
          XlsxColumn('Client'.td, XlsxType.text),
          XlsxColumn('Project'.td, XlsxType.text, width: 14),
          XlsxColumn('Contract'.td, XlsxType.text, width: 16),
          XlsxColumn('Title'.td, XlsxType.text, width: 32),
          XlsxColumn('Status'.td, XlsxType.text, width: 12),
          XlsxColumn('Without VAT'.td, XlsxType.money),
          XlsxColumn('VAT'.td, XlsxType.money),
          XlsxColumn('Total'.td, XlsxType.money),
          XlsxColumn('Received'.td, XlsxType.money),
          XlsxColumn('Balance due'.td, XlsxType.money),
        ],
        rows: [
          for (final i in invoices)
            () {
              final issued = i.status == InvoiceStatus.sent;
              return <Object?>[
                i.number,
                i.date,
                i.dueDate,
                clientOf(i.clientId),
                projectOf(i.projectId),
                i.extra
                    ? 'Extra work'.td
                    : repo.quotation(i.quotationId)?.number ?? '',
                i.title,
                paymentStateLabel(repo.paymentState(i), docLang),
                _c(i.net),
                _c(i.vat),
                _c(i.total),
                issued ? _c(repo.paidOn(i)) : null,
                issued ? _c(repo.balanceOf(i)) : null,
              ];
            }(),
        ],
      ),
    if (receipts.isNotEmpty)
      XlsxSheet(
        'Receipts'.td,
        rtl: rtl,
        title: title('Receipts'.td),
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Number'.td, XlsxType.text, width: 16),
          XlsxColumn('Date'.td, XlsxType.date),
          XlsxColumn('Client'.td, XlsxType.text),
          XlsxColumn('Project'.td, XlsxType.text, width: 14),
          XlsxColumn('For'.td, XlsxType.text, width: 34),
          XlsxColumn('Method'.td, XlsxType.text, width: 14),
          XlsxColumn('Reference'.td, XlsxType.text, width: 16),
          XlsxColumn('Amount'.td, XlsxType.money),
          if (s.projectId != null)
            XlsxColumn('For this project'.td, XlsxType.money),
        ],
        rows: [
          for (final p in receipts)
            [
              p.number,
              p.date,
              clientOf(repo.payerOf(p)),
              projectOf(repo.projectOfPayment(p)),
              receiptPurpose(repo, p, docLang),
              paymentMethodLabel(p.method, docLang),
              p.reference,
              _c(p.amount),
              if (s.projectId != null) _c(repo.receivedFor(p, s.projectId)),
            ],
        ],
      ),
    if (expenses.isNotEmpty)
      XlsxSheet(
        'Expenses'.td,
        rtl: rtl,
        title: '${title('Expenses'.td)} · ${'AK internal'.td}',
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Number'.td, XlsxType.text, width: 14),
          XlsxColumn('Date'.td, XlsxType.date),
          XlsxColumn('Project'.td, XlsxType.text, width: 14),
          XlsxColumn('Work'.td, XlsxType.text, width: 22),
          XlsxColumn('Supplier'.td, XlsxType.text),
          XlsxColumn('Category'.td, XlsxType.text, width: 20),
          XlsxColumn('Description'.td, XlsxType.text, width: 30),
          XlsxColumn('Supplier ref.'.td, XlsxType.text, width: 14),
          XlsxColumn('Without VAT'.td, XlsxType.money),
          XlsxColumn('VAT'.td, XlsxType.money),
          XlsxColumn('Total'.td, XlsxType.money),
          XlsxColumn('Paid'.td, XlsxType.text, width: 10),
          XlsxColumn('Files'.td, XlsxType.number),
        ],
        rows: [
          for (final e in expenses)
            [
              e.number,
              e.date,
              projectOf(e.projectId),
              workLabel(repo, e, docLang),
              e.vendor,
              expenseCategoryLabel(e.category, docLang),
              e.title,
              e.reference,
              _c(e.net),
              _c(e.vat),
              _c(e.amount),
              e.paid ? 'Yes'.td : 'No'.td,
              repo.attachmentsOf(e.id).length,
            ],
        ],
      ),
  ];
  if (expenses.isNotEmpty) {
    final report = CostReport(
      repo,
      expenses,
      projectId: s.projectId,
      from: s.from,
      to: s.to,
    );
    sheets.add(
      XlsxSheet(
        'Profit by work'.td,
        rtl: rtl,
        title: '${title('Profit by work'.td)} · ${'AK internal'.td}',
        totalsLabel: 'Total'.td,
        columns: [
          XlsxColumn('Project'.td, XlsxType.text, width: 14),
          XlsxColumn('Work'.td, XlsxType.text, width: 34),
          XlsxColumn('Invoiced, without VAT'.td, XlsxType.money, width: 18),
          XlsxColumn('Received'.td, XlsxType.money),
          XlsxColumn('Expenses, without VAT'.td, XlsxType.money, width: 18),
          XlsxColumn('Profit'.td, XlsxType.money),
          XlsxColumn('Margin %'.td, XlsxType.number, width: 10),
        ],
        rows: [
          for (final w in report.works)
            [
              projectOf(w.projectId),
              w.label(docLang),
              _c(w.revenue),
              _c(w.received + w.held),
              _c(w.cost),
              _c(w.profit),
              w.margin?.round(),
            ],
          if (report.revenueOutside.abs() >= .005 ||
              report.receivedOutside.abs() >= .005)
            [
              '',
              'Outside projects'.td,
              _c(report.revenueOutside),
              _c(report.receivedOutside),
              0.0,
              _c(report.revenueOutside),
              null,
            ],
          if (report.outside.isNotEmpty)
            [
              '',
              'Company overheads'.td,
              0.0,
              0.0,
              _c(report.overheads),
              _c(-report.overheads),
              null,
            ],
        ],
      ),
    );
  }
  return buildXlsx(
    sheets.isEmpty
        ? [
            XlsxSheet(
              'Export'.td,
              rtl: rtl,
              title: title('Export'.td),
              columns: const [],
              rows: const [],
            ),
          ]
        : sheets,
    title: title('Export'.td),
    author: repo.companyName,
    created: repo.now(),
  );
}

/// Money to the cent.
double _c(double v) => (v * 100).round() / 100;
