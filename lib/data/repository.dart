import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'models.dart';

const _uuid = Uuid();

/// Company details printed on quotations and invoices.
const companyInfoKeys = [
  'address',
  'phone',
  'email',
  'website',
  'whatsapp',
  'instagram',
  'facebook',
  'linkedin',
  'tax_number',
  'bank',
  'terms',
];

const companyInfoDefaults = {
  'address': 'Lebanon',
  'phone': '+961 79 180 650',
  'whatsapp': '+961 79 180 650',
  'website': 'www.ak-dac.com',
  'instagram': '@ak.designconstruction',
  'facebook': 'https://www.facebook.com/profile.php?id=61556269824537',
  'terms':
      'Prices in US dollars. Payment due within 14 days of the invoice date. '
      'Quotation valid for 30 days.',
};

/// In-memory view of the local database that the screens read from.
/// Every change is written to SQLite first, then the lists are reloaded.
class Repository extends ChangeNotifier {
  Repository(this.local, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalDb local;
  final DateTime Function() _clock;

  /// Called after any local change so the sync service can upload it.
  VoidCallback? onLocalChange;

  List<Member> members = [];
  List<Stage> stages = [];
  List<Client> clients = [];
  List<Project> projects = [];
  List<Task> tasks = [];
  List<Deliverable> deliverables = [];
  List<Quotation> quotations = [];
  List<Invoice> invoices = [];
  List<Payment> payments = [];
  List<Expense> expenses = [];

  /// Company details printed on quotations and invoices.
  Map<String, String> companyInfo = {};

  /// The signed-in team member. Null means the app is used on its own,
  /// without cloud sync, and the user is treated as the owner.
  String? currentMemberId;
  String companyName = 'AK Design and Construction';

  /// The company logo image (PNG or JPG), shown in the app and on PDFs.
  Uint8List? companyLogo;

  DateTime now() => _clock();
  String newId() => _uuid.v4();

  Member? get currentMember =>
      members.where((m) => m.id == currentMemberId).firstOrNull;

  bool get isOwner => currentMember == null || currentMember!.isOwner;

  Future<void> load() async {
    await _seedStages();
    await reload();
  }

  Future<void> reload() async {
    members = (await local.all('members')).map(Member.fromMap).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    stages = (await local.all('stages')).map(Stage.fromMap).toList()
      ..sort(
        (a, b) => a.service != b.service
            ? a.service.index.compareTo(b.service.index)
            : a.position.compareTo(b.position),
      );
    clients = (await local.all('clients')).map(Client.fromMap).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    projects = (await local.all('projects')).map(Project.fromMap).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    tasks = (await local.all('tasks')).map(Task.fromMap).toList();
    deliverables = (await local.all('deliverables'))
        .map(Deliverable.fromMap)
        .toList();
    quotations = (await local.all('quotations')).map(Quotation.fromMap).toList()
      ..sort((a, b) => b.number.compareTo(a.number));
    invoices = (await local.all('invoices')).map(Invoice.fromMap).toList()
      ..sort((a, b) => b.number.compareTo(a.number));
    payments = (await local.all('payments')).map(Payment.fromMap).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    expenses = (await local.all('expenses')).map(Expense.fromMap).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    companyInfo = {
      for (final k in companyInfoKeys)
        k: await local.getSetting('company_$k') ?? companyInfoDefaults[k] ?? '',
    };
    currentMemberId = await local.getSetting('current_member_id');
    companyName = await local.getSetting('company_name') ?? companyName;
    final logo = await local.getSetting('company_logo');
    companyLogo = logo == null || logo.isEmpty ? null : base64Decode(logo);
    notifyListeners();
  }

  /// Standard stages for each service, with fixed ids and an old timestamp
  /// so every device creates the same rows and any edit made in the cloud
  /// wins over them. A service is only seeded once, so stages the owner
  /// deleted do not come back.
  Future<void> _seedStages() async {
    final existing = (await local.everything('stages')).map(Stage.fromMap);
    final t = DateTime.utc(2026, 1, 1);
    for (final e in serviceStages.entries) {
      if (existing.any((s) => s.service == e.key)) continue;
      for (var i = 0; i < e.value.length; i++) {
        final key = e.key == ServiceType.design
            ? 'ak-system/stage/${e.value[i]}'
            : 'ak-system/stage/${e.key.name}/${e.value[i]}';
        await local.save(
          'stages',
          Stage(
            id: _uuid.v5(Namespace.url.value, key),
            createdAt: t,
            updatedAt: t,
            name: e.value[i],
            position: i,
            service: e.key,
          ).toMap(),
        );
      }
    }
  }

  // ---- What the current user may see -------------------------------------

  List<Project> get visibleProjects => isOwner
      ? projects
      : projects.where((p) => p.teamIds.contains(currentMemberId)).toList();

  Set<String> get _visibleProjectIds =>
      visibleProjects.map((p) => p.id).toSet();

  List<Task> get visibleTasks {
    final ids = _visibleProjectIds;
    return tasks.where((t) => ids.contains(t.projectId)).toList();
  }

  List<Deliverable> get visibleDeliverables {
    final ids = _visibleProjectIds;
    return deliverables.where((d) => ids.contains(d.projectId)).toList();
  }

  List<Client> get visibleClients {
    if (isOwner) return clients;
    final ids = visibleProjects.map((p) => p.clientId).toSet();
    return clients.where((c) => ids.contains(c.id)).toList();
  }

  // ---- Lookups ------------------------------------------------------------

  Project? project(String? id) => projects.where((p) => p.id == id).firstOrNull;
  Client? client(String? id) => clients.where((c) => c.id == id).firstOrNull;
  Stage? stage(String? id) => stages.where((s) => s.id == id).firstOrNull;
  Member? member(String? id) => members.where((m) => m.id == id).firstOrNull;

  List<Task> tasksFor(String projectId) =>
      tasks.where((t) => t.projectId == projectId).toList();
  List<Deliverable> deliverablesFor(String projectId) =>
      deliverables.where((d) => d.projectId == projectId).toList()
        ..sort((a, b) => a.title.compareTo(b.title));
  List<Project> projectsFor(String clientId) =>
      projects.where((p) => p.clientId == clientId).toList();

  /// Stages of one service, in order.
  List<Stage> stagesFor(ServiceType service) =>
      stages.where((s) => s.service == service).toList();

  /// Stages that apply to a project, by its service.
  List<Stage> stagesOf(String? projectId) =>
      stagesFor(project(projectId)?.service ?? ServiceType.design);

  // ---- Money --------------------------------------------------------------

  Quotation? quotation(String? id) =>
      quotations.where((q) => q.id == id).firstOrNull;
  Invoice? invoice(String? id) => invoices.where((i) => i.id == id).firstOrNull;

  List<Payment> paymentsFor(String invoiceId) =>
      payments.where((p) => p.invoiceId == invoiceId).toList();

  double paidOn(Invoice i) => paymentsFor(i.id).fold(0, (s, p) => s + p.amount);

  double balanceOf(Invoice i) => i.total - paidOn(i);

  PaymentState paymentState(Invoice i) {
    if (i.status == InvoiceStatus.cancelled) return PaymentState.cancelled;
    if (i.status == InvoiceStatus.draft) return PaymentState.draft;
    final paid = paidOn(i);
    if (paid >= i.total - 0.005) return PaymentState.paid;
    final due = i.dueDate;
    if (due != null && _day(now()).isAfter(_day(due))) {
      return PaymentState.overdue;
    }
    return paid > 0 ? PaymentState.partlyPaid : PaymentState.unpaid;
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  List<Quotation> quotationsFor(String projectId) =>
      quotations.where((q) => q.projectId == projectId).toList();
  List<Invoice> invoicesFor(String projectId) =>
      invoices.where((i) => i.projectId == projectId).toList();
  List<Expense> expensesFor(String projectId) =>
      expenses.where((e) => e.projectId == projectId).toList();

  /// Money position of one project, or of everything when [projectId] is
  /// null. [since] limits it to documents dated on or after that day.
  MoneySummary money({String? projectId, DateTime? since}) {
    bool inRange(DateTime d) => since == null || !d.isBefore(since);
    bool inProject(String? id) => projectId == null || id == projectId;
    final live = invoices.where(
      (i) =>
          inProject(i.projectId) &&
          inRange(i.date) &&
          i.status == InvoiceStatus.sent,
    );
    return MoneySummary(
      quoted: quotations
          .where(
            (q) =>
                inProject(q.projectId) &&
                inRange(q.date) &&
                q.status == QuotationStatus.accepted,
          )
          .fold(0.0, (s, q) => s + q.total),
      invoiced: live.fold(0.0, (s, i) => s + i.total),
      received: live.fold(0.0, (s, i) => s + paidOn(i)),
      expenses: expenses
          .where((e) => inProject(e.projectId) && inRange(e.date))
          .fold(0.0, (s, e) => s + e.amount),
      overdue: live
          .where((i) => paymentState(i) == PaymentState.overdue)
          .fold(0.0, (s, i) => s + balanceOf(i)),
    );
  }

  String _nextNumber(String kind, Iterable<String> used) {
    final yy = (now().year % 100).toString().padLeft(2, '0');
    final prefix = '$kind-$yy-';
    var max = 0;
    for (final n in used) {
      if (n.startsWith(prefix)) {
        final v = int.tryParse(n.substring(prefix.length)) ?? 0;
        if (v > max) max = v;
      }
    }
    return '$prefix${(max + 1).toString().padLeft(3, '0')}';
  }

  /// e.g. QT-26-004
  String nextQuotationNumber() =>
      _nextNumber('QT', quotations.map((q) => q.number));

  /// e.g. INV-26-012
  String nextInvoiceNumber() =>
      _nextNumber('INV', invoices.map((i) => i.number));

  /// Next project code for the current year, e.g. AK-26-004.
  String nextProjectCode() {
    final yy = (now().year % 100).toString().padLeft(2, '0');
    final prefix = 'AK-$yy-';
    var max = 0;
    for (final p in projects) {
      if (p.code.startsWith(prefix)) {
        max = [
          max,
          int.tryParse(p.code.substring(prefix.length)) ?? 0,
        ].reduce((a, b) => a > b ? a : b);
      }
    }
    return '$prefix${(max + 1).toString().padLeft(3, '0')}';
  }

  /// Next free number for a document of this discipline and type.
  int nextDocNumber(String projectId, Discipline d, DocType t) {
    var max = 0;
    for (final x in deliverables) {
      if (x.projectId == projectId && x.discipline == d && x.docType == t) {
        if (x.number > max) max = x.number;
      }
    }
    return max + 1;
  }

  String docCode(Deliverable d) => d.docCode(project(d.projectId)?.code ?? '');

  // ---- Changes ------------------------------------------------------------

  Future<void> _write(String table, Map<String, Object?> row) async {
    await local.save(table, {
      ...row,
      'updated_at': now().toUtc().toIso8601String(),
    });
    await reload();
    onLocalChange?.call();
  }

  Future<void> saveClient(Client c) => _write('clients', c.toMap());
  Future<void> saveProject(Project p) => _write('projects', p.toMap());
  Future<void> saveTask(Task t) => _write('tasks', t.toMap());
  Future<void> saveDeliverable(Deliverable d) =>
      _write('deliverables', d.toMap());
  Future<void> saveStage(Stage s) => _write('stages', s.toMap());
  Future<void> saveMember(Member m) => _write('members', m.toMap());
  Future<void> saveQuotation(Quotation q) => _write('quotations', q.toMap());
  Future<void> saveInvoice(Invoice i) => _write('invoices', i.toMap());
  Future<void> savePayment(Payment p) => _write('payments', p.toMap());
  Future<void> saveExpense(Expense e) => _write('expenses', e.toMap());
  Future<void> deleteQuotation(Quotation q) =>
      _write('quotations', q.copyWith(deleted: true).toMap());
  Future<void> deletePayment(Payment p) =>
      _write('payments', p.copyWith(deleted: true).toMap());
  Future<void> deleteExpense(Expense e) =>
      _write('expenses', e.copyWith(deleted: true).toMap());

  /// Deleting an invoice also removes the payments recorded against it.
  Future<void> deleteInvoice(Invoice i) async {
    for (final p in paymentsFor(i.id)) {
      await local.save('payments', {
        ...p.copyWith(deleted: true).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    await _write('invoices', i.copyWith(deleted: true).toMap());
  }

  /// A new draft invoice carrying the quotation's lines.
  Invoice invoiceFromQuotation(Quotation q) {
    final t = now();
    return Invoice(
      id: newId(),
      createdAt: t,
      updatedAt: t,
      number: nextInvoiceNumber(),
      title: q.title,
      clientId: q.clientId,
      projectId: q.projectId,
      quotationId: q.id,
      date: t,
      dueDate: t.add(const Duration(days: 14)),
      items: q.items,
      discount: q.discount,
      vatRate: q.vatRate,
      markupRate: q.markupRate,
      showMarkup: q.showMarkup,
    );
  }

  Future<void> setCompanyInfo(Map<String, String> info) async {
    for (final e in info.entries) {
      await local.setSetting('company_${e.key}', e.value);
    }
    await reload();
  }

  Future<void> deleteClient(Client c) =>
      _write('clients', c.copyWith(deleted: true).toMap());
  Future<void> deleteTask(Task t) =>
      _write('tasks', t.copyWith(deleted: true).toMap());
  Future<void> deleteDeliverable(Deliverable d) =>
      _write('deliverables', d.copyWith(deleted: true).toMap());
  Future<void> deleteStage(Stage s) =>
      _write('stages', s.copyWith(deleted: true).toMap());
  Future<void> deleteMember(Member m) =>
      _write('members', m.copyWith(deleted: true).toMap());

  /// Deleting a project also removes its tasks and deliverables.
  Future<void> deleteProject(Project p) async {
    for (final t in tasksFor(p.id)) {
      await local.save('tasks', {
        ...t.copyWith(deleted: true).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    for (final d in deliverablesFor(p.id)) {
      await local.save('deliverables', {
        ...d.copyWith(deleted: true).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    await _write('projects', p.copyWith(deleted: true).toMap());
  }

  Future<void> toggleTaskDone(Task t) => saveTask(
    t.copyWith(
      status: t.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done,
    ),
  );

  /// Moves a deliverable through its workflow, stamping the dates.
  Future<void> setDeliverableStatus(Deliverable d, DeliverableStatus s) {
    final t = now();
    return saveDeliverable(
      d.copyWith(
        status: s,
        submittedAt: s == DeliverableStatus.submitted ? t : null,
        approvedAt: s == DeliverableStatus.approved ? t : null,
      ),
    );
  }

  /// Starts the next revision after the client asked for changes.
  Future<void> newRevision(Deliverable d) => saveDeliverable(
    d.copyWith(version: d.version + 1, status: DeliverableStatus.draft),
  );

  Future<void> moveStage(Stage s, int delta) async {
    final list = stagesFor(s.service);
    final i = list.indexWhere((x) => x.id == s.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    for (var k = 0; k < list.length; k++) {
      if (list[k].position != k) {
        await local.save('stages', {
          ...list[k].copyWith(position: k).toMap(),
          'updated_at': now().toUtc().toIso8601String(),
        });
      }
    }
    await reload();
    onLocalChange?.call();
  }

  Future<void> setCompanyLogo(Uint8List? bytes) async {
    await local.setSetting(
      'company_logo',
      bytes == null ? '' : base64Encode(bytes),
    );
    await reload();
  }

  Future<void> setCompanyName(String name) async {
    await local.setSetting('company_name', name);
    await reload();
  }

  Future<void> setCurrentMember(String? id) async {
    await local.setSetting('current_member_id', id);
    await reload();
  }
}
