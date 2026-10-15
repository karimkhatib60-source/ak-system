import 'package:intl/intl.dart';

import 'models.dart';
import 'repository.dart';

enum AdviceLevel { urgent, important, tip }

/// One thing the office may have missed, with where to fix it.
class Advice {
  const Advice(this.level, this.title, this.detail, {this.projectId});

  final AdviceLevel level;
  final String title;
  final String detail;
  final String? projectId;
}

/// Free, built-in review of the office's records: what is missing, late or
/// waiting. Runs on the device with no AI service.
List<Advice> reviewOffice(Repository repo, {String? projectId}) {
  final out = <Advice>[];
  final now = repo.now();
  final today = DateTime(now.year, now.month, now.day);
  int daysSince(DateTime d) =>
      today.difference(DateTime(d.year, d.month, d.day)).inDays;

  final projects = repo.visibleProjects.where(
    (p) =>
        (projectId == null || p.id == projectId) &&
        (p.status == ProjectStatus.active || p.status == ProjectStatus.lead),
  );

  for (final p in projects) {
    final name = p.code.isEmpty ? p.name : '${p.code} ${p.name}';
    void add(AdviceLevel l, String t, String d) =>
        out.add(Advice(l, t, '$name: $d', projectId: p.id));

    final client = repo.client(p.clientId);
    if (client == null) {
      add(AdviceLevel.important, 'No client linked', 'link the client.');
    } else if (client.phone.isEmpty && client.email.isEmpty) {
      add(
        AdviceLevel.tip,
        'Client contact missing',
        'add a phone or email for ${client.name}.',
      );
    }
    if (p.dueDate == null) {
      add(AdviceLevel.important, 'No deadline', 'set the delivery deadline.');
    } else if (p.dueDate!.isBefore(today) && p.status == ProjectStatus.active) {
      add(
        AdviceLevel.urgent,
        'Deadline passed',
        'the deadline was ${daysSince(p.dueDate!)} days ago. '
            'Agree a new date or close the project.',
      );
    }
    if (p.location.isEmpty && p.mapLink.isEmpty) {
      add(AdviceLevel.tip, 'No site location', 'add the Google Maps pin.');
    } else if (p.mapLink.isEmpty && !p.abroad) {
      add(AdviceLevel.tip, 'No map pin', 'add the exact Google Maps pin.');
    }
    if (p.areaSqm == null && p.service != ServiceType.consultancy) {
      add(
        AdviceLevel.tip,
        'Area not recorded',
        'add the built-up area in m² (needed for fees and BOQ).',
      );
    }
    if (p.stageId == null || repo.stage(p.stageId) == null) {
      add(AdviceLevel.important, 'No current stage', 'set the stage.');
    }
    if (repo.members.isNotEmpty && p.teamIds.isEmpty) {
      add(AdviceLevel.tip, 'No team assigned', 'add the architect to it.');
    }

    final tasks = repo.tasksFor(p.id);
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final late = open.where((t) => t.isOverdue(now)).length;
    if (late > 0) {
      add(
        AdviceLevel.urgent,
        '$late late task${late == 1 ? '' : 's'}',
        'follow up or move the dates.',
      );
    }
    if (p.status == ProjectStatus.active && open.isEmpty) {
      add(
        AdviceLevel.important,
        'No open tasks',
        'plan the next tasks for the ${repo.stage(p.stageId)?.name ?? 'current'} stage.',
      );
    }
    final noDate = open.where((t) => t.dueDate == null).length;
    if (noDate > 0) {
      add(
        AdviceLevel.tip,
        '$noDate task${noDate == 1 ? '' : 's'} without a date',
        'give each task a due date.',
      );
    }
    for (final d in repo.deliverablesFor(p.id)) {
      if (d.status == DeliverableStatus.submitted &&
          d.submittedAt != null &&
          daysSince(d.submittedAt!) >= 10) {
        add(
          AdviceLevel.important,
          'Waiting on client',
          '"${d.title}" was sent ${daysSince(d.submittedAt!)} days ago with '
              'no answer. Call the client.',
        );
      }
      if (d.status == DeliverableStatus.revise) {
        add(
          AdviceLevel.important,
          'Client asked for changes',
          'start revision R${d.version.toString().padLeft(2, '0')} of "${d.title}".',
        );
      }
    }

    if (!repo.isOwner) continue;
    final quotes = repo.quotationsFor(p.id);
    final invoices = repo.invoicesFor(p.id);
    if (quotes.isEmpty && invoices.isEmpty) {
      add(
        AdviceLevel.important,
        'No quotation',
        'send a fee quotation before work goes further.',
      );
    }
    for (final q in quotes) {
      if (q.status == QuotationStatus.sent && daysSince(q.date) >= 14) {
        add(
          AdviceLevel.important,
          'Quotation unanswered',
          '${q.number} was sent ${daysSince(q.date)} days ago. Follow up.',
        );
      }
      if (q.status == QuotationStatus.sent &&
          q.validUntil != null &&
          q.validUntil!.isBefore(today)) {
        add(
          AdviceLevel.tip,
          'Quotation expired',
          '${q.number} is past its validity date.',
        );
      }
    }
    final accepted = quotes
        .where((q) => q.status == QuotationStatus.accepted)
        .fold(0.0, (s, q) => s + q.total);
    if (accepted > 0 && invoices.isEmpty) {
      add(
        AdviceLevel.important,
        'Accepted but not invoiced',
        'issue the first invoice (advance payment).',
      );
    }
    for (final i in invoices) {
      if (repo.paymentState(i) == PaymentState.overdue) {
        add(
          AdviceLevel.urgent,
          'Invoice overdue',
          '${i.number}: ${_money(repo.balanceOf(i))} not paid.',
        );
      }
      if (i.status == InvoiceStatus.draft && daysSince(i.date) >= 3) {
        add(
          AdviceLevel.tip,
          'Invoice still a draft',
          '${i.number} has not been issued.',
        );
      }
    }
  }

  if (projectId == null) {
    if (repo.isOwner) {
      final info = repo.companyInfo;
      if ((info['phone'] ?? '').isEmpty || (info['email'] ?? '').isEmpty) {
        out.add(
          const Advice(
            AdviceLevel.tip,
            'Company details incomplete',
            'Add phone and email in Settings so they print on quotations.',
          ),
        );
      }
      if ((info['bank'] ?? '').isEmpty && repo.invoices.isNotEmpty) {
        out.add(
          const Advice(
            AdviceLevel.tip,
            'Bank details missing',
            'Add bank details in Settings so clients know how to pay.',
          ),
        );
      }
    }
    final idle = repo.visibleProjects.where(
      (p) => p.status == ProjectStatus.lead && daysSince(p.createdAt) >= 21,
    );
    for (final p in idle) {
      out.add(
        Advice(
          AdviceLevel.tip,
          'Lead going cold',
          '${p.name} has been a lead for ${daysSince(p.createdAt)} days. '
              'Follow up or mark it cancelled.',
          projectId: p.id,
        ),
      );
    }
  }

  out.sort((a, b) => a.level.index.compareTo(b.level.index));
  return out;
}

final _fmt = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

String _money(double v) => _fmt.format(v);
