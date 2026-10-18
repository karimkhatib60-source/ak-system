import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'ai/assistant.dart';
import 'data/repository.dart';
import 'data/file_store.dart';
import 'platform/file_store.dart';
import 'platform/installer.dart';
import 'platform/open_db.dart';
import 'sync/cloud_account.dart';
import 'sync/cloud_config.dart';
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
  final cloud = CloudAccount(local, repo, sync, builtIn: builtInCloud);
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
      // A new language rebuilds every screen with its texts and direction,
      // leaving open screens where they are.
      child: Selector<Repository, AppLang>(
        selector: (_, r) => r.appLanguage,
        builder: (context, lang, _) => _Relabel(
          lang: lang,
          child: MaterialApp(
            title: 'AK System',
            debugShowCheckedModeBanner: false,
            locale: Locale(lang.name),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: buildTheme(Brightness.light, lang),
            darkTheme: buildTheme(Brightness.dark, lang),
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}

/// Builds every screen again when the language changes, so texts read when
/// a screen builds come out in the new language.
class _Relabel extends StatefulWidget {
  const _Relabel({required this.lang, required this.child});

  final AppLang lang;
  final Widget child;

  @override
  State<_Relabel> createState() => _RelabelState();
}

class _RelabelState extends State<_Relabel> {
  @override
  void didUpdateWidget(_Relabel old) {
    super.didUpdateWidget(old);
    if (old.lang == widget.lang) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void mark(Element e) {
        e.markNeedsBuild();
        e.visitChildren(mark);
      }

      (context as Element).visitChildren(mark);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
