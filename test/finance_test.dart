import 'package:ak_system/data/advisor.dart';
import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/data/statement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:io';

import 'helpers.dart';

void main() {
  late TestClock clock;
  late Repository repo;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 14, 9));
    repo = await memoryRepo(clock);
  });

  Future<Project> project() async {
    final t = repo.now();
    final c = Client(id: repo.newId(), createdAt: t, updatedAt: t, name: 'N');
    await repo.saveClient(c);
    final pr = Project(
      id: repo.newId(),
      createdAt: t,
      updatedAt: t,
      code: repo.nextProjectCode(),
      name: 'Villa',
      clientId: c.id,
    );
    await repo.saveProject(pr);
    return pr;
  }

  Quotation quote(Project pr, {QuotationStatus s = QuotationStatus.draft}) {
    final t = repo.now();
    return Quotation(
      id: repo.newId(),
      createdAt: t,
      updatedAt: t,
      number: repo.nextQuotationNumber(),
      clientId: pr.clientId,
      projectId: pr.id,
      date: t,
      items: const [
        LineItem(description: 'Concept', rate: 3000),
        LineItem(description: 'Visits', quantity: 4, unit: 'visit', rate: 250),
      ],
      discount: 1000,
      status: s,
    );
  }

  test('totals: subtotal, discount, 11% VAT', () async {
    final q = quote(await project());
    expect(q.subtotal, 4000);
    expect(q.net, 3000);
    expect(q.vat, closeTo(330, 1e-9));
    expect(q.total, closeTo(3330, 1e-9));
  });

  test('line items survive the database round trip', () async {
    final q = quote(await project());
    await repo.saveQuotation(q);
    final back = repo.quotation(q.id)!;
    expect(back.items.map((i) => i.description), ['Concept', 'Visits']);
    expect(back.items[1].quantity, 4);
    expect(back.total, closeTo(3330, 1e-9));
  });

  test('cost-plus fee is added on top of cost, before VAT', () async {
    final q = quote(await project()).copyWith(markupRate: 15);
    expect(q.subtotal, 4000);
    expect(q.markup, 600);
    expect(q.net, 3600);
    expect(q.total, closeTo(3996, 1e-9));
  });

  test('sections and the fee survive saving and invoicing', () async {
    final pr = await project();
    final q = quote(pr).copyWith(
      markupRate: 20,
      showMarkup: false,
      items: const [
        LineItem(
          description: 'Block wall',
          unit: 'm²',
          quantity: 10,
          rate: 18,
          section: 'Masonry',
        ),
      ],
    );
    await repo.saveQuotation(q);
    final back = repo.quotation(q.id)!;
    expect(back.items.single.section, 'Masonry');
    expect(back.markupRate, 20);
    expect(back.showMarkup, isFalse);
    final inv = repo.invoiceFromQuotation(back);
    expect(inv.markupRate, 20);
    expect(inv.showMarkup, isFalse);
    expect(inv.total, closeTo(back.total, 1e-9));
  });

  test('statement of account: running balance, opening and aging', () async {
    final pr = await project();
    final t = repo.now();
    Invoice inv(String n, DateTime d, double amount, {bool draft = false}) =>
        Invoice(
          id: repo.newId(),
          createdAt: t,
          updatedAt: t,
          number: n,
          clientId: pr.clientId,
          projectId: pr.id,
          date: d,
          dueDate: d.add(const Duration(days: 14)),
          vatRate: 0,
          status: draft ? InvoiceStatus.draft : InvoiceStatus.sent,
          items: [LineItem(description: 'Fee', rate: amount)],
        );
    final a = inv('INV-1', DateTime(2026, 6, 1), 1000);
    final b = inv('INV-2', DateTime(2026, 9, 1), 2000);
    final c = inv('INV-3', DateTime(2026, 10, 1), 500, draft: true);
    for (final i in [a, b, c]) {
      await repo.saveInvoice(i);
    }
    Future<void> pay(Invoice i, DateTime d, double v) => repo.savePayment(
      Payment(
        id: repo.newId(),
        createdAt: t,
        updatedAt: t,
        invoiceId: i.id,
        date: d,
        amount: v,
      ),
    );
    await pay(a, DateTime(2026, 6, 20), 1000);
    await pay(b, DateTime(2026, 9, 10), 500);

    final all = buildStatement(repo, pr.clientId!);
    expect(all.lines.map((l) => l.balance), [1000, 0, 2000, 1500]);
    expect(all.invoiced, 3000); // the draft is left out
    expect(all.closing, 1500);
    expect(all.open.single.invoice.number, 'INV-2');
    // Due 15 Sep, statement on 14 Oct: 29 days late.
    expect(all.open.single.daysOverdue, 29);
    expect(all.aging, [0, 1500, 0, 0, 0]);

    final fromJuly = buildStatement(
      repo,
      pr.clientId!,
      from: DateTime(2026, 7, 1),
    );
    expect(fromJuly.opening, 0);
    expect(fromJuly.lines, hasLength(2));
    final fromSept5 = buildStatement(
      repo,
      pr.clientId!,
      from: DateTime(2026, 9, 5),
    );
    expect(fromSept5.opening, 2000);
    expect(fromSept5.closing, 1500);
  });

  test('numbers count up per year: QT-26-001, INV-26-001', () async {
    final pr = await project();
    expect(repo.nextQuotationNumber(), 'QT-26-001');
    await repo.saveQuotation(quote(pr));
    expect(repo.nextQuotationNumber(), 'QT-26-002');
    expect(repo.nextInvoiceNumber(), 'INV-26-001');
  });

  test('payments move an invoice from unpaid to part paid to paid', () async {
    final pr = await project();
    final q = quote(pr, s: QuotationStatus.accepted);
    await repo.saveQuotation(q);
    var inv = repo.invoiceFromQuotation(q);
    expect(inv.items, hasLength(2));
    expect(repo.paymentState(inv), PaymentState.draft);
    inv = inv.copyWith(status: InvoiceStatus.sent);
    await repo.saveInvoice(inv);
    expect(repo.paymentState(inv), PaymentState.unpaid);

    Future<void> pay(double amount) {
      final t = repo.now();
      return repo.savePayment(
        Payment(
          id: repo.newId(),
          createdAt: t,
          updatedAt: t,
          invoiceId: inv.id,
          date: t,
          amount: amount,
        ),
      );
    }

    await pay(1000);
    expect(repo.paymentState(inv), PaymentState.partlyPaid);
    expect(repo.balanceOf(inv), closeTo(2330, 1e-9));
    clock.advance(const Duration(days: 20));
    expect(repo.paymentState(inv), PaymentState.overdue);
    await pay(2330);
    expect(repo.paymentState(inv), PaymentState.paid);

    final m = repo.money(projectId: pr.id);
    expect(m.quoted, closeTo(3330, 1e-9));
    expect(m.invoiced, closeTo(3330, 1e-9));
    expect(m.received, closeTo(3330, 1e-9));
    expect(m.outstanding, closeTo(0, 1e-9));
  });

  test('deleting an invoice keeps its receipts on account', () async {
    final pr = await project();
    final inv = repo
        .invoiceFromQuotation(quote(pr))
        .copyWith(status: InvoiceStatus.sent);
    await repo.saveInvoice(inv);
    final t = repo.now();
    await repo.savePayment(
      Payment(
        id: repo.newId(),
        createdAt: t,
        updatedAt: t,
        invoiceId: inv.id,
        date: t,
        amount: 10,
      ),
    );
    await repo.deleteInvoice(inv);
    expect(repo.invoices, isEmpty);
    final kept = repo.payments.single;
    expect(kept.onInvoice, isFalse);
    expect(kept.clientId, inv.clientId);
    expect(kept.projectId, inv.projectId);
    expect(kept.notes, 'Was on ${inv.number}');
    expect(repo.unappliedOf(kept), 10);
  });

  test('the advisor flags a project with no deadline or quotation', () async {
    final pr = await project();
    final titles = reviewOffice(repo, projectId: pr.id).map((a) => a.title);
    expect(titles, contains('No deadline'));
    expect(titles, contains('No quotation'));
    expect(titles, contains('No open tasks'));
  });

  test('upgrading a version 2 database keeps the data', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('akdb');
    final path = p.join(dir.path, 'ak.db');
    final f = databaseFactoryFfiNoIsolate;
    final old = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          for (final e in syncedTables.entries) {
            if (financeTables.contains(e.key)) continue;
            // Strip the columns added in versions 3 and 4.
            var cols = e.value;
            if (e.key == 'stages') cols = cols.replaceAll(', service TEXT', '');
            cols = cols
                .replaceAll(', map_link TEXT', '')
                .replaceAll(', markup_rate REAL', '');
            await db.execute(
              'CREATE TABLE ${e.key} (id TEXT PRIMARY KEY, created_at TEXT '
              'NOT NULL, updated_at TEXT NOT NULL, deleted INTEGER NOT NULL '
              'DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, $cols)',
            );
          }
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.insert('stages', {
            'id': 's1',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'name': 'Brief',
            'position': 0,
          });
          await db.insert('projects', {
            'id': 'p1',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'name': 'Old villa',
            'stage_id': 's1',
          });
        },
      ),
    );
    await old.close();

    final local = await LocalDb.open(path, factory: f);
    final r = Repository(local, clock: () => clock.now);
    await r.load();
    expect(r.project('p1')!.name, 'Old villa');
    expect(r.stage('s1')!.service, ServiceType.design);
    // Design already had stages, so only the other services are seeded.
    expect(r.stagesFor(ServiceType.design), hasLength(1));
    expect(r.stagesFor(ServiceType.contracting), isNotEmpty);
    expect(r.quotations, isEmpty);
    // Version 4 columns were added on the way up.
    await r.saveProject(r.project('p1')!.copyWith(markupRate: 15));
    expect(r.project('p1')!.markupRate, 15);
    await local.close();
    await dir.delete(recursive: true);
  });
}
