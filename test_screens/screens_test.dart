// Renders preview screenshots with real fonts:
//   flutter test test_screens --update-goldens
import 'dart:io';

import 'package:ak_system/data/models.dart';
import 'package:ak_system/main.dart';
import 'package:ak_system/sync/cloud_account.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/helpers.dart';

Future<void> _loadFonts() async {
  final dir =
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(
      Future.value(
        ByteData.sublistView(File('$dir/Roboto-$f.ttf').readAsBytesSync()),
      ),
    );
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$dir/MaterialIcons-Regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
  final manrope = FontLoader('Manrope');
  for (final w in [400, 500, 600, 700, 800]) {
    manrope.addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/Manrope-$w.ttf').readAsBytesSync(),
        ),
      ),
    );
  }
  await manrope.load();
}

void main() {
  setUpAll(_loadFonts);

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final clock = TestClock(DateTime(2026, 10, 14, 9));
    final repo = (await tester.runAsync(() async {
      final r = await memoryRepo(clock);
      final t = r.now();
      final s = r.stages;
      Future<void> client(String id, String name, String country) =>
          r.saveClient(
            Client(
              id: id,
              createdAt: t,
              updatedAt: t,
              name: name,
              country: country,
            ),
          );
      await client('c1', 'Nadim Haddad', 'Lebanon');
      await client('c2', 'Al Rayyan Holding', 'Qatar');
      await client('c3', 'Maya Khoury', 'Lebanon');
      await r.saveProject(
        Project(
          id: 'p1',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-001',
          name: 'Villa Byblos',
          clientId: 'c1',
          stageId: s[3].id,
          location: 'Byblos',
          dueDate: DateTime(2026, 12, 20),
        ),
      );
      await r.saveProject(
        Project(
          id: 'p2',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-002',
          name: 'Doha office tower review',
          clientId: 'c2',
          service: ServiceType.consultancy,
          abroad: true,
          stageId: s[2].id,
          location: 'Doha',
        ),
      );
      await r.saveProject(
        Project(
          id: 'p3',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-003',
          name: 'Apartment fit-out, Achrafieh',
          clientId: 'c3',
          service: ServiceType.contracting,
          stageId: s[7].id,
          location: 'Beirut',
          dueDate: DateTime(2026, 11, 5),
        ),
      );
      Future<void> task(
        String id,
        String p,
        String title,
        DateTime? due, [
        TaskPriority pr = TaskPriority.normal,
      ]) => r.saveTask(
        Task(
          id: id,
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: title,
          dueDate: due,
          priority: pr,
        ),
      );
      await task(
        't1',
        'p1',
        'Update facade elevations',
        DateTime(2026, 10, 12),
        TaskPriority.high,
      );
      await task(
        't2',
        'p3',
        'Site visit: tiling check',
        DateTime(2026, 10, 15),
      );
      await task(
        't3',
        'p2',
        'Comments on structural report',
        DateTime(2026, 10, 17),
      );
      await task('t4', 'p1', 'Kitchen layout options', DateTime(2026, 10, 20));
      Future<void> del(
        String id,
        String p,
        String title,
        DeliverableStatus st,
        int v,
        int stage,
      ) => r.saveDeliverable(
        Deliverable(
          id: id,
          createdAt: t,
          updatedAt: t,
          projectId: p,
          title: title,
          status: st,
          version: v,
          stageId: s[stage].id,
          submittedAt: st == DeliverableStatus.submitted
              ? DateTime(2026, 10, 9)
              : null,
          dueDate: DateTime(2026, 10, 25),
        ),
      );
      await del(
        'd1',
        'p1',
        'Design development set',
        DeliverableStatus.submitted,
        2,
        3,
      );
      await del(
        'd2',
        'p2',
        'Review memo no. 3',
        DeliverableStatus.revise,
        1,
        2,
      );
      await del(
        'd3',
        'p3',
        'Joinery shop drawings',
        DeliverableStatus.internalReview,
        1,
        7,
      );
      return r;
    }))!;
    final sync = SyncService(repo.local, repo);
    await tester.pumpWidget(
      AkApp(
        repo: repo,
        sync: sync,
        cloud: CloudAccount(repo.local, repo, sync),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone overview', (tester) async {
    await pump(tester, const Size(400, 860));
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_overview.png'),
    );
  });

  testWidgets('phone project', (tester) async {
    await pump(tester, const Size(400, 860));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_projects.png'),
    );
    await tester.tap(find.text('Villa Byblos'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_project_detail.png'),
    );
  });

  testWidgets('phone lists', (tester) async {
    await pump(tester, const Size(360, 740));
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_tasks.png'),
    );
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/phone_deliverables.png'),
    );
  });

  testWidgets('laptop', (tester) async {
    await pump(tester, const Size(1366, 768));
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/laptop_overview.png'),
    );
    await tester.tap(find.text('Deliverables').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Design development set'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AkApp),
      matchesGoldenFile('out/laptop_deliverable.png'),
    );
  });
}
