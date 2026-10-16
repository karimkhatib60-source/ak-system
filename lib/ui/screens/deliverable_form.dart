import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../widgets/common.dart';

Future<void> openDeliverableForm(
  BuildContext context, {
  Deliverable? deliverable,
  String? projectId,
}) {
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
  Discipline _discipline = Discipline.architecture;
  DocType _docType = DocType.drawing;
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
    _discipline = d?.discipline ?? Discipline.architecture;
    _docType = d?.docType ?? DocType.drawing;
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
    await repo.saveDeliverable(
      Deliverable(
        id: d?.id ?? repo.newId(),
        createdAt: d?.createdAt ?? now,
        updatedAt: now,
        projectId: _projectId!,
        title: _title.text.trim(),
        stageId: _stageId,
        discipline: _discipline,
        docType: _docType,
        number: _number(repo),
        version: d?.version ?? 1,
        status: d?.status ?? DeliverableStatus.draft,
        dueDate: _due,
        submittedAt: d?.submittedAt,
        approvedAt: d?.approvedAt,
        fileLink: _link.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  /// Keeps the existing number unless the discipline or type changed.
  int _number(Repository repo) {
    final d = _current;
    if (d != null &&
        d.discipline == _discipline &&
        d.docType == _docType &&
        d.projectId == _projectId) {
      return d.number;
    }
    if (_projectId == null) return 1;
    return repo.nextDocNumber(_projectId!, _discipline, _docType);
  }

  Future<void> _delete() async {
    if (!await confirmDelete(context, 'this deliverable'.tr)) return;
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
        title: Text(d == null ? 'New deliverable'.tr : 'Deliverable'.tr),
        actions: [
          if (d != null)
            IconButton(
              tooltip: 'Delete'.tr,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
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
              if (d != null) ...[_Workflow(d: d), const SizedBox(height: 20)],
              TextFormField(
                controller: _title,
                autofocus: d == null,
                decoration: InputDecoration(
                  labelText: 'Deliverable'.tr,
                  hintText: 'e.g. Ground floor plan, Permit set'.tr,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Enter the deliverable'.tr
                    : null,
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Discipline>(
                      initialValue: _discipline,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Discipline'.tr),
                      items: [
                        for (final x in Discipline.values)
                          DropdownMenuItem(
                            value: x,
                            child: Text('${x.code} · ${disciplineLabel(x)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _discipline = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<DocType>(
                      initialValue: _docType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Document type'.tr,
                      ),
                      items: [
                        for (final x in DocType.values)
                          DropdownMenuItem(
                            value: x,
                            child: Text('${x.code} · ${docTypeLabel(x)}'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _docType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final code = Deliverable(
                    id: '',
                    createdAt: DateTime(2000),
                    updatedAt: DateTime(2000),
                    projectId: _projectId ?? '',
                    title: '',
                    discipline: _discipline,
                    docType: _docType,
                    number: _number(repo),
                  ).docCode(repo.project(_projectId)?.code ?? '');
                  return Text(
                    'Document number: {0}'.trArgs([code]),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: c.onSurfaceVariant,
                    ),
                  );
                },
              ),
              gap,
              DropdownButtonFormField<String>(
                initialValue: _projectId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Project'.tr),
                items: [
                  for (final p in repo.visibleProjects)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: d == null
                    ? (v) => setState(() {
                        _projectId = v;
                        _stageId = repo.project(v)?.stageId;
                      })
                    : null,
                validator: (v) => v == null ? 'Choose a project'.tr : null,
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(_projectId),
                      initialValue:
                          repo.stagesOf(_projectId).any((s) => s.id == _stageId)
                          ? _stageId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Stage'.tr),
                      items: [
                        DropdownMenuItem(value: null, child: Text('None'.tr)),
                        for (final s in repo.stagesOf(_projectId))
                          DropdownMenuItem(value: s.id, child: Text(s.name.tr)),
                      ],
                      onChanged: (v) => setState(() => _stageId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Due date'.tr,
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
                  labelText: 'File link'.tr,
                  hintText: 'Google Drive or OneDrive link to the files'.tr,
                  suffixIcon: IconButton(
                    tooltip: 'Copy link'.tr,
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _link.text));
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Link copied'.tr)));
                    },
                  ),
                ),
              ),
              gap,
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: 'Notes'.tr,
                  hintText: 'Client comments, scope…'.tr,
                ),
              ),
              if (d != null) ...[
                const SizedBox(height: 20),
                Text(
                  'Revision {0}'.trArgs([d.revisionLabel]) +
                      (d.submittedAt != null
                          ? ' · last sent {0}'.trArgs([fmtDate(d.submittedAt)])
                          : '') +
                      (d.approvedAt != null
                          ? ' · approved {0}'.trArgs([fmtDate(d.approvedAt)])
                          : ''),
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
    void add(
      String label,
      IconData icon,
      VoidCallback onTap, {
      bool primary = false,
    }) {
      actions.add(
        primary
            ? FilledButton.icon(
                onPressed: onTap,
                icon: Icon(icon),
                label: Text(label),
              )
            : OutlinedButton.icon(
                onPressed: onTap,
                icon: Icon(icon),
                label: Text(label),
              ),
      );
    }

    switch (d.status) {
      case DeliverableStatus.draft:
        add(
          'Ready for review'.tr,
          Icons.rate_review_outlined,
          () => repo.setDeliverableStatus(d, DeliverableStatus.internalReview),
        );
        add(
          'Send to client'.tr,
          Icons.send_outlined,
          () => repo.setDeliverableStatus(d, DeliverableStatus.submitted),
          primary: true,
        );
      case DeliverableStatus.internalReview:
        add(
          'Back to draft'.tr,
          Icons.undo,
          () => repo.setDeliverableStatus(d, DeliverableStatus.draft),
        );
        add(
          'Send to client'.tr,
          Icons.send_outlined,
          () => repo.setDeliverableStatus(d, DeliverableStatus.submitted),
          primary: true,
        );
      case DeliverableStatus.submitted:
        add(
          'Client asked for changes'.tr,
          Icons.edit_note,
          () => repo.setDeliverableStatus(d, DeliverableStatus.revise),
        );
        add(
          'Client approved'.tr,
          Icons.verified_outlined,
          () => repo.setDeliverableStatus(d, DeliverableStatus.approved),
          primary: true,
        );
      case DeliverableStatus.revise:
        add(
          'Start revision {0}'.trArgs([_next(d)]),
          Icons.restart_alt,
          () => repo.newRevision(d),
          primary: true,
        );
      case DeliverableStatus.approved:
        add(
          'Reopen as new revision'.tr,
          Icons.restart_alt,
          () => repo.newRevision(d),
        );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${d.revisionLabel}  ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Pill(
                  deliverableStatusLabel(d.status),
                  color: deliverableStatusColor(d.status, c),
                ),
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
