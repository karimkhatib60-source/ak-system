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

/// A project's notes, pinned ones first, then the newest; they can be
/// narrowed to one kind or searched.
class ProjectNotesTab extends StatefulWidget {
  const ProjectNotesTab({super.key, required this.project});

  final Project project;

  @override
  State<ProjectNotesTab> createState() => _ProjectNotesTabState();
}

class _ProjectNotesTabState extends State<ProjectNotesTab> {
  NoteKind? _kind;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final all = repo.notesFor(widget.project.id);
    final kinds = {for (final n in all) n.kind};
    // A kind with no notes left is no longer offered.
    final kind = kinds.contains(_kind) ? _kind : null;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final n in all)
        if ((kind == null || n.kind == kind) &&
            (q.isEmpty || n.text.toLowerCase().contains(q)))
          n,
    ];
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-note',
        onPressed: () =>
            openNoteForm(context, projectId: widget.project.id, kind: kind),
        icon: const Icon(Icons.add),
        label: Text('Note'.tr),
      ),
      body: all.isEmpty
          ? EmptyState(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet'.tr,
              message:
                  'Meeting minutes, site visits, client requests and '
                          'decisions, each with its date.'
                      .tr,
            )
          : Readable(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                children: [
                  if (all.length > 4) ...[
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search notes'.tr,
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _query = v),
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
                          selected: kind == null,
                          onSelected: (_) => setState(() => _kind = null),
                        ),
                        for (final k in NoteKind.values)
                          if (kinds.contains(k))
                            ChoiceChip(
                              avatar: Icon(noteKindIcon(k), size: 16),
                              label: Text(noteKindLabel(k)),
                              selected: kind == k,
                              onSelected: (_) => setState(() => _kind = k),
                            ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (shown.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No notes match.'.tr,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final n in shown) NoteCard(n),
                ],
              ),
            ),
    );
  }
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
              // Each part reads in the language it was typed in.
              SizedBox(
                width: double.infinity,
                child: Text(
                  note.heading,
                  textDirection: directionOf(note.heading),
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    note.body,
                    textDirection: directionOf(note.body),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium,
                  ),
                ),
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

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    final now = context.read<Repository>().now();
    _text = TextEditingController(text: n?.text ?? '')
      ..addListener(_followDirection);
    _date = n?.date ?? DateTime(now.year, now.month, now.day);
    _kind = n?.kind ?? widget.kind ?? NoteKind.general;
    _pinned = n?.pinned ?? false;
    _ownerOnly = n?.ownerOnly ?? false;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  TextDirection? _direction;

  /// The note's field reads the way its text was typed.
  void _followDirection() {
    final d = directionOf(_text.text);
    if (d != null && d != _direction) setState(() => _direction = d);
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

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final n = widget.note;
    final canEdit = n == null || repo.canEditNote(n);
    final project = repo.project(n?.projectId ?? widget.projectId);
    final author = repo.member(n?.authorId)?.name;
    final c = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    return Scaffold(
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
                  [project.code, project.name]
                      .where((s) => s.isNotEmpty)
                      .dots(),
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
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Write the note'.tr : null,
              ),
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.push_pin_outlined),
                title: Text('Pin to the top'.tr),
                value: _pinned,
                onChanged: canEdit ? (v) => setState(() => _pinned = v) : null,
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
                    'Last changed {0}'.trArgs([fmtDate(n.updatedAt.toLocal())]),
                  ].dots(),
                  style: TextStyle(color: c.onSurfaceVariant, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
