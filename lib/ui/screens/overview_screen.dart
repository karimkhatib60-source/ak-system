import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'project_detail_screen.dart' show compareTasks;

/// Today's picture: what is late, what is due this week, and what is
/// waiting on clients.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final now = repo.now();
    final weekEnd = DateTime(now.year, now.month, now.day + 7);
    final projects = repo.visibleProjects;
    final tasks = repo.visibleTasks;
    final dels = repo.visibleDeliverables;

    final active =
        projects.where((p) => p.status == ProjectStatus.active).length;
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final lateTasks = open.where((t) => t.isOverdue(now)).toList()
      ..sort(compareTasks);
    final lateDels = dels.where((d) => d.isOverdue(now)).toList();
    final dueSoon = open
        .where((t) =>
            !t.isOverdue(now) &&
            t.dueDate != null &&
            t.dueDate!.isBefore(weekEnd))
        .toList()
      ..sort(compareTasks);
    final waiting =
        dels.where((d) => d.status == DeliverableStatus.submitted).toList()
          ..sort((a, b) => (a.submittedAt ?? a.updatedAt)
              .compareTo(b.submittedAt ?? b.updatedAt));
    final revise =
        dels.where((d) => d.status == DeliverableStatus.revise).toList();

    final name = repo.currentMember?.name.split(' ').first ?? 'Karim';
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';

    if (projects.isEmpty) {
      return EmptyState(
        icon: Icons.architecture,
        title: '$greeting, $name',
        message: repo.isOwner
            ? 'Start by adding a client and a project. Everything else, tasks, '
                'deliverables and deadlines, hangs off the project.'
            : 'You will see your projects here once you are added to one.',
      );
    }

    return Readable(
      maxWidth: 900,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('$greeting, $name',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth / (box.maxWidth > 640 ? 4 : 2);
              return Wrap(
                children: [
                  _Tile('Active projects', '$active', Icons.folder_outlined, w),
                  _Tile('Open tasks', '${open.length}', Icons.checklist, w),
                  _Tile('Late', '${lateTasks.length + lateDels.length}',
                      Icons.warning_amber_rounded, w,
                      alert: lateTasks.isNotEmpty || lateDels.isNotEmpty),
                  _Tile('With clients', '${waiting.length}',
                      Icons.hourglass_top_rounded, w),
                ],
              );
            }),
          ),
          if (lateTasks.isNotEmpty || lateDels.isNotEmpty) ...[
            const SectionHeader('Late'),
            for (final d in lateDels) DeliverableTile(d),
            for (final t in lateTasks) TaskTile(t),
          ],
          if (revise.isNotEmpty) ...[
            const SectionHeader('Client asked for changes'),
            for (final d in revise) DeliverableTile(d),
          ],
          const SectionHeader('Due in the next 7 days'),
          if (dueSoon.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Nothing due this week.'),
            ),
          for (final t in dueSoon) TaskTile(t),
          if (waiting.isNotEmpty) ...[
            const SectionHeader('Waiting for client approval'),
            for (final d in waiting) DeliverableTile(d),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value, this.icon, this.width,
      {this.alert = false});

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final color = alert ? c.error : c.primary;
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: alert ? c.error : null)),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c.onSurfaceVariant)),
                  ],
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
