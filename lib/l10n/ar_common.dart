// Arabic wording for the common texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
const arCommon = <String, String>{
  // ---------------------------------------------------- Due dates (format) --
  'No date': 'بلا تاريخ',
  'Today': 'اليوم',
  'Tomorrow': 'غداً',
  '1 day late': 'متأخر يوماً واحداً',
  '2 days late': 'متأخر يومين',
  '{0} days late': 'أيام التأخير: {0}',
  'In 2 days': 'بعد يومين',
  'In {0} days': 'بعد {0} أيام',
  'Due today': 'الموعد اليوم',
  'Due tomorrow': 'الموعد غداً',
  'Due in 2 days': 'الموعد بعد يومين',
  'Due in {0} days': 'الموعد بعد {0} أيام',
  'Due {0}': 'الموعد {0}',

  // ------------------------------------------------- Labels (format.dart) --
  // Services
  'Design': 'تصميم',
  'Consultancy': 'استشارات',
  'Contracting': 'مقاولات',
  // Project status
  'Lead': 'مشروع محتمل',
  'Active': 'نشط',
  'On hold': 'متوقف مؤقتاً',
  'Completed': 'منجز',
  'Cancelled': 'ملغى',
  // Task status
  'To do': 'للتنفيذ',
  'In progress': 'قيد التنفيذ',
  'Done': 'منجزة',
  // Priority
  'Low': 'منخفضة',
  'Normal': 'عادية',
  'High': 'عالية',
  // Deliverable status
  'Draft': 'مسودة',
  'Internal review': 'مراجعة داخلية',
  'Submitted to client': 'مُرسل إلى العميل',
  'Approved': 'معتمد',
  'Client asked for changes': 'طلب العميل تعديلات',
  'In review': 'قيد المراجعة',
  'With client': 'لدى العميل',
  'Changes': 'تعديلات',
  // Roles
  'Owner': 'المالك',
  'Architect': 'المهندس المعماري',
  // Project types
  'Residential': 'سكني',
  'Commercial / office': 'تجاري / مكاتب',
  'Hospitality': 'ضيافة وفنادق',
  'Interior fit-out': 'تجهيز داخلي',
  'Mixed-use': 'متعدد الاستخدامات',
  'Industrial': 'صناعي',
  'Landscape': 'تنسيق الحدائق',
  'Other': 'أخرى',
  // Task categories
  'Drawings': 'مخططات',
  'Site visit': 'زيارة موقع',
  'Meeting': 'اجتماع',
  'Coordination': 'تنسيق',
  'Admin': 'أعمال إدارية',
  // Disciplines
  'Architecture': 'عمارة',
  'Interior design': 'تصميم داخلي',
  'Structure': 'إنشاءات',
  'MEP': 'كهروميكانيك',
  'General': 'عام',
  // Document types
  'Drawing': 'مخطط',
  'Report': 'تقرير',
  'Presentation': 'عرض تقديمي',
  '3D model / render': 'نموذج ثلاثي الأبعاد / إظهار',
  'Bill of quantities': 'جدول الكميات',
  'Specification': 'مواصفات فنية',
  'Letter / transmittal': 'رسالة / كتاب إحالة',
  // Quotation status
  'Sent': 'مُرسل',
  'Rejected': 'مرفوض',
  // Payment state
  'Unpaid': 'غير مدفوعة',
  'Part paid': 'مدفوعة جزئياً',
  'Paid': 'مدفوعة',
  'Overdue': 'متأخرة',
  // Payment methods
  'Bank transfer': 'تحويل مصرفي',
  'Cash': 'نقداً',
  'Cheque': 'شيك',
  'Card': 'بطاقة',
  // Expense categories
  'Materials': 'مواد',
  'Subcontractor': 'مقاول فرعي',
  'Labour (daily workers)': 'عمالة (عمّال مياومون)',
  'Equipment and tool rental': 'استئجار معدات وأدوات',
  'Salaries and fees to team': 'رواتب وأتعاب الفريق',
  'Office rent and utilities': 'إيجار المكتب والخدمات',
  'Software and licences': 'برامج وتراخيص',
  'Transport and site visits': 'نقل وزيارات مواقع',
  'Printing and models': 'طباعة ومجسّمات',
  'Marketing': 'تسويق',
  'Permits and official fees': 'تراخيص ورسوم رسمية',

  // ------------------------------------------ Preset stages (stored English) --
  // Design (defaultStages in lib/data/models.dart)
  'Brief': 'دراسة المتطلبات',
  'Concept design': 'التصميم المبدئي',
  'Schematic design': 'التصميم التخطيطي',
  'Design development': 'تطوير التصميم',
  'Permit': 'الترخيص',
  'Construction drawings': 'المخططات التنفيذية',
  'Tender': 'المناقصة',
  'Site supervision': 'الإشراف على التنفيذ',
  // Consultancy (serviceStages in lib/data/finance.dart)
  'Inquiry and scope': 'الاستفسار وتحديد النطاق',
  'Proposal and agreement': 'العرض والاتفاق',
  'Site visit and survey': 'زيارة الموقع والمسح',
  'Review and analysis': 'المراجعة والتحليل',
  'Recommendations report': 'تقرير التوصيات',
  'Client meeting': 'اجتماع مع العميل',
  'Final report': 'التقرير النهائي',
  'Follow-up': 'المتابعة',
  // Contracting (serviceStages in lib/data/finance.dart)
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
  // Default client country (stored English)
  'Lebanon': 'لبنان',

  // ------------------------------------------------- To cover (advisor.dart) --
  'No client linked': 'لا يوجد عميل مرتبط',
  'link the client.': 'اربط العميل بالمشروع.',
  'Client contact missing': 'بيانات تواصل العميل ناقصة',
  'add a phone or email for {0}.':
      'أضف رقم هاتف أو بريداً إلكترونياً للعميل {0}.',
  'No deadline': 'لا يوجد موعد نهائي',
  'set the delivery deadline.': 'حدّد الموعد النهائي للتسليم.',
  'Deadline passed': 'انقضى الموعد النهائي',
  'the deadline was {0} days ago. Agree a new date or close the project.':
      'الأيام المنقضية منذ الموعد النهائي: {0}. اتفق على موعد جديد أو أغلق '
      'المشروع.',
  'No site location': 'لا يوجد موقع للمشروع',
  'add the Google Maps pin.': 'أضف الموقع على خرائط Google.',
  'No map pin': 'لا يوجد موقع على الخريطة',
  'add the exact Google Maps pin.': 'أضف الموقع الدقيق على خرائط Google.',
  'Area not recorded': 'المساحة غير مسجّلة',
  'add the built-up area in m² (needed for fees and BOQ).':
      'أضف المساحة المبنية بالـ m² (لازمة للأتعاب وجدول الكميات).',
  'No current stage': 'لا توجد مرحلة حالية',
  'set the stage.': 'حدّد المرحلة.',
  'No team assigned': 'لم يُعيَّن فريق',
  'add the architect to it.': 'أضف المهندس المعماري إلى المشروع.',
  '1 late task': 'مهمة متأخرة واحدة',
  '{0} late tasks': 'المهام المتأخرة: {0}',
  'follow up or move the dates.': 'تابِعها أو عدّل التواريخ.',
  'No open tasks': 'لا توجد مهام مفتوحة',
  'plan the next tasks for the current stage.':
      'خطّط للمهام التالية في المرحلة الحالية.',
  'plan the next tasks for the {0} stage.': 'خطّط للمهام التالية في مرحلة {0}.',
  '1 task without a date': 'مهمة واحدة بلا تاريخ',
  '{0} tasks without a date': 'مهام بلا تاريخ: {0}',
  'give each task a due date.': 'حدّد موعداً لكل مهمة.',
  'Waiting on client': 'بانتظار العميل',
  '"{0}" was sent {1} days ago with no answer. Call the client.':
      'أُرسل «{0}» منذ {1} يوماً من دون رد. اتصل بالعميل.',
  'start revision R{0} of "{1}".': 'ابدأ المراجعة R{0} للمستند «{1}».',
  'No quotation': 'لا يوجد عرض سعر',
  'send a fee quotation before work goes further.':
      'أرسل عرض سعر بالأتعاب قبل التقدّم في العمل.',
  'Quotation unanswered': 'عرض سعر بلا رد',
  '{0} was sent {1} days ago. Follow up.':
      'أُرسل {0} منذ {1} يوماً. تابِع الأمر.',
  'Quotation expired': 'انتهت صلاحية عرض السعر',
  '{0} is past its validity date.': 'تجاوز {0} تاريخ صلاحيته.',
  'Approved but not invoiced': 'معتمد ولم تصدر فاتورة',
  'issue the first invoice (advance payment).':
      'أصدر الفاتورة الأولى (الدفعة المقدّمة).',
  'Invoice overdue': 'فاتورة متأخرة',
  '{0}: {1} not paid.': '{0}: مبلغ {1} غير مدفوع.',
  'Invoice still a draft': 'الفاتورة ما زالت مسودة',
  '{0} has not been issued.': 'لم تُصدَر الفاتورة {0} بعد.',
  'Company details incomplete': 'بيانات الشركة ناقصة',
  'Add phone and email in Settings so they print on quotations.':
      'أضف الهاتف والبريد الإلكتروني في الإعدادات لتظهر على عروض الأسعار.',
  'Quotation number used twice': 'رقم عرض سعر مستخدم مرتين',
  'Invoice number used twice': 'رقم فاتورة مستخدم مرتين',
  'Receipt number used twice': 'رقم إيصال مستخدم مرتين',
  '{0} is on two documents. Give one of them a new number before sending it.':
      'الرقم {0} موجود على مستندين. أعطِ أحدهما رقماً جديداً قبل إرساله.',
  'Bank details missing': 'البيانات المصرفية ناقصة',
  'Add bank details in Settings so clients know how to pay.':
      'أضف البيانات المصرفية في الإعدادات ليعرف العملاء كيفية الدفع.',
  'Lead going cold': 'مشروع محتمل بلا متابعة',
  '{0} has been a lead for {1} days. Follow up or mark it cancelled.':
      'ما زال {0} مشروعاً محتملاً منذ {1} يوماً. تابِعه أو حدّده كملغى.',

  // ------------------------------------------------------------- Overview --
  'Good morning, {0}': 'صباح الخير، {0}',
  'Good afternoon, {0}': 'نهارك سعيد، {0}',
  'Good evening, {0}': 'مساء الخير، {0}',
  'Start by adding a client and a project. Everything else, tasks, '
          'deliverables and deadlines, hangs off the project.':
      'ابدأ بإضافة عميل ومشروع. كل ما عدا ذلك، من مهام وتسليمات ومواعيد، '
      'يتفرّع من المشروع.',
  'You will see your projects here once you are added to one.':
      'ستظهر مشاريعك هنا بعد إضافتك إلى أحدها.',
  'Nothing is late. {0} due this week.':
      'لا شيء متأخر. المستحق هذا الأسبوع: {0}.',
  '1 late item needs attention.': 'بند متأخر واحد يحتاج إلى متابعة.',
  '{0} late items need attention.': 'بنود متأخرة تحتاج إلى متابعة: {0}.',
  'Active projects': 'مشاريع نشطة',
  'Open tasks': 'مهام مفتوحة',
  'Late': 'متأخرة',
  'With clients': 'لدى العملاء',
  'To collect · {0}': 'للتحصيل · {0}',
  'Due in the next 7 days': 'المستحق خلال الأيام السبعة المقبلة',
  'Nothing due this week.': 'لا شيء مستحق هذا الأسبوع.',
  'Waiting for client approval': 'بانتظار موافقة العميل',
  'To cover': 'للمتابعة',
  'See all {0}': 'عرض الكل ({0})',

  // ---------------------------------------------------------------- Lists --
  'Project': 'مشروع',
  'Search by name, code or client': 'ابحث بالاسم أو الرمز أو العميل',
  'Current': 'الحالية',
  'Leads': 'المحتملة',
  'Finished': 'المنتهية',
  'All': 'الكل',
  'No projects here': 'لا توجد مشاريع هنا',
  'Tap "Project" to add your first one.': 'اضغط «مشروع» لإضافة أول مشروع.',
  'Projects you are added to appear here.':
      'تظهر هنا المشاريع التي تُضاف إليها.',
  'Tasks': 'المهام',
  'Deliverables': 'التسليمات',
  'Task': 'مهمة',
  'Mine': 'مهامي',
  'All open': 'كل المفتوحة',
  'Nothing is late': 'لا شيء متأخر',
  'No finished tasks yet': 'لا توجد مهام منجزة بعد',
  'Create a project first, then add its tasks.':
      'أنشئ مشروعاً أولاً، ثم أضف مهامه.',
  'Deliverable': 'تسليم',
  'All {0}': 'الكل {0}',
  'No deliverables here': 'لا توجد تسليمات هنا',
  'Track every drawing set and report you send a client.':
      'تابِع كل مجموعة مخططات وكل تقرير ترسله إلى العميل.',

  // -------------------------------------------------- Assistant / To cover --
  'New design project: villa in Byblos for Nadim Haddad, 450 m², '
          'deadline end of March':
      'مشروع تصميم جديد: فيلا في جبيل لنديم حداد، 450 m²، الموعد النهائي '
      'آخر آذار',
  'Make a quotation for the villa: concept 3,000, permit drawings 5,000, '
          'execution drawings 7,000':
      'أعدّ عرض سعر للفيلا: التصميم المبدئي 3,000، مخططات الترخيص 5,000، '
      'المخططات التنفيذية 7,000',
  'Received 2,000 from Nadim by bank transfer':
      'تم استلام 2,000 من نديم بتحويل مصرفي',
  'What am I missing?': 'ما الذي ينقصني؟',
  'AK Assistant': 'مساعد AK',
  'New conversation': 'محادثة جديدة',
  'AI key': 'مفتاح الذكاء الاصطناعي',
  'What is missing, late or waiting across your projects. Tap an item to '
          'open the project and fix it.':
      'ما هو ناقص أو متأخر أو معلّق في مشاريعك. اضغط على أي بند لفتح المشروع '
      'ومعالجته.',
  'To cover ({0})': 'للمتابعة ({0})',
  'Nothing missing right now.': 'لا نواقص حالياً.',
  'Working on it…': 'جارٍ العمل…',
  'Tell me what to do…': 'قل لي ماذا أفعل…',
  'Add your AI key to start': 'أضف مفتاح الذكاء الاصطناعي للبدء',
  'Send': 'إرسال',
  'Tell it, and it is done': 'قل ما تريد، ويُنجَز',
  'Write or dictate what you need: a new client or project, tasks for the '
          'team, a quotation, an invoice, a payment received. The assistant '
          'enters it in the app and asks about anything you missed.':
      'اكتب أو أملِ ما تحتاج إليه: عميل أو مشروع جديد، مهام للفريق، عرض سعر، '
      'فاتورة، دفعة مقبوضة. يُدخل المساعد ذلك في التطبيق ويسألك عن أي شيء '
      'فاتك.',
  'Add AI key': 'إضافة مفتاح الذكاء الاصطناعي',
  'The assistant uses Claude. Create a key at console.anthropic.com (API '
          'keys), add a small prepaid credit, and paste the key here. You pay '
          'only for what you use. The key stays on this device.':
      'يعمل المساعد بواسطة Claude. أنشئ مفتاحاً على console.anthropic.com '
      '(API keys)، وأضف رصيداً صغيراً مسبق الدفع، ثم الصق المفتاح هنا. تدفع '
      'فقط مقابل ما تستخدمه. يبقى المفتاح على هذا الجهاز.',
  'Open the Claude console': 'فتح لوحة تحكم Claude',
  'Key (starts with sk-ant-)': 'المفتاح (يبدأ بـ sk-ant-)',
  'Remove key': 'إزالة المفتاح',
  'Cancel': 'إلغاء',
  'Save': 'حفظ',
};
