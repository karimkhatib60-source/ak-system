import 'package:ak_system/data/models.dart';
import 'package:ak_system/data/repository.dart';
import 'package:ak_system/main.dart';
import 'package:ak_system/sync/cloud_account.dart';
import 'package:ak_system/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The Notes tab of a project, as used on a phone.
void main() {
  late Repository repo;

  Future<void> openNotes(WidgetTester tester, List<ProjectNote> notes) async {
    tester.view.physicalSize = const Size(400, 860);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final clock = TestClock(DateTime(2026, 10, 17, 9));
    repo = (await tester.runAsync(() async {
      final r = await memoryRepo(clock);
      final t = r.now();
      await r.saveProject(
        Project(
          id: 'p1',
          createdAt: t,
          updatedAt: t,
          code: 'AK-26-001',
          name: 'Villa Byblos',
        ),
      );
      for (final n in notes) {
        await r.saveNote(n);
      }
      return r;
    }))!;
    final sync = SyncService(repo.local, repo);
    final cloud = CloudAccount(repo.local, repo, sync);
    await tester.pumpWidget(AkApp(repo: repo, sync: sync, cloud: cloud));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Villa Byblos'));
    await tester.pumpAndSettle();
    // The overview's notes card opens the Notes tab.
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined).first);
    await tester.pumpAndSettle();
  }

  ProjectNote n(String id, String text, NoteKind kind, int day) {
    final t = DateTime(2026, 10, 17, 9);
    return ProjectNote(
      id: id,
      createdAt: t,
      updatedAt: t,
      projectId: 'p1',
      date: DateTime(2026, 10, day),
      kind: kind,
      text: text,
    );
  }

  final five = [
    n('a', 'Kitchen layout', NoteKind.meeting, 1),
    n('b', 'Slab poured', NoteKind.siteVisit, 2),
    n('c', 'Oak floors please', NoteKind.clientRequest, 3),
    n('d', 'Sandstone facade', NoteKind.decision, 4),
    n('e', 'Parking at the back', NoteKind.general, 5),
  ];

  testWidgets('search narrows the notes and clearing it shows them all', (
    tester,
  ) async {
    await openNotes(tester, five);
    await tester.enterText(find.byType(TextField), 'kitchen');
    await tester.pumpAndSettle();
    expect(find.text('Kitchen layout'), findsOneWidget);
    expect(find.text('Slab poured'), findsNothing);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Slab poured'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a kind filter whose last note is gone does not come back', (
    tester,
  ) async {
    await openNotes(tester, five);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Slab poured'), findsNothing);
    await tester.runAsync(
      () => repo.deleteNote(repo.notes.firstWhere((x) => x.id == 'a')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Slab poured'), findsOneWidget);
    await tester.runAsync(
      () => repo.saveNote(n('f', 'Second meeting', NoteKind.meeting, 6)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Slab poured'), findsOneWidget);
    expect(find.text('Second meeting'), findsOneWidget);
  });

  testWidgets('closing a note with unsaved text asks first', (tester) async {
    await openNotes(tester, const []);
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Call the surveyor');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Call the surveyor'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('No notes yet'), findsOneWidget);
    expect(repo.notes, isEmpty);
  });

  testWidgets('a new note is saved with the chosen kind', (tester) async {
    await openNotes(tester, const []);
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Site visit'));
    await tester.enterText(
      find.byType(TextFormField),
      'Site visit\nRebar checked',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = repo.notes.single;
    expect(saved.kind, NoteKind.siteVisit);
    expect(saved.heading, 'Site visit');
    expect(find.text('Rebar checked'), findsOneWidget);
  });

  testWidgets('the owner keeps key points on the project', (tester) async {
    await openNotes(tester, const []);
    await tester.tap(find.text('Add key points'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Budget 400k; client prefers stone',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.project('p1')!.notes, 'Budget 400k; client prefers stone');
    expect(find.text('Key points'), findsOneWidget);
    expect(find.text('Budget 400k; client prefers stone'), findsOneWidget);
  });
}
