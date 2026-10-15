import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/advisor.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'assistant_screen.dart';
import 'finance_screen.dart' show InvoiceTile;
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

    final active = projects
        .where((p) => p.status == ProjectStatus.active)
        .length;
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final lateTasks = open.where((t) => t.isOverdue(now)).toList()
      ..sort(compareTasks);
    final lateDels = dels.where((d) => d.isOverdue(now)).toList();
    final dueSoon =
        open
            .where(
              (t) =>
                  !t.isOverdue(now) &&
                  t.dueDate != null &&
                  t.dueDate!.isBefore(weekEnd),
            )
            .toList()
          ..sort(compareTasks);
    final waiting =
        dels.where((d) => d.status == DeliverableStatus.submitted).toList()
          ..sort(
            (a, b) => (a.submittedAt ?? a.updatedAt).compareTo(
              b.submittedAt ?? b.updatedAt,
            ),
          );
    final revise = dels
        .where((d) => d.status == DeliverableStatus.revise)
        .toList();
    final unpaid = repo.isOwner
        ? repo.invoices.where((i) {
            final st = repo.paymentState(i);
            return st == PaymentState.overdue ||
                st == PaymentState.unpaid ||
                st == PaymentState.partlyPaid;
          }).toList()
        : <Invoice>[];
    unpaid.sort((a, b) => (a.dueDate ?? a.date).compareTo(b.dueDate ?? b.date));
    final advice = reviewOffice(repo);

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

    final ak = AkColors.of(context);
    final dateLine = DateFormat('EEEE d MMMM yyyy').format(now).toUpperCase();
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Container(
          color: ak.chrome,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
          child: Readable(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLine,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: const Color(0xFF8FB0F7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$greeting, $name',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: ak.onChrome,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  lateTasks.isEmpty && lateDels.isEmpty
                      ? 'Nothing is late. ${dueSoon.length} due this week.'
                      : '${lateTasks.length + lateDels.length} late item${lateTasks.length + lateDels.length == 1 ? ' needs' : 's need'} attention.',
                  style: TextStyle(fontSize: 14, color: ak.onChromeMuted),
                ),
                const SizedBox(height: 18),
                LayoutBuilder(
                  builder: (context, box) {
                    final cols = box.maxWidth > 640 ? 4 : 2;
                    final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _Tile(
                          'Active projects',
                          '$active',
                          Icons.folder_outlined,
                          w,
                        ),
                        _Tile(
                          'Open tasks',
                          '${open.length}',
                          Icons.checklist,
                          w,
                        ),
                        _Tile(
                          'Late',
                          '${lateTasks.length + lateDels.length}',
                          Icons.warning_amber_rounded,
                          w,
                          alert: lateTasks.isNotEmpty || lateDels.isNotEmpty,
                        ),
                        _Tile(
                          'With clients',
                          '${waiting.length}',
                          Icons.hourglass_top_rounded,
                          w,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Readable(
          maxWidth: 900,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (lateTasks.isNotEmpty || lateDels.isNotEmpty) ...[
                const SectionHeader('Late'),
                _Group([
                  for (final d in lateDels) DeliverableTile(d),
                  for (final t in lateTasks) TaskTile(t),
                ]),
              ],
              if (unpaid.isNotEmpty) ...[
                SectionHeader(
                  'To collect · ${fmtMoneyShort(unpaid.fold(0.0, (s, i) => s + repo.balanceOf(i)))}',
                ),
                _Group([
                  for (final i in unpaid) InvoiceTile(i, showProject: true),
                ]),
              ],
              if (revise.isNotEmpty) ...[
                const SectionHeader('Client asked for changes'),
                _Group([for (final d in revise) DeliverableTile(d)]),
              ],
              const SectionHeader('Due in the next 7 days'),
              if (dueSoon.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Nothing due this week.'),
                ),
              if (dueSoon.isNotEmpty)
                _Group([for (final t in dueSoon) TaskTile(t)]),
              if (waiting.isNotEmpty) ...[
                const SectionHeader('Waiting for client approval'),
                _Group([for (final d in waiting) DeliverableTile(d)]),
              ],
              if (advice.isNotEmpty) ...[
                SectionHeader(
                  'To cover',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AssistantScreen(),
                      ),
                    ),
                    child: Text('See all ${advice.length}'),
                  ),
                ),
                _Group([for (final a in advice.take(5)) AdviceTile(a)]),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
    this.label,
    this.value,
    this.icon,
    this.width, {
    this.alert = false,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ak.chromeHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alert ? ak.bad.withValues(alpha: 0.7) : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: alert ? const Color(0xFFFF8A7A) : ak.onChrome,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: ak.onChromeMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            size: 20,
            color: alert ? const Color(0xFFFF8A7A) : const Color(0xFF8FB0F7),
          ),
        ],
      ),
    );
  }
}

/// A white card holding a list of rows, separated by hairlines.
class _Group extends StatelessWidget {
  const _Group(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    ),
  );
}
