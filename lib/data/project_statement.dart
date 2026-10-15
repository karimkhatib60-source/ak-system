import 'boq_library.dart';
import 'models.dart';
import 'repository.dart';
import 'statement.dart';

/// One contract item (a BOQ line) against what has been invoiced on it.
class ItemProgress {
  ItemProgress(this.description, this.unit);

  final String description;
  final String unit;
  double contractQty = 0;
  double contractAmount = 0;
  double invoicedQty = 0;
  double invoicedAmount = 0;

  double get percent =>
      contractAmount == 0 ? 0 : invoicedAmount / contractAmount * 100;
}

/// One trade (BOQ section) with its items.
class LayerProgress {
  LayerProgress(this.name);

  final String name;
  final items = <ItemProgress>[];

  double get contractAmount => items.fold(0, (s, i) => s + i.contractAmount);
  double get invoicedAmount => items.fold(0, (s, i) => s + i.invoicedAmount);
  double get percent =>
      contractAmount == 0 ? 0 : invoicedAmount / contractAmount * 100;
}

/// One project phase: its tasks and the invoices raised for it.
class PhaseProgress {
  PhaseProgress(this.stage);

  /// Null for invoices and tasks not linked to a phase.
  final Stage? stage;
  final tasks = <Task>[];
  final invoices = <OpenInvoice>[];

  String get name => stage?.name ?? 'Not linked to a phase';
  int get tasksDone => tasks.where((t) => t.status == TaskStatus.done).length;
  double get invoiced => invoices.fold(0, (s, i) => s + i.invoice.total);
  double get received => invoices.fold(0, (s, i) => s + i.paid);
  double get balance => ((invoiced - received) * 100).round() / 100;
}

/// One instalment of an accepted quotation's payment schedule.
class ScheduleLine {
  const ScheduleLine(this.quotation, this.index, this.status);

  final Quotation quotation;
  final int index;
  final TermStatus status;

  String get label =>
      status.term.label.isEmpty ? 'Payment ${index + 1}' : status.term.label;
}

/// Detailed statement for one project: by phase, by trade and item, and
/// the account movements.
class ProjectStatement {
  const ProjectStatement({
    required this.project,
    required this.account,
    required this.phases,
    required this.layers,
    required this.contractValue,
    required this.currentStageId,
    this.schedule = const [],
    this.extras = 0,
  });

  final Project project;
  final Statement account;
  final List<PhaseProgress> phases;
  final List<LayerProgress> layers;

  /// Accepted quotations, VAT included.
  final double contractValue;
  final String? currentStageId;

  /// Payment schedules of the accepted quotations, term by term.
  final List<ScheduleLine> schedule;

  /// Issued invoices for extra work outside the contract, VAT included.
  final double extras;

  /// Share of the contract billed so far; extra work does not count.
  double get billedPercent => contractValue == 0
      ? 0
      : (account.invoiced - extras) / contractValue * 100;
}

ProjectStatement buildProjectStatement(Repository repo, String projectId) {
  final project = repo.project(projectId)!;
  final account = buildStatement(
    repo,
    project.clientId ?? '',
    projectId: projectId,
  );
  final issued = repo
      .invoicesFor(projectId)
      .where((i) => i.status == InvoiceStatus.sent)
      .toList();

  // Phases, in stage order, with tasks and invoices.
  final phases = <String?, PhaseProgress>{
    for (final s in repo.stagesOf(projectId)) s.id: PhaseProgress(s),
  };
  PhaseProgress phaseOf(String? id) =>
      phases[id] ?? (phases[null] ??= PhaseProgress(null));
  for (final t in repo.tasksFor(projectId)) {
    phaseOf(t.stageId).tasks.add(t);
  }
  final now = repo.now();
  final today = DateTime(now.year, now.month, now.day);
  for (final i in issued) {
    final due = i.dueDate ?? i.date;
    phaseOf(i.stageId).invoices.add(
      OpenInvoice(
        i,
        repo.paidOn(i),
        today.difference(DateTime(due.year, due.month, due.day)).inDays,
      ),
    );
  }

  // Trades and items: contract from accepted quotations, invoiced from
  // issued invoices, matched by section and description. Amounts include
  // the cost-plus fee and exclude VAT.
  final layers = <String, LayerProgress>{};
  final items = <String, ItemProgress>{};
  ItemProgress item(LineItem l) {
    final layer = layers[l.section] ??= LayerProgress(l.section);
    return items['${l.section}\n${l.description}'] ??= () {
      final p = ItemProgress(l.description, l.unit);
      layer.items.add(p);
      return p;
    }();
  }

  final accepted = repo
      .quotationsFor(projectId)
      .where((q) => q.status == QuotationStatus.accepted);
  for (final q in accepted) {
    final f = 1 + q.markupRate / 100;
    for (final l in q.items) {
      final p = item(l);
      p.contractQty += l.quantity;
      p.contractAmount += l.amount * f;
    }
  }
  for (final i in issued) {
    final f = 1 + i.markupRate / 100;
    for (final l in i.items) {
      final p = item(l);
      p.invoicedQty += l.quantity;
      p.invoicedAmount += l.amount * f;
    }
  }

  return ProjectStatement(
    project: project,
    account: account,
    phases: [
      for (final p in phases.values)
        if (p.tasks.isNotEmpty || p.invoices.isNotEmpty) p,
    ],
    layers: layers.values.toList()
      ..sort((a, b) => _rank(a.name).compareTo(_rank(b.name))),
    contractValue: accepted.fold(0.0, (s, q) => s + q.total),
    extras: issued.where((i) => i.extra).fold(0.0, (s, i) => s + i.total),
    currentStageId: project.stageId,
    schedule: [
      for (final q in accepted)
        for (var k = 0; k < q.paymentTerms.length; k++)
          ScheduleLine(q, k, repo.termStatus(q, k)),
    ],
  );
}

/// Library trades in BOQ order, then any other section.
int _rank(String name) {
  final i = boqSections.indexOf(name);
  return i < 0 ? 1000 : i;
}
