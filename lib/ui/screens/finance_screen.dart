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
import 'export_screen.dart';
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
          _Tab.quotations => 'Quotation'.tr,
          _Tab.invoices => 'Invoice'.tr,
          _Tab.receipts => 'Receipt'.tr,
          _Tab.expenses || _Tab.profit => 'Expense'.tr,
        }),
      ),
      body: Readable(
        maxWidth: 1000,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<_Period>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: _Period.month,
                          label: Text('This month'.tr),
                        ),
                        ButtonSegment(
                          value: _Period.year,
                          label: Text('This year'.tr),
                        ),
                        ButtonSegment(
                          value: _Period.all,
                          label: Text('All time'.tr),
                        ),
                      ],
                      selected: {_period},
                      onSelectionChanged: (v) =>
                          setState(() => _period = v.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Export'.tr,
                    icon: const Icon(Icons.ios_share),
                    onPressed: () => openExportScreen(
                      context,
                      from: since,
                      internal: _tab == _Tab.expenses || _tab == _Tab.profit,
                    ),
                  ),
                ],
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
                    label: Text('Quotes {0}'.trArgs([repo.quotations.length])),
                  ),
                  ButtonSegment(
                    value: _Tab.invoices,
                    label: Text('Invoices {0}'.trArgs([repo.invoices.length])),
                  ),
                  ButtonSegment(
                    value: _Tab.receipts,
                    label: Text('Receipts {0}'.trArgs([repo.payments.length])),
                  ),
                  ButtonSegment(
                    value: _Tab.expenses,
                    label: Text('Expenses {0}'.trArgs([repo.expenses.length])),
                  ),
                  ButtonSegment(
                    value: _Tab.profit,
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: Text('Profit'.tr),
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
                    _Tab.quotations => 'No quotations in this period'.tr,
                    _Tab.invoices => 'No invoices in this period'.tr,
                    _Tab.receipts => 'No receipts in this period'.tr,
                    _Tab.expenses => 'No expenses in this period'.tr,
                    _Tab.profit => 'No income or expenses in this period'.tr,
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
        ('Approved quotes'.tr, m.quoted, Icons.handshake_outlined, null, null),
      ('Invoiced'.tr, m.invoiced, Icons.receipt_long_outlined, null, null),
      ('Received'.tr, m.received, Icons.savings_outlined, ak.good, null),
      (
        'Outstanding'.tr,
        m.outstanding,
        Icons.hourglass_bottom,
        m.overdue > 0 ? ak.bad : null,
        m.advances > 0.005
            ? 'Credit held {0}'.trArgs([fmtMoneyShort(m.advances)])
            : null,
      ),
      if (showProfit) ...[
        (
          'Expenses'.tr,
          m.expenses,
          Icons.shopping_bag_outlined,
          null,
          m.unpaidBills > 0.005
              ? 'Unpaid bills {0}'.trArgs([fmtMoneyShort(m.unpaidBills)])
              : 'Without VAT'.tr,
        ),
        (
          'Profit'.tr,
          m.profit,
          Icons.trending_up,
          m.profit < 0 ? ak.bad : ak.good,
          m.margin == null
              ? 'Invoiced without VAT, less expenses'.tr
              : '{0}% margin · without VAT'.trArgs([m.margin!.round()]),
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
                            alignment: AlignmentDirectional.centerStart,
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
        ].dots(),
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
            '{0} due'.trArgs([fmtMoneyShort(balance)]),
          if (i.dueDate != null &&
              state != PaymentState.paid &&
              state != PaymentState.cancelled)
            dueLine(i.dueDate!, repo.now()),
        ].dots(),
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
    final works = _internal ? profitByWork(repo, p.id) : const <WorkProfit>[];

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
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 16, 4),
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
                label: Text('Project statement'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () => openReceiptForm(
                  context,
                  projectId: p.id,
                  clientId: p.clientId,
                ),
                icon: const Icon(Icons.payments_outlined),
                label: Text('Receipt'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () => openExportScreen(context, projectId: p.id),
                icon: const Icon(Icons.ios_share),
                label: Text('Export'.tr),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => openExportScreen(context, projectId: p.id),
              icon: const Icon(Icons.ios_share),
              label: Text('Export'.tr),
            ),
          ),
        ),
      header(
        'Quotations'.tr,
        () => openQuotationForm(context, projectId: p.id),
        'Quotation'.tr,
      ),
      ...rows([
        for (final q in quotes) QuotationTile(q),
      ], 'No quotation yet.'.tr),
      if (accepted.isNotEmpty) ...[
        SectionHeader('Payment schedule'.tr),
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
        'Invoices'.tr,
        () => openInvoiceForm(context, projectId: p.id),
        'Invoice'.tr,
      ),
      ...rows([for (final i in invoices) InvoiceTile(i)], 'No invoice yet.'.tr),
      header(
        'Receipts'.tr,
        () => openReceiptForm(context, projectId: p.id, clientId: p.clientId),
        'Receipt'.tr,
      ),
      ...rows([
        for (final r in receipts) ReceiptTile(r, projectId: p.id),
      ], 'No money received yet.'.tr),
    ];

    final internalPart = <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 16, 0),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 15, color: ak.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'AK only. Expenses and profit never appear on client '
                        'documents.'
                    .tr,
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
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () =>
                openExportScreen(context, projectId: p.id, internal: true),
            icon: const Icon(Icons.ios_share, size: 18),
            label: Text('Export'.tr),
          ),
        ),
      ),
      if (works.isNotEmpty) ...[
        SectionHeader('By contract'.tr),
        for (final w in works)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: WorkCard(
              w,
              key: ValueKey('${w.kind.name}${w.contract?.id ?? ''}'),
            ),
          ),
      ],
      if (expenses.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: CostBreakdown(expenses),
        ),
      header(
        'Expenses'.tr,
        () => openExpenseForm(context, projectId: p.id),
        'Expense'.tr,
      ),
      ...rows(
        [for (final e in expenses) ExpenseTile(e, showWork: true)],
        'No expenses yet. Add each supplier bill or cost you pay for this '
                'project.'
            .tr,
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
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.handshake_outlined, size: 18),
                    label: Text('Client account'.tr),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: Text('AK internal'.tr),
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
            'Approved and invoice from it.'
        .tr;
  }
  if (approved.isEmpty && issued.isEmpty) {
    final open = quotes.where((q) => q.status != QuotationStatus.rejected);
    return open.isEmpty
        ? 'No approved quotation. Prepare a new one for the client.'.tr
        : 'Waiting for the client to approve {0}. Mark it '
                  'Approved when they agree, then invoice from it.'
              .trArgs([open.first.number]);
  }
  final due = [
    for (final i in issued)
      if (repo.balanceOf(i) > 0.005) i,
  ]..sort((a, b) => a.date.compareTo(b.date));
  if (due.isNotEmpty) {
    final names = due.length <= 3
        ? due.map((i) => i.number).join(', ')
        : '{0} invoices'.trArgs([due.length]);
    final allLate = m.overdue >= m.outstanding - 0.005;
    final args = [fmtMoney(m.outstanding), names, fmtMoney(m.overdue)];
    return allLate
        ? '{0} is overdue on {1}. Record a receipt when the client pays.'
              .trArgs(args)
        : m.overdue > 0.005
        ? '{0} is due on {1}, {2} of it overdue. Record a receipt when the '
                  'client pays.'
              .trArgs(args)
        : '{0} is due on {1}. Record a receipt when the client pays.'.trArgs(
            args,
          );
  }
  if (drafts.isNotEmpty) {
    return '{0} is still a draft. Send it to issue it; '
            'money already received is set off automatically.'
        .trArgs([drafts.first.number]);
  }
  if (approved.isNotEmpty && issued.isEmpty) {
    return m.advances > 0.005
        ? 'Raise the first invoice from {0}; the {1} received in advance is '
                  'deducted from it.'
              .trArgs([approved.first.number, fmtMoney(m.advances)])
        : 'Raise the first invoice from {0}.'.trArgs([approved.first.number]);
  }
  if (m.leftToInvoice > 0.005) {
    return m.advances > 0.005
        ? 'Nothing due now. {0} of the contract is left to invoice, and the '
                  '{1} received in advance is set off on the next invoices.'
              .trArgs([fmtMoney(m.leftToInvoice), fmtMoney(m.advances)])
        : 'Nothing due now. {0} of the contract is left to invoice.'.trArgs([
            fmtMoney(m.leftToInvoice),
          ]);
  }
  if (issued.isNotEmpty) {
    return m.advances > 0.005
        ? 'Fully invoiced and paid. {0} credit is held for the client.'.trArgs([
            fmtMoney(m.advances),
          ])
        : 'Fully invoiced and paid.'.tr;
  }
  return 'Raise the first invoice from the approved quotation.'.tr;
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
                'CLIENT ACCOUNT'.tr,
                if (clientName != null) clientName!.toUpperCase(),
              ].dots(),
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
              'Contract value'.tr,
              m.quoted,
              hint: m.quoted > 0
                  ? 'Approved quotations'.tr
                  : 'No approved quotation yet'.tr,
            ),
            row(
              'Invoiced'.tr,
              m.invoiced,
              hint: [
                if (m.quoted > 0 && m.onContract > 0.005)
                  '{0} of the contract'.trArgs([pct(m.onContract, m.quoted)]),
                if (m.extras > 0.005)
                  '{0} extra work'.trArgs([fmtMoney(m.extras)]),
              ].dots(),
            ),
            row(
              'Received'.tr,
              m.received,
              color: m.received > 0 ? ak.good : null,
              hint: m.invoiced > 0 && m.received > 0
                  ? '{0} of invoiced'.trArgs([pct(m.received, m.invoiced)])
                  : null,
            ),
            const Divider(height: 16),
            if (due > 0.005 || m.advances <= 0.005)
              row(
                'Due now'.tr,
                due,
                bold: true,
                color: m.overdue > 0.005
                    ? ak.bad
                    : due > 0.005
                    ? null
                    : ak.good,
                hint: m.overdue > 0.005
                    ? '{0} overdue'.trArgs([fmtMoney(m.overdue)])
                    : due > 0.005
                    ? 'On issued invoices, after advances'.tr
                    : 'Nothing to collect on issued invoices'.tr,
              ),
            if (m.advances > 0.005)
              row(
                'Credit held'.tr,
                m.advances,
                bold: due <= 0.005,
                color: ak.info,
                hint:
                    'Received ahead; set off on the next invoices, '
                            'oldest first'
                        .tr,
              ),
            if (m.quoted > 0 || m.invoiced > 0) ...[
              const SizedBox(height: 6),
              if (m.quoted > 0)
                row(
                  'Left to invoice'.tr,
                  m.leftToInvoice,
                  hint: 'Contract less what was invoiced on it'.tr,
                ),
              row(
                'Still to receive'.tr,
                m.leftToReceive,
                hint: m.quoted <= 0.005
                    ? 'Invoiced less received'.tr
                    : m.extras > 0.005
                    ? 'Contract and extra work, less received'.tr
                    : m.onContract > m.quoted + 0.005
                    ? 'Invoiced less received (above the contract)'.tr
                    : 'Contract less received'.tr,
              ),
            ],
            if (m.quoted > 0) ...[
              const SizedBox(height: 10),
              _Progress(
                label: 'Invoiced of the contract'.tr,
                value: m.onContract / m.quoted,
              ),
              const SizedBox(height: 8),
              if (m.extras > 0.005)
                _Progress(
                  label: 'Received of the contract and extra work'.tr,
                  value:
                      m.received /
                      ((m.onContract > m.quoted ? m.onContract : m.quoted) +
                          m.extras),
                )
              else
                _Progress(
                  label: 'Received of the contract'.tr,
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
              'Amounts include VAT, as on the client\'s documents.'.tr,
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
