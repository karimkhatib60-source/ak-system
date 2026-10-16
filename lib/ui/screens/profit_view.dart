import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/profit.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

String _margin(double? m) => m == null ? '—' : '${m.round()}%';

/// A project's internal profit: income without VAT less expenses, the
/// budget, the expected result and the cash in hand. Owner only; none of
/// this is printed on client documents.
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
    final left = f.budgetLeft;
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
                    'PROFIT · INTERNAL'.tr,
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
            if (f.contractNet > 0.005) ...[
              const SizedBox(height: 10),
              row(
                'Contract, without VAT'.tr,
                fmtMoney(f.contractNet),
                hint: [
                  if (f.leftToInvoice > 0)
                    '{0} still to invoice'.trArgs([fmtMoney(f.leftToInvoice)])
                  else if (f.onContract > f.contractNet + 0.005)
                    '{0} invoiced above the contract'.trArgs([
                      fmtMoney(f.onContract - f.contractNet),
                    ])
                  else
                    'Fully invoiced'.tr,
                  if (f.extrasNet > 0.005)
                    '{0} extra work invoiced'.trArgs([fmtMoney(f.extrasNet)]),
                ].join(' · '),
              ),
              if (left != null)
                row(
                  'Budgeted cost (BOQ)'.tr,
                  fmtMoney(f.budgetCost),
                  hint: left < -0.005
                      ? 'Over budget by {0}'.trArgs([fmtMoney(-left)])
                      : '{0} of the budget left'.trArgs([fmtMoney(left)]),
                ),
              if (f.expectedProfit case final e?)
                row(
                  'Expected profit at completion'.tr,
                  fmtMoney(e),
                  color: tone(e),
                  hint: 'If costs stay within the budget'.tr,
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'No cost budget on this contract, so the final profit '
                            'is not forecast.'
                        .tr,
                    style: TextStyle(color: ak.muted, fontSize: 12),
                  ),
                ),
            ],
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
