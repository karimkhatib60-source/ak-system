import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'client_detail_screen.dart';
import 'deliverable_form.dart';
import 'project_form.dart';
import 'task_form.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final p = repo.project(projectId);
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'Project not found',
        ),
      );
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            if (repo.isOwner) ...[
              IconButton(
                tooltip: 'Edit project',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => openProjectForm(context, project: p),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete' &&
                      await confirmDelete(
                        context,
                        '${p.name} with its tasks and deliverables',
                      )) {
                    await repo.deleteProject(p);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'delete', child: Text('Delete project')),
                ],
              ),
            ],
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Tasks'),
              Tab(text: 'Deliverables'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _Overview(p: p),
            _Tasks(p: p),
            _Deliverables(p: p),
          ],
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.p});

  final Project p;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = Theme.of(context).colorScheme;
    final client = repo.client(p.clientId);
    final now = repo.now();
    final tasks = repo.tasksFor(p.id);
    final dels = repo.deliverablesFor(p.id);
    final currentIndex = repo.stages.indexWhere((s) => s.id == p.stageId);

    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: c.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );

    return Readable(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (p.code.isNotEmpty)
                        Text(
                          '${p.code}  ',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      Pill(
                        projectStatusLabel(p.status),
                        color: projectStatusColor(p.status, c),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  fact(
                    'Service',
                    '${serviceLabel(p.service)}${p.abroad ? ' (outside Lebanon)' : ''}',
                  ),
                  fact('Type', projectTypeLabel(p.type)),
                  if (p.areaSqm != null) fact('Area', fmtArea(p.areaSqm)),
                  if (p.location.isNotEmpty) fact('Location', p.location),
                  fact('Start', fmtDate(p.startDate)),
                  fact('Deadline', fmtDate(p.dueDate)),
                  if (p.teamIds.isNotEmpty)
                    fact(
                      'Team',
                      p.teamIds
                          .map((id) => repo.member(id)?.name)
                          .whereType<String>()
                          .join(', '),
                    ),
                  if (p.notes.isNotEmpty) fact('Notes', p.notes),
                ],
              ),
            ),
          ),
          if (client != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(client.name),
                subtitle: client.phone.isEmpty && client.email.isEmpty
                    ? null
                    : Text(
                        [
                          client.phone,
                          client.email,
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(clientId: client.id),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                'Open tasks',
                '${tasks.where((t) => t.status != TaskStatus.done).length}',
              ),
              const SizedBox(width: 8),
              _Stat(
                'Late tasks',
                '${tasks.where((t) => t.isOverdue(now)).length}',
                alert: tasks.any((t) => t.isOverdue(now)),
              ),
              const SizedBox(width: 8),
              _Stat(
                'Approved',
                '${dels.where((d) => d.status == DeliverableStatus.approved).length}/${dels.length}',
              ),
            ],
          ),
          const SectionHeader('Stages'),
          Card(
            child: Column(
              children: [
                for (var i = 0; i < repo.stages.length; i++)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      i < currentIndex
                          ? Icons.check_circle
                          : i == currentIndex
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: i <= currentIndex ? c.primary : c.outline,
                    ),
                    title: Text(
                      repo.stages[i].name,
                      style: TextStyle(
                        fontWeight: i == currentIndex ? FontWeight.w700 : null,
                      ),
                    ),
                    trailing: i == currentIndex
                        ? const Text('Current')
                        : repo.isOwner
                        ? TextButton(
                            onPressed: () => repo.saveProject(
                              p.copyWith(stageId: repo.stages[i].id),
                            ),
                            child: const Text('Set'),
                          )
                        : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.alert = false});

  final String label;
  final String value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: alert ? c.error : null,
                ),
              ),
              Text(label, style: TextStyle(color: c.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tasks extends StatelessWidget {
  const _Tasks({required this.p});

  final Project p;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final tasks = repo.tasksFor(p.id)..sort(compareTasks);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-task',
        onPressed: () => openTaskForm(context, projectId: p.id),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: tasks.isEmpty
          ? const EmptyState(
              icon: Icons.checklist,
              title: 'No tasks yet',
              message: 'Add the work needed for the current stage.',
            )
          : Readable(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final t in tasks) TaskTile(t, showProject: false),
                ],
              ),
            ),
    );
  }
}

class _Deliverables extends StatelessWidget {
  const _Deliverables({required this.p});

  final Project p;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final dels = repo.deliverablesFor(p.id);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-deliverable',
        onPressed: () => openDeliverableForm(context, projectId: p.id),
        icon: const Icon(Icons.add),
        label: const Text('Deliverable'),
      ),
      body: dels.isEmpty
          ? const EmptyState(
              icon: Icons.description_outlined,
              title: 'No deliverables yet',
              message: 'Drawings, reports and packages you send the client.',
            )
          : Readable(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 88),
                children: [
                  for (final d in dels) DeliverableTile(d, showProject: false),
                ],
              ),
            ),
    );
  }
}

/// Open tasks first, by due date (undated last), then finished ones.
int compareTasks(Task a, Task b) {
  final ad = a.status == TaskStatus.done, bd = b.status == TaskStatus.done;
  if (ad != bd) return ad ? 1 : -1;
  if (a.dueDate == null && b.dueDate == null) return a.title.compareTo(b.title);
  if (a.dueDate == null) return 1;
  if (b.dueDate == null) return -1;
  return a.dueDate!.compareTo(b.dueDate!);
}
