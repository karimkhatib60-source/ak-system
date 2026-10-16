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
      add(AdviceLevel.important, 'No client linked'.tr, 'link the client.'.tr);
    } else if (client.phone.isEmpty && client.email.isEmpty) {
      add(
        AdviceLevel.tip,
        'Client contact missing'.tr,
        'add a phone or email for {0}.'.trArgs([client.name]),
      );
    }
    if (p.dueDate == null) {
      add(
        AdviceLevel.important,
        'No deadline'.tr,
        'set the delivery deadline.'.tr,
      );
    } else if (p.dueDate!.isBefore(today) && p.status == ProjectStatus.active) {
      add(
        AdviceLevel.urgent,
        'Deadline passed'.tr,
        'the deadline was {0} days ago. '
                'Agree a new date or close the project.'
            .trArgs([daysSince(p.dueDate!)]),
      );
    }
    if (p.location.isEmpty && p.mapLink.isEmpty) {
      add(
        AdviceLevel.tip,
        'No site location'.tr,
        'add the Google Maps pin.'.tr,
      );
    } else if (p.mapLink.isEmpty && !p.abroad) {
      add(
        AdviceLevel.tip,
        'No map pin'.tr,
        'add the exact Google Maps pin.'.tr,
      );
    }
    if (p.areaSqm == null && p.service != ServiceType.consultancy) {
      add(
        AdviceLevel.tip,
        'Area not recorded'.tr,
        'add the built-up area in m² (needed for fees and BOQ).'.tr,
      );
    }
    if (p.stageId == null || repo.stage(p.stageId) == null) {
      add(AdviceLevel.important, 'No current stage'.tr, 'set the stage.'.tr);
    }
    if (repo.members.isNotEmpty && p.teamIds.isEmpty) {
      add(
        AdviceLevel.tip,
        'No team assigned'.tr,
        'add the architect to it.'.tr,
      );
    }

    final tasks = repo.tasksFor(p.id);
    final open = tasks.where((t) => t.status != TaskStatus.done).toList();
    final late = open.where((t) => t.isOverdue(now)).length;
    if (late > 0) {
      add(
        AdviceLevel.urgent,
        late == 1 ? '1 late task'.tr : '{0} late tasks'.trArgs([late]),
        'follow up or move the dates.'.tr,
      );
    }
    if (p.status == ProjectStatus.active && open.isEmpty) {
      final stage = repo.stage(p.stageId)?.name;
      add(
        AdviceLevel.important,
        'No open tasks'.tr,
        stage == null
            ? 'plan the next tasks for the current stage.'.tr
            : 'plan the next tasks for the {0} stage.'.trArgs([stage.tr]),
      );
    }
    final noDate = open.where((t) => t.dueDate == null).length;
    if (noDate > 0) {
      add(
        AdviceLevel.tip,
        noDate == 1
            ? '1 task without a date'.tr
            : '{0} tasks without a date'.trArgs([noDate]),
        'give each task a due date.'.tr,
      );
    }
    for (final d in repo.deliverablesFor(p.id)) {
      if (d.status == DeliverableStatus.submitted &&
          d.submittedAt != null &&
          daysSince(d.submittedAt!) >= 10) {
        add(
          AdviceLevel.important,
          'Waiting on client'.tr,
          '"{0}" was sent {1} days ago with no answer. Call the client.'.trArgs(
            [d.title, daysSince(d.submittedAt!)],
          ),
        );
      }
      if (d.status == DeliverableStatus.revise) {
        add(
          AdviceLevel.important,
          'Client asked for changes'.tr,
          'start revision R{0} of "{1}".'.trArgs([
            d.version.toString().padLeft(2, '0'),
            d.title,
          ]),
        );
      }
    }

    if (!repo.isOwner) continue;
    final quotes = repo.quotationsFor(p.id);
    final invoices = repo.invoicesFor(p.id);
    if (quotes.isEmpty && invoices.isEmpty) {
      add(
        AdviceLevel.important,
        'No quotation'.tr,
        'send a fee quotation before work goes further.'.tr,
      );
    }
    for (final q in quotes) {
      if (q.status == QuotationStatus.sent && daysSince(q.date) >= 14) {
        add(
          AdviceLevel.important,
          'Quotation unanswered'.tr,
          '{0} was sent {1} days ago. Follow up.'.trArgs([
            q.number,
            daysSince(q.date),
          ]),
        );
      }
      if (q.status == QuotationStatus.sent &&
          q.validUntil != null &&
          q.validUntil!.isBefore(today)) {
        add(
          AdviceLevel.tip,
          'Quotation expired'.tr,
          '{0} is past its validity date.'.trArgs([q.number]),
        );
      }
    }
    final accepted = quotes
        .where((q) => q.status == QuotationStatus.accepted)
        .fold(0.0, (s, q) => s + q.total);
    if (accepted > 0 && invoices.isEmpty) {
      add(
        AdviceLevel.important,
        'Approved but not invoiced'.tr,
        'issue the first invoice (advance payment).'.tr,
      );
    }
    for (final i in invoices) {
      if (repo.paymentState(i) == PaymentState.overdue) {
        add(
          AdviceLevel.urgent,
          'Invoice overdue'.tr,
          '{0}: {1} not paid.'.trArgs([i.number, _money(repo.balanceOf(i))]),
        );
      }
      if (i.status == InvoiceStatus.draft && daysSince(i.date) >= 3) {
        add(
          AdviceLevel.tip,
          'Invoice still a draft'.tr,
          '{0} has not been issued.'.trArgs([i.number]),
        );
      }
    }
  }

  if (projectId == null) {
    if (repo.isOwner) {
      final info = repo.companyInfo;
      if ((info['phone'] ?? '').isEmpty || (info['email'] ?? '').isEmpty) {
        out.add(
          Advice(
            AdviceLevel.tip,
            'Company details incomplete'.tr,
            'Add phone and email in Settings so they print on quotations.'.tr,
          ),
        );
      }
      // Two devices working offline can give one number twice.
      for (final (title, numbers) in [
        (
          'Quotation number used twice'.tr,
          repo.quotations.map((q) => q.number),
        ),
        ('Invoice number used twice'.tr, repo.invoices.map((i) => i.number)),
        ('Receipt number used twice'.tr, repo.payments.map((p) => p.number)),
      ]) {
        final seen = <String>{};
        for (final n in numbers.where((n) => n.isNotEmpty)) {
          if (!seen.add(n)) {
            out.add(
              Advice(
                AdviceLevel.urgent,
                title,
                '{0} is on two documents. Give one of them a new number '
                        'before sending it.'
                    .trArgs([n]),
              ),
            );
          }
        }
      }
      if ((info['bank'] ?? '').isEmpty && repo.invoices.isNotEmpty) {
        out.add(
          Advice(
            AdviceLevel.tip,
            'Bank details missing'.tr,
            'Add bank details in Settings so clients know how to pay.'.tr,
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
          'Lead going cold'.tr,
          '{0} has been a lead for {1} days. Follow up or mark it cancelled.'
              .trArgs([p.name, daysSince(p.createdAt)]),
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
