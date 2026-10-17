import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../l10n/lang.dart';

import '../data/models.dart';
import 'theme.dart';

/// [s] kept left to right inside Arabic text, so a phone number, an email
/// or a handle reads as typed ("+961 79 180 650", "@ak").
String ltr(String s) => s.isEmpty ? s : '\u2066$s\u2069';

final _strongLetter = RegExp(
  r'[A-Za-z\u00C0-\u024F\u0620-\u064A\u066E-\u06D3\u06FA-\u06FF'
  r'\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]',
);

/// The direction of text the user typed, by its first letter: Arabic reads
/// right to left and English left to right, whatever the screens'
/// language. Null when it has no letters.
TextDirection? directionOf(String s) {
  final m = _strongLetter.firstMatch(s);
  if (m == null) return null;
  return m[0]!.codeUnitAt(0) >= 0x0600 ? TextDirection.rtl : TextDirection.ltr;
}

/// Parts of a line joined by " · ". On Arabic screens each part keeps its
/// own direction, so a date or an English name beside it stays whole.
extension Dots on Iterable<String> {
  String dots() => appLang == AppLang.ar
      ? map((s) => s.isEmpty ? s : '\u2068$s\u2069').join(' · ')
      : join(' · ');
}

/// A date in the language of the screens.
String fmtDate(DateTime? d) => d == null ? '—' : dayIn(appLang, d);

/// A date in the language of printed documents.
String fmtDocDate(DateTime? d) => d == null ? '—' : dayIn(docLang, d);

/// "Today", "Tomorrow", "3 days late", or a short date.
String fmtDue(DateTime? d, DateTime now) {
  if (d == null) return 'No date'.tr;
  final diff = _daysAhead(d, now);
  if (diff == 0) return 'Today'.tr;
  if (diff == 1) return 'Tomorrow'.tr;
  if (diff == -1) return '1 day late'.tr;
  // Two has its own wording in Arabic; the English is the same.
  if (diff == -2) return '2 days late'.tr;
  if (diff < 0) return '{0} days late'.trArgs([-diff]);
  if (diff == 2) return 'In 2 days'.tr;
  if (diff < 7) return 'In {0} days'.trArgs([diff]);
  return dayIn(appLang, d, year: false);
}

/// Whole days from today to [d]; negative when [d] is past.
int _daysAhead(DateTime d, DateTime now) => DateTime(
  d.year,
  d.month,
  d.day,
).difference(DateTime(now.year, now.month, now.day)).inDays;

String serviceLabel(ServiceType s, [AppLang? lang]) => switch (s) {
  ServiceType.design => 'Design'.inLang(lang ?? appLang),
  ServiceType.consultancy => 'Consultancy'.inLang(lang ?? appLang),
  ServiceType.contracting => 'Contracting'.inLang(lang ?? appLang),
};

String projectStatusLabel(ProjectStatus s, [AppLang? lang]) => switch (s) {
  ProjectStatus.lead => 'Lead'.inLang(lang ?? appLang),
  ProjectStatus.active => 'Active'.inLang(lang ?? appLang),
  ProjectStatus.onHold => 'On hold'.inLang(lang ?? appLang),
  ProjectStatus.completed => 'Completed'.inLang(lang ?? appLang),
  ProjectStatus.cancelled => 'Cancelled'.inLang(lang ?? appLang),
};

String taskStatusLabel(TaskStatus s, [AppLang? lang]) => switch (s) {
  TaskStatus.todo => 'To do'.inLang(lang ?? appLang),
  TaskStatus.inProgress => 'In progress'.inLang(lang ?? appLang),
  TaskStatus.done => 'Done'.inLang(lang ?? appLang),
};

String priorityLabel(TaskPriority p, [AppLang? lang]) => switch (p) {
  TaskPriority.low => 'Low'.inLang(lang ?? appLang),
  TaskPriority.normal => 'Normal'.inLang(lang ?? appLang),
  TaskPriority.high => 'High'.inLang(lang ?? appLang),
};

String deliverableStatusLabel(
  DeliverableStatus s, [
  AppLang? lang,
]) => switch (s) {
  DeliverableStatus.draft => 'Draft'.inLang(lang ?? appLang),
  DeliverableStatus.internalReview => 'Internal review'.inLang(lang ?? appLang),
  DeliverableStatus.submitted => 'Submitted to client'.inLang(lang ?? appLang),
  DeliverableStatus.approved => 'Approved'.inLang(lang ?? appLang),
  DeliverableStatus.revise => 'Client asked for changes'.inLang(
    lang ?? appLang,
  ),
};

/// Short label for list badges where space is tight.
String deliverableStatusShort(DeliverableStatus s, [AppLang? lang]) =>
    switch (s) {
      DeliverableStatus.draft => 'Draft'.inLang(lang ?? appLang),
      DeliverableStatus.internalReview => 'In review'.inLang(lang ?? appLang),
      DeliverableStatus.submitted => 'With client'.inLang(lang ?? appLang),
      DeliverableStatus.approved => 'Approved'.inLang(lang ?? appLang),
      DeliverableStatus.revise => 'Changes'.inLang(lang ?? appLang),
    };

/// "Due tomorrow", "Due 25 Oct", or "2 days late".
String dueLine(DateTime d, DateTime now) {
  final diff = _daysAhead(d, now);
  if (diff < 0) return fmtDue(d, now);
  if (diff == 0) return 'Due today'.tr;
  if (diff == 1) return 'Due tomorrow'.tr;
  if (diff == 2) return 'Due in 2 days'.tr;
  if (diff < 7) return 'Due in {0} days'.trArgs([diff]);
  return 'Due {0}'.trArgs([dayIn(appLang, d, year: false)]);
}

String roleLabel(MemberRole r, [AppLang? lang]) => switch (r) {
  MemberRole.owner => 'Owner'.inLang(lang ?? appLang),
  MemberRole.architect => 'Architect'.inLang(lang ?? appLang),
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

String projectTypeLabel(ProjectType t, [AppLang? lang]) => switch (t) {
  ProjectType.residential => 'Residential'.inLang(lang ?? appLang),
  ProjectType.commercial => 'Commercial / office'.inLang(lang ?? appLang),
  ProjectType.hospitality => 'Hospitality'.inLang(lang ?? appLang),
  ProjectType.interior => 'Interior fit-out'.inLang(lang ?? appLang),
  ProjectType.mixedUse => 'Mixed-use'.inLang(lang ?? appLang),
  ProjectType.industrial => 'Industrial'.inLang(lang ?? appLang),
  ProjectType.landscape => 'Landscape'.inLang(lang ?? appLang),
  ProjectType.other => 'Other'.inLang(lang ?? appLang),
};

String taskCategoryLabel(TaskCategory c, [AppLang? lang]) => switch (c) {
  TaskCategory.design => 'Design'.inLang(lang ?? appLang),
  TaskCategory.drawings => 'Drawings'.inLang(lang ?? appLang),
  TaskCategory.siteVisit => 'Site visit'.inLang(lang ?? appLang),
  TaskCategory.meeting => 'Meeting'.inLang(lang ?? appLang),
  TaskCategory.coordination => 'Coordination'.inLang(lang ?? appLang),
  TaskCategory.admin => 'Admin'.inLang(lang ?? appLang),
};

IconData taskCategoryIcon(TaskCategory c) => switch (c) {
  TaskCategory.design => Icons.architecture,
  TaskCategory.drawings => Icons.straighten,
  TaskCategory.siteVisit => Icons.engineering_outlined,
  TaskCategory.meeting => Icons.groups_outlined,
  TaskCategory.coordination => Icons.hub_outlined,
  TaskCategory.admin => Icons.inventory_2_outlined,
};

String noteKindLabel(NoteKind k) => switch (k) {
  NoteKind.general => 'General@@note'.tr,
  NoteKind.meeting => 'Meeting'.tr,
  NoteKind.siteVisit => 'Site visit'.tr,
  NoteKind.clientRequest => 'Client request'.tr,
  NoteKind.decision => 'Decision'.tr,
};

IconData noteKindIcon(NoteKind k) => switch (k) {
  NoteKind.general => Icons.sticky_note_2_outlined,
  NoteKind.meeting => Icons.groups_outlined,
  NoteKind.siteVisit => Icons.engineering_outlined,
  NoteKind.clientRequest => Icons.record_voice_over_outlined,
  NoteKind.decision => Icons.gavel_outlined,
};

String disciplineLabel(Discipline d, [AppLang? lang]) => switch (d) {
  Discipline.architecture => 'Architecture'.inLang(lang ?? appLang),
  Discipline.interior => 'Interior design'.inLang(lang ?? appLang),
  Discipline.structure => 'Structure'.inLang(lang ?? appLang),
  Discipline.mep => 'MEP'.inLang(lang ?? appLang),
  Discipline.landscape => 'Landscape'.inLang(lang ?? appLang),
  Discipline.general => 'General'.inLang(lang ?? appLang),
};

String docTypeLabel(DocType t, [AppLang? lang]) => switch (t) {
  DocType.drawing => 'Drawing'.inLang(lang ?? appLang),
  DocType.report => 'Report'.inLang(lang ?? appLang),
  DocType.presentation => 'Presentation'.inLang(lang ?? appLang),
  DocType.model => '3D model / render'.inLang(lang ?? appLang),
  DocType.boq => 'Bill of quantities'.inLang(lang ?? appLang),
  DocType.specification => 'Specification'.inLang(lang ?? appLang),
  DocType.letter => 'Letter / transmittal'.inLang(lang ?? appLang),
};

String fmtArea(double? a) {
  if (a == null) return '—';
  final s = a == a.roundToDouble()
      ? a.toStringAsFixed(0)
      : a.toStringAsFixed(1);
  return '{0} m²'.trArgs([
    NumberFormat.decimalPattern().format(double.parse(s)),
  ]);
}

final _money = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _moneyRound = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

/// "$12,500.00"
String fmtMoney(double v) => _money.format(v.abs() < .005 ? 0 : v);

/// "$12,500", for summaries.
String fmtMoneyShort(double v) => _moneyRound.format(v.abs() < .5 ? 0 : v);

String quotationStatusLabel(QuotationStatus s, [AppLang? lang]) => switch (s) {
  QuotationStatus.draft => 'Draft'.inLang(lang ?? appLang),
  QuotationStatus.sent => 'Sent'.inLang(lang ?? appLang),
  QuotationStatus.accepted => 'Approved'.inLang(lang ?? appLang),
  QuotationStatus.rejected => 'Rejected'.inLang(lang ?? appLang),
};

Color quotationStatusColor(QuotationStatus s) => switch (s) {
  QuotationStatus.draft => AkPalette.slate,
  QuotationStatus.sent => AkPalette.blue,
  QuotationStatus.accepted => AkPalette.good,
  QuotationStatus.rejected => AkPalette.bad,
};

String paymentStateLabel(PaymentState s, [AppLang? lang]) => switch (s) {
  PaymentState.draft => 'Draft'.inLang(lang ?? appLang),
  PaymentState.unpaid => 'Unpaid'.inLang(lang ?? appLang),
  PaymentState.partlyPaid => 'Part paid'.inLang(lang ?? appLang),
  PaymentState.paid => 'Paid'.inLang(lang ?? appLang),
  PaymentState.overdue => 'Overdue'.inLang(lang ?? appLang),
  PaymentState.cancelled => 'Cancelled@@invoice'.inLang(lang ?? appLang),
};

Color paymentStateColor(PaymentState s) => switch (s) {
  PaymentState.draft => AkPalette.slate,
  PaymentState.unpaid => AkPalette.blue,
  PaymentState.partlyPaid => AkPalette.warn,
  PaymentState.paid => AkPalette.good,
  PaymentState.overdue => AkPalette.bad,
  PaymentState.cancelled => AkPalette.slate,
};

String paymentMethodLabel(PaymentMethod m, [AppLang? lang]) => switch (m) {
  PaymentMethod.bankTransfer => 'Bank transfer'.inLang(lang ?? appLang),
  PaymentMethod.cash => 'Cash'.inLang(lang ?? appLang),
  PaymentMethod.cheque => 'Cheque'.inLang(lang ?? appLang),
  PaymentMethod.card => 'Card'.inLang(lang ?? appLang),
  PaymentMethod.other => 'Other'.inLang(lang ?? appLang),
};

String expenseCategoryLabel(ExpenseCategory c, [AppLang? lang]) => switch (c) {
  ExpenseCategory.materials => 'Materials'.inLang(lang ?? appLang),
  ExpenseCategory.subcontractor => 'Subcontractor'.inLang(lang ?? appLang),
  ExpenseCategory.labour => 'Labour (daily workers)'.inLang(lang ?? appLang),
  ExpenseCategory.equipment => 'Equipment and tool rental'.inLang(
    lang ?? appLang,
  ),
  ExpenseCategory.salaries => 'Salaries and fees to team'.inLang(
    lang ?? appLang,
  ),
  ExpenseCategory.rent => 'Office rent and utilities'.inLang(lang ?? appLang),
  ExpenseCategory.software => 'Software and licences'.inLang(lang ?? appLang),
  ExpenseCategory.transport => 'Transport and site visits'.inLang(
    lang ?? appLang,
  ),
  ExpenseCategory.printing => 'Printing and models'.inLang(lang ?? appLang),
  ExpenseCategory.marketing => 'Marketing'.inLang(lang ?? appLang),
  ExpenseCategory.fees => 'Permits and official fees'.inLang(lang ?? appLang),
  ExpenseCategory.other => 'Other'.inLang(lang ?? appLang),
};

IconData expenseCategoryIcon(ExpenseCategory c) => switch (c) {
  ExpenseCategory.materials => Icons.inventory_2_outlined,
  ExpenseCategory.subcontractor => Icons.engineering_outlined,
  ExpenseCategory.labour => Icons.construction_outlined,
  ExpenseCategory.equipment => Icons.handyman_outlined,
  ExpenseCategory.salaries => Icons.badge_outlined,
  ExpenseCategory.rent => Icons.apartment_outlined,
  ExpenseCategory.software => Icons.computer_outlined,
  ExpenseCategory.transport => Icons.directions_car_outlined,
  ExpenseCategory.printing => Icons.print_outlined,
  ExpenseCategory.marketing => Icons.campaign_outlined,
  ExpenseCategory.fees => Icons.account_balance_outlined,
  ExpenseCategory.other => Icons.receipt_outlined,
};
