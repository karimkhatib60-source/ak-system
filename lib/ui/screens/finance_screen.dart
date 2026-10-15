import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/project_statement.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../pdf_docs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'money_doc_form.dart';

enum _Tab { quotations, invoices, expenses }

enum _Period { month, year, all }

/// Company money: what was quoted, invoiced, received and spent, with the
/// lists behind each figure. Owner only.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  _Tab _tab = _Tab.invoices;
  _Period _period = _Period.year;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final now = repo.now();
    final since = switch (_period) {
      _Period.month => DateTime(now.year, now.month),
      _Period.year => DateTime(now.year),
      _Period.all => null,
    };
    final m = repo.money(since: since);
    bool inRange(DateTime d) => since == null || !d.isBefore(since);

    final list = switch (_tab) {
      _Tab.quotations => [
        for (final q in repo.quotations)
          if (inRange(q.date)) QuotationTile(q, showProject: true),
      ],
      _Tab.invoices => [
        for (final i in repo.invoices)
          if (inRange(i.date)) InvoiceTile(i, showProject: true),
      ],
      _Tab.expenses => [
        for (final e in repo.expenses)
          if (inRange(e.date)) ExpenseTile(e, showProject: true),
      ],
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'finance-add',
        onPressed: () => switch (_tab) {
          _Tab.quotations => openQuotationForm(context),
          _Tab.invoices => openInvoiceForm(context),
          _Tab.expenses => openExpenseForm(context),
        },
        icon: const Icon(Icons.add),
        label: Text(switch (_tab) {
          _Tab.quotations => 'Quotation',
          _Tab.invoices => 'Invoice',
          _Tab.expenses => 'Expense',
        }),
      ),
      body: Readable(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: SegmentedButton<_Period>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Period.month,
                    label: Text('This month'),
                  ),
                  ButtonSegment(value: _Period.year, label: Text('This year')),
                  ButtonSegment(value: _Period.all, label: Text('All time')),
                ],
                selected: {_period},
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
            ),
            MoneyPanel(m),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: SegmentedButton<_Tab>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Tab.quotations,
                    label: Text('Quotes ${repo.quotations.length}'),
                  ),
                  ButtonSegment(
                    value: _Tab.invoices,
                    label: Text('Invoices ${repo.invoices.length}'),
                  ),
                  ButtonSegment(
                    value: _Tab.expenses,
                    label: Text('Expenses ${repo.expenses.length}'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: switch (_tab) {
                    _Tab.quotations => Icons.request_quote_outlined,
                    _Tab.invoices => Icons.receipt_long_outlined,
                    _Tab.expenses => Icons.receipt_outlined,
                  },
                  title: switch (_tab) {
                    _Tab.quotations => 'No quotations in this period',
                    _Tab.invoices => 'No invoices in this period',
                    _Tab.expenses => 'No expenses in this period',
                  },
                ),
              )
            else
              for (var i = 0; i < list.length; i++)
                GroupedRow(index: i, count: list.length, child: list[i]),
          ],
        ),
      ),
    );
  }
}

/// Six key figures in a grid.
class MoneyPanel extends StatelessWidget {
  const MoneyPanel(this.m, {super.key, this.showQuoted = true});

  final MoneySummary m;
  final bool showQuoted;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final tiles = [
      if (showQuoted) ('Agreed fees', m.quoted, Icons.handshake_outlined, null),
      ('Invoiced', m.invoiced, Icons.receipt_long_outlined, null),
      ('Received', m.received, Icons.savings_outlined, ak.good),
      (
        'Outstanding',
        m.outstanding,
        Icons.hourglass_bottom,
        m.overdue > 0 ? ak.bad : null,
      ),
      ('Expenses', m.expenses, Icons.shopping_bag_outlined, null),
      (
        'Profit (received − expenses)',
        m.profit,
        Icons.trending_up,
        m.profit < 0 ? ak.bad : ak.good,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: LayoutBuilder(
        builder: (context, box) {
          final cols = box.maxWidth > 700 ? 3 : 2;
          final w = (box.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in tiles)
                SizedBox(
                  width: w,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(t.$3, size: 16, color: ak.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  t.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ak.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              fmtMoneyShort(t.$2),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: t.$4,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class QuotationTile extends StatelessWidget {
  const QuotationTile(this.q, {super.key, this.showProject = false});

  final Quotation q;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final client = repo.client(q.clientId)?.name;
    final project = repo.project(q.projectId)?.name;
    return ListTile(
      leading: const Icon(Icons.request_quote_outlined),
      title: Text(
        q.title.isEmpty ? q.number : q.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          q.number,
          ?client,
          if (showProject && project != null) project,
          fmtDate(q.date),
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtMoneyShort(q.total),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Pill(
            quotationStatusLabel(q.status),
            color: quotationStatusColor(q.status),
          ),
        ],
      ),
      onTap: () => openQuotationForm(context, quotation: q),
    );
  }
}

class InvoiceTile extends StatelessWidget {
  const InvoiceTile(this.i, {super.key, this.showProject = false});

  final Invoice i;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final client = repo.client(i.clientId)?.name;
    final project = repo.project(i.projectId)?.name;
    final state = repo.paymentState(i);
    final balance = repo.balanceOf(i);
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(
        i.title.isEmpty ? i.number : i.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          i.number,
          ?client,
          if (showProject && project != null) project,
          if (state == PaymentState.partlyPaid || state == PaymentState.overdue)
            '${fmtMoneyShort(balance)} due',
          if (i.dueDate != null &&
              state != PaymentState.paid &&
              state != PaymentState.cancelled)
            dueLine(i.dueDate!, repo.now()),
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            fmtMoneyShort(i.total),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Pill(paymentStateLabel(state), color: paymentStateColor(state)),
        ],
      ),
      onTap: () => openInvoiceForm(context, invoice: i),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  const ExpenseTile(this.e, {super.key, this.showProject = false});

  final Expense e;
  final bool showProject;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final project = repo.project(e.projectId)?.name;
    return ListTile(
      leading: Icon(expenseCategoryIcon(e.category)),
      title: Text(
        e.vendor.isEmpty ? expenseCategoryLabel(e.category) : e.vendor,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          expenseCategoryLabel(e.category),
          if (showProject) project ?? 'Company',
          fmtDate(e.date),
        ].join(' · '),
      ),
      trailing: Text(
        fmtMoneyShort(e.amount),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onTap: () => openExpenseForm(context, expense: e),
    );
  }
}

/// The money tab inside a project.
class ProjectMoneyTab extends StatelessWidget {
  const ProjectMoneyTab({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final p = project;
    final quotes = repo.quotationsFor(p.id);
    final invoices = repo.invoicesFor(p.id);
    final expenses = repo.expensesFor(p.id);
    final m = repo.money(projectId: p.id);

    Widget header(String title, VoidCallback onAdd, String addLabel) =>
        SectionHeader(
          title,
          trailing: TextButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(addLabel),
          ),
        );

    List<Widget> rows(List<Widget> tiles, String empty) => tiles.isEmpty
        ? [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 4),
              child: Text(
                empty,
                style: TextStyle(color: AkColors.of(context).muted),
              ),
            ),
          ]
        : [
            for (var i = 0; i < tiles.length; i++)
              GroupedRow(index: i, count: tiles.length, child: tiles[i]),
          ];

    return Readable(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          MoneyPanel(m),
          if (p.clientId != null && repo.client(p.clientId) != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FilledButton.tonalIcon(
                onPressed: () => shareProjectStatementPdf(
                  repo,
                  buildProjectStatement(repo, p.id),
                ),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Project statement (by phase, trade, item)'),
              ),
            ),
          if (m.quoted > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _Progress(
                label: 'Invoiced of agreed fees',
                value: m.invoiced / m.quoted,
              ),
            ),
          if (m.invoiced > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _Progress(
                label: 'Collected of invoiced',
                value: m.received / m.invoiced,
              ),
            ),
          header(
            'Quotations',
            () => openQuotationForm(context, projectId: p.id),
            'Quotation',
          ),
          ...rows([
            for (final q in quotes) QuotationTile(q),
          ], 'No quotation yet.'),
          header(
            'Invoices',
            () => openInvoiceForm(context, projectId: p.id),
            'Invoice',
          ),
          ...rows([
            for (final i in invoices) InvoiceTile(i),
          ], 'No invoice yet.'),
          header(
            'Expenses',
            () => openExpenseForm(context, projectId: p.id),
            'Expense',
          ),
          ...rows([
            for (final e in expenses) ExpenseTile(e),
          ], 'No expenses yet.'),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: v, minHeight: 7),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Expense form --

Future<void> openExpenseForm(
  BuildContext context, {
  Expense? expense,
  String? projectId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => ExpenseForm(expense: expense, projectId: projectId),
  ),
);

class ExpenseForm extends StatefulWidget {
  const ExpenseForm({super.key, this.expense, this.projectId});

  final Expense? expense;
  final String? projectId;

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _vendor;
  late final TextEditingController _notes;
  String? _projectId;
  ExpenseCategory _category = ExpenseCategory.other;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    final repo = context.read<Repository>();
    _amount = TextEditingController(
      text: e == null ? '' : e.amount.toStringAsFixed(2),
    );
    _vendor = TextEditingController(text: e?.vendor ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    _projectId = e?.projectId ?? widget.projectId;
    _category =
        e?.category ??
        (_projectId == null
            ? ExpenseCategory.rent
            : ExpenseCategory.subcontractor);
    _date = e?.date ?? repo.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _vendor.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final e = widget.expense;
    final now = repo.now();
    await repo.saveExpense(
      Expense(
        id: e?.id ?? repo.newId(),
        createdAt: e?.createdAt ?? now,
        updatedAt: now,
        projectId: _projectId,
        date: _date,
        category: _category,
        amount: double.parse(_amount.text.replaceAll(',', '').trim()),
        vendor: _vendor.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'New expense' : 'Expense'),
        actions: [
          if (widget.expense != null)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmDelete(context, 'this expense')) return;
                await repo.deleteExpense(widget.expense!);
                if (context.mounted) Navigator.pop(context);
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: Readable(
          maxWidth: 640,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amount,
                      autofocus: widget.expense == null,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: '\$ ',
                      ),
                      validator: (v) =>
                          double.tryParse(
                                (v ?? '').replaceAll(',', '').trim(),
                              ) ==
                              null
                          ? 'Enter the amount'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Date',
                      value: _date,
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ),
                ],
              ),
              gap,
              DropdownButtonFormField<String?>(
                initialValue: repo.project(_projectId) == null
                    ? null
                    : _projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'For'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Company (overheads)'),
                  ),
                  for (final p in repo.projects)
                    DropdownMenuItem(
                      value: p.id,
                      child: Text('${p.code} · ${p.name}'),
                    ),
                ],
                onChanged: (v) => setState(() => _projectId = v),
              ),
              gap,
              DropdownButtonFormField<ExpenseCategory>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in ExpenseCategory.values)
                    DropdownMenuItem(
                      value: c,
                      child: Row(
                        children: [
                          Icon(expenseCategoryIcon(c), size: 18),
                          const SizedBox(width: 10),
                          Text(expenseCategoryLabel(c)),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              gap,
              TextFormField(
                controller: _vendor,
                decoration: const InputDecoration(
                  labelText: 'Paid to',
                  hintText: 'Supplier, subcontractor or person',
                ),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
