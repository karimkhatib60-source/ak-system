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
                    'PROFIT · INTERNAL',
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
                    '${_margin(f.margin)} margin',
                    color: f.profit < 0 ? AkPalette.bad : AkPalette.good,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            row('Invoiced, without VAT', fmtMoney(f.revenue)),
            row('Expenses', fmtMoney(f.expenses == 0 ? 0 : -f.expenses)),
            const Divider(height: 14),
            row(
              'Profit on invoiced work',
              fmtMoney(f.profit),
              bold: true,
              color: tone(f.profit),
              hint: f.costsMayBeMissing
                  ? 'Above the expected profit: some costs of the invoiced '
                        'work may not be recorded yet'
                  : null,
            ),
            if (f.contractNet > 0.005) ...[
              const SizedBox(height: 10),
              row(
                'Contract, without VAT',
                fmtMoney(f.contractNet),
                hint: f.leftToInvoice > 0
                    ? '${fmtMoney(f.leftToInvoice)} still to invoice'
                    : f.revenue > f.contractNet + 0.005
                    ? '${fmtMoney(f.revenue - f.contractNet)} invoiced above '
                          'the contract'
                    : 'Fully invoiced',
              ),
              if (left != null)
                row(
                  'Budgeted cost (BOQ)',
                  fmtMoney(f.budgetCost),
                  hint: left < -0.005
                      ? 'Over budget by ${fmtMoney(-left)}'
                      : '${fmtMoney(left)} of the budget left',
                ),
              if (f.expectedProfit case final e?)
                row(
                  'Expected profit at completion',
                  fmtMoney(e),
                  color: tone(e),
                  hint: 'If costs stay within the budget',
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'No cost budget on this contract, so the final profit '
                    'is not forecast.',
                    style: TextStyle(color: ak.muted, fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 10),
            row(
              'Cash in hand',
              fmtMoney(f.cash),
              color: tone(f.cash),
              hint: 'Received ${fmtMoney(f.received)} less expenses',
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (f.vat > 0.005)
                  'VAT of ${fmtMoney(f.vat)} on your invoices is owed to the '
                      'tax office, so it is not counted as income.',
                'Expenses and profit never appear on client documents.',
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
  String margin(Profit f) =>
      f.margin == null ? 'no income yet' : '${_margin(f.margin)} margin';
  return [
    for (final (p, f) in rows)
      ListTile(
        title: Text(
          '${p.code} · ${p.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Invoiced ${fmtMoneyShort(f.revenue)} without VAT · '
          'expenses ${fmtMoneyShort(f.expenses)}',
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
        title: const Text('Not on a project'),
        subtitle: Text(
          'Invoiced ${fmtMoneyShort(outside.revenue)} without VAT'
          '${outside.expenses > 0.005 ? ' · expenses ${fmtMoneyShort(outside.expenses)}' : ''}'
          ' · invoices with no project or of a deleted one',
        ),
        trailing: amount(outside.profit, margin(outside)),
      ),
    if (all.overheads > 0.005)
      ListTile(
        leading: const Icon(Icons.apartment_outlined),
        title: const Text('Company overheads'),
        subtitle: const Text('Expenses not booked on a project'),
        trailing: Text(
          fmtMoneyShort(-all.overheads),
          style: TextStyle(fontWeight: FontWeight.w800, color: ak.bad),
        ),
      ),
    if (rows.isNotEmpty || !outside.isEmpty || all.overheads > 0.005)
      ListTile(
        title: const Text(
          'Total profit',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Invoiced ${fmtMoneyShort(all.revenue)} without VAT · '
          'expenses ${fmtMoneyShort(all.expenses)}',
        ),
        trailing: amount(all.profit, margin(all)),
      ),
  ];
}
