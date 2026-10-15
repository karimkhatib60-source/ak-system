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
