import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'sync_service.dart';

/// Cloud store backed by the company's Supabase project.
class SupabaseRemote implements RemoteStore {
  SupabaseRemote(this.client);

  final SupabaseClient client;

  static const _page = 500;

  @override
  Future<void> upsert(String table, List<Map<String, Object?>> rows) async {
    for (var i = 0; i < rows.length; i += _page) {
      final chunk = rows.sublist(i, (i + _page).clamp(0, rows.length));
      await client.from(table).upsert(chunk);
    }
  }

  @override
  Future<List<Map<String, Object?>>> changedSince(
    String table,
    String? since,
  ) async {
    final out = <Map<String, Object?>>[];
    var from = 0;
    while (true) {
      var q = client.from(table).select();
      if (since != null) q = q.gt('synced_at', since);
      final rows = await q
          .order('synced_at', ascending: true)
          .order('id', ascending: true)
          .range(from, from + _page - 1);
      out.addAll(rows.cast<Map<String, Object?>>());
      if (rows.length < _page) break;
      from += _page;
    }
    return out;
  }

  /// Private bucket; only the owner can read or write it (schema.sql).
  StorageFileApi get _files => client.storage.from('attachments');

  @override
  Future<void> uploadFile(String path, Uint8List bytes, String mime) async {
    await _files.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: true),
    );
  }

  @override
  Future<Uint8List?> downloadFile(String path) => _files.download(path);

  @override
  Future<void> removeFile(String path) async {
    await _files.remove([path]);
  }
}
