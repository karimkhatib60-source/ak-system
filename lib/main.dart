import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repository.dart';
import 'platform/open_db.dart';
import 'sync/cloud_account.dart';
import 'sync/sync_service.dart';
import 'ui/app_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final local = await openLocalDb();
  final repo = Repository(local);
  await repo.load();
  final sync = SyncService(local, repo);
  final cloud = CloudAccount(local, repo, sync);
  // Restoring the cloud session must never block opening the app offline.
  cloud.restore().catchError((_) {});

  runApp(AkApp(repo: repo, sync: sync, cloud: cloud));
}

class AkApp extends StatelessWidget {
  const AkApp(
      {super.key, required this.repo, required this.sync, required this.cloud});

  final Repository repo;
  final SyncService sync;
  final CloudAccount cloud;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repo),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: cloud),
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
