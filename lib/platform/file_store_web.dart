import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../data/file_store.dart';

/// In a browser, attached files live in their own IndexedDB store, apart
/// from the database, so they are only read when opened.
Future<FileStore> openFileStore() async {
  final req = web.window.indexedDB.open('ak_files', 1);
  req.onupgradeneeded = ((web.Event _) {
    final db = req.result as web.IDBDatabase;
    if (!db.objectStoreNames.contains(_store)) db.createObjectStore(_store);
  }).toJS;
  return _IdbFileStore(await _result(req) as web.IDBDatabase);
}

const _store = 'files';

Future<JSAny?> _result(web.IDBRequest req) {
  final done = Completer<JSAny?>();
  req.onsuccess = ((web.Event _) => done.complete(req.result)).toJS;
  req.onerror = ((web.Event _) => done.completeError(
    StateError('Browser storage: ${req.error?.message ?? 'error'}'),
  )).toJS;
  return done.future;
}

class _IdbFileStore implements FileStore {
  _IdbFileStore(this._db);

  final web.IDBDatabase _db;

  web.IDBObjectStore _files(String mode) =>
      _db.transaction(_store.toJS, mode).objectStore(_store);

  @override
  Future<void> put(String id, Uint8List bytes) async {
    await _result(_files('readwrite').put(bytes.toJS, id.toJS));
  }

  @override
  Future<Uint8List?> get(String id) async {
    final v = await _result(_files('readonly').get(id.toJS));
    if (v == null || v.isUndefinedOrNull) return null;
    return (v as JSUint8Array).toDart;
  }

  @override
  Future<void> remove(String id) async {
    await _result(_files('readwrite').delete(id.toJS));
  }
}
