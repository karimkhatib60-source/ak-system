import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import 'theme.dart';

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
  ProjectStatus.lead => AkPalette.info,
  ProjectStatus.active => AkPalette.good,
  ProjectStatus.onHold => AkPalette.warn,
  ProjectStatus.completed => AkPalette.slate,
  ProjectStatus.cancelled => c.outline,
};

Color deliverableStatusColor(DeliverableStatus s, ColorScheme c) => switch (s) {
  DeliverableStatus.draft => c.outline,
  DeliverableStatus.internalReview => AkPalette.info,
  DeliverableStatus.submitted => AkPalette.blueDeep,
  DeliverableStatus.approved => AkPalette.good,
  DeliverableStatus.revise => AkPalette.warn,
};

Color priorityColor(TaskPriority p, ColorScheme c) => switch (p) {
  TaskPriority.low => c.outline,
  TaskPriority.normal => c.onSurfaceVariant,
  TaskPriority.high => c.error,
};

String projectTypeLabel(ProjectType t) => switch (t) {
  ProjectType.residential => 'Residential',
  ProjectType.commercial => 'Commercial / office',
  ProjectType.hospitality => 'Hospitality',
  ProjectType.interior => 'Interior fit-out',
  ProjectType.mixedUse => 'Mixed-use',
  ProjectType.industrial => 'Industrial',
  ProjectType.landscape => 'Landscape',
  ProjectType.other => 'Other',
};

String taskCategoryLabel(TaskCategory c) => switch (c) {
  TaskCategory.design => 'Design',
  TaskCategory.drawings => 'Drawings',
  TaskCategory.siteVisit => 'Site visit',
  TaskCategory.meeting => 'Meeting',
  TaskCategory.coordination => 'Coordination',
  TaskCategory.admin => 'Admin',
};

IconData taskCategoryIcon(TaskCategory c) => switch (c) {
  TaskCategory.design => Icons.architecture,
  TaskCategory.drawings => Icons.straighten,
  TaskCategory.siteVisit => Icons.engineering_outlined,
  TaskCategory.meeting => Icons.groups_outlined,
  TaskCategory.coordination => Icons.hub_outlined,
  TaskCategory.admin => Icons.inventory_2_outlined,
};

String disciplineLabel(Discipline d) => switch (d) {
  Discipline.architecture => 'Architecture',
  Discipline.interior => 'Interior design',
  Discipline.structure => 'Structure',
  Discipline.mep => 'MEP',
  Discipline.landscape => 'Landscape',
  Discipline.general => 'General',
};

String docTypeLabel(DocType t) => switch (t) {
  DocType.drawing => 'Drawing',
  DocType.report => 'Report',
  DocType.presentation => 'Presentation',
  DocType.model => '3D model / render',
  DocType.boq => 'Bill of quantities',
  DocType.specification => 'Specification',
  DocType.letter => 'Letter / transmittal',
};

String fmtArea(double? a) {
  if (a == null) return '—';
  final s = a == a.roundToDouble()
      ? a.toStringAsFixed(0)
      : a.toStringAsFixed(1);
  return '${NumberFormat.decimalPattern().format(double.parse(s))} m²';
}

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _moneyRound = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// "$12,500.00"
String fmtMoney(double v) => _money.format(v.abs() < .005 ? 0 : v);

/// "$12,500", for summaries.
String fmtMoneyShort(double v) => _moneyRound.format(v.abs() < .5 ? 0 : v);

String quotationStatusLabel(QuotationStatus s) => switch (s) {
  QuotationStatus.draft => 'Draft',
  QuotationStatus.sent => 'Sent',
  QuotationStatus.accepted => 'Accepted',
  QuotationStatus.rejected => 'Rejected',
};

Color quotationStatusColor(QuotationStatus s) => switch (s) {
  QuotationStatus.draft => AkPalette.slate,
  QuotationStatus.sent => AkPalette.blue,
  QuotationStatus.accepted => AkPalette.good,
  QuotationStatus.rejected => AkPalette.bad,
};

String paymentStateLabel(PaymentState s) => switch (s) {
  PaymentState.draft => 'Draft',
  PaymentState.unpaid => 'Unpaid',
  PaymentState.partlyPaid => 'Part paid',
  PaymentState.paid => 'Paid',
  PaymentState.overdue => 'Overdue',
  PaymentState.cancelled => 'Cancelled',
};

Color paymentStateColor(PaymentState s) => switch (s) {
  PaymentState.draft => AkPalette.slate,
  PaymentState.unpaid => AkPalette.blue,
  PaymentState.partlyPaid => AkPalette.warn,
  PaymentState.paid => AkPalette.good,
  PaymentState.overdue => AkPalette.bad,
  PaymentState.cancelled => AkPalette.slate,
};

String paymentMethodLabel(PaymentMethod m) => switch (m) {
  PaymentMethod.bankTransfer => 'Bank transfer',
  PaymentMethod.cash => 'Cash',
  PaymentMethod.cheque => 'Cheque',
  PaymentMethod.card => 'Card',
  PaymentMethod.other => 'Other',
};

String expenseCategoryLabel(ExpenseCategory c) => switch (c) {
  ExpenseCategory.subcontractor => 'Subcontractor',
  ExpenseCategory.materials => 'Materials',
  ExpenseCategory.salaries => 'Salaries and fees to team',
  ExpenseCategory.rent => 'Office rent and utilities',
  ExpenseCategory.software => 'Software and licences',
  ExpenseCategory.transport => 'Transport and site visits',
  ExpenseCategory.printing => 'Printing and models',
  ExpenseCategory.marketing => 'Marketing',
  ExpenseCategory.fees => 'Permits and official fees',
  ExpenseCategory.other => 'Other',
};

IconData expenseCategoryIcon(ExpenseCategory c) => switch (c) {
  ExpenseCategory.subcontractor => Icons.engineering_outlined,
  ExpenseCategory.materials => Icons.inventory_2_outlined,
  ExpenseCategory.salaries => Icons.badge_outlined,
  ExpenseCategory.rent => Icons.apartment_outlined,
  ExpenseCategory.software => Icons.computer_outlined,
  ExpenseCategory.transport => Icons.directions_car_outlined,
  ExpenseCategory.printing => Icons.print_outlined,
  ExpenseCategory.marketing => Icons.campaign_outlined,
  ExpenseCategory.fees => Icons.account_balance_outlined,
  ExpenseCategory.other => Icons.receipt_outlined,
};
