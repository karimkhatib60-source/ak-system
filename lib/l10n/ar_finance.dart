// Arabic wording for the finance texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
const arFinance = <String, String>{
  // ------------------------------------------------ Finance screen --
  'Quotation': 'عرض سعر',
  'Invoice': 'فاتورة',
  'Receipt': 'إيصال',
  'Expense': 'مصروف',
  'This month': 'هذا الشهر',
  'This year': 'هذه السنة',
  'All time': 'كل الفترات',
  'Quotes {0}': 'العروض {0}',
  'Invoices {0}': 'الفواتير {0}',
  'Receipts {0}': 'الإيصالات {0}',
  'Expenses {0}': 'المصاريف {0}',
  'Profit': 'الربح',
  'No quotations in this period': 'لا عروض أسعار في هذه الفترة',
  'No invoices in this period': 'لا فواتير في هذه الفترة',
  'No receipts in this period': 'لا إيصالات في هذه الفترة',
  'No expenses in this period': 'لا مصاريف في هذه الفترة',
  'No income or expenses in this period': 'لا دخل ولا مصاريف في هذه الفترة',

  // Key figures.
  'Approved quotes': 'عروض معتمدة',
  'Invoiced': 'المفوتر',
  'Received': 'المقبوض',
  'Outstanding': 'غير المسدّد',
  'Credit held {0}': 'رصيد دائن: {0}',
  'Expenses': 'المصاريف',
  'Unpaid bills {0}': 'فواتير غير مدفوعة: {0}',
  'Without VAT': 'من دون الضريبة',
  'Invoiced without VAT, less expenses':
      'المفوتر من دون الضريبة، ناقص المصاريف',
  '{0}% margin · without VAT': 'هامش {0}% · من دون الضريبة',
  '{0} due': 'مستحق {0}',

  // Project money tab.
  'Project statement': 'كشف حساب المشروع',
  'Quotations': 'عروض الأسعار',
  'No quotation yet.': 'لا يوجد عرض سعر بعد.',
  'Payment schedule': 'جدول الدفعات',
  'Invoices': 'الفواتير',
  'No invoice yet.': 'لا توجد فاتورة بعد.',
  'Receipts': 'الإيصالات',
  'No money received yet.': 'لم يُقبض أي مبلغ بعد.',
  'AK only. Expenses and profit never appear on client documents.':
      'خاص بـ AK. لا تظهر المصاريف والأرباح أبداً في مستندات العميل.',
  'No expenses yet. Add each supplier bill or cost you pay for this project.':
      'لا مصاريف بعد. أضف كل فاتورة مورّد أو تكلفة تدفعها لهذا المشروع.',
  'Client account': 'حساب العميل',
  'AK internal': 'داخلي AK',

  // Next step on a project's account.
  'Start with a quotation. When the client approves it, mark it Approved '
          'and invoice from it.':
      'ابدأ بعرض سعر. عند موافقة العميل عليه، علّمه «معتمد» وأصدر '
      'الفاتورة منه.',
  'No approved quotation. Prepare a new one for the client.':
      'لا يوجد عرض سعر معتمد. حضّر عرضاً جديداً للعميل.',
  'Waiting for the client to approve {0}. Mark it Approved when they agree, '
          'then invoice from it.':
      'بانتظار موافقة العميل على {0}. علّمه «معتمد» عند موافقته، ثم '
      'أصدر الفاتورة منه.',
  '{0} invoices': '{0} من الفواتير',
  '{0} is overdue on {1}. Record a receipt when the client pays.':
      'مبلغ {0} متأخر السداد على {1}. سجّل إيصالاً عندما يدفع العميل.',
  '{0} is due on {1}, {2} of it overdue. Record a receipt when the client '
          'pays.':
      'مبلغ {0} مستحق على {1}، منه {2} متأخر السداد. سجّل إيصالاً عندما '
      'يدفع العميل.',
  '{0} is due on {1}. Record a receipt when the client pays.':
      'مبلغ {0} مستحق على {1}. سجّل إيصالاً عندما يدفع العميل.',
  '{0} is still a draft. Send it to issue it; money already received is set '
          'off automatically.':
      '{0} لا تزال مسودة. أرسلها لإصدارها؛ وتُخصم المبالغ المقبوضة مسبقاً '
      'تلقائياً.',
  'Raise the first invoice from {0}; the {1} received in advance is deducted '
          'from it.':
      'أصدر الفاتورة الأولى من {0}؛ ويُخصم منها مبلغ {1} المقبوض مسبقاً.',
  'Raise the first invoice from {0}.': 'أصدر الفاتورة الأولى من {0}.',
  'Nothing due now. {0} of the contract is left to invoice, and the {1} '
          'received in advance is set off on the next invoices.':
      'لا مستحقات حالياً. بقي {0} من العقد بانتظار الفوترة، ويُخصم مبلغ {1} '
      'المقبوض مسبقاً من الفواتير التالية.',
  'Nothing due now. {0} of the contract is left to invoice.':
      'لا مستحقات حالياً. بقي {0} من العقد بانتظار الفوترة.',
  'Fully invoiced and paid. {0} credit is held for the client.':
      'تمّت الفوترة والدفع بالكامل. يوجد رصيد دائن بقيمة {0} لصالح العميل.',
  'Fully invoiced and paid.': 'تمّت الفوترة والدفع بالكامل.',
  'Raise the first invoice from the approved quotation.':
      'أصدر الفاتورة الأولى من عرض السعر المعتمد.',

  // Client account card.
  'CLIENT ACCOUNT': 'حساب العميل',
  'Contract value': 'قيمة العقد',
  'Approved quotations': 'عروض الأسعار المعتمدة',
  'No approved quotation yet': 'لا يوجد عرض سعر معتمد بعد',
  '{0} of the contract': '{0} من العقد',
  '{0} extra work': 'أعمال إضافية {0}',
  '{0} of invoiced': '{0} من المفوتر',
  'Due now': 'المستحق الآن',
  '{0} overdue': 'متأخر السداد: {0}',
  'On issued invoices, after advances':
      'على الفواتير الصادرة، بعد خصم الدفعات المقدّمة',
  'Nothing to collect on issued invoices':
      'لا مبالغ للتحصيل على الفواتير الصادرة',
  'Credit held': 'رصيد دائن',
  'Received ahead; set off on the next invoices, oldest first':
      'مقبوض مسبقاً؛ يُخصم من الفواتير التالية، الأقدم أولاً',
  'Left to invoice': 'المتبقي للفوترة',
  'Contract less what was invoiced on it': 'العقد ناقص ما فوتر منه',
  'Still to receive': 'المتبقي للقبض',
  'Invoiced less received': 'المفوتر ناقص المقبوض',
  'Contract and extra work, less received':
      'العقد والأعمال الإضافية، ناقص المقبوض',
  'Invoiced less received (above the contract)':
      'المفوتر ناقص المقبوض (يتجاوز العقد)',
  'Contract less received': 'العقد ناقص المقبوض',
  'Invoiced of the contract': 'المفوتر من العقد',
  'Received of the contract and extra work':
      'المقبوض من العقد والأعمال الإضافية',
  'Received of the contract': 'المقبوض من العقد',
  "Amounts include VAT, as on the client's documents.":
      'المبالغ شاملة الضريبة، كما في مستندات العميل.',

  // -------------------------------------------------------- Expenses --
  'Company': 'الشركة',
  '{0} item': '{0} بند',
  '{0} items': 'البنود: {0}',
  'Unpaid': 'غير مدفوعة',
  'COSTS BY TYPE · WITHOUT VAT': 'التكاليف حسب النوع · من دون الضريبة',
  '{0} is over {1}. Please attach a smaller copy, for example a photo '
          'instead of a scan.':
      'حجم {0} يتجاوز {1}. يُرجى إرفاق نسخة أصغر، مثلاً صورة بدلاً من مسح '
      'ضوئي.',
  'Add at least one item with a rate, or switch to Total only.':
      'أضف بنداً واحداً على الأقل مع سعره، أو انتقل إلى «الإجمالي فقط».',
  'New expense': 'مصروف جديد',
  'Delete': 'حذف',
  'this expense': 'هذا المصروف',
  'Save': 'حفظ',
  'Internal to AK. Expenses never appear on client documents.':
      'داخلي لـ AK. لا تظهر المصاريف أبداً في مستندات العميل.',
  'Bill': 'الفاتورة',
  'Supplier': 'المورّد',
  'Company, subcontractor or person paid':
      'شركة أو مقاول فرعي أو شخص تمّ الدفع له',
  'Supplier invoice no.': 'رقم فاتورة المورّد',
  'As on their bill': 'كما في فاتورته',
  'Date': 'التاريخ',
  'Description': 'الوصف',
  'e.g. Porcelain tiles, kitchen and bathrooms':
      'مثلاً: بلاط بورسلان، المطبخ والحمّامات',
  'For': 'يُحمَّل على',
  'Company running cost (overheads), not on a project':
      'تكلفة تشغيل الشركة (مصاريف عامة)، غير مرتبطة بمشروع',
  "It lowers this project's profit": 'يخفّض ربح هذا المشروع',
  'Company (overheads)': 'الشركة (مصاريف عامة)',
  'Type of cost': 'نوع التكلفة',
  'Amount': 'المبلغ',
  'Items': 'بنود',
  'Total only': 'الإجمالي فقط',
  'Item': 'بند',
  "Paste the lines of the supplier's bill, from Excel or written for you in "
          'the chat. One item per line: description, unit, quantity, rate.':
      'الصق بنود فاتورة المورّد، من Excel أو كما كُتبت لك في المحادثة. بند '
      'واحد في كل سطر: الوصف، الوحدة، الكمية، السعر.',
  'Porcelain tiles 60x60 | m² | 85 | 22\nTile adhesive | bag | 40 | 6.5':
      'بلاط بورسلان 60x60 | م² | 85 | 22\nغراء بلاط | كيس | 40 | 6.5',
  'Paste items': 'لصق البنود',
  'Total, VAT included': 'الإجمالي شامل الضريبة',
  'Total': 'الإجمالي',
  'Enter the amount': 'أدخل المبلغ',
  'The supplier charged VAT': 'فرض المورّد الضريبة على القيمة المضافة',
  'VAT you pay suppliers is deducted from the VAT on your invoices, so profit '
          'counts the cost without it.':
      'تُخصم الضريبة التي تدفعها للمورّدين من الضريبة على فواتيرك، لذا يُحتسب '
      'الربح على التكلفة من دونها.',
  'VAT rate': 'نسبة الضريبة',
  'Cost without VAT': 'التكلفة من دون الضريبة',
  'Subtotal': 'المجموع الفرعي',
  'VAT {0}%': 'الضريبة على القيمة المضافة {0}%',
  'Total of the bill': 'إجمالي الفاتورة',
  'Payment': 'الدفع',
  'Paid': 'مدفوعة',
  'Not paid yet': 'غير مدفوعة بعد',
  'Paid by': 'طريقة الدفع',
  'Shown as a bill still to pay to the supplier. Open it and mark it paid '
          'when you pay.':
      'تظهر كفاتورة مستحقة الدفع للمورّد. افتحها وعلّمها مدفوعة عند الدفع.',
  'Supplier invoice': 'فاتورة المورّد',
  'Attach': 'إرفاق',
  "Attach the supplier's invoice or receipt (PDF or photo) to keep it with "
          'this expense. The amounts are not read from the file: enter the '
          'items or the total above.':
      'أرفق فاتورة المورّد أو إيصاله (PDF أو صورة) لحفظها مع هذا المصروف. لا '
      'تُقرأ المبالغ من الملف: أدخل البنود أو الإجمالي أعلاه.',
  'This file is not on this device yet. It opens once the device that added '
          'it has synced.':
      'هذا الملف غير موجود على هذا الجهاز بعد. يُفتح بعد مزامنة الجهاز الذي '
      'أضافه.',
  'The file could not be opened. Check the internet connection and try '
          'again.':
      'تعذّر فتح الملف. تحقّق من الاتصال بالإنترنت وحاول مجدداً.',
  'Notes': 'ملاحظات',
  'Anything to remember about this bill':
      'أي شيء تودّ تذكّره بشأن هذه الفاتورة',
  'Remove item': 'إزالة البند',
  'Qty': 'الكمية',
  'Unit': 'الوحدة',
  'Rate': 'السعر',
  'Remove file': 'إزالة الملف',
  'Save a copy': 'حفظ نسخة',

  // ---------------------------------------------------------- Profit --
  'PROFIT · INTERNAL': 'الربح · داخلي',
  '{0} margin': 'هامش {0}',
  'Invoiced, without VAT': 'المفوتر، من دون الضريبة',
  'Expenses, without VAT': 'المصاريف، من دون الضريبة',
  'Profit on invoiced work': 'الربح على الأعمال المفوترة',
  'Above the expected profit: some costs of the invoiced work may not be '
          'recorded yet':
      'أعلى من الربح المتوقّع: قد تكون بعض تكاليف الأعمال المفوترة غير مسجّلة '
      'بعد',
  'Contract, without VAT': 'العقد، من دون الضريبة',
  '{0} still to invoice': 'يتبقّى {0} للفوترة',
  '{0} invoiced above the contract': '{0} مفوتر فوق قيمة العقد',
  'Fully invoiced': 'تمّت فوترته بالكامل',
  '{0} extra work invoiced': 'أعمال إضافية مفوترة {0}',
  'Budgeted cost (BOQ)': 'التكلفة المقدّرة (جدول الكميات)',
  'Over budget by {0}': 'تجاوز الميزانية بمبلغ {0}',
  '{0} of the budget left': 'يتبقّى {0} من الميزانية',
  'Expected profit at completion': 'الربح المتوقّع عند الإنجاز',
  'If costs stay within the budget': 'إذا بقيت التكاليف ضمن الميزانية',
  'No cost budget on this contract, so the final profit is not forecast.':
      'لا توجد ميزانية تكلفة لهذا العقد، لذا لا يُقدَّر الربح النهائي.',
  'Cash in hand': 'النقد المتوفّر',
  'Received {0} less expenses paid': 'المقبوض {0} ناقص المصاريف المدفوعة',
  'Paid to suppliers': 'المدفوع للمورّدين',
  'Bills paid, VAT included': 'فواتير مدفوعة، شاملة الضريبة',
  'Unpaid supplier bills': 'فواتير مورّدين غير مدفوعة',
  'Still to pay, VAT included; the cost without VAT is already in expenses':
      'متبقّية للدفع، شاملة الضريبة؛ والتكلفة من دون الضريبة محتسبة ضمن '
      'المصاريف',
  'VAT: {0} on your invoices less {1} charged by suppliers, so {2} is owed '
          'to the tax office. VAT is not income or cost.':
      'الضريبة: {0} على فواتيرك ناقص {1} فرضها المورّدون، لذا يتوجّب {2} '
      'لوزارة المالية. الضريبة ليست دخلاً ولا تكلفة.',
  'VAT: {0} on your invoices less {1} charged by suppliers, so you have a '
          'VAT credit of {2} to set against VAT on future invoices. VAT is '
          'not income or cost.':
      'الضريبة: {0} على فواتيرك ناقص {1} فرضها المورّدون، لذا لديك رصيد '
      'ضريبي بقيمة {2} يُخصم من الضريبة على الفواتير المقبلة. الضريبة ليست '
      'دخلاً ولا تكلفة.',
  'VAT: {0} on your invoices less {1} charged by suppliers, so no VAT is '
          'owed. VAT is not income or cost.':
      'الضريبة: {0} على فواتيرك ناقص {1} فرضها المورّدون، لذا لا ضريبة '
      'متوجّبة. الضريبة ليست دخلاً ولا تكلفة.',
  'VAT of {0} on your invoices is owed to the tax office, so it is not '
          'counted as income.':
      'الضريبة البالغة {0} على فواتيرك متوجّبة لوزارة المالية، لذا لا تُحتسب '
      'دخلاً.',
  'VAT of {0} charged by suppliers is recoverable, so it is not counted as '
          'cost.':
      'الضريبة البالغة {0} التي فرضها المورّدون قابلة للاسترداد، لذا لا '
      'تُحتسب تكلفة.',
  'Expenses and profit never appear on client documents.':
      'لا تظهر المصاريف والأرباح أبداً في مستندات العميل.',
  'no income yet': 'لا دخل بعد',
  'Invoiced {0} without VAT · expenses {1}':
      'المفوتر {0} من دون الضريبة · المصاريف {1}',
  'Not on a project': 'خارج المشاريع',
  'Invoiced {0} without VAT · expenses {1} · invoices with no project or of '
          'a deleted one':
      'المفوتر {0} من دون الضريبة · المصاريف {1} · فواتير بلا مشروع أو '
      'لمشروع محذوف',
  'Invoiced {0} without VAT · invoices with no project or of a deleted one':
      'المفوتر {0} من دون الضريبة · فواتير بلا مشروع أو لمشروع محذوف',
  'Company overheads': 'المصاريف العامة للشركة',
  'Expenses not booked on a project': 'مصاريف غير مسجّلة على مشروع',
  'Total profit': 'إجمالي الربح',

  // ------------------------------------------------- Seeded presets --
  // Stored in English in the database; screens show value.tr and printed
  // documents value.td. A renamed value has no Arabic and shows as typed.

  // Payment term labels (paymentTermPresets).
  'Advance payment': 'دفعة مقدّمة',
  'Concept and schematic design': 'التصميم المبدئي والتخطيطي',
  'Design development and permit': 'تطوير التصميم والترخيص',
  'Construction drawings': 'الخرائط التنفيذية',
  'Final payment': 'الدفعة النهائية',
  'Progress payment 1': 'دفعة مرحلية 1',
  'Progress payment 2': 'دفعة مرحلية 2',
  'Final payment (retention)': 'الدفعة النهائية (المحتجزات)',

  // Payment term due texts (paymentTermPresets).
  'On signing the agreement': 'عند توقيع الاتفاقية',
  'On approval of the concept design': 'عند الموافقة على التصميم المبدئي',
  'On submission of the permit drawings': 'عند تقديم خرائط الترخيص',
  'On delivery of the construction drawings': 'عند تسليم الخرائط التنفيذية',
  'On delivery of the final report': 'عند تسليم التقرير النهائي',
  'On signing the contract, before mobilization':
      'عند توقيع العقد، قبل تجهيز الموقع',
  'On completion of structure works': 'عند إنجاز الأعمال الإنشائية',
  'On completion of MEP and finishing works':
      'عند إنجاز الأعمال الكهروميكانيكية وأعمال التشطيب',
  'On handover, after snagging': 'عند التسليم، بعد معالجة الملاحظات',

  // Design stages (defaultStages in models.dart, the design list of
  // serviceStages). 'Construction drawings' is with the terms above.
  'Concept design': 'التصميم المبدئي',
  'Schematic design': 'التصميم التخطيطي',
  'Design development': 'تطوير التصميم',
  'Permit': 'الترخيص',
  'Tender': 'المناقصة',
  'Site supervision': 'الإشراف على التنفيذ',

  // Consultancy stages (serviceStages).
  'Inquiry and scope': 'الاستفسار وتحديد النطاق',
  'Proposal and agreement': 'العرض والاتفاقية',
  'Site visit and survey': 'زيارة الموقع والمسح',
  'Review and analysis': 'المراجعة والتحليل',
  'Recommendations report': 'تقرير التوصيات',
  'Client meeting': 'اجتماع مع العميل',
  'Final report': 'التقرير النهائي',
  'Follow-up': 'المتابعة',

  // Contracting stages (serviceStages).
  'Quotation and BOQ': 'عرض السعر وجدول الكميات',
  'Contract signed': 'توقيع العقد',
  'Mobilization': 'تجهيز الموقع',
  'Demolition and excavation': 'الهدم والحفريات',
  'Structure works': 'الأعمال الإنشائية',
  'MEP works': 'الأعمال الكهروميكانيكية',
  'Finishing works': 'أعمال التشطيب',
  'Snagging': 'معالجة الملاحظات',
  'Handover': 'تسليم المشروع',
  'Warranty period': 'فترة الضمان',

  // Default unit of a new line (LineItem in finance.dart).
  'lump sum': 'مقطوعة',

  // Document colour themes (report_theme.dart).
  'Own colours': 'ألوان مخصّصة',
  'Graphite and blue': 'رمادي غرافيتي وأزرق',
  'Navy': 'كحلي',
  'Black and grey': 'أسود ورمادي',
  'Slate and teal': 'رمادي أردوازي وفيروزي',
  'Forest green': 'أخضر داكن',
  'Burgundy': 'خمري',
  "Attach the supplier's bill": 'إرفاق فاتورة المورّد',

  // Export and profit by contract (v14).
  'A general cost of the project, not matched to one contract':
      'كلفة عامة للمشروع، غير مربوطة بعقد معيّن',
  'A sheet for each kind of document, with amounts, VAT, money received and balances.':
      'ورقة لكل نوع من المستندات، مع المبالغ والضريبة والمقبوضات والأرصدة.',
  "Add the suppliers' files": 'إضافة ملفات الموردين',
  'All dates': 'كل التواريخ',
  'Budgeted cost {0}': 'الكلفة المقدّرة {0}',
  'By contract': 'حسب العقد',
  'COST AND PROFIT REPORT': 'تقرير الكلفة والربح',
  'Category': 'الفئة',
  'Choose one by one': 'الاختيار واحداً واحداً',
  'Client documents': 'مستندات العميل',
  'Company overhead': 'مصروف عام للشركة',
  'Contract {0}': 'العقد {0}',
  'Contract {0} without VAT': 'العقد {0} من دون الضريبة',
  'Contract, payment schedule, invoices and money received, as of today':
      'العقد وجدول الدفعات والفواتير والمقبوضات، حتى اليوم',
  'Cost and profit report': 'تقرير الكلفة والربح',
  'Cost of': 'مربوط بـ',
  'Could not export: {0}': 'تعذّر التصدير: {0}',
  'EXPENSES': 'المصاريف',
  'Every document one after the other, each with its own page numbers. Easy to print or send in one go.': 'كل المستندات متتالية، ولكلٍّ منها ترقيم صفحاته. سهل للطباعة أو للإرسال دفعة واحدة.',
  'Excel list': 'قائمة Excel',
  'Expenses come with a cost and profit report by contract. Never send them to the client.': 'تأتي المصاريف مع تقرير الكلفة والربح حسب العقد. لا ترسلها إلى العميل أبداً.',
  'Expenses, without VAT · 1 bill': 'المصاريف من دون الضريبة · فاتورة واحدة',
  'Expenses, without VAT · {0} bills': 'المصاريف من دون الضريبة · {0} فواتير',
  'Export': 'تصدير',
  'Export 1 document': 'تصدير مستند واحد',
  'Export {0} documents': 'تصدير {0} مستندات',
  'Extra work': 'أعمال إضافية',
  'Files': 'الملفات',
  'For this project': 'لهذا المشروع',
  'General project cost (not linked)': 'كلفة عامة للمشروع (غير مربوطة)',
  'Held, not yet set against an invoice': 'محتجز، لم يُخصم بعد من فاتورة',
  'Hide details': 'إخفاء التفاصيل',
  'Hide the list': 'إخفاء القائمة',
  'INVOICES': 'الفواتير',
  'In the ZIP only': 'في ملف ZIP فقط',
  'Income': 'الإيرادات',
  'Internal: AK only, not for the client': 'داخلي: لـ AK فقط، ليس للعميل',
  'Invoiced and expenses are without VAT: VAT is owed to, or recovered from, the tax office, so it is neither income nor cost. Received is the money received in the period, VAT included, whether set against an invoice or still held.': 'المفوتر والمصاريف من دون الضريبة: الضريبة مستحقة لدائرة الضرائب أو مستردّة منها، فهي ليست إيراداً ولا كلفة. المقبوض هو المال المقبوض خلال الفترة، شاملاً الضريبة، سواء خُصم من فاتورة أو ما زال محفوظاً.',
  'Outside projects': 'خارج المشاريع',
  'Received on invoices dated outside the period':
      'مقبوض على فواتير مؤرّخة خارج الفترة',
  'This Excel list includes the expenses and the profit by work. Keep it inside AK.':
      'ملف Excel هذا يتضمّن المصاريف والربح حسب العمل. احتفظ به داخل AK.',
  'Saved {0}. One supplier file is not on this device and was left out; open its expense when online, then export again.': 'تمّ حفظ {0}. ملف مورّد واحد غير موجود على هذا الجهاز فلم يُضمَّن؛ افتح مصروفه عند الاتصال بالإنترنت ثم صدّر من جديد.',
  'Saved {0}. {1} supplier files are not on this device and were left out; open their expenses when online, then export again.': 'تمّ حفظ {0}. {1} من ملفات الموردين غير موجودة على هذا الجهاز فلم تُضمَّن؛ افتح مصاريفها عند الاتصال بالإنترنت ثم صدّر من جديد.',
  'Invoices and expenses': 'الفواتير والمصاريف',
  'Leave both empty for every date.': 'اتركهما فارغين لكل التواريخ.',
  'Link': 'ربط',
  'Link all to {0}': 'ربط الكل بـ {0}',
  'Link {0} costs to {1}?': 'ربط {0} مصاريف بـ {1}؟',
  'Margin': 'الهامش',
  'Margin %': 'الهامش %',
  'Matched with the extra-work invoices': 'تُقابَل بفواتير الأعمال الإضافية',
  "Matched with this contract's invoices for its profit":
      'تُقابَل بفواتير هذا العقد لحساب ربحه',
  'No': 'لا',
  'No.': 'الرقم',
  'None in this period': 'لا شيء في هذه الفترة',
  'Not linked': 'غير مربوط',
  'Not linked to a contract': 'غير مربوط بعقد',
  'Number': 'الرقم',
  'One PDF file': 'ملف PDF واحد',
  'One PDF per document in folders, with an Excel list of everything.':
      'ملف PDF لكل مستند ضمن مجلدات، مع قائمة Excel بكل شيء.',
  'PROJECT TOTAL · INTERNAL': 'إجمالي المشروع · داخلي',
  'Prepared on': 'تاريخ الإعداد',
  'Preparing…': 'جارٍ التحضير…',
  'Profit by work': 'الربح حسب العمل',
  'Profit {0}': 'الربح {0}',
  'Received less expenses paid': 'المقبوض ناقص المصاريف المدفوعة',
  'Received less expenses paid · {0} of bills still to pay':
      'المقبوض ناقص المصاريف المدفوعة · {0} من الفواتير لم يُدفع بعد',
  'Received {0} of {1}': 'قُبض {0} من {1}',
  'Register': 'السجل',
  'Save as': 'الحفظ بصيغة',
  'Save the export': 'حفظ التصدير',
  'Saved {0}': 'تم حفظ {0}',
  'Separate files (ZIP)': 'ملفات منفصلة (ZIP)',
  'Supplier files': 'ملفات الموردين',
  'Supplier ref.': 'مرجع المورّد',
  'The ZIP includes the internal cost and profit report. Keep it inside AK.':
      'يتضمّن ملف ZIP تقرير الكلفة والربح الداخلي. أبقِه داخل AK.',
  'The bills and receipts attached to these expenses':
      'الفواتير والإيصالات المرفقة بهذه المصاريف',
  'These costs are not matched to a contract. Open one to choose its contract, or link them all:': 'هذه المصاريف غير مربوطة بعقد. افتح أيّاً منها لاختيار عقده، أو اربطها كلها:',
  'They will count in the profit of {0}. You can change any of them later.':
      'ستُحتسب في ربح {0}. يمكنك تغيير أيٍّ منها لاحقاً.',
  'This PDF includes the internal cost and profit report. Keep it inside AK.':
      'يتضمّن ملف PDF هذا تقرير الكلفة والربح الداخلي. أبقِه داخل AK.',
  'Title': 'العنوان',
  'To': 'إلى',
  'VAT included': 'شاملاً الضريبة',
  'VAT included · {0} on account, not yet set against an invoice':
      'شاملاً الضريبة · {0} على الحساب، لم تُخصم بعد من فاتورة',
  'VAT included · {0} advance held, not yet set against an invoice':
      'شاملاً الضريبة · {0} دفعة مقدّمة محفوظة، لم تُخصم بعد من فاتورة',
  'Yes': 'نعم',
  '{0}, not approved': '{0}، غير معتمد',
};
