import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
