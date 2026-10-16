import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';

Future<void> openTaskForm(
  BuildContext context, {
  Task? task,
  String? projectId,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TaskForm(task: task, projectId: projectId),
    ),
  );
}

class TaskForm extends StatefulWidget {
  const TaskForm({super.key, this.task, this.projectId});

  final Task? task;
  final String? projectId;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  String? _projectId;
  String? _assigneeId;
  String? _stageId;
  DateTime? _due;
  TaskStatus _status = TaskStatus.todo;
  TaskPriority _priority = TaskPriority.normal;
  TaskCategory _category = TaskCategory.design;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    final repo = context.read<Repository>();
    _title = TextEditingController(text: t?.title ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _projectId = t?.projectId ?? widget.projectId;
    _assigneeId = t?.assigneeId ?? repo.currentMemberId;
    _stageId = t?.stageId ?? repo.project(_projectId)?.stageId;
    _due = t?.dueDate;
    _status = t?.status ?? TaskStatus.todo;
    _priority = t?.priority ?? TaskPriority.normal;
    _category = t?.category ?? TaskCategory.design;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final t = widget.task;
    final now = repo.now();
    await repo.saveTask(
      Task(
        id: t?.id ?? repo.newId(),
        createdAt: t?.createdAt ?? now,
        updatedAt: now,
        projectId: _projectId!,
        title: _title.text.trim(),
        assigneeId: _assigneeId,
        dueDate: _due,
        status: _status,
        priority: _priority,
        category: _category,
        stageId: _stageId,
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this task'.tr)) return;
    if (!mounted) return;
    await context.read<Repository>().deleteTask(widget.task!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'New task'.tr : 'Edit task'.tr),
        actions: [
          if (widget.task != null)
            IconButton(
              tooltip: 'Delete'.tr,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: FilledButton(onPressed: _save, child: Text('Save'.tr)),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _title,
                autofocus: widget.task == null,
                decoration: InputDecoration(labelText: 'Task'.tr),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter the task'.tr : null,
              ),
              gap,
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in TaskCategory.values)
                    ChoiceChip(
                      avatar: Icon(taskCategoryIcon(c), size: 16),
                      label: Text(taskCategoryLabel(c)),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Project'.tr),
                items: [
                  for (final p in repo.visibleProjects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() {
                  _projectId = v;
                  _stageId = repo.project(v)?.stageId;
                }),
                validator: (v) => v == null ? 'Choose a project'.tr : null,
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'Due date'.tr,
                      value: _due,
                      onChanged: (d) => setState(() => _due = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<TaskPriority>(
                      initialValue: _priority,
                      decoration: InputDecoration(labelText: 'Priority'.tr),
                      items: [
                        for (final p in TaskPriority.values)
                          DropdownMenuItem(
                            value: p,
                            child: Text(priorityLabel(p)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              gap,
              if (repo.members.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: repo.member(_assigneeId) == null
                      ? null
                      : _assigneeId,
                  decoration: InputDecoration(labelText: 'Assigned to'.tr),
                  items: [
                    DropdownMenuItem(value: null, child: Text('Nobody yet'.tr)),
                    for (final m in repo.members)
                      DropdownMenuItem(value: m.id, child: Text(m.name)),
                  ],
                  onChanged: (v) => setState(() => _assigneeId = v),
                ),
                gap,
              ],
              DropdownButtonFormField<String?>(
                key: ValueKey(_projectId),
                initialValue:
                    repo.stagesOf(_projectId).any((s) => s.id == _stageId)
                    ? _stageId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Stage'.tr),
                items: [
                  DropdownMenuItem(value: null, child: Text('None'.tr)),
                  for (final s in repo.stagesOf(_projectId))
                    DropdownMenuItem(value: s.id, child: Text(s.name.tr)),
                ],
                onChanged: (v) => setState(() => _stageId = v),
              ),
              gap,
              SegmentedButton<TaskStatus>(
                segments: [
                  for (final s in TaskStatus.values)
                    ButtonSegment(value: s, label: Text(taskStatusLabel(s))),
                ],
                selected: {_status},
                onSelectionChanged: (v) => setState(() => _status = v.first),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(labelText: 'Notes'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
