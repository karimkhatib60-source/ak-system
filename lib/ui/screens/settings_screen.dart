import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_version.dart';
import '../../data/company_links.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../sync/cloud_account.dart';
import '../../sync/sync_service.dart';
import '../format.dart';
import '../maps.dart';
import '../pdf_docs.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import '../widgets/update_banner.dart';
import '../../update/update_service.dart';

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
            SectionHeader('Language'.tr),
            const _LanguageSection(),
            const SectionHeader('Cloud sync and login'),
            const _CloudSection(),
            const SectionHeader('Team'),
            const _TeamSection(),
            const SectionHeader('Project stages'),
            const _StagesSection(),
            if (repo.isOwner) ...[
              const SectionHeader('Company'),
              const _CompanyCard(),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(repo.companyName),
                subtitle: const Text('Shown in the app header'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () async {
                  final v = await _ask(
                    context,
                    'Company name',
                    repo.companyName,
                  );
                  if (v != null && v.isNotEmpty) await repo.setCompanyName(v);
                },
              ),
              for (final k in companyInfoKeys)
                ListTile(
                  dense: true,
                  leading: Icon(_infoIcon(k)),
                  title: Text(_infoLabel(k)),
                  subtitle: Text(
                    (repo.companyInfo[k] ?? '').isEmpty
                        ? 'Not set'
                        : repo.companyInfo[k]!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () async {
                    final v = await _ask(
                      context,
                      _infoLabel(k),
                      repo.companyInfo[k] ?? '',
                      multiline: k == 'bank' || k == 'terms' || k == 'address',
                    );
                    if (v != null) await repo.setCompanyInfo({k: v});
                  },
                ),
            ],
            if (repo.isOwner) ...[
              const SectionHeader('Document colours'),
              const _ReportColours(),
            ],
            const SectionHeader('About'),
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('AK System · version $appVersion'),
              subtitle: Text(
                'Projects, tasks, deliverables and finance. Works offline; syncs when online.',
              ),
            ),
            const _UpdatesTile(),
          ],
        ),
      ),
    );
  }
}

String _infoLabel(String k) => switch (k) {
  'address' => 'Address',
  'phone' => 'Phone',
  'email' => 'Email',
  'website' => 'Website',
  'whatsapp' => 'WhatsApp',
  'instagram' => 'Instagram',
  'facebook' => 'Facebook page link',
  'linkedin' => 'LinkedIn page link',
  'tax_number' => 'VAT / tax number',
  'bank' => 'Bank details (on invoices)',
  'terms' => 'Standard terms (on quotations and invoices)',
  _ => k,
};

IconData _infoIcon(String k) => switch (k) {
  'address' => Icons.location_on_outlined,
  'phone' => Icons.phone_outlined,
  'email' => Icons.mail_outline,
  'website' => Icons.language,
  'whatsapp' => Icons.chat_outlined,
  'instagram' => Icons.camera_alt_outlined,
  'facebook' => Icons.facebook,
  'linkedin' => Icons.work_outline,
  'tax_number' => Icons.receipt_long_outlined,
  'bank' => Icons.account_balance_outlined,
  _ => Icons.gavel_outlined,
};

Future<String?> _ask(
  BuildContext context,
  String title,
  String initial, {
  bool multiline = false,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        minLines: multiline ? 3 : 1,
        maxLines: multiline ? 6 : 1,
        onSubmitted: multiline ? null : (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<void> _editStage(
  BuildContext context,
  Stage? s,
  ServiceType service,
) async {
  final repo = context.read<Repository>();
  final name = await _ask(
    context,
    s == null ? 'New stage' : 'Rename stage',
    s?.name ?? '',
  );
  if (name == null || name.isEmpty) return;
  final now = repo.now();
  await repo.saveStage(
    s?.copyWith(name: name) ??
        Stage(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          name: name,
          position: repo.stagesFor(service).length,
          service: service,
        ),
  );
}

class _StagesSection extends StatefulWidget {
  const _StagesSection();

  @override
  State<_StagesSection> createState() => _StagesSectionState();
}

class _StagesSectionState extends State<_StagesSection> {
  ServiceType _service = ServiceType.design;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final stages = repo.stagesFor(_service);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ServiceType>(
              showSelectedIcon: false,
              segments: [
                for (final s in ServiceType.values)
                  ButtonSegment(value: s, label: Text(serviceLabel(s))),
              ],
              selected: {_service},
              onSelectionChanged: (v) => setState(() => _service = v.first),
            ),
          ),
        ),
        for (var i = 0; i < stages.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              child: Text('${i + 1}', style: const TextStyle(fontSize: 11)),
            ),
            title: Text(stages[i].name),
            onTap: repo.isOwner
                ? () => _editStage(context, stages[i], _service)
                : null,
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
                          final used = repo.projects.any(
                            (p) => p.stageId == stages[i].id,
                          );
                          if (used) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A project is at this stage. Move it first.',
                                ),
                              ),
                            );
                            return;
                          }
                          if (await confirmDelete(
                            context,
                            'the stage "${stages[i].name}"',
                          )) {
                            await repo.deleteStage(stages[i]);
                          }
                        },
                      ),
                    ],
                  ),
          ),
        if (repo.isOwner)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: TextButton.icon(
                onPressed: () => _editStage(context, null, _service),
                icon: const Icon(Icons.add),
                label: Text(
                  'Add ${serviceLabel(_service).toLowerCase()} stage',
                ),
              ),
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
          'architects.',
        ),
      );
    }
    return Column(
      children: [
        for (final m in repo.members)
          ListTile(
            leading: CircleAvatar(
              child: Text(m.name.isEmpty ? '?' : m.name[0].toUpperCase()),
            ),
            title: Text(
              m.id == repo.currentMemberId ? '${m.name} (you)' : m.name,
            ),
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
          'database to sync between phone and laptop and add your team.',
        ),
        trailing: FilledButton.tonal(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => const _ConnectDialog(),
          ),
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
            context: context,
            builder: (_) => const _LoginDialog(),
          ),
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
            _ =>
              last == null
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
              'Supabase project (Project Settings > API).',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://xxxx.supabase.co',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _key,
              decoration: const InputDecoration(labelText: 'Anon public key'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
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
                    await context.read<CloudAccount>().configure(
                      url,
                      _key.text,
                    );
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
            _message =
                'Login created. Confirm it from the email, then sign in.';
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
                decoration: const InputDecoration(labelText: 'Your name'),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _create = !_create),
                child: Text(
                  _create
                      ? 'I already have a login'
                      : 'New here? Create a login',
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_create ? 'Create' : 'Sign in'),
        ),
      ],
    );
  }
}

IconData linkIcon(String kind) => switch (kind) {
  'website' => Icons.language,
  'phone' => Icons.phone_outlined,
  'whatsapp' => Icons.chat_outlined,
  'email' => Icons.mail_outline,
  'instagram' => Icons.camera_alt_outlined,
  'facebook' => Icons.facebook,
  _ => Icons.link,
};

/// Logo, name and links, as they appear on documents.
class _CompanyCard extends StatelessWidget {
  const _CompanyCard();

  Future<void> _pickLogo(BuildContext context) async {
    final repo = context.read<Repository>();
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (files.isEmpty) return;
    final bytes = await files.first.readAsBytes();
    if (bytes.length > 1500000) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please choose a logo under 1.5 MB (PNG works best).',
            ),
          ),
        );
      }
      return;
    }
    await repo.setCompanyLogo(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final logo = repo.companyLogo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: ak.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: logo == null
                        ? const Center(child: AkMonogram(size: 48))
                        : Image.memory(logo, fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          repo.companyName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Design · Consultancy · Contracting',
                          style: TextStyle(color: ak.muted, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [
                            TextButton.icon(
                              onPressed: () => _pickLogo(context),
                              icon: const Icon(Icons.upload_outlined, size: 18),
                              label: Text(
                                logo == null ? 'Upload logo' : 'Change logo',
                              ),
                            ),
                            if (logo != null)
                              TextButton(
                                onPressed: () => repo.setCompanyLogo(null),
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final l in companyLinks(repo.companyInfo))
                    ActionChip(
                      avatar: Icon(linkIcon(l.kind), size: 16),
                      label: Text(l.display),
                      onPressed: () => openUri(Uri.parse(l.url)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'The logo and these details print on every quotation, '
                'invoice and statement.',
                style: TextStyle(color: ak.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Updates of the Windows app: the state of the last check, and the button
/// to look again or install.
class _UpdatesTile extends StatelessWidget {
  const _UpdatesTile();

  @override
  Widget build(BuildContext context) {
    final u = context.watch<UpdateService?>();
    if (u == null || !u.supported) return const SizedBox();
    final r = u.available;
    final (title, subtitle) = switch (u.state) {
      UpdateState.checking => ('Checking for updates…', null),
      UpdateState.downloading => (
        'Downloading version ${r?.version}…',
        '${(u.progress * 100).round()}%',
      ),
      UpdateState.installing => (
        'Installing version ${r?.version}…',
        'AK System will open again in a moment.',
      ),
      UpdateState.ready => (
        'Version ${r?.version} is ready to install',
        u.problem ?? 'Your data stays as it is.',
      ),
      UpdateState.upToDate => ('You have the latest version', null),
      UpdateState.failed => ('Updates', u.problem),
      UpdateState.idle => (
        'Updates',
        'When a new version is ready you will see it here and at the top '
            'of the app.',
      ),
    };
    return ListTile(
      leading: const Icon(Icons.system_update_alt),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: switch (u.state) {
        UpdateState.ready => Wrap(
          spacing: 4,
          children: [
            if (r != null)
              TextButton(
                onPressed: () => showWhatsNew(context, r),
                child: const Text('What\'s new'),
              ),
            if (u.blocked)
              TextButton(
                onPressed: () => openDownloadPage(u),
                child: const Text('Download page'),
              ),
            FilledButton(onPressed: u.install, child: const Text('Update now')),
          ],
        ),
        UpdateState.checking ||
        UpdateState.downloading ||
        UpdateState.installing => const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        _ => TextButton(onPressed: u.check, child: const Text('Check now')),
      },
    );
  }
}

/// Colours of quotations, invoices, receipts and statements.
class _ReportColours extends StatefulWidget {
  const _ReportColours();

  @override
  State<_ReportColours> createState() => _ReportColoursState();
}

class _ReportColoursState extends State<_ReportColours> {
  bool _own = false;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final current = repo.reportTheme;
    final own = _own || current.custom;
    Widget swatch(int c, {double size = 14}) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(c),
        borderRadius: BorderRadius.circular(size / 4),
        border: Border.all(color: Colors.black12),
      ),
    );
    Widget pickRow(
      String label,
      List<int> colours,
      int selected,
      ReportTheme Function(int) make,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(label, style: TextStyle(color: ak.muted, fontSize: 12.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in colours)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => repo.setReportTheme(make(c)),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      width: 2,
                      color: c == selected
                          ? AkPalette.blue
                          : Colors.transparent,
                    ),
                  ),
                  child: swatch(c, size: 26),
                ),
              ),
          ],
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReportPreview(theme: current),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in reportThemes)
                    ChoiceChip(
                      selected: t.id == current.id,
                      showCheckmark: false,
                      avatar: _Pair(t),
                      label: Text(t.name),
                      onSelected: (_) {
                        setState(() => _own = false);
                        repo.setReportTheme(t);
                      },
                    ),
                  ChoiceChip(
                    selected: own,
                    showCheckmark: false,
                    avatar: const Icon(Icons.palette_outlined, size: 18),
                    label: const Text('Own colours'),
                    onSelected: (_) {
                      setState(() => _own = true);
                      if (!current.custom) {
                        repo.setReportTheme(
                          ReportTheme.customOf(current.ink, current.accent),
                        );
                      }
                    },
                  ),
                ],
              ),
              if (own) ...[
                pickRow(
                  'Main colour: headings, table headers and totals',
                  reportInks,
                  current.ink,
                  (c) => ReportTheme.customOf(c, current.accent),
                ),
                pickRow(
                  'Highlight colour: document number and accents',
                  reportAccents,
                  current.accent,
                  (c) => ReportTheme.customOf(current.ink, c),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Used on every quotation, invoice, receipt and statement '
                'from now on.',
                style: TextStyle(color: ak.muted, fontSize: 12),
              ),
              if (repo.invoices.isNotEmpty || repo.quotations.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => sharePdf(
                      repo,
                      repo.invoices.isNotEmpty
                          ? repo.invoices.first
                          : repo.quotations.first,
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(
                      repo.invoices.isNotEmpty
                          ? 'See it on ${repo.invoices.first.number}'
                          : 'See it on ${repo.quotations.first.number}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small page drawn in a report theme, to compare themes at a glance.
class ReportPreview extends StatelessWidget {
  const ReportPreview({super.key, required this.theme});

  final ReportTheme theme;

  @override
  Widget build(BuildContext context) {
    final ink = Color(theme.ink);
    final accent = Color(theme.accent);
    final soft = Color(theme.soft);
    final line = Color(theme.line);
    final muted = Color(theme.muted);
    Widget bar(double w, Color c, {double h = 5}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    return Container(
      height: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AkPalette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(70, ink),
                  const SizedBox(height: 4),
                  bar(46, muted, h: 3),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'INVOICE',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'INV-0012',
                    style: TextStyle(color: accent, fontSize: 9.5),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1.5, color: ink),
          const SizedBox(height: 8),
          Container(
            height: 14,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: ink,
            alignment: AlignmentDirectional.centerStart,
            child: bar(60, Colors.white54, h: 3),
          ),
          for (var k = 0; k < 3; k++)
            Container(
              height: 13,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: k == 1 ? soft : null,
                border: Border(bottom: BorderSide(color: line)),
              ),
              child: Row(
                children: [
                  bar(80.0 - k * 14, muted.withValues(alpha: .5), h: 3),
                  const Spacer(),
                  bar(26, muted.withValues(alpha: .5), h: 3),
                ],
              ),
            ),
          const Spacer(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'TOTAL  \$4,440.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two colours of a theme in one small square.
class _Pair extends StatelessWidget {
  const _Pair(this.theme);

  final ReportTheme theme;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: Colors.white70),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(theme.ink),
          Color(theme.ink),
          Color(theme.accent),
          Color(theme.accent),
        ],
        stops: const [0, .6, .6, 1],
      ),
    ),
  );
}

/// Language of the screens and, for the owner, of printed documents.
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    Widget choice(
      String label,
      AppLang value,
      Future<void> Function(AppLang) set,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<AppLang>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: AppLang.en, label: Text('English')),
              ButtonSegment(value: AppLang.ar, label: Text('العربية')),
            ],
            selected: {value},
            onSelectionChanged: (v) => set(v.first),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              choice('Screens'.tr, repo.appLanguage, repo.setAppLanguage),
              if (repo.isOwner)
                choice(
                  'Quotations, invoices and receipts'.tr,
                  repo.docLanguage,
                  repo.setDocLanguage,
                ),
              const SizedBox(height: 4),
              Text(
                'Each person chooses the language of their own screens. '
                        'Documents print in the language chosen here.'
                    .tr,
                style: TextStyle(color: ak.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
