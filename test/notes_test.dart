import 'dart:io';

import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'helpers.dart';

/// Dated notes kept with each project.
void main() {
  late TestClock clock;
  late Repository repo;
  late DateTime t;

  setUp(() async {
    clock = TestClock(DateTime(2026, 10, 17, 9));
    repo = await memoryRepo(clock);
    t = repo.now();
    for (final id in ['A', 'B']) {
      await repo.saveProject(
        Project(
          id: id,
          createdAt: t,
          updatedAt: t,
          name: 'Project $id',
          teamIds: id == 'A' ? const ['arch'] : const [],
        ),
      );
    }
  });

  Future<ProjectNote> note(
    String id,
    String text, {
    String project = 'A',
    int day = 10,
    bool pinned = false,
    bool ownerOnly = false,
    NoteKind kind = NoteKind.general,
  }) async {
    await repo.saveNote(
      ProjectNote(
        id: id,
        createdAt: t,
        updatedAt: t,
        projectId: project,
        date: DateTime(2026, 10, day),
        kind: kind,
        text: text,
        pinned: pinned,
        ownerOnly: ownerOnly,
      ),
    );
    return repo.notes.firstWhere((n) => n.id == id);
  }

  Future<void> asArchitect() async {
    await repo.saveMember(
      Member(
        id: 'arch',
        createdAt: t,
        updatedAt: t,
        name: 'Rami',
        role: MemberRole.architect,
      ),
    );
    await repo.setCurrentMember('arch');
  }

  test('pinned notes come first, then the newest day', () async {
    await note('old', 'Kick-off meeting', day: 2);
    await note('new', 'Site visit\nSlab poured on level 1', day: 12);
    await note('pin', 'Client wants oak floors', day: 1, pinned: true);
    await note('other', 'Elsewhere', project: 'B', day: 15);
    expect(repo.notesFor('A').map((n) => n.id), ['pin', 'new', 'old']);
    final n = repo.notes.firstWhere((n) => n.id == 'new');
    expect(n.heading, 'Site visit');
    expect(n.body, 'Slab poured on level 1');
  });

  test('a note keeps its kind, day and flags after a reload', () async {
    await note(
      'm',
      'Meeting with the client',
      kind: NoteKind.meeting,
      day: 14,
      pinned: true,
      ownerOnly: true,
    );
    await repo.reload();
    final n = repo.notes.single;
    expect(n.kind, NoteKind.meeting);
    expect(n.date, DateTime(2026, 10, 14));
    expect(n.pinned, isTrue);
    expect(n.ownerOnly, isTrue);
  });

  test('deleting a note hides it', () async {
    final n = await note('x', 'Draft');
    await repo.deleteNote(n);
    expect(repo.notesFor('A'), isEmpty);
  });

  test('the team sees shared notes of their projects only', () async {
    await note('shared', 'Shared with the team');
    await note('mine', 'Fee discussion', ownerOnly: true);
    await note('b', 'Another project', project: 'B');
    expect(repo.notesFor('A'), hasLength(2));
    await asArchitect();
    expect(repo.notesFor('A').map((n) => n.id), ['shared']);
    expect(repo.notesFor('B'), isEmpty);
    expect(repo.canEditNote(repo.notesFor('A').single), isTrue);
    expect(
      repo.canEditNote(repo.notes.firstWhere((n) => n.id == 'mine')),
      isFalse,
    );
  });

  test('deleting a project deletes its notes', () async {
    await note('a1', 'On A');
    await note('b1', 'On B', project: 'B');
    await repo.deleteProject(repo.project('A')!);
    expect(repo.notes.map((n) => n.id), ['b1']);
  });

  group('the old notes field', () {
    Future<void> oldNotes(String id, String text) => repo.local.save(
      'projects',
      Project(
        id: id,
        createdAt: DateTime.utc(2026, 9, 1),
        updatedAt: DateTime.utc(2026, 9, 3),
        name: 'Old $id',
        notes: text,
      ).toMap(),
    );

    test('becomes the project\'s first note, once', () async {
      await oldNotes('C', '  Client prefers stone cladding  ');
      await repo.load();
      final n = repo.notesFor('C').single;
      expect(n.text, 'Client prefers stone cladding');
      expect(n.date, DateTime.utc(2026, 9, 1));
      expect(n.kind, NoteKind.general);
      expect(repo.project('C')!.notes, '');
      await repo.load();
      expect(repo.notesFor('C'), hasLength(1));
    });

    test('gives the same note on every device', () async {
      final other = await memoryRepo(clock);
      for (final r in [repo, other]) {
        await r.local.save(
          'projects',
          Project(
            id: 'C',
            createdAt: DateTime.utc(2026, 9, 1),
            updatedAt: DateTime.utc(2026, 9, 3),
            name: 'Old C',
            notes: 'Same text',
          ).toMap(),
        );
        await r.load();
      }
      final a = repo.notesFor('C').single, b = other.notesFor('C').single;
      expect(a.id, b.id);
      expect(a.toMap(), b.toMap());
    });

    test('is left alone on an architect\'s device', () async {
      await asArchitect();
      await oldNotes('C', 'Owner text');
      await repo.load();
      expect(repo.notes, isEmpty);
      expect(repo.project('C')!.notes, 'Owner text');
    });
  });

  test('an architect uploads their notes, never projects', () async {
    final cloud = FakeRemote();
    final sync = SyncService(repo.local, repo)..remote = cloud;
    await asArchitect();
    await note('site', 'Site visit: rebar checked');
    await sync.syncNow();
    expect(cloud.tables['project_notes']!.keys, ['site']);
    expect(cloud.tables['projects'], isNull);
  });

  test('notes reach the other device', () async {
    final cloud = FakeRemote();
    final laptop = await memoryRepo(clock);
    final phoneSync = SyncService(repo.local, repo)..remote = cloud;
    final laptopSync = SyncService(laptop.local, laptop)..remote = cloud;
    await note('n', 'Decided on the facade colour', pinned: true);
    await phoneSync.syncNow();
    await laptopSync.syncNow();
    final n = laptop.notes.single;
    expect(n.text, 'Decided on the facade colour');
    expect(n.pinned, isTrue);
    expect(n.ownerOnly, isFalse);
  });

  test('pinned and owner-only are true or false in the cloud', () {
    final row = SyncService.toRemote({
      'id': 'n',
      'pinned': 1,
      'owner_only': 0,
      'dirty': 1,
    });
    expect(row['pinned'], true);
    expect(row['owner_only'], false);
    final back = SyncService.fromRemote({...row, 'synced_at': 'x'});
    expect(back['pinned'], 1);
    expect(back['owner_only'], 0);
  });

  test('upgrading a version 7 database adds notes and moves old ones', () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('akdb7');
    final path = p.join(dir.path, 'ak.db');
    final f = databaseFactoryFfiNoIsolate;
    final old = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, _) async {
          for (final e in syncedTables.entries) {
            if (e.key == 'project_notes') continue;
            await db.execute(
              'CREATE TABLE ${e.key} (id TEXT PRIMARY KEY, created_at TEXT '
              'NOT NULL, updated_at TEXT NOT NULL, deleted INTEGER NOT NULL '
              'DEFAULT 0, dirty INTEGER NOT NULL DEFAULT 1, ${e.value})',
            );
          }
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.insert('projects', {
            'id': 'P',
            'created_at': '2026-08-01T00:00:00.000Z',
            'updated_at': '2026-08-02T00:00:00.000Z',
            'name': 'Villa',
            'notes': 'Gate faces north',
          });
        },
      ),
    );
    await old.close();
    final r = Repository(await LocalDb.open(path, factory: f), clock: () => t);
    await r.load();
    expect(r.notesFor('P').single.text, 'Gate faces north');
    expect(r.project('P')!.notes, '');
    await r.saveNote(
      ProjectNote(
        id: 'n2',
        createdAt: t,
        updatedAt: t,
        projectId: 'P',
        date: t,
        text: 'Second note',
      ),
    );
    expect(r.notesFor('P'), hasLength(2));
    await r.local.db.close();
    await dir.delete(recursive: true);
  });
}
