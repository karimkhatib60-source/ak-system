import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      if (l.expenseId == null || l.fromInvoice)
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

/// The categories an invoice bills, in order: the sections of its lines
/// (for a cost-plus invoice, the expense categories of its bills).
List<String> invoiceCategories(Invoice i) => {
  for (final l in i.items)
    if (l.section.trim().isNotEmpty) l.section.trim(),
}.toList();

/// What one category was billed at on the project's issued cost-plus
/// invoices: the supplier cost and AK's fee on it.
class CategoryBilled {
  CategoryBilled(this.category);
  final String category;
  double cost = 0;
  double fee = 0;
}

/// Supplier bills billed to the client on the project's issued invoices,
/// by category, with the fee each invoice added on them.
List<CategoryBilled> costPlusBilled(Repository repo, String projectId) {
  final out = <String, CategoryBilled>{};
  for (final i in repo.invoicesFor(projectId)) {
    if (i.status != InvoiceStatus.sent) continue;
    for (final l in i.items) {
      if (l.expenseId == null) continue;
      final c = out.putIfAbsent(l.section, () => CategoryBilled(l.section));
      c.cost += l.amount;
      c.fee += l.amount * i.markupRate / 100;
    }
  }
  return out.values.toList();
}

/// The cost-plus fee set once for the whole project, shown on top of the
/// project's money tab, with what has been billed at cost so far by
/// category and the fee earned on it. Internal: the client never sees it.
class ProjectFeeCard extends StatelessWidget {
  const ProjectFeeCard({super.key, required this.project});

  final Project project;

  Future<void> _edit(BuildContext context) async {
    final repo = context.read<Repository>();
    final f = project.markupRate;
    final ctrl = TextEditingController(
      text: f == null || f == 0
          ? ''
          : f == f.roundToDouble()
          ? f.toStringAsFixed(0)
          : '$f',
    );
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cost-plus fee for this project'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Every cost-plus invoice of this project takes '
                      'this fee by itself. Invoices already sent keep theirs.'
                  .tr,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Cost-plus fee'.tr,
                suffixText: '%',
                hintText: 'e.g. 15'.tr,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(ctrl.text.replaceAll('%', '').trim()) ?? 0,
            ),
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    if (v == null) return;
    await repo.saveProject(
      project.copyWith(markupRate: v, updatedAt: repo.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final p = repo.project(project.id) ?? project;
    final rate = p.markupRate ?? 0;
    final billed = costPlusBilled(repo, p.id);
    final cost = billed.fold(0.0, (s, c) => s + c.cost);
    final fee = billed.fold(0.0, (s, c) => s + c.fee);
    final pct = rate == rate.roundToDouble()
        ? rate.toStringAsFixed(0)
        : '$rate';
    Widget row(String label, double c, double f, {bool bold = false}) {
      final style = TextStyle(
        fontWeight: bold ? FontWeight.w800 : null,
        fontSize: 13,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            SizedBox(
              width: 92,
              child: Text(fmtMoney(c), textAlign: TextAlign.end, style: style),
            ),
            SizedBox(
              width: 84,
              child: Text(fmtMoney(f), textAlign: TextAlign.end, style: style),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.percent, size: 18, color: ak.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rate == 0
                        ? 'No cost-plus fee set for this project'.tr
                        : 'Cost-plus fee {0}% on the whole project'.trArgs([
                            pct,
                          ]),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _edit(context),
                  child: Text(rate == 0 ? 'Set'.tr : 'Change'.tr),
                ),
              ],
            ),
            if (billed.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Billed on sent invoices, by category'.tr,
                            style: TextStyle(fontSize: 12, color: ak.muted),
                          ),
                        ),
                        SizedBox(
                          width: 92,
                          child: Text(
                            'Cost'.tr,
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, color: ak.muted),
                          ),
                        ),
                        SizedBox(
                          width: 84,
                          child: Text(
                            'Fee'.tr,
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, color: ak.muted),
                          ),
                        ),
                      ],
                    ),
                    for (final c in billed)
                      row(
                        c.category.isEmpty ? 'Other'.tr : c.category.tr,
                        c.cost,
                        c.fee,
                      ),
                    const Divider(height: 12),
                    row('Total'.tr, cost, fee, bold: true),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The expense category a line's section names, when it names one.
ExpenseCategory? categoryOfSection(String section) {
  final s = section.trim();
  for (final c in ExpenseCategory.values) {
    if (expenseCategoryLabel(c, AppLang.en) == s ||
        expenseCategoryLabel(c, AppLang.ar) == s) {
      return c;
    }
  }
  return null;
}

/// Records the items typed on a client invoice as AK's expenses (client
/// invoice first): one expense per line marked [LineItem.fromInvoice],
/// kept equal to the line, and removed when the line is. What is filled in
/// on the expense itself (supplier, reference, VAT, paid, files, notes)
/// is kept. [before] is the invoice as it was saved before.
Future<void> syncInvoiceCosts(
  Repository repo,
  Invoice inv,
  Invoice? before,
) async {
  final keep = <String>{};
  for (final l in inv.items) {
    if (!l.fromInvoice || l.expenseId == null) continue;
    keep.add(l.expenseId!);
    final old = repo.expenses.where((e) => e.id == l.expenseId).firstOrNull;
    final cat = categoryOfSection(l.section);
    final items = [
      LineItem(
        description: l.description,
        quantity: l.quantity,
        unit: l.unit,
        rate: l.rate,
      ),
    ];
    final vat = old?.vatRate ?? 0;
    final now = repo.now();
    final e = Expense(
      id: l.expenseId!,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
      number: old?.number ?? repo.nextExpenseNumber(),
      projectId: inv.projectId,
      quotationId: inv.extra ? null : inv.quotationId,
      extra: inv.extra,
      date: inv.date,
      category: cat ?? ExpenseCategory.other,
      title: cat == null && l.section.trim().isNotEmpty
          ? '${l.section.trim()} · ${l.description}'
          : l.description,
      vendor: old?.vendor ?? '',
      reference: old?.reference ?? '',
      items: items,
      vatRate: vat,
      amount: Expense.totalOf(items, vat),
      paid: old?.paid ?? true,
      method: old?.method,
      notes: old?.notes ?? 'From invoice {0}'.trArgs([inv.number]),
    );
    final a = {...e.toMap()}..remove('updated_at');
    final b = old == null ? null : ({...old.toMap()}..remove('updated_at'));
    if (b == null || a.toString() != b.toString()) await repo.saveExpense(e);
  }
  for (final l in before?.items ?? const <LineItem>[]) {
    if (!l.fromInvoice || l.expenseId == null) continue;
    if (keep.contains(l.expenseId)) continue;
    final e = repo.expenses.where((x) => x.id == l.expenseId).firstOrNull;
    if (e != null) await repo.deleteExpense(e);
  }
}
