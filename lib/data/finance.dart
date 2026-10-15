part of 'models.dart';

// Money records: quotations, invoices, payments received, and expenses.
// Only the owner sees these. Amounts are in US dollars.

enum QuotationStatus { draft, sent, accepted, rejected }

enum InvoiceStatus { draft, sent, cancelled }

/// What an invoice amounts to once payments are counted.
enum PaymentState { draft, unpaid, partlyPaid, paid, overdue, cancelled }

enum PaymentMethod { bankTransfer, cash, cheque, card, other }

enum ExpenseCategory {
  subcontractor,
  materials,
  salaries,
  rent,
  software,
  transport,
  printing,
  marketing,
  fees,
  other,
}

/// One priced line on a quotation or invoice.
class LineItem {
  const LineItem({
    this.description = '',
    this.quantity = 1,
    this.unit = 'lump sum',
    this.rate = 0,
    this.section = '',
  });

  /// BOQ heading this line belongs to, e.g. "Masonry works".
  final String section;
  final String description;
  final double quantity;
  final String unit;
  final double rate;

  double get amount => quantity * rate;

  factory LineItem.fromJson(Map<String, Object?> m) => LineItem(
    description: (m['d'] ?? '') as String,
    quantity: (m['q'] as num?)?.toDouble() ?? 1,
    unit: (m['u'] ?? '') as String,
    rate: (m['r'] as num?)?.toDouble() ?? 0,
    section: (m['s'] ?? '') as String,
  );

  Map<String, Object?> toJson() => {
    'd': description,
    'q': quantity,
    'u': unit,
    'r': rate,
    if (section.isNotEmpty) 's': section,
  };

  LineItem copyWith({
    String? description,
    double? quantity,
    String? unit,
    double? rate,
    String? section,
  }) => LineItem(
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    rate: rate ?? this.rate,
    section: section ?? this.section,
  );
}

List<LineItem> _items(Object? v) {
  if (v == null || v == '') return const [];
  final raw = v is String ? jsonDecode(v) : v;
  return [
    for (final e in raw as List)
      LineItem.fromJson(Map<String, Object?>.from(e as Map)),
  ];
}

String _itemsStr(List<LineItem> items) =>
    jsonEncode([for (final i in items) i.toJson()]);

double _num(Object? v, [double fallback = 0]) =>
    (v as num?)?.toDouble() ?? fallback;

/// Totals shared by quotations and invoices.
mixin PricedDocument {
  List<LineItem> get items;
  double get discount;
  double get vatRate;

  /// Cost-plus percentage added on top of the cost of the items.
  double get markupRate;

  /// Whether the PDF shows the cost-plus fee as its own line. When false the
  /// fee is spread into the item rates and the client sees final prices.
  bool get showMarkup;

  /// Cost of the items before the cost-plus fee.
  double get subtotal => items.fold(0, (s, i) => s + i.amount);
  double get markup => subtotal * markupRate / 100;
  double get net => subtotal + markup - discount;
  double get vat => net * vatRate / 100;
  double get total => net + vat;
}

class Quotation with PricedDocument implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  /// e.g. QT-26-001
  final String number;
  final String title;
  final String? clientId;
  final String? projectId;
  final DateTime date;
  final DateTime? validUntil;
  @override
  final List<LineItem> items;
  @override
  final double discount;
  @override
  final double vatRate;
  @override
  final double markupRate;
  @override
  final bool showMarkup;
  final QuotationStatus status;
  final String terms;
  final String notes;

  const Quotation({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.number,
    this.title = '',
    this.clientId,
    this.projectId,
    required this.date,
    this.validUntil,
    this.items = const [],
    this.discount = 0,
    this.vatRate = 11,
    this.markupRate = 0,
    this.showMarkup = true,
    this.status = QuotationStatus.draft,
    this.terms = '',
    this.notes = '',
  });

  factory Quotation.fromMap(Map<String, Object?> m) => Quotation(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    number: (m['number'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    clientId: m['client_id'] as String?,
    projectId: m['project_id'] as String?,
    date: _date(m['date']) ?? _date(m['created_at'])!,
    validUntil: _date(m['valid_until']),
    items: _items(m['items']),
    discount: _num(m['discount']),
    vatRate: _num(m['vat_rate'], 11),
    markupRate: _num(m['markup_rate']),
    showMarkup: m['show_markup'] != 0 && m['show_markup'] != false,
    status: _enumByName(
      QuotationStatus.values,
      m['status'],
      QuotationStatus.draft,
    ),
    terms: (m['terms'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'number': number,
    'title': title,
    'client_id': clientId,
    'project_id': projectId,
    'date': _dateStr(date),
    'valid_until': _dateStr(validUntil),
    'items': _itemsStr(items),
    'discount': discount,
    'vat_rate': vatRate,
    'markup_rate': markupRate,
    'show_markup': showMarkup ? 1 : 0,
    'status': status.name,
    'terms': terms,
    'notes': notes,
  };

  Quotation copyWith({
    QuotationStatus? status,
    String? projectId,
    bool? deleted,
    List<LineItem>? items,
    double? markupRate,
    bool? showMarkup,
  }) => Quotation(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
    number: number,
    title: title,
    clientId: clientId,
    projectId: projectId ?? this.projectId,
    date: date,
    validUntil: validUntil,
    items: items ?? this.items,
    discount: discount,
    vatRate: vatRate,
    markupRate: markupRate ?? this.markupRate,
    showMarkup: showMarkup ?? this.showMarkup,
    status: status ?? this.status,
    terms: terms,
    notes: notes,
  );
}

class Invoice with PricedDocument implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  /// e.g. INV-26-001
  final String number;
  final String title;
  final String? clientId;
  final String? projectId;
  final String? quotationId;
  final DateTime date;
  final DateTime? dueDate;
  @override
  final List<LineItem> items;
  @override
  final double discount;
  @override
  final double vatRate;
  @override
  final double markupRate;
  @override
  final bool showMarkup;
  final InvoiceStatus status;
  final String notes;

  const Invoice({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.number,
    this.title = '',
    this.clientId,
    this.projectId,
    this.quotationId,
    required this.date,
    this.dueDate,
    this.items = const [],
    this.discount = 0,
    this.vatRate = 11,
    this.markupRate = 0,
    this.showMarkup = true,
    this.status = InvoiceStatus.draft,
    this.notes = '',
  });

  factory Invoice.fromMap(Map<String, Object?> m) => Invoice(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    number: (m['number'] ?? '') as String,
    title: (m['title'] ?? '') as String,
    clientId: m['client_id'] as String?,
    projectId: m['project_id'] as String?,
    quotationId: m['quotation_id'] as String?,
    date: _date(m['date']) ?? _date(m['created_at'])!,
    dueDate: _date(m['due_date']),
    items: _items(m['items']),
    discount: _num(m['discount']),
    vatRate: _num(m['vat_rate'], 11),
    markupRate: _num(m['markup_rate']),
    showMarkup: m['show_markup'] != 0 && m['show_markup'] != false,
    status: _enumByName(InvoiceStatus.values, m['status'], InvoiceStatus.draft),
    notes: (m['notes'] ?? '') as String,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'number': number,
    'title': title,
    'client_id': clientId,
    'project_id': projectId,
    'quotation_id': quotationId,
    'date': _dateStr(date),
    'due_date': _dateStr(dueDate),
    'items': _itemsStr(items),
    'discount': discount,
    'vat_rate': vatRate,
    'markup_rate': markupRate,
    'show_markup': showMarkup ? 1 : 0,
    'status': status.name,
    'notes': notes,
  };

  Invoice copyWith({InvoiceStatus? status, bool? deleted}) => Invoice(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
    number: number,
    title: title,
    clientId: clientId,
    projectId: projectId,
    quotationId: quotationId,
    date: date,
    dueDate: dueDate,
    items: items,
    discount: discount,
    vatRate: vatRate,
    markupRate: markupRate,
    showMarkup: showMarkup,
    status: status ?? this.status,
    notes: notes,
  );
}

class Payment implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;
  final String invoiceId;
  final DateTime date;
  final double amount;
  final PaymentMethod method;
  final String reference;

  const Payment({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    required this.invoiceId,
    required this.date,
    required this.amount,
    this.method = PaymentMethod.bankTransfer,
    this.reference = '',
  });

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    invoiceId: (m['invoice_id'] ?? '') as String,
    date: _date(m['date']) ?? _date(m['created_at'])!,
    amount: _num(m['amount']),
    method: _enumByName(
      PaymentMethod.values,
      m['method'],
      PaymentMethod.bankTransfer,
    ),
    reference: (m['reference'] ?? '') as String,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'invoice_id': invoiceId,
    'date': _dateStr(date),
    'amount': amount,
    'method': method.name,
    'reference': reference,
  };

  Payment copyWith({bool? deleted}) => Payment(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
    invoiceId: invoiceId,
    date: date,
    amount: amount,
    method: method,
    reference: reference,
  );
}

class Expense implements Record {
  @override
  final String id;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  /// Null for company overheads such as rent or software.
  final String? projectId;
  final DateTime date;
  final ExpenseCategory category;
  final double amount;
  final String vendor;
  final String notes;

  const Expense({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    this.deleted = false,
    this.projectId,
    required this.date,
    this.category = ExpenseCategory.other,
    required this.amount,
    this.vendor = '',
    this.notes = '',
  });

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as String,
    createdAt: _date(m['created_at'])!,
    updatedAt: _date(m['updated_at'])!,
    deleted: m['deleted'] == 1 || m['deleted'] == true,
    projectId: m['project_id'] as String?,
    date: _date(m['date']) ?? _date(m['created_at'])!,
    category: _enumByName(
      ExpenseCategory.values,
      m['category'],
      ExpenseCategory.other,
    ),
    amount: _num(m['amount']),
    vendor: (m['vendor'] ?? '') as String,
    notes: (m['notes'] ?? '') as String,
  );

  @override
  Map<String, Object?> toMap() => {
    ..._base(this),
    'project_id': projectId,
    'date': _dateStr(date),
    'category': category.name,
    'amount': amount,
    'vendor': vendor,
    'notes': notes,
  };

  Expense copyWith({bool? deleted}) => Expense(
    id: id,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted ?? this.deleted,
    projectId: projectId,
    date: date,
    category: category,
    amount: amount,
    vendor: vendor,
    notes: notes,
  );
}

/// Money position of one project, or of the whole company.
class MoneySummary {
  const MoneySummary({
    required this.quoted,
    required this.invoiced,
    required this.received,
    required this.expenses,
    required this.overdue,
  });

  /// Total of accepted quotations: the agreed fee.
  final double quoted;
  final double invoiced;
  final double received;
  final double expenses;
  final double overdue;

  double get outstanding => invoiced - received;
  double get profit => received - expenses;
}

/// Standard stages per service. Design keeps its original names so existing
/// devices keep the same stage ids.
const serviceStages = <ServiceType, List<String>>{
  ServiceType.design: defaultStages,
  ServiceType.consultancy: [
    'Inquiry and scope',
    'Proposal and agreement',
    'Site visit and survey',
    'Review and analysis',
    'Recommendations report',
    'Client meeting',
    'Final report',
    'Follow-up',
  ],
  ServiceType.contracting: [
    'Quotation and BOQ',
    'Contract signed',
    'Mobilization',
    'Demolition and excavation',
    'Structure works',
    'MEP works',
    'Finishing works',
    'Snagging',
    'Handover',
    'Warranty period',
  ],
};
