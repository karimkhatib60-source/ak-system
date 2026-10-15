// Renders preview screenshots with real fonts:
//   flutter test test_screens --update-goldens
import 'dart:io';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/project_statement.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/statement.dart';
import 'package:ak_system/main.dart';
import 'package:ak_system/ui/app_shell.dart';
import 'package:ak_system/ui/pdf_docs.dart';
import 'package:provider/provider.dart';
import 'package:ak_system/sync/cloud_account.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      Future.value(
        ByteData.sublistView(File('$dir/Roboto-$f.ttf').readAsBytesSync()),
      ),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$dir/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Manrope-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await manrope.load();
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final clock = TestClock(DateTime(2026, 10, 14, 9));
    final repo = (await tester.runAsync(() async {
      final r = await memoryRepo(clock);
      final t = r.now();
      final s = r.stagesFor(ServiceType.design);
      final cs = r.stagesFor(ServiceType.consultancy);
      final ks = r.stagesFor(ServiceType.contracting);
      Future<void> client(String id, String name, String country) =>
          r.saveClient(
            Client(
              id: id,
              createdAt: t,
              updatedAt: t,
              name: name,
              country: country,
            ),
          );
      await client('c1', 'Nadim Haddad', 'Lebanon');
      await client('c2', 'Al Rayyan Holding', 'Qatar');
      await client('c3', 'Maya Khoury', 'Lebanon');
      await r.saveProject(
        Project(
          id: 'p1',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-001',
          name: 'Villa Byblos',
          clientId: 'c1',
          stageId: s[3].id,
          location: 'Byblos',
          areaSqm: 450,
          mapLink: 'https://maps.app.goo.gl/example',
          dueDate: DateTime(2026, 12, 20),
        ),
      );
      await r.saveProject(
        Project(
          id: 'p2',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-002',
          name: 'Doha office tower review',
          clientId: 'c2',
          service: ServiceType.consultancy,
          abroad: true,
          stageId: cs[3].id,
          location: 'Doha',
        ),
      );
      await r.saveProject(
        Project(
          id: 'p3',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-003',
          name: 'Apartment fit-out, Achrafieh',
          clientId: 'c3',
          service: ServiceType.contracting,
          stageId: ks[6].id,
          areaSqm: 180,
          markupRate: 15,
          location: 'Beirut',
          dueDate: DateTime(2026, 11, 5),
        ),
      );
      Future<void> task(
        String id,
        String p,
        String title,
        DateTime? due, [
        TaskPriority pr = TaskPriority.normal,
      ]) => r.saveTask(
        Task(
          id: id,
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: title,
          dueDate: due,
          priority: pr,
        ),
      );
      await task(
        't1',
        'p1',
        'Update facade elevations',
        DateTime(2026, 10, 12),
        TaskPriority.high,
      );
      await task(
        't2',
        'p3',
        'Site visit: tiling check',
        DateTime(2026, 10, 15),
      );
      await task(
        't3',
        'p2',
        'Comments on structural report',
        DateTime(2026, 10, 17),
      );
      await task('t4', 'p1', 'Kitchen layout options', DateTime(2026, 10, 20));
      Future<void> del(
        String id,
        String p,
        String title,
        DeliverableStatus st,
        int v,
        int stage,
      ) => r.saveDeliverable(
        Deliverable(
          id: id,
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: title,
          status: st,
          version: v,
          stageId: s[stage].id,
          submittedAt: st == DeliverableStatus.submitted
              ? DateTime(2026, 10, 9)
              : null,
          dueDate: DateTime(2026, 10, 25),
        ),
      );
      await del(
        'd1',
        'p1',
        'Design development set',
        DeliverableStatus.submitted,
        2,
        3,
      );
      await del(
        'd2',
        'p2',
        'Review memo no. 3',
        DeliverableStatus.revise,
        1,
        2,
      );
      await del(
        'd3',
        'p3',
        'Joinery shop drawings',
        DeliverableStatus.internalReview,
        1,
        7,
      );
      final q = Quotation(
        id: 'q1',
        createdAt: t,
        updatedAt: t,
        number: 'QT-26-001',
        title: 'Architectural design services, Villa Byblos',
        clientId: 'c1',
        projectId: 'p1',
        date: DateTime(2026, 9, 2),
        validUntil: DateTime(2026, 10, 2),
        status: QuotationStatus.accepted,
        paymentTerms: paymentTermPresets[ServiceType.design]!,
        items: const [
          LineItem(description: 'Concept design', rate: 4000),
          LineItem(description: 'Permit drawings', rate: 6000),
          LineItem(description: 'Construction drawings', rate: 9000),
          LineItem(
            description: 'Site supervision visits',
            quantity: 10,
            unit: 'visit',
            rate: 150,
          ),
        ],
      );
      await r.saveQuotation(q);
      final inv = r.invoiceFromQuotation(q);
      await r.saveInvoice(
        Invoice(
          id: 'i1',
          createdAt: t,
          updatedAt: t,
          number: 'INV-26-001',
          title: 'Advance payment 30%',
          clientId: 'c1',
          projectId: 'p1',
          quotationId: 'q1',
          termIndex: 0,
          date: DateTime(2026, 9, 5),
          dueDate: DateTime(2026, 9, 19),
          status: InvoiceStatus.sent,
          items: [
            LineItem(
              description: '30% advance on ${q.number}',
              rate: q.net * .3,
            ),
          ],
          vatRate: inv.vatRate,
        ),
      );
      await r.savePayment(
        Payment(
          id: 'pay1',
          createdAt: t,
          updatedAt: t,
          invoiceId: 'i1',
          date: DateTime(2026, 9, 12),
          amount: 4000,
        ),
      );
      await r.saveInvoice(
        Invoice(
          id: 'i2',
          createdAt: t,
          updatedAt: t,
          number: 'INV-26-002',
          title: 'Review memos 1-3',
          clientId: 'c2',
          projectId: 'p2',
          date: DateTime(2026, 10, 1),
          dueDate: DateTime(2026, 10, 15),
          status: InvoiceStatus.sent,
          vatRate: 0,
          items: const [
            LineItem(
              description: 'Design review',
              quantity: 3,
              unit: 'memo',
              rate: 1800,
            ),
          ],
        ),
      );
      LineItem li(String s, String d, String u, double q, double r) =>
          LineItem(section: s, description: d, unit: u, quantity: q, rate: r);
      await r.saveQuotation(
        Quotation(
          id: 'q2',
          createdAt: t,
          updatedAt: t,
          number: 'QT-26-002',
          title: 'Fit-out works, apartment Achrafieh',
          clientId: 'c3',
          projectId: 'p3',
          date: DateTime(2026, 10, 10),
          validUntil: DateTime(2026, 11, 10),
          status: QuotationStatus.accepted,
          markupRate: 15,
          terms: r.companyInfo['terms'] ?? '',
          items: [
            li(
              'Demolition and removal',
              'Removal of existing floor tiles and screed down to slab',
              'm²',
              150,
              4,
            ),
            li(
              'Demolition and removal',
              'Demolition of existing block walls including removal of debris',
              'm²',
              36,
              9,
            ),
            li(
              'Demolition and removal',
              'Debris removal and disposal to an approved dump site',
              'trip',
              6,
              90,
            ),
            li(
              'Masonry',
              'Concrete block wall, 10 cm thick, in cement mortar',
              'm²',
              48,
              14,
            ),
            li(
              'Masonry',
              'Internal cement plaster, two coats, 2 cm, on walls',
              'm²',
              96,
              9,
            ),
            li(
              'Screeds and flooring',
              'Cement screed 5 cm for floor finishes',
              'm²',
              150,
              7,
            ),
            li(
              'Screeds and flooring',
              'Porcelain floor tiles 60x60 cm, supply and installation, with grout',
              'm²',
              150,
              32,
            ),
            li(
              'Screeds and flooring',
              'Porcelain wall tiles for bathrooms and kitchen, full height',
              'm²',
              70,
              30,
            ),
            li(
              'Gypsum board and ceilings',
              'Gypsum board false ceiling on galvanized steel frame, painted',
              'm²',
              120,
              22,
            ),
            li(
              'Gypsum board and ceilings',
              'Gypsum cornice / light cove with concealed LED profile',
              'lin. m',
              45,
              18,
            ),
            li(
              'Painting',
              'Internal walls: sealer, two coats putty, primer and two coats emulsion paint',
              'm²',
              420,
              6.5,
            ),
            li(
              'Electrical works',
              'Lighting point including conduit, wiring and switch',
              'point',
              38,
              35,
            ),
            li(
              'Electrical works',
              'Power socket 13 A including conduit and wiring',
              'point',
              44,
              32,
            ),
            li(
              'Plumbing and drainage',
              'Water supply network (hot and cold), PPR pipes, per wet point',
              'point',
              14,
              85,
            ),
            li(
              'Plumbing and drainage',
              'Wall-hung WC with concealed cistern and flush plate',
              'no.',
              2,
              420,
            ),
          ],
        ),
      );
      for (final (id, n, d, pct, stage) in [
        ('i3', 'INV-26-003', DateTime(2026, 8, 20), .4, 3),
        ('i4', 'INV-26-004', DateTime(2026, 9, 25), .3, 6),
      ]) {
        final q2 = r.quotation('q2')!;
        final draft = r.progressInvoice(q2, pct * 100);
        await r.saveInvoice(
          Invoice(
            id: id,
            createdAt: t,
            updatedAt: t,
            number: n,
            title: 'Progress payment ${(pct * 100).round()}%',
            stageId: ks[stage].id,
            markupRate: q2.markupRate,
            discount: draft.discount,
            clientId: 'c3',
            projectId: 'p3',
            quotationId: 'q2',
            date: d,
            dueDate: d.add(const Duration(days: 14)),
            status: InvoiceStatus.sent,
            items: draft.items,
          ),
        );
      }
      final ksTasks = [
        ('k1', 'Strip floor tiles and screed', 3, TaskStatus.done),
        ('k2', 'Build new partitions', 4, TaskStatus.done),
        ('k3', 'Electrical first fix', 5, TaskStatus.done),
        ('k4', 'Plumbing first fix', 5, TaskStatus.done),
        ('k5', 'Lay porcelain flooring', 6, TaskStatus.inProgress),
        ('k6', 'Gypsum ceilings and light coves', 6, TaskStatus.todo),
        ('k7', 'Painting, final coats', 6, TaskStatus.todo),
      ];
      for (final (id, title, stage, status) in ksTasks) {
        await r.saveTask(
          Task(
            id: id,
            createdAt: t,
            updatedAt: t,
            projectId: 'p3',
            title: title,
            stageId: ks[stage].id,
            status: status,
          ),
        );
      }
      await r.savePayment(
        Payment(
          id: 'pay2',
          createdAt: t,
          updatedAt: t,
          invoiceId: 'i3',
          date: DateTime(2026, 8, 28),
          amount: 8000,
          reference: 'TRF 2291',
        ),
      );
      await r.savePayment(
        Payment(
          id: 'pay3',
          createdAt: t,
          updatedAt: t,
          invoiceId: 'i3',
          date: DateTime(2026, 9, 15),
          amount: 3181.12,
          method: PaymentMethod.cash,
        ),
      );
      await r.savePayment(
        Payment(
          id: 'pay4',
          createdAt: t,
          updatedAt: t,
          invoiceId: 'i4',
          date: DateTime(2026, 10, 8),
          amount: 5000,
          method: PaymentMethod.cheque,
          reference: 'CHQ 104455',
        ),
      );
      // Money on a payment term before it is invoiced, and a deposit.
      await r.savePayment(
        Payment(
          id: 'pay5',
          createdAt: t,
          updatedAt: t,
          clientId: 'c1',
          projectId: 'p1',
          quotationId: 'q1',
          termIndex: 1,
          date: DateTime(2026, 10, 10),
          amount: 3000,
          reference: 'TRF 88120',
        ),
      );
      await r.savePayment(
        Payment(
          id: 'pay6',
          createdAt: t,
          updatedAt: t,
          clientId: 'c2',
          projectId: 'p2',
          date: DateTime(2026, 9, 20),
          amount: 7000,
          notes: 'Advance on account for the review',
        ),
      );
      Future<void> exp(
        String id,
        String? p,
        ExpenseCategory c,
        double a,
        String v,
      ) => r.saveExpense(
        Expense(
          id: id,
          createdAt: t,
          updatedAt: t,
          projectId: p,
          date: DateTime(2026, 10, 3),
          category: c,
          amount: a,
          vendor: v,
        ),
      );
      await exp('e1', 'p1', ExpenseCategory.printing, 120, 'Print House Jbeil');
      await exp('e2', null, ExpenseCategory.software, 290, 'AutoCAD licence');
      await exp('e3', 'p3', ExpenseCategory.subcontractor, 2400, 'Tiling team');
      // A supplier's bill entered line by line, with VAT and the bill kept.
      await r.saveExpense(
        Expense(
          id: 'e4',
          createdAt: t,
          updatedAt: t,
          projectId: 'p3',
          date: DateTime(2026, 10, 6),
          category: ExpenseCategory.materials,
          title: 'Porcelain tiles, kitchen and bathrooms',
          vendor: 'Ceramica Lebanon',
          reference: 'CL-2291',
          vatRate: 11,
          items: const [
            LineItem(
              description: 'Porcelain tiles 60x60, matt grey',
              unit: 'm²',
              quantity: 320,
              rate: 22,
            ),
            LineItem(
              description: 'Tile adhesive C2TE',
              unit: 'bag',
              quantity: 180,
              rate: 6.5,
            ),
            LineItem(
              description: 'Epoxy grout',
              unit: 'kg',
              quantity: 120,
              rate: 3.5,
            ),
            LineItem(description: 'Delivery to site', unit: 'trip', rate: 150),
          ],
          amount: Expense.totalOf(const [
            LineItem(quantity: 320, rate: 22),
            LineItem(quantity: 180, rate: 6.5),
            LineItem(quantity: 120, rate: 3.5),
            LineItem(rate: 150),
          ], 11),
          method: PaymentMethod.bankTransfer,
        ),
        attach: [
          (
            Attachment(
              id: 'a1',
              createdAt: t,
              updatedAt: t,
              ownerId: 'e4',
              name: 'Ceramica CL-2291.pdf',
              mime: 'application/pdf',
              size: 184320,
            ),
            Uint8List.fromList('%PDF-1.4'.codeUnits),
          ),
        ],
      );
      await r.saveExpense(
        Expense(
          id: 'e5',
          createdAt: t,
          updatedAt: t,
          projectId: 'p3',
          date: DateTime(2026, 10, 9),
          category: ExpenseCategory.subcontractor,
          title: 'Electrical works, first fix',
          vendor: 'Electrician',
          amount: 3100,
          paid: false,
        ),
      );
      return r;
    }))!;
    final sync = SyncService(repo.local, repo);
    await tester.pumpWidget(
      AkApp(
        repo: repo,
        sync: sync,
        cloud: CloudAccount(repo.local, repo, sync),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone overview', (tester) async {
    await pump(tester, const Size(400, 860));
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_overview.png'),
    );
  });

  testWidgets('phone project', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_projects.png'),
    );
    await tester.tap(find.text('Villa Byblos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_detail.png'),
    );
  });

  testWidgets('phone lists', (tester) async {
    await pump(tester, const Size(360, 740));
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_tasks.png'),
    );
    await tester.tap(find.text('Deliverables'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_deliverables.png'),
    );
  });

  testWidgets('phone finance', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_finance.png'),
    );
    await tester.tap(find.text('Advance payment 30%'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_invoice.png'),
    );
  });

  testWidgets('sample PDFs', (tester) async {
    await pump(tester, const Size(400, 860));
    final repo = tester.element(find.byType(AppShell)).read<Repository>();
    await repo.setCompanyInfo({
      'bank': 'Bank name · IBAN LB00 0000 0000 0000 0000 0000 0000',
    });
    await tester.runAsync(() async {
      File('test_screens/out/sample_quotation.pdf')
          .writeAsBytesSync(await buildPdf(repo, repo.quotation('q1')!));
      File('test_screens/out/sample_invoice.pdf')
          .writeAsBytesSync(await buildPdf(repo, repo.invoice('i1')!));
      final boq = repo.quotation('q2')!;
      File('test_screens/out/sample_boq.pdf')
          .writeAsBytesSync(await buildPdf(repo, boq));
      File(
        'test_screens/out/sample_boq_fee_in_rates.pdf',
      ).writeAsBytesSync(await buildPdf(repo, boq.copyWith(showMarkup: false)));
      File('test_screens/out/sample_receipt.pdf').writeAsBytesSync(
        await buildReceiptPdf(
          repo,
          repo.payments.firstWhere((p) => p.id == 'pay2'),
        ),
      );
      File('test_screens/out/sample_receipt_term.pdf').writeAsBytesSync(
        await buildReceiptPdf(
          repo,
          repo.payments.firstWhere((p) => p.id == 'pay5'),
        ),
      );
      File('test_screens/out/sample_receipt_on_account.pdf').writeAsBytesSync(
        await buildReceiptPdf(
          repo,
          repo.payments.firstWhere((p) => p.id == 'pay6'),
        ),
      );
      File(
        'test_screens/out/sample_project_statement_design.pdf',
      ).writeAsBytesSync(
        await buildProjectStatementPdf(repo, buildProjectStatement(repo, 'p1')),
      );
      File('test_screens/out/sample_project_statement.pdf').writeAsBytesSync(
        await buildProjectStatementPdf(repo, buildProjectStatement(repo, 'p3')),
      );
      File('test_screens/out/sample_statement_advance.pdf').writeAsBytesSync(
        await buildStatementPdf(repo, buildStatement(repo, 'c1')),
      );
      File('test_screens/out/sample_statement.pdf').writeAsBytesSync(
        await buildStatementPdf(repo, buildStatement(repo, 'c3')),
      );
    });
  });

  testWidgets('phone receipts', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Receipts'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -330));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_receipts.png'),
    );
    await tester.tap(find.textContaining('Concept and schematic design'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_receipt_sheet.png'),
    );
  });

  testWidgets('phone project profit', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Profit').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profit').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -330));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_profit_by_project.png'),
    );
    await tester.tap(find.textContaining('AK-26-003 · Apartment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_account.png'),
    );
    await tester.tap(find.text('AK internal'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -60));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_profit.png'),
    );
    await tester.dragUntilVisible(
      find.text('Porcelain tiles, kitchen and bathrooms'),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_expenses.png'),
    );
    await tester.tap(find.text('Porcelain tiles, kitchen and bathrooms'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_expense_form.png'),
    );
    await tester.dragUntilVisible(
      find.text('Total of the bill'),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await tester.runAsync(
      () => Scrollable.ensureVisible(
        tester.element(find.text('Epoxy grout')),
        alignment: 0.05,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_expense_items.png'),
    );
    await tester.dragUntilVisible(
      find.text('Ceramica CL-2291.pdf'),
      find.byType(ListView).last,
      const Offset(0, -250),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_expense_payment.png'),
    );
  });

  testWidgets('phone payment terms', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quotes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Architectural design services, Villa Byblos'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('PAYMENT TERMS'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.runAsync(
      () => Scrollable.ensureVisible(
        tester.element(find.text('PAYMENT TERMS')),
        alignment: 0.02,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_payment_terms.png'),
    );
    await tester.tap(find.text('Receive').at(1));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_receipt_form.png'),
    );
  });

  testWidgets('phone payment terms editor', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quotes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fit-out works, apartment Achrafieh'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Standard'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.tap(find.text('Standard'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Contracting:'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Scrollable.ensureVisible(
        tester.element(find.text('PAYMENT TERMS')),
        alignment: 0.02,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_terms_editor.png'),
    );
  });

  testWidgets('phone BOQ quotation', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(4));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Quotes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fit-out works, apartment Achrafieh'));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('From BOQ library'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.drag(find.byType(ListView).last, const Offset(0, -250));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_boq_quote.png'),
    );
    await tester.tap(find.text('From BOQ library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masonry').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_boq_library.png'),
    );
  });

  testWidgets('phone client account', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maya Khoury'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_client_account.png'),
    );
    await tester.tap(find.text('Statement of account'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_statement_sheet.png'),
    );
  });

  testWidgets('phone company settings', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Upload logo'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.runAsync(
      () => Scrollable.ensureVisible(
        tester.element(find.text('Upload logo')),
        alignment: 0.25,
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_company_settings.png'),
    );
  });

  testWidgets('phone assistant', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byTooltip('To cover'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_assistant.png'),
    );
  });

  testWidgets('phone project form', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apartment fit-out, Achrafieh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit project'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -380));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_form.png'),
    );
  });

  testWidgets('laptop finance', (tester) async {
    await pump(tester, const Size(1366, 768));
    await tester.tap(find.text('Projects').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Villa Byblos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/laptop_project_finance.png'),
    );
  });

  testWidgets('laptop', (tester) async {
    await pump(tester, const Size(1366, 768));
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/laptop_overview.png'),
    );
    await tester.tap(find.text('Work').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deliverables').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design development set'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/laptop_deliverable.png'),
    );
  });
}
