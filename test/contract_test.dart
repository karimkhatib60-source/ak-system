import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/profit.dart';
import 'package:ak_system/data/project_statement.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/ui/screens/finance_screen.dart';
import 'package:ak_system/ui/screens/profit_view.dart';
import 'package:ak_system/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late Repository repo;
  late DateTime t;

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 15, 9)));
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
      ),
    );
  });

  /// Approved QT-26-001: 10,000 + 11% VAT = 11,100, paid 30% then 70%.
  Future<Quotation> approved() async {
    final q = Quotation(
      id: 'q',
      createdAt: t,
      updatedAt: t,
      number: 'QT-26-001',
      clientId: 'c',
      projectId: 'p',
      date: t,
      status: QuotationStatus.accepted,
      items: const [LineItem(description: 'Works', rate: 10000)],
      paymentTerms: const [
        PaymentTerm(label: 'Advance', percent: 30),
        PaymentTerm(label: 'Rest', percent: 70),
      ],
    );
    await repo.saveQuotation(q);
    return q;
  }

  Future<Invoice> invoice(
    String id,
    double rate, {
    String? quotationId,
    bool extra = false,
    int day = 15,
  }) async {
    await repo.saveInvoice(
      Invoice(
        id: id,
        createdAt: t,
        updatedAt: t,
        number: repo.nextInvoiceNumber(),
        clientId: 'c',
        projectId: 'p',
        quotationId: quotationId,
        extra: extra,
        date: DateTime(2026, 10, day),
        status: InvoiceStatus.sent,
        items: [LineItem(description: 'Works', rate: rate)],
      ),
    );
    return repo.invoice(id)!;
  }

  Future<void> advance(double amount) => repo.savePayment(
    Payment(
      id: 'adv',
      createdAt: t,
      updatedAt: t,
      invoiceId: '',
      date: DateTime(2026, 10, 14),
      amount: amount,
      clientId: 'c',
      projectId: 'p',
      quotationId: 'q',
      termIndex: 0,
    ),
  );

  test('extra work is kept apart from the contract', () async {
    await approved();
    await invoice('i1', 3000, quotationId: 'q'); // 3,330 on the contract
    await invoice('i2', 2000, extra: true); // 2,220 extra work
    final m = repo.money(projectId: 'p');
    expect(m.quoted, closeTo(11100, 1e-9));
    expect(m.invoiced, closeTo(5550, 1e-9));
    expect(m.extras, closeTo(2220, 1e-9));
    expect(m.onContract, closeTo(3330, 1e-9));
    expect(m.leftToInvoice, closeTo(7770, 1e-9));
    // The contract and the extra work, nothing received yet.
    expect(m.leftToReceive, closeTo(13320, 1e-9));

    final f = profitOf(repo, projectId: 'p');
    expect(f.extrasNet, 2000);
    expect(f.leftToInvoice, closeTo(7000, 1e-9));
    expect(f.income, closeTo(12000, 1e-9));

    final st = buildProjectStatement(repo, 'p');
    expect(st.billedPercent, closeTo(30, 1e-9));
  });

  test('an invoice not linked to a quotation counts as contract', () async {
    await approved();
    await invoice('i1', 4000);
    final m = repo.money(projectId: 'p');
    expect(m.extras, 0);
    expect(m.leftToInvoice, closeTo(11100 - 4440, 1e-9));
  });

  test('the extra flag is saved and read back', () async {
    final i = await invoice('i1', 100, extra: true);
    expect(i.extra, isTrue);
    expect(Invoice.fromMap(i.toMap()).extra, isTrue);
    expect(Invoice.fromMap({...i.toMap(), 'extra': null}).extra, isFalse);
  });

  test('an advance is deducted from a blank invoice on the project', () async {
    await approved();
    await advance(3330);
    final inv = await invoice('i1', 3000); // no quotation linked
    expect(repo.balanceOf(inv), 0);
    final m = repo.money(projectId: 'p');
    expect(m.outstanding, 0);
    expect(m.advances, 0);
    expect(repo.termStatus(repo.quotation('q')!, 0).received, 3330);
  });

  test('an advance on the contract also settles extra work', () async {
    await approved();
    await advance(3330);
    final extra = await invoice('i1', 1000, extra: true);
    expect(repo.balanceOf(extra), 0);
    final m = repo.money(projectId: 'p');
    expect(m.advances, closeTo(2220, 1e-9));
    expect(m.outstanding, 0);
  });

  test('after approval the next step is the first invoice', () async {
    final q = await approved();
    String next() => projectNextStep(
      repo,
      repo.quotationsFor('p'),
      repo.invoicesFor('p'),
      repo.money(projectId: 'p'),
    );
    expect(next(), 'Raise the first invoice from ${q.number}.');
    await advance(3330);
    expect(
      next(),
      'Raise the first invoice from ${q.number}; the \$3,330.00 received '
      'in advance is deducted from it.',
    );
  });

  Future<void> pumpCard(WidgetTester tester, Profit f) => tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: SingleChildScrollView(child: ProfitCard(f))),
    ),
  );

  testWidgets('more VAT charged by suppliers is a VAT credit', (tester) async {
    await pumpCard(
      tester,
      const Profit(
        contractNet: 0,
        budgetCost: 0,
        revenue: 1000,
        vat: 110,
        expenses: 5000,
        expenseVat: 550,
        received: 0,
        unpaidBills: 5550,
      ),
    );
    final note = find.textContaining('VAT credit of \$440.00');
    expect(note, findsOneWidget);
    expect(find.textContaining('owed to the tax office'), findsNothing);
    expect(find.textContaining('charged by suppliers'), findsOneWidget);
    expect(find.textContaining('VAT included; the cost'), findsOneWidget);
    expect(find.text('Paid to suppliers'), findsNothing);
  });

  testWidgets('VAT owed and what was paid to suppliers', (tester) async {
    await pumpCard(
      tester,
      const Profit(
        contractNet: 0,
        budgetCost: 0,
        revenue: 10000,
        vat: 1100,
        expenses: 2000,
        expenseVat: 220,
        received: 11100,
        paidOut: 2220,
      ),
    );
    expect(
      find.textContaining('so \$880.00 is owed to the tax office'),
      findsOneWidget,
    );
    expect(find.text('Paid to suppliers'), findsOneWidget);
    expect(find.text('\$2,220.00'), findsOneWidget);
  });
}
