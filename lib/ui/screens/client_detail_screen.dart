import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/statement.dart';
import '../format.dart';
import '../pdf_docs.dart';
import '../theme.dart';

import '../../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/tiles.dart';
import 'client_form.dart';
import 'project_form.dart';
import 'receipts.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final q = _query.toLowerCase();
    final clients = repo.visibleClients
        .where(
          (c) =>
              q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.company.toLowerCase().contains(q),
        )
        .toList();
    return Scaffold(
      floatingActionButton: repo.isOwner
          ? FloatingActionButton.extended(
              heroTag: 'add-client',
              onPressed: () => openClientForm(context),
              icon: const Icon(Icons.person_add_alt),
              label: Text('Client'.tr),
            )
          : null,
      body: Readable(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search clients'.tr,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: clients.isEmpty
                  ? EmptyState(
                      icon: Icons.people_outline,
                      title: 'No clients yet'.tr,
                      message: 'Add a client, then open projects for them.'.tr,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: clients.length,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (_, i) {
                        final c = clients[i];
                        final count = repo.projectsFor(c.id).length;
                        return GroupedRow(
                          index: i,
                          count: clients.length,
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                c.name.isEmpty ? '?' : c.name[0].toUpperCase(),
                              ),
                            ),
                            title: Text(c.name),
                            subtitle: Text(
                              [
                                if (c.company.isNotEmpty) c.company,
                                if (c.country.isNotEmpty) c.country,
                                count == 1
                                    ? '1 project'.tr
                                    : '{0} projects'.trArgs([count]),
                              ].join(' · '),
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClientDetailScreen(clientId: c.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientDetailScreen extends StatelessWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = repo.client(clientId);
    final scheme = Theme.of(context).colorScheme;
    if (c == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Client not found'.tr,
        ),
      );
    }
    final projects = repo.projectsFor(c.id);

    Widget contact(IconData icon, String value) => ListTile(
      leading: Icon(icon),
      title: Text(value),
      trailing: IconButton(
        tooltip: 'Copy'.tr,
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Copied'.tr)));
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (repo.isOwner) ...[
            IconButton(
              tooltip: 'Edit client'.tr,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openClientForm(context, client: c),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v != 'delete') return;
                if (projects.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'This client has projects. Delete or move them first.'
                            .tr,
                      ),
                    ),
                  );
                  return;
                }
                if (await confirmDelete(context, c.name)) {
                  await repo.deleteClient(c);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'delete', child: Text('Delete client'.tr)),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: repo.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => openProjectForm(context, clientId: c.id),
              icon: const Icon(Icons.add),
              label: Text('Project'.tr),
            )
          : null,
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (c.company.isNotEmpty)
              contact(Icons.business_outlined, c.company),
            if (c.phone.isNotEmpty) contact(Icons.phone_outlined, c.phone),
            if (c.email.isNotEmpty) contact(Icons.email_outlined, c.email),
            if (c.country.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(c.country),
              ),
            if (c.notes.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.notes),
                title: Text(
                  c.notes,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            if (repo.isOwner) _AccountCard(clientId: c.id),
            SectionHeader('Projects ({0})'.trArgs([projects.length])),
            if (projects.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('No projects for this client yet.'.tr),
              ),
            for (final p in projects)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: ProjectCard(p),
              ),
          ],
        ),
      ),
    );
  }
}

/// The client's balance, with the statement of account to send.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final st = buildStatement(repo, clientId);
    if (st.lines.isEmpty && st.contractValue == 0) return const SizedBox();
    Widget figure(String l, double v, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l, style: TextStyle(color: ak.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            fmtMoneyShort(v),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  figure('Invoiced'.tr, st.invoiced),
                  figure('Received'.tr, st.received, color: ak.good),
                  if (st.advances > 0.005)
                    figure(
                      'Due on invoices'.tr,
                      st.dueOnInvoices,
                      color: st.overdue > 0 ? ak.bad : null,
                    )
                  else if (st.closing < -0.005)
                    figure('Credit'.tr, -st.closing, color: ak.good)
                  else
                    figure(
                      'Balance due'.tr,
                      st.closing,
                      color: st.overdue > 0 ? ak.bad : null,
                    ),
                ],
              ),
              if (st.advances > 0.005) ...[
                const SizedBox(height: 8),
                Text(
                  'Credit held: {0} received in '
                          'advance and not yet set against an invoice.'
                      .trArgs([fmtMoney(st.advances)]),
                  style: TextStyle(color: ak.muted, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => showStatementSheet(context, clientId),
                    icon: const Icon(Icons.request_quote_outlined),
                    label: Text('Statement of account'.tr),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        openReceiptForm(context, clientId: clientId),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text('Receipt'.tr),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Choose the period and project, then send the statement as a PDF.
Future<void> showStatementSheet(BuildContext context, String clientId) {
  final repo = context.read<Repository>();
  final now = repo.now();
  var period = 'all';
  DateTime? from;
  String? projectId;
  final projects = repo.projectsFor(clientId);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final start = switch (period) {
          'year' => DateTime(now.year),
          'custom' => from,
          _ => null,
        };
        final st = buildStatement(
          repo,
          clientId,
          from: start,
          projectId: projectId,
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Statement of account'.tr,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 'all', label: Text('All time'.tr)),
                    ButtonSegment(value: 'year', label: Text('This year'.tr)),
                    ButtonSegment(value: 'custom', label: Text('From date'.tr)),
                  ],
                  selected: {period},
                  onSelectionChanged: (v) => set(() {
                    period = v.first;
                    if (period == 'custom') {
                      from ??= DateTime(now.year, now.month);
                    }
                  }),
                ),
                if (period == 'custom') ...[
                  const SizedBox(height: 12),
                  DateField(
                    label: 'From'.tr,
                    value: from,
                    onChanged: (d) => set(() => from = d),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: projectId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: 'Project'.tr),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text('All projects'.tr),
                    ),
                    for (final p in projects)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.code} · ${p.name}'),
                      ),
                  ],
                  onChanged: (v) => set(() => projectId = v),
                ),
                const SizedBox(height: 14),
                Text(
                  '{0} movements · invoiced {1} · received {2}'.trArgs([
                    st.lines.length,
                    fmtMoney(st.invoiced),
                    fmtMoney(st.received),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance due {0}'.trArgs([fmtMoney(st.closing)]),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await shareStatementPdf(repo, st);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.ios_share),
                  label: Text('Send PDF'.tr),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
