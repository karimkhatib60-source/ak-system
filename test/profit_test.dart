import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/profit.dart';
import 'package:ak_system/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Repository repo;

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 14, 9)));
    final t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'A'),
    );
    for (final id in ['p', 'p2']) {
      await repo.saveProject(
        Project(
          id: id,
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-$id',
          name: id,
          clientId: 'c',
        ),
      );
    }
    // Cost-plus BOQ: cost 10,000, fee 15% = 1,500, VAT 11%.
    await repo.saveQuotation(
      Quotation(
        id: 'q',
        createdAt: t,
        updatedAt: t,
        number: 'QT-26-001',
        clientId: 'c',
        projectId: 'p',
        date: t,
        markupRate: 15,
        status: QuotationStatus.accepted,
        items: const [LineItem(description: 'Works', rate: 10000)],
      ),
    );
    // Invoiced 40%: 4,600 before VAT, 506 VAT.
    await repo.saveInvoice(
      repo
          .progressInvoice(repo.quotation('q')!, 40)
          .copyWith(status: InvoiceStatus.sent),
    );
    Future<void> spend(String id, String? project, double a) =>
        repo.saveExpense(
          Expense(
            id: id,
            createdAt: t,
            updatedAt: t,
            projectId: project,
            date: t,
            category: ExpenseCategory.subcontractor,
            amount: a,
          ),
        );
    await spend('e1', 'p', 3000);
    await spend('e2', 'p2', 200);
    await spend('e3', null, 500);
  });

  test('project profit is income without VAT less its expenses', () {
    final f = profitOf(repo, projectId: 'p');
    expect(f.contractNet, closeTo(11500, 1e-9));
    expect(f.budgetCost, closeTo(10000, 1e-9));
    expect(f.revenue, closeTo(4600, 1e-9));
    expect(f.vat, closeTo(506, 1e-9));
    expect(f.expenses, 3000);
    expect(f.profit, closeTo(1600, 1e-9));
    expect(f.margin, closeTo(1600 / 4600 * 100, 1e-9));
    expect(f.budgetLeft, closeTo(7000, 1e-9));
    // On budget, the expected profit is the fee.
    expect(f.expectedProfit, closeTo(1500, 1e-9));
    expect(f.overheads, 0);
  });

  test('a cost overrun lowers the expected profit', () async {
    final t = repo.now();
    await repo.saveExpense(
      Expense(
        id: 'e4',
        createdAt: t,
        updatedAt: t,
        projectId: 'p',
        date: t,
        category: ExpenseCategory.materials,
        amount: 8000,
      ),
    );
    final f = profitOf(repo, projectId: 'p');
    expect(f.budgetLeft, closeTo(-1000, 1e-9));
    expect(f.expectedProfit, closeTo(500, 1e-9));
  });

  test('company profit includes overheads; projects are ranked', () {
    final all = profitOf(repo);
    expect(all.expenses, 3700);
    expect(all.overheads, 500);
    expect(all.profit, closeTo(900, 1e-9));
    final m = repo.money();
    expect(m.revenue, closeTo(4600, 1e-9));
    expect(m.profit, closeTo(900, 1e-9));
    final ranked = profitByProject(repo);
    expect(ranked.map((e) => e.$1.id), ['p', 'p2']);
    expect(ranked.last.$2.profit, -200);
  });

  test('no forecast without a cost budget; extras count as income', () async {
    final t = repo.now();
    await repo.saveQuotation(
      Quotation(
        id: 'q2',
        createdAt: t,
        updatedAt: t,
        number: 'QT-26-002',
        clientId: 'c',
        projectId: 'p2',
        date: t,
        status: QuotationStatus.accepted,
        items: const [LineItem(description: 'Design fee', rate: 10000)],
      ),
    );
    var f = profitOf(repo, projectId: 'p2');
    expect(f.expectedProfit, isNull);
    expect(f.leftToInvoice, closeTo(10000, 1e-9));
    // Invoiced in full plus a variation of 2,000.
    for (final (id, a) in [('v1', 10000.0), ('v2', 2000.0)]) {
      await repo.saveInvoice(
        Invoice(
          id: id,
          createdAt: t,
          updatedAt: t,
          number: repo.nextInvoiceNumber(),
          clientId: 'c',
          projectId: 'p2',
          date: t,
          status: InvoiceStatus.sent,
          items: [LineItem(description: 'Fee', rate: a)],
        ),
      );
    }
    f = profitOf(repo, projectId: 'p2');
    expect(f.income, closeTo(12000, 1e-9));
    expect(f.leftToInvoice, 0);
    expect(f.costsMayBeMissing, isFalse);
  });

  test('the profit list adds up to the company profit', () async {
    final t = repo.now();
    await repo.saveInvoice(
      Invoice(
        id: 'free',
        createdAt: t,
        updatedAt: t,
        number: repo.nextInvoiceNumber(),
        clientId: 'c',
        date: t,
        status: InvoiceStatus.sent,
        items: const [LineItem(description: 'Consultation', rate: 1000)],
      ),
    );
    final outside = profitOutsideProjects(repo);
    expect(outside.revenue, closeTo(1000, 1e-9));
    final all = profitOf(repo);
    final listed = profitByProject(repo).fold(0.0, (s, r) => s + r.$2.profit);
    expect(listed + outside.profit - all.overheads, closeTo(all.profit, 1e-9));
    expect(all.profit, closeTo(repo.money().profit, 1e-9));
  });
}
