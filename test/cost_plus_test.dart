import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/ui/pdf_docs.dart';
import 'package:ak_system/ui/screens/cost_plus.dart';
import 'package:ak_system/ui/screens/money_doc_form.dart';
import 'package:ak_system/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// Cost-plus invoices: the client is billed for supplier bills, grouped by
/// category, with the fee on the total or next to each bill.
void main() {
  late Repository repo;
  late DateTime t;

  Expense bill(
    String id,
    ExpenseCategory c,
    double amount, {
    double vat = 0,
    int day = 10,
    String vendor = 'Supplier',
    String ref = '',
  }) => Expense(
    id: id,
    createdAt: t,
    updatedAt: t,
    projectId: 'p',
    date: DateTime(2026, 10, day),
    category: c,
    title: 'Goods',
    vendor: vendor,
    reference: ref,
    vatRate: vat,
    amount: amount,
  );

  Future<void> seed() async {
    t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya'),
    );
    await repo.saveProject(
      Project(
        id: 'p',
        createdAt: t,
        updatedAt: t,
        code: 'AK-26-001',
        name: 'Villa',
        clientId: 'c',
        markupRate: 15,
      ),
    );
    // A steel bill with 11% VAT: 1,110 paid, 1,000 cost to AK.
    await repo.saveExpense(
      bill(
        'steel',
        ExpenseCategory.materials,
        1110,
        vat: 11,
        day: 12,
        vendor: 'Ghandour Steel',
        ref: '4471',
      ),
    );
    await repo.saveExpense(
      bill('crew', ExpenseCategory.labour, 400, day: 5, vendor: 'Crew'),
    );
    await repo.saveExpense(
      bill('sand', ExpenseCategory.materials, 200, day: 3, vendor: 'Sand Co'),
    );
  }

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 11, 1, 9)));
    await seed();
  });

  test('lines: one per bill, cost before VAT, by category then date', () {
    final lines = costPlusLines(repo.expensesFor('p'));
    expect(lines.map((l) => l.expenseId), ['sand', 'steel', 'crew']);
    expect(lines.map((l) => l.section), [
      'Materials',
      'Materials',
      'Labour (daily workers)',
    ]);
    expect(lines[1].rate, 1000);
    expect(lines[1].quantity, 1);
    expect(lines[1].description, startsWith('Goods · Ghandour Steel · '));
    expect(lines[1].description, contains('Ref. 4471'));
  });

  test('the fee is the same on the total and per line', () {
    final inv = Invoice(
      id: 'i',
      createdAt: t,
      updatedAt: t,
      number: 'INV-26-001',
      projectId: 'p',
      clientId: 'c',
      date: t,
      items: costPlusLines(repo.expensesFor('p')),
      markupRate: 15,
      feePerLine: true,
    );
    expect(inv.subtotal, 1600);
    expect(inv.markup, closeTo(240, 1e-9));
    expect(inv.net, closeTo(1840, 1e-9));
    expect(inv.total, closeTo(1840 * 1.11, 1e-9));
  });

  test('the bill link and the fee choice are saved and read back', () async {
    await repo.saveInvoice(
      Invoice(
        id: 'i',
        createdAt: t,
        updatedAt: t,
        number: 'INV-26-001',
        projectId: 'p',
        date: t,
        items: costPlusLines(repo.expensesFor('p')),
        markupRate: 15,
        feePerLine: true,
      ),
    );
    await repo.reload();
    final back = repo.invoice('i')!;
    expect(back.feePerLine, isTrue);
    expect(back.items.map((l) => l.expenseId).toSet(), {
      'sand',
      'steel',
      'crew',
    });
    // Editing a line keeps its bill.
    expect(back.items.first.copyWith(rate: 5).expenseId, 'sand');
  });

  test('a bill is billed once; cancelling the invoice frees it', () async {
    final inv = Invoice(
      id: 'i',
      createdAt: t,
      updatedAt: t,
      number: 'INV-26-001',
      projectId: 'p',
      date: t,
      status: InvoiceStatus.sent,
      items: costPlusLines([repo.expensesFor('p').first]),
    );
    await repo.saveInvoice(inv);
    final id = inv.items.single.expenseId!;
    expect(repo.billedExpenses()[id]?.number, 'INV-26-001');
    expect(repo.billedExpenses(except: 'i'), isEmpty);
    expect(repo.costPlusCount('p'), 1);
    expect(repo.costPlusCount('p', except: 'i'), 0);
    await repo.saveInvoice(inv.copyWith(status: InvoiceStatus.cancelled));
    expect(repo.billedExpenses(), isEmpty);
    await repo.deleteInvoice(repo.invoice('i')!);
    expect(repo.billedExpenses(), isEmpty);
    expect(repo.costPlusCount('p'), 0);
  });

  test('the title follows the pattern', () {
    final bills = repo.expensesFor('p');
    expect(costPlusTitle(3, bills), startsWith('Cost-plus bill 03 · from '));
    expect(costPlusTitle(1, bills.take(1)), isNot(contains('from')));
  });

  test('the PDF prints with the fee next to each line', () async {
    final items = costPlusLines(repo.expensesFor('p'));
    for (final perLine in [true, false]) {
      final pdf = await buildPdf(
        repo,
        Invoice(
          id: 'i',
          createdAt: t,
          updatedAt: t,
          number: 'INV-26-001',
          projectId: 'p',
          clientId: 'c',
          date: t,
          items: items,
          markupRate: 15,
          feePerLine: perLine,
        ),
      );
      expect(pdf.length, greaterThan(1000));
    }
  });

  testWidgets('the invoice form adds ticked bills and names the invoice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // One bill is already on another invoice.
    await tester.runAsync(
      () => repo.saveInvoice(
        Invoice(
          id: 'old',
          createdAt: t,
          updatedAt: t,
          number: 'INV-26-001',
          projectId: 'p',
          clientId: 'c',
          date: t,
          status: InvoiceStatus.sent,
          items: costPlusLines([
            repo.expenses.firstWhere((e) => e.id == 'crew'),
          ]),
        ),
      ),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openInvoiceForm(context, projectId: 'p'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('From supplier bills'));
    await tester.tap(find.text('From supplier bills'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Billed on INV-26-001'), findsOneWidget);
    await tester.tap(find.text('Select all'));
    await tester.pump();
    expect(find.text('Cost \$1,200.00'), findsOneWidget);
    await tester.tap(find.text('Add 2 bills'));
    await tester.pumpAndSettle();
    // Two lines, the fee from the project, and the invoice named.
    expect(find.text('Materials'), findsNWidgets(2));
    expect(
      find.textContaining('Cost-plus bill 02 · from 3 Oct 2026 to 12 Oct 2026'),
      findsOneWidget,
    );
    expect(find.text('15'), findsOneWidget);
    // The bills already on this invoice are not offered again.
    await tester.ensureVisible(find.text('From supplier bills'));
    await tester.tap(find.text('From supplier bills'));
    await tester.pumpAndSettle();
    expect(find.text('Ghandour Steel · Goods'), findsNothing);
    expect(find.text('Select all'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    // The bill lines are locked: no field to type in, only a note and the
    // remove button, which takes a whole bill off.
    expect(find.textContaining('Change it under Expenses.'), findsNWidgets(2));
    expect(find.text('Item 1'), findsNothing);
    await tester.tap(find.byTooltip('Remove this supplier bill').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Change it under Expenses.'), findsOneWidget);
  });

  test('a bill entered item by item brings every item', () {
    final e = Expense(
      id: 'x',
      createdAt: t,
      updatedAt: t,
      projectId: 'p',
      date: DateTime(2026, 10, 9),
      category: ExpenseCategory.materials,
      vendor: 'Ghandour Steel',
      reference: '4471',
      vatRate: 11,
      items: const [
        LineItem(description: 'Rebar 12 mm', quantity: 4, unit: 't', rate: 800),
        LineItem(description: 'Tie wire', quantity: 10, unit: 'roll', rate: 12),
      ],
      amount: Expense.totalOf(const [
        LineItem(quantity: 4, rate: 800),
        LineItem(quantity: 10, rate: 12),
      ], 11),
    );
    final lines = costPlusLinesOf(e);
    expect(lines, hasLength(2));
    expect(lines.map((l) => l.expenseId).toSet(), {'x'});
    expect(lines.first.description, startsWith('Rebar 12 mm · Ghandour Steel'));
    expect(lines.first.quantity, 4);
    expect(lines.first.unit, 't');
    expect(lines.first.rate, 800);
    expect(lines.fold(0.0, (s, l) => s + l.amount), e.net);
  });

  test('refreshing takes each bill again as it is now', () {
    final bills = {for (final e in repo.expensesFor('p')) e.id: e};
    final typed = const LineItem(description: 'Site visit', rate: 50);
    final lines = [typed, ...costPlusLines(bills.values)];
    // The steel bill is corrected and the sand bill deleted.
    final fixed = {
      ...bills,
      'steel': bill(
        'steel',
        ExpenseCategory.materials,
        2220,
        vat: 11,
        day: 12,
        vendor: 'Ghandour Steel',
        ref: '4471',
      ),
    }..remove('sand');
    final again = refreshCostPlus(lines, fixed);
    expect(again.first.description, 'Site visit');
    expect(again.map((l) => l.expenseId), [null, 'steel', 'crew']);
    expect(again[1].rate, 2000);
  });

  testWidgets('a draft invoice follows its bills; a sent one does not', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Invoice inv(String id, InvoiceStatus st) => Invoice(
      id: id,
      createdAt: t,
      updatedAt: t,
      number: id,
      projectId: 'p',
      clientId: 'c',
      date: t,
      status: st,
      items: costPlusLines([repo.expenses.firstWhere((e) => e.id == 'crew')]),
    );
    await tester.runAsync(() async {
      await repo.saveInvoice(inv('INV-D', InvoiceStatus.draft));
      await repo.saveInvoice(inv('INV-S', InvoiceStatus.sent));
      // The crew bill is corrected from 400 to 450 after both were made.
      await repo.saveExpense(
        bill('crew', ExpenseCategory.labour, 450, day: 5, vendor: 'Crew'),
      );
    });
    for (final (id, shown) in [('INV-D', '\$450.00'), ('INV-S', '\$400.00')]) {
      await tester.pumpWidget(
        ChangeNotifierProvider<Repository>.value(
          value: repo,
          child: MaterialApp(
            key: ValueKey(id),
            theme: buildTheme(Brightness.light),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    openInvoiceForm(context, invoice: repo.invoice(id)),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1 bill × $shown'), findsOneWidget);
    }
  });
}
