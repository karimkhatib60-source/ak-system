import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';

const _uuid = Uuid();

/// In-memory view of the local database that the screens read from.
/// Every change is written to SQLite first, then the lists are reloaded.
class Repository extends ChangeNotifier {
  Repository(this.local, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDb local;
  final DateTime Function() _clock;

  /// Called after any local change so the sync service can upload it.
  VoidCallback? onLocalChange;

  List<Member> members = [];
  List<Stage> stages = [];
  List<Client> clients = [];
  List<Project> projects = [];
  List<Task> tasks = [];
  List<Deliverable> deliverables = [];

  /// The signed-in team member. Null means the app is used on its own,
  /// without cloud sync, and the user is treated as the owner.
  String? currentMemberId;
  String companyName = 'AK Design and Construction';

  DateTime now() => _clock();
  String newId() => _uuid.v4();

  Member? get currentMember =>
      members.where((m) => m.id == currentMemberId).firstOrNull;

  bool get isOwner => currentMember == null || currentMember!.isOwner;

  Future<void> load() async {
    if ((await local.all('stages')).isEmpty) await _seedStages();
    await reload();
  }

  Future<void> reload() async {
    members = (await local.all('members')).map(Member.fromMap).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    stages = (await local.all('stages')).map(Stage.fromMap).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    clients = (await local.all('clients')).map(Client.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    projects = (await local.all('projects')).map(Project.fromMap).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    tasks = (await local.all('tasks')).map(Task.fromMap).toList();
    deliverables = (await local.all('deliverables'))
        .map(Deliverable.fromMap)
        .toList();
    currentMemberId = await local.getSetting('current_member_id');
    companyName = await local.getSetting('company_name') ?? companyName;
    notifyListeners();
  }

  /// Standard stages, with fixed ids and an old timestamp so every device
  /// creates the same rows and any edit made in the cloud wins over them.
  Future<void> _seedStages() async {
    final t = DateTime.utc(2026, 1, 1);
    for (var i = 0; i < defaultStages.length; i++) {
      await local.save(
        'stages',
        Stage(
          id: _uuid.v5(
            Namespace.url.value,
            'ak-system/stage/${defaultStages[i]}',
          ),
          createdAt: t,
          updatedAt: t,
          name: defaultStages[i],
          position: i,
        ).toMap(),
      );
    }
  }

  // ---- What the current user may see -------------------------------------

  List<Project> get visibleProjects => isOwner
      ? projects
      : projects.where((p) => p.teamIds.contains(currentMemberId)).toList();

  Set<String> get _visibleProjectIds =>
      visibleProjects.map((p) => p.id).toSet();

  List<Task> get visibleTasks {
    final ids = _visibleProjectIds;
    return tasks.where((t) => ids.contains(t.projectId)).toList();
  }

  List<Deliverable> get visibleDeliverables {
    final ids = _visibleProjectIds;
    return deliverables.where((d) => ids.contains(d.projectId)).toList();
  }

  List<Client> get visibleClients {
    if (isOwner) return clients;
    final ids = visibleProjects.map((p) => p.clientId).toSet();
    return clients.where((c) => ids.contains(c.id)).toList();
  }

  // ---- Lookups ------------------------------------------------------------

  Project? project(String? id) => projects.where((p) => p.id == id).firstOrNull;
  Client? client(String? id) => clients.where((c) => c.id == id).firstOrNull;
  Stage? stage(String? id) => stages.where((s) => s.id == id).firstOrNull;
  Member? member(String? id) => members.where((m) => m.id == id).firstOrNull;

  List<Task> tasksFor(String projectId) =>
      tasks.where((t) => t.projectId == projectId).toList();
  List<Deliverable> deliverablesFor(String projectId) =>
      deliverables.where((d) => d.projectId == projectId).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
  List<Project> projectsFor(String clientId) =>
      projects.where((p) => p.clientId == clientId).toList();

  /// Next project code for the current year, e.g. AK-26-004.
  String nextProjectCode() {
    final yy = (now().year % 100).toString().padLeft(2, '0');
    final prefix = 'AK-$yy-';
    var max = 0;
    for (final p in projects) {
      if (p.code.startsWith(prefix)) {
        max = [
          max,
          int.tryParse(p.code.substring(prefix.length)) ?? 0,
        ].reduce((a, b) => a > b ? a : b);
      }
    }
    return '$prefix${(max + 1).toString().padLeft(3, '0')}';
  }

  /// Next free number for a document of this discipline and type.
  int nextDocNumber(String projectId, Discipline d, DocType t) {
    var max = 0;
    for (final x in deliverables) {
      if (x.projectId == projectId && x.discipline == d && x.docType == t) {
        if (x.number > max) max = x.number;
      }
    }
    return max + 1;
  }

  String docCode(Deliverable d) => d.docCode(project(d.projectId)?.code ?? '');

  // ---- Changes ------------------------------------------------------------

  Future<void> _write(String table, Map<String, Object?> row) async {
    await local.save(table, {
      ...row,
      'updated_at': now().toUtc().toIso8601String(),
    });
    await reload();
    onLocalChange?.call();
  }

  Future<void> saveClient(Client c) => _write('clients', c.toMap());
  Future<void> saveProject(Project p) => _write('projects', p.toMap());
  Future<void> saveTask(Task t) => _write('tasks', t.toMap());
  Future<void> saveDeliverable(Deliverable d) =>
      _write('deliverables', d.toMap());
  Future<void> saveStage(Stage s) => _write('stages', s.toMap());
  Future<void> saveMember(Member m) => _write('members', m.toMap());

  Future<void> deleteClient(Client c) =>
      _write('clients', c.copyWith(deleted: true).toMap());
  Future<void> deleteTask(Task t) =>
      _write('tasks', t.copyWith(deleted: true).toMap());
  Future<void> deleteDeliverable(Deliverable d) =>
      _write('deliverables', d.copyWith(deleted: true).toMap());
  Future<void> deleteStage(Stage s) =>
      _write('stages', s.copyWith(deleted: true).toMap());
  Future<void> deleteMember(Member m) =>
      _write('members', m.copyWith(deleted: true).toMap());

  /// Deleting a project also removes its tasks and deliverables.
  Future<void> deleteProject(Project p) async {
    for (final t in tasksFor(p.id)) {
      await local.save('tasks', {
        ...t.copyWith(deleted: true).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    for (final d in deliverablesFor(p.id)) {
      await local.save('deliverables', {
        ...d.copyWith(deleted: true).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    await _write('projects', p.copyWith(deleted: true).toMap());
  }

  Future<void> toggleTaskDone(Task t) => saveTask(
    t.copyWith(
      status: t.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done,
    ),
  );

  /// Moves a deliverable through its workflow, stamping the dates.
  Future<void> setDeliverableStatus(Deliverable d, DeliverableStatus s) {
    final t = now();
    return saveDeliverable(
      d.copyWith(
        status: s,
        submittedAt: s == DeliverableStatus.submitted ? t : null,
        approvedAt: s == DeliverableStatus.approved ? t : null,
      ),
    );
  }

  /// Starts the next revision after the client asked for changes.
  Future<void> newRevision(Deliverable d) => saveDeliverable(
    d.copyWith(version: d.version + 1, status: DeliverableStatus.draft),
  );

  Future<void> moveStage(Stage s, int delta) async {
    final list = [...stages];
    final i = list.indexWhere((x) => x.id == s.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    for (var k = 0; k < list.length; k++) {
      if (list[k].position != k) {
        await local.save('stages', {
          ...list[k].copyWith(position: k).toMap(),
          'updated_at': now().toUtc().toIso8601String(),
        });
      }
    }
    await reload();
    onLocalChange?.call();
  }

  Future<void> setCompanyName(String name) async {
    await local.setSetting('company_name', name);
    await reload();
  }

  Future<void> setCurrentMember(String? id) async {
    await local.setSetting('current_member_id', id);
    await reload();
  }
}
