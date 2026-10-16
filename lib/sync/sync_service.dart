import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/repository.dart';

/// The cloud side of sync. The real one talks to Supabase; tests use a fake.
abstract class RemoteStore {
  /// Uploads rows, overwriting the cloud copy.
  Future<void> upsert(String table, List<Map<String, Object?>> rows);

  /// Rows that reached the cloud after [since] (all rows when null), each
  /// with a `synced_at` stamp set by the server's clock.
  Future<List<Map<String, Object?>>> changedSince(String table, String? since);

  /// Attached files, kept in the cloud's private file storage.
  Future<void> uploadFile(String path, Uint8List bytes, String mime);
  Future<Uint8List?> downloadFile(String path);
  Future<void> removeFile(String path);
}

/// Where an attachment's file is kept in the cloud.
String cloudPathOf(String attachmentId) => 'files/$attachmentId';

enum SyncState { localOnly, idle, syncing, offline, error }

/// Two-way sync between the local database and the cloud.
///
/// Push: rows changed on this device are uploaded.
/// Pull: rows changed in the cloud since the last pull are downloaded.
/// When both sides changed the same row, the most recent change wins.
class SyncService extends ChangeNotifier {
  SyncService(this.local, this.repo);

  final LocalDb local;
  final Repository repo;

  RemoteStore? remote;
  SyncState state = SyncState.localOnly;
  String? lastError;
  DateTime? lastSyncedAt;

  Timer? _debounce;
  Timer? _periodic;
  Future<void>? _running;

  void attach(RemoteStore r) {
    remote = r;
    state = SyncState.idle;
    repo.onLocalChange = scheduleSoon;
    repo.downloadFile = (Attachment a) => r.downloadFile(cloudPathOf(a.id));
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    notifyListeners();
  }

  void detach() {
    remote = null;
    repo.onLocalChange = null;
    repo.downloadFile = null;
    _periodic?.cancel();
    _debounce?.cancel();
    state = SyncState.localOnly;
    notifyListeners();
  }

  /// Uploads a few seconds after the last edit, so a burst of edits goes up
  /// together.
  void scheduleSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), syncNow);
  }

  Future<void> syncNow() => _running ??= _sync().whenComplete(() {
    _running = null;
  });

  Future<void> _sync() async {
    final r = remote;
    if (r == null) return;
    state = SyncState.syncing;
    notifyListeners();
    // Each step stands alone: a table or file that fails is tried again
    // next time and never stops the others, so the device keeps receiving
    // changes. Being offline stops the whole round.
    final problems = <String>[];
    var pulledAny = false;
    Future<void> step(Future<void> Function() run) async {
      try {
        await run();
      } on Exception catch (e) {
        if (_looksOffline('$e')) rethrow;
        problems.add('$e');
      }
    }

    try {
      await step(() => _uploadFiles(r, problems));
      // Members and stages first so projects can refer to them.
      for (final table in syncedTables.keys) {
        await step(() => _push(r, table));
      }
      for (final table in syncedTables.keys) {
        await step(() async => pulledAny = await _pull(r, table) || pulledAny);
      }
      if (problems.isEmpty) lastSyncedAt = DateTime.now();
      lastError = problems.isEmpty ? null : problems.join('\n');
      state = problems.isEmpty ? SyncState.idle : SyncState.error;
    } on Exception catch (e) {
      lastError = e.toString();
      state = _looksOffline(lastError!) ? SyncState.offline : SyncState.error;
    }
    if (pulledAny) {
      await repo.reload();
      if (repo.isOwner) await repo.renumberDuplicateExpenses();
    }
    notifyListeners();
  }

  /// Uploads files added on this device. A file that fails stays pending
  /// and is tried again on the next round.
  Future<void> _uploadFiles(RemoteStore r, List<String> problems) async {
    if (!repo.isOwner) return;
    for (final id in await local.pendingFiles()) {
      final row = await local.byId('attachments', id);
      final bytes = await repo.files.get(id);
      if (row == null || row['deleted'] == 1 || bytes == null) {
        await local.removePendingFile(id);
        continue;
      }
      try {
        await r.uploadFile(cloudPathOf(id), bytes, row['mime'] as String);
        await local.removePendingFile(id);
      } on Exception catch (e) {
        if (_looksOffline('$e')) rethrow;
        problems.add(
          'The file "{0}" could not be uploaded yet; it will be '
                  'tried again. ({1})'
              .trArgs([row['name'], e]),
        );
      }
    }
  }

  bool _looksOffline(String msg) {
    final m = msg.toLowerCase();
    return m.contains('socket') ||
        m.contains('host lookup') ||
        m.contains('network') ||
        m.contains('connection') ||
        m.contains('timed out');
  }

  /// Architects may only change tasks and deliverables in the cloud.
  static const teamWritable = {'tasks', 'deliverables'};

  Future<void> _push(RemoteStore r, String table) async {
    if (!repo.isOwner && !teamWritable.contains(table)) return;
    var rows = await local.dirtyRows(table);
    if (table == 'attachments') {
      // A file's details go up only once the file itself is in the cloud,
      // so other devices never list a file they cannot open.
      final pending = await local.pendingFiles();
      rows = [
        for (final row in rows)
          if (!pending.contains(row['id'])) row,
      ];
    }
    if (rows.isEmpty) return;
    final payload = rows.map(toRemote).toList();
    await r.upsert(table, payload);
    for (final row in rows) {
      await local.markClean(
        table,
        row['id'] as String,
        row['updated_at'] as String,
      );
      if (table == 'attachments' && row['deleted'] == 1) {
        // Best effort: a file left behind only takes space.
        try {
          await r.removeFile(cloudPathOf(row['id'] as String));
        } on Exception catch (_) {}
      }
    }
  }

  Future<bool> _pull(RemoteStore r, String table) async {
    final key = 'last_pull_$table';
    final since = await local.getSetting(key);
    final rows = await r.changedSince(table, since);
    if (rows.isEmpty) return false;
    var newest = since;
    for (final remoteRow in rows) {
      // The checkpoint uses the server's clock, so a device with a wrong
      // clock cannot make others skip its changes.
      final synced = remoteRow['synced_at'] as String;
      final row = fromRemote(remoteRow);
      final updated = row['updated_at'] as String;
      final mine = await local.byId(table, row['id'] as String);
      final mineIsNewer =
          mine != null &&
          mine['dirty'] == 1 &&
          (mine['updated_at'] as String).compareTo(updated) > 0;
      if (!mineIsNewer) {
        await local.putRemote(table, row);
        if (table == 'attachments' && row['deleted'] == 1) {
          await repo.files.remove(row['id'] as String);
        }
      }
      if (newest == null || _after(synced, newest)) newest = synced;
    }
    await local.setSetting(key, newest);
    return true;
  }

  /// Local rows use 0/1 for booleans; the cloud uses true/false.
  static Map<String, Object?> toRemote(Map<String, Object?> row) {
    final out = Map<String, Object?>.from(row)..remove('dirty');
    for (final k in _boolColumns) {
      if (out[k] != null) out[k] = out[k] == 1 || out[k] == true;
    }
    return out;
  }

  static bool _after(String a, String b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b));

  static Map<String, Object?> fromRemote(Map<String, Object?> row) {
    final out = Map<String, Object?>.from(row)..remove('synced_at');
    for (final k in _boolColumns) {
      if (out[k] != null) out[k] = out[k] == true || out[k] == 1 ? 1 : 0;
    }
    // Timestamps come back with a +00:00 suffix; store them in the same
    // form the app writes so string comparison stays correct.
    for (final k in ['created_at', 'updated_at']) {
      final v = out[k];
      if (v is String) {
        final d = DateTime.tryParse(v);
        if (d != null) out[k] = d.toUtc().toIso8601String();
      }
    }
    return out;
  }

  static const _boolColumns = [
    'deleted',
    'abroad',
    'show_markup',
    'paid',
    'extra',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
