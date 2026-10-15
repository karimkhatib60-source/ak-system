import 'dart:io';
import 'dart:typed_data';

import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/profit.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

void main() {
  late Repository repo;
  late DateTime t;

  setUp(() async {
    repo = await memoryRepo(TestClock(DateTime(2026, 10, 15, 9)));
    t = repo.now();
    await repo.saveClient(
      Client(id: 'c', createdAt: t, updatedAt: t, name: 'A'),
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

  const tiles = [
    LineItem(description: 'Tiles', unit: 'm²', quantity: 320, rate: 22),
    LineItem(description: 'Adhesive', unit: 'bag', quantity: 180, rate: 6.5),
  ];

  Expense bill({
    String id = 'e1',
    List<LineItem> items = tiles,
    double vat = 11,
    double? amount,
    bool paid = true,
  }) => Expense(
    id: id,
    createdAt: t,
    updatedAt: t,
    projectId: 'p',
    date: t,
    category: ExpenseCategory.materials,
    vendor: 'Ceramica',
    reference: 'CL-1',
    items: items,
    vatRate: vat,
    amount: amount ?? Expense.totalOf(items, vat),
    paid: paid,
  );

  test('a bill entered line by line adds up, with VAT', () {
    final e = bill();
    expect(e.net, 8210);
    expect(e.vat, closeTo(903.10, 1e-9));
    expect(e.amount, closeTo(9113.10, 1e-9));
  });

  test('a total with VAT is split into cost and VAT', () {
    final e = bill(items: const [], amount: 1110);
    expect(e.net, 1000);
    expect(e.vat, closeTo(110, 1e-9));
    // Without VAT the whole amount is cost.
    expect(bill(items: const [], vat: 0, amount: 500).net, 500);
  });

  test('expenses are numbered and keep their lines', () async {
    await repo.saveExpense(bill());
    await repo.saveExpense(bill(id: 'e2', vat: 0));
    final e = repo.expenses.firstWhere((x) => x.id == 'e1');
    expect(e.number, 'EXP-26-001');
    expect(repo.expenses.firstWhere((x) => x.id == 'e2').number, 'EXP-26-002');
    expect(e.items.map((i) => i.description), ['Tiles', 'Adhesive']);
    expect(e.reference, 'CL-1');
    expect(e.paid, isTrue);
    // Saving again keeps the number.
    await repo.saveExpense(e.copyWith(paid: false));
    final again = repo.expenses.firstWhere((x) => x.id == 'e1');
    expect(again.number, 'EXP-26-001');
    expect(again.paid, isFalse);
  });

  test('an expense from before this version reads as paid', () {
    final e = Expense.fromMap({
      'id': 'old',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'date': '2026-01-01',
      'category': 'subcontractor',
      'amount': 2400.0,
      'vendor': 'Tiling team',
    });
    expect(e.paid, isTrue);
    expect(e.items, isEmpty);
    expect(e.net, 2400);
    expect(e.number, '');
  });

  test('profit counts cost without VAT; cash counts what was paid', () async {
    await repo.saveInvoice(
      Invoice(
        id: 'i',
        createdAt: t,
        updatedAt: t,
        number: 'INV-26-001',
        clientId: 'c',
        projectId: 'p',
        date: t,
        status: InvoiceStatus.sent,
        items: const [LineItem(description: 'Works', rate: 20000)],
      ),
    );
    await repo.saveExpense(bill()); // 8,210 + 903.10 VAT, paid
    await repo.saveExpense(
      bill(id: 'e2', items: const [], vat: 0, amount: 1000, paid: false),
    );
    final f = profitOf(repo, projectId: 'p');
    expect(f.expenses, closeTo(9210, 1e-9));
    expect(f.expenseVat, closeTo(903.10, 1e-9));
    expect(f.profit, closeTo(20000 - 9210, 1e-9));
    expect(f.netVat, closeTo(2200 - 903.10, 1e-9));
    expect(f.paidOut, closeTo(9113.10, 1e-9));
    expect(f.unpaidBills, 1000);
    final m = repo.money(projectId: 'p');
    expect(m.expenses, closeTo(9210, 1e-9));
    expect(m.profit, closeTo(f.profit, 1e-9));
    expect(m.unpaidBills, 1000);
    expect(m.cash, closeTo(0 - 9113.10, 1e-9));
  });

  test('the client side: left to invoice and still to receive', () {
    const m = MoneySummary(
      quoted: 10000,
      invoiced: 6000,
      received: 4000,
      expenses: 0,
      overdue: 0,
      outstanding: 2000,
    );
    expect(m.leftToInvoice, 4000);
    expect(m.leftToReceive, 6000);
    // Extras invoiced above the contract are still to receive.
    const extra = MoneySummary(
      quoted: 10000,
      invoiced: 12000,
      received: 11000,
      expenses: 0,
      overdue: 0,
      outstanding: 1000,
    );
    expect(extra.leftToInvoice, 0);
    expect(extra.leftToReceive, 1000);
  });

  test('the supplier invoice is kept with the expense', () async {
    final bytes = Uint8List.fromList(List.generate(2000, (i) => i % 256));
    final a = Attachment(
      id: 'a1',
      createdAt: t,
      updatedAt: t,
      ownerId: 'e1',
      name: 'CL-1.pdf',
      mime: mimeOf('CL-1.pdf'),
      size: bytes.length,
    );
    await repo.saveExpense(bill(), attach: [(a, bytes)]);
    expect(repo.attachmentsOf('e1').single.name, 'CL-1.pdf');
    expect(repo.attachmentsOf('e1').single.isPdf, isTrue);
    expect(await repo.attachmentBytes('a1'), bytes);
    // Removing the file.
    await repo.saveExpense(
      repo.expenses.single,
      detach: [repo.attachmentsOf('e1').single],
    );
    expect(repo.attachmentsOf('e1'), isEmpty);
    // Deleting an expense deletes its files.
    await repo.saveExpense(
      repo.expenses.single,
      attach: [
        (
          Attachment(
            id: 'a2',
            createdAt: t,
            updatedAt: t,
            ownerId: 'e1',
            name: 'photo.jpg',
            mime: mimeOf('photo.jpg'),
            size: 3,
          ),
          Uint8List.fromList([1, 2, 3]),
        ),
      ],
    );
    expect(repo.attachmentsOf('e1').single.isImage, isTrue);
    await repo.deleteExpense(repo.expenses.single);
    expect(repo.expenses, isEmpty);
    expect(repo.attachmentsOf('e1'), isEmpty);
  });

  test('expenses and their files sync as owner-only money tables', () async {
    expect(financeTables, containsAll(['expenses', 'attachments']));
    final row = SyncService.toRemote({
      ...bill(paid: false).toMap(),
      'dirty': 1,
    });
    expect(row['paid'], false);
    expect(row.containsKey('dirty'), isFalse);
    expect(SyncService.fromRemote({...row, 'synced_at': 'x'})['paid'], 0);
  });

  test('upgrading a version 6 database keeps expenses', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('akdb6');
    final path = p.join(dir.path, 'ak.db');
    final f = databaseFactoryFfiNoIsolate;
    final old = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, _) async {
          for (final e in syncedTables.entries) {
            if (e.key == 'attachments') continue;
            var cols = e.value;
            if (e.key == 'expenses') {
              cols =
                  'project_id TEXT, date TEXT, category TEXT, amount REAL, '
                  'vendor TEXT, notes TEXT';
            }
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
            'id': 'x1',
            'created_at': '2026-01-01T00:00:00Z',
            'updated_at': '2026-01-01T00:00:00Z',
            'date': '2026-01-02',
            'category': 'materials',
            'amount': 750.0,
            'vendor': 'Hardware store',
          });
        },
      ),
    );
    await old.close();
    final local = await LocalDb.open(path, factory: f);
    final r = Repository(local, clock: () => t);
    await r.load();
    final e = r.expenses.single;
    expect(e.vendor, 'Hardware store');
    expect(e.amount, 750);
    expect(e.paid, isTrue);
    expect(r.attachments, isEmpty);
    // The new columns and table work after the upgrade.
    await r.saveExpense(
      Expense(
        id: 'x2',
        createdAt: t,
        updatedAt: t,
        date: t,
        reference: 'B-7',
        items: const [LineItem(description: 'Nails', quantity: 2, rate: 5)],
        amount: 10,
        paid: false,
      ),
      attach: [
        (
          Attachment(
            id: 'f1',
            createdAt: t,
            updatedAt: t,
            ownerId: 'x2',
            name: 'b7.png',
            mime: 'image/png',
            size: 1,
          ),
          Uint8List.fromList([9]),
        ),
      ],
    );
    expect(r.expenses.firstWhere((x) => x.id == 'x2').reference, 'B-7');
    expect(r.attachmentsOf('x2'), hasLength(1));
    await local.close();
    await dir.delete(recursive: true);
  });
}
