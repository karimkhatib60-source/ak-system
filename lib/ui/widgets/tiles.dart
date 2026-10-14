import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../screens/deliverable_form.dart';
import '../screens/project_detail_screen.dart';
import '../screens/task_form.dart';
import 'common.dart';

class TaskTile extends StatelessWidget {
  const TaskTile(this.task, {super.key, this.showProject = true});

  final Task task;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final c = Theme.of(context).colorScheme;
    final now = repo.now();
    final done = task.status == TaskStatus.done;
    final late = task.isOverdue(now);
    final project = repo.project(task.projectId);
    final who = repo.member(task.assigneeId)?.name;
    final parts = [
      if (showProject && project != null) project.name,
      ?who,
      if (task.status == TaskStatus.inProgress) 'In progress',
    ];
    return ListTile(
      leading: Checkbox(
        value: done,
        onChanged: (_) => repo.toggleTaskDone(task),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: done ? TextDecoration.lineThrough : null,
          color: done ? c.outline : null,
        ),
      ),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtDue(task.dueDate, now),
            style: TextStyle(
              color: late ? c.error : c.onSurfaceVariant,
              fontWeight: late ? FontWeight.w600 : null,
              fontSize: 13,
            ),
          ),
          if (task.priority == TaskPriority.high && !done)
            Text('High', style: TextStyle(color: c.error, fontSize: 12)),
        ],
      ),
      onTap: () => openTaskForm(context, task: task),
    );
  }
}

class DeliverableTile extends StatelessWidget {
  const DeliverableTile(this.d, {super.key, this.showProject = true});

  final Deliverable d;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final c = Theme.of(context).colorScheme;
    final now = repo.now();
    final project = repo.project(d.projectId);
    final stage = repo.stage(d.stageId)?.name;
    final late = d.isOverdue(now);
    final sub = [
      if (showProject && project != null) project.name,
      ?stage,
      if (d.dueDate != null && d.status != DeliverableStatus.approved)
        dueLine(d.dueDate!, now),
      if (d.status == DeliverableStatus.submitted && d.submittedAt != null)
        'Sent ${fmtDate(d.submittedAt)}',
    ];
    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: c.secondaryContainer,
        child: Text(d.revisionLabel,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: c.onSecondaryContainer)),
      ),
      title: Text(d.title),
      subtitle: Text(sub.join(' · '),
          style: TextStyle(color: late ? c.error : null)),
      trailing: Pill(deliverableStatusShort(d.status),
          color: deliverableStatusColor(d.status, c)),
      onTap: () => openDeliverableForm(context, deliverable: d),
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard(this.p, {super.key});

  final Project p;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final c = Theme.of(context).colorScheme;
    final now = repo.now();
    final tasks = repo.tasksFor(p.id);
    final open = tasks.where((t) => t.status != TaskStatus.done).length;
    final late = tasks.where((t) => t.isOverdue(now)).length;
    final client = repo.client(p.clientId)?.name;
    final stage = repo.stage(p.stageId)?.name;
    final stageIndex = repo.stages.indexWhere((s) => s.id == p.stageId);
    final progress = repo.stages.isEmpty || stageIndex < 0
        ? 0.0
        : (stageIndex + 1) / repo.stages.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(projectId: p.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (p.code.isNotEmpty)
                    Text('${p.code}  ',
                        style: TextStyle(
                            color: c.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Pill(projectStatusLabel(p.status),
                      color: projectStatusColor(p.status, c)),
                ],
              ),
              const SizedBox(height: 4),
              Text(p.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                [
                  ?client,
                  serviceLabel(p.service),
                  if (p.location.isNotEmpty) p.location,
                ].join(' · '),
                style: TextStyle(color: c.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: progress,
                borderRadius: BorderRadius.circular(4),
                minHeight: 5,
              ),
              const SizedBox(height: 6),
              Text(stage ?? 'No stage set',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$open open'),
                  if (late > 0)
                    TextSpan(
                        text: '  ·  $late late',
                        style: TextStyle(
                            color: c.error, fontWeight: FontWeight.w600)),
                  if (p.dueDate != null)
                    TextSpan(text: '  ·  Deadline ${fmtDate(p.dueDate)}'),
                ]),
                style: TextStyle(fontSize: 13, color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
