import 'models.dart';
import 'repository.dart';

/// Internal profit of one project, or of the company: what was earned
/// (invoiced, without VAT) less what was spent. Never shown to clients.
class Profit {
  const Profit({
    required this.contractNet,
    required this.budgetCost,
    required this.revenue,
    required this.vat,
    required this.expenses,
    required this.received,
    this.overheads = 0,
    this.expenseVat = 0,
    this.paidOut = 0,
    this.unpaidBills = 0,
    this.extrasNet = 0,
  });

  /// Accepted quotations, before VAT.
  final double contractNet;

  /// The cost part (before the fee) of cost-plus quotations: the budget the
  /// project's expenses should stay within. Zero when none is cost-plus.
  final double budgetCost;

  /// Issued invoices, before VAT: the income earned so far.
  final double revenue;

  /// The part of [revenue] billing extra work outside the contract.
  final double extrasNet;

  /// The part of [revenue] billing the contract.
  double get onContract => revenue - extrasNet;

  /// VAT charged on those invoices. It is owed to the tax office, so it is
  /// not income.
  final double vat;

  /// Expenses booked on the project (company-wide: all expenses), without
  /// the VAT suppliers charged, which is recovered.
  final double expenses;

  /// VAT paid to suppliers on those expenses. It is set against the VAT
  /// charged on invoices.
  final double expenseVat;

  /// Expenses actually paid, VAT included.
  final double paidOut;

  /// Supplier bills not paid yet, VAT included.
  final double unpaidBills;

  /// Expenses not booked on any project (company-wide only).
  final double overheads;

  /// Money received for it, VAT included: receipts on its invoices, money
  /// set against them, and credit held for it.
  final double received;

  /// Profit on the work invoiced so far.
  double get profit => revenue - expenses;

  /// Profit as a share of income, in percent; null before any income.
  double? get margin => revenue.abs() < .005 ? null : profit / revenue * 100;

  /// Money in hand from the project: received less what was paid out.
  double get cash => received - paidOut;

  /// VAT to pay the tax office: charged on invoices less paid to suppliers.
  double get netVat => vat - expenseVat;

  /// What the budget still allows; null when there is no cost-plus budget.
  double? get budgetLeft => budgetCost == 0 ? null : budgetCost - expenses;

  /// Expected income: the contract (or what was billed on it, if more)
  /// plus extra work invoiced.
  double get income =>
      (onContract > contractNet ? onContract : contractNet) + extrasNet;

  /// Contract still to invoice.
  double get leftToInvoice =>
      contractNet - onContract > 0.005 ? contractNet - onContract : 0;

  /// Profit at completion if costs stay within the budget; a cost overrun
  /// lowers it. Null without a cost budget, since the cost of the work
  /// still to do is then unknown.
  double? get expectedProfit => budgetCost == 0
      ? null
      : income - (budgetCost > expenses ? budgetCost : expenses);

  /// Profit so far is above the forecast while invoicing stays within the
  /// contract: costs of the invoiced work may not be booked yet.
  bool get costsMayBeMissing {
    final e = expectedProfit;
    return e != null && onContract <= contractNet + 0.005 && profit > e + 0.5;
  }

  bool get isEmpty =>
      contractNet.abs() < .005 &&
      revenue.abs() < .005 &&
      expenses.abs() < .005 &&
      received.abs() < .005;
}

/// Profit of one project, or of everything when [projectId] is null.
/// [since] limits it to documents dated on or after that day.
Profit profitOf(Repository repo, {String? projectId, DateTime? since}) {
  bool inRange(DateTime d) => since == null || !d.isBefore(since);
  bool inProject(String? id) => projectId == null || id == projectId;
  final accepted = repo.quotations.where(
    (q) =>
        inProject(q.projectId) &&
        inRange(q.date) &&
        q.status == QuotationStatus.accepted,
  );
  final issued = repo.invoices.where(
    (i) =>
        inProject(i.projectId) &&
        inRange(i.date) &&
        i.status == InvoiceStatus.sent,
  );
  final spent = repo.expenses.where(
    (e) => inProject(e.projectId) && inRange(e.date),
  );
  return Profit(
    contractNet: accepted.fold(0.0, (s, q) => s + q.net),
    budgetCost: accepted
        .where((q) => q.markupRate != 0)
        .fold(0.0, (s, q) => s + q.subtotal),
    revenue: issued.fold(0.0, (s, i) => s + i.net),
    extrasNet: issued.where((i) => i.extra).fold(0.0, (s, i) => s + i.net),
    vat: issued.fold(0.0, (s, i) => s + i.vat),
    expenses: spent.fold(0.0, (s, e) => s + e.net),
    expenseVat: spent.fold(0.0, (s, e) => s + e.vat),
    paidOut: spent.where((e) => e.paid).fold(0.0, (s, e) => s + e.amount),
    unpaidBills: spent.where((e) => !e.paid).fold(0.0, (s, e) => s + e.amount),
    overheads: projectId != null
        ? 0
        : spent
              .where((e) => e.projectId == null)
              .fold(0.0, (s, e) => s + e.net),
    received: repo.receivedOn(projectId: projectId, since: since),
  );
}

/// Invoices with no project (or of a deleted project) and expenses of
/// deleted projects. Expenses booked on no project are overheads.
Profit profitOutsideProjects(Repository repo, {DateTime? since}) {
  bool inRange(DateTime d) => since == null || !d.isBefore(since);
  final issued = repo.invoices.where(
    (i) =>
        repo.project(i.projectId) == null &&
        inRange(i.date) &&
        i.status == InvoiceStatus.sent,
  );
  return Profit(
    contractNet: 0,
    budgetCost: 0,
    revenue: issued.fold(0.0, (s, i) => s + i.net),
    vat: issued.fold(0.0, (s, i) => s + i.vat),
    expenses: repo.expenses
        .where(
          (e) =>
              e.projectId != null &&
              repo.project(e.projectId) == null &&
              inRange(e.date),
        )
        .fold(0.0, (s, e) => s + e.net),
    received: 0,
  );
}

/// Profit of each project with any money on it, most profitable first.
List<(Project, Profit)> profitByProject(Repository repo, {DateTime? since}) => [
  for (final p in repo.projects)
    if (profitOf(repo, projectId: p.id, since: since) case final f
        when !f.isEmpty)
      (p, f),
]..sort((a, b) => b.$2.profit.compareTo(a.$2.profit));

/// What the income and costs of a project are matched to.
enum WorkKind {
  /// A contract: an approved quotation of the project.
  contract,

  /// Extra work outside the contracts.
  extra,

  /// Invoices, receipts and costs linked to no contract and not extra
  /// work.
  general,
}

/// The result of one piece of work on a project: a contract, extra work,
/// or what is linked to neither. Every issued invoice, receipt and expense
/// of the project counts in exactly one piece, so the pieces add up to the
/// project's figures, and a design fee and the construction works each
/// show their own profit. Internal: never shown to clients.
class WorkProfit {
  WorkProfit._(this.projectId, this.kind, this.contract);

  final String projectId;
  final WorkKind kind;

  /// The quotation, for a contract.
  final Quotation? contract;

  /// Its issued invoices, oldest first.
  final invoices = <Invoice>[];

  /// Its expenses, oldest first.
  final expenses = <Expense>[];

  /// Money set against its invoices, VAT included. In a period: money
  /// received in it, as things stood at its end, whatever the invoice's
  /// date.
  double received = 0;

  /// The part of [received] set against each invoice, by invoice id.
  final receivedOn = <String, double>{};

  /// The part of [received] set against invoices outside the period, so
  /// not in [invoices].
  double get receivedOutside =>
      invoices.fold(received, (s, i) => s - (receivedOn[i.id] ?? 0));

  /// Money held for it and not yet set against an invoice, VAT included:
  /// advances on the contract's payment terms, money on account (for the
  /// part linked to nothing) or paid on an invoice that is not issued.
  double held = 0;

  /// The contract's value without VAT, while its quotation is approved.
  double get contractNet =>
      contract?.status == QuotationStatus.accepted ? contract!.net : 0;

  /// The cost part (before the fee) of a cost-plus contract: the budget
  /// its expenses should stay within. Zero when it is not cost-plus.
  double get budgetCost =>
      contract?.status == QuotationStatus.accepted && contract!.markupRate != 0
      ? contract!.subtotal
      : 0;

  /// Issued invoices, before VAT: the income earned so far.
  double get revenue => invoices.fold(0.0, (s, i) => s + i.net);

  /// VAT charged on those invoices; owed to the tax office.
  double get vat => invoices.fold(0.0, (s, i) => s + i.vat);

  /// Its expenses without the VAT suppliers charged.
  double get cost => expenses.fold(0.0, (s, e) => s + e.net);

  /// VAT paid to suppliers on those expenses.
  double get expenseVat => expenses.fold(0.0, (s, e) => s + e.vat);

  /// Expenses paid, VAT included.
  double get paidOut =>
      expenses.where((e) => e.paid).fold(0.0, (s, e) => s + e.amount);

  /// Supplier bills not paid yet, VAT included.
  double get unpaidBills =>
      expenses.where((e) => !e.paid).fold(0.0, (s, e) => s + e.amount);

  /// Profit on the work invoiced so far.
  double get profit => revenue - cost;

  /// Profit as a share of income, in percent; null before any income.
  double? get margin => revenue.abs() < .005 ? null : profit / revenue * 100;

  /// Money in hand from this work: received and held, less paid out.
  double get cash => received + held - paidOut;

  /// What the budget still allows; null without a cost-plus budget.
  double? get budgetLeft => budgetCost == 0 ? null : budgetCost - cost;

  /// The contract still to invoice.
  double get leftToInvoice =>
      contractNet - revenue > 0.005 ? contractNet - revenue : 0;

  /// Invoiced above the contract's value.
  double get overInvoiced =>
      kind == WorkKind.contract && revenue - contractNet > 0.005
      ? revenue - contractNet
      : 0;

  /// Profit at completion if costs stay within the budget; a cost overrun
  /// lowers it. Null without a cost budget.
  double? get expectedProfit => budgetCost == 0
      ? null
      : (revenue > contractNet ? revenue : contractNet) -
            (budgetCost > cost ? budgetCost : cost);

  /// Profit so far is above the forecast while invoicing stays within the
  /// contract: costs of the invoiced work may not be booked yet.
  bool get costsMayBeMissing {
    final e = expectedProfit;
    return e != null && revenue <= contractNet + 0.005 && profit > e + 0.5;
  }

  bool get isEmpty =>
      invoices.isEmpty &&
      expenses.isEmpty &&
      received.abs() < .005 &&
      held.abs() < .005;

  /// The [Expense.copyWith] work value that links an expense to this.
  String get workKey => switch (kind) {
    WorkKind.contract => contract!.id,
    WorkKind.extra => Expense.extraWork,
    WorkKind.general => '',
  };

  String label(AppLang lang) => switch (kind) {
    WorkKind.contract => workTitle(contract!, lang),
    WorkKind.extra => 'Extra work'.inLang(lang),
    WorkKind.general => 'Not linked to a contract'.inLang(lang),
  };
}

/// "QT-26-003 · Construction works".
String workTitle(Quotation q, AppLang lang) =>
    '${q.number} · ${q.title.trim().isEmpty ? 'Contract'.inLang(lang) : q.title.trim()}';

/// The project's contracts: its approved quotations, oldest first.
List<Quotation> contractsOf(Repository repo, String? projectId) =>
    [
      for (final q in repo.quotationsFor(projectId ?? ''))
        if (q.status == QuotationStatus.accepted) q,
    ]..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.number.compareTo(b.number);
    });

/// The contract an invoice or an expense of a project counts in: the
/// quotation it is linked to when that is a quotation of the same project,
/// otherwise the project's only contract when it has exactly one. Null for
/// extra work and for what is linked to no contract.
Quotation? workContract(
  Repository repo,
  String? projectId, {
  required String? quotationId,
  required bool extra,
  List<Quotation>? contracts,
}) {
  if (extra || projectId == null) return null;
  final q = repo.quotation(quotationId);
  if (q != null && q.projectId == projectId) return q;
  final all = contracts ?? contractsOf(repo, projectId);
  return all.length == 1 ? all.single : null;
}

/// The work an expense counts in, in words.
String workLabel(Repository repo, Expense e, AppLang lang) {
  if (e.projectId == null) return 'Company overhead'.inLang(lang);
  if (e.extra) return 'Extra work'.inLang(lang);
  final q = workContract(
    repo,
    e.projectId,
    quotationId: e.quotationId,
    extra: false,
  );
  return q == null
      ? 'Not linked to a contract'.inLang(lang)
      : workTitle(q, lang);
}

/// The project's results by work: each contract (every approved quotation,
/// even before any money on it, oldest first), then extra work, then what
/// is linked to no contract. With [from] or [to], only invoices, expenses
/// and receipts dated within them count, and receipts are set against
/// invoices as they stood on [to], as the project's received figure does;
/// with [expenseIds], only those expenses.
List<WorkProfit> profitByWork(
  Repository repo,
  String projectId, {
  DateTime? from,
  DateTime? to,
  Set<String>? expenseIds,
}) {
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  bool inRange(DateTime d) =>
      (from == null || !day(d).isBefore(day(from))) &&
      (to == null || !day(d).isAfter(day(to)));
  final contracts = contractsOf(repo, projectId);
  final byContract = <String, WorkProfit>{
    for (final q in contracts)
      q.id: WorkProfit._(projectId, WorkKind.contract, q),
  };
  final extra = WorkProfit._(projectId, WorkKind.extra, null);
  final general = WorkProfit._(projectId, WorkKind.general, null);
  WorkProfit workOf(String? quotationId, bool isExtra) {
    if (isExtra) return extra;
    final q = workContract(
      repo,
      projectId,
      quotationId: quotationId,
      extra: false,
      contracts: contracts,
    );
    if (q == null) return general;
    // A quotation no longer approved still keeps what is linked to it.
    return byContract[q.id] ??= WorkProfit._(projectId, WorkKind.contract, q);
  }

  for (final i in repo.invoicesFor(projectId)) {
    if (i.status != InvoiceStatus.sent || !inRange(i.date)) continue;
    workOf(i.quotationId, i.extra).invoices.add(i);
  }
  for (final e in repo.expensesFor(projectId)) {
    if (!inRange(e.date)) continue;
    if (expenseIds != null && !expenseIds.contains(e.id)) continue;
    workOf(e.quotationId, e.extra).expenses.add(e);
  }
  // Money received: set against the project's invoices, each in its work,
  // or held for the project and not yet set against an invoice. Together
  // they make what the project received.
  for (final p in repo.payments) {
    if (!inRange(p.date)) continue;
    for (final (i, used) in repo.appliedTo(p, until: to)) {
      if (i.projectId != projectId) continue;
      final w = workOf(i.quotationId, i.extra);
      w.received += used;
      w.receivedOn[i.id] = (w.receivedOn[i.id] ?? 0) + used;
    }
    if (repo.homeProject(p) != projectId) continue;
    final held = repo.unappliedOf(p, until: to);
    if (held.abs() < .005) continue;
    final inv = p.onInvoice ? repo.invoice(p.invoiceId) : null;
    final w = inv != null
        ? workOf(inv.quotationId, inv.extra)
        : p.quotationId != null
        ? workOf(p.quotationId, false)
        : general;
    w.held += held;
  }
  int byDate(DateTime a, String an, DateTime b, String bn) {
    final c = day(a).compareTo(day(b));
    return c != 0 ? c : an.compareTo(bn);
  }

  final works = [...byContract.values, extra, general];
  for (final w in works) {
    w.invoices.sort((a, b) => byDate(a.date, a.number, b.date, b.number));
    w.expenses.sort((a, b) => byDate(a.date, a.number, b.date, b.number));
  }
  return [
    for (final w in works)
      if (!w.isEmpty ||
          (w.kind == WorkKind.contract &&
              w.contract!.status == QuotationStatus.accepted))
        w,
  ];
}

/// The internal cost and profit report of an export: the chosen expenses
/// by project and work, with each work's income and result. Never for
/// the client.
class CostReport {
  CostReport(this.repo, this.expenses, {this.projectId, this.from, this.to});

  final Repository repo;

  /// The chosen expenses.
  final List<Expense> expenses;

  /// Null for every project.
  final String? projectId;
  final DateTime? from;
  final DateTime? to;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _inRange(DateTime d) =>
      (from == null || !_day(d).isBefore(_day(from!))) &&
      (to == null || !_day(d).isAfter(_day(to!)));

  late final Map<Project, List<WorkProfit>> _byProject = {
    for (final p
        in projectId != null ? [?repo.project(projectId)] : repo.projects)
      p: profitByWork(
        repo,
        p.id,
        from: from,
        to: to,
        expenseIds: {for (final e in expenses) e.id},
      ),
  };

  /// The projects in the report: the one exported, or every project with
  /// income, money received or a chosen expense in the period.
  late final List<Project> projects = [
    for (final MapEntry(key: p, value: works) in _byProject.entries)
      if (projectId != null || works.any((w) => !w.isEmpty)) p,
  ];

  /// The works of those projects, counting only the chosen expenses.
  late final List<WorkProfit> works = [
    for (final p in projects) ..._byProject[p]!,
  ];

  /// Chosen expenses on no project (company overheads) or on a deleted one.
  late final List<Expense> outside = [
    for (final e in expenses)
      if (repo.project(e.projectId) == null) e,
  ];

  /// For every project: issued invoices of no project, or of a deleted
  /// one, so the totals match the company's.
  late final List<Invoice> invoicesOutside = projectId != null
      ? const []
      : [
          for (final i in repo.invoices)
            if (i.status == InvoiceStatus.sent &&
                _inRange(i.date) &&
                repo.project(i.projectId) == null)
              i,
        ];

  /// For every project: money received in the period that went to no
  /// project, or to a deleted one.
  late final double receivedOutside = projectId != null
      ? 0
      : repo.payments.where((p) => _inRange(p.date)).fold(0.0, (s, p) {
          final gone = {
            repo.homeProject(p),
            for (final (i, _) in repo.appliedTo(p, until: to)) i.projectId,
          }.where((id) => repo.project(id) == null);
          return s +
              gone.fold(0.0, (t, id) => t + repo.receivedFor(p, id, until: to));
        });

  /// Invoiced outside projects, without VAT.
  double get revenueOutside => invoicesOutside.fold(0.0, (s, i) => s + i.net);

  double get overheads => outside.fold(0.0, (s, e) => s + e.net);

  double get revenue =>
      works.fold(0.0, (s, w) => s + w.revenue) + revenueOutside;
  double get received =>
      works.fold(0.0, (s, w) => s + w.received + w.held) + receivedOutside;
  double get cost => works.fold(0.0, (s, w) => s + w.cost) + overheads;
  double get profit => revenue - cost;
}
