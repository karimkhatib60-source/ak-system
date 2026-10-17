import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';

Future<void> openNoteForm(
  BuildContext context, {
  ProjectNote? note,
  String? projectId,
  NoteKind? kind,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => NoteForm(note: note, projectId: projectId, kind: kind),
    ),
  );
}

/// Text for searching: lower case, and Arabic letters people type in more
/// than one way (with or without hamza, ة or ه, ى or ي) made the same,
/// without vowel marks or the stretching dash.
String searchable(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[ً-ْٰـ]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي');

/// [text] with each paragraph set in the direction it was typed in, so
/// Arabic and English lines in one note both read right.
class DirectedText extends StatelessWidget {
  const DirectedText(this.text, {super.key, this.style, this.maxLines});

  final String text;
  final TextStyle? style;

  /// At most this many lines in all; the rest is cut with "…".
  final int? maxLines;

  Widget _line(String p, int? lines) => SizedBox(
    width: double.infinity,
    child: Text(
      p,
      textDirection: directionOf(p),
      style: style,
      maxLines: lines,
      overflow: lines == null ? null : TextOverflow.ellipsis,
    ),
  );

  Widget _column(List<Widget> children) => children.length == 1
      ? children.single
      : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );

  @override
  Widget build(BuildContext context) {
    final paragraphs = text.split('\n');
    final max = maxLines;
    if (max == null) {
      return _column([for (final p in paragraphs) _line(p, null)]);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final base = DefaultTextStyle.of(context).style.merge(style);
        final scaler = MediaQuery.textScalerOf(context);
        final ambient = Directionality.of(context);
        final children = <Widget>[];
        var left = max;
        for (final p in paragraphs) {
          if (left <= 0) break;
          children.add(_line(p, left));
          // How many lines this paragraph takes at this width.
          final painter = TextPainter(
            text: TextSpan(text: p.isEmpty ? ' ' : p, style: base),
            textDirection: directionOf(p) ?? ambient,
            textScaler: scaler,
            maxLines: left,
          )..layout(maxWidth: box.maxWidth);
          final used = painter.computeLineMetrics().length;
          painter.dispose();
          left -= used < 1 ? 1 : used;
        }
        return _column(children);
      },
    );
  }
}

/// A project's notes: its key points, then the dated notes, pinned ones
/// first, then the newest; they can be narrowed to one kind or searched.
class ProjectNotesTab extends StatefulWidget {
  const ProjectNotesTab({super.key, required this.project});

  final Project project;

  @override
  State<ProjectNotesTab> createState() => _ProjectNotesTabState();
}

class _ProjectNotesTabState extends State<ProjectNotesTab> {
  final _search = TextEditingController();
  NoteKind? _kind;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final p = repo.project(widget.project.id) ?? widget.project;
    final all = repo.notesFor(p.id);
    final kinds = {for (final n in all) n.kind};
    // A kind with no notes left is no longer offered, nor chosen.
    if (!kinds.contains(_kind)) _kind = null;
    final q = searchable(_search.text.trim());
    final shown = [
      for (final n in all)
        if ((_kind == null || n.kind == _kind) &&
            (q.isEmpty || searchable(n.text).contains(q)))
          n,
    ];
    final keyPoints = p.notes.trim();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-note',
        onPressed: () => openNoteForm(context, projectId: p.id, kind: _kind),
        icon: const Icon(Icons.add),
        label: Text('Note'.tr),
      ),
      body: Readable(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
          children: [
            if (keyPoints.isNotEmpty)
              _KeyPoints(project: p)
            else if (repo.isOwner)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => editKeyPoints(context, p),
                  icon: const Icon(Icons.star_outline),
                  label: Text('Add key points'.tr),
                ),
              ),
            const SizedBox(height: 8),
            if (all.isEmpty)
              EmptyState(
                icon: Icons.sticky_note_2_outlined,
                title: 'No notes yet'.tr,
                message:
                    'Meeting minutes, site visits, client requests and '
                            'decisions, each with its date.'
                        .tr,
              )
            else ...[
              if (all.length > 4 || _search.text.isNotEmpty) ...[
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search notes'.tr,
                    isDense: true,
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear'.tr,
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
              ],
              if (kinds.length > 1) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All@@notes'.tr),
                      selected: _kind == null,
                      onSelected: (_) => setState(() => _kind = null),
                    ),
                    for (final k in NoteKind.values)
                      if (kinds.contains(k))
                        ChoiceChip(
                          avatar: Icon(noteKindIcon(k), size: 16),
                          label: Text(noteKindLabel(k)),
                          selected: _kind == k,
                          onSelected: (_) => setState(() => _kind = k),
                        ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('No notes match.'.tr, textAlign: TextAlign.center),
                ),
              for (final n in shown) NoteCard(n),
            ],
          ],
        ),
      ),
    );
  }
}

/// The project's key points: the essentials that stay true, kept apart
/// from the dated notes. Only the owner changes them.
class _KeyPoints extends StatelessWidget {
  const _KeyPoints({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: repo.isOwner ? () => editKeyPoints(context, project) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.star, size: 16, color: c.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Key points'.tr,
                      style: TextStyle(
                        color: c.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (repo.isOwner)
                    Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: c.onSurfaceVariant,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              DirectedText(project.notes.trim()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Changes a project's key points.
Future<void> editKeyPoints(BuildContext context, Project p) async {
  final repo = context.read<Repository>();
  final value = await showDialog<String>(
    context: context,
    builder: (_) => _KeyPointsDialog(text: p.notes.trim()),
  );
  if (value == null) return;
  // Saved on the project as it is now, so nothing else on it goes back.
  final now = repo.project(p.id) ?? p;
  if (value == now.notes.trim()) return;
  await repo.saveProject(now.copyWith(notes: value));
}

class _KeyPointsDialog extends StatefulWidget {
  const _KeyPointsDialog({required this.text});

  final String text;

  @override
  State<_KeyPointsDialog> createState() => _KeyPointsDialogState();
}

class _KeyPointsDialogState extends State<_KeyPointsDialog> {
  late final _text = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Key points'.tr),
    content: SizedBox(
      width: 520,
      child: TextField(
        controller: _text,
        autofocus: true,
        minLines: 4,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        textDirection: directionOf(_text.text),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText:
              'What always holds for this project: the client\'s wishes, '
                      'budget, access, materials.'
                  .tr,
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'.tr),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _text.text.trim()),
        child: Text('Save'.tr),
      ),
    ],
  );
}

/// One note in a project's list: its kind, day and first lines.
class NoteCard extends StatelessWidget {
  const NoteCard(this.note, {super.key});

  final ProjectNote note;

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final author = repo.member(note.authorId)?.name;
    final muted = TextStyle(color: c.onSurfaceVariant, fontSize: 12.5);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => openNoteForm(context, note: note),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(noteKindIcon(note.kind), size: 16, color: c.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      noteKindLabel(note.kind),
                      style: muted.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (note.ownerOnly)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Tooltip(
                        message: 'Only you'.tr,
                        child: Icon(
                          Icons.lock_outline,
                          size: 15,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (note.pinned)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Tooltip(
                        message: 'Pinned'.tr,
                        child: Icon(Icons.push_pin, size: 15, color: c.primary),
                      ),
                    ),
                  Text(fmtDate(note.date), style: muted),
                ],
              ),
              const SizedBox(height: 6),
              DirectedText(
                note.heading,
                maxLines: 2,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                DirectedText(note.body, maxLines: 6, style: t.bodyMedium),
              ],
              if (author != null && repo.members.length > 1) ...[
                const SizedBox(height: 6),
                Text('By {0}'.trArgs([author]), style: muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class NoteForm extends StatefulWidget {
  const NoteForm({super.key, this.note, this.projectId, this.kind});

  final ProjectNote? note;
  final String? projectId;

  /// The kind a new note starts with.
  final NoteKind? kind;

  @override
  State<NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<NoteForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  late DateTime _date;
  late NoteKind _kind;
  late bool _pinned;
  late bool _ownerOnly;

  /// What the form held when it opened, to tell whether anything changed.
  late final String _start;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    final now = context.read<Repository>().now();
    _text = TextEditingController(text: n?.text ?? '')
      ..addListener(_changed);
    _date = n?.date ?? DateTime(now.year, now.month, now.day);
    _kind = n?.kind ?? widget.kind ?? NoteKind.general;
    _pinned = n?.pinned ?? false;
    _ownerOnly = n?.ownerOnly ?? false;
    _start = _state;
  }

  String get _state =>
      [_text.text.trim(), _date, _kind, _pinned, _ownerOnly].join('|');

  bool get _dirty => _state != _start;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  TextDirection? _direction;

  /// Follows what was typed: the field reads the way its text was typed,
  /// and closing it asks first once something changed.
  void _changed() {
    final d = directionOf(_text.text);
    setState(() {
      if (d != null) _direction = d;
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final n = widget.note;
    final now = repo.now();
    await repo.saveNote(
      ProjectNote(
        id: n?.id ?? repo.newId(),
        createdAt: n?.createdAt ?? now,
        updatedAt: now,
        projectId: n?.projectId ?? widget.projectId!,
        date: _date,
        kind: _kind,
        text: _text.text.trim(),
        authorId: n == null ? repo.currentMemberId : n.authorId,
        pinned: _pinned,
        ownerOnly: repo.isOwner && _ownerOnly,
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this note'.tr)) return;
    if (!mounted) return;
    await context.read<Repository>().deleteNote(widget.note!);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _text.text.trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Copied'.tr)));
  }

  /// Asked before closing a note with changes that are not saved.
  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Discard your changes?'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep editing'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard'.tr),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final n = widget.note;
    final canEdit = n == null || repo.canEditNote(n);
    final project = repo.project(n?.projectId ?? widget.projectId);
    final author = repo.member(n?.authorId)?.name;
    final c = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    return PopScope(
      canPop: !canEdit || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(n == null ? 'New note'.tr : 'Edit note'.tr),
          actions: [
            if (n != null)
              IconButton(
                tooltip: 'Copy'.tr,
                icon: const Icon(Icons.copy_outlined),
                onPressed: _copy,
              ),
            if (n != null && canEdit)
              IconButton(
                tooltip: 'Delete'.tr,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
            if (canEdit)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: FilledButton(onPressed: _save, child: Text('Save'.tr)),
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
                if (project != null) ...[
                  Text(
                    [
                      project.code,
                      project.name,
                    ].where((s) => s.isNotEmpty).dots(),
                    style: TextStyle(color: c.onSurfaceVariant),
                  ),
                  gap,
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final k in NoteKind.values)
                      ChoiceChip(
                        avatar: Icon(noteKindIcon(k), size: 16),
                        label: Text(noteKindLabel(k)),
                        selected: _kind == k,
                        onSelected: canEdit
                            ? (_) => setState(() => _kind = k)
                            : null,
                      ),
                  ],
                ),
                gap,
                DateField(
                  label: 'Date'.tr,
                  value: _date,
                  onChanged: canEdit
                      ? (d) => setState(() {
                          final now = repo.now();
                          _date = d ?? DateTime(now.year, now.month, now.day);
                        })
                      : (_) {},
                ),
                gap,
                TextFormField(
                  controller: _text,
                  readOnly: !canEdit,
                  autofocus: n == null,
                  textDirection: _direction ?? directionOf(_text.text),
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Note'.tr,
                    hintText: 'The first line is the title of the note.'.tr,
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Write the note'.tr
                      : null,
                ),
                gap,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.push_pin_outlined),
                  title: Text('Pin to the top'.tr),
                  value: _pinned,
                  onChanged: canEdit
                      ? (v) => setState(() => _pinned = v)
                      : null,
                ),
                if (repo.isOwner)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.lock_outline),
                    title: Text('Only me'.tr),
                    subtitle: Text('Your team never sees this note.'.tr),
                    value: _ownerOnly,
                    onChanged: (v) => setState(() => _ownerOnly = v),
                  ),
                if (n != null) ...[
                  gap,
                  Text(
                    [
                      if (author != null) 'Written by {0}'.trArgs([author]),
                      'Last changed {0}'.trArgs([
                        fmtDate(n.updatedAt.toLocal()),
                      ]),
                    ].dots(),
                    style: TextStyle(color: c.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
