import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/project_statement.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/words.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Repository repo;

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 14, 9)));
  });

  Future<(Project, Quotation)> setup() async {
    final t = repo.now();
    final c = Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya');
    await repo.saveClient(c);
    final stages = repo.stagesFor(ServiceType.contracting);
    final p = Project(
      id: 'p',
      createdAt: t,
      updatedAt: t,
      code: 'AK-26-003',
      name: 'Fit-out',
      clientId: 'c',
      service: ServiceType.contracting,
      stageId: stages[4].id,
    );
    await repo.saveProject(p);
    final q = Quotation(
      id: 'q',
      createdAt: t,
      updatedAt: t,
      number: 'QT-26-001',
      clientId: 'c',
      projectId: 'p',
      date: t,
      vatRate: 0,
      markupRate: 10,
      status: QuotationStatus.accepted,
      items: const [
        LineItem(
          section: 'Masonry',
          description: 'Block wall 10 cm',
          unit: 'm²',
          quantity: 100,
          rate: 10,
        ),
        LineItem(
          section: 'Painting',
          description: 'Emulsion paint',
          unit: 'm²',
          quantity: 200,
          rate: 5,
        ),
      ],
    );
    await repo.saveQuotation(q);
    return (p, q);
  }

  test('amounts in words for receipts', () {
    expect(dollarsInWords(2500), 'Two thousand five hundred US dollars');
    expect(
      dollarsInWords(1021.5),
      'One thousand twenty-one US dollars and 50 cents',
    );
    expect(dollarsInWords(1), 'One US dollar');
  });

  test('payments get receipt numbers in order', () async {
    final (_, q) = await setup();
    final inv = repo
        .invoiceFromQuotation(q)
        .copyWith(status: InvoiceStatus.sent);
    await repo.saveInvoice(inv);
    final t = repo.now();
    for (final (id, a) in [('a', 500.0), ('b', 700.0)]) {
      await repo.savePayment(
        Payment(
          id: id,
          createdAt: t,
          updatedAt: t,
          invoiceId: inv.id,
          date: t,
          amount: a,
        ),
      );
    }
    expect(repo.payments.map((p) => p.number).toSet(), {
      'RCT-26-001',
      'RCT-26-002',
    });
  });

  test('progress invoice bills a share of every item, in the phase', () async {
    final (p, q) = await setup();
    final inv = repo.progressInvoice(q, 30);
    expect(inv.items.map((i) => i.quantity), [30, 60]);
    expect(inv.total, closeTo(q.total * .3, 1e-9));
    expect(inv.stageId, p.stageId);
  });

  test('project statement by phase, trade and item', () async {
    final (p, q) = await setup();
    final t = repo.now();
    final inv = repo
        .progressInvoice(q, 40)
        .copyWith(status: InvoiceStatus.sent);
    await repo.saveInvoice(inv);
    await repo.savePayment(
      Payment(
        id: 'x',
        createdAt: t,
        updatedAt: t,
        invoiceId: inv.id,
        date: t,
        amount: 400,
      ),
    );
    await repo.saveTask(
      Task(
        id: 't1',
        createdAt: t,
        updatedAt: t,
        projectId: 'p',
        title: 'Order tiles',
        stageId: p.stageId,
        status: TaskStatus.done,
      ),
    );
    final ps = buildProjectStatement(repo, 'p');
    expect(ps.contractValue, closeTo(2200, 1e-9));
    expect(ps.layers.map((l) => l.name), ['Masonry', 'Painting']);
    expect(ps.layers.first.contractAmount, closeTo(1100, 1e-9));
    expect(ps.layers.first.percent, closeTo(40, 1e-9));
    expect(ps.layers.first.items.single.invoicedQty, 40);
    final phase = ps.phases.single;
    expect(phase.stage?.id, p.stageId);
    expect(phase.tasksDone, 1);
    expect(phase.invoiced, closeTo(880, 1e-9));
    expect(phase.balance, closeTo(480, 1e-9));
    expect(ps.billedPercent, closeTo(40, 1e-9));
  });
}
