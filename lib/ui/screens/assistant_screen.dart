import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/assistant.dart';
import '../../data/advisor.dart';
import '../../data/repository.dart';
import '../maps.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'project_detail_screen.dart';

/// AK Assistant: type what you want done; it fills in the app and tells you
/// what is still missing. The "To cover" list works without AI.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _examples = [
    'New design project: villa in Byblos for Nadim Haddad, 450 m², '
        'deadline end of March',
    'Make a quotation for the villa: concept 3,000, permit drawings 5,000, '
        'execution drawings 7,000',
    'Received 2,000 from Nadim by bank transfer',
    'What am I missing?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final ai = context.read<Assistant>();
    _input.clear();
    final f = ai.send(text);
    _toEnd();
    await f;
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<Assistant>();
    final repo = context.watch<Repository>();
    final ak = AkColors.of(context);
    final advice = reviewOffice(repo);

    return Scaffold(
      appBar: AppBar(
        title: Text(ai.ready ? 'AK Assistant' : 'To cover'),
        actions: [
          if (ai.lines.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.refresh),
              onPressed: ai.clear,
            ),
          if (ai.ready)
            IconButton(
              tooltip: 'AI key',
              icon: const Icon(Icons.key_outlined),
              onPressed: () => showAiKeyDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Readable(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (ai.lines.isEmpty) ...[
                    if (ai.ready) ...[
                      const _Intro(ready: true),
                      const SizedBox(height: 12),
                    ] else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Text(
                          'What is missing, late or waiting across your '
                          'projects. Tap an item to open the project and fix it.',
                          style: TextStyle(color: ak.muted, height: 1.4),
                        ),
                      ),
                    if (ai.ready)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final e in _examples)
                            ActionChip(
                              label: Text(e, maxLines: 2),
                              onPressed: () => _input.text = e,
                            ),
                        ],
                      ),
                    SectionHeader('To cover (${advice.length})'),
                    if (advice.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Nothing missing right now.'),
                      ),
                    for (var i = 0; i < advice.length && i < 25; i++)
                      GroupedRow(
                        index: i,
                        count: advice.length.clamp(0, 25),
                        child: AdviceTile(advice[i]),
                      ),
                  ],
                  for (final l in ai.lines) _Bubble(l),
                  if (ai.busy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Working on it…',
                            style: TextStyle(color: ak.muted),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (ai.ready)
            Material(
              color: ak.card,
              child: SafeArea(
                top: false,
                child: Readable(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            enabled: ai.ready,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: ai.ready
                                  ? 'Tell me what to do…'
                                  : 'Add your AI key to start',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: !ai.ready || ai.busy
                              ? null
                              : () => _send(_input.text),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ak.chrome,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: ak.accent),
              const SizedBox(width: 8),
              Text(
                'Tell it, and it is done',
                style: TextStyle(
                  color: ak.onChrome,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Write or dictate what you need: a new client or project, tasks '
            'for the team, a quotation, an invoice, a payment received. The '
            'assistant enters it in the app and asks about anything you '
            'missed.',
            style: TextStyle(color: ak.onChromeMuted, height: 1.4),
          ),
          if (!ready) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => showAiKeyDialog(context),
              icon: const Icon(Icons.key_outlined),
              label: const Text('Add AI key'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.line);

  final ChatLine line;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final c = Theme.of(context).colorScheme;
    final user = line.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: user ? ak.accent : ak.card,
            border: user ? null : Border.all(color: ak.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (line.actions.isNotEmpty) ...[
                for (final a in line.actions)
                  InkWell(
                    onTap: a.projectId == null
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailScreen(projectId: a.projectId!),
                            ),
                          ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            a.error ? Icons.error_outline : Icons.check_circle,
                            size: 16,
                            color: a.error ? ak.bad : ak.good,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              a.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (line.text.isNotEmpty) const Divider(height: 16),
              ],
              if (line.text.isNotEmpty)
                SelectableText(
                  line.text,
                  style: TextStyle(
                    color: user ? Colors.white : c.onSurface,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One "to cover" item, opening its project when tapped.
class AdviceTile extends StatelessWidget {
  const AdviceTile(this.a, {super.key});

  final Advice a;

  @override
  Widget build(BuildContext context) {
    final ak = AkColors.of(context);
    final color = switch (a.level) {
      AdviceLevel.urgent => ak.bad,
      AdviceLevel.important => ak.warn,
      AdviceLevel.tip => ak.info,
    };
    return ListTile(
      leading: Icon(switch (a.level) {
        AdviceLevel.urgent => Icons.error_outline,
        AdviceLevel.important => Icons.flag_outlined,
        AdviceLevel.tip => Icons.lightbulb_outline,
      }, color: color),
      title: Text(a.title),
      subtitle: Text(a.detail),
      trailing: a.projectId == null ? null : const Icon(Icons.chevron_right),
      onTap: a.projectId == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(projectId: a.projectId!),
              ),
            ),
    );
  }
}

Future<void> showAiKeyDialog(BuildContext context) async {
  final ai = context.read<Assistant>();
  final ctrl = TextEditingController(text: ai.apiKey ?? '');
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('AI key'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The assistant uses Claude. Create a key at '
              'console.anthropic.com (API keys), add a small prepaid credit, '
              'and paste the key here. You pay only for what you use. The '
              'key stays on this device.',
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => openUri(
                Uri.parse('https://console.anthropic.com/settings/keys'),
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open the Claude console'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Key (starts with sk-ant-)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if ((ai.apiKey ?? '').isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Remove key'),
          ),
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
  if (v != null) await ai.setKey(v.isEmpty ? null : v);
}
