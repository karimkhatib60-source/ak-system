import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai/assistant.dart';
import 'data/repository.dart';
import 'data/file_store.dart';
import 'platform/file_store.dart';
import 'platform/installer.dart';
import 'platform/open_db.dart';
import 'sync/cloud_account.dart';
import 'sync/sync_service.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';
import 'update/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final local = await openLocalDb();
  // Without the device's file storage, files added now are kept until the
  // app closes; saved records still open.
  final files = await openFileStore().catchError(
    (Object _) => MemoryFileStore(),
  );
  final repo = Repository(local, files: files);
  await repo.load();
  final sync = SyncService(local, repo);
  final cloud = CloudAccount(local, repo, sync);
  // Restoring the cloud session must never block opening the app offline.
  cloud.restore().catchError((_) {});
  // The Windows app looks for new versions and installs them.
  final updates = UpdateService(installer: PlatformInstaller())
    ..beforeInstall = (() =>
        sync.syncNow().timeout(const Duration(seconds: 15), onTimeout: () {}))
    ..beforeQuit = local.close
    ..start();

  runApp(AkApp(repo: repo, sync: sync, cloud: cloud, updates: updates));
}

class AkApp extends StatelessWidget {
  const AkApp({
    super.key,
    required this.repo,
    required this.sync,
    required this.cloud,
    this.updates,
  });

  final Repository repo;
  final SyncService sync;
  final CloudAccount cloud;
  final UpdateService? updates;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: cloud),
        if (updates != null) ChangeNotifierProvider.value(value: updates!),
        ChangeNotifierProvider(create: (_) => Assistant(repo)..loadKey()),
      ],
      child: MaterialApp(
        title: 'AK System',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const AppShell(),
      ),
    );
  }
}
