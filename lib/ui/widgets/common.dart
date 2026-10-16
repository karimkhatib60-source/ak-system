import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../sync/sync_service.dart';
import '../../l10n/lang.dart';
import '../format.dart';
import '../theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: c.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: TextStyle(color: c.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small coloured label, e.g. a status.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                // Spacing would break the joined letters of Arabic.
                letterSpacing: isArabic ? 0 : 1.3,
                color: ak.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A form field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(2020),
          lastDate: DateTime(now.year + 10),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Clear date'.tr,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value == null ? 'Not set'.tr : fmtDate(value)),
      ),
    );
  }
}

/// Shows whether changes are saved on this device only, syncing, or synced.
class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final (icon, tip) = switch (sync.state) {
      SyncState.localOnly => (
        Icons.phone_android,
        'Saved on this device. Set up cloud sync in Settings.'.tr,
      ),
      SyncState.idle => (Icons.cloud_done_outlined, 'All changes synced'.tr),
      SyncState.syncing => (Icons.cloud_sync_outlined, 'Syncing…'.tr),
      SyncState.offline => (
        Icons.cloud_off_outlined,
        'Offline. Changes are saved and will sync when you reconnect.'.tr,
      ),
      SyncState.error => (
        Icons.error_outline,
        'Sync problem: {0}'.trArgs([sync.lastError ?? 'unknown'.tr]),
      ),
    };
    return IconButton(
      tooltip: tip,
      icon: Icon(icon),
      onPressed: sync.remote == null
          ? () =>
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(tip)))
          : sync.syncNow,
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String what) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete {0}?'.trArgs([what])),
      content: Text('This cannot be undone.'.tr),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete'.tr),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Constrains forms and lists to a readable width on a laptop screen.
class Readable extends StatelessWidget {
  const Readable({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// One row of a list drawn as a single white card: rounded at the first and
/// last row, hairlines between.
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.index,
    required this.count,
    required this.child,
  });

  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    const r = Radius.circular(14);
    final first = index == 0, last = index == count - 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: ak.card,
          borderRadius: BorderRadius.vertical(
            top: first ? r : Radius.zero,
            bottom: last ? r : Radius.zero,
          ),
          border: Border(
            left: BorderSide(color: ak.line),
            right: BorderSide(color: ak.line),
            top: first ? BorderSide(color: ak.line) : BorderSide.none,
            bottom: BorderSide(color: ak.line, width: last ? 1 : 0.6),
          ),
        ),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}
