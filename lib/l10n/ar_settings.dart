// Arabic wording for the settings texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
const arSettings = <String, String>{
  'Language': 'اللغة',
  'Screens': 'الشاشات',
  'Quotations, invoices and receipts': 'عروض الأسعار والفواتير والإيصالات',
  'Each person chooses the language of their own screens. '
          'Documents print in the language chosen here.':
      'يختار كل مستخدم لغة شاشاته. تُطبع المستندات باللغة المختارة هنا.',

  // Common buttons.
  'Cancel': 'إلغاء',
  'Save': 'حفظ',
  'Delete': 'حذف',
  'Close': 'إغلاق',
  'Remove': 'إزالة',
  'Create': 'إنشاء',
  'Try again': 'إعادة المحاولة',
  'Not set': 'غير محدد',

  // App frame and navigation.
  'Overview': 'نظرة عامة',
  'Projects': 'المشاريع',
  'Work': 'العمل',
  'Clients': 'العملاء',
  'Finance': 'المالية',
  'To cover': 'للمتابعة',
  'Settings': 'الإعدادات',
  'DESIGN · CONSULTANCY · CONTRACTING': 'تصميم · استشارات · مقاولات',

  // Shared widgets.
  'Clear date': 'مسح التاريخ',
  'Saved on this device. Set up cloud sync in Settings.':
      'محفوظ على هذا الجهاز. فعّل المزامنة السحابية من الإعدادات.',
  'All changes synced': 'تمت مزامنة كل التغييرات',
  'Syncing…': 'جارٍ المزامنة…',
  'Offline. Changes are saved and will sync when you reconnect.':
      'غير متصل. التغييرات محفوظة وستتم مزامنتها عند عودة الاتصال.',
  'Sync problem: {0}': 'مشكلة في المزامنة: {0}',
  'unknown': 'غير معروفة',
  'Delete {0}?': 'حذف {0}؟',
  'This cannot be undone.': 'لا يمكن التراجع عن ذلك.',
  'Sent {0}': 'أُرسل في {0}',
  'No stage set': 'لم تُحدَّد مرحلة',
  'Stage {0} of {1} · {2}': 'المرحلة {0} من {1} · {2}',
  '{0} open': 'مفتوحة: {0}',
  '{0} late': 'متأخرة: {0}',
  'Deadline {0}': 'الموعد النهائي {0}',

  // Settings sections.
  'Cloud sync and login': 'المزامنة السحابية وتسجيل الدخول',
  'Team': 'الفريق',
  'Project stages': 'مراحل المشاريع',
  'Company': 'الشركة',
  'Document colours': 'ألوان المستندات',
  'About': 'حول التطبيق',
  'Shown in the app header': 'يظهر في أعلى التطبيق',
  'Company name': 'اسم الشركة',
  'AK System · version {0}': 'AK System · الإصدار {0}',
  'Projects, tasks, deliverables and finance. Works offline; '
          'syncs when online.':
      'المشاريع والمهام والتسليمات والمالية. يعمل دون اتصال، ويزامن '
      'البيانات عند توفّر الإنترنت.',

  // Company details.
  'Address': 'العنوان',
  'Phone': 'الهاتف',
  'Email': 'البريد الإلكتروني',
  'Website': 'الموقع الإلكتروني',
  'WhatsApp': 'واتساب',
  'Instagram': 'إنستغرام',
  'Facebook page link': 'رابط صفحة فيسبوك',
  'LinkedIn page link': 'رابط صفحة لينكدإن',
  'VAT / tax number': 'الرقم الضريبي',
  'Bank details (on invoices)': 'التفاصيل المصرفية (على الفواتير)',
  'Standard terms (on quotations and invoices)':
      'الشروط العامة (على عروض الأسعار والفواتير)',
  'Please choose a logo under 1.5 MB (PNG works best).':
      'يرجى اختيار شعار أصغر من 1.5 MB (يُفضَّل PNG).',
  'Design · Consultancy · Contracting': 'تصميم · استشارات · مقاولات',
  'Upload logo': 'رفع الشعار',
  'Change logo': 'تغيير الشعار',
  'The logo and these details print on every quotation, '
          'invoice and statement.':
      'يُطبع الشعار وهذه التفاصيل على كل عرض سعر وفاتورة وكشف حساب.',

  // Project stages.
  'New stage': 'مرحلة جديدة',
  'Rename stage': 'إعادة تسمية المرحلة',
  'Move up': 'نقل للأعلى',
  'Move down': 'نقل للأسفل',
  'Delete stage': 'حذف المرحلة',
  'A project is at this stage. Move it first.':
      'يوجد مشروع في هذه المرحلة. انقله أولاً.',
  'the stage "{0}"': 'المرحلة "{0}"',
  'Add {0} stage': 'إضافة مرحلة {0}',

  // Team.
  'No team logins yet': 'لا توجد حسابات للفريق بعد',
  'Once cloud sync is set up, each person creates a login from this '
          'screen. The first login becomes the owner; the next ones '
          'join as architects.':
      'بعد إعداد المزامنة السحابية، ينشئ كل شخص حساب دخول من هذه الشاشة. '
      'يصبح أول حساب هو المالك، وتنضم الحسابات التالية بصفة مهندسين '
      'معماريين.',
  '{0} (you)': '{0} (أنت)',

  // Cloud sync and login.
  'Not connected': 'غير متصل',
  'Everything is saved on this device. Connect the company cloud '
          'database to sync between phone and laptop and add your '
          'team.':
      'كل البيانات محفوظة على هذا الجهاز. اربط قاعدة بيانات الشركة '
      'السحابية للمزامنة بين الهاتف والكمبيوتر المحمول ولإضافة فريقك.',
  'Connect': 'ربط',
  'Connected, not signed in': 'متصل، دون تسجيل دخول',
  'Sign in': 'تسجيل الدخول',
  'Offline. Changes are kept on this device until you reconnect.':
      'غير متصل. تبقى التغييرات محفوظة على هذا الجهاز حتى يعود الاتصال.',
  'Signed in': 'تم تسجيل الدخول',
  'Last synced {0}': 'آخر مزامنة {0}',
  'Sync now': 'زامن الآن',
  'Sign out': 'تسجيل الخروج',
  'Connect cloud database': 'ربط قاعدة البيانات السحابية',
  'Paste the Project URL and the anon public key from your '
          'Supabase project (Project Settings > API).':
      'الصق رابط المشروع (Project URL) والمفتاح العام (anon public key) '
      'من مشروعك على Supabase، في Project Settings > API.',
  'Project URL': 'رابط المشروع (Project URL)',
  'Anon public key': 'المفتاح العام (Anon public key)',
  'Enter both the URL and the key.': 'أدخل الرابط والمفتاح معاً.',
  'Login created. Confirm it from the email, then sign in.':
      'تم إنشاء الحساب. أكّده من البريد الإلكتروني، ثم سجّل الدخول.',
  'Create login': 'إنشاء حساب',
  'Your name': 'اسمك',
  'Password': 'كلمة المرور',
  'I already have a login': 'لدي حساب بالفعل',
  'New here? Create a login': 'جديد هنا؟ أنشئ حساباً',
  'The file "{0}" could not be uploaded yet; it will be '
          'tried again. ({1})':
      'تعذّر رفع الملف "{0}" حتى الآن؛ ستُعاد المحاولة لاحقاً. ({1})',

  // Document colours.
  'Own colours': 'ألوان مخصّصة',
  'Main colour: headings, table headers and totals':
      'اللون الرئيسي: العناوين ورؤوس الجداول والمجاميع',
  'Highlight colour: document number and accents':
      'لون الإبراز: رقم المستند واللمسات اللونية',
  'Used on every quotation, invoice, receipt and statement '
          'from now on.':
      'تُستخدم على كل عرض سعر وفاتورة وإيصال وكشف حساب من الآن فصاعداً.',
  'See it on {0}': 'اعرضها على {0}',
  'INVOICE': 'فاتورة',
  'TOTAL': 'الإجمالي',

  // Updates.
  'Updates': 'التحديثات',
  'Checking for updates…': 'جارٍ البحث عن تحديثات…',
  'Downloading version {0}…': 'جارٍ تنزيل الإصدار {0}…',
  'Downloading version {0}… {1}%': 'جارٍ تنزيل الإصدار {0}… {1}%',
  'Installing version {0}…': 'جارٍ تثبيت الإصدار {0}…',
  'AK System will open again in a moment.': 'سيُعاد فتح AK System بعد لحظات.',
  'Installing version {0}. AK System will open again in a moment.':
      'جارٍ تثبيت الإصدار {0}. سيُعاد فتح AK System بعد لحظات.',
  'Version {0} is ready to install': 'الإصدار {0} جاهز للتثبيت',
  'Version {0} of AK System is ready.': 'الإصدار {0} من AK System جاهز.',
  'Your data stays as it is.': 'تبقى بياناتك كما هي.',
  'You have the latest version': 'لديك أحدث إصدار',
  'When a new version is ready you will see it here and at the top '
          'of the app.':
      'عندما يصبح إصدار جديد جاهزاً، ستراه هنا وفي أعلى التطبيق.',
  "What's new": 'ما الجديد',
  "What's new in version {0}": 'ما الجديد في الإصدار {0}',
  'Improvements and fixes.': 'تحسينات وإصلاحات.',
  'Download page': 'صفحة التنزيل',
  'Update now': 'حدّث الآن',
  'Check now': 'ابحث الآن',
  'Later': 'لاحقاً',
  'The update page github.com/{0} cannot be found, so '
          'new versions cannot arrive. Please tell Claude.':
      'تعذّر العثور على صفحة التحديثات github.com/{0}، لذا لا يمكن أن تصل '
      'إصدارات جديدة. يرجى إبلاغ Claude.',
  'Could not check for updates ({0}).': 'تعذّر البحث عن تحديثات ({0}).',
  'Could not check for updates. Check the internet connection.':
      'تعذّر البحث عن تحديثات. تحقّق من الاتصال بالإنترنت.',
  'The download failed ({0}).': 'فشل التنزيل ({0}).',
  'The download was incomplete. Please try again.':
      'لم يكتمل التنزيل. يرجى المحاولة مرة أخرى.',
  'The download was damaged. Please try again.':
      'الملف الذي تم تنزيله تالف. يرجى المحاولة مرة أخرى.',
  'The update could not be downloaded. Check the internet '
          'connection and try again.':
      'تعذّر تنزيل التحديث. تحقّق من الاتصال بالإنترنت وحاول مرة أخرى.',
  'Version {0} was downloaded, but Windows or the '
          'antivirus did not let the installer start. You can '
          'install it from the download page instead.':
      'تم تنزيل الإصدار {0}، لكن Windows أو برنامج مكافحة الفيروسات منع '
      'بدء التثبيت. يمكنك تثبيته من صفحة التنزيل بدلاً من ذلك.',
};
