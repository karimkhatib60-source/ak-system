import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/file_store.dart';

/// Attached files live in a "files" folder next to the database.
Future<FileStore> openFileStore() async {
  final dir = Directory(
    p.join((await getApplicationSupportDirectory()).path, 'files'),
  );
  await dir.create(recursive: true);
  return FolderFileStore(dir);
}

class FolderFileStore implements FileStore {
  FolderFileStore(this.dir);

  final Directory dir;

  File _file(String id) {
    if (!isSafeFileId(id)) throw ArgumentError.value(id, 'id');
    return File(p.join(dir.path, id));
  }

  @override
  Future<void> put(String id, Uint8List bytes) async {
    // Written beside the final name first, so a crash never leaves half a
    // file under it.
    final f = _file(id);
    final tmp = File('${f.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Uint8List?> get(String id) async {
    final f = _file(id);
    return await f.exists() ? f.readAsBytes() : null;
  }

  @override
  Future<void> remove(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}
