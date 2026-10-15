import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/profit.dart';
import 'package:ak_system/data/project_statement.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/statement.dart';
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

  group('receipts on payment terms and on account', () {
    const terms = [
      PaymentTerm(label: 'Advance payment', percent: 30, due: 'On signing'),
      PaymentTerm(label: 'Progress payment', percent: 60),
      PaymentTerm(label: 'Final payment', percent: 10, due: 'On handover'),
    ];

    Future<Quotation> withTerms() async {
      final (_, q) = await setup();
      final withTerms = q.copyWith(paymentTerms: terms);
      await repo.saveQuotation(withTerms);
      return repo.quotation('q')!;
    }

    Future<Payment> receive(
      String id,
      double amount, {
      String invoiceId = '',
      String? quotationId,
      int? termIndex,
      String notes = '',
      int day = 14,
      String? projectId = 'p',
    }) async {
      final t = repo.now();
      await repo.savePayment(
        Payment(
          id: id,
          createdAt: t,
          updatedAt: t,
          invoiceId: invoiceId,
          date: DateTime(2026, 10, day),
          amount: amount,
          clientId: invoiceId.isEmpty ? 'c' : null,
          projectId: invoiceId.isEmpty ? projectId : null,
          quotationId: quotationId,
          termIndex: termIndex,
          notes: notes,
        ),
      );
      return repo.payments.firstWhere((p) => p.id == id);
    }

    test('standard schedules add up to 100%', () {
      for (final preset in paymentTermPresets.values) {
        expect(preset.fold(0.0, (s, t) => s + t.percent), 100);
      }
    });

    test('payment terms are saved with the quotation', () async {
      final q = await withTerms();
      expect(q.paymentTerms.map((t) => t.label), [
        'Advance payment',
        'Progress payment',
        'Final payment',
      ]);
      expect(q.paymentTerms.first.due, 'On signing');
      expect(q.paymentTerms.map((t) => t.valueOf(q.total)), [
        closeTo(660, 1e-9),
        closeTo(1320, 1e-9),
        closeTo(220, 1e-9),
      ]);
    });

    test('an advance on a term is held until it is invoiced', () async {
      final q = await withTerms();
      final adv = await receive('a1', 660, quotationId: 'q', termIndex: 0);
      expect(adv.number, 'RCT-26-001');
      expect(repo.payerOf(adv), 'c');
      expect(repo.projectOfPayment(adv), 'p');
      expect(receiptPurpose(repo, adv), 'Advance payment of QT-26-001');
      expect(repo.termStatus(q, 0).settled, isTrue);
      expect(repo.unappliedOf(adv), 660);

      final m = repo.money(projectId: 'p');
      expect(m.received, 660);
      expect(m.advances, 660);
      expect(m.outstanding, 0);

      final st = buildStatement(repo, 'c');
      expect(st.received, 660);
      expect(st.advances, 660);
      expect(st.closing, -660);
      expect(st.open, isEmpty);
    });

    test('invoicing the term sets the advance against it', () async {
      final q = await withTerms();
      final adv = await receive('a1', 660, quotationId: 'q', termIndex: 0);
      final draft = repo.invoiceForTerm(q, 0);
      expect(draft.termIndex, 0);
      expect(draft.quotationId, 'q');
      expect(draft.total, closeTo(660, 1e-9));
      expect(draft.title, 'Advance payment (30%)');
      final inv = draft.copyWith(status: InvoiceStatus.sent);
      await repo.saveInvoice(inv);

      expect(repo.paidOn(inv), closeTo(660, 1e-9));
      expect(repo.paymentState(inv), PaymentState.paid);
      expect(repo.advancesOn(inv).single.$1.id, adv.id);
      expect(repo.unappliedOf(adv), 0);
      final st = buildStatement(repo, 'c');
      expect(st.closing, closeTo(0, 1e-9));
      expect(st.advances, 0);
      expect(st.open, isEmpty);
      expect(repo.money(projectId: 'p').advances, 0);
      // The term counts the receipt once, not twice.
      expect(repo.termStatus(q, 0).received, closeTo(660, 1e-9));
    });

    test('a part advance leaves the rest due on the term invoice', () async {
      final q = await withTerms();
      await receive('a1', 500, quotationId: 'q', termIndex: 0, day: 10);
      final inv = repo
          .invoiceForTerm(q, 0)
          .copyWith(status: InvoiceStatus.sent);
      await repo.saveInvoice(inv);
      expect(repo.balanceOf(inv), closeTo(160, 1e-9));
      expect(repo.paymentState(inv), PaymentState.partlyPaid);
      final rest = await receive('r2', 160, invoiceId: inv.id);
      expect(repo.receivedBefore(rest), 0); // the advance was on the term
      expect(repo.paymentState(inv), PaymentState.paid);
      final status = repo.termStatus(q, 0);
      expect(status.received, closeTo(660, 1e-9));
      expect(status.settled, isTrue);
      expect(status.invoices.single.id, inv.id);
      expect(buildStatement(repo, 'c').closing, closeTo(0, 1e-9));
    });

    test('receipts on account show as a credit with their purpose', () async {
      await setup();
      final dep = await receive('d1', 1000, notes: 'Deposit');
      expect(receiptPurpose(repo, dep), 'on account · Deposit');
      expect(repo.unappliedOf(dep), 1000);
      expect(repo.receipts(clientId: 'c').single.id, 'd1');
      expect(repo.receipts(projectId: 'other'), isEmpty);
      final st = buildStatement(repo, 'c', projectId: 'p');
      expect(st.lines.single.credit, 1000);
      expect(st.lines.single.description, contains('on account · Deposit'));
      expect(st.closing, -1000);
    });

    test('earlier receipts on the same term come first', () async {
      await withTerms();
      final a = await receive('a1', 200, quotationId: 'q', termIndex: 1);
      final b = await receive('b2', 300, quotationId: 'q', termIndex: 1);
      await receive('c3', 50, quotationId: 'q', termIndex: 2);
      expect(repo.receivedBefore(a), 0);
      expect(repo.receivedBefore(b), 200);
    });

    test('project statement lists the payment schedule', () async {
      await withTerms();
      await receive('a1', 660, quotationId: 'q', termIndex: 0);
      final ps = buildProjectStatement(repo, 'p');
      expect(ps.schedule.length, 3);
      expect(ps.schedule.first.label, 'Advance payment');
      expect(ps.schedule.first.status.settled, isTrue);
      expect(ps.schedule[1].status.remaining, closeTo(1320, 1e-9));
      expect(ps.account.advances, 660);
    });

    Future<Invoice> issue(
      String id,
      double amount, {
      String? projectId = 'p',
      String? quotationId,
      int? termIndex,
      int day = 14,
      DateTime? at,
    }) async {
      final t = repo.now();
      final inv = Invoice(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: repo.nextInvoiceNumber(),
        clientId: 'c',
        projectId: projectId,
        quotationId: quotationId,
        termIndex: termIndex,
        date: at ?? DateTime(2026, 10, day),
        status: InvoiceStatus.sent,
        vatRate: 0,
        items: [LineItem(description: 'Fees', rate: amount)],
      );
      await repo.saveInvoice(inv);
      return repo.invoice(id)!;
    }

    test(
      'money on account settles a later invoice and keeps the rest',
      () async {
        await setup();
        final dep = await receive('d1', 2000, notes: 'Advance', day: 1);
        final inv = await issue('i1', 754, day: 10);
        expect(repo.paidOn(inv), closeTo(754, 1e-9));
        expect(repo.paymentState(inv), PaymentState.paid);
        expect(repo.unappliedOf(dep), closeTo(1246, 1e-9));
        expect(repo.appliedTo(dep).single.$1.id, 'i1');
        expect(repo.advancesOn(inv).single.$2, closeTo(754, 1e-9));
        final st = buildStatement(repo, 'c');
        expect(st.closing, closeTo(-1246, 1e-9));
        expect(st.advances, closeTo(1246, 1e-9));
        expect(st.dueOnInvoices, 0);
        expect(st.open, isEmpty);
        final m = repo.money(projectId: 'p');
        expect(m.outstanding, 0);
        expect(m.advances, closeTo(1246, 1e-9));
      },
    );

    test('older invoices are settled first and never reopen', () async {
      await setup();
      final dep = await receive('d1', 2000, day: 1);
      final a = await issue('a', 754, day: 5);
      final b = await issue('b', 1500, day: 9);
      expect(repo.paymentState(a), PaymentState.paid);
      expect(repo.balanceOf(b), closeTo(254, 1e-9));
      expect(repo.unappliedOf(dep), 0);
      // A newer invoice takes nothing from the older ones.
      final c = await issue('c', 300, day: 12);
      expect(repo.paymentState(a), PaymentState.paid);
      expect(repo.balanceOf(b), closeTo(254, 1e-9));
      expect(repo.balanceOf(c), closeTo(300, 1e-9));
      expect(buildStatement(repo, 'c').dueOnInvoices, closeTo(554, 1e-9));
    });

    test('a statement as of a past date only sets off what existed', () async {
      await setup();
      await issue('a', 754, day: 5);
      await receive('d1', 2000, day: 10);
      final before = buildStatement(repo, 'c', to: DateTime(2026, 10, 8));
      expect(before.open.single.balance, closeTo(754, 1e-9));
      expect(before.advances, 0);
      final after = buildStatement(repo, 'c');
      expect(after.open, isEmpty);
      expect(after.advances, closeTo(1246, 1e-9));
    });

    test('money on account for one project does not pay another', () async {
      await setup();
      final t = repo.now();
      await repo.saveProject(
        Project(
          id: 'p2',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-004',
          name: 'Second',
          clientId: 'c',
        ),
      );
      await receive('d1', 1000, day: 1); // project p
      final other = await issue('x', 400, projectId: 'p2', day: 5);
      final general = await issue('y', 100, projectId: null, day: 6);
      expect(repo.balanceOf(other), closeTo(400, 1e-9));
      expect(repo.balanceOf(general), 0);
    });

    test('an advance on a term is recovered from progress invoices', () async {
      final q = await withTerms();
      await receive('a1', 660, quotationId: 'q', termIndex: 0, day: 1);
      final prog = await issue('pr', 880, quotationId: 'q', day: 10);
      expect(repo.paidOn(prog), closeTo(660, 1e-9));
      expect(repo.balanceOf(prog), closeTo(220, 1e-9));
      // The term itself still counts as received.
      expect(repo.termStatus(q, 0).settled, isTrue);
    });

    test('money on account paying a term invoice counts on the term', () async {
      final q = await withTerms();
      await receive('d1', 500, day: 1);
      final inv = await issue('t', 220, quotationId: 'q', termIndex: 2, day: 9);
      expect(repo.paymentState(inv), PaymentState.paid);
      expect(repo.termStatus(q, 2).received, closeTo(220, 1e-9));
      expect(repo.termStatus(q, 2).settled, isTrue);
    });

    test('a deposit with no project pays a project invoice, and the project '
        'shows it', () async {
      await setup();
      final dep = await receive('d1', 2000, day: 1, projectId: null);
      final inv = await issue('i1', 754, day: 10);
      expect(repo.paymentState(inv), PaymentState.paid);
      // The project: invoiced 754, received 754 (set off), nothing due.
      final st = buildStatement(repo, 'c', projectId: 'p');
      expect(st.invoiced, closeTo(754, 1e-9));
      expect(st.received, closeTo(754, 1e-9));
      expect(st.closing, closeTo(0, 1e-9));
      expect(st.advances, 0);
      expect(st.open, isEmpty);
      expect(st.lines.last.description, startsWith('Set off from'));
      final m = repo.money(projectId: 'p');
      expect(m.received, closeTo(754, 1e-9));
      expect(m.outstanding, 0);
      expect(m.advances, 0);
      expect(profitOf(repo, projectId: 'p').received, closeTo(754, 1e-9));
      expect(repo.receivedFor(dep, 'p'), closeTo(754, 1e-9));
      expect(repo.receipts(projectId: 'p').single.id, 'd1');
      final ps = buildProjectStatement(repo, 'p');
      expect(
        ps.phases.fold(0.0, (s, ph) => s + ph.received),
        closeTo(ps.account.received, 1e-9),
      );
      // The rest stays on the client's account.
      final all = buildStatement(repo, 'c');
      expect(all.closing, closeTo(-1246, 1e-9));
      expect(all.advances, closeTo(1246, 1e-9));
      expect(repo.money().received, 2000);
    });

    test('credit of a project used outside it leaves its statement', () async {
      await setup();
      await receive('d1', 1000, day: 1); // project p
      await issue('y', 100, projectId: null, day: 6);
      final st = buildStatement(repo, 'c', projectId: 'p');
      expect(st.invoiced, 0);
      expect(st.received, closeTo(900, 1e-9));
      expect(st.closing, closeTo(-900, 1e-9));
      expect(st.advances, closeTo(900, 1e-9));
      expect(repo.money(projectId: 'p').received, closeTo(900, 1e-9));
    });

    test('paying above a term becomes credit for the next invoices', () async {
      final q = await withTerms();
      final a = await receive('a1', 800, quotationId: 'q', termIndex: 0);
      final t0 = await issue('t0', 660, quotationId: 'q', termIndex: 0);
      final t1 = await issue('t1', 1320, quotationId: 'q', termIndex: 1);
      expect(repo.paymentState(t0), PaymentState.paid);
      expect(repo.paidOn(t1), closeTo(140, 1e-9));
      expect(repo.balanceOf(t1), closeTo(1180, 1e-9));
      expect(repo.termStatus(q, 0).received, closeTo(660, 1e-9));
      expect(repo.unappliedOf(a), 0);
    });

    test('money on a cancelled invoice becomes credit', () async {
      await setup();
      final i1 = await issue('i1', 754, day: 5);
      final paid = await receive('r1', 754, invoiceId: 'i1', day: 6);
      expect(repo.unappliedOf(paid), 0);
      await repo.saveInvoice(i1.copyWith(status: InvoiceStatus.cancelled));
      expect(repo.unappliedOf(paid), 754);
      expect(receiptPurpose(repo, paid), contains('cancelled'));
      final i2 = await issue('i2', 800, day: 7);
      expect(repo.paidOn(i2), closeTo(754, 1e-9));
      expect(repo.balanceOf(i2), closeTo(46, 1e-9));
      final st = buildStatement(repo, 'c');
      expect(st.closing, closeTo(46, 1e-9));
      expect(st.dueOnInvoices, closeTo(46, 1e-9));
    });

    test('totals are settled to the cent', () async {
      await setup();
      // 369.9963 prints as \$370.00; two of them are paid with \$740.00.
      final a = await issue('a', 369.9963, day: 5);
      final b = await issue('b', 369.9963, day: 6);
      final dep = await receive('d1', 740, day: 7);
      expect(repo.balanceOf(a), 0);
      expect(repo.balanceOf(b), 0);
      expect(repo.paymentState(b), PaymentState.paid);
      expect(repo.unappliedOf(dep), 0);
    });

    test('invoices of the same day settle in number order', () async {
      await setup();
      await receive('d1', 1000, day: 1);
      final first = await issue('a', 754, at: DateTime(2026, 10, 15, 10, 30));
      final second = await issue('b', 500, at: DateTime(2026, 10, 15));
      expect(repo.paymentState(first), PaymentState.paid);
      expect(repo.balanceOf(second), closeTo(254, 1e-9));
    });

    test('set-offs read during a reload are not kept', () async {
      await setup();
      final inv = await issue('i1', 754, day: 5);
      // A receipt arrives from the cloud: written to the database, then
      // the lists reload while the screen keeps reading.
      final t = repo.now();
      await repo.local.save(
        'payments',
        Payment(
          id: 'd1',
          createdAt: t,
          updatedAt: t,
          date: DateTime(2026, 10, 6),
          amount: 2000,
          clientId: 'c',
        ).toMap(),
      );
      var done = false;
      final reload = repo.reload().then((_) => done = true);
      while (!done) {
        repo.balanceOf(inv);
        await Future<void>.delayed(Duration.zero);
      }
      await reload;
      expect(repo.balanceOf(repo.invoice('i1')!), 0);
    });
  });
}
