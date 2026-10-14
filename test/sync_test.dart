import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<String> addProject(Repository repo, String name) async {
  final t = repo.now();
  final id = repo.newId();
  await repo.saveProject(
      Project(id: id, createdAt: t, updatedAt: t, name: name));
  return id;
}

void main() {
  late TestClock clock;
  late FakeRemote cloud;
  late Repository phone, laptop;
  late SyncService phoneSync, laptopSync;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 14, 9));
    cloud = FakeRemote();
    phone = await memoryRepo(clock);
    laptop = await memoryRepo(clock);
    phoneSync = SyncService(phone.local, phone)..remote = cloud;
    laptopSync = SyncService(laptop.local, laptop)..remote = cloud;
  });

  test('work done offline on the phone appears on the laptop', () async {
    cloud.offline = true;
    await addProject(phone, 'Villa Batroun');
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.offline);

    cloud.offline = false;
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.idle);
    await laptopSync.syncNow();
    expect(laptop.projects.map((p) => p.name), ['Villa Batroun']);
  });

  test('stages are not duplicated across devices', () async {
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    expect(laptop.stages, hasLength(8));
    expect(cloud.tables['stages'], hasLength(8));
  });

  test('the most recent edit wins when both devices change a row', () async {
    final id = await addProject(phone, 'Office fit-out');
    await phoneSync.syncNow();
    await laptopSync.syncNow();

    clock.advance(const Duration(minutes: 1));
    await phone.saveProject(phone.project(id)!.copyWith(name: 'Phone name'));
    clock.advance(const Duration(minutes: 1));
    await laptop.saveProject(laptop.project(id)!.copyWith(name: 'Laptop name'));

    await phoneSync.syncNow();
    await laptopSync.syncNow(); // laptop's newer edit overwrites the cloud
    await phoneSync.syncNow();
    expect(phone.project(id)!.name, 'Laptop name');
    expect(laptop.project(id)!.name, 'Laptop name');
  });

  test('a newer local edit is not overwritten by an older cloud copy',
      () async {
    final id = await addProject(phone, 'A');
    await phoneSync.syncNow();
    await laptopSync.syncNow();

    clock.advance(const Duration(minutes: 1));
    await laptop.saveProject(laptop.project(id)!.copyWith(name: 'Old'));
    await laptopSync.syncNow();
    clock.advance(const Duration(minutes: 1));
    await phone.saveProject(phone.project(id)!.copyWith(name: 'New'));

    // Phone pulls before pushing: its own newer edit must survive.
    phone.onLocalChange = null;
    await phoneSync.syncNow();
    expect(phone.project(id)!.name, 'New');
  });

  test('deletes sync too', () async {
    final id = await addProject(phone, 'Temp');
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    expect(laptop.projects, hasLength(1));

    clock.advance(const Duration(minutes: 1));
    await phone.deleteProject(phone.project(id)!);
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    expect(laptop.projects, isEmpty);
  });

  test('an architect does not upload projects, only tasks', () async {
    final t = phone.now();
    await phone.saveMember(Member(
        id: 'arch', createdAt: t, updatedAt: t, name: 'A'));
    await phone.setCurrentMember('arch');
    final pid = await addProject(phone, 'Not allowed');
    await phone.saveTask(Task(
        id: phone.newId(),
        createdAt: t,
        updatedAt: t,
        projectId: pid,
        title: 'Allowed'));
    await phoneSync.syncNow();
    expect(phoneSync.state, SyncState.idle);
    expect(cloud.tables['projects'], isNull);
    expect(cloud.tables['tasks'], hasLength(1));
  });

  test('booleans are converted for the cloud and back', () {
    final out = SyncService.toRemote({'id': 'x', 'deleted': 1, 'abroad': 0, 'dirty': 1});
    expect(out, {'id': 'x', 'deleted': true, 'abroad': false});
    final back = SyncService.fromRemote({
      'id': 'x',
      'deleted': false,
      'synced_at': '2030-01-01T00:00:00Z',
      'updated_at': '2026-10-14T09:00:00+00:00',
    });
    expect(back['deleted'], 0);
    expect(back.containsKey('synced_at'), isFalse);
    expect(back['updated_at'], '2026-10-14T09:00:00.000Z');
  });
}
