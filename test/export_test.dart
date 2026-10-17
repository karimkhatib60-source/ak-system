import 'dart:convert';
import 'dart:typed_data';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/xlsx.dart';
import 'package:ak_system/ui/export.dart';
import 'package:ak_system/ui/pdf_docs.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Exporting chosen money documents of a project.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Repository repo;
  late DateTime t;

  setUp(() async {
    docLang = AppLang.en;
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 17, 9)));
    t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya Haddad'),
    );
    for (final id in ['p', 'p2']) {
      await repo.saveProject(
        Project(
          id: id,
          createdAt: t,
          updatedAt: t,
          code: id == 'p' ? 'AK-26-001' : 'AK-26-002',
          name: 'Villa $id',
          clientId: 'c',
        ),
      );
    }
    await repo.saveQuotation(
      Quotation(
        id: 'q',
        createdAt: t,
        updatedAt: t,
        number: 'QT-26-001',
        title: 'Villa works',
        clientId: 'c',
        projectId: 'p',
        date: DateTime(2026, 9, 1),
        status: QuotationStatus.accepted,
        vatRate: 11,
        items: const [LineItem(description: 'Works', rate: 10000)],
      ),
    );
    await repo.saveQuotation(
      Quotation(
        id: 'qd',
        createdAt: t,
        updatedAt: t,
        number: 'QT-26-002',
        title: 'Draft idea',
        clientId: 'c',
        projectId: 'p',
        date: DateTime(2026, 9, 3),
        items: const [LineItem(description: 'Idea', rate: 500)],
      ),
    );
    Invoice inv(String id, int day, InvoiceStatus s, String project) => Invoice(
      id: id,
      createdAt: t,
      updatedAt: t,
      number: 'INV-$id',
      title: 'Invoice $id',
      clientId: 'c',
      projectId: project,
      quotationId: project == 'p' ? 'q' : null,
      date: DateTime(2026, 10, day),
      status: s,
      vatRate: 11,
      items: const [LineItem(description: 'Works', rate: 1000)],
    );
    await repo.saveInvoice(inv('i1', 2, InvoiceStatus.sent, 'p'));
    await repo.saveInvoice(inv('i2', 9, InvoiceStatus.sent, 'p'));
    await repo.saveInvoice(inv('i3', 12, InvoiceStatus.draft, 'p'));
    await repo.saveInvoice(inv('i4', 13, InvoiceStatus.cancelled, 'p'));
    await repo.saveInvoice(inv('other', 5, InvoiceStatus.sent, 'p2'));
    await repo.savePayment(
      Payment(
        id: 'r',
        createdAt: t,
        updatedAt: t,
        invoiceId: 'i1',
        date: DateTime(2026, 10, 4),
        amount: 1110,
      ),
    );
    await repo.saveExpense(
      Expense(
        id: 'e',
        createdAt: t,
        updatedAt: t,
        projectId: 'p',
        quotationId: 'q',
        date: DateTime(2026, 10, 6),
        vendor: 'Stone & Co',
        title: 'Sandstone',
        vatRate: 11,
        amount: 555,
      ),
    );
  });

  test('a project\'s documents, by date, within a period', () {
    final s = ExportSource(repo, projectId: 'p');
    expect(s.quotations.map((q) => q.id), ['q', 'qd']);
    expect(s.invoices.map((i) => i.id), ['i1', 'i2', 'i3', 'i4']);
    expect(s.receipts.map((p) => p.id), ['r']);
    expect(s.expenses.map((e) => e.id), ['e']);
    expect(s.hasStatement, isTrue);
    final oct = ExportSource(
      repo,
      projectId: 'p',
      from: DateTime(2026, 10, 2, 18),
      to: DateTime(2026, 10, 9),
    );
    // Whole days: the 2nd and the 9th are in.
    expect(oct.invoices.map((i) => i.id), ['i1', 'i2']);
    expect(oct.quotations, isEmpty);
    expect(ExportSource(repo).invoices, hasLength(5));
    expect(ExportSource(repo).hasStatement, isFalse);
  });

  test('chosen first: what the client has seen, no internal costs', () {
    final c = ExportChoice.client(ExportSource(repo, projectId: 'p'));
    expect(c.quotations, {'q'});
    expect(c.invoices, {'i1', 'i2'});
    expect(c.receipts, {'r'});
    expect(c.expenses, isEmpty);
    expect(c.statement, isTrue);
    expect(c.count, 5);
    expect(c.hasInternal, isFalse);
  });

  Map<String, String> unzip(List<int> bytes) => {
    for (final f in ZipDecoder().decodeBytes(bytes))
      if (f.isFile)
        f.name: f.name.endsWith('.xml') ? utf8.decode(f.content) : '',
  };

  test(
    'Excel lists the chosen documents with real numbers and totals',
    () async {
      final s = ExportSource(repo, projectId: 'p');
      final c = ExportChoice.client(s)..expenses.add('e');
      final file = await buildExport(s, c, ExportFormat.excel);
      expect(file.name, 'Export-AK-26-001-2026-10-17.xlsx');
      final parts = unzip(file.bytes);
      final book = parts['xl/workbook.xml']!;
      for (final name in [
        'Project statement',
        'Quotations',
        'Invoices',
        'Receipts',
        'Expenses',
        'Profit by work',
      ]) {
        expect(book, contains('name="$name"'));
      }
      final invoices = parts['xl/worksheets/sheet3.xml']!;
      expect(invoices, contains('INV-i1'));
      expect(invoices, isNot(contains('INV-i3'))); // draft not chosen
      expect(invoices, contains('<v>1110</v>')); // total, a number
      expect(invoices, contains('SUBTOTAL(109,'));
      expect(invoices, contains('<autoFilter'));
      final expenses = parts['xl/worksheets/sheet5.xml']!;
      expect(expenses, contains('Stone &amp; Co'));
      expect(expenses, contains('QT-26-001 · Villa works'));
    },
  );

  test(
    'a ZIP holds one PDF per document, the register and the report',
    () async {
      final s = ExportSource(repo, projectId: 'p');
      final c = ExportChoice.client(s)
        ..expenses.add('e')
        ..billFiles = true;
      final file = await buildExport(s, c, ExportFormat.zip);
      final names = ZipDecoder()
          .decodeBytes(file.bytes)
          .where((f) => f.isFile)
          .map((f) => f.name)
          .toList();
      const base = 'Export-AK-26-001-2026-10-17';
      expect(
        names,
        containsAll([
          '$base/Quotations/QT-26-001-Villa-works.pdf',
          '$base/Invoices/INV-i1-Invoice-i1.pdf',
          '$base/Invoices/INV-i2-Invoice-i2.pdf',
          '$base/Receipts/${repo.payments.single.number}-Maya-Haddad.pdf',
          '$base/AK-internal/Cost-and-profit-report.pdf',
          '$base/Register.xlsx',
        ]),
      );
      expect(names.where((n) => n.contains('/Statement/')), hasLength(1));
      for (final f in ZipDecoder().decodeBytes(file.bytes)) {
        if (f.name.endsWith('.pdf')) {
          expect(latin1.decode(f.content.sublist(0, 5)), '%PDF-');
        }
      }
      // Exporting a receipt gives it its number, as printing it does.
      expect(repo.payments.single.number, isNotEmpty);
    },
  );

  test('one PDF holds every chosen document, page after page', () async {
    final s = ExportSource(repo, projectId: 'p');
    final c = ExportChoice(invoices: {'i1', 'i2'}, receipts: {'r'});
    final file = await buildExport(s, c, ExportFormat.pdf);
    expect(file.name, endsWith('.pdf'));
    final text = latin1.decode(file.bytes);
    expect(text.startsWith('%PDF-'), isTrue);
    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 3);
  });

  test('a supplier file not on this device is left out and counted, '
      'the rest is saved', () async {
    Attachment file(String id, String name) => Attachment(
      id: id,
      createdAt: t,
      updatedAt: t,
      ownerId: 'e',
      name: name,
      mime: 'application/pdf',
      size: 3,
    );
    final bytes = Uint8List.fromList([1, 2, 3]);
    await repo.saveExpense(
      repo.expenses.single,
      attach: [
        (file('here', 'bill.pdf'), bytes),
        (file('away', 'photo.'), bytes),
        (file('cloud', 'scan.pdf'), bytes),
      ],
    );
    // Two files never reached this device; the cloud is out of reach.
    await repo.files.remove('away');
    await repo.files.remove('cloud');
    repo.downloadFile = (a) async =>
        a.id == 'cloud' ? throw Exception('offline') : null;
    final s = ExportSource(repo, projectId: 'p');
    final file2 = await buildExport(
      s,
      ExportChoice(expenses: {'e'}, billFiles: true),
      ExportFormat.zip,
    );
    expect(file2.missing, 2);
    final names = ZipDecoder()
        .decodeBytes(file2.bytes)
        .where((f) => f.isFile)
        .map((f) => f.name.split('/').skip(1).join('/'))
        .toList();
    expect(names, contains('AK-internal/Supplier-files/EXP-26-001-bill.pdf'));
    expect(names.where((n) => n.contains('Supplier-files')), hasLength(1));

    // Once there, a file named without an extension is saved as .bin.
    await repo.files.put('away', bytes);
    final again = await buildExport(
      s,
      ExportChoice(expenses: {'e'}, billFiles: true),
      ExportFormat.zip,
    );
    expect(again.missing, 1);
    expect(
      ZipDecoder().decodeBytes(again.bytes).map((f) => f.name),
      contains(endsWith('Supplier-files/EXP-26-001-photo.bin')),
    );
  });

  test('supplier file names stay valid for Windows', () async {
    Attachment file(String id, String name) => Attachment(
      id: id,
      createdAt: t,
      updatedAt: t,
      ownerId: 'e',
      name: name,
      mime: 'application/pdf',
      size: 1,
    );
    final bytes = Uint8List.fromList([1]);
    await repo.saveExpense(
      repo.expenses.single,
      attach: [
        (file('a', 'scan. '), bytes),
        (file('b', 'scan.***'), bytes),
        (file('c', '${'x' * 250}.pdf'), bytes),
        (file('d', 'photo.jpeg-copy-of-long'), bytes),
      ],
    );
    final zip = await buildExport(
      ExportSource(repo, projectId: 'p'),
      ExportChoice(expenses: {'e'}, billFiles: true),
      ExportFormat.zip,
    );
    final names = [
      for (final f in ZipDecoder().decodeBytes(zip.bytes))
        if (f.name.contains('Supplier-files/')) f.name.split('/').last,
    ];
    expect(names, hasLength(4));
    for (final n in names) {
      expect(n, isNot(endsWith('.')));
      expect(n.length, lessThan(120));
    }
    expect(
      names,
      containsAll(['EXP-26-001-scan.bin', 'EXP-26-001-scan-2.bin']),
    );
    expect(names.where((n) => n.endsWith('.pdf')), hasLength(1));
  });

  test('a year of expenses fits in the cost report', () async {
    for (var k = 0; k < 700; k++) {
      await repo.saveExpense(
        Expense(
          id: 'm$k',
          createdAt: t,
          updatedAt: t,
          projectId: 'p',
          quotationId: 'q',
          date: DateTime(2026, 1 + k % 9, 1 + k % 28),
          vendor: 'Supplier $k',
          title: 'Materials',
          amount: 100,
        ),
      );
    }
    final s = ExportSource(repo, projectId: 'p');
    final file = await buildExport(
      s,
      ExportChoice(expenses: {for (final e in s.expenses) e.id}),
      ExportFormat.pdf,
    );
    final pages = RegExp(r'/Type\s*/Page[^s]')
        .allMatches(latin1.decode(file.bytes))
        .length;
    expect(pages, greaterThan(20));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('Excel carries the project statement when it is chosen', () async {
    final s = ExportSource(repo, projectId: 'p');
    final file = await buildExport(
      s,
      ExportChoice(statement: true),
      ExportFormat.excel,
    );
    final parts = unzip(file.bytes);
    expect(parts['xl/workbook.xml'], contains('name="Project statement"'));
    final sheet = parts['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('INV-i1'));
    expect(sheet, contains('<v>1110</v>'));
    // Debit and credit add up; the running balance does not.
    expect(sheet, contains('SUBTOTAL(109,D'));
    expect(sheet, contains('SUBTOTAL(109,E'));
    expect(sheet, isNot(contains('SUBTOTAL(109,F')));
  });

  test('file names drop what Windows refuses', () {
    expect(fileSafe('INV-3 Bad \u0001 <x>: "q"?'), 'INV-3-Bad-x-q');
    expect(fileSafe('Maya\u007f & Co\t'), 'Maya-&-Co');
  });

  test('the Excel helpers name columns, dates and sheets as Excel does', () {
    expect(xlsxColumn(0), 'A');
    expect(xlsxColumn(25), 'Z');
    expect(xlsxColumn(26), 'AA');
    expect(xlsxColumn(27), 'AB');
    expect(xlsxDate(DateTime(1900, 3, 1)), 61);
    expect(xlsxDate(DateTime(2026, 10, 17, 23, 59)), 46312);
    final book = buildXlsx([
      XlsxSheet(
        'Bad:/name*[x]?',
        columns: const [XlsxColumn('A', XlsxType.text)],
        rows: const [
          ['x'],
        ],
      ),
      XlsxSheet(
        'Bad:/name*[x]?',
        rtl: true,
        columns: const [XlsxColumn('A', XlsxType.text)],
        rows: const [],
      ),
    ]);
    final parts = unzip(book);
    expect(parts['xl/workbook.xml'], contains('name="Bad  name  x"'));
    expect(parts['xl/workbook.xml'], contains('name="Bad  name  x (2)"'));
    expect(parts['xl/worksheets/sheet2.xml'], contains('rightToLeft="1"'));
  });
}
