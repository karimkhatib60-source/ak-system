import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/ui/screens/expenses.dart';
import 'package:ak_system/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

void main() {
  testWidgets('opening and saving a bill never changes its figures', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const items = [
      LineItem(description: 'Rebar', unit: 'kg', quantity: 12000, rate: 0.875),
      LineItem(description: 'Concrete', unit: 'm³', quantity: 12.375, rate: 95),
    ];
    final repo = (await tester.runAsync(() async {
      final r = await memoryRepo(TestClock(DateTime(2026, 10, 15, 9)));
      final t = r.now();
      await r.saveExpense(
        Expense(
          id: 'e1',
          createdAt: t,
          updatedAt: t,
          date: t,
          vendor: 'Steel Co',
          items: items,
          vatRate: 11,
          amount: Expense.totalOf(items, 11),
          paid: false,
        ),
      );
      return r;
    }))!;
    final before = repo.expenses.single;
    expect(before.amount, closeTo(12959.95, 1e-9));

    await tester.pumpWidget(
      ChangeNotifierProvider<Repository>.value(
        value: repo,
        child: MaterialApp(
          theme: buildTheme(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => openExpenseForm(context, expense: before),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Paid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paid'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      for (var k = 0; k < 20 && repo.expenses.single.paid == false; k++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pumpAndSettle();

    final after = repo.expenses.single;
    expect(after.paid, isTrue);
    expect(after.amount, before.amount);
    expect(
      after.items.map((i) => (i.quantity, i.rate)),
      items.map((i) => (i.quantity, i.rate)),
    );
  });
}
