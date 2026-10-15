import 'dart:io';
import 'dart:typed_data';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/platform/file_store_io.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestClock clock;
  late FakeRemote cloud;
  late Repository phone, laptop;
  late SyncService phoneSync, laptopSync;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 15, 9));
    cloud = FakeRemote();
    phone = await memoryRepo(clock);
    laptop = await memoryRepo(clock);
    phoneSync = SyncService(phone.local, phone)..attach(cloud);
    laptopSync = SyncService(laptop.local, laptop)..attach(cloud);
    // Sync only when a test asks for it.
    phone.onLocalChange = null;
    laptop.onLocalChange = null;
  });

  tearDown(() {
    phoneSync.detach();
    laptopSync.detach();
  });

  Expense bill(Repository r, String id) => Expense(
    id: id,
    createdAt: r.now(),
    updatedAt: r.now(),
    date: r.now(),
    vendor: 'Ceramica',
    items: const [LineItem(description: 'Tiles', quantity: 10, rate: 20)],
    vatRate: 0,
    amount: 200,
  );

  (Attachment, Uint8List) file(Repository r, String id, String owner) {
    final bytes = Uint8List.fromList(List.generate(5000, (i) => i % 251));
    return (
      Attachment(
        id: id,
        createdAt: r.now(),
        updatedAt: r.now(),
        ownerId: owner,
        name: 'bill.pdf',
        mime: 'application/pdf',
        size: bytes.length,
      ),
      bytes,
    );
  }

  test('a supplier file goes to cloud storage, not the database', () async {
    final (a, bytes) = file(phone, 'f1', 'e1');
    await phone.saveExpense(bill(phone, 'e1'), attach: [(a, bytes)]);
    expect(await phone.local.pendingFiles(), {'f1'});
    final row = await phone.local.byId('attachments', 'f1');
    expect(row!.keys, isNot(contains('data')));

    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.idle);
    expect(cloud.files[cloudPathOf('f1')], bytes);
    expect(cloud.tables['attachments']!['f1']!['name'], 'bill.pdf');
    expect(await phone.local.pendingFiles(), isEmpty);

    // The laptop lists the file and fetches it the first time it opens.
    await laptopSync.syncNow();
    expect(laptop.attachmentsOf('e1').single.name, 'bill.pdf');
    expect(await laptop.files.get('f1'), isNull);
    expect(await laptop.attachmentBytes('f1'), bytes);
    expect(await laptop.files.get('f1'), bytes);
  });

  test('a file that fails to upload never blocks other changes', () async {
    cloud.filesFail = true;
    final (a, bytes) = file(phone, 'f1', 'e1');
    await phone.saveExpense(bill(phone, 'e1'), attach: [(a, bytes)]);
    final t = laptop.now();
    await laptop.saveProject(
      Project(id: 'np', createdAt: t, updatedAt: t, name: 'NewP'),
    );
    await laptopSync.syncNow();

    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.error);
    expect(phoneSync.lastError, contains('bill.pdf'));
    // The expense went up, the file's details wait for the file, and the
    // laptop's project still came down.
    expect(cloud.tables['expenses']!.keys, contains('e1'));
    expect(cloud.tables['attachments']?['f1'], isNull);
    expect(phone.projects.map((p) => p.name), contains('NewP'));
    expect(await phone.local.pendingFiles(), {'f1'});

    cloud.filesFail = false;
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.idle);
    expect(cloud.files[cloudPathOf('f1')], bytes);
    expect(cloud.tables['attachments']!['f1'], isNotNull);
  });

  test('one table the cloud refuses does not stop the rest', () async {
    cloud.failing.add('expenses');
    await phone.saveExpense(bill(phone, 'e1'));
    final t = laptop.now();
    await laptop.saveProject(
      Project(id: 'np', createdAt: t, updatedAt: t, name: 'NewP'),
    );
    await laptopSync.syncNow();
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.error);
    expect(phone.projects.map((p) => p.name), contains('NewP'));
    // Still waiting to go up, and goes up once the cloud accepts it.
    cloud.failing.clear();
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.idle);
    expect(cloud.tables['expenses']!.keys, contains('e1'));
  });

  test('deleting an expense removes its file everywhere', () async {
    final (a, bytes) = file(phone, 'f1', 'e1');
    await phone.saveExpense(bill(phone, 'e1'), attach: [(a, bytes)]);
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    expect(await laptop.attachmentBytes('f1'), bytes);

    clock.advance(const Duration(minutes: 1));
    await phone.deleteExpense(phone.expenses.single);
    expect(await phone.files.get('f1'), isNull);
    await phoneSync.syncNow();
    expect(cloud.files, isEmpty);
    await laptopSync.syncNow();
    expect(laptop.attachmentsOf('e1'), isEmpty);
    expect(await laptop.files.get('f1'), isNull);
  });

  test('a file removed before it was uploaded is never uploaded', () async {
    final (a, bytes) = file(phone, 'f1', 'e1');
    await phone.saveExpense(bill(phone, 'e1'), attach: [(a, bytes)]);
    await phone.saveExpense(
      phone.expenses.single,
      detach: [phone.attachmentsOf('e1').single],
    );
    await phoneSync.syncNow();
    expect(cloud.files, isEmpty);
    expect(cloud.tables['attachments']!['f1']!['deleted'], true);
  });

  test('numbers of deleted documents are never given again', () async {
    await phone.saveExpense(bill(phone, 'e1'));
    await phone.saveExpense(bill(phone, 'e2'));
    await phone.deleteExpense(phone.expenses.firstWhere((e) => e.id == 'e2'));
    await phone.saveExpense(bill(phone, 'e3'));
    expect(phone.expenses.firstWhere((e) => e.id == 'e3').number, 'EXP-26-003');
    final t = phone.now();
    await phone.saveInvoice(
      Invoice(
        id: 'i1',
        createdAt: t,
        updatedAt: t,
        number: 'INV-26-001',
        date: t,
      ),
    );
    await phone.deleteInvoice(phone.invoice('i1')!);
    expect(phone.nextInvoiceNumber(), 'INV-26-002');
  });

  test('two devices offline never keep the same expense number', () async {
    await phone.saveExpense(bill(phone, 'e1'));
    clock.advance(const Duration(minutes: 1));
    await laptop.saveExpense(bill(laptop, 'e2'));
    expect(laptop.expenses.single.number, 'EXP-26-001');

    await phoneSync.syncNow();
    await laptopSync.syncNow();
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    String numberOf(Repository r, String id) =>
        r.expenses.firstWhere((e) => e.id == id).number;
    for (final r in [phone, laptop]) {
      expect(numberOf(r, 'e1'), 'EXP-26-001');
      expect(numberOf(r, 'e2'), 'EXP-26-002');
    }
  });

  test('files on Android and Windows are kept in a folder', () async {
    final dir = await Directory.systemTemp.createTemp('akfiles');
    final store = FolderFileStore(dir);
    final bytes = Uint8List.fromList([1, 2, 3]);
    await store.put('abc-123', bytes);
    expect(await store.get('abc-123'), bytes);
    expect(await store.get('other'), isNull);
    await store.remove('abc-123');
    expect(await store.get('abc-123'), isNull);
    expect(() => store.put('../x', bytes), throwsArgumentError);
    await dir.delete(recursive: true);
  });
}
