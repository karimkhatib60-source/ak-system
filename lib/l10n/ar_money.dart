// Arabic wording for the money texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
const arMoney = <String, String>{
  // ------------------------------------------------- Common words --
  'Save': 'حفظ',
  'Delete': 'حذف',
  'Cancel': 'إلغاء',
  'Required': 'مطلوب',
  'Client': 'العميل',
  'Project': 'المشروع',
  'Date': 'التاريخ',
  'Notes': 'ملاحظات',
  'Reference': 'المرجع',
  'Invoice': 'فاتورة',
  'Payment term': 'دفعة تعاقدية',
  'On account': 'على الحساب',
  'Choose the client': 'اختر العميل',
  'Send receipt': 'إرسال الإيصال',
  'Balance due': 'الرصيد المستحق',
  'Received so far': 'المقبوض حتى الآن',
  'Remaining': 'المتبقي',
  // Shared with expenses, where it means "charged to"; the later list
  // (finance) wins on the same key.
  'For': 'يُحمَّل على',

  // ------------------------------------- Quotation and invoice form --
  'New invoice': 'فاتورة جديدة',
  'New quotation': 'عرض سعر جديد',
  'this invoice': 'هذه الفاتورة',
  'this quotation': 'عرض السعر هذا',
  'this payment': 'هذه الدفعة',
  'PDF to send or print': 'ملف PDF للإرسال أو الطباعة',
  'STATUS': 'الحالة',
  'Draft': 'مسودة',
  'Issued': 'صادرة',
  'Cancelled@@invoice': 'ملغاة',
  'Accept and invoice': 'موافقة وإصدار فاتورة',
  'Progress invoice': 'فاتورة مرحلية',
  'Record payment': 'تسجيل دفعة',
  'Send PDF': 'إرسال PDF',
  'Invoice number': 'رقم الفاتورة',
  'Quotation number': 'رقم عرض السعر',
  'Subject': 'الموضوع',
  'e.g. Architectural design services, Villa Byblos':
      'مثلاً: خدمات التصميم المعماري، فيلا جبيل',
  'No project yet': 'بلا مشروع بعد',
  'Payment due': 'تاريخ الاستحقاق',
  'Valid until': 'صالح حتى',
  'Billing for': 'موضوع الفوترة',
  "Not counted in the contract's progress. Money received is set against "
          'invoices oldest first, extra work included.':
      'لا تُحتسب ضمن تقدّم العقد. تُخصم المبالغ المقبوضة من الفواتير، '
      'الأقدم أولاً، بما فيها الأعمال الإضافية.',
  'Money received is set against invoices oldest first, advances included.':
      'تُخصم المبالغ المقبوضة من الفواتير، الأقدم أولاً، بما فيها الدفعات '
      'المقدّمة.',
  'contract': 'العقد',
  'Project work (no approved quotation yet)':
      'أعمال المشروع (لا يوجد عرض سعر معتمد بعد)',
  'Not linked to a quotation': 'غير مرتبطة بعرض سعر',
  'Extra work, outside the contract': 'أعمال إضافية، خارج العقد',
  'Phase billed': 'المرحلة المفوترة',
  'Not linked to a phase': 'غير مرتبطة بمرحلة',
  'Bills payment term {0} of {1}: {2}': 'تُفوتر الدفعة {0} من {1}: {2}',

  // Items and totals.
  'Items': 'بنود',
  'Add item': 'إضافة بند',
  'From BOQ library': 'من مكتبة جدول الكميات',
  'Paste items': 'لصق البنود',
  'Section': 'القسم',
  'No section': 'بلا قسم',
  'Item {0}': 'البند {0}',
  'e.g. Concept design': 'مثلاً: التصميم المبدئي',
  'Remove item': 'إزالة البند',
  'Qty': 'الكمية',
  'Unit': 'الوحدة',
  'Rate': 'السعر',
  // Default unit of a new line, as in finance.
  'lump sum': 'مقطوعة',
  'Cost-plus fee': 'نسبة الأتعاب فوق الكلفة',
  'e.g. 15': 'مثلاً 15',
  'Show fee on PDF': 'إظهار الأتعاب في PDF',
  'As its own line': 'في بند مستقل',
  'Included in the rates': 'ضمن الأسعار',
  'Discount': 'حسم',
  'VAT': 'الضريبة',
  'Subtotal': 'المجموع الفرعي',
  'Cost': 'الكلفة',
  'Cost-plus fee {0}%': 'نسبة الأتعاب فوق الكلفة {0}%',
  'VAT {0}%': 'الضريبة على القيمة المضافة {0}%',
  'Total': 'الإجمالي',

  // Payments on an invoice. Receipts settle the client's invoices oldest
  // first, so part of a payment can sit on another invoice or as credit.
  'Payments received': 'الدفعات المقبوضة',
  'from payment on {0}': 'من دفعة مسجّلة على {0}',
  'another invoice': 'فاتورة أخرى',
  'set off from advance on payment term': 'خُصم من مبلغ مقبوض مسبقاً على دفعة',
  'set off from money on account': 'خُصم من مبلغ مقبوض على الحساب',
  'No payments yet.': 'لا دفعات بعد.',
  'Remove payment': 'إزالة الدفعة',
  'Balance due: {0}': 'الرصيد المستحق: {0}',
  '{0} to {1}': '{0} إلى {1}',
  '{0} held as credit': '{0} رصيد دائن محفوظ',
  'Terms and conditions': 'الشروط والأحكام',
  'Notes (printed on the PDF)': 'ملاحظات (تُطبع في ملف PDF)',

  // Payment schedule of a quotation.
  'Payment terms': 'جدول الدفعات',
  'Edit the instalments': 'تعديل الدفعات',
  'Instalment {0}': 'الدفعة {0}',
  'e.g. Advance payment': 'مثلاً: دفعة مقدّمة',
  'Has receipts or invoices': 'عليها إيصالات أو فواتير',
  'Remove instalment': 'إزالة الدفعة',
  'Share': 'النسبة',
  'or fixed amount': 'أو مبلغ ثابت',
  'When due': 'موعد الاستحقاق',
  'e.g. On signing the agreement': 'مثلاً: عند توقيع الاتفاقية',
  'Add instalment': 'إضافة دفعة',
  'Standard payment terms': 'جداول الدفعات المعتادة',
  'Standard': 'جدول معتاد',
  'The instalments add up to {0}, not the quotation total of {1}.':
      'مجموع الدفعات {0}، وهو لا يساوي مجموع عرض السعر البالغ {1}.',
  'Instalments add up to the quotation total{0}.':
      'مجموع الدفعات يساوي مجموع عرض السعر{0}.',

  // Progress invoice dialog.
  'Bill a share of every item in this quotation. You can adjust each line '
          'on the invoice afterwards.':
      'فوترة نسبة من كل بند في عرض السعر هذا. يمكنك تعديل كل بند في '
      'الفاتورة لاحقاً.',
  'Percent to bill': 'النسبة المراد فوترتها',
  'Create invoice': 'إنشاء الفاتورة',

  // BOQ library picker.
  'AK BOQ library': 'مكتبة جدول الكميات AK',
  'Search, e.g. porcelain, block, AC': 'ابحث، مثلاً: بورسلان، بلوك، تكييف',
  'last rate {0}': 'آخر سعر {0}',
  'Add': 'إضافة',
  'Add {0}': 'إضافة {0}',
  '{0} of {1} chosen': 'تم اختيار {0} من {1}',

  // Paste items.
  'Paste rows from Excel, or a BOQ written for you in the chat. One item '
          'per line: description, unit, quantity, rate. A line with only a '
          'name starts a new section.':
      'الصق صفوفاً من Excel، أو جدول كميات كُتب لك في المحادثة. بند واحد '
      'في كل سطر: الوصف، الوحدة، الكمية، السعر. السطر الذي يحوي اسماً فقط '
      'يبدأ قسماً جديداً.',
  'Masonry\n'
          'Block wall 20 cm | m² | 120 | 18\n'
          'Block wall 10 cm | m² | 85 | 14':
      'أعمال البناء\n'
      'جدار بلوك 20 سم | م² | 120 | 18\n'
      'جدار بلوك 10 سم | م² | 85 | 14',
  'No items found yet.': 'لم يُعثر على أي بند بعد.',
  '1 item found': 'تم العثور على بند واحد',
  '{0} items found': 'البنود المعثور عليها: {0}',
  'Add items': 'إضافة البنود',

  // ------------------------------------------------------ Receipts --
  'Receipt {0} saved': 'تم حفظ الإيصال {0}',
  'New receipt': 'إيصال جديد',
  'Received from': 'استلمنا من',
  'All projects of this client': 'كل مشاريع هذا العميل',
  'Received against': 'مقبوض مقابل',
  'No unpaid invoices for this client.': 'لا فواتير غير مدفوعة لهذا العميل.',
  '{0} due': 'مستحق {0}',
  'draft': 'مسودة',
  'Choose the invoice': 'اختر الفاتورة',
  'No open payment terms. Add the payment terms on the approved quotation '
          'first.':
      'لا دفعات مفتوحة. أضف جدول الدفعات إلى عرض السعر المعتمد أولاً.',
  '{0} left': 'المتبقي {0}',
  'Choose the payment term': 'اختر الدفعة التعاقدية',
  'Money received without a specific invoice, for example a deposit. It is '
          "set against this client's open invoices automatically, oldest "
          'first, and the rest stays as credit on the account.':
      'مبلغ مقبوض من دون فاتورة محدّدة، كعربون مثلاً. يُخصم تلقائياً من '
      'فواتير هذا العميل المفتوحة، الأقدم أولاً، ويبقى الباقي رصيداً دائناً '
      'على الحساب.',
  'Amount received': 'المبلغ المقبوض',
  'Enter the amount': 'أدخل المبلغ',
  'Nothing left to collect here': 'لم يبقَ ما يُحصَّل هنا',
  'Only {0} is due. Record the extra on account.':
      'المستحق {0} فقط. سجّل الزيادة على الحساب.',
  'Date received': 'تاريخ القبض',
  'Method': 'طريقة الدفع',
  'Cheque number and bank': 'رقم الشيك والمصرف',
  'Transfer reference': 'مرجع التحويل',
  'Card slip number': 'رقم إيصال البطاقة',
  'Reference (optional)': 'المرجع (اختياري)',
  'Received for': 'المبلغ لقاء',
  'Notes (printed on the receipt)': 'ملاحظات (تُطبع على الإيصال)',
  'e.g. Deposit before the design agreement':
      'مثلاً: عربون قبل اتفاقية التصميم',
  'Say what the money is for': 'اذكر لقاء ماذا قُبض المبلغ',

  // Where the invoice or payment term stands before the receipt.
  'Invoice total': 'إجمالي الفاتورة',
  'Includes {0} set off from other payments of the client.':
      'يشمل {0} من دفعات أخرى للعميل خُصمت من هذه الفاتورة.',
  'Payments settle the oldest invoices first, so {0} is paid before {1}.':
      'تُسدِّد الدفعات الفواتير الأقدم أولاً، لذا تُسدَّد الفاتورة {0} قبل '
      '{1}.',
  'Payments settle the oldest invoices first, so {0} are paid before {1}.':
      'تُسدِّد الدفعات الفواتير الأقدم أولاً، لذا تُسدَّد الفواتير {0} قبل '
      '{1}.',
  'Contract value ({0})': 'قيمة العقد ({0})',
  'Instalment value': 'قيمة الدفعة',
  'This receipt settles the open invoices oldest first: {0}.':
      'يسدّد هذا الإيصال الفواتير المفتوحة، الأقدم أولاً: {0}.',
  'Due: {0}.': 'الاستحقاق: {0}.',

  // Receipt lists and details.
  '{0} of {1}': '{0} من {1}',
  'set against {0}': 'خُصم من {0}',
  '{0} credit left': '{0} رصيد دائن متبقٍ',
  'Advance': 'دفعة مقدّمة',
  'Term': 'دفعة تعاقدية',
  'RECEIPT {0}': 'إيصال {0}',
  'Set against': 'خُصم من',
  'Credit left': 'الرصيد الدائن المتبقي',
  '{0} on the account': '{0} على الحساب',
  'None, fully set against invoices': 'لا شيء، خُصم بالكامل من الفواتير',
  'Open invoice': 'فتح الفاتورة',
  'Delete receipt {0}?': 'حذف الإيصال {0}؟',
  'A receipt is proof of money received. Delete it only if it was recorded '
          'by mistake.':
      'الإيصال إثبات لمبلغ مقبوض. لا تحذفه إلا إذا سُجّل عن طريق الخطأ.',

  // Payment term tile.
  'Payment {0}': 'الدفعة {0}',
  'Received in full': 'قُبض بالكامل',
  'Received {0} · Remaining {1}': 'المقبوض {0} · المتبقي {1}',
  'Receive': 'قبض',

  // ------------------------- Written into documents (repository.dart) --
  '{0} as per {1}': '{0} بموجب {1}',
  'Progress invoice {0}% of {1}': 'فاتورة مرحلية {0}% من {1}',
  'Was on {0}': 'كان مسجّلاً على {0}',
};
