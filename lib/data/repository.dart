import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'db.dart';
import 'file_store.dart';
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
  Repository(this.local, {DateTime Function()? clock, FileStore? files})
    : _clock = clock ?? DateTime.now,
      files = files ?? MemoryFileStore();

  final LocalDb local;
  final DateTime Function() _clock;

  /// The bytes of attached files, kept outside the database.
  final FileStore files;

  /// Called after any local change so the sync service can upload it.
  VoidCallback? onLocalChange;

  /// Fetches a file this device does not have from the cloud. Set while
  /// cloud sync is on.
  Future<Uint8List?> Function(Attachment a)? downloadFile;

  /// Numbers of deleted documents by table; never given out again.
  final _deletedNumbers = <String, List<String>>{};

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

  /// Files kept with expenses, without their contents.
  List<Attachment> attachments = [];

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
    _allocations.clear();
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
    attachments =
        (await local.all('attachments')).map(Attachment.fromMap).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final t in const ['quotations', 'invoices', 'payments', 'expenses']) {
      _deletedNumbers[t] = await local.deletedNumbers(t);
    }
    companyInfo = {
      for (final k in companyInfoKeys)
        k: await local.getSetting('company_$k') ?? companyInfoDefaults[k] ?? '',
    };
    currentMemberId = await local.getSetting('current_member_id');
    companyName = await local.getSetting('company_name') ?? companyName;
    final logo = await local.getSetting('company_logo');
    companyLogo = logo == null || logo.isEmpty ? null : base64Decode(logo);
    // A screen may have read set-offs while the lists were half loaded.
    _allocations.clear();
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

  /// Receipts taken directly on an invoice.
  List<Payment> paymentsFor(String invoiceId) =>
      payments.where((p) => p.invoiceId == invoiceId).toList();

  static bool _upTo(DateTime d, DateTime? until) =>
      until == null || !_day(d).isAfter(_day(until));

  static double _cents(double v) => (v * 100).round() / 100;

  /// Receipts taken on an invoice. On an issued invoice this stops at the
  /// invoice total: anything paid above it is credit on the account.
  double _paidDirect(Invoice i, [DateTime? until]) {
    final paid = payments
        .where((p) => p.invoiceId == i.id && _upTo(p.date, until))
        .fold(0.0, (s, p) => s + p.amount);
    if (i.status != InvoiceStatus.sent) return paid;
    final total = _cents(i.total);
    return paid > total ? total : paid;
  }

  /// Advances set against invoices, per client and cut-off day. Rebuilt
  /// whenever the data changes.
  final _allocations = <String, _Allocation>{};

  _Allocation _allocation(String? clientId, [DateTime? until]) =>
      _allocations['$clientId|${until == null ? '' : _day(until)}'] ??=
          _allocate(clientId, until);

  /// The project money held from a receipt belongs to: its invoice's
  /// project, its quotation's, or its own.
  String? homeProject(Payment p) => p.onInvoice
      ? invoice(p.invoiceId)?.projectId ?? p.projectId
      : p.projectId ?? quotation(p.quotationId)?.projectId;

  /// The money of a client's receipts that is not taken on an issued
  /// invoice, and so can be set against invoices:
  ///  - an advance on a payment term, up to the term's amount;
  ///  - money on account, and whatever was paid above a term's amount (or
  ///    on a term that no longer exists);
  ///  - a receipt on an invoice that was cancelled, set back to draft or
  ///    deleted, and whatever was paid above an invoice's total.
  List<_Credit> _creditsOf(String clientId, DateTime? until) {
    final out = <_Credit>[];
    final onTerms = <String, List<Payment>>{};
    final onInvoices = <String, List<Payment>>{};
    for (final p in payments) {
      if (payerOf(p) != clientId || !_upTo(p.date, until)) continue;
      if (p.onInvoice) {
        (onInvoices[p.invoiceId] ??= []).add(p);
      } else if (p.quotationId != null && p.termIndex != null) {
        (onTerms['${p.quotationId}|${p.termIndex}'] ??= []).add(p);
      } else {
        out.add(_Credit(p, p.amount, projectId: p.projectId));
      }
    }
    // Fills [cap] with the receipts in order; the part of each receipt
    // above it becomes money on account of [project].
    void split(
      List<Payment> group,
      double cap,
      String? project, {
      String? quotationId,
      int? termIndex,
      bool keep = true,
    }) {
      group.sort(_byDateThenNumber);
      var room = cap;
      for (final p in group) {
        final inside = p.amount < room ? p.amount : room;
        room -= inside;
        if (inside > 0.005 && keep) {
          out.add(
            _Credit(
              p,
              inside,
              projectId: project,
              quotationId: quotationId,
              termIndex: termIndex,
            ),
          );
        }
        final rest = p.amount - inside;
        if (rest > 0.005) out.add(_Credit(p, rest, projectId: project));
      }
    }

    for (final group in onTerms.values) {
      final p = group.first;
      final q = quotation(p.quotationId);
      final t = p.termIndex!;
      final live =
          q != null &&
          q.status != QuotationStatus.rejected &&
          t < q.paymentTerms.length;
      split(
        group,
        live ? _cents(q.paymentTerms[t].valueOf(q.total)) : 0,
        p.projectId ?? q?.projectId,
        quotationId: p.quotationId,
        termIndex: t,
      );
    }
    for (final MapEntry(key: id, value: group) in onInvoices.entries) {
      final i = invoice(id);
      final issued = i != null && i.status == InvoiceStatus.sent;
      split(
        group,
        issued ? _cents(i.total) : 0,
        i?.projectId ?? group.first.projectId,
        keep: false, // the part within the total is paid on the invoice
      );
    }
    return out..sort((a, b) => _byDateThenNumber(a.payment, b.payment));
  }

  /// Sets every credit (see [_creditsOf]) against the client's issued
  /// invoices.
  ///
  /// Invoices are settled oldest first, so a new invoice never changes how
  /// older ones were paid. For each invoice the money is taken, oldest
  /// receipt first, from:
  ///  1. advances on the invoice's own payment term;
  ///  2. for an invoice on a quotation but not on one term (a full or
  ///     progress invoice), advances on any term of that quotation;
  ///  3. money on account for the same project, or with no project.
  /// Whatever is left stays as credit: an advance waits for its term's
  /// invoice, money on account for the client's next invoice.
  _Allocation _allocate(String? clientId, DateTime? until) {
    final out = _Allocation();
    if (clientId == null) return out;
    final credits = _creditsOf(clientId, until);
    out.credits.addAll(credits);
    if (credits.isEmpty) return out;
    final left = [for (final c in credits) c.amount];
    final targets = [
      for (final i in invoices)
        if (i.clientId == clientId &&
            i.status == InvoiceStatus.sent &&
            _upTo(i.date, until))
          i,
    ]..sort(_byInvoiceDate);
    for (final i in targets) {
      var need = _cents(i.total) - _paidDirect(i, until);
      if (need <= 0.005) continue;
      final groups = <bool Function(_Credit)>[
        if (i.quotationId != null && i.termIndex != null)
          (c) => c.quotationId == i.quotationId && c.termIndex == i.termIndex,
        if (i.quotationId != null && i.termIndex == null)
          (c) => c.onTerm && c.quotationId == i.quotationId,
        (c) =>
            !c.onTerm &&
            (c.projectId == null ||
                i.projectId == null ||
                c.projectId == i.projectId),
        // A contract invoice not linked to a quotation still takes the
        // advances held on the project's payment terms.
        if (i.quotationId == null && !i.extra)
          (c) =>
              c.onTerm &&
              (c.projectId == null ||
                  i.projectId == null ||
                  c.projectId == i.projectId),
      ];
      for (final inGroup in groups) {
        for (var k = 0; k < credits.length && need > 0.005; k++) {
          final c = credits[k];
          if (left[k] <= 0.005 || !inGroup(c)) continue;
          final take = left[k] < need ? left[k] : need;
          left[k] -= take;
          need -= take;
          (out.toInvoice[i.id] ??= []).add((c, take));
          out.add(c.payment.id, i, take);
        }
      }
    }
    return out;
  }

  /// Receipts in the order they were taken.
  static int receiptOrder(Payment a, Payment b) => _byDateThenNumber(a, b);

  /// By day, then receipt number, so a receipt dated with a time and one
  /// picked as a bare date sort the same way.
  static int _byDateThenNumber(Payment a, Payment b) {
    var c = _day(a.date).compareTo(_day(b.date));
    if (c == 0) c = a.number.compareTo(b.number);
    return c != 0 ? c : a.date.compareTo(b.date);
  }

  static int _byInvoiceDate(Invoice a, Invoice b) {
    var c = _day(a.date).compareTo(_day(b.date));
    if (c == 0) c = a.number.compareTo(b.number);
    return c != 0 ? c : a.date.compareTo(b.date);
  }

  /// Advances and money on account set against an invoice.
  double advanceOn(Invoice i, {DateTime? until}) =>
      _allocation(i.clientId, until).onInvoice(i.id);

  /// The receipts set against an invoice (not taken on it), with the
  /// amount of each.
  List<(Payment, double)> advancesOn(Invoice i) {
    final out = <(Payment, double)>[];
    for (final (c, a)
        in _allocation(i.clientId).toInvoice[i.id] ??
            const <(_Credit, double)>[]) {
      final k = out.indexWhere((e) => e.$1.id == c.payment.id);
      if (k < 0) {
        out.add((c.payment, a));
      } else {
        out[k] = (c.payment, out[k].$2 + a);
      }
    }
    return out;
  }

  /// The invoices a receipt's credit was set against.
  List<(Invoice, double)> appliedTo(Payment p, {DateTime? until}) =>
      _allocation(payerOf(p), until).fromReceipt[p.id] ?? const [];

  /// Everything received on an invoice: receipts taken on it, plus
  /// advances and money on account set against it.
  double paidOn(Invoice i, {DateTime? until}) =>
      _paidDirect(i, until) + advanceOn(i, until: until);

  /// Still to collect on an invoice, to the cent.
  double balanceOf(Invoice i) {
    final b = _cents(i.total) - paidOn(i);
    return b.abs() < .005 ? 0 : b;
  }

  /// The part of a receipt not yet set against an invoice: credit held as
  /// an advance on a payment term, or on the client's account.
  double unappliedOf(Payment p, {DateTime? until}) {
    final a = _allocation(payerOf(p), until);
    var left = 0.0;
    for (final c in a.credits) {
      if (c.payment.id == p.id) left += c.amount;
    }
    for (final (_, used)
        in a.fromReceipt[p.id] ?? const <(Invoice, double)>[]) {
      left -= used;
    }
    return left.abs() < .005 ? 0 : left;
  }

  /// The part of a receipt that went to one project (null: to no
  /// project): taken on its invoices, set against its invoices, or held
  /// as credit for it. The parts of every receipt add up to its amount.
  double receivedFor(Payment p, String? projectId, {DateTime? until}) {
    final a = _allocation(payerOf(p), until);
    var credit = 0.0;
    for (final c in a.credits) {
      if (c.payment.id == p.id) credit += c.amount;
    }
    final home = homeProject(p) == projectId;
    var out = home ? p.amount - credit : 0.0; // taken on its own invoice
    for (final (i, used)
        in a.fromReceipt[p.id] ?? const <(Invoice, double)>[]) {
      credit -= used;
      if (i.projectId == projectId) out += used;
    }
    if (home) out += credit; // still held as credit
    return out.abs() < .005 ? 0 : out;
  }

  /// Received for a project (all receipts when [projectId] is null), by
  /// receipt date.
  double receivedOn({String? projectId, DateTime? since}) => payments
      .where((p) => since == null || !p.date.isBefore(since))
      .fold(
        0.0,
        (s, p) =>
            s + (projectId == null ? p.amount : receivedFor(p, projectId)),
      );

  /// Received before [p] on the same invoice or term, in receipt order.
  double receivedBefore(Payment p) {
    bool same(Payment o) => p.onInvoice
        ? o.invoiceId == p.invoiceId
        : p.quotationId != null && p.termIndex != null
        ? !o.onInvoice &&
              o.quotationId == p.quotationId &&
              o.termIndex == p.termIndex
        : false;
    return payments
        .where((o) => o.id != p.id && same(o) && _byDateThenNumber(o, p) < 0)
        .fold(0.0, (s, o) => s + o.amount);
  }

  /// Who paid: the receipt's own client, or its invoice's.
  String? payerOf(Payment p) => p.clientId ?? invoice(p.invoiceId)?.clientId;

  /// The project a receipt belongs to.
  String? projectOfPayment(Payment p) =>
      p.projectId ?? invoice(p.invoiceId)?.projectId;

  /// Receipts, newest first, optionally for one client or project.
  List<Payment> receipts({String? clientId, String? projectId}) => [
    for (final p in payments)
      if ((clientId == null || payerOf(p) == clientId) &&
          (projectId == null ||
              projectOfPayment(p) == projectId ||
              receivedFor(p, projectId) > 0))
        p,
  ]..sort((a, b) => b.date.compareTo(a.date));

  /// Where a payment term of a quotation stands.
  TermStatus termStatus(Quotation q, int index, {DateTime? until}) {
    final term = q.paymentTerms[index];
    final termInvoices = invoices
        .where(
          (i) =>
              i.quotationId == q.id &&
              i.termIndex == index &&
              i.status != InvoiceStatus.cancelled,
        )
        .toList();
    bool mine(_Credit c) => c.quotationId == q.id && c.termIndex == index;
    final a = _allocation(q.clientId, until);
    // Advances held on the term (up to its amount), receipts on the term's
    // invoices, and other money set against them.
    var received = a.credits.where(mine).fold(0.0, (s, c) => s + c.amount);
    for (final i in termInvoices) {
      received += _paidDirect(i, until);
      for (final (c, used)
          in a.toInvoice[i.id] ?? const <(_Credit, double)>[]) {
        if (!mine(c)) received += used;
      }
    }
    return TermStatus(
      term: term,
      value: term.valueOf(q.total),
      invoices: termInvoices,
      received: received,
    );
  }

  /// A draft invoice for one payment term, for the term's amount.
  Invoice invoiceForTerm(Quotation q, int index) {
    final t = now();
    final term = q.paymentTerms[index];
    final value = term.valueOf(q.total);
    final pct = term.percent == 0
        ? ''
        : ' (${term.percent == term.percent.roundToDouble() ? term.percent.toStringAsFixed(0) : term.percent}%)';
    return Invoice(
      id: newId(),
      createdAt: t,
      updatedAt: t,
      number: nextInvoiceNumber(),
      title: '${term.label.isEmpty ? 'Payment ${index + 1}' : term.label}$pct',
      clientId: q.clientId,
      projectId: q.projectId,
      quotationId: q.id,
      termIndex: index,
      stageId: project(q.projectId)?.stageId,
      date: t,
      dueDate: t.add(const Duration(days: 14)),
      vatRate: q.vatRate,
      items: [
        LineItem(
          description:
              '${term.label.isEmpty ? 'Payment ${index + 1}' : term.label}$pct '
              'as per ${q.number}${q.title.isEmpty ? '' : ' · ${q.title}'}',
          rate: value / (1 + q.vatRate / 100),
        ),
      ],
    );
  }

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
    final spent = expenses.where(
      (e) => inProject(e.projectId) && inRange(e.date),
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
      extras: live.where((i) => i.extra).fold(0.0, (s, i) => s + i.total),
      revenue: live.fold(0.0, (s, i) => s + i.net),
      received: receivedOn(projectId: projectId, since: since),
      expenses: spent.fold(0.0, (s, e) => s + e.net),
      paidOut: spent.where((e) => e.paid).fold(0.0, (s, e) => s + e.amount),
      unpaidBills: spent
          .where((e) => !e.paid)
          .fold(0.0, (s, e) => s + e.amount),
      overdue: live
          .where((i) => paymentState(i) == PaymentState.overdue)
          .fold(0.0, (s, i) => s + balanceOf(i)),
      outstanding: live.fold(0.0, (s, i) {
        final b = balanceOf(i);
        return b > 0 ? s + b : s;
      }),
      advances: payments
          .where((p) => inProject(homeProject(p)) && inRange(p.date))
          .fold(0.0, (s, p) => s + unappliedOf(p)),
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

  /// Numbers in use, deleted documents included: a deleted document keeps
  /// its number, so the next one never repeats it.
  Iterable<String> _numbersOf(String table, Iterable<String> live) => [
    ...live,
    ...?_deletedNumbers[table],
  ];

  /// e.g. QT-26-004
  String nextQuotationNumber() => _nextNumber(
    'QT',
    _numbersOf('quotations', quotations.map((q) => q.number)),
  );

  /// e.g. INV-26-012
  String nextInvoiceNumber() =>
      _nextNumber('INV', _numbersOf('invoices', invoices.map((i) => i.number)));

  /// Next expense number, e.g. EXP-26-007.
  String nextExpenseNumber() =>
      _nextNumber('EXP', _numbersOf('expenses', expenses.map((e) => e.number)));

  /// Next receipt number, e.g. RCT-26-004.
  String nextReceiptNumber() =>
      _nextNumber('RCT', _numbersOf('payments', payments.map((p) => p.number)));

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

  /// Saves a payment, giving it the next receipt number if it has none.
  Future<void> savePayment(Payment p) => _write(
    'payments',
    (p.number.isEmpty ? p.copyWith(number: nextReceiptNumber()) : p).toMap(),
  );

  /// The payment with its receipt number, numbering older payments that
  /// were recorded before receipts existed.
  Future<Payment> withReceiptNumber(Payment p) async {
    if (p.number.isNotEmpty) return p;
    final numbered = p.copyWith(number: nextReceiptNumber());
    await _write('payments', numbered.toMap());
    return numbered;
  }

  /// A progress invoice billing [percent] of every line of an accepted
  /// quotation, so each item can be tracked as it is invoiced.
  Invoice progressInvoice(Quotation q, double percent, {String? stageId}) {
    final t = now();
    final f = percent / 100;
    String p(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
    return Invoice(
      id: newId(),
      createdAt: t,
      updatedAt: t,
      number: nextInvoiceNumber(),
      title: 'Progress invoice ${p(percent)}% of ${q.number}',
      clientId: q.clientId,
      projectId: q.projectId,
      quotationId: q.id,
      stageId: stageId ?? project(q.projectId)?.stageId,
      date: t,
      dueDate: t.add(const Duration(days: 14)),
      items: [for (final i in q.items) i.copyWith(quantity: i.quantity * f)],
      discount: q.discount * f,
      vatRate: q.vatRate,
      markupRate: q.markupRate,
      showMarkup: q.showMarkup,
    );
  }

  /// Saves an expense, numbering a new one, with files added to it and
  /// files removed from it.
  Future<void> saveExpense(
    Expense e, {
    List<(Attachment, Uint8List)> attach = const [],
    List<Attachment> detach = const [],
  }) async {
    final stamp = now().toUtc().toIso8601String();
    for (final (a, bytes) in attach) {
      // The file first: its details are only saved once it is safely kept.
      await files.put(a.id, bytes);
      await local.addPendingFile(a.id);
      await local.save('attachments', {...a.toMap(), 'updated_at': stamp});
    }
    for (final a in detach) {
      await _removeFile(a, stamp);
    }
    await _write(
      'expenses',
      (e.number.isEmpty ? e.copyWith(number: nextExpenseNumber()) : e).toMap(),
    );
  }

  Future<void> _removeFile(Attachment a, String stamp) async {
    await local.save('attachments', {
      ...a.copyWith(deleted: true).toMap(),
      'updated_at': stamp,
    });
    await local.removePendingFile(a.id);
    await files.remove(a.id);
  }

  /// Two devices working offline can give the same number to two
  /// expenses. After a sync the later one takes the next free number; every
  /// device picks the same one, so they agree.
  Future<void> renumberDuplicateExpenses() async {
    final seen = <String>{};
    final given = <String>[];
    final byAge = [...expenses]
      ..sort((a, b) {
        final c = a.createdAt.compareTo(b.createdAt);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    for (final e in byAge) {
      if (e.number.isEmpty || seen.add(e.number)) continue;
      final n = _nextNumber('EXP', [
        ..._numbersOf('expenses', expenses.map((x) => x.number)),
        ...given,
      ]);
      given.add(n);
      await local.save('expenses', {
        ...e.copyWith(number: n).toMap(),
        'updated_at': now().toUtc().toIso8601String(),
      });
    }
    if (given.isEmpty) return;
    await reload();
    onLocalChange?.call();
  }

  /// The files kept with a record.
  List<Attachment> attachmentsOf(String ownerId) =>
      attachments.where((a) => a.ownerId == ownerId).toList();

  /// The contents of an attachment, read when it is opened. A file added
  /// on another device is fetched from the cloud the first time and then
  /// kept here.
  Future<Uint8List?> attachmentBytes(String id) async {
    final kept = await files.get(id);
    if (kept != null) return kept;
    final a = attachments.where((x) => x.id == id).firstOrNull;
    final fetch = downloadFile;
    if (a == null || fetch == null) return null;
    final bytes = await fetch(a);
    if (bytes != null) await files.put(id, bytes);
    return bytes;
  }

  Future<void> deleteQuotation(Quotation q) =>
      _write('quotations', q.copyWith(deleted: true).toMap());
  Future<void> deletePayment(Payment p) =>
      _write('payments', p.copyWith(deleted: true).toMap());

  /// Deletes an expense and the files kept with it.
  Future<void> deleteExpense(Expense e) async {
    final stamp = now().toUtc().toIso8601String();
    for (final a in attachmentsOf(e.id)) {
      await _removeFile(a, stamp);
    }
    await _write('expenses', e.copyWith(deleted: true).toMap());
  }

  /// Deleting an invoice never loses money received: its receipts stay,
  /// moved to the client's account (or back to the payment term it billed).
  Future<void> deleteInvoice(Invoice i) async {
    for (final p in paymentsFor(i.id)) {
      await local.save('payments', {
        ...p
            .detached(
              clientId: i.clientId,
              projectId: i.projectId,
              quotationId: i.termIndex == null ? null : i.quotationId,
              termIndex: i.termIndex,
              notes: [
                if (p.notes.isNotEmpty) p.notes,
                'Was on ${i.number}',
              ].join(' · '),
            )
            .toMap(),
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
      stageId: project(q.projectId)?.stageId,
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

/// Which receipts paid how much of which invoice.
/// Money from one receipt that can be set against invoices. One receipt
/// can give two: the part within a payment term, and what was paid above.
class _Credit {
  _Credit(
    this.payment,
    this.amount, {
    this.projectId,
    this.quotationId,
    this.termIndex,
  });

  final Payment payment;
  final double amount;
  final String? projectId;

  /// Set on an advance held for one payment term.
  final String? quotationId;
  final int? termIndex;

  bool get onTerm => quotationId != null && termIndex != null;
}

class _Allocation {
  final credits = <_Credit>[];
  final toInvoice = <String, List<(_Credit, double)>>{};
  final fromReceipt = <String, List<(Invoice, double)>>{};

  double onInvoice(String id) =>
      toInvoice[id]?.fold<double>(0, (s, e) => s + e.$2) ?? 0;

  void add(String paymentId, Invoice i, double amount) {
    final list = fromReceipt[paymentId] ??= [];
    final k = list.indexWhere((e) => e.$1.id == i.id);
    if (k < 0) {
      list.add((i, amount));
    } else {
      list[k] = (i, list[k].$2 + amount);
    }
  }
}
