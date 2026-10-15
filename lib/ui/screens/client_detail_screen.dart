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
              label: const Text('Client'),
            )
          : null,
      body: Readable(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search clients',
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: clients.isEmpty
                  ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No clients yet',
                      message: 'Add a client, then open projects for them.',
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
                                '$count project${count == 1 ? '' : 's'}',
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
        body: const EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Client not found',
        ),
      );
    }
    final projects = repo.projectsFor(c.id);

    Widget contact(IconData icon, String value) => ListTile(
      leading: Icon(icon),
      title: Text(value),
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () {
          Clipboard.setData(ClipboardData(text: value));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Copied')));
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (repo.isOwner) ...[
            IconButton(
              tooltip: 'Edit client',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => openClientForm(context, client: c),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v != 'delete') return;
                if (projects.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This client has projects. Delete or move them first.',
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
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete client')),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: repo.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => openProjectForm(context, clientId: c.id),
              icon: const Icon(Icons.add),
              label: const Text('Project'),
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
            SectionHeader('Projects (${projects.length})'),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('No projects for this client yet.'),
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
                  figure('Invoiced', st.invoiced),
                  figure('Received', st.received, color: ak.good),
                  figure(
                    'Balance due',
                    st.closing,
                    color: st.overdue > 0 ? ak.bad : null,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => showStatementSheet(context, clientId),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('Statement of account'),
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
                const Text(
                  'Statement of account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('All time')),
                    ButtonSegment(value: 'year', label: Text('This year')),
                    ButtonSegment(value: 'custom', label: Text('From date')),
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
                    label: 'From',
                    value: from,
                    onChanged: (d) => set(() => from = d),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: projectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Project'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All projects'),
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
                  '${st.lines.length} movements · invoiced '
                  '${fmtMoney(st.invoiced)} · received '
                  '${fmtMoney(st.received)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance due ${fmtMoney(st.closing)}',
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
                  label: const Text('Send PDF'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
