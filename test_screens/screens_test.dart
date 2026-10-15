// Renders preview screenshots with real fonts:
//   flutter test test_screens --update-goldens
import 'dart:io';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
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
      'phone': '+961 3 000 000',
      'email': 'info@ak-dac.com',
      'bank': 'Bank name · IBAN LB00 0000 0000 0000 0000 0000 0000',
    });
    await tester.runAsync(() async {
      File('test_screens/out/sample_quotation.pdf')
          .writeAsBytesSync(await buildPdf(repo, repo.quotation('q1')!));
      File('test_screens/out/sample_invoice.pdf')
          .writeAsBytesSync(await buildPdf(repo, repo.invoice('i1')!));
    });
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
