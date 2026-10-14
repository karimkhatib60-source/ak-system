import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/db.dart';
import '../data/repository.dart';

/// The cloud side of sync. The real one talks to Supabase; tests use a fake.
abstract class RemoteStore {
  /// Uploads rows, overwriting the cloud copy.
  Future<void> upsert(String table, List<Map<String, Object?>> rows);

  /// Rows that reached the cloud after [since] (all rows when null), each
  /// with a `synced_at` stamp set by the server's clock.
  Future<List<Map<String, Object?>>> changedSince(String table, String? since);
}

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
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(minutes: 5), (_) => syncNow());
    notifyListeners();
  }

  void detach() {
    remote = null;
    repo.onLocalChange = null;
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
    try {
      // Members and stages first so projects can refer to them.
      for (final table in syncedTables.keys) {
        await _push(r, table);
      }
      var pulledAny = false;
      for (final table in syncedTables.keys) {
        pulledAny = await _pull(r, table) || pulledAny;
      }
      if (pulledAny) await repo.reload();
      lastSyncedAt = DateTime.now();
      lastError = null;
      state = SyncState.idle;
    } on Exception catch (e) {
      lastError = e.toString();
      state = _looksOffline(lastError!) ? SyncState.offline : SyncState.error;
    }
    notifyListeners();
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
    final rows = await local.dirtyRows(table);
    if (rows.isEmpty) return;
    final payload = rows.map(toRemote).toList();
    await r.upsert(table, payload);
    for (final row in rows) {
      await local.markClean(
          table, row['id'] as String, row['updated_at'] as String);
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
      final mineIsNewer = mine != null &&
          mine['dirty'] == 1 &&
          (mine['updated_at'] as String).compareTo(updated) > 0;
      if (!mineIsNewer) await local.putRemote(table, row);
      if (newest == null || _after(synced, newest)) newest = synced;
    }
    await local.setSetting(key, newest);
    return true;
  }

  /// Local rows use 0/1 for booleans; the cloud uses true/false.
  static Map<String, Object?> toRemote(Map<String, Object?> row) {
    final out = Map<String, Object?>.from(row)..remove('dirty');
    for (final k in _boolColumns) {
      if (out.containsKey(k)) out[k] = out[k] == 1 || out[k] == true;
    }
    return out;
  }

  static bool _after(String a, String b) =>
      DateTime.parse(a).isAfter(DateTime.parse(b));

  static Map<String, Object?> fromRemote(Map<String, Object?> row) {
    final out = Map<String, Object?>.from(row)..remove('synced_at');
    for (final k in _boolColumns) {
      if (out.containsKey(k)) out[k] = out[k] == true || out[k] == 1 ? 1 : 0;
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

  static const _boolColumns = ['deleted', 'abroad'];

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    super.dispose();
  }
}
