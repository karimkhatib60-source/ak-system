import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'deliverable_form.dart';
import 'project_detail_screen.dart' show compareTasks;
import 'project_form.dart';
import 'task_form.dart';

// ---------------------------------------------------------------- Projects --

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

enum _ProjectFilter { current, leads, finished, all }

class _ProjectsScreenState extends State<ProjectsScreen> {
  _ProjectFilter _filter = _ProjectFilter.current;
  String _query = '';

  bool _matches(Project p) => switch (_filter) {
    _ProjectFilter.current =>
      p.status == ProjectStatus.active || p.status == ProjectStatus.onHold,
    _ProjectFilter.leads => p.status == ProjectStatus.lead,
    _ProjectFilter.finished =>
      p.status == ProjectStatus.completed ||
          p.status == ProjectStatus.cancelled,
    _ProjectFilter.all => true,
  };

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final q = _query.toLowerCase();
    final list = repo.visibleProjects
        .where(_matches)
        .where(
          (p) =>
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.code.toLowerCase().contains(q) ||
              (repo.client(p.clientId)?.name.toLowerCase().contains(q) ??
                  false),
        )
        .toList();
    return Scaffold(
      floatingActionButton: repo.isOwner
          ? FloatingActionButton.extended(
              heroTag: 'add-project',
              onPressed: () => openProjectForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Project'),
            )
          : null,
      body: Readable(
        maxWidth: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by name, code or client',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  for (final f in _ProjectFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(switch (f) {
                          _ProjectFilter.current => 'Current',
                          _ProjectFilter.leads => 'Leads',
                          _ProjectFilter.finished => 'Finished',
                          _ProjectFilter.all => 'All',
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'No projects here',
                      message: repo.isOwner
                          ? 'Tap "Project" to add your first one.'
                          : 'Projects you are added to appear here.',
                    )
                  : LayoutBuilder(
                      builder: (context, box) {
                        final cols = box.maxWidth > 760 ? 2 : 1;
                        final w = (box.maxWidth - 32 - 10 * (cols - 1)) / cols;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final p in list)
                                SizedBox(width: w, child: ProjectCard(p)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Tasks --

enum _TaskFilter { mine, open, late, done }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  _TaskFilter? _filter;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final now = repo.now();
    final hasMe = repo.currentMemberId != null;
    final filter = _filter ?? (hasMe ? _TaskFilter.mine : _TaskFilter.open);
    final tasks =
        repo.visibleTasks
            .where(
              (t) => switch (filter) {
                _TaskFilter.mine =>
                  t.assigneeId == repo.currentMemberId &&
                      t.status != TaskStatus.done,
                _TaskFilter.open => t.status != TaskStatus.done,
                _TaskFilter.late => t.isOverdue(now),
                _TaskFilter.done => t.status == TaskStatus.done,
              },
            )
            .toList()
          ..sort(compareTasks);
    if (filter == _TaskFilter.done) {
      tasks.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return Scaffold(
      floatingActionButton: repo.visibleProjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add-task-all',
              onPressed: () => openTaskForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Task'),
            ),
      body: Readable(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  for (final f in _TaskFilter.values)
                    if (f != _TaskFilter.mine || hasMe)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(switch (f) {
                            _TaskFilter.mine => 'Mine',
                            _TaskFilter.open => 'All open',
                            _TaskFilter.late => 'Late',
                            _TaskFilter.done => 'Done',
                          }),
                          selected: filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? EmptyState(
                      icon: filter == _TaskFilter.late
                          ? Icons.celebration_outlined
                          : Icons.checklist,
                      title: switch (filter) {
                        _TaskFilter.late => 'Nothing is late',
                        _TaskFilter.done => 'No finished tasks yet',
                        _ => 'No open tasks',
                      },
                      message: repo.visibleProjects.isEmpty
                          ? 'Create a project first, then add its tasks.'
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (_, i) => GroupedRow(
                        index: i,
                        count: tasks.length,
                        child: TaskTile(tasks[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Deliverables --

class DeliverablesScreen extends StatefulWidget {
  const DeliverablesScreen({super.key});

  @override
  State<DeliverablesScreen> createState() => _DeliverablesScreenState();
}

class _DeliverablesScreenState extends State<DeliverablesScreen> {
  DeliverableStatus? _status;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final all = repo.visibleDeliverables;
    final list =
        all.where((d) => _status == null || d.status == _status).toList()
          ..sort((a, b) {
            final ad = a.dueDate, bd = b.dueDate;
            if (ad == null && bd == null) {
              return b.updatedAt.compareTo(a.updatedAt);
            }
            if (ad == null) return 1;
            if (bd == null) return -1;
            return ad.compareTo(bd);
          });
    int count(DeliverableStatus s) => all.where((d) => d.status == s).length;
    return Scaffold(
      floatingActionButton: repo.visibleProjects.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'add-deliverable-all',
              onPressed: () => openDeliverableForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Deliverable'),
            ),
      body: Readable(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('All ${all.length}'),
                      selected: _status == null,
                      onSelected: (_) => setState(() => _status = null),
                    ),
                  ),
                  for (final s in DeliverableStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${deliverableStatusLabel(s)} ${count(s)}'),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No deliverables here',
                      message: 'Track every drawing set and report you send a client.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (_, i) => GroupedRow(
                        index: i,
                        count: list.length,
                        child: DeliverableTile(list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
