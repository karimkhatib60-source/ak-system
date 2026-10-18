import 'package:ak_system/main.dart';
import 'package:ak_system/sync/cloud_account.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The cloud address built into the app: each person only signs in.
void main() {
  Future<CloudAccount> openSettings(
    WidgetTester tester, {
    ({String url, String key})? builtIn,
    String? url,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = (await tester.runAsync(
      () => memoryRepo(TestClock(DateTime(2026, 10, 18, 9))),
    ))!;
    final sync = SyncService(repo.local, repo);
    final cloud = CloudAccount(repo.local, repo, sync, builtIn: builtIn)
      ..url = url
      ..anonKey = url == null ? null : 'sb_publishable_test';
    await tester.pumpWidget(AkApp(repo: repo, sync: sync, cloud: cloud));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    return cloud;
  }

  const ak = (url: 'https://ak.supabase.co', key: 'sb_publishable_test');

  testWidgets('with the built-in database, Settings only asks to sign in', (
    tester,
  ) async {
    final cloud = await openSettings(tester, builtIn: ak, url: ak.url);
    expect(cloud.usesBuiltIn, isTrue);
    expect(find.text('Not signed in'), findsOneWidget);
    expect(
      find.text(
        'Sign in to share your data between your phone and laptop. '
        'Use the same email and password on each.',
      ),
      findsOneWidget,
    );
    expect(find.text(ak.url), findsNothing);
    expect(find.text('Connect'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    await tester.tap(find.text('New here? Create a login'));
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
  });

  testWidgets('a database typed in by hand still shows its address', (
    tester,
  ) async {
    final cloud = await openSettings(
      tester,
      builtIn: ak,
      url: 'https://other.supabase.co',
    );
    expect(cloud.usesBuiltIn, isFalse);
    expect(find.text('Connected, not signed in'), findsOneWidget);
    expect(find.text('https://other.supabase.co'), findsOneWidget);
  });

  testWidgets('without a database, Connect asks for the publishable key', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('Not connected'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pumpAndSettle();
    expect(find.text('Publishable key'), findsOneWidget);
    expect(find.textContaining('Project Settings > API Keys'), findsOneWidget);
  });
}
