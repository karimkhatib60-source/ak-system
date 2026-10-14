import 'package:sqflite/sqflite.dart';

/// Tables that sync with the cloud, with their non-sync columns.
/// Every table also has: id, created_at, updated_at, deleted, dirty.
const syncedTables = <String, String>{
  'members': 'name TEXT, email TEXT, role TEXT',
  'stages': 'name TEXT, position INTEGER',
  'clients':
      'name TEXT, company TEXT, phone TEXT, email TEXT, country TEXT, notes TEXT',
  'projects': 'code TEXT, name TEXT, client_id TEXT, service TEXT, '
      'location TEXT, abroad INTEGER, stage_id TEXT, status TEXT, '
      'start_date TEXT, due_date TEXT, team_ids TEXT, notes TEXT',
  'tasks': 'project_id TEXT, title TEXT, assignee_id TEXT, due_date TEXT, '
      'status TEXT, priority TEXT, stage_id TEXT, notes TEXT',
  'deliverables': 'project_id TEXT, title TEXT, stage_id TEXT, '
      'version INTEGER, status TEXT, due_date TEXT, submitted_at TEXT, '
      'approved_at TEXT, file_link TEXT, notes TEXT',
};

/// Local SQLite store. Everything the app shows is read from here, so the app
/// works with no internet; the sync service copies changes to and from the
/// cloud when a connection is available.
class LocalDb {
  LocalDb(this.db);

  final Database db;

  static const _version = 1;

  static Future<LocalDb> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        // Each in-memory database (used in tests) is its own copy.
        singleInstance: path != inMemoryDatabasePath,
        onCreate: (db, _) async {
          for (final e in syncedTables.entries) {
            await db.execute('CREATE TABLE ${e.key} ('
                'id TEXT PRIMARY KEY, created_at TEXT NOT NULL, '
                'updated_at TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, '
                'dirty INTEGER NOT NULL DEFAULT 1, ${e.value})');
          }
          await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)');
          await db.execute('CREATE INDEX tasks_project ON tasks(project_id)');
          await db.execute(
              'CREATE INDEX deliverables_project ON deliverables(project_id)');
        },
      ),
    );
    return LocalDb(db);
  }

  Future<List<Map<String, Object?>>> all(String table) =>
      db.query(table, where: 'deleted = 0');

  /// Saves a record changed on this device and marks it for upload.
  Future<void> save(String table, Map<String, Object?> row) => db.insert(
        table,
        {...row, 'dirty': 1},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<Map<String, Object?>>> dirtyRows(String table) =>
      db.query(table, where: 'dirty = 1');

  /// Clears the upload flag, unless the row changed again since it was read.
  Future<void> markClean(String table, String id, String updatedAt) =>
      db.update(table, {'dirty': 0},
          where: 'id = ? AND updated_at = ?', whereArgs: [id, updatedAt]);

  Future<Map<String, Object?>?> byId(String table, String id) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Writes a row that came from the cloud. It is already in sync.
  Future<void> putRemote(String table, Map<String, Object?> row) => db.insert(
        table,
        {...row, 'dirty': 0},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<String?> getSetting(String key) async {
    final rows =
        await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) => db.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<void> close() => db.close();
}
