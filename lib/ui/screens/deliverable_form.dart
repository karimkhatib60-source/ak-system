import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';

Future<void> openDeliverableForm(BuildContext context,
    {Deliverable? deliverable, String? projectId}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          DeliverableForm(deliverable: deliverable, projectId: projectId),
    ),
  );
}

class DeliverableForm extends StatefulWidget {
  const DeliverableForm({super.key, this.deliverable, this.projectId});

  final Deliverable? deliverable;
  final String? projectId;

  @override
  State<DeliverableForm> createState() => _DeliverableFormState();
}

class _DeliverableFormState extends State<DeliverableForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _link;
  late final TextEditingController _notes;
  String? _projectId;
  String? _stageId;
  DateTime? _due;

  @override
  void initState() {
    super.initState();
    final d = widget.deliverable;
    final repo = context.read<Repository>();
    _title = TextEditingController(text: d?.title ?? '');
    _link = TextEditingController(text: d?.fileLink ?? '');
    _notes = TextEditingController(text: d?.notes ?? '');
    _projectId = d?.projectId ?? widget.projectId;
    _stageId = d?.stageId ?? repo.project(_projectId)?.stageId;
    _due = d?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// The deliverable as currently shown in the live repository, so status
  /// changes made on this screen are not lost when saving.
  Deliverable? get _current {
    final id = widget.deliverable?.id;
    if (id == null) return null;
    return context
        .read<Repository>()
        .deliverables
        .where((d) => d.id == id)
        .firstOrNull;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final d = _current;
    final now = repo.now();
    await repo.saveDeliverable(Deliverable(
      id: d?.id ?? repo.newId(),
      createdAt: d?.createdAt ?? now,
      updatedAt: now,
      projectId: _projectId!,
      title: _title.text.trim(),
      stageId: _stageId,
      version: d?.version ?? 1,
      status: d?.status ?? DeliverableStatus.draft,
      dueDate: _due,
      submittedAt: d?.submittedAt,
      approvedAt: d?.approvedAt,
      fileLink: _link.text.trim(),
      notes: _notes.text.trim(),
    ));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this deliverable')) return;
    if (!mounted) return;
    await context.read<Repository>().deleteDeliverable(widget.deliverable!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    final d = _current;
    final c = Theme.of(context).colorScheme;
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(d == null ? 'New deliverable' : 'Deliverable'),
        actions: [
          if (d != null)
            IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: const Text('Save')),
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
              if (d != null) ...[
                _Workflow(d: d),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _title,
                autofocus: d == null,
                decoration: const InputDecoration(
                    labelText: 'Deliverable',
                    hintText: 'e.g. Ground floor plan, Permit set'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the deliverable'
                    : null,
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final p in repo.visibleProjects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: d == null
                    ? (v) => setState(() => _projectId = v)
                    : null,
                validator: (v) => v == null ? 'Choose a project' : null,
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue:
                          repo.stage(_stageId) == null ? null : _stageId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Stage'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None')),
                        for (final s in repo.stages)
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _stageId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Due date',
                      value: _due,
                      onChanged: (v) => setState(() => _due = v),
                    ),
                  ),
                ],
              ),
              gap,
              TextFormField(
                controller: _link,
                decoration: InputDecoration(
                  labelText: 'File link',
                  hintText: 'Google Drive or OneDrive link to the files',
                  suffixIcon: IconButton(
                    tooltip: 'Copy link',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _link.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied')));
                    },
                  ),
                ),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                    labelText: 'Notes', hintText: 'Client comments, scope…'),
              ),
              if (d != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Revision ${d.revisionLabel}'
                  '${d.submittedAt != null ? ' · last sent ${fmtDate(d.submittedAt)}' : ''}'
                  '${d.approvedAt != null ? ' · approved ${fmtDate(d.approvedAt)}' : ''}',
                  style: TextStyle(color: c.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The submission workflow: draft → review → sent → approved, or back for
/// a new revision when the client asks for changes.
class _Workflow extends StatelessWidget {
  const _Workflow({required this.d});

  final Deliverable d;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<Repository>();
    final c = Theme.of(context).colorScheme;
    final actions = <Widget>[];
    void add(String label, IconData icon, VoidCallback onTap,
        {bool primary = false}) {
      actions.add(primary
          ? FilledButton.icon(
              onPressed: onTap, icon: Icon(icon), label: Text(label))
          : OutlinedButton.icon(
              onPressed: onTap, icon: Icon(icon), label: Text(label)));
    }

    switch (d.status) {
      case DeliverableStatus.draft:
        add('Ready for review', Icons.rate_review_outlined,
            () => repo.setDeliverableStatus(d, DeliverableStatus.internalReview));
        add('Send to client', Icons.send_outlined,
            () => repo.setDeliverableStatus(d, DeliverableStatus.submitted),
            primary: true);
      case DeliverableStatus.internalReview:
        add('Back to draft', Icons.undo,
            () => repo.setDeliverableStatus(d, DeliverableStatus.draft));
        add('Send to client', Icons.send_outlined,
            () => repo.setDeliverableStatus(d, DeliverableStatus.submitted),
            primary: true);
      case DeliverableStatus.submitted:
        add('Client asked for changes', Icons.edit_note,
            () => repo.setDeliverableStatus(d, DeliverableStatus.revise));
        add('Client approved', Icons.verified_outlined,
            () => repo.setDeliverableStatus(d, DeliverableStatus.approved),
            primary: true);
      case DeliverableStatus.revise:
        add('Start revision ${_next(d)}', Icons.restart_alt,
            () => repo.newRevision(d),
            primary: true);
      case DeliverableStatus.approved:
        add('Reopen as new revision', Icons.restart_alt,
            () => repo.newRevision(d));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${d.revisionLabel}  ',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Pill(deliverableStatusLabel(d.status),
                    color: deliverableStatusColor(d.status, c)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    );
  }

  String _next(Deliverable d) => 'R${d.version.toString().padLeft(2, '0')}';
}
