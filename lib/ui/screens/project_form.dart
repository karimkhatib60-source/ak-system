import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models.dart';
import '../../data/repository.dart';
import '../format.dart';
import '../maps.dart';
import '../widgets/common.dart';
import 'client_form.dart';

Future<void> openProjectForm(
  BuildContext context, {
  Project? project,
  String? clientId,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ProjectForm(project: project, clientId: clientId),
    ),
  );
}

class ProjectForm extends StatefulWidget {
  const ProjectForm({super.key, this.project, this.clientId});

  final Project? project;
  final String? clientId;

  @override
  State<ProjectForm> createState() => _ProjectFormState();
}

class _ProjectFormState extends State<ProjectForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late final TextEditingController _area;
  late final TextEditingController _mapLink;
  late final TextEditingController _fee;
  ProjectType _type = ProjectType.residential;
  String? _clientId;
  String? _stageId;
  ServiceType _service = ServiceType.design;
  ProjectStatus _status = ProjectStatus.active;
  bool _abroad = false;
  DateTime? _start;
  DateTime? _due;
  Set<String> _team = {};

  @override
  void initState() {
    super.initState();
    final repo = context.read<Repository>();
    final p = widget.project;
    _code = TextEditingController(text: p?.code ?? repo.nextProjectCode());
    _name = TextEditingController(text: p?.name ?? '');
    _location = TextEditingController(text: p?.location ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _clientId = p?.clientId ?? widget.clientId;
    _service = p?.service ?? ServiceType.design;
    _stageId = p?.stageId ?? repo.stagesFor(_service).firstOrNull?.id;
    _mapLink = TextEditingController(text: p?.mapLink ?? '');
    _status = p?.status ?? ProjectStatus.active;
    _abroad = p?.abroad ?? false;
    _start = p?.startDate ?? (p == null ? repo.now() : null);
    _due = p?.dueDate;
    _team = {...?p?.teamIds};
    _type = p?.type ?? ProjectType.residential;
    final f = p?.markupRate;
    _fee = TextEditingController(text: f == null ? '' : _plain(f));
    final a = p?.areaSqm;
    _area = TextEditingController(
      text: a == null
          ? ''
          : (a == a.roundToDouble() ? a.toStringAsFixed(0) : '$a'),
    );
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _location.dispose();
    _area.dispose();
    _mapLink.dispose();
    _fee.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<Repository>();
    final p = widget.project;
    final now = repo.now();
    // Outside Lebanon AK only does consultancy.
    final service = _abroad ? ServiceType.consultancy : _service;
    await repo.saveProject(
      Project(
        id: p?.id ?? repo.newId(),
        createdAt: p?.createdAt ?? now,
        updatedAt: now,
        code: _code.text.trim(),
        name: _name.text.trim(),
        clientId: _clientId,
        service: service,
        location: _location.text.trim(),
        abroad: _abroad,
        stageId: _stageId,
        status: _status,
        startDate: _start,
        dueDate: _due,
        teamIds: _team.toList()..sort(),
        type: _type,
        areaSqm: double.tryParse(_area.text.replaceAll(',', '').trim()),
        mapLink: _mapLink.text.trim(),
        markupRate: repo.isOwner
            ? double.tryParse(_fee.text.replaceAll('%', '').trim())
            : p?.markupRate,
        notes: _notes.text.trim(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  ServiceType get _effectiveService =>
      _abroad ? ServiceType.consultancy : _service;

  /// Keeps the stage when it belongs to the chosen service, otherwise moves
  /// to that service's first stage.
  void _fitStage(Repository repo) {
    final list = repo.stagesFor(_effectiveService);
    if (!list.any((s) => s.id == _stageId)) _stageId = list.firstOrNull?.id;
  }

  Future<void> _newClient() async {
    final id = await openClientForm(context);
    if (id != null) setState(() => _clientId = id);
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<Repository>();
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project == null ? 'New project' : 'Edit project'),
        actions: [
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
              Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(labelText: 'Code'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _name,
                      autofocus: widget.project == null,
                      decoration: const InputDecoration(
                        labelText: 'Project name',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a name' : null,
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: repo.client(_clientId) == null
                          ? null
                          : _clientId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Client'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No client yet'),
                        ),
                        for (final c in repo.clients)
                          DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => setState(() => _clientId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: 'New client',
                    onPressed: _newClient,
                    icon: const Icon(Icons.person_add_alt),
                  ),
                ],
              ),
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Outside Lebanon'),
                subtitle: const Text('Consultancy only'),
                value: _abroad,
                onChanged: (v) => setState(() {
                  _abroad = v;
                  if (v) _service = ServiceType.consultancy;
                  _fitStage(repo);
                }),
              ),
              SegmentedButton<ServiceType>(
                showSelectedIcon: false,
                segments: [
                  for (final s in ServiceType.values)
                    ButtonSegment(
                      value: s,
                      label: Text(serviceLabel(s)),
                      enabled: !_abroad || s == ServiceType.consultancy,
                    ),
                ],
                selected: {_service},
                onSelectionChanged: (v) => setState(() {
                  _service = v.first;
                  _fitStage(repo);
                }),
              ),
              gap,
              DropdownButtonFormField<ProjectType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Project type'),
                items: [
                  for (final t in ProjectType.values)
                    DropdownMenuItem(
                      value: t,
                      child: Text(projectTypeLabel(t)),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'City, area or country',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Area',
                        suffixText: 'm²',
                      ),
                      validator: (v) =>
                          v == null ||
                              v.trim().isEmpty ||
                              double.tryParse(v.replaceAll(',', '').trim()) !=
                                  null
                          ? null
                          : 'Numbers only',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mapLink,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Google Maps link',
                  hintText: 'Paste the pin link from Google Maps',
                  prefixIcon: const Icon(Icons.place_outlined),
                  suffixIcon: IconButton(
                    tooltip: 'Find on Google Maps',
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => openUri(
                      _mapLink.text.trim().isNotEmpty
                          ? Uri.parse(
                              _mapLink.text.trim().startsWith('http')
                                  ? _mapLink.text.trim()
                                  : 'https://${_mapLink.text.trim()}',
                            )
                          : mapSearchUri(
                              _location.text.trim().isEmpty
                                  ? 'Lebanon'
                                  : _location.text,
                            ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  'Tap the map button, drop a pin on the site, press Share, '
                  'copy the link and paste it here.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (repo.isOwner) ...[
                gap,
                TextFormField(
                  controller: _fee,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cost-plus fee',
                    hintText: 'For example 15',
                    suffixText: '%',
                    prefixIcon: Icon(Icons.percent),
                    helperText:
                        'Added on top of cost in this project\'s quotations '
                        'and invoices.',
                  ),
                  validator: (v) =>
                      v == null ||
                          v.trim().isEmpty ||
                          double.tryParse(v.replaceAll('%', '').trim()) != null
                      ? null
                      : 'Numbers only',
                ),
              ],
              gap,
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      key: ValueKey(_effectiveService),
                      initialValue:
                          repo
                              .stagesFor(_effectiveService)
                              .any((s) => s.id == _stageId)
                          ? _stageId
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText:
                            'Current stage (${serviceLabel(_effectiveService).toLowerCase()})',
                      ),
                      items: [
                        for (final s in repo.stagesFor(_effectiveService))
                          DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ],
                      onChanged: (v) => setState(() => _stageId = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ProjectStatus>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s in ProjectStatus.values)
                          DropdownMenuItem(
                            value: s,
                            child: Text(projectStatusLabel(s)),
                          ),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: DateField(
                      label: 'Start date',
                      value: _start,
                      onChanged: (d) => setState(() => _start = d),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DateField(
                      label: 'Deadline',
                      value: _due,
                      onChanged: (d) => setState(() => _due = d),
                    ),
                  ),
                ],
              ),
              if (repo.members.isNotEmpty) ...[
                gap,
                Text(
                  'Team on this project',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in repo.members)
                      FilterChip(
                        label: Text(m.name),
                        selected: _team.contains(m.id),
                        onSelected: (v) => setState(
                          () => v ? _team.add(m.id) : _team.remove(m.id),
                        ),
                      ),
                  ],
                ),
              ],
              gap,
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
