import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/ui/pdf_docs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Every receipt of a client is one pool that settles their issued
/// invoices oldest first.
void main() {
  late Repository repo;
  late DateTime t;
  late TestClock clock;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 20, 9));
    repo = await memoryRepo(clock);
    t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'Maya'),
    );
    for (final p in ['A', 'B']) {
      await repo.saveProject(
        Project(
          id: p,
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-00$p',
          name: 'Project $p',
          clientId: 'c',
        ),
      );
    }
  });

  Future<Invoice> invoice(
    String id,
    double amount, {
    String? project,
    String? client = 'c',
    int day = 15,
    String? quotationId,
    int? termIndex,
    bool extra = false,
  }) async {
    await repo.saveInvoice(
      Invoice(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: repo.nextInvoiceNumber(),
        clientId: client,
        projectId: project,
        quotationId: quotationId,
        termIndex: termIndex,
        extra: extra,
        date: DateTime(2026, 10, day),
        status: InvoiceStatus.sent,
        vatRate: 0,
        items: [LineItem(description: 'Works', rate: amount)],
      ),
    );
    return repo.invoice(id)!;
  }

  Future<Payment> receive(
    String id,
    double amount, {
    int day = 10,
    String? project,
    String invoiceId = '',
    String? quotationId,
    int? termIndex,
    String? client = 'c',
  }) async {
    await repo.savePayment(
      Payment(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: repo.nextReceiptNumber(),
        invoiceId: invoiceId,
        date: DateTime(2026, 10, day),
        amount: amount,
        clientId: invoiceId.isEmpty ? client : null,
        projectId: project,
        quotationId: quotationId,
        termIndex: termIndex,
      ),
    );
    return repo.payments.firstWhere((p) => p.id == id);
  }

  Future<Quotation> contract() async {
    final q = Quotation(
      id: 'q',
      createdAt: t,
      updatedAt: t,
      number: 'QT-26-001',
      clientId: 'c',
      projectId: 'A',
      date: DateTime(2026, 10, 1),
      status: QuotationStatus.accepted,
      vatRate: 0,
      items: const [LineItem(description: 'Works', rate: 10000)],
      paymentTerms: const [
        PaymentTerm(label: 'Advance', percent: 30),
        PaymentTerm(label: 'Rest', percent: 70),
      ],
    );
    await repo.saveQuotation(q);
    return q;
  }

  test('money for any project never leaves another project unpaid', () async {
    final any = await receive('any', 1000, day: 1);
    final forA = await receive('forA', 1000, day: 2, project: 'A');
    final a1 = await invoice('a1', 1000, project: 'A', day: 5);
    final b1 = await invoice('b1', 1000, project: 'B', day: 6);
    expect(repo.balanceOf(a1), 0);
    expect(repo.balanceOf(b1), 0);
    expect(repo.unappliedOf(any), 0);
    expect(repo.unappliedOf(forA), 0);
    expect(repo.appliedTo(forA).single.$1.id, 'a1');
    expect(repo.appliedTo(any).single.$1.id, 'b1');
    // Before B1 was issued, the oldest money paid A1.
    final then = DateTime(2026, 10, 5);
    expect(repo.appliedTo(any, until: then).single.$1.id, 'a1');
    expect(repo.unappliedOf(forA, until: then), 1000);
  });

  test('project money still pays only its own project', () async {
    final forA = await receive('forA', 1000, day: 2, project: 'A');
    final b1 = await invoice('b1', 1000, project: 'B', day: 6);
    expect(repo.balanceOf(b1), 1000);
    expect(repo.unappliedOf(forA), 1000);
  });

  test('a payment on an invoice with no client still counts', () async {
    final inv = await invoice('x', 500, project: 'A', client: null);
    await receive('p', 500, invoiceId: 'x');
    expect(repo.paidOn(inv), 500);
    expect(repo.balanceOf(inv), 0);
  });

  test('an advance that paid extra work is not counted on its instalment '
      'as well', () async {
    final q = await contract();
    final extra = await invoice('e', 500, project: 'A', day: 1, extra: true);
    await receive('adv', 3000, day: 5, quotationId: 'q', termIndex: 0);
    expect(repo.balanceOf(extra), 0);
    expect(repo.termStatus(q, 0).received, 2500);
  });

  test('an advance that paid another contract is not counted twice', () async {
    final q = await contract();
    final other = await invoice(
      'o',
      1000,
      project: 'A',
      day: 1,
      quotationId: 'other',
    );
    await receive('adv', 3000, day: 5, quotationId: 'q', termIndex: 0);
    expect(repo.balanceOf(other), 0);
    expect(repo.termStatus(q, 0).received, 2000);
  });

  test('what one receipt adds to its instalment, when part of it settles an '
      'older instalment invoice', () async {
    final q = await contract();
    clock.now = DateTime(2026, 10, 5, 9);
    final first = repo.invoiceForTerm(q, 0);
    await repo.saveInvoice(first.copyWith(status: InvoiceStatus.sent));
    clock.now = DateTime(2026, 10, 20, 9);
    final pay = await receive(
      'rest',
      7000,
      day: 10,
      quotationId: 'q',
      termIndex: 1,
    );
    // 3,000 settles the first instalment's invoice; 4,000 stays on the rest.
    expect(repo.termStatus(q, 0).received, closeTo(3000, 1e-6));
    expect(
      repo
          .termStatus(q, 1, until: pay.date, through: pay, before: true)
          .received,
      0,
    );
    expect(
      repo.termStatus(q, 1, until: pay.date, through: pay).received,
      closeTo(4000, 1e-6),
    );
    expect(
      repo.appliedTo(pay, until: pay.date, through: pay).single.$1.id,
      first.id,
    );
  });

  test('receipts after the one asked about do not count', () async {
    await invoice('a1', 1000, project: 'A', day: 5);
    final one = await receive('one', 600, day: 6);
    final two = await receive('two', 600, day: 6);
    expect(repo.appliedTo(one, through: one).single.$2, 600);
    expect(repo.unappliedOf(two, through: two), closeTo(200, 1e-6));
    expect(repo.settledBy(repo.invoice('a1')!, through: one).length, 1);
  });

  test('money is passed along older invoices so none stays due while credit '
      'could pay it', () async {
    final forC = await receive('forC', 100, day: 1, project: 'C');
    final free = await receive('free', 100, day: 2);
    final forB = await receive('forB', 100, day: 3, project: 'B');
    final m2 = await invoice('m2', 100, day: 5);
    final m1 = await invoice('m1', 100, project: 'C', day: 6);
    final i = await invoice('i', 100, project: 'A', day: 7);
    for (final x in [m2, m1, i]) {
      expect(repo.balanceOf(x), 0, reason: x.id);
    }
    for (final p in [forC, free, forB]) {
      expect(repo.unappliedOf(p), 0, reason: p.id);
    }
    expect(repo.appliedTo(free).single.$1.id, 'i');
    expect(repo.appliedTo(forC).single.$1.id, 'm1');
    expect(repo.appliedTo(forB).single.$1.id, 'm2');
  });

  test(
    'receipts and invoices with no client only pay their own invoice',
    () async {
      final x = await invoice('x', 500, project: 'A', client: null, day: 3);
      final y = await invoice('y', 500, project: 'A', client: null, day: 4);
      await receive('py', 500, day: 5, invoiceId: 'y');
      expect(repo.balanceOf(x), 500);
      expect(repo.balanceOf(y), 0);
    },
  );

  test('an advance that paid a contract invoice stops counting on its '
      'instalment once the instalment has its own invoice', () async {
    final q = await contract();
    await receive('adv', 3000, day: 2, quotationId: 'q', termIndex: 0);
    final plain = await invoice('plain', 3000, project: 'A', day: 3);
    expect(repo.balanceOf(plain), 0);
    expect(repo.termStatus(q, 0).received, closeTo(3000, 1e-6));
    clock.now = DateTime(2026, 10, 4, 9);
    final own = repo.invoiceForTerm(q, 0);
    await repo.saveInvoice(own.copyWith(status: InvoiceStatus.sent));
    clock.now = DateTime(2026, 10, 20, 9);
    expect(repo.balanceOf(repo.invoice(own.id)!), closeTo(3000, 1e-6));
    expect(repo.termStatus(q, 0).received, closeTo(0, 1e-6));
    expect(repo.termStatus(q, 0).settled, isFalse);
  });

  group('receipt notes', () {
    test(
      'an advance that paid a contract invoice is not called credit',
      () async {
        final q = await contract();
        clock.now = DateTime(2026, 10, 2, 9);
        final first = repo.invoiceForTerm(q, 0);
        await repo.saveInvoice(first.copyWith(status: InvoiceStatus.sent));
        clock.now = DateTime(2026, 10, 20, 9);
        await receive('onFirst', 3000, day: 3, invoiceId: first.id);
        await invoice('plain', 500, project: 'A', day: 4);
        final pay = await receive(
          'adv',
          500,
          day: 6,
          quotationId: 'q',
          termIndex: 0,
        );
        expect(repo.unappliedOf(pay), 0);
        final note = receiptNote(repo, pay);
        expect(note, contains('This instalment is now fully paid.'));
        expect(note, contains(r'so $500.00 of this receipt went to INV-'));
        expect(note, isNot(contains('held as credit')));
      },
    );

    test('part of an instalment receipt settles an older invoice, the rest '
        'stays on the instalment', () async {
      final q = await contract();
      clock.now = DateTime(2026, 10, 5, 9);
      final first = repo.invoiceForTerm(q, 0);
      await repo.saveInvoice(first.copyWith(status: InvoiceStatus.sent));
      clock.now = DateTime(2026, 10, 20, 9);
      final pay = await receive(
        'rest',
        7000,
        day: 10,
        quotationId: 'q',
        termIndex: 1,
      );
      final note = receiptNote(repo, pay);
      expect(note, contains(r'Remaining on this instalment: $3,000.00.'));
      expect(
        note,
        contains('so \$3,000.00 of this receipt went to ${first.number}.'),
      );
      expect(note, isNot(contains('held as credit')));
    });

    test('money above an instalment is held as credit', () async {
      await contract();
      final pay = await receive(
        'adv',
        3500,
        day: 5,
        quotationId: 'q',
        termIndex: 0,
      );
      final note = receiptNote(repo, pay);
      expect(note, contains('This instalment is now fully paid.'));
      expect(note, contains(r'The extra $500.00 is held as credit'));
    });

    test('a receipt dated before its invoice still pays it', () async {
      final inv = await invoice('later', 1000, project: 'A', day: 20);
      final pay = await receive('early', 1000, day: 18, invoiceId: 'later');
      expect(repo.balanceOf(inv), 0);
      final note = receiptNote(repo, pay);
      expect(note, contains('${inv.number} is now fully paid.'));
      expect(note, isNot(contains('held as credit')));
    });

    test(
      'a receipt on a cancelled invoice goes to the open invoices',
      () async {
        final open = await invoice('open', 400, project: 'A', day: 1);
        final gone = await invoice('gone', 1000, project: 'A', day: 2);
        await repo.saveInvoice(gone.copyWith(status: InvoiceStatus.cancelled));
        final pay = await receive('p', 1000, day: 5, invoiceId: 'gone');
        final note = receiptNote(repo, pay);
        expect(note, contains('${gone.number} is cancelled'));
        expect(
          note,
          contains(
            r'so $400.00 of this receipt went to '
            '${open.number}.',
          ),
        );
        expect(note, contains(r'The extra $600.00 is held as credit'));
      },
    );
  });
}
