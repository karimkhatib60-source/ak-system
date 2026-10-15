import 'package:ak_system/data/models.dart';
import 'package:ak_system/main.dart';
import 'package:ak_system/sync/cloud_account.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    Size size, {
    bool withData = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final clock = TestClock(DateTime(2026, 10, 14, 9));
    final repo = await tester.runAsync(() async {
      final repo = await memoryRepo(clock);
      if (withData) {
        final t = repo.now();
        await repo.saveClient(
          Client(id: 'c1', createdAt: t, updatedAt: t, name: 'Nadim Haddad'),
        );
        await repo.saveProject(
          Project(
            id: 'p1',
            createdAt: t,
            updatedAt: t,
            code: 'AK-26-001',
            name: 'Villa Byblos',
            clientId: 'c1',
            stageId: repo.stages[1].id,
            location: 'Byblos',
          ),
        );
        await repo.saveTask(
          Task(
            id: 't1',
            createdAt: t,
            updatedAt: t,
            projectId: 'p1',
            title: 'Concept sketches',
            dueDate: DateTime(2026, 10, 12),
          ),
        );
        await repo.saveDeliverable(
          Deliverable(
            id: 'd1',
            createdAt: t,
            updatedAt: t,
            projectId: 'p1',
            title: 'Concept booklet',
            status: DeliverableStatus.submitted,
            submittedAt: t,
          ),
        );
      }
      return repo;
    });
    final sync = SyncService(repo!.local, repo);
    final cloud = CloudAccount(repo.local, repo, sync);
    await tester.pumpWidget(AkApp(repo: repo, sync: sync, cloud: cloud));
    await tester.pumpAndSettle();
  }

  testWidgets('phone overview shows late work and client approvals', (
    tester,
  ) async {
    await pumpApp(tester, const Size(400, 860));
    expect(find.text('Good morning, Karim'), findsOneWidget);
    expect(find.text('Concept sketches'), findsOneWidget);
    expect(find.text('2 days late'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('WAITING FOR CLIENT APPROVAL'),
      200,
    );
    expect(find.text('WAITING FOR CLIENT APPROVAL'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('laptop layout uses a side rail and opens a project', (
    tester,
  ) async {
    await pumpApp(tester, const Size(1366, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Villa Byblos'));
    await tester.pumpAndSettle();
    expect(find.text('Concept design'), findsWidgets);
    expect(find.text('Current'), findsOneWidget);
  });

  testWidgets('empty app invites adding the first project', (tester) async {
    await pumpApp(tester, const Size(400, 860), withData: false);
    expect(find.textContaining('Start by adding a client'), findsOneWidget);
  });

  testWidgets('each tab renders on a phone without layout errors', (
    tester,
  ) async {
    await pumpApp(tester, const Size(360, 740));
    for (var i = 1; i < 5; i++) {
      await tester.tap(find.byType(NavigationDestination).at(i));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('CLOUD SYNC AND LOGIN'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Site supervision'), 200);
    expect(find.text('Site supervision'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
