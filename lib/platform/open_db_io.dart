import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../data/db.dart';

/// Android uses the built-in SQLite; Windows and Linux use the bundled one.
Future<LocalDb> openLocalDb() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  final dir = await getApplicationSupportDirectory();
  return LocalDb.open(p.join(dir.path, 'ak_system.db'));
}
