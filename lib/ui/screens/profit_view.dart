import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/profit.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'expenses.dart';
import 'money_doc_form.dart';
import 'project_detail_screen.dart';

String _margin(double? m) => m == null ? '—' : '${m.round()}%';

/// A project's internal profit as a whole: income without VAT less
/// expenses, and the cash in hand. Each contract's own result, budget and
/// forecast are on its [WorkCard]. Owner only; none of this is printed on
/// client documents.
class ProfitCard extends StatelessWidget {
  const ProfitCard(this.f, {super.key});

  final Profit f;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    Color tone(double v) => v < -0.005 ? ak.bad : ak.good;
    Widget row(
      String label,
      String value, {
      bool bold = false,
      Color? color,
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
                ),
                if (hint != null)
                  Text(hint, style: TextStyle(color: ak.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : null,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, size: 15, color: ak.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PROJECT TOTAL · INTERNAL'.tr,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: ak.muted,
                    ),
                  ),
                ),
                if (f.margin != null)
                  Pill(
                    '{0} margin'.trArgs([_margin(f.margin)]),
                    color: f.profit < 0 ? AkPalette.bad : AkPalette.good,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            row('Invoiced, without VAT'.tr, fmtMoney(f.revenue)),
            row(
              f.expenseVat > 0.005 ? 'Expenses, without VAT'.tr : 'Expenses'.tr,
              fmtMoney(f.expenses == 0 ? 0 : -f.expenses),
            ),
            const Divider(height: 14),
            row(
              'Profit on invoiced work'.tr,
              fmtMoney(f.profit),
              bold: true,
              color: tone(f.profit),
              hint: f.costsMayBeMissing
                  ? 'Above the expected profit: some costs of the invoiced '
                            'work may not be recorded yet'
                        .tr
                  : null,
            ),
            const SizedBox(height: 10),
            row(
              'Cash in hand'.tr,
              fmtMoney(f.cash),
              color: tone(f.cash),
              hint: 'Received {0} less expenses paid'.trArgs([
                fmtMoney(f.received),
              ]),
            ),
            if (f.paidOut > 0.005)
              row(
                'Paid to suppliers'.tr,
                fmtMoney(f.paidOut),
                hint: 'Bills paid, VAT included'.tr,
              ),
            if (f.unpaidBills > 0.005)
              row(
                'Unpaid supplier bills'.tr,
                fmtMoney(f.unpaidBills),
                color: ak.warn,
                hint:
                    'Still to pay, VAT included; the cost without VAT is '
                            'already in expenses'
                        .tr,
              ),
            const SizedBox(height: 8),
            Text(
              [
                if (f.vat > 0.005 && f.expenseVat > 0.005)
                  f.netVat > 0.005
                      ? 'VAT: {0} on your invoices less {1} charged by '
                                'suppliers, so {2} is owed to the tax office. '
                                'VAT is not income or cost.'
                            .trArgs([
                              fmtMoney(f.vat),
                              fmtMoney(f.expenseVat),
                              fmtMoney(f.netVat),
                            ])
                      : f.netVat < -0.005
                      ? 'VAT: {0} on your invoices less {1} charged by '
                                'suppliers, so you have a VAT credit of {2} '
                                'to set against VAT on future invoices. VAT is '
                                'not income or cost.'
                            .trArgs([
                              fmtMoney(f.vat),
                              fmtMoney(f.expenseVat),
                              fmtMoney(-f.netVat),
                            ])
                      : 'VAT: {0} on your invoices less {1} charged by '
                                'suppliers, so no VAT is owed. VAT is not '
                                'income or cost.'
                            .trArgs([fmtMoney(f.vat), fmtMoney(f.expenseVat)])
                else if (f.vat > 0.005)
                  'VAT of {0} on your invoices is owed to the tax office, so '
                          'it is not counted as income.'
                      .trArgs([fmtMoney(f.vat)])
                else if (f.expenseVat > 0.005)
                  'VAT of {0} charged by suppliers is recoverable, so it is '
                          'not counted as cost.'
                      .trArgs([fmtMoney(f.expenseVat)]),
                'Expenses and profit never appear on client documents.'.tr,
              ].join(' '),
              style: TextStyle(color: ak.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every project with money on it, by profit, then income not on a
/// project, company overheads and the total.
List<Widget> profitTiles(BuildContext context, {DateTime? since}) {
  final repo = context.watch<Repository>();
  final ak = AkColors.of(context);
  final all = profitOf(repo, since: since);
  final outside = profitOutsideProjects(repo, since: since);
  final rows = profitByProject(repo, since: since);
  Widget amount(double v, String note) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        fmtMoneyShort(v),
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: v < -0.005 ? ak.bad : ak.good,
        ),
      ),
      const SizedBox(height: 2),
      Text(note, style: TextStyle(fontSize: 12, color: ak.muted)),
    ],
  );
  String margin(Profit f) => f.margin == null
      ? 'no income yet'.tr
      : '{0} margin'.trArgs([_margin(f.margin)]);
  return [
    for (final (p, f) in rows)
      ListTile(
        title: Text(
          '${p.code} · ${p.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Invoiced {0} without VAT · expenses {1}'.trArgs([
            fmtMoneyShort(f.revenue),
            fmtMoneyShort(f.expenses),
          ]),
        ),
        trailing: amount(f.profit, margin(f)),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(projectId: p.id),
          ),
        ),
      ),
    if (!outside.isEmpty)
      ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('Not on a project'.tr),
        subtitle: Text(
          outside.expenses > 0.005
              ? 'Invoiced {0} without VAT · expenses {1} · invoices with no '
                        'project or of a deleted one'
                    .trArgs([
                      fmtMoneyShort(outside.revenue),
                      fmtMoneyShort(outside.expenses),
                    ])
              : 'Invoiced {0} without VAT · invoices with no project or of a '
                        'deleted one'
                    .trArgs([fmtMoneyShort(outside.revenue)]),
        ),
        trailing: amount(outside.profit, margin(outside)),
      ),
    if (all.overheads > 0.005)
      ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: Text('Company overheads'.tr),
        subtitle: Text('Expenses not booked on a project'.tr),
        trailing: Text(
          fmtMoneyShort(-all.overheads),
          style: TextStyle(fontWeight: FontWeight.w800, color: ak.bad),
        ),
      ),
    if (rows.isNotEmpty || !outside.isEmpty || all.overheads > 0.005)
      ListTile(
        title: Text(
          'Total profit'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Invoiced {0} without VAT · expenses {1}'.trArgs([
            fmtMoneyShort(all.revenue),
            fmtMoneyShort(all.expenses),
          ]),
        ),
        trailing: amount(all.profit, margin(all)),
      ),
  ];
}

/// One piece of work of a project (a contract, extra work, or what is
/// linked to no contract) with its own income, money received, costs and
/// profit, and the invoices and expenses behind them. Owner only.
class WorkCard extends StatefulWidget {
  const WorkCard(this.w, {super.key});

  final WorkProfit w;

  @override
  State<WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<WorkCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final ak = AkColors.of(context);
    final w = widget.w;
    Color tone(double v) => v < -0.005 ? ak.bad : ak.good;
    Widget row(
      String label,
      String value, {
      bool bold = false,
      Color? color,
      String? hint,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontWeight: bold ? FontWeight.w800 : null),
                ),
                if (hint != null)
                  Text(hint, style: TextStyle(color: ak.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : null,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    final icon = switch (w.kind) {
      WorkKind.contract => Icons.handshake_outlined,
      WorkKind.extra => Icons.add_circle_outline,
      WorkKind.general => Icons.link_off,
    };
    final contracts = contractsOf(repo, w.projectId);
    final unlinked = w.kind == WorkKind.general ? w.expenses : <Expense>[];
    final left = w.budgetLeft;
    final notApproved =
        w.kind == WorkKind.contract &&
        w.contract!.status != QuotationStatus.accepted;
    final bills = w.expenses.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: ak.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w.label(appLang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (w.margin != null)
                  Pill(
                    '{0} margin'.trArgs([_margin(w.margin)]),
                    color: w.profit < 0 ? AkPalette.bad : AkPalette.good,
                  ),
              ],
            ),
            if (w.kind == WorkKind.contract)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 26, top: 2),
                child: Text(
                  [
                    if (notApproved)
                      '{0}, not approved'.trArgs([
                        quotationStatusLabel(w.contract!.status),
                      ])
                    else
                      'Contract {0} without VAT'.trArgs([
                        fmtMoney(w.contractNet),
                      ]),
                    if (w.leftToInvoice > 0)
                      '{0} still to invoice'.trArgs([fmtMoney(w.leftToInvoice)])
                    else if (w.overInvoiced > 0)
                      '{0} invoiced above the contract'.trArgs([
                        fmtMoney(w.overInvoiced),
                      ])
                    else if (!notApproved && w.revenue > 0)
                      'Fully invoiced'.tr,
                  ].dots(),
                  style: TextStyle(color: ak.muted, fontSize: 12.5),
                ),
              ),
            const SizedBox(height: 8),
            row('Invoiced, without VAT'.tr, fmtMoney(w.revenue)),
            row(
              bills == 1
                  ? 'Expenses, without VAT · 1 bill'.tr
                  : 'Expenses, without VAT · {0} bills'.trArgs([bills]),
              fmtMoney(w.cost == 0 ? 0 : -w.cost),
            ),
            const Divider(height: 14),
            row(
              'Profit on invoiced work'.tr,
              fmtMoney(w.profit),
              bold: true,
              color: tone(w.profit),
              hint: w.costsMayBeMissing
                  ? 'Above the expected profit: some costs of the invoiced '
                            'work may not be recorded yet'
                        .tr
                  : null,
            ),
            const SizedBox(height: 6),
            row(
              'Received'.tr,
              fmtMoney(w.received + w.held),
              hint: w.held.abs() >= .005
                  ? (w.kind == WorkKind.general
                            ? 'VAT included · {0} on account, not yet set '
                                  'against an invoice'
                            : 'VAT included · {0} advance held, not yet set '
                                  'against an invoice')
                        .trArgs([fmtMoney(w.held)])
                  : 'VAT included'.tr,
            ),
            row(
              'Cash in hand'.tr,
              fmtMoney(w.cash),
              color: tone(w.cash),
              hint: w.unpaidBills > 0.005
                  ? 'Received less expenses paid · {0} of bills still to pay'
                        .trArgs([fmtMoney(w.unpaidBills)])
                  : 'Received less expenses paid'.tr,
            ),
            if (left != null)
              row(
                'Budgeted cost (BOQ)'.tr,
                fmtMoney(w.budgetCost),
                hint: left < -0.005
                    ? 'Over budget by {0}'.trArgs([fmtMoney(-left)])
                    : '{0} of the budget left'.trArgs([fmtMoney(left)]),
              ),
            if (w.expectedProfit case final e?)
              row(
                'Expected profit at completion'.tr,
                fmtMoney(e),
                color: tone(e),
                hint: 'If costs stay within the budget'.tr,
              ),
            if (unlinked.isNotEmpty && contracts.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                'These costs are not matched to a contract. Open one to '
                        'choose its contract, or link them all:'
                    .tr,
                style: TextStyle(color: ak.muted, fontSize: 12.5),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final q in contracts)
                    TextButton.icon(
                      onPressed: () => _linkAll(context, unlinked, q),
                      icon: const Icon(Icons.link, size: 18),
                      label: Text('Link all to {0}'.trArgs([q.number])),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // With one contract, a cost linked to nothing is its cost.
                if (w.kind != WorkKind.general || contracts.length != 1)
                  TextButton.icon(
                    onPressed: () => openExpenseForm(
                      context,
                      projectId: w.projectId,
                      work: w.workKey,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Expense'.tr),
                  ),
                if (w.invoices.isNotEmpty || w.expenses.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _open = !_open),
                    icon: Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    label: Text(
                      _open ? 'Hide details'.tr : 'Invoices and expenses'.tr,
                    ),
                  ),
              ],
            ),
            if (_open) ...[
              if (w.invoices.isNotEmpty) ...[
                _caption(context, 'INVOICES'.tr),
                for (final i in w.invoices)
                  _line(
                    context,
                    icon: Icons.receipt_long_outlined,
                    title: [i.number, fmtDate(i.date)].dots(),
                    subtitle: 'Received {0} of {1}'.trArgs([
                      fmtMoneyShort(repo.paidOn(i)),
                      fmtMoneyShort(i.total),
                    ]),
                    amount: fmtMoney(i.net),
                    onTap: () => openInvoiceForm(context, invoice: i),
                  ),
              ],
              if (w.expenses.isNotEmpty) ...[
                _caption(context, 'EXPENSES'.tr),
                for (final e in w.expenses)
                  _line(
                    context,
                    icon: expenseCategoryIcon(e.category),
                    title: [
                      if (e.number.isNotEmpty) e.number,
                      e.vendor.isNotEmpty
                          ? e.vendor
                          : e.title.isNotEmpty
                          ? e.title
                          : expenseCategoryLabel(e.category),
                    ].dots(),
                    subtitle: [
                      fmtDate(e.date),
                      if (!e.paid) 'Unpaid'.tr,
                    ].dots(),
                    amount: fmtMoney(-e.net),
                    onTap: () => openExpenseForm(context, expense: e),
                  ),
              ],
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _caption(BuildContext context, String s) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      s,
      style: TextStyle(
        fontSize: 11,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w800,
        color: AkColors.of(context).muted,
      ),
    ),
  );

  Widget _line(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AkColors.of(context).muted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AkColors.of(context).muted,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _linkAll(
    BuildContext context,
    List<Expense> list,
    Quotation q,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Link {0} costs to {1}?'.trArgs([list.length, q.number])),
        content: Text(
          'They will count in the profit of {0}. You can change any of them '
                  'later.'
              .trArgs([workTitle(q, appLang)]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Link'.tr),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<Repository>().linkExpenses(list, q.id);
    }
  }
}
