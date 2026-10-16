import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/advisor.dart';
import '../data/models.dart';
import '../data/repository.dart';

const _model = 'claude-opus-5-5';
const _endpoint = 'https://api.anthropic.com/v1/messages';

/// Settings key holding the owner's Claude API key. It stays on the device.
const aiKeySetting = 'ai_key';

/// One line in the assistant conversation as the screen shows it.
class ChatLine {
  ChatLine.user(this.text) : fromUser = true, actions = const [];
  ChatLine.assistant(this.text, this.actions) : fromUser = false;

  final bool fromUser;
  final String text;

  /// What the assistant changed while answering, e.g. "Created project …".
  final List<DoneAction> actions;
}

class DoneAction {
  const DoneAction(this.label, {this.projectId, this.error = false});

  final String label;
  final String? projectId;
  final bool error;
}

/// The AK Assistant: turns plain instructions into records in the app, and
/// points out what is missing. Calls Claude directly with the owner's key.
class Assistant extends ChangeNotifier {
  Assistant(this.repo, {http.Client? client}) : _http = client ?? http.Client();

  final Repository repo;
  final http.Client _http;

  final lines = <ChatLine>[];
  final _messages = <Map<String, Object?>>[];
  bool busy = false;
  String? apiKey;

  bool get ready => (apiKey ?? '').isNotEmpty;

  Future<void> loadKey() async {
    apiKey = await repo.local.getSetting(aiKeySetting);
    notifyListeners();
  }

  Future<void> setKey(String? key) async {
    await repo.local.setSetting(aiKeySetting, key?.trim());
    apiKey = key?.trim();
    notifyListeners();
  }

  void clear() {
    lines.clear();
    _messages.clear();
    notifyListeners();
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty || busy) return;
    lines.add(ChatLine.user(text.trim()));
    _messages.add({'role': 'user', 'content': text.trim()});
    busy = true;
    notifyListeners();
    final done = <DoneAction>[];
    try {
      final reply = await _run(done);
      lines.add(ChatLine.assistant(reply, done));
    } on AssistantError catch (e) {
      lines.add(ChatLine.assistant(e.message, done));
      // Drop the unanswered turn so the next message starts cleanly.
      while (_messages.isNotEmpty && _messages.last['role'] != 'assistant') {
        _messages.removeLast();
      }
    } catch (e) {
      lines.add(
        ChatLine.assistant(
          'I could not reach the AI service. Check the internet connection '
          'and try again.',
          done,
        ),
      );
      while (_messages.isNotEmpty && _messages.last['role'] != 'assistant') {
        _messages.removeLast();
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// The tool-use loop: ask, run the tools Claude calls, send the results
  /// back, until Claude answers in words.
  Future<String> _run(List<DoneAction> done) async {
    for (var round = 0; round < 12; round++) {
      final res = await _http.post(
        Uri.parse(_endpoint),
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey ?? '',
          'anthropic-version': '2023-06-01',
          'anthropic-beta': 'server-side-fallback-2026-07-01',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 16000,
          'fallbacks': 'default',
          'output_config': {'effort': 'medium'},
          'system': _system(),
          'tools': _tools(repo.isOwner),
          'messages': _messages,
        }),
      );
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode == 401) {
        throw const AssistantError(
          'The AI key was refused. Check it in Settings > AK Assistant.',
        );
      }
      if (res.statusCode == 429 || res.statusCode >= 500) {
        throw const AssistantError(
          'The AI service is busy right now. Try again in a minute.',
        );
      }
      if (res.statusCode != 200) {
        final err = body is Map ? body['error'] : null;
        final msg = err is Map ? '${err['message'] ?? ''}' : '';
        throw AssistantError('The AI service returned an error. $msg');
      }
      final m = body as Map<String, Object?>;
      if (m['stop_reason'] == 'refusal') {
        throw const AssistantError(
          'The AI declined that request. Try rephrasing it.',
        );
      }
      final content = _echoable((m['content'] as List).cast<Map>());
      _messages.add({'role': 'assistant', 'content': content});

      final uses = content.where((b) => b['type'] == 'tool_use').toList();
      if (m['stop_reason'] != 'tool_use' || uses.isEmpty) {
        return content
            .where((b) => b['type'] == 'text')
            .map((b) => b['text'] as String)
            .join('\n')
            .trim();
      }
      final results = <Map<String, Object?>>[];
      for (final u in uses) {
        String out;
        var isError = false;
        try {
          out = await _call(
            u['name'] as String,
            Map<String, Object?>.from(u['input'] as Map),
            done,
          );
        } catch (e) {
          out = 'Error: $e';
          isError = true;
        }
        results.add({
          'type': 'tool_result',
          'tool_use_id': u['id'],
          'content': out,
          if (isError) 'is_error': true,
        });
      }
      _messages.add({'role': 'user', 'content': results});
    }
    return 'I stopped after many steps. Tell me what is left to do.';
  }

  /// After a fallback to another model, the blocks produced before the
  /// switch must not be sent back (except text).
  List<Map<String, Object?>> _echoable(List<Map> blocks) {
    final list = [for (final b in blocks) Map<String, Object?>.from(b)];
    final last = list.lastIndexWhere((b) => b['type'] == 'fallback');
    if (last < 0) return list;
    return [
      for (var i = 0; i < list.length; i++)
        if (i > last || list[i]['type'] == 'text') list[i],
    ];
  }

  String _system() {
    final now = repo.now();
    final b = StringBuffer()
      ..writeln(
        'You are AK Assistant, built into the AK System app of '
        '${repo.companyName}, an architecture practice in Lebanon run by '
        'architect Karim El Khatib (design, consultancy and contracting in '
        'Lebanon; consultancy only outside Lebanon).',
      )
      ..writeln(
        'Karim tells you what he wants in plain words, often short or mixed '
        'English. Do the work with the tools: create and update clients, '
        'projects, tasks, deliverables'
        '${repo.isOwner ? ', quotations, invoices, payments and expenses' : ''}. '
        'Fill in sensible professional defaults where he did not say '
        '(task categories, document disciplines, standard architectural '
        'fee items, 11% VAT, USD, 30-day quotation validity, 14-day invoice '
        'terms) and say which defaults you used.',
      )
      ..writeln(
        'After acting, check what an experienced architect would make sure '
        'is covered and is still missing: deadline, client contact, site '
        'location and map pin, built-up area, scope, fee quotation, payment '
        'schedule, permits, consultants (structure, MEP), next tasks for the '
        'current stage. Ask about the most important gaps in one short list. '
        'Call review_office when useful.',
      )
      ..writeln(
        'Reply briefly in plain English, like a capable office manager. No '
        'markdown tables. Never invent amounts or dates he did not give; ask '
        'instead, except for the defaults above.',
      )
      ..writeln('Today is ${_d(now)}.')
      ..writeln()
      ..writeln(
        'CURRENT OFFICE DATA (ids are for tool calls only; never show them):',
      )
      ..writeln('Clients:');
    for (final c in repo.visibleClients) {
      b.writeln(
        '- ${c.id} | ${c.name}${c.company.isEmpty ? '' : ' (${c.company})'} | '
        '${c.phone} ${c.email} | ${c.country}',
      );
    }
    b.writeln('Projects:');
    for (final p in repo.visibleProjects) {
      b.writeln(
        '- ${p.id} | ${p.code} ${p.name} | client ${repo.client(p.clientId)?.name ?? '-'} | '
        '${p.service.name} | ${p.type.name} | ${p.status.name} | stage '
        '${repo.stage(p.stageId)?.name ?? '-'} | location ${p.location} | '
        'area ${p.areaSqm ?? '-'} | due ${_d(p.dueDate)}',
      );
    }
    b.writeln('Stages by service:');
    for (final s in ServiceType.values) {
      b.writeln(
        '- ${s.name}: ${repo.stagesFor(s).map((x) => x.name).join(', ')}',
      );
    }
    if (repo.members.isNotEmpty) {
      b.writeln(
        'Team: ${repo.members.map((m) => '${m.id} ${m.name} (${m.role.name})').join('; ')}',
      );
    }
    b.writeln('Open tasks:');
    for (final t in repo.visibleTasks.where(
      (t) => t.status != TaskStatus.done,
    )) {
      b.writeln(
        '- ${t.id} | ${repo.project(t.projectId)?.code} | ${t.title} | due ${_d(t.dueDate)}',
      );
    }
    if (repo.isOwner) {
      b.writeln('Quotations:');
      for (final q in repo.quotations) {
        b.writeln(
          '- ${q.id} | ${q.number} | ${repo.client(q.clientId)?.name} | '
          '${q.title} | ${q.status.name} | total ${q.total.toStringAsFixed(2)}',
        );
      }
      b.writeln('Invoices:');
      for (final i in repo.invoices) {
        b.writeln(
          '- ${i.id} | ${i.number} | ${repo.client(i.clientId)?.name} | '
          '${repo.paymentState(i).name} | total ${i.total.toStringAsFixed(2)} | '
          'balance ${repo.balanceOf(i).toStringAsFixed(2)}',
        );
      }
    }
    return b.toString();
  }

  // ---- Tools --------------------------------------------------------------

  Future<String> _call(
    String name,
    Map<String, Object?> a,
    List<DoneAction> done,
  ) async {
    final now = repo.now();
    String s(String k) => (a[k] as String?)?.trim() ?? '';
    double? n(String k) => (a[k] as num?)?.toDouble();
    DateTime? d(String k) => DateTime.tryParse(s(k));
    T pick<T extends Enum>(List<T> values, String k, T fallback) =>
        values.where((v) => v.name == s(k)).firstOrNull ?? fallback;

    switch (name) {
      case 'create_client':
        final c = Client(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          name: s('name'),
          company: s('company'),
          phone: s('phone'),
          email: s('email'),
          country: s('country').isEmpty ? 'Lebanon' : s('country'),
          notes: s('notes'),
        );
        await repo.saveClient(c);
        done.add(DoneAction('Added client ${c.name}'));
        return 'client_id ${c.id}';

      case 'save_project':
        final old = repo.project(s('project_id'));
        if (s('project_id').isNotEmpty && old == null) {
          return 'Error: no project with that id';
        }
        final abroad = a['abroad'] as bool? ?? old?.abroad ?? false;
        var service = pick(
          ServiceType.values,
          'service',
          old?.service ?? ServiceType.design,
        );
        if (abroad) service = ServiceType.consultancy;
        final stages = repo.stagesFor(service);
        final stageName = s('stage').toLowerCase();
        final stage =
            stages
                .where((x) => x.name.toLowerCase() == stageName)
                .firstOrNull ??
            (old != null && stages.any((x) => x.id == old.stageId)
                ? repo.stage(old.stageId)
                : stages.firstOrNull);
        final p = Project(
          id: old?.id ?? repo.newId(),
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
          code: old?.code ?? repo.nextProjectCode(),
          name: s('name').isEmpty ? old?.name ?? 'New project' : s('name'),
          clientId: s('client_id').isEmpty ? old?.clientId : s('client_id'),
          service: service,
          location: s('location').isEmpty ? old?.location ?? '' : s('location'),
          mapLink: s('map_link').isEmpty ? old?.mapLink ?? '' : s('map_link'),
          abroad: abroad,
          stageId: stage?.id,
          status: pick(
            ProjectStatus.values,
            'status',
            old?.status ?? ProjectStatus.active,
          ),
          startDate: d('start_date') ?? old?.startDate ?? now,
          dueDate: d('due_date') ?? old?.dueDate,
          teamIds: old?.teamIds ?? const [],
          notes: s('notes').isEmpty ? old?.notes ?? '' : s('notes'),
          type: pick(
            ProjectType.values,
            'project_type',
            old?.type ?? ProjectType.residential,
          ),
          areaSqm: n('area_sqm') ?? old?.areaSqm,
          markupRate: n('markup_rate') ?? old?.markupRate,
        );
        await repo.saveProject(p);
        done.add(
          DoneAction(
            '${old == null ? 'Created' : 'Updated'} project ${p.code} ${p.name}',
            projectId: p.id,
          ),
        );
        return 'project_id ${p.id}, code ${p.code}, stage ${stage?.name}';

      case 'create_task':
        final p = repo.project(s('project_id'));
        if (p == null) return 'Error: no project with that id';
        final assignee = repo.members
            .where(
              (m) => m.name.toLowerCase().contains(s('assignee').toLowerCase()),
            )
            .firstOrNull;
        final t = Task(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          projectId: p.id,
          title: s('title'),
          dueDate: d('due_date'),
          priority: pick(TaskPriority.values, 'priority', TaskPriority.normal),
          category: pick(TaskCategory.values, 'category', TaskCategory.design),
          assigneeId: s('assignee').isEmpty
              ? repo.currentMemberId
              : assignee?.id,
          stageId: p.stageId,
          notes: s('notes'),
        );
        await repo.saveTask(t);
        done.add(DoneAction('Task: ${t.title}', projectId: p.id));
        return 'task_id ${t.id}';

      case 'complete_task':
        final t = repo.tasks.where((x) => x.id == s('task_id')).firstOrNull;
        if (t == null) return 'Error: no task with that id';
        await repo.saveTask(t.copyWith(status: TaskStatus.done));
        done.add(DoneAction('Done: ${t.title}', projectId: t.projectId));
        return 'ok';

      case 'create_deliverable':
        final p = repo.project(s('project_id'));
        if (p == null) return 'Error: no project with that id';
        final disc = pick(
          Discipline.values,
          'discipline',
          Discipline.architecture,
        );
        final type = pick(DocType.values, 'doc_type', DocType.drawing);
        final x = Deliverable(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          projectId: p.id,
          title: s('title'),
          stageId: p.stageId,
          dueDate: d('due_date'),
          discipline: disc,
          docType: type,
          number: repo.nextDocNumber(p.id, disc, type),
        );
        await repo.saveDeliverable(x);
        done.add(
          DoneAction(
            'Deliverable ${repo.docCode(x)} ${x.title}',
            projectId: p.id,
          ),
        );
        return 'deliverable ${repo.docCode(x)}';

      case 'create_quotation':
        _ownerOnly();
        final items = _lineItems(a['items']);
        final q = Quotation(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          number: repo.nextQuotationNumber(),
          title: s('title'),
          clientId: s('client_id'),
          projectId: s('project_id').isEmpty ? null : s('project_id'),
          date: now,
          validUntil: now.add(
            Duration(days: (a['valid_days'] as num?)?.toInt() ?? 30),
          ),
          items: items,
          discount: n('discount') ?? 0,
          vatRate: n('vat_rate') ?? 11,
          markupRate:
              n('markup_rate') ??
              repo.project(s('project_id'))?.markupRate ??
              0,
          terms: s('terms').isEmpty
              ? repo.companyInfo['terms'] ?? ''
              : s('terms'),
          notes: s('notes'),
        );
        await repo.saveQuotation(q);
        done.add(
          DoneAction(
            'Quotation ${q.number}: \$${q.total.toStringAsFixed(2)}',
            projectId: q.projectId,
          ),
        );
        return 'quotation ${q.number}, total ${q.total.toStringAsFixed(2)}';

      case 'set_quotation_status':
        _ownerOnly();
        final q = repo.quotation(s('quotation_id'));
        if (q == null) return 'Error: no quotation with that id';
        await repo.saveQuotation(
          q.copyWith(status: pick(QuotationStatus.values, 'status', q.status)),
        );
        done.add(DoneAction('${q.number} marked ${s('status')}'));
        return 'ok';

      case 'create_invoice':
        _ownerOnly();
        Invoice inv;
        final q = repo.quotation(s('quotation_id'));
        if (q != null && a['items'] == null) {
          inv = repo.invoiceFromQuotation(q);
          if (q.status != QuotationStatus.accepted) {
            await repo.saveQuotation(
              q.copyWith(status: QuotationStatus.accepted),
            );
          }
        } else {
          inv = Invoice(
            id: repo.newId(),
            createdAt: now,
            updatedAt: now,
            number: repo.nextInvoiceNumber(),
            title: s('title'),
            clientId: s('client_id').isEmpty ? q?.clientId : s('client_id'),
            projectId: s('project_id').isEmpty ? q?.projectId : s('project_id'),
            quotationId: q?.id,
            date: now,
            dueDate: now.add(
              Duration(days: (a['due_days'] as num?)?.toInt() ?? 14),
            ),
            items: _lineItems(a['items']),
            discount: n('discount') ?? 0,
            vatRate: n('vat_rate') ?? q?.vatRate ?? 11,
            notes: s('notes'),
          );
        }
        if (a['issue'] == true) {
          inv = inv.copyWith(status: InvoiceStatus.sent);
        }
        await repo.saveInvoice(inv);
        done.add(
          DoneAction(
            'Invoice ${inv.number}: \$${inv.total.toStringAsFixed(2)}',
            projectId: inv.projectId,
          ),
        );
        return 'invoice ${inv.number}, total ${inv.total.toStringAsFixed(2)}';

      case 'record_payment':
        _ownerOnly();
        final inv = repo.invoice(s('invoice_id'));
        if (inv == null) return 'Error: no invoice with that id';
        if (inv.status == InvoiceStatus.cancelled) {
          return 'Error: ${inv.number} is cancelled';
        }
        if (inv.status == InvoiceStatus.draft) {
          await repo.saveInvoice(inv.copyWith(status: InvoiceStatus.sent));
        }
        final due = repo.balanceOf(repo.invoice(inv.id) ?? inv);
        final amount = n('amount') ?? due;
        if (due <= 0.005) {
          final setOff = repo.advanceOn(repo.invoice(inv.id) ?? inv);
          return 'Nothing to record: ${inv.number} is already paid'
              '${setOff > 0.005 ? ', including ${setOff.toStringAsFixed(2)} set off from other payments' : ''}';
        }
        if (amount <= 0 || amount > due + 0.005) {
          return 'Error: the amount must be more than 0 and at most '
              '${due.toStringAsFixed(2)}, the balance due. Record any extra on '
              'account.';
        }
        await repo.savePayment(
          Payment(
            id: repo.newId(),
            createdAt: now,
            updatedAt: now,
            invoiceId: inv.id,
            date: d('date') ?? now,
            amount: amount,
            method: pick(
              PaymentMethod.values,
              'method',
              PaymentMethod.bankTransfer,
            ),
            reference: s('reference'),
          ),
        );
        done.add(
          DoneAction(
            'Payment \$${amount.toStringAsFixed(2)} on ${inv.number}',
            projectId: inv.projectId,
          ),
        );
        return 'ok, balance now ${repo.balanceOf(inv).toStringAsFixed(2)}';

      case 'add_expense':
        _ownerOnly();
        final e = Expense(
          id: repo.newId(),
          createdAt: now,
          updatedAt: now,
          projectId: s('project_id').isEmpty ? null : s('project_id'),
          date: d('date') ?? now,
          category: pick(
            ExpenseCategory.values,
            'category',
            ExpenseCategory.other,
          ),
          amount: n('amount') ?? 0,
          vendor: s('vendor'),
          notes: s('notes'),
        );
        await repo.saveExpense(e);
        done.add(
          DoneAction(
            'Expense \$${e.amount.toStringAsFixed(2)} ${e.vendor}',
            projectId: e.projectId,
          ),
        );
        return 'ok';

      case 'review_office':
        final list = reviewOffice(
          repo,
          projectId: s('project_id').isEmpty ? null : s('project_id'),
        );
        if (list.isEmpty) return 'Nothing missing.';
        return list
            .take(30)
            .map((x) => '- [${x.level.name}] ${x.title}: ${x.detail}')
            .join('\n');
    }
    return 'Error: unknown tool $name';
  }

  void _ownerOnly() {
    if (!repo.isOwner) throw StateError('only the owner can change finances');
  }

  List<LineItem> _lineItems(Object? v) => [
    for (final e in (v as List?) ?? const [])
      LineItem(
        description: (e['description'] ?? '') as String,
        quantity: (e['quantity'] as num?)?.toDouble() ?? 1,
        unit: (e['unit'] ?? 'lump sum') as String,
        rate: (e['rate'] as num?)?.toDouble() ?? 0,
        section: (e['section'] ?? '') as String,
      ),
  ];
}

class AssistantError implements Exception {
  const AssistantError(this.message);
  final String message;
}

String _d(DateTime? d) => d == null
    ? '-'
    : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Map<String, Object?> _tool(
  String name,
  String description,
  Map<String, Object?> props, [
  List<String> required = const [],
]) => {
  'name': name,
  'description': description,
  'input_schema': {'type': 'object', 'properties': props, 'required': required},
};

Map<String, Object?> _str([String? d]) => {'type': 'string', 'description': ?d};
Map<String, Object?> _num([String? d]) => {'type': 'number', 'description': ?d};
Map<String, Object?> _enum(List<Enum> v) => {
  'type': 'string',
  'enum': [for (final e in v) e.name],
};

const _date = 'Date as YYYY-MM-DD';

final _items = {
  'type': 'array',
  'description': 'Priced lines',
  'items': {
    'type': 'object',
    'properties': {
      'description': {'type': 'string'},
      'quantity': {'type': 'number'},
      'unit': {'type': 'string', 'description': 'e.g. lump sum, m², visit'},
      'rate': {'type': 'number', 'description': 'USD cost per unit'},
      'section': {
        'type': 'string',
        'description': 'BOQ section or trade, e.g. Masonry',
      },
    },
    'required': ['description', 'rate'],
  },
};

List<Map<String, Object?>> _tools(bool owner) => [
  _tool(
    'create_client',
    'Add a client.',
    {
      'name': _str(),
      'company': _str(),
      'phone': _str(),
      'email': _str(),
      'country': _str(),
      'notes': _str(),
    },
    ['name'],
  ),
  _tool(
    'save_project',
    'Create a project, or update one when project_id is given (only the '
        'fields passed change).',
    {
      'project_id': _str('Only to update an existing project'),
      'name': _str(),
      'client_id': _str(),
      'service': _enum(ServiceType.values),
      'project_type': _enum(ProjectType.values),
      'abroad': {'type': 'boolean', 'description': 'Outside Lebanon'},
      'location': _str(),
      'map_link': _str('Google Maps link'),
      'area_sqm': _num('Built-up area in m²'),
      'markup_rate': _num('Cost-plus fee percent for this project'),
      'stage': _str('Stage name from that service\'s list'),
      'status': _enum(ProjectStatus.values),
      'start_date': _str(_date),
      'due_date': _str(_date),
      'notes': _str(),
    },
  ),
  _tool(
    'create_task',
    'Add a task to a project.',
    {
      'project_id': _str(),
      'title': _str(),
      'due_date': _str(_date),
      'priority': _enum(TaskPriority.values),
      'category': _enum(TaskCategory.values),
      'assignee': _str('Team member name'),
      'notes': _str(),
    },
    ['project_id', 'title'],
  ),
  _tool('complete_task', 'Mark a task done.', {'task_id': _str()}, ['task_id']),
  _tool(
    'create_deliverable',
    'Add a deliverable (drawing set, report…) to a project; it is numbered '
        'automatically.',
    {
      'project_id': _str(),
      'title': _str(),
      'discipline': _enum(Discipline.values),
      'doc_type': _enum(DocType.values),
      'due_date': _str(_date),
    },
    ['project_id', 'title'],
  ),
  if (owner) ...[
    _tool(
      'create_quotation',
      'Create a draft fee quotation.',
      {
        'client_id': _str(),
        'project_id': _str(),
        'title': _str('Subject line'),
        'items': _items,
        'discount': _num('USD'),
        'vat_rate': _num('Percent, default 11'),
        'markup_rate': _num(
          'Cost-plus fee percent; defaults to the project fee',
        ),
        'valid_days': _num(),
        'terms': _str(),
        'notes': _str(),
      },
      ['client_id', 'items'],
    ),
    _tool(
      'set_quotation_status',
      'Mark a quotation sent, accepted or rejected.',
      {'quotation_id': _str(), 'status': _enum(QuotationStatus.values)},
      ['quotation_id', 'status'],
    ),
    _tool(
      'create_invoice',
      'Create an invoice. With quotation_id and no items it copies the '
          'quotation. Pass items for a partial invoice (e.g. 30% advance).',
      {
        'quotation_id': _str(),
        'client_id': _str(),
        'project_id': _str(),
        'title': _str(),
        'items': _items,
        'discount': _num(),
        'vat_rate': _num(),
        'due_days': _num(),
        'issue': {'type': 'boolean', 'description': 'Issue now (not draft)'},
        'notes': _str(),
      },
    ),
    _tool(
      'record_payment',
      'Record money received against an invoice.',
      {
        'invoice_id': _str(),
        'amount': _num('USD; omit for the full balance'),
        'date': _str(_date),
        'method': _enum(PaymentMethod.values),
        'reference': _str(),
      },
      ['invoice_id'],
    ),
    _tool(
      'add_expense',
      'Record an expense (project or company overhead).',
      {
        'project_id': _str('Omit for company overheads'),
        'amount': _num('USD'),
        'category': _enum(ExpenseCategory.values),
        'vendor': _str(),
        'date': _str(_date),
        'notes': _str(),
      },
      ['amount'],
    ),
  ],
  _tool(
    'review_office',
    'List what is missing, late or waiting across the office or one project.',
    {'project_id': _str()},
  ),
];
