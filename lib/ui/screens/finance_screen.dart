import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/profit.dart';
import '../../data/project_statement.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../pdf_docs.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'expenses.dart';
import 'money_doc_form.dart';
import 'profit_view.dart';
import 'receipts.dart';

enum _Tab { quotations, invoices, receipts, expenses, profit }

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
      _Tab.receipts => [
        for (final p in repo.receipts())
          if (inRange(p.date)) ReceiptTile(p, showProject: true),
      ],
      _Tab.expenses => [
        for (final e in repo.expenses)
          if (inRange(e.date)) ExpenseTile(e, showProject: true),
      ],
      _Tab.profit => profitTiles(context, since: since),
    };

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'finance-add',
        onPressed: () => switch (_tab) {
          _Tab.quotations => openQuotationForm(context),
          _Tab.invoices => openInvoiceForm(context),
          _Tab.receipts => openReceiptForm(context),
          _Tab.expenses || _Tab.profit => openExpenseForm(context),
        },
        icon: const Icon(Icons.add),
        label: Text(switch (_tab) {
          _Tab.quotations => 'Quotation',
          _Tab.invoices => 'Invoice',
          _Tab.receipts => 'Receipt',
          _Tab.expenses || _Tab.profit => 'Expense',
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                    value: _Tab.receipts,
                    label: Text('Receipts ${repo.payments.length}'),
                  ),
                  ButtonSegment(
                    value: _Tab.expenses,
                    label: Text('Expenses ${repo.expenses.length}'),
                  ),
                  const ButtonSegment(
                    value: _Tab.profit,
                    icon: Icon(Icons.lock_outline, size: 16),
                    label: Text('Profit'),
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
                    _Tab.receipts => Icons.payments_outlined,
                    _Tab.expenses => Icons.receipt_outlined,
                    _Tab.profit => Icons.trending_up,
                  },
                  title: switch (_tab) {
                    _Tab.quotations => 'No quotations in this period',
                    _Tab.invoices => 'No invoices in this period',
                    _Tab.receipts => 'No receipts in this period',
                    _Tab.expenses => 'No expenses in this period',
                    _Tab.profit => 'No income or expenses in this period',
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
  const MoneyPanel(
    this.m, {
    super.key,
    this.showQuoted = true,
    this.showProfit = true,
  });

  final MoneySummary m;
  final bool showQuoted;

  /// Expenses and profit; a project shows them in its own profit card.
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final tiles = [
      if (showQuoted)
        ('Approved quotes', m.quoted, Icons.handshake_outlined, null, null),
      ('Invoiced', m.invoiced, Icons.receipt_long_outlined, null, null),
      ('Received', m.received, Icons.savings_outlined, ak.good, null),
      (
        'Outstanding',
        m.outstanding,
        Icons.hourglass_bottom,
        m.overdue > 0 ? ak.bad : null,
        m.advances > 0.005
            ? 'Advances held ${fmtMoneyShort(m.advances)}'
            : null,
      ),
      if (showProfit) ...[
        (
          'Expenses',
          m.expenses,
          Icons.shopping_bag_outlined,
          null,
          m.unpaidBills > 0.005
              ? 'Unpaid bills ${fmtMoneyShort(m.unpaidBills)}'
              : 'Without VAT',
        ),
        (
          'Profit',
          m.profit,
          Icons.trending_up,
          m.profit < 0 ? ak.bad : ak.good,
          m.margin == null
              ? 'Invoiced without VAT, less expenses'
              : '${m.margin!.round()}% margin · without VAT',
        ),
      ],
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
                          if (t.$5 != null)
                            Text(
                              t.$5!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: ak.muted),
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

/// The money tab inside a project, in two parts: the client's account
/// (quotations, invoices, receipts and what is due, as the client sees
/// them) and AK's internal side (expenses and profit), never shown to
/// clients.
class ProjectMoneyTab extends StatefulWidget {
  const ProjectMoneyTab({super.key, required this.project});

  final Project project;

  @override
  State<ProjectMoneyTab> createState() => _ProjectMoneyTabState();
}

class _ProjectMoneyTabState extends State<ProjectMoneyTab> {
  var _internal = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final p = widget.project;
    final quotes = repo.quotationsFor(p.id);
    final invoices = repo.invoicesFor(p.id);
    final expenses = repo.expensesFor(p.id);
    final receipts = repo.receipts(projectId: p.id);
    final accepted = quotes
        .where(
          (q) =>
              q.status == QuotationStatus.accepted && q.paymentTerms.isNotEmpty,
        )
        .toList();
    final m = repo.money(projectId: p.id);
    final client = repo.client(p.clientId);
    final ak = AkColors.of(context);

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
              child: Text(empty, style: TextStyle(color: ak.muted)),
            ),
          ]
        : [
            for (var i = 0; i < tiles.length; i++)
              GroupedRow(index: i, count: tiles.length, child: tiles[i]),
          ];

    final clientPart = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ClientAccountCard(
          m: m,
          clientName: client?.name,
          nextStep: projectNextStep(repo, quotes, invoices, m),
        ),
      ),
      if (client != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => shareProjectStatementPdf(
                  repo,
                  buildProjectStatement(repo, p.id),
                ),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Project statement'),
              ),
              OutlinedButton.icon(
                onPressed: () => openReceiptForm(
                  context,
                  projectId: p.id,
                  clientId: p.clientId,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Receipt'),
              ),
            ],
          ),
        ),
      header(
        'Quotations',
        () => openQuotationForm(context, projectId: p.id),
        'Quotation',
      ),
      ...rows([for (final q in quotes) QuotationTile(q)], 'No quotation yet.'),
      if (accepted.isNotEmpty) ...[
        const SectionHeader('Payment schedule'),
        ...rows([
          for (final q in accepted)
            for (var k = 0; k < q.paymentTerms.length; k++)
              TermStatusTile(
                quotation: q,
                index: k,
                showQuotation: accepted.length > 1,
              ),
        ], ''),
      ],
      header(
        'Invoices',
        () => openInvoiceForm(context, projectId: p.id),
        'Invoice',
      ),
      ...rows([for (final i in invoices) InvoiceTile(i)], 'No invoice yet.'),
      header(
        'Receipts',
        () => openReceiptForm(context, projectId: p.id, clientId: p.clientId),
        'Receipt',
      ),
      ...rows([
        for (final r in receipts) ReceiptTile(r, projectId: p.id),
      ], 'No money received yet.'),
    ];

    final internalPart = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 16, 0),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: ak.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'AK only. Expenses and profit never appear on client '
                'documents.',
                style: TextStyle(color: ak.muted, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: ProfitCard(profitOf(repo, projectId: p.id)),
      ),
      if (expenses.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CostBreakdown(expenses),
        ),
      header(
        'Expenses',
        () => openExpenseForm(context, projectId: p.id),
        'Expense',
      ),
      ...rows(
        [for (final e in expenses) ExpenseTile(e)],
        'No expenses yet. Add each supplier bill or cost you pay for this '
        'project.',
      ),
    ];

    return Readable(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.handshake_outlined, size: 18),
                    label: Text('Client account'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.lock_outline, size: 18),
                    label: Text('AK internal'),
                  ),
                ],
                selected: {_internal},
                onSelectionChanged: (v) => setState(() => _internal = v.first),
              ),
            ),
          ),
          ...(_internal ? internalPart : clientPart),
        ],
      ),
    );
  }
}

/// What to do next on a project's account, in one sentence.
String projectNextStep(
  Repository repo,
  List<Quotation> quotes,
  List<Invoice> invoices,
  MoneySummary m,
) {
  final approved = quotes.where((q) => q.status == QuotationStatus.accepted);
  final issued = invoices.where((i) => i.status == InvoiceStatus.sent);
  final drafts = invoices.where((i) => i.status == InvoiceStatus.draft);
  if (quotes.isEmpty && invoices.isEmpty) {
    return 'Start with a quotation. When the client approves it, mark it '
        'Approved and invoice from it.';
  }
  if (approved.isEmpty && issued.isEmpty) {
    final open = quotes.where((q) => q.status != QuotationStatus.rejected);
    return open.isEmpty
        ? 'No approved quotation. Prepare a new one for the client.'
        : 'Waiting for the client to approve ${open.first.number}. Mark it '
              'Approved when they agree, then invoice from it.';
  }
  final due = [
    for (final i in issued)
      if (repo.balanceOf(i) > 0.005) i,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (due.isNotEmpty) {
    final names = due.length <= 3
        ? due.map((i) => i.number).join(', ')
        : '${due.length} invoices';
    final allLate = m.overdue >= m.outstanding - 0.005;
    // Advances only stay unused while an invoice is due when that invoice
    // bills extra work.
    final held = m.advances > 0.005
        ? ' The ${fmtMoney(m.advances)} received in advance is kept for '
              'the contract invoices.'
        : '';
    return '${fmtMoney(m.outstanding)} is ${allLate ? 'overdue' : 'due'} on '
        '$names'
        '${m.overdue > 0.005 && !allLate ? ', ${fmtMoney(m.overdue)} of it overdue' : ''}. '
        'Record a receipt when the client pays.$held';
  }
  if (drafts.isNotEmpty) {
    return '${drafts.first.number} is still a draft. Send it to issue it; '
        'money already received is set off automatically.';
  }
  if (approved.isNotEmpty && issued.isEmpty) {
    return 'Raise the first invoice from ${approved.first.number}'
        '${m.advances > 0.005 ? '; the ${fmtMoney(m.advances)} received in advance is deducted from it' : ''}.';
  }
  if (m.leftToInvoice > 0.005) {
    return 'Nothing due now. ${fmtMoney(m.leftToInvoice)} of the contract is '
        'left to invoice'
        '${m.advances > 0.005 ? ', and the ${fmtMoney(m.advances)} received in advance is set off on the next invoices' : ''}.';
  }
  if (issued.isNotEmpty) {
    return m.advances > 0.005
        ? 'Fully invoiced and paid. ${fmtMoney(m.advances)} credit is held '
              'for the client.'
        : 'Fully invoiced and paid.';
  }
  return 'Raise the first invoice from the approved quotation.';
}

/// A project's account with the client, as the client's own documents
/// show it (VAT included): the contract, what was invoiced and received,
/// and what is still due.
class ClientAccountCard extends StatelessWidget {
  const ClientAccountCard({
    super.key,
    required this.m,
    this.clientName,
    this.nextStep,
  });

  final MoneySummary m;
  final String? clientName;
  final String? nextStep;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    String pct(double a, double b) => b <= 0 ? '' : '${(a / b * 100).round()}%';
    Widget row(
      String label,
      double v, {
      String? hint,
      bool bold = false,
      Color? color,
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
                if (hint != null && hint.isNotEmpty)
                  Text(hint, style: TextStyle(color: ak.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(
            fmtMoney(v),
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
    final due = m.outstanding;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                'CLIENT ACCOUNT',
                if (clientName != null) clientName!.toUpperCase(),
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
                color: ak.muted,
              ),
            ),
            const SizedBox(height: 8),
            row(
              'Contract value',
              m.quoted,
              hint: m.quoted > 0
                  ? 'Approved quotations'
                  : 'No approved quotation yet',
            ),
            row(
              'Invoiced',
              m.invoiced,
              hint: [
                if (m.quoted > 0 && m.onContract > 0.005)
                  '${pct(m.onContract, m.quoted)} of the contract',
                if (m.extras > 0.005) '${fmtMoney(m.extras)} extra work',
              ].join(' · '),
            ),
            row(
              'Received',
              m.received,
              color: m.received > 0 ? ak.good : null,
              hint: m.invoiced > 0 && m.received > 0
                  ? '${pct(m.received, m.invoiced)} of invoiced'
                  : null,
            ),
            const Divider(height: 16),
            if (due > 0.005 || m.advances <= 0.005)
              row(
                'Due now',
                due,
                bold: true,
                color: m.overdue > 0.005
                    ? ak.bad
                    : due > 0.005
                    ? null
                    : ak.good,
                hint: m.overdue > 0.005
                    ? '${fmtMoney(m.overdue)} overdue'
                    : due > 0.005
                    ? 'On issued invoices, after advances'
                    : 'Nothing to collect on issued invoices',
              ),
            if (m.advances > 0.005)
              row(
                'Credit held',
                m.advances,
                bold: due <= 0.005,
                color: ak.info,
                hint: due > 0.005
                    ? 'Received in advance; kept for the contract invoices'
                    : 'Received in advance; set off on the next invoices',
              ),
            if (m.quoted > 0 || m.invoiced > 0) ...[
              const SizedBox(height: 6),
              if (m.quoted > 0)
                row(
                  'Left to invoice',
                  m.leftToInvoice,
                  hint: 'Contract less what was invoiced on it',
                ),
              row(
                'Still to receive',
                m.leftToReceive,
                hint: m.quoted <= 0.005
                    ? 'Invoiced less received'
                    : m.extras > 0.005
                    ? 'Contract and extra work, less received'
                    : m.onContract > m.quoted + 0.005
                    ? 'Invoiced less received (above the contract)'
                    : 'Contract less received',
              ),
            ],
            if (m.quoted > 0) ...[
              const SizedBox(height: 10),
              _Progress(
                label: 'Invoiced of the contract',
                value: m.onContract / m.quoted,
              ),
              const SizedBox(height: 8),
              if (m.extras > 0.005)
                _Progress(
                  label: 'Received of the contract and extra work',
                  value:
                      m.received /
                      ((m.onContract > m.quoted ? m.onContract : m.quoted) +
                          m.extras),
                )
              else
                _Progress(
                  label: 'Received of the contract',
                  value: m.received / m.quoted,
                ),
            ],
            if (nextStep != null && nextStep!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ak.accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_forward, size: 16, color: ak.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nextStep!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Amounts include VAT, as on the client\'s documents.',
              style: TextStyle(color: ak.muted, fontSize: 12),
            ),
          ],
        ),
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
