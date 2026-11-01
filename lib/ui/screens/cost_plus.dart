import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../theme.dart';

/// Where a line comes from, in the fixed pattern nobody types:
/// supplier · ref. · date.
String _source(Expense e) => [
  e.vendor.trim(),
  if (e.reference.trim().isNotEmpty) 'Ref. {0}'.tdArgs([e.reference.trim()]),
  fmtDocDate(e.date),
].where((s) => s.isNotEmpty).join(' · ');

/// The lines billing one supplier bill on a cost-plus invoice, taken from
/// the bill as entered under Expenses: each of its items with quantity,
/// unit and rate, or one line for the whole bill when only its total was
/// entered. Rates are before the supplier's VAT (AK gets that VAT back),
/// and the cost-plus fee is added on top. All lines sit under the bill's
/// category.
List<LineItem> costPlusLinesOf(Expense e) {
  final section = expenseCategoryLabel(e.category, AppLang.en);
  final from = _source(e);
  if (e.items.isEmpty) {
    return [
      LineItem(
        expenseId: e.id,
        section: section,
        description: [
          if (e.title.trim().isNotEmpty) e.title.trim(),
          from,
        ].where((s) => s.isNotEmpty).join(' · '),
        quantity: 1,
        unit: 'bill'.td,
        rate: e.net,
      ),
    ];
  }
  return [
    for (final i in e.items)
      LineItem(
        expenseId: e.id,
        section: section,
        description: [
          i.description.trim(),
          from,
        ].where((s) => s.isNotEmpty).join(' · '),
        quantity: i.quantity,
        unit: i.unit,
        rate: i.rate,
      ),
  ];
}

/// Lines for [bills], by category in the usual order, oldest first in each.
List<LineItem> costPlusLines(Iterable<Expense> bills) {
  final sorted = bills.toList()
    ..sort((a, b) {
      final c = a.category.index.compareTo(b.category.index);
      return c != 0 ? c : a.date.compareTo(b.date);
    });
  return [for (final e in sorted) ...costPlusLinesOf(e)];
}

/// [lines] with every supplier bill's lines taken again from the bill as
/// it is now, so a correction made under Expenses reaches a draft invoice.
/// A bill deleted since is dropped; other lines stay as they are.
List<LineItem> refreshCostPlus(
  List<LineItem> lines,
  Map<String, Expense> bills,
) {
  final done = <String>{};
  return [
    for (final l in lines)
      if (l.expenseId == null)
        l
      else if (done.add(l.expenseId!) && bills[l.expenseId] != null)
        ...costPlusLinesOf(bills[l.expenseId]!),
  ];
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
                        'Each bill comes in with all its items at cost '
                                'before VAT, under its category, and cannot '
                                'be edited on the invoice. The cost-plus fee '
                                'is added on top.'
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
