import 'dart:convert';

part 'finance.dart';

// Data records for Phase 1. Every record carries the same sync columns
// (id, created_at, updated_at, deleted) so the sync service can treat all
// tables alike.

enum ServiceType { design, consultancy, contracting }

enum ProjectStatus { lead, active, onHold, completed, cancelled }

enum TaskStatus { todo, inProgress, done }

enum TaskPriority { low, normal, high }

enum DeliverableStatus { draft, internalReview, submitted, approved, revise }

enum MemberRole { owner, architect }

enum ProjectType {
  residential,
  commercial,
  hospitality,
  interior,
  mixedUse,
  industrial,
  landscape,
  other,
}

enum TaskCategory { design, drawings, siteVisit, meeting, coordination, admin }

/// Discipline codes used in document numbers, e.g. ARC.
enum Discipline {
  architecture('ARC'),
  interior('INT'),
  structure('STR'),
  mep('MEP'),
  landscape('LAN'),
  general('GEN');

  const Discipline(this.code);
  final String code;
}

/// Document type codes used in document numbers, e.g. DWG.
enum DocType {
  drawing('DWG'),
  report('RPT'),
  presentation('PRS'),
  model('MOD'),
  boq('BOQ'),
  specification('SPC'),
  letter('LTR');

  const DocType(this.code);
  final String code;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

DateTime? _date(Object? v) =>
    v == null || v == '' ? null : DateTime.tryParse(v as String);

String? _dateStr(DateTime? d) => d?.toIso8601String();

/// Fields shared by every synced record.
abstract class Record {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  bool get deleted;
  Map<String, Object?> toMap();
}

Map<String, Object?> _base(Record r) => {
  'id': r.id,
  'created_at': r.createdAt.toUtc().toIso8601String(),
  'updated_at': r.updatedAt.toUtc().toIso8601String(),
  'deleted': r.deleted ? 1 : 0,
};

class Client implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String name;
  final String company;
  final String phone;
  final String email;
  final String country;
  final String notes;

  const Client({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.name,
    this.company = '',
    this.phone = '',
    this.email = '',
    this.country = 'Lebanon',
    this.notes = '',
  });

  factory Client.fromMap(Map<String, Object?> m) => Client(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    name: (m['name'] ?? '') as String,
    company: (m['company'] ?? '') as String,
    phone: (m['phone'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    country: (m['country'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'name': name,
    'company': company,
    'phone': phone,
    'email': email,
    'country': country,
    'notes': notes,
  };

  Client copyWith({
    String? name,
    String? company,
    String? phone,
    String? email,
    String? country,
    String? notes,
    bool? deleted,
    DateTime? updatedAt,
  }) => Client(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    company: company ?? this.company,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    country: country ?? this.country,
    notes: notes ?? this.notes,
  );
}

class Project implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String code;
  final String name;
  final String? clientId;
  final ServiceType service;
  final String location;
  final bool abroad;
  final String? stageId;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? dueDate;
  final List<String> teamIds;
  final String notes;
  final ProjectType type;

  /// Built-up area in square metres.
  final double? areaSqm;

  /// Google Maps link to the site.
  final String mapLink;

  /// Cost-plus percentage agreed for this project, used on its quotations.
  final double? markupRate;

  const Project({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.code = '',
    required this.name,
    this.clientId,
    this.service = ServiceType.design,
    this.location = '',
    this.abroad = false,
    this.stageId,
    this.status = ProjectStatus.active,
    this.startDate,
    this.dueDate,
    this.teamIds = const [],
    this.notes = '',
    this.type = ProjectType.residential,
    this.areaSqm,
    this.mapLink = '',
    this.markupRate,
  });

  factory Project.fromMap(Map<String, Object?> m) => Project(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    code: (m['code'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    clientId: m['client_id'] as String?,
    service: _enumByName(ServiceType.values, m['service'], ServiceType.design),
    location: (m['location'] ?? '') as String,
    abroad: m['abroad'] == 1 || m['abroad'] == true,
    stageId: m['stage_id'] as String?,
    status: _enumByName(
      ProjectStatus.values,
      m['status'],
      ProjectStatus.active,
    ),
    startDate: _date(m['start_date']),
    dueDate: _date(m['due_date']),
    teamIds: _splitIds(m['team_ids']),
    notes: (m['notes'] ?? '') as String,
    type: _enumByName(
      ProjectType.values,
      m['project_type'],
      ProjectType.residential,
    ),
    areaSqm: (m['area_sqm'] as num?)?.toDouble(),
    mapLink: (m['map_link'] ?? '') as String,
    markupRate: (m['markup_rate'] as num?)?.toDouble(),
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'code': code,
    'name': name,
    'client_id': clientId,
    'service': service.name,
    'location': location,
    'abroad': abroad ? 1 : 0,
    'stage_id': stageId,
    'status': status.name,
    'start_date': _dateStr(startDate),
    'due_date': _dateStr(dueDate),
    'team_ids': teamIds.join(','),
    'notes': notes,
    'project_type': type.name,
    'area_sqm': areaSqm,
    'map_link': mapLink,
    'markup_rate': markupRate,
  };

  Project copyWith({
    String? code,
    String? name,
    String? clientId,
    ServiceType? service,
    String? location,
    bool? abroad,
    String? stageId,
    ProjectStatus? status,
    DateTime? startDate,
    DateTime? dueDate,
    List<String>? teamIds,
    String? notes,
    bool? deleted,
    DateTime? updatedAt,
    double? markupRate,
  }) => Project(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    code: code ?? this.code,
    name: name ?? this.name,
    clientId: clientId ?? this.clientId,
    service: service ?? this.service,
    location: location ?? this.location,
    abroad: abroad ?? this.abroad,
    stageId: stageId ?? this.stageId,
    status: status ?? this.status,
    startDate: startDate ?? this.startDate,
    dueDate: dueDate ?? this.dueDate,
    teamIds: teamIds ?? this.teamIds,
    notes: notes ?? this.notes,
    type: type,
    areaSqm: areaSqm,
    mapLink: mapLink,
    markupRate: markupRate ?? this.markupRate,
  );
}

List<String> _splitIds(Object? v) {
  if (v == null) return const [];
  if (v is List) return v.map((e) => e.toString()).toList();
  final s = v as String;
  return s.isEmpty ? const [] : s.split(',');
}

class Task implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String projectId;
  final String title;
  final String? assigneeId;
  final DateTime? dueDate;
  final TaskStatus status;
  final TaskPriority priority;
  final String? stageId;
  final String notes;
  final TaskCategory category;

  const Task({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.projectId,
    required this.title,
    this.assigneeId,
    this.dueDate,
    this.status = TaskStatus.todo,
    this.priority = TaskPriority.normal,
    this.stageId,
    this.notes = '',
    this.category = TaskCategory.design,
  });

  bool isOverdue(DateTime now) =>
      status != TaskStatus.done &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(now.year, now.month, now.day));

  factory Task.fromMap(Map<String, Object?> m) => Task(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    projectId: m['project_id'] as String,
    title: (m['title'] ?? '') as String,
    assigneeId: m['assignee_id'] as String?,
    dueDate: _date(m['due_date']),
    status: _enumByName(TaskStatus.values, m['status'], TaskStatus.todo),
    priority: _enumByName(
      TaskPriority.values,
      m['priority'],
      TaskPriority.normal,
    ),
    stageId: m['stage_id'] as String?,
    notes: (m['notes'] ?? '') as String,
    category: _enumByName(
      TaskCategory.values,
      m['category'],
      TaskCategory.design,
    ),
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'project_id': projectId,
    'title': title,
    'assignee_id': assigneeId,
    'due_date': _dateStr(dueDate),
    'status': status.name,
    'priority': priority.name,
    'stage_id': stageId,
    'notes': notes,
    'category': category.name,
  };

  Task copyWith({
    String? projectId,
    String? title,
    String? assigneeId,
    DateTime? dueDate,
    TaskStatus? status,
    TaskPriority? priority,
    String? stageId,
    String? notes,
    bool? deleted,
    DateTime? updatedAt,
  }) => Task(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    projectId: projectId ?? this.projectId,
    title: title ?? this.title,
    assigneeId: assigneeId ?? this.assigneeId,
    dueDate: dueDate ?? this.dueDate,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    stageId: stageId ?? this.stageId,
    notes: notes ?? this.notes,
    category: category,
  );
}

class Deliverable implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String projectId;
  final String title;
  final String? stageId;
  final int version;
  final DeliverableStatus status;
  final DateTime? dueDate;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final String fileLink;
  final String notes;
  final Discipline discipline;
  final DocType docType;

  /// Running number within the project, discipline and type.
  final int number;

  const Deliverable({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.projectId,
    required this.title,
    this.stageId,
    this.version = 1,
    this.status = DeliverableStatus.draft,
    this.dueDate,
    this.submittedAt,
    this.approvedAt,
    this.fileLink = '',
    this.notes = '',
    this.discipline = Discipline.architecture,
    this.docType = DocType.drawing,
    this.number = 1,
  });

  /// Document number, e.g. AK-26-001-ARC-DWG-003.
  String docCode(String projectCode) => [
    if (projectCode.isNotEmpty) projectCode,
    discipline.code,
    docType.code,
    number.toString().padLeft(3, '0'),
  ].join('-');

  /// Revision label used on submissions: R00, R01, ...
  String get revisionLabel => 'R${(version - 1).toString().padLeft(2, '0')}';

  bool isOverdue(DateTime now) =>
      (status == DeliverableStatus.draft ||
          status == DeliverableStatus.internalReview ||
          status == DeliverableStatus.revise) &&
      dueDate != null &&
      dueDate!.isBefore(DateTime(now.year, now.month, now.day));

  factory Deliverable.fromMap(Map<String, Object?> m) => Deliverable(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    projectId: m['project_id'] as String,
    title: (m['title'] ?? '') as String,
    stageId: m['stage_id'] as String?,
    version: (m['version'] as num?)?.toInt() ?? 1,
    status: _enumByName(
      DeliverableStatus.values,
      m['status'],
      DeliverableStatus.draft,
    ),
    dueDate: _date(m['due_date']),
    submittedAt: _date(m['submitted_at']),
    approvedAt: _date(m['approved_at']),
    fileLink: (m['file_link'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
    discipline: _enumByName(
      Discipline.values,
      m['discipline'],
      Discipline.architecture,
    ),
    docType: _enumByName(DocType.values, m['doc_type'], DocType.drawing),
    number: (m['doc_number'] as num?)?.toInt() ?? 1,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'project_id': projectId,
    'title': title,
    'stage_id': stageId,
    'version': version,
    'status': status.name,
    'due_date': _dateStr(dueDate),
    'submitted_at': _dateStr(submittedAt),
    'approved_at': _dateStr(approvedAt),
    'file_link': fileLink,
    'notes': notes,
    'discipline': discipline.name,
    'doc_type': docType.name,
    'doc_number': number,
  };

  Deliverable copyWith({
    String? title,
    String? stageId,
    int? version,
    DeliverableStatus? status,
    DateTime? dueDate,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? fileLink,
    String? notes,
    bool? deleted,
    DateTime? updatedAt,
  }) => Deliverable(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    projectId: projectId,
    title: title ?? this.title,
    stageId: stageId ?? this.stageId,
    version: version ?? this.version,
    status: status ?? this.status,
    dueDate: dueDate ?? this.dueDate,
    submittedAt: submittedAt ?? this.submittedAt,
    approvedAt: approvedAt ?? this.approvedAt,
    fileLink: fileLink ?? this.fileLink,
    notes: notes ?? this.notes,
    discipline: discipline,
    docType: docType,
    number: number,
  );
}

class Stage implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String name;
  final int position;

  /// The service this stage belongs to: design, consultancy or contracting.
  final ServiceType service;

  const Stage({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.name,
    required this.position,
    this.service = ServiceType.design,
  });

  factory Stage.fromMap(Map<String, Object?> m) => Stage(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    name: (m['name'] ?? '') as String,
    position: (m['position'] as num?)?.toInt() ?? 0,
    service: _enumByName(ServiceType.values, m['service'], ServiceType.design),
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'name': name,
    'position': position,
    'service': service.name,
  };

  Stage copyWith({
    String? name,
    int? position,
    bool? deleted,
    DateTime? updatedAt,
  }) => Stage(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    position: position ?? this.position,
    service: service,
  );
}

class Member implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String name;
  final String email;
  final MemberRole role;

  const Member({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.name,
    this.email = '',
    this.role = MemberRole.architect,
  });

  bool get isOwner => role == MemberRole.owner;

  factory Member.fromMap(Map<String, Object?> m) => Member(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    name: (m['name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    role: _enumByName(MemberRole.values, m['role'], MemberRole.architect),
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'name': name,
    'email': email,
    'role': role.name,
  };

  Member copyWith({
    String? name,
    String? email,
    MemberRole? role,
    bool? deleted,
    DateTime? updatedAt,
  }) => Member(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    name: name ?? this.name,
    email: email ?? this.email,
    role: role ?? this.role,
  );
}

/// Standard design stages. They are stored in English; screens show them
/// with `.tr` (Arabic in lib/l10n/ar_common.dart), so a renamed stage shows
/// as typed.
const defaultStages = [
  'Brief',
  'Concept design',
  'Schematic design',
  'Design development',
  'Permit',
  'Construction drawings',
  'Tender',
  'Site supervision',
];
