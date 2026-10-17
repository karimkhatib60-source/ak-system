import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/ui/screens/expenses.dart';
import 'package:ak_system/ui/screens/export_screen.dart';
import 'package:ak_system/ui/screens/finance_screen.dart';
import 'package:ak_system/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// The export screen, the expense's contract and the contract cards.
void main() {
  late Repository repo;

  Future<void> setUpRepo(WidgetTester tester) async {
    repo = (await tester.runAsync(() async {
      final r = await memoryRepo(TestClock(DateTime(2026, 10, 17, 9)));
      final t = r.now();
      await r.saveClient(
        Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya Haddad'),
      );
      for (final id in ['p', 'p2']) {
        await r.saveProject(
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
      Quotation q(String id, String project, int day) => Quotation(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: 'QT-$id',
        title: 'Work $id',
        clientId: 'c',
        projectId: project,
        date: DateTime(2026, 9, day),
        status: QuotationStatus.accepted,
        vatRate: 11,
        items: const [LineItem(description: 'Works', rate: 10000)],
      );
      await r.saveQuotation(q('A', 'p', 1));
      await r.saveQuotation(q('B', 'p', 2));
      await r.saveQuotation(q('C', 'p2', 3));
      Invoice inv(String id, int day) => Invoice(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: 'INV-$id',
        title: 'Invoice $id',
        clientId: 'c',
        projectId: 'p',
        quotationId: 'A',
        date: DateTime(2026, 10, day),
        status: InvoiceStatus.sent,
        vatRate: 11,
        items: const [LineItem(description: 'Works', rate: 1000)],
      );
      await r.saveInvoice(inv('i1', 2));
      await r.saveInvoice(inv('i2', 9));
      await r.savePayment(
        Payment(
          id: 'r',
          createdAt: t,
          updatedAt: t,
          invoiceId: 'i1',
          date: DateTime(2026, 10, 4),
          amount: 1110,
        ),
      );
      await r.saveExpense(
        Expense(
          id: 'e',
          createdAt: t,
          updatedAt: t,
          projectId: 'p',
          quotationId: 'B',
          date: DateTime(2026, 10, 6),
          vendor: 'Stone and Co',
          title: 'Sandstone',
          vatRate: 11,
          amount: 555,
        ),
      );
      return r;
    }))!;
  }

  Future<void> show(
    WidgetTester tester,
    Widget Function(BuildContext) page, {
    Size size = const Size(800, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(builder: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openWith(
    WidgetTester tester,
    Future<void> Function(BuildContext) open,
  ) async {
    await show(
      tester,
      (context) => Scaffold(
        body: TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> pickDate(WidgetTester tester, String field, String typed) async {
    await tester.tap(find.text(field));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, typed);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  /// The "n of m chosen" line of a kind of document.
  String kindLine(WidgetTester tester, String kind) {
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text(kind), matching: find.byType(ListTile)).first,
    );
    return (tile.subtitle! as Text).data!;
  }

  bool ticked(WidgetTester tester, String title) => tester
      .widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(CheckboxListTile),
        ),
      )
      .value!;

  testWidgets('a document left out stays out when the period changes', (
    tester,
  ) async {
    await setUpRepo(tester);
    await openWith(
      tester,
      (context) => openExportScreen(context, projectId: 'p'),
    );
    // Statement, both contracts, both invoices and the receipt.
    expect(find.text('Export 6 documents'), findsOneWidget);
    await tester.tap(find.text('Invoices'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('INV-i2 · Invoice i2'));
    await tester.pumpAndSettle();
    expect(find.text('Export 5 documents'), findsOneWidget);

    // From 1 October: the September contracts leave the list, INV-i2
    // stays left out.
    await pickDate(tester, 'From', '10/01/2026');
    expect(ticked(tester, 'INV-i2 · Invoice i2'), isFalse);
    expect(ticked(tester, 'INV-i1 · Invoice i1'), isTrue);
    expect(find.text('Export 3 documents'), findsOneWidget);

    // Every date again: the contracts come back as they were chosen.
    await tester.tap(find.byTooltip('Clear date'));
    await tester.pumpAndSettle();
    expect(ticked(tester, 'INV-i2 · Invoice i2'), isFalse);
    expect(find.text('Export 5 documents'), findsOneWidget);
  });

  testWidgets('a kind cleared stays cleared, even through an empty period', (
    tester,
  ) async {
    await setUpRepo(tester);
    await openWith(
      tester,
      (context) => openExportScreen(
        context,
        projectId: 'p',
        from: DateTime(2026, 10, 7),
        internal: true,
      ),
    );
    // The expense of 6 October is outside; INV-i2 (9 October) is in.
    expect(kindLine(tester, 'Expenses'), 'None in this period');
    expect(kindLine(tester, 'Invoices'), '1 of 1 chosen');
    // Clear the invoices, then pass through an empty period.
    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Invoices'),
          matching: find.byType(ListTile),
        ),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    await pickDate(tester, 'To', '10/07/2026');
    await tester.tap(find.byTooltip('Clear date').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear date').first);
    await tester.pumpAndSettle();
    // Every date: INV-i1 is new but invoices were cleared; the expense is
    // new and expenses were wanted.
    expect(kindLine(tester, 'Invoices'), '0 of 2 chosen');
    expect(kindLine(tester, 'Expenses'), '1 of 1 chosen');
  });

  testWidgets('a document that arrives while choosing is left out until '
      'chosen', (tester) async {
    await setUpRepo(tester);
    await openWith(
      tester,
      (context) => openExportScreen(context, projectId: 'p'),
    );
    expect(kindLine(tester, 'Invoices'), '2 of 2 chosen');
    await tester.runAsync(
      () => repo.saveInvoice(
        Invoice.fromMap({
          ...repo.invoice('i2')!.toMap(),
          'id': 'i9',
          'number': 'INV-i9',
          'title': 'Again',
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(kindLine(tester, 'Invoices'), '2 of 3 chosen');
    await pickDate(tester, 'From', '09/15/2026');
    expect(kindLine(tester, 'Invoices'), '2 of 3 chosen');
  });

  testWidgets('expenses in an Excel list are flagged as internal', (
    tester,
  ) async {
    await setUpRepo(tester);
    await openWith(
      tester,
      (context) => openExportScreen(context, projectId: 'p', internal: true),
    );
    await tester.tap(find.text('Excel list'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'This Excel list includes the expenses and the profit by work. '
        'Keep it inside AK.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('picking the same project again keeps the expense\'s contract', (
    tester,
  ) async {
    await setUpRepo(tester);
    final e = repo.expenses.single;
    await openWith(tester, (context) => openExpenseForm(context, expense: e));
    expect(find.text('QT-B · Work B'), findsOneWidget);
    await tester.tap(find.text('AK-26-001 · Villa p'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AK-26-001 · Villa p').last);
    await tester.pumpAndSettle();
    expect(find.text('QT-B · Work B'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (
        var k = 0;
        k < 20 && repo.expenses.single.updatedAt == e.updatedAt;
        k++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();
    expect(repo.expenses.single.quotationId, 'B');
  });

  testWidgets('with one contract, a cost is that contract\'s or extra work', (
    tester,
  ) async {
    await setUpRepo(tester);
    await openWith(
      tester,
      (context) => openExpenseForm(context, projectId: 'p2', work: ''),
    );
    expect(find.text('QT-C · Work C'), findsOneWidget);
    await tester.tap(find.text('QT-C · Work C'));
    await tester.pumpAndSettle();
    expect(find.text('Extra work, outside the contract'), findsWidgets);
    expect(find.text('General project cost (not linked)'), findsNothing);
  });

  testWidgets('contract cards fit a narrow phone', (tester) async {
    await setUpRepo(tester);
    await show(
      tester,
      (context) => Scaffold(body: ProjectMoneyTab(project: repo.project('p')!)),
      size: const Size(320, 3000),
    );
    await tester.tap(find.text('AK internal'));
    await tester.pumpAndSettle();
    expect(find.text('BY CONTRACT'), findsOneWidget);
    expect(find.text('Invoices and expenses'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
