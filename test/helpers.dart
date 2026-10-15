import 'dart:typed_data';

import 'package:ak_system/data/db.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<LocalDb> memoryDb() async {
  sqfliteFfiInit();
  return LocalDb.open(
    inMemoryDatabasePath,
    factory: databaseFactoryFfiNoIsolate,
  );
}

/// A controllable clock for tests.
class TestClock {
  TestClock(this.now);
  DateTime now;
  void advance(Duration d) => now = now.add(d);
}

Future<Repository> memoryRepo(TestClock clock) async {
  final repo = Repository(await memoryDb(), clock: () => clock.now);
  await repo.load();
  return repo;
}

/// In-memory stand-in for the cloud database. Stamps synced_at with its own
/// clock like the real server trigger does.
class FakeRemote implements RemoteStore {
  final tables = <String, Map<String, Map<String, Object?>>>{};
  final files = <String, Uint8List>{};
  int _tick = 0;
  bool offline = false;

  /// Tables whose upload fails, as if the server refused it.
  final failing = <String>{};

  /// File uploads fail, as if the storage refused them.
  bool filesFail = false;

  @override
  Future<void> uploadFile(String path, Uint8List bytes, String mime) async {
    if (offline) throw const SocketExceptionLike();
    if (filesFail) throw Exception('413 Payload too large');
    files[path] = bytes;
  }

  @override
  Future<Uint8List?> downloadFile(String path) async {
    if (offline) throw const SocketExceptionLike();
    return files[path];
  }

  @override
  Future<void> removeFile(String path) async {
    if (offline) throw const SocketExceptionLike();
    files.remove(path);
  }

  String _stamp() => DateTime.utc(
    2030,
    1,
    1,
  ).add(Duration(seconds: ++_tick)).toIso8601String();

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    if (offline) throw const SocketExceptionLike();
    if (failing.contains(table)) throw Exception('500 refused $table');
    final t = tables.putIfAbsent(table, () => {});
    for (final r in rows) {
      t[r['id'] as String] = {...r, 'synced_at': _stamp()};
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(
    String table,
    String? since,
  ) async {
    if (offline) throw const SocketExceptionLike();
    final rows =
        (tables[table]?.values ?? const <Map<String, Object?>>[])
            .where(
              (r) =>
                  since == null ||
                  DateTime.parse(r['synced_at'] as String)
                      .isAfter(DateTime.parse(since)),
            )
            .toList()
          ..sort(
            (a, b) =>
                (a['synced_at'] as String).compareTo(b['synced_at'] as String),
          );
    return rows.map((r) => Map<String, Object?>.from(r)).toList();
  }
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: Failed host lookup';
}
