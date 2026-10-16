// Arabic wording for the documents texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
const arDocuments = <String, String>{
  // Words shared with the screens (same Arabic as there)
  'Amount': 'المبلغ',
  'Balance due': 'الرصيد المستحق',
  'Contract value': 'قيمة العقد',
  'Credit': 'رصيد دائن',
  'Credit@@column': 'دائن',
  'Prices in US dollars. Payment due within 14 days of the invoice date. '
          'Quotation valid for 30 days.':
      'الأسعار بالدولار الأميركي. تُستحق الدفعة خلال 14 يوماً من تاريخ '
      'الفاتورة. عرض السعر صالح لمدة 30 يوماً.',
  'Date': 'التاريخ',
  'Description': 'الوصف',
  'Discount': 'حسم',
  'Due on invoices': 'المستحق على الفواتير',
  'General': 'عام',
  'Invoice': 'فاتورة',
  'Invoice total': 'إجمالي الفاتورة',
  'Invoiced': 'المفوتر',
  'Item': 'بند',
  'Late': 'متأخرة',
  'Location': 'الموقع',
  'Method': 'طريقة الدفع',
  'Notes': 'ملاحظات',
  'On account': 'على الحساب',
  'Paid': 'مدفوعة',
  'Payment {0}': 'الدفعة {0}',
  'Project': 'المشروع',
  'Qty': 'الكمية',
  'Quotation': 'عرض سعر',
  'Rate': 'السعر',
  'Receipt': 'إيصال',
  'Received': 'المقبوض',
  'Reference': 'المرجع',
  'Remaining': 'المتبقي',
  'Share': 'النسبة',
  'Subject': 'الموضوع',
  'Total': 'الإجمالي',
  'Unit': 'الوحدة',
  '{0} of {1}': '{0} من {1}',

  // Page header and footer
  'Design · Consultancy · Contracting': 'تصميم · استشارات · مقاولات',
  'Page {0} of {1}': 'صفحة {0} من {1}',
  'As of {0}': 'بتاريخ {0}',

  // Quotations and invoices
  'INVOICE': 'فاتورة',
  'QUOTATION': 'عرض سعر',
  'Bill to': 'العميل',
  'Prepared for': 'مقدّم إلى',
  'Payment due': 'تاريخ الاستحقاق',
  'Valid until': 'صالح حتى',
  'VAT no.': 'الرقم الضريبي',
  'Cost subtotal': 'مجموع الكلفة',
  'Cost-plus fee {0}%': 'نسبة الأتعاب فوق الكلفة {0}%',
  'Subtotal': 'المجموع الفرعي',
  'VAT {0}%': 'الضريبة على القيمة المضافة {0}%',
  'Total (USD)': 'الإجمالي (دولار أميركي)',
  'Set off from other payments': 'مخصوم من دفعات أخرى',
  'Payment schedule': 'جدول الدفعات',
  'Payment details': 'تفاصيل الدفع',
  'Terms and conditions': 'الشروط والأحكام',
  'For {0}': 'عن {0}',
  'Client acceptance': 'موافقة العميل',
  'Name, signature and date': 'الاسم والتوقيع والتاريخ',
  'Instalment': 'الدفعة',
  'Due': 'الاستحقاق',
  'Total {0}': 'مجموع {0}',
  'general': 'الأعمال العامة',

  // Statements of account
  'STATEMENT': 'كشف حساب',
  'Statement of account {0}': 'كشف حساب {0}',
  'Statement of account for': 'كشف حساب العميل',
  'Period': 'الفترة',
  'All to {0}': 'من البداية حتى {0}',
  'All projects': 'كل المشاريع',
  'Currency': 'العملة',
  'Agreed contract': 'العقد المتفق عليه',
  'Opening balance': 'الرصيد الافتتاحي',
  'Closing balance': 'الرصيد الختامي',
  'Credit held': 'رصيد دائن',
  'Credit balance': 'رصيد دائن',
  'Account movements': 'حركة الحساب',
  'Debit': 'مدين',
  'Balance': 'الرصيد',
  'Open invoices': 'الفواتير غير المسدّدة',
  '{0} days@@late': '{0}',
  'Paid@@column': 'المدفوع',
  'Late@@column': 'أيام التأخير',
  'Not due': 'غير مستحقة',
  'Not yet due': 'لم تستحق بعد',
  '1–30 days': '1–30 يوماً',
  '31–60 days': '31–60 يوماً',
  '61–90 days': '61–90 يوماً',
  '90+ days': 'أكثر من 90 يوماً',
  'Bank details': 'التفاصيل المصرفية',
  '{0} is cancelled, so this receipt is set against the open invoices, '
          'oldest first.':
      'الفاتورة {0} ملغاة، لذا يُخصم هذا الإيصال من الفواتير المفتوحة بدءاً '
      'بالأقدم.',
  '{0} is not issued yet, so this receipt is set against the open '
          'invoices, oldest first.':
      'الفاتورة {0} لم تصدر بعد، لذا يُخصم هذا الإيصال من الفواتير المفتوحة '
      'بدءاً بالأقدم.',
  'credit {0}': 'دائن {0}',
  'Credit held: {0} received and not yet set against an invoice. Every '
          'payment received, as an advance, on account or on an invoice, '
          'settles the issued invoices of the same project oldest first; the '
          'rest is set against the next invoices. Due on issued invoices: {1}. '
          'Net account balance: {2}. Please report any difference within 15 '
          'days of this statement; otherwise it is considered accepted.':
      'رصيد دائن: {0} مقبوض ولم يُخصم بعد من أي فاتورة. كل مبلغ مقبوض، '
      'سواء كان دفعة مقدّمة أو على الحساب أو تسديداً لفاتورة، يسدّد الفواتير '
      'الصادرة للمشروع نفسه بدءاً بالأقدم، ويُخصم الباقي من الفواتير التالية. '
      'المستحق على الفواتير الصادرة: {1}. صافي رصيد الحساب: {2}. في حال وجود '
      'أي فرق، يُرجى إبلاغنا خلال 15 يوماً من تاريخ هذا الكشف، وإلا يُعتبر '
      'مقبولاً.',
  'Kindly settle the balance due of {0}. Please report any difference '
          'within 15 days of this statement; otherwise it is considered '
          'accepted.':
      'يُرجى تسديد الرصيد المستحق البالغ {0}. في حال وجود أي فرق، يُرجى '
      'إبلاغنا خلال 15 يوماً من تاريخ هذا الكشف، وإلا يُعتبر الكشف مقبولاً.',
  'Your account is in credit by {0}. Please report any difference within '
          '15 days of this statement; otherwise it is considered accepted.':
      'لحسابكم رصيد دائن بقيمة {0}. في حال وجود أي فرق، يُرجى إبلاغنا خلال '
      '15 يوماً من تاريخ هذا الكشف، وإلا يُعتبر الكشف مقبولاً.',
  'Your account is fully settled. Thank you.':
      'حسابكم مسدّد بالكامل. شكراً لكم.',
  'Client confirmation': 'مصادقة العميل',

  // Statement lines and what a receipt pays for
  'Set off from {0} · {1}': 'مخصوم من {0} · {1}',
  'Credit set against {0} · {1}': 'رصيد مُستخدم لتسديد {0} · {1}',
  'not on a project': 'خارج المشاريع',
  'project {0}': 'المشروع {0}',
  'bank transfer': 'تحويل مصرفي',
  'cash': 'نقداً',
  'cheque': 'شيك',
  'card': 'بطاقة',
  'other': 'طريقة أخرى',
  'on account': 'على الحساب',
  'on account · {0}': 'على الحساب · {0}',
  'on {0}': 'عن {0}',
  'on {0} ({1}), held as credit': 'عن {0} ({1})، محفوظة كرصيد دائن',
  'cancelled': 'ملغاة',
  'draft': 'مسودة',

  // Receipts
  'RECEIPT': 'إيصال',
  'Received from': 'استلمنا من',
  'Receipt no.': 'رقم الإيصال',
  'Payment for': 'موضوع الدفعة',
  'AMOUNT RECEIVED': 'المبلغ المقبوض',
  'Invoice {0}': 'الفاتورة {0}',
  'Received before': 'المقبوض سابقاً',
  'This receipt': 'هذا الإيصال',
  '{0} is now fully paid. Thank you.':
      'سُدّدت الفاتورة {0} بالكامل. شكراً لكم.',
  'Remaining on {0}: {1}.': 'المتبقي على الفاتورة {0}: {1}.',
  'Open invoices are settled oldest first, so {0} of this receipt went '
          'to {1}.':
      'تُسدَّد الفواتير المفتوحة بدءاً بالأقدم، لذا خُصّص {0} من هذا '
      'الإيصال لتسديد {1}.',
  'The extra {0} is held as credit on the account.':
      'المبلغ الزائد {0} محفوظ كرصيد دائن في الحساب.',
  'Instalment value': 'قيمة الدفعة',
  'As per the payment schedule of {0}, contract value {1}.':
      'وفقاً لجدول دفعات عرض السعر {0}، وقيمة العقد {1}.',
  'As per the payment schedule of {0} ({1}), contract value {2}.':
      'وفقاً لجدول دفعات عرض السعر {0} – {1}، وقيمة العقد {2}.',
  'This instalment is now fully paid.': 'سُدّدت هذه الدفعة بالكامل.',
  'Remaining on this instalment: {0}.': 'المتبقي من هذه الدفعة: {0}.',
  'Money received earlier ({0}) that counted on this instalment now '
          'settles other open invoices.':
      'المبلغ المقبوض سابقاً ({0}) الذي كان محسوباً على هذه الدفعة يسدّد الآن '
      'فواتير مفتوحة أخرى.',
  'Payment on account': 'دفعة على الحساب',
  'Received on account. It is set against the open invoices{0}, oldest '
          'first; any balance stays as credit on the account.':
      'مقبوضة على الحساب. تُخصم من الفواتير المفتوحة{0} بدءاً بالأقدم، '
      'ويبقى أي فائض رصيداً دائناً في الحساب.',
  ' of {0}': ' للمشروع {0}',
  'How this receipt was used · as of {0}': 'توزيع هذا الإيصال · بتاريخ {0}',
  'Amount set off': 'المبلغ المخصوم',
  'Credit remaining on account': 'الرصيد الدائن المتبقي في الحساب',
  'Credit held for the next invoices': 'رصيد دائن محفوظ للفواتير التالية',
  'Project account after this receipt · {0}':
      'حساب المشروع بعد هذا الإيصال · {0}',
  'Received to date': 'المقبوض حتى تاريخه',
  'Remaining on contract': 'المتبقي من العقد',
  'Payment by cheque is valid subject to collection.':
      'الدفع بشيك لا يُعتبر نهائياً إلا بعد تحصيل قيمته.',
  'Received by (name and signature)': 'المستلم (الاسم والتوقيع)',

  // Project statements
  'PROJECT STATEMENT': 'كشف حساب مشروع',
  'Project statement {0}': 'كشف حساب المشروع {0}',
  'Name': 'الاسم',
  'Phase': 'المرحلة',
  'Not linked to a phase': 'غير مرتبطة بمرحلة',
  '(current)': '(الحالية)',
  'Credit not yet set off': 'رصيد دائن لم يُخصم بعد',
  'Billed': 'الفوترة',
  '1 · By phase': '1 · حسب المرحلة',
  'Tasks done': 'مهام منجزة',
  'Done': 'منجزة',
  'In progress': 'قيد التنفيذ',
  'To do': 'للتنفيذ',
  '{0} · paid {1}': '{0} · المدفوع {1}',
  '2 · Payment schedule': '2 · جدول الدفعات',
  'Value': 'القيمة',
  '{0} · By trade and item (before VAT, fee included)':
      '{0} · حسب نوع الأعمال والبند (قبل الضريبة، شاملاً الأتعاب)',
  'Contract': 'العقد',
  'Total before VAT': 'الإجمالي قبل الضريبة على القيمة المضافة',
  '{0} · Account movements': '{0} · حركة الحساب',
  'Due on issued invoices: {0}. Credit of {1} is held on this project: '
          'every payment received settles the issued invoices oldest first, '
          'and the rest is set against the next invoices. Net account '
          'balance: {2}. Please report any difference within 15 days of this '
          'statement.':
      'المستحق على الفواتير الصادرة: {0}. رصيد دائن بقيمة {1} محفوظ لهذا '
      'المشروع: كل مبلغ مقبوض يسدّد الفواتير الصادرة بدءاً بالأقدم، ويُخصم '
      'الباقي من الفواتير التالية. صافي رصيد الحساب: {2}. في حال وجود أي '
      'فرق، يُرجى إبلاغنا خلال 15 يوماً من تاريخ هذا الكشف.',
  'Balance due: {0}. Please report any difference within 15 days of this '
          'statement.':
      'الرصيد المستحق: {0}. في حال وجود أي فرق، يُرجى إبلاغنا خلال 15 '
      'يوماً من تاريخ هذا الكشف.',
  'The project account is in credit by {0}.':
      'لحساب المشروع رصيد دائن بقيمة {0}.',
  'The project account is fully settled. Thank you.':
      'حساب المشروع مسدّد بالكامل. شكراً لكم.',
  'Statement@@file': 'كشف-حساب',
};
