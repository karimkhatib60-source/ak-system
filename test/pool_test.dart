import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
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
}
