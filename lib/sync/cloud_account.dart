import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import '../data/repository.dart';
import 'supabase_remote.dart';
import 'sync_service.dart';

/// Connects the app to the company's cloud database and signs the user in.
/// Until this is set up, the app works on this device only.
class CloudAccount extends ChangeNotifier {
  CloudAccount(this.local, this.repo, this.sync);

  final LocalDb local;
  final Repository repo;
  final SyncService sync;

  String? url;
  String? anonKey;
  bool _initialized = false;

  bool get configured => url != null && anonKey != null;
  User? get user => _initialized ? Supabase.instance.client.auth.currentUser : null;
  bool get signedIn => user != null;

  /// Restores the saved connection and session at app start.
  Future<void> restore() async {
    url = await local.getSetting('cloud_url');
    anonKey = await local.getSetting('cloud_key');
    if (configured) {
      await _init();
      if (signedIn) await _afterSignIn();
    }
    notifyListeners();
  }

  Future<void> _init() async {
    if (_initialized) return;
    await Supabase.initialize(url: url!, publishableKey: anonKey!);
    _initialized = true;
  }

  /// Saves the cloud address. Changing it after the first connection needs
  /// an app restart.
  Future<void> configure(String newUrl, String newKey) async {
    url = newUrl.trim();
    anonKey = newKey.trim();
    await local.setSetting('cloud_url', url);
    await local.setSetting('cloud_key', anonKey);
    await _init();
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _init();
    await Supabase.instance.client.auth
        .signInWithPassword(email: email.trim(), password: password);
    await _afterSignIn();
  }

  /// Creates a login. The first person ever to sign up becomes the owner;
  /// everyone after that joins as an architect (set up in the cloud schema).
  Future<void> signUp(String name, String email, String password) async {
    await _init();
    final res = await Supabase.instance.client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'name': name.trim()},
    );
    if (res.session != null) await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    await repo.setCurrentMember(user!.id);
    sync.attach(SupabaseRemote(Supabase.instance.client));
    await sync.syncNow();
    notifyListeners();
  }

  Future<void> signOut() async {
    await sync.syncNow();
    if (_initialized) await Supabase.instance.client.auth.signOut();
    sync.detach();
    await repo.setCurrentMember(null);
    notifyListeners();
  }
}
