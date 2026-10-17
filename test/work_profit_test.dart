import 'dart:io';

import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/profit.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// Income and costs of a project matched to the work they belong to.
void main() {
  late Repository repo;
  late DateTime t;

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 17, 9)));
    t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya'),
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
  });

  Future<Quotation> contract(
    String id,
    double cost, {
    double markup = 0,
    int day = 1,
    String project = 'p',
    QuotationStatus status = QuotationStatus.accepted,
    List<PaymentTerm> terms = const [],
  }) async {
    await repo.saveQuotation(
      Quotation(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: 'QT-$id',
        title: 'Work $id',
        clientId: 'c',
        projectId: project,
        date: DateTime(2026, 9, day),
        status: status,
        vatRate: 11,
        markupRate: markup,
        items: [LineItem(description: 'Works', rate: cost)],
        paymentTerms: terms,
      ),
    );
    return repo.quotation(id)!;
  }

  Future<Invoice> invoice(
    String id,
    double net, {
    String? quotationId,
    bool extra = false,
    int day = 10,
    int month = 10,
    String? project = 'p',
    InvoiceStatus status = InvoiceStatus.sent,
  }) async {
    await repo.saveInvoice(
      Invoice(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: 'INV-$id',
        clientId: 'c',
        projectId: project,
        quotationId: quotationId,
        extra: extra,
        date: DateTime(2026, month, day),
        status: status,
        vatRate: 11,
        items: [LineItem(description: 'Works', rate: net)],
      ),
    );
    return repo.invoice(id)!;
  }

  Future<Expense> expense(
    String id,
    double net, {
    String? quotationId,
    bool extra = false,
    String? project = 'p',
    bool paid = true,
    int day = 12,
  }) async {
    await repo.saveExpense(
      Expense(
        id: id,
        createdAt: t,
        updatedAt: t,
        projectId: project,
        quotationId: quotationId,
        extra: extra,
        date: DateTime(2026, 10, day),
        vendor: 'Supplier $id',
        amount: net,
        paid: paid,
      ),
    );
    return repo.expenses.firstWhere((e) => e.id == id);
  }

  Future<void> pay(
    String id,
    double amount, {
    String invoiceId = '',
    String? quotationId,
    int? termIndex,
    String? project = 'p',
    int day = 14,
    int month = 10,
  }) => repo.savePayment(
    Payment(
      id: id,
      createdAt: t,
      updatedAt: t,
      invoiceId: invoiceId,
      date: DateTime(2026, month, day),
      amount: amount,
      clientId: invoiceId.isEmpty ? 'c' : null,
      projectId: invoiceId.isEmpty ? project : null,
      quotationId: quotationId,
      termIndex: termIndex,
    ),
  );

  WorkProfit work(List<WorkProfit> all, String key) => all.firstWhere(
    (w) => switch (w.kind) {
      WorkKind.contract => w.contract!.id == key,
      WorkKind.extra => key == 'extra',
      WorkKind.general => key == 'general',
    },
  );

  /// The pieces add up to the project's own figures.
  void expectReconciles(String projectId) {
    final works = profitByWork(repo, projectId);
    final whole = profitOf(repo, projectId: projectId);
    double sum(double Function(WorkProfit) f) =>
        works.fold(0.0, (s, w) => s + f(w));
    expect(sum((w) => w.revenue), closeTo(whole.revenue, .01));
    expect(sum((w) => w.cost), closeTo(whole.expenses, .01));
    expect(sum((w) => w.profit), closeTo(whole.profit, .01));
    expect(sum((w) => w.paidOut), closeTo(whole.paidOut, .01));
    expect(
      sum((w) => w.received + w.held),
      closeTo(repo.receivedOn(projectId: projectId), .01),
    );
  }

  test('a design fee and the works each show their own profit', () async {
    // The audit's case: cost-plus works A (cost 100,000, fee 10%) and a
    // lump-sum design contract B (20,000).
    await contract('A', 100000, markup: 10, day: 2);
    await contract('B', 20000, day: 1);
    await invoice('a1', 55000, quotationId: 'A');
    await invoice('b1', 20000, quotationId: 'B');
    await expense('ea', 95000, quotationId: 'A');
    await expense('eb', 5000, quotationId: 'B');

    final works = profitByWork(repo, 'p');
    expect(works.map((w) => w.contract?.id), ['B', 'A']);
    final a = work(works, 'A'), b = work(works, 'B');
    expect(a.contractNet, closeTo(110000, .01));
    expect(a.budgetCost, closeTo(100000, .01));
    expect(a.budgetLeft, closeTo(5000, .01));
    expect(a.expectedProfit, closeTo(10000, .01));
    expect(a.leftToInvoice, closeTo(55000, .01));
    expect(a.profit, closeTo(55000 - 95000, .01));
    expect(b.budgetLeft, isNull);
    expect(b.expectedProfit, isNull);
    expect(b.profit, closeTo(15000, .01));
    expect(b.margin, closeTo(75, .01));
    expectReconciles('p');
  });

  test(
    'extra work and costs linked to no contract have their own rows',
    () async {
      await contract('A', 50000, day: 1);
      await contract('B', 20000, day: 2);
      await invoice('x1', 12000, extra: true);
      await invoice('plain', 3000); // no quotation, two contracts
      await expense('ex', 10000, extra: true);
      await expense('gen', 700); // not linked
      final works = profitByWork(repo, 'p');
      expect(works.map((w) => w.kind), [
        WorkKind.contract,
        WorkKind.contract,
        WorkKind.extra,
        WorkKind.general,
      ]);
      final extra = work(works, 'extra');
      expect(extra.revenue, closeTo(12000, .01));
      expect(extra.cost, closeTo(10000, .01));
      expect(extra.profit, closeTo(2000, .01));
      final general = work(works, 'general');
      expect(general.invoices.map((i) => i.id), ['plain']);
      expect(general.expenses.map((e) => e.id), ['gen']);
      // Contracts with nothing on them still show.
      expect(work(works, 'A').isEmpty, isTrue);
      expectReconciles('p');
    },
  );

  test('with one contract, what is not linked counts in it', () async {
    await contract('A', 50000);
    await invoice('plain', 10000);
    await expense('e', 4000);
    final works = profitByWork(repo, 'p');
    expect(works, hasLength(1));
    expect(works.single.contract!.id, 'A');
    expect(works.single.invoices.single.id, 'plain');
    expect(works.single.expenses.single.id, 'e');
    expect(workLabel(repo, repo.expenses.single, AppLang.en), 'QT-A · Work A');
  });

  test('a link to another project\'s quotation counts as not linked', () async {
    await contract('A', 50000);
    await contract('B', 20000);
    await contract('other', 9000, project: 'p2');
    await expense('e', 300, quotationId: 'other');
    final works = profitByWork(repo, 'p');
    expect(work(works, 'general').expenses.single.id, 'e');
    expect(work(works, 'A').expenses, isEmpty);
    expect(
      workLabel(repo, repo.expenses.single, AppLang.en),
      'Not linked to a contract',
    );
  });

  test('a quotation no longer approved keeps what is linked to it', () async {
    await contract('A', 50000);
    await contract('old', 9000, status: QuotationStatus.rejected);
    await contract('B', 1000);
    await expense('e', 300, quotationId: 'old');
    final old = work(profitByWork(repo, 'p'), 'old');
    expect(old.contractNet, 0);
    expect(old.cost, closeTo(300, .01));
  });

  test('money received follows the invoices it settled, advances stay with '
      'their contract', () async {
    final terms = const [
      PaymentTerm(label: 'Advance', percent: 30),
      PaymentTerm(label: 'Rest', percent: 70),
    ];
    await contract('A', 10000, terms: terms, day: 1);
    await contract('B', 5000, day: 2);
    // An advance on A before any invoice: held for A.
    await pay('adv', 3330, quotationId: 'A', termIndex: 0, day: 3);
    var works = profitByWork(repo, 'p');
    expect(work(works, 'A').held, closeTo(3330, .01));
    expect(work(works, 'A').received, 0);
    expectReconciles('p');

    // B is invoiced: the pooled advance settles the oldest open invoice,
    // so the money now counts where it went.
    await invoice('b1', 2000, quotationId: 'B', day: 5);
    works = profitByWork(repo, 'p');
    expect(work(works, 'B').received, closeTo(2220, .01));
    expect(work(works, 'A').held, closeTo(1110, .01));
    expectReconciles('p');

    // Money on account and money on a draft invoice are held too.
    await invoice('draft', 900, quotationId: 'A', status: InvoiceStatus.draft);
    await pay('acc', 500, day: 6);
    await pay('ondraft', 100, invoiceId: 'draft', day: 7);
    works = profitByWork(repo, 'p');
    expectReconciles('p');
    expect(work(works, 'general').held, closeTo(500, .01));
    expect(work(works, 'A').held, closeTo(1110 + 100, .01));
  });

  test('cash is what was received and held, less bills paid', () async {
    await contract('A', 10000);
    await invoice('a1', 10000, quotationId: 'A');
    await pay('r', 5550, invoiceId: 'a1');
    await expense('paid', 2000, quotationId: 'A');
    await expense('unpaid', 1000, quotationId: 'A', paid: false);
    final a = profitByWork(repo, 'p').single;
    expect(a.received, closeTo(5550, .01));
    expect(a.paidOut, closeTo(2000, .01));
    expect(a.unpaidBills, closeTo(1000, .01));
    expect(a.cash, closeTo(3550, .01));
    expect(a.profit, closeTo(7000, .01));
  });

  test('dates and a choice of expenses narrow the report', () async {
    await contract('A', 10000);
    await invoice('sep', 1000, quotationId: 'A', day: 1);
    await invoice('oct', 2000, quotationId: 'A', day: 20);
    await expense('e1', 100, quotationId: 'A', day: 2);
    await expense('e2', 200, quotationId: 'A', day: 21);
    await expense('e3', 300, quotationId: 'A', day: 22);
    final late = profitByWork(
      repo,
      'p',
      from: DateTime(2026, 10, 20),
      expenseIds: {'e2'},
    ).single;
    expect(late.invoices.map((i) => i.id), ['oct']);
    expect(late.expenses.map((e) => e.id), ['e2']);
    final r = CostReport(
      repo,
      repo.expenses.where((e) => e.id != 'e1').toList(),
      projectId: 'p',
    );
    expect(r.cost, closeTo(500, .01));
    expect(r.revenue, closeTo(3000, .01));
  });

  test('in a period, received is the money received in it, set against '
      'invoices as they stood at its end', () async {
    final terms = const [PaymentTerm(label: 'All', percent: 100)];
    await contract('A', 10000, terms: terms);
    DateTime d(int month, int day) => DateTime(2026, month, day);
    List<WorkProfit> period(DateTime from, DateTime to) =>
        profitByWork(repo, 'p', from: from, to: to);
    double inAll(List<WorkProfit> ws) =>
        ws.fold(0.0, (s, w) => s + w.received + w.held);

    // An advance on 5 October; the invoice it settles comes on 3 November.
    await pay('adv', 5550, quotationId: 'A', termIndex: 0, day: 5);
    await invoice('nov', 5000, quotationId: 'A', day: 3, month: 11);
    var oct = work(period(d(10, 1), d(10, 31)), 'A');
    expect(oct.received, 0);
    expect(oct.held, closeTo(5550, .01)); // still held on 31 October
    var nov = work(period(d(11, 1), d(11, 30)), 'A');
    expect(nov.invoices.map((i) => i.id), ['nov']);
    expect(nov.received + nov.held, 0); // nothing came in during November

    // An October invoice: by 31 October the advance had settled it.
    await invoice('octinv', 1000, quotationId: 'A', day: 10);
    await pay('late', 1110, invoiceId: 'octinv', day: 20, month: 11);
    oct = work(period(d(10, 1), d(10, 31)), 'A');
    expect(oct.receivedOn['octinv'], closeTo(1110, .01));
    expect(oct.held, closeTo(4440, .01));
    // November's receipt, pooled, settles what is still open: November's
    // invoice.
    nov = work(period(d(11, 1), d(11, 30)), 'A');
    expect(nov.received, closeTo(1110, .01));
    expect(nov.receivedOn['nov'], closeTo(1110, .01));
    expect(nov.receivedOutside, 0);

    // Paid in November for an October invoice of another project.
    await invoice('p2oct', 1000, project: 'p2', day: 10);
    await pay('p2late', 1110, invoiceId: 'p2oct', day: 20, month: 11);
    final p2 = profitByWork(repo, 'p2', from: d(11, 1), to: d(11, 30)).single;
    expect(p2.invoices, isEmpty);
    expect(p2.received, closeTo(1110, .01));
    expect(p2.receivedOutside, closeTo(1110, .01));
    final r = CostReport(
      repo,
      const [],
      projectId: 'p2',
      from: d(11, 1),
      to: d(11, 30),
    );
    expect(r.received, closeTo(1110, .01));
    expect(
      CostReport(repo, const [], projectId: 'p2', to: d(10, 31)).received,
      0,
    );

    // From a day on, it matches the project's received figure.
    for (final since in [d(10, 1), d(10, 6), d(11, 1), d(11, 21)]) {
      expect(
        inAll(profitByWork(repo, 'p', from: since)),
        closeTo(repo.receivedOn(projectId: 'p', since: since), .01),
        reason: 'since $since',
      );
    }
    expectReconciles('p');
  });

  test('for every project, the report counts every project\'s income, so '
      'its totals match the company\'s', () async {
    await contract('A', 10000);
    // p has the expense; p2 only income; one invoice has no project.
    await invoice('a1', 5000, quotationId: 'A');
    await expense('e1', 1000, quotationId: 'A');
    await invoice('fee', 20000, project: 'p2');
    await pay('fee-paid', 22200, invoiceId: 'fee');
    await invoice('loose', 300, project: null);
    await pay('acc', 400, project: null);
    await expense('rent', 700, project: null);
    final from = DateTime(2026, 10, 1);
    final r = CostReport(repo, repo.expenses.toList(), from: from);
    final company = profitOf(repo, since: from);
    expect(r.projects.map((p) => p.id), containsAll(['p', 'p2']));
    expect(r.revenue, closeTo(company.revenue, .01));
    expect(r.received, closeTo(company.received, .01));
    expect(r.cost, closeTo(company.expenses, .01));
    expect(r.profit, closeTo(company.profit, .01));
    expect(r.revenueOutside, closeTo(300, .01));
  });

  test('a column a newer version added in the cloud is left out', () async {
    final row = (await expense('e1', 100)).toMap()
      ..['quotation_id'] = null
      ..['added_by_v15'] = 'x';
    await repo.local.putRemote('expenses', row);
    await repo.reload();
    expect(repo.expenses.single.id, 'e1');
  });

  test('Link all leaves a cost deleted meanwhile deleted', () async {
    await contract('A', 10000);
    await contract('B', 10000);
    final e1 = await expense('e1', 100);
    final e2 = await expense('e2', 200);
    await repo.deleteExpense(e2);
    await repo.saveExpense(e1.copyWith(paid: false));
    await repo.linkExpenses([e1, e2], 'B');
    expect(repo.expenses.map((e) => e.id), ['e1']);
    expect(repo.expenses.single.quotationId, 'B');
    expect(repo.expenses.single.paid, isFalse);
  });

  test(
    'an expense keeps its work after a reload and when it changes',
    () async {
      await contract('A', 10000);
      await contract('B', 10000);
      final e = await expense('e', 100, quotationId: 'B');
      await repo.reload();
      expect(repo.expenses.single.quotationId, 'B');
      expect(repo.expenses.single.extra, isFalse);
      // Numbering and paying keep the link.
      expect(e.copyWith(paid: false).quotationId, 'B');
      expect(e.copyWith(work: Expense.extraWork).extra, isTrue);
      expect(e.copyWith(work: Expense.extraWork).quotationId, isNull);
      expect(e.copyWith(work: '').quotationId, isNull);
      expect(e.copyWith(work: 'A').quotationId, 'A');
      await repo.linkExpenses([repo.expenses.single], 'A');
      expect(repo.expenses.single.quotationId, 'A');
      expect(work(profitByWork(repo, 'p'), 'A').expenses.single.id, 'e');
    },
  );

  test(
    'the cloud gets the link and the extra-work flag as true or false',
    () async {
      final cloud = FakeRemote();
      final sync = SyncService(repo.local, repo)..remote = cloud;
      await contract('A', 10000);
      await expense('e', 100, extra: true);
      await sync.syncNow();
      final row = cloud.tables['expenses']!['e']!;
      expect(row['extra'], true);
      expect(row['quotation_id'], isNull);
      final laptop = await memoryRepo(TestClock(t));
      await (SyncService(laptop.local, laptop)..remote = cloud).syncNow();
      expect(laptop.expenses.single.extra, isTrue);
    },
  );

  test('upgrading a version 8 database keeps expenses, not linked', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('akdb8');
    final path = p.join(dir.path, 'ak.db');
    final f = databaseFactoryFfiNoIsolate;
    final old = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, _) async {
          for (final e in syncedTables.entries) {
            final cols = e.key == 'expenses'
                ? e.value
                      .replaceAll(', quotation_id TEXT', '')
                      .replaceAll(', extra INTEGER', '')
                : e.value;
            await db.execute(
              'CREATE TABLE ${e.key} (id TEXT PRIMARY KEY, created_at TEXT '
              'NOT NULL, updated_at TEXT NOT NULL, deleted INTEGER NOT NULL '
              'DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, $cols)',
            );
          }
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.insert('expenses', {
            'id': 'E',
            'created_at': '2026-08-01T00:00:00.000Z',
            'updated_at': '2026-08-02T00:00:00.000Z',
            'project_id': 'P',
            'amount': 250.0,
            'date': '2026-08-01',
          });
          // Pulled before the update, without the new columns.
          await db.insert('settings', {
            'key': 'last_pull_expenses',
            'value': '2030-01-01T00:00:09.000Z',
          });
          await db.insert('settings', {'key': 'app_language', 'value': 'ar'});
        },
      ),
    );
    final before = await old.rawQuery('PRAGMA table_info(expenses)');
    expect(before.any((c) => c['name'] == 'quotation_id'), isFalse);
    await old.close();
    addTearDown(() => appLang = docLang = AppLang.en);
    final r = Repository(await LocalDb.open(path, factory: f), clock: () => t);
    await r.load();
    // Everything is pulled again, now with the new columns.
    expect(await r.local.getSetting('last_pull_expenses'), isNull);
    expect(await r.local.getSetting('app_language'), 'ar');
    final e = r.expenses.single;
    expect(e.amount, 250);
    expect(e.quotationId, isNull);
    expect(e.extra, isFalse);
    await r.saveExpense(e.copyWith(work: Expense.extraWork));
    await r.reload();
    expect(r.expenses.single.extra, isTrue);
    await r.local.db.close();
    await dir.delete(recursive: true);
  });
}
