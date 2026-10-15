import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../data/db.dart';

/// In a browser the database lives in the browser's own storage (IndexedDB).
/// SQLite runs on the page itself, so it also works where web workers are
/// not allowed.
Future<LocalDb> openLocalDb() =>
    LocalDb.open('ak_system.db', factory: databaseFactoryFfiWebNoWebWorker);
