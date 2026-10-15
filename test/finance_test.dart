import 'package:ak_system/data/advisor.dart';
import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
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

  test('deleting an invoice removes its payments', () async {
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
    expect(repo.payments, isEmpty);
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
            final cols = e.value
                .replaceAll(', service TEXT', '')
                .replaceAll(', map_link TEXT', '');
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
    await local.close();
    await dir.delete(recursive: true);
  });
}
