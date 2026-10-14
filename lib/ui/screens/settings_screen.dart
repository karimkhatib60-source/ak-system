import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../../sync/cloud_account.dart';
import '../../sync/sync_service.dart';
import '../format.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const SectionHeader('Cloud sync and login'),
            const _CloudSection(),
            const SectionHeader('Team'),
            const _TeamSection(),
            SectionHeader('Project stages',
                trailing: repo.isOwner
                    ? TextButton.icon(
                        onPressed: () => _editStage(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('Add stage'))
                    : null),
            const _StagesSection(),
            if (repo.isOwner) ...[
              const SectionHeader('Company'),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(repo.companyName),
                subtitle: const Text('Shown in the app header'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final v = await _ask(context, 'Company name', repo.companyName);
                  if (v != null && v.isNotEmpty) await repo.setCompanyName(v);
                },
              ),
            ],
            const SectionHeader('About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('AK System · Phase 1'),
              subtitle: Text(
                  'Projects, tasks and deliverables. Works offline; syncs when online.'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, String title, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save')),
      ],
    ),
  );
}

Future<void> _editStage(BuildContext context, Stage? s) async {
  final repo = context.read<Repository>();
  final name = await _ask(context, s == null ? 'New stage' : 'Rename stage',
      s?.name ?? '');
  if (name == null || name.isEmpty) return;
  final now = repo.now();
  await repo.saveStage(s?.copyWith(name: name) ??
      Stage(
        id: repo.newId(),
        createdAt: now,
        updatedAt: now,
        name: name,
        position: repo.stages.length,
      ));
}

class _StagesSection extends StatelessWidget {
  const _StagesSection();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final stages = repo.stages;
    return Column(
      children: [
        for (var i = 0; i < stages.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(radius: 12, child: Text('${i + 1}',
                style: const TextStyle(fontSize: 11))),
            title: Text(stages[i].name),
            onTap: repo.isOwner ? () => _editStage(context, stages[i]) : null,
            trailing: !repo.isOwner
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Move up',
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        onPressed: i == 0
                            ? null
                            : () => repo.moveStage(stages[i], -1),
                      ),
                      IconButton(
                        tooltip: 'Move down',
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        onPressed: i == stages.length - 1
                            ? null
                            : () => repo.moveStage(stages[i], 1),
                      ),
                      IconButton(
                        tooltip: 'Delete stage',
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          final used = repo.projects
                              .any((p) => p.stageId == stages[i].id);
                          if (used) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'A project is at this stage. Move it first.')));
                            return;
                          }
                          if (await confirmDelete(
                              context, 'the stage "${stages[i].name}"')) {
                            await repo.deleteStage(stages[i]);
                          }
                        },
                      ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    if (repo.members.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.group_outlined),
        title: Text('No team logins yet'),
        subtitle: Text(
            'Once cloud sync is set up, each person creates a login from this '
            'screen. The first login becomes the owner; the next ones join as '
            'architects.'),
      );
    }
    return Column(
      children: [
        for (final m in repo.members)
          ListTile(
            leading: CircleAvatar(
                child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase())),
            title: Text(m.id == repo.currentMemberId ? '${m.name} (you)' : m.name),
            subtitle: Text('${roleLabel(m.role)} · ${m.email}'),
            trailing: repo.isOwner && m.id != repo.currentMemberId
                ? DropdownButton<MemberRole>(
                    value: m.role,
                    underline: const SizedBox(),
                    items: [
                      for (final r in MemberRole.values)
                        DropdownMenuItem(value: r, child: Text(roleLabel(r))),
                    ],
                    onChanged: (r) => repo.saveMember(m.copyWith(role: r)),
                  )
                : null,
          ),
      ],
    );
  }
}

class _CloudSection extends StatelessWidget {
  const _CloudSection();

  @override
  Widget build(BuildContext context) {
    final cloud = context.watch<CloudAccount>();
    final sync = context.watch<SyncService>();
    if (!cloud.configured) {
      return ListTile(
        leading: const Icon(Icons.cloud_outlined),
        title: const Text('Not connected'),
        subtitle: const Text(
            'Everything is saved on this device. Connect the company cloud '
            'database to sync between phone and laptop and add your team.'),
        trailing: FilledButton.tonal(
          onPressed: () => showDialog(
              context: context, builder: (_) => const _ConnectDialog()),
          child: const Text('Connect'),
        ),
      );
    }
    if (!cloud.signedIn) {
      return ListTile(
        leading: const Icon(Icons.login),
        title: const Text('Connected, not signed in'),
        subtitle: Text(cloud.url ?? ''),
        trailing: FilledButton(
          onPressed: () => showDialog(
              context: context, builder: (_) => const _LoginDialog()),
          child: const Text('Sign in'),
        ),
      );
    }
    final last = sync.lastSyncedAt;
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(cloud.user?.email ?? ''),
          subtitle: Text(switch (sync.state) {
            SyncState.syncing => 'Syncing…',
            SyncState.offline =>
              'Offline. Changes are kept on this device until you reconnect.',
            SyncState.error => 'Sync problem: ${sync.lastError}',
            _ => last == null
                ? 'Signed in'
                : 'Last synced ${TimeOfDay.fromDateTime(last).format(context)}',
          }),
          trailing: IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: sync.syncNow,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: cloud.signOut,
              child: const Text('Sign out'),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog();

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  final _url = TextEditingController();
  final _key = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Connect cloud database'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Paste the Project URL and the anon public key from your '
                'Supabase project (Project Settings > API).'),
            const SizedBox(height: 12),
            TextField(
                controller: _url,
                decoration: const InputDecoration(
                    labelText: 'Project URL',
                    hintText: 'https://xxxx.supabase.co')),
            const SizedBox(height: 12),
            TextField(
                controller: _key,
                decoration: const InputDecoration(labelText: 'Anon public key')),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  final url = _url.text.trim();
                  if (!url.startsWith('https://') || _key.text.trim().isEmpty) {
                    setState(() => _error = 'Enter both the URL and the key.');
                    return;
                  }
                  setState(() => _busy = true);
                  try {
                    await context.read<CloudAccount>().configure(url, _key.text);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    setState(() {
                      _busy = false;
                      _error = '$e';
                    });
                  }
                },
          child: const Text('Connect'),
        ),
      ],
    );
  }
}

class _LoginDialog extends StatefulWidget {
  const _LoginDialog();

  @override
  State<_LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<_LoginDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    final cloud = context.read<CloudAccount>();
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_create) {
        await cloud.signUp(_name.text, _email.text, _password.text);
        if (!cloud.signedIn) {
          setState(() {
            _busy = false;
            _create = false;
            _message = 'Login created. Confirm it from the email, then sign in.';
          });
          return;
        }
      } else {
        await cloud.signIn(_email.text, _password.text);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _busy = false;
        _message = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_create ? 'Create login' : 'Sign in'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_create) ...[
              TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Your name')),
              const SizedBox(height: 12),
            ],
            TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Password')),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _create = !_create),
                child: Text(_create
                    ? 'I already have a login'
                    : 'New here? Create a login'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_create ? 'Create' : 'Sign in')),
      ],
    );
  }
}
