import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';

/// The line billing one supplier bill on a cost-plus invoice. Named by a
/// fixed pattern so nobody types a name: supplier · what · ref. · date,
/// under its expense category. The rate is the bill before the supplier's
/// VAT (AK gets that VAT back), and the cost-plus fee is added on top.
LineItem costPlusLine(Expense e) => LineItem(
  expenseId: e.id,
  section: expenseCategoryLabel(e.category, AppLang.en),
  description: [
    e.vendor.trim(),
    e.title.trim(),
    if (e.reference.trim().isNotEmpty) 'Ref. {0}'.tdArgs([e.reference.trim()]),
    fmtDocDate(e.date),
  ].where((s) => s.isNotEmpty).join(' · '),
  quantity: 1,
  unit: 'bill'.td,
  rate: e.net,
);

/// Lines for [bills], by category in the usual order, oldest first in each.
List<LineItem> costPlusLines(Iterable<Expense> bills) {
  final sorted = bills.toList()
    ..sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      return c != 0 ? c : a.date.compareTo(b.date);
    });
  return sorted.map(costPlusLine).toList();
}

/// The title of a cost-plus invoice: its number among the project's
/// cost-plus invoices and the dates of the bills it covers, e.g.
/// "Cost-plus bill 03 · 02 Oct 2026 to 28 Oct 2026".
String costPlusTitle(int n, Iterable<Expense> bills) {
  final dates = bills.map((e) => e.date).toList()..sort();
  final no = n.toString().padLeft(2, '0');
  if (dates.isEmpty) return 'Cost-plus bill {0}'.tdArgs([no]);
  final from = fmtDocDate(dates.first);
  final to = fmtDocDate(dates.last);
  return 'Cost-plus bill {0} · {1}'.tdArgs([
    no,
    from == to ? from : 'from {0} to {1}'.tdArgs([from, to]),
  ]);
}

/// Lets the owner tick the project's supplier bills to bill the client
/// for. Bills already on another invoice are shown but cannot be ticked;
/// [inForm] are the bills already on this invoice, left out.
Future<List<Expense>?> pickSupplierBills(
  BuildContext context, {
  required Repository repo,
  required String projectId,
  String? invoiceId,
  Set<String> inForm = const {},
}) {
  final billed = repo.billedExpenses(except: invoiceId);
  final bills =
      repo.expensesFor(projectId).where((e) => !inForm.contains(e.id)).toList()
        ..sort((a, b) {
          final c = a.category.index.compareTo(b.category.index);
          return c != 0 ? c : a.date.compareTo(b.date);
        });
  final picked = <String>{};
  return showDialog<List<Expense>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final ak = AkColors.of(ctx);
        final free = [
          for (final e in bills)
            if (!billed.containsKey(e.id)) e,
        ];
        final total = bills
            .where((e) => picked.contains(e.id))
            .fold(0.0, (s, e) => s + e.net);
        final rows = <Widget>[];
        ExpenseCategory? last;
        for (final e in bills) {
          if (e.category != last) {
            last = e.category;
            rows.add(
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(4, 14, 4, 4),
                child: Text(
                  expenseCategoryLabel(e.category).toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: ak.muted,
                    letterSpacing: .4,
                  ),
                ),
              ),
            );
          }
          final on = billed[e.id];
          rows.add(
            CheckboxListTile(
              dense: true,
              contentPadding: const EdgeInsetsDirectional.only(start: 4),
              controlAffinity: ListTileControlAffinity.leading,
              value: on != null || picked.contains(e.id),
              onChanged: on != null
                  ? null
                  : (v) =>
                        set(() => v! ? picked.add(e.id) : picked.remove(e.id)),
              title: Text(
                [e.vendor, e.title]
                    .where((s) => s.trim().isNotEmpty)
                    .join(' · ')
                    .ifEmpty(expenseCategoryLabel(e.category)),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  fmtDate(e.date),
                  if (e.reference.isNotEmpty) 'Ref. {0}'.trArgs([e.reference]),
                  if (on != null) 'Billed on {0}'.trArgs([on.number]),
                  if (on == null && !e.paid) 'Not paid yet'.tr,
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: ak.muted),
              ),
              secondary: Text(
                fmtMoney(e.net),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          );
        }
        return AlertDialog(
          title: Text('Bill supplier invoices'.tr),
          content: SizedBox(
            width: 560,
            child: bills.isEmpty
                ? Text(
                    'This project has no supplier bills yet. Add them under '
                            'Expenses first.'
                        .tr,
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Each bill becomes one line at its cost before VAT, '
                                'under its category. The cost-plus fee is '
                                'added on top.'
                            .tr,
                        style: TextStyle(fontSize: 13, color: ak.muted),
                      ),
                      Flexible(
                        child: ListView(shrinkWrap: true, children: rows),
                      ),
                      const Divider(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: free.isEmpty
                                ? null
                                : () => set(() {
                                    if (picked.length == free.length) {
                                      picked.clear();
                                    } else {
                                      picked.addAll(free.map((e) => e.id));
                                    }
                                  }),
                            child: Text(
                              picked.length == free.length && free.isNotEmpty
                                  ? 'Clear'.tr
                                  : 'Select all'.tr,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Cost {0}'.trArgs([fmtMoney(total)]),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'.tr),
            ),
            FilledButton(
              onPressed: picked.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, [
                      for (final e in bills)
                        if (picked.contains(e.id)) e,
                    ]),
              child: Text(
                picked.length == 1
                    ? 'Add 1 bill'.tr
                    : 'Add {0} bills'.trArgs([picked.length]),
              ),
            ),
          ],
        );
      },
    ),
  );
}

extension on String {
  String ifEmpty(String other) => trim().isEmpty ? other : this;
}
