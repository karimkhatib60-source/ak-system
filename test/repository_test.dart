import 'package:ak_system/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late TestClock clock;

  setUp(() => clock = TestClock(DateTime(2026, 10, 14, 9)));

  test('seeds the eight standard stages once', () async {
    final repo = await memoryRepo(clock);
    expect(repo.stages.map((s) => s.name), defaultStages);
    await repo.load();
    expect(repo.stages, hasLength(8));
  });

  test('stage ids are identical on every device', () async {
    final a = await memoryRepo(clock);
    final b = await memoryRepo(clock);
    expect(a.stages.map((s) => s.id), b.stages.map((s) => s.id));
  });

  test('project codes count up within the year', () async {
    final repo = await memoryRepo(clock);
    expect(repo.nextProjectCode(), 'AK-26-001');
    final t = repo.now();
    await repo.saveProject(
      Project(
        id: repo.newId(),
        createdAt: t,
        updatedAt: t,
        code: 'AK-26-001',
        name: 'Villa Byblos',
      ),
    );
    expect(repo.nextProjectCode(), 'AK-26-002');
  });

  test('overdue tasks and deleting a project removes its work', () async {
    final repo = await memoryRepo(clock);
    final t = repo.now();
    final p = Project(id: repo.newId(), createdAt: t, updatedAt: t, name: 'X');
    await repo.saveProject(p);
    await repo.saveTask(
      Task(
        id: repo.newId(),
        createdAt: t,
        updatedAt: t,
        projectId: p.id,
        title: 'Facade study',
        dueDate: DateTime(2026, 10, 10),
      ),
    );
    await repo.saveDeliverable(
      Deliverable(
        id: repo.newId(),
        createdAt: t,
        updatedAt: t,
        projectId: p.id,
        title: 'Concept booklet',
      ),
    );
    expect(repo.tasks.single.isOverdue(repo.now()), isTrue);

    await repo.toggleTaskDone(repo.tasks.single);
    expect(repo.tasks.single.isOverdue(repo.now()), isFalse);

    await repo.deleteProject(repo.project(p.id)!);
    expect(repo.projects, isEmpty);
    expect(repo.tasks, isEmpty);
    expect(repo.deliverables, isEmpty);
  });

  test('deliverable workflow stamps dates and bumps revisions', () async {
    final repo = await memoryRepo(clock);
    final t = repo.now();
    final d = Deliverable(
      id: repo.newId(),
      createdAt: t,
      updatedAt: t,
      projectId: 'p',
      title: 'Permit set',
    );
    await repo.saveDeliverable(d);
    expect(repo.deliverables.single.revisionLabel, 'R00');

    await repo.setDeliverableStatus(
      repo.deliverables.single,
      DeliverableStatus.submitted,
    );
    expect(repo.deliverables.single.submittedAt, isNotNull);

    await repo.setDeliverableStatus(
      repo.deliverables.single,
      DeliverableStatus.revise,
    );
    await repo.newRevision(repo.deliverables.single);
    final r1 = repo.deliverables.single;
    expect(r1.revisionLabel, 'R01');
    expect(r1.status, DeliverableStatus.draft);
  });

  test('an architect only sees projects they are on', () async {
    final repo = await memoryRepo(clock);
    final t = repo.now();
    final arch = Member(
      id: 'arch-1',
      createdAt: t,
      updatedAt: t,
      name: 'Rami',
      role: MemberRole.architect,
    );
    await repo.saveMember(arch);
    final mine = Project(
      id: 'p1',
      createdAt: t,
      updatedAt: t,
      name: 'Mine',
      teamIds: ['arch-1'],
    );
    final other = Project(id: 'p2', createdAt: t, updatedAt: t, name: 'Other');
    await repo.saveProject(mine);
    await repo.saveProject(other);

    expect(repo.visibleProjects, hasLength(2)); // no login: owner view
    await repo.setCurrentMember('arch-1');
    expect(repo.isOwner, isFalse);
    expect(repo.visibleProjects.map((p) => p.name), ['Mine']);
  });

  test('moving a stage reorders the list', () async {
    final repo = await memoryRepo(clock);
    final permit = repo.stages.firstWhere((s) => s.name == 'Permit');
    await repo.moveStage(permit, -1);
    expect(repo.stages[3].name, 'Permit');
    expect(repo.stages[4].name, 'Design development');
  });
}
