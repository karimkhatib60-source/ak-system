import 'package:sqflite/sqflite.dart';

/// Tables that sync with the cloud, with their non-sync columns.
/// Every table also has: id, created_at, updated_at, deleted, dirty.
const syncedTables = <String, String>{
  'members': 'name TEXT, email TEXT, role TEXT',
  'stages': 'name TEXT, position INTEGER, service TEXT',
  'clients': 'name TEXT, company TEXT, phone TEXT, email TEXT, country TEXT, notes TEXT',
  'projects':
      'code TEXT, name TEXT, client_id TEXT, service TEXT, '
      'location TEXT, abroad INTEGER, stage_id TEXT, status TEXT, '
      'start_date TEXT, due_date TEXT, team_ids TEXT, notes TEXT, '
      'project_type TEXT, area_sqm REAL, map_link TEXT, markup_rate REAL',
  'tasks':
      'project_id TEXT, title TEXT, assignee_id TEXT, due_date TEXT, '
      'status TEXT, priority TEXT, stage_id TEXT, notes TEXT, category TEXT',
  'deliverables':
      'project_id TEXT, title TEXT, stage_id TEXT, '
      'version INTEGER, status TEXT, due_date TEXT, submitted_at TEXT, '
      'approved_at TEXT, file_link TEXT, notes TEXT, discipline TEXT, '
      'doc_type TEXT, doc_number INTEGER',
  'project_notes':
      'project_id TEXT, date TEXT, kind TEXT, text TEXT, author_id TEXT, '
      'pinned INTEGER, owner_only INTEGER',
  'quotations':
      'number TEXT, title TEXT, client_id TEXT, project_id TEXT, date TEXT, '
      'valid_until TEXT, items TEXT, discount REAL, vat_rate REAL, '
      'status TEXT, terms TEXT, notes TEXT, markup_rate REAL, '
      'show_markup INTEGER, payment_terms TEXT',
  'invoices':
      'number TEXT, title TEXT, client_id TEXT, project_id TEXT, '
      'quotation_id TEXT, date TEXT, due_date TEXT, items TEXT, '
      'discount REAL, vat_rate REAL, status TEXT, notes TEXT, '
      'markup_rate REAL, show_markup INTEGER, stage_id TEXT, '
      'term_index INTEGER, extra INTEGER',
  'payments':
      'invoice_id TEXT, date TEXT, amount REAL, method TEXT, reference TEXT, '
      'number TEXT, client_id TEXT, project_id TEXT, quotation_id TEXT, '
      'term_index INTEGER, notes TEXT',
  'expenses':
      'project_id TEXT, date TEXT, category TEXT, amount REAL, vendor TEXT, '
      'notes TEXT, number TEXT, title TEXT, reference TEXT, items TEXT, '
      'vat_rate REAL, paid INTEGER, method TEXT, quotation_id TEXT, '
      'extra INTEGER',
  // Files kept with expenses (supplier invoices). Only the details are kept
  // here; the file itself is in the device's file store and the cloud's
  // file storage, so the database stays small.
  'attachments': 'owner_id TEXT, name TEXT, mime TEXT, size INTEGER',
};

/// Money tables. Only the owner syncs these.
const financeTables = {
  'quotations',
  'invoices',
  'payments',
  'expenses',
  'attachments',
};

/// Local SQLite store. Everything the app shows is read from here, so the app
/// works with no internet; the sync service copies changes to and from the
/// cloud when a connection is available.
class LocalDb {
  LocalDb(this.db);

  final Database db;

  static const _version = 9;

  /// Columns added after the first release, by the version that added them.
  static const _added = {
    2: [
      'projects ADD COLUMN project_type TEXT',
      'projects ADD COLUMN area_sqm REAL',
      'tasks ADD COLUMN category TEXT',
      'deliverables ADD COLUMN discipline TEXT',
      'deliverables ADD COLUMN doc_type TEXT',
      'deliverables ADD COLUMN doc_number INTEGER',
    ],
    3: ['stages ADD COLUMN service TEXT', 'projects ADD COLUMN map_link TEXT'],
    4: [
      'projects ADD COLUMN markup_rate REAL',
      'quotations ADD COLUMN markup_rate REAL',
      'quotations ADD COLUMN show_markup INTEGER',
      'invoices ADD COLUMN markup_rate REAL',
      'invoices ADD COLUMN show_markup INTEGER',
    ],
    5: ['invoices ADD COLUMN stage_id TEXT', 'payments ADD COLUMN number TEXT'],
    6: [
      'quotations ADD COLUMN payment_terms TEXT',
      'invoices ADD COLUMN term_index INTEGER',
      'payments ADD COLUMN client_id TEXT',
      'payments ADD COLUMN project_id TEXT',
      'payments ADD COLUMN quotation_id TEXT',
      'payments ADD COLUMN term_index INTEGER',
      'payments ADD COLUMN notes TEXT',
    ],
    7: [
      'expenses ADD COLUMN number TEXT',
      'expenses ADD COLUMN title TEXT',
      'expenses ADD COLUMN reference TEXT',
      'expenses ADD COLUMN items TEXT',
      'expenses ADD COLUMN vat_rate REAL',
      'expenses ADD COLUMN paid INTEGER',
      'expenses ADD COLUMN method TEXT',
      'invoices ADD COLUMN extra INTEGER',
    ],
    9: [
      'expenses ADD COLUMN quotation_id TEXT',
      'expenses ADD COLUMN extra INTEGER',
    ],
  };

  /// Tables added after the first release, by the version that added them.
  static const _newTables = {
    3: ['quotations', 'invoices', 'payments', 'expenses'],
    7: ['attachments'],
    8: ['project_notes'],
  };

  /// Files saved on this device that the cloud does not have yet. Never
  /// synced itself.
  static const _pendingFilesTable =
      'CREATE TABLE IF NOT EXISTS pending_files (id TEXT PRIMARY KEY)';

  static const _notesIndex =
      'CREATE INDEX IF NOT EXISTS project_notes_project '
      'ON project_notes(project_id)';

  static Future<void> _createTable(Database db, String name) => db.execute(
    'CREATE TABLE IF NOT EXISTS $name ('
    'id TEXT PRIMARY KEY, created_at TEXT NOT NULL, '
    'updated_at TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0, '
    'dirty INTEGER NOT NULL DEFAULT 1, ${syncedTables[name]})',
  );

  static Future<LocalDb> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        // Each in-memory database (used in tests) is its own copy.
        singleInstance: path != inMemoryDatabasePath,
        onCreate: (db, _) async {
          for (final t in syncedTables.keys) {
            await _createTable(db, t);
          }
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT)',
          );
          await db.execute(_pendingFilesTable);
          await db.execute('CREATE INDEX tasks_project ON tasks(project_id)');
          await db.execute(
            'CREATE INDEX deliverables_project ON deliverables(project_id)',
          );
          await db.execute(_notesIndex);
        },
        onUpgrade: (db, from, to) async {
          for (var v = from + 1; v <= to; v++) {
            for (final change in _added[v] ?? const <String>[]) {
              // A table created by a later step already has the column.
              final table = change.split(' ').first;
              final column = change.split(' ')[3];
              final cols = await db.rawQuery('PRAGMA table_info($table)');
              if (cols.every((c) => c['name'] != column)) {
                await db.execute('ALTER TABLE $change');
              }
            }
            for (final t in _newTables[v] ?? const <String>[]) {
              await _createTable(db, t);
            }
          }
          await db.execute(_pendingFilesTable);
          if (from < 8) await db.execute(_notesIndex);
        },
      ),
    );
    return LocalDb(db);
  }

  Future<List<Map<String, Object?>>> all(
    String table, {
    List<String>? columns,
  }) => db.query(table, columns: columns, where: 'deleted = 0');

  /// Every row, deleted ones included.
  Future<List<Map<String, Object?>>> everything(String table) =>
      db.query(table);

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
      db.update(
        table,
        {'dirty': 0},
        where: 'id = ? AND updated_at = ?',
        whereArgs: [id, updatedAt],
      );

  Future<Map<String, Object?>?> byId(String table, String id) async {
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  /// Writes a row that came from the cloud. It is already in sync.
  Future<void> putRemote(String table, Map<String, Object?> row) async {
    // Columns a newer version added in the cloud are left out, so a device
    // not yet updated keeps receiving the rest.
    final known = _columns[table] ??= {
      for (final c in await db.rawQuery('PRAGMA table_info($table)'))
        c['name'] as String,
    };
    await db.insert(table, {
      for (final MapEntry(:key, :value) in row.entries)
        if (known.contains(key)) key: value,
      'dirty': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  final _columns = <String, Set<String>>{};

  /// Numbers of deleted documents, so a number is never given twice.
  Future<List<String>> deletedNumbers(String table) async => [
    for (final r in await db.query(
      table,
      columns: ['number'],
      where: 'deleted = 1 AND number IS NOT NULL',
    ))
      r['number'] as String,
  ];

  Future<void> addPendingFile(String id) => db.insert('pending_files', {
    'id': id,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);

  Future<void> removePendingFile(String id) =>
      db.delete('pending_files', where: 'id = ?', whereArgs: [id]);

  Future<Set<String>> pendingFiles() async => {
    for (final r in await db.query('pending_files')) r['id'] as String,
  };

  Future<String?> getSetting(String key) async {
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) => db.insert('settings', {
    'key': key,
    'value': value,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> close() => db.close();
}
