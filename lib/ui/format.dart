import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';

final _day = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('d MMM');

String fmtDate(DateTime? d) => d == null ? '—' : _day.format(d);

/// "Today", "Tomorrow", "3 days late", or a short date.
String fmtDue(DateTime? d, DateTime now) {
  if (d == null) return 'No date';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return '1 day late';
  if (diff < 0) return '${-diff} days late';
  if (diff < 7) return 'In $diff days';
  return _dayShort.format(d);
}

String serviceLabel(ServiceType s) => switch (s) {
      ServiceType.design => 'Design',
      ServiceType.consultancy => 'Consultancy',
      ServiceType.contracting => 'Contracting',
    };

String projectStatusLabel(ProjectStatus s) => switch (s) {
      ProjectStatus.lead => 'Lead',
      ProjectStatus.active => 'Active',
      ProjectStatus.onHold => 'On hold',
      ProjectStatus.completed => 'Completed',
      ProjectStatus.cancelled => 'Cancelled',
    };

String taskStatusLabel(TaskStatus s) => switch (s) {
      TaskStatus.todo => 'To do',
      TaskStatus.inProgress => 'In progress',
      TaskStatus.done => 'Done',
    };

String priorityLabel(TaskPriority p) => switch (p) {
      TaskPriority.low => 'Low',
      TaskPriority.normal => 'Normal',
      TaskPriority.high => 'High',
    };

String deliverableStatusLabel(DeliverableStatus s) => switch (s) {
      DeliverableStatus.draft => 'Draft',
      DeliverableStatus.internalReview => 'Internal review',
      DeliverableStatus.submitted => 'Submitted to client',
      DeliverableStatus.approved => 'Approved',
      DeliverableStatus.revise => 'Client asked for changes',
    };

/// Short label for list badges where space is tight.
String deliverableStatusShort(DeliverableStatus s) => switch (s) {
      DeliverableStatus.draft => 'Draft',
      DeliverableStatus.internalReview => 'In review',
      DeliverableStatus.submitted => 'With client',
      DeliverableStatus.approved => 'Approved',
      DeliverableStatus.revise => 'Changes',
    };

/// "Due tomorrow", "Due 25 Oct", or "2 days late".
String dueLine(DateTime d, DateTime now) {
  final s = fmtDue(d, now);
  if (s.endsWith('late')) return s;
  final first = s[0];
  return 'Due ${first.toUpperCase() == first && int.tryParse(first) == null && !RegExp(r'^[A-Z][a-z]{2} ').hasMatch(s) ? first.toLowerCase() + s.substring(1) : s}';
}

String roleLabel(MemberRole r) => switch (r) {
      MemberRole.owner => 'Owner',
      MemberRole.architect => 'Architect',
    };

Color projectStatusColor(ProjectStatus s, ColorScheme c) => switch (s) {
      ProjectStatus.lead => Colors.blueGrey,
      ProjectStatus.active => c.primary,
      ProjectStatus.onHold => Colors.orange.shade700,
      ProjectStatus.completed => Colors.green.shade700,
      ProjectStatus.cancelled => c.outline,
    };

Color deliverableStatusColor(DeliverableStatus s, ColorScheme c) => switch (s) {
      DeliverableStatus.draft => c.outline,
      DeliverableStatus.internalReview => Colors.blueGrey,
      DeliverableStatus.submitted => c.primary,
      DeliverableStatus.approved => Colors.green.shade700,
      DeliverableStatus.revise => Colors.orange.shade800,
    };

Color priorityColor(TaskPriority p, ColorScheme c) => switch (p) {
      TaskPriority.low => c.outline,
      TaskPriority.normal => c.onSurfaceVariant,
      TaskPriority.high => c.error,
    };
