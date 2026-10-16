// Arabic wording for the boq texts of the app, keyed by the English text.
// Placeholders {0}, {1}… stand for values filled in at run time.
//
// Covers the AK master BOQ library (lib/data/boq_library.dart): trade
// (section) names, group names, item descriptions and units, in the
// construction Arabic used on Lebanese bills of quantities.
const arBoq = <String, String>{
  // Units.
  'lump sum': 'مقطوعة',
  'm²': 'م²',
  'm³': 'م³',
  'lin. m': 'م.ط',
  'no.': 'عدد',
  'point': 'نقطة',
  'set': 'مجموعة',
  'kg': 'كغ',
  'ton': 'طن',
  'month': 'شهر',
  'image': 'صورة',
  'visit': 'زيارة',
  'meeting': 'اجتماع',
  'hour': 'ساعة',
  'certificate': 'كشف',
  'trip': 'نقلة',
  'kWp': 'كيلوواط ذروة',

  // 01 Design services.
  'Design services': 'خدمات التصميم',
  'Survey and brief': 'المسح وبرنامج المتطلبات',
  'Site visit, survey of existing conditions, photographic record and measured drawings of the existing building': 'زيارة الموقع، ومسح الوضع القائم، وتوثيق بالصور، ورفع خرائط المبنى القائم بالقياسات',
  'Topographic survey by licensed surveyor, with levels, boundaries and existing trees':
      'مسح طوبوغرافي من قبل مسّاح محلّف، مع المناسيب والحدود والأشجار القائمة',
  'Client brief, space programme and area schedule, with zoning analysis and regulatory check (exploitation factors, setbacks)': 'متطلبات العميل، والبرنامج الوظيفي للمساحات وجدول المساحات، مع تحليل نظام المنطقة والتحقق من الأنظمة (عوامل الاستثمار، التراجعات)',
  'Architecture': 'عمارة',
  'Concept design: site analysis, design approach, space planning, massing studies and two design options, with presentation': 'التصميم المبدئي: تحليل الموقع، والمقاربة التصميمية، وتخطيط المساحات، ودراسات الكتلة، وخياران تصميميان، مع عرض تقديمي',
  'Schematic design: developed plans, sections and elevations at 1:100, with 3D massing views and outline material palette': 'التصميم التخطيطي: مساقط ومقاطع وواجهات مطوّرة بمقياس 1:100، مع مناظر ثلاثية الأبعاد للكتلة ولوحة أولية للمواد',
  'Design development: coordinated architectural drawings at 1:50, finishes schedule and outline specifications': 'تطوير التصميم: خرائط معمارية منسّقة بمقياس 1:50، وجدول التشطيبات، ومواصفات أولية',
  'Permit drawings and complete submission file to the Order of Engineers and Architects and the municipality, follow-up until permit issue': 'خرائط الترخيص وملف التقديم الكامل إلى نقابة المهندسين والبلدية، ومتابعة المعاملة حتى صدور الرخصة',
  'Construction (execution) drawings: setting-out, plans, sections, elevations, wall types, door and window schedules and details': 'الخرائط التنفيذية: خرائط التوقيع، والمساقط، والمقاطع، والواجهات، وأنواع الجدران، وجداول الأبواب والشبابيك، والتفاصيل',
  'Architectural design fee based on built-up area':
      'أتعاب التصميم المعماري على أساس المساحة المبنية',
  'Interior design': 'تصميم داخلي',
  'Interior concept: mood boards, layout options and material and colour palette': 'المفهوم التصميمي الداخلي: لوحات الإيحاء (Mood boards)، وخيارات التوزيع، ولوحة المواد والألوان',
  'Interior design package: furniture layouts, reflected ceiling plans, flooring patterns, wall elevations and finishes schedule': 'ملف التصميم الداخلي: خرائط توزيع الأثاث، ومساقط الأسقف المنعكسة، وتصاميم الأرضيات، وواجهات الجدران، وجدول التشطيبات',
  'Joinery and custom furniture design with shop-drawing level details': 'تصميم أعمال النجارة والأثاث حسب الطلب، مع تفاصيل بمستوى الخرائط التنفيذية للمصنع (Shop drawings)',
  'Lighting design: lighting layout, fixture schedule and switching scenes': 'تصميم الإنارة: خريطة توزيع الإنارة، وجدول وحدات الإنارة، وسيناريوهات التشغيل',
  'Loose furniture, accessories and lighting selection with supplier schedule and budget': 'اختيار الأثاث المنفصل والإكسسوارات ووحدات الإنارة، مع جدول بالموردين والميزانية',
  'Photorealistic 3D rendering, interior or exterior':
      'منظور ثلاثي الأبعاد واقعي (Rendering)، داخلي أو خارجي',
  'Walk-through 3D animation': 'جولة افتراضية متحركة ثلاثية الأبعاد',
  'Engineering coordination': 'التنسيق الهندسي',
  'Structural design and calculation note, with structural drawings (by licensed structural engineer)': 'التصميم الإنشائي ومذكرة الحسابات، مع الخرائط الإنشائية (من قبل مهندس إنشائي مجاز)',
  'Mechanical design: plumbing, drainage, HVAC and fire fighting drawings and specifications': 'التصميم الميكانيكي: خرائط ومواصفات التمديدات الصحية والصرف والتكييف والتهوئة ومكافحة الحريق',
  'Electrical design: power, lighting, low-current and earthing drawings with load calculations': 'التصميم الكهربائي: خرائط القوى والإنارة والتيار الخفيف والتأريض، مع حسابات الأحمال',
  'Coordination of all disciplines and clash review of drawings':
      'التنسيق بين جميع الاختصاصات ومراجعة التعارضات في الخرائط',
  'Tender documents': 'مستندات المناقصة',
  'Detailed bill of quantities with quantity take-off from drawings':
      'جدول كميات مفصّل مع استخراج الكميات من الخرائط',
  'Technical specifications for all trades':
      'المواصفات الفنية لجميع فئات الأعمال',
  'Cost estimate of the works at design stage':
      'تقدير كلفة الأعمال في مرحلة التصميم',
  'Tender documents, invitation of contractors, bid analysis and recommendation for award':
      'مستندات المناقصة، ودعوة المقاولين، وتحليل العروض، والتوصية بالتلزيم',

  // 02 Consultancy and supervision.
  'Consultancy and supervision': 'الاستشارات والإشراف',
  'Consultancy': 'استشارات',
  'Review of drawings and design documents with written comments report':
      'مراجعة الخرائط ومستندات التصميم، مع تقرير خطي بالملاحظات',
  'Technical site inspection and building condition assessment report with photos and recommendations':
      'كشف فني على الموقع وتقرير تقييم حالة المبنى، مع صور وتوصيات',
  'Value engineering study with cost-saving alternatives':
      'دراسة هندسة القيمة مع بدائل لتوفير الكلفة',
  'Feasibility study: area analysis, development options and budget estimate':
      'دراسة جدوى: تحليل المساحات، وخيارات التطوير، وتقدير الميزانية',
  'Review of contractor quotations and bill of quantities':
      'مراجعة عروض أسعار المقاولين وجدول الكميات',
  'Coordination meeting with client, consultants or authorities, with minutes of meeting': 'اجتماع تنسيقي مع العميل أو الاستشاريين أو الجهات الرسمية، مع محضر الاجتماع',
  'Consultancy services, hourly rate': 'خدمات استشارية، على أساس سعر الساعة',
  'Supervision and project management': 'الإشراف وإدارة المشروع',
  'Periodic site supervision visit with written site report':
      'زيارة إشراف دورية على الموقع، مع تقرير خطي',
  'Full-time resident site engineer': 'مهندس موقع مقيم بدوام كامل',
  'Project management: programme, cost control, monthly progress report and coordination of contractors and suppliers': 'إدارة المشروع: البرنامج الزمني، وضبط الكلفة، وتقرير تقدّم شهري، وتنسيق أعمال المقاولين والموردين',
  'Checking and certifying contractor payment applications':
      'تدقيق كشوفات المقاول (طلبات الدفع) والمصادقة عليها',
  'Review and approval of shop drawings and material samples':
      'مراجعة واعتماد الخرائط التنفيذية للمقاول (Shop drawings) وعيّنات المواد',
  'Snag list, final inspection and handover with as-built review': 'لائحة الملاحظات، والكشف النهائي، والاستلام، مع مراجعة خرائط التنفيذ الفعلي (As-built)',

  // 03 Preliminaries.
  'Preliminaries': 'الأعمال التحضيرية',
  'Site setup': 'تجهيز الموقع',
  'Mobilization of labour, plant and equipment to site, and demobilization on completion':
      'نقل العمال والآليات والمعدات إلى الموقع، وسحبها عند إنجاز الأعمال',
  'Site office, storage and workers facilities, maintained for the duration of the works':
      'مكتب الموقع والمستودعات ومرافق العمال، مع صيانتها طوال مدة الأعمال',
  'Temporary hoarding / site fence with gate, 2.4 m high':
      'سياج مؤقت للموقع مع بوابة، بارتفاع 2.4 م',
  'Project sign board as per design': 'لوحة تعريف بالمشروع حسب التصميم',
  'Temporary electricity supply and distribution for construction':
      'تأمين وتوزيع الكهرباء المؤقتة لأعمال البناء',
  'Temporary water supply for construction':
      'تأمين المياه المؤقتة لأعمال البناء',
  'Protection and safety': 'الحماية والسلامة',
  'Protection of existing finishes, lifts, staircases and common areas throughout the works': 'حماية التشطيبات القائمة والمصاعد والأدراج والأقسام المشتركة طوال مدة الأعمال',
  'Health and safety measures: PPE, signage, first aid and fire extinguishers on site': 'تدابير الصحة والسلامة: معدات الوقاية الشخصية، واللافتات، والإسعافات الأولية، وطفايات الحريق في الموقع',
  'Scaffolding, supply, erection, maintenance and dismantling':
      'سقالات: تقديم وتركيب وصيانة وفك',
  'Contractor all-risk and third-party insurance':
      'تأمين جميع أخطار المقاول والمسؤولية المدنية تجاه الغير',
  'General': 'عام',
  'Setting out of the works by licensed surveyor':
      'توقيع الأعمال على الأرض من قبل مسّاح محلّف',
  'Shop drawings, material submittals and samples for approval': 'الخرائط التنفيذية للمقاول (Shop drawings) وملفات المواد والعيّنات للموافقة',
  'Daily cleaning of site and removal of debris to an approved dump':
      'تنظيف يومي للموقع ونقل الردميات إلى مكبّ معتمد',
  'Debris removal by truck to an approved dump site':
      'نقل الردميات بالشاحنة إلى مكبّ معتمد',
  'As-built drawings and operation manuals at handover':
      'خرائط التنفيذ الفعلي (As-built) وكتيّبات التشغيل عند التسليم',

  // 04 Demolition and removal.
  'Demolition and removal': 'أعمال الهدم والإزالة',
  'Walls and structure': 'الجدران والهيكل',
  'Demolition of existing block walls of all thicknesses, including plaster, finishes and removal of debris': 'هدم جدران البلوك القائمة بجميع السماكات، شاملاً الطينة والتشطيبات ونقل الردميات',
  'Demolition of reinforced concrete elements by saw cutting and breaking, including removal':
      'هدم عناصر من الباطون المسلّح بالقص بالمنشار والتكسير، شاملاً النقل',
  'Concrete core drilling for services openings, diameter up to 150 mm':
      'تخريم الباطون (كاروتاج) لفتحات التمديدات، بقطر حتى 150 مم',
  'Saw cutting of concrete slabs or walls for new openings':
      'قص بلاطات أو جدران الباطون بالمنشار لفتح فتحات جديدة',
  'Finishes': 'التشطيبات',
  'Removal of existing floor tiles or marble and screed down to structural slab':
      'قلع البلاط أو الرخام القائم مع التسوية حتى البلاطة الإنشائية',
  'Removal of existing wall tiles and backing plaster':
      'قلع بلاط الجدران القائم مع الطينة التي تحته',
  'Scraping of existing paint to sound plaster':
      'كشط الدهان القائم حتى الوصول إلى طينة سليمة',
  'Removal of existing false ceilings including suspension system':
      'فك الأسقف المستعارة القائمة، شاملاً نظام التعليق',
  'Removal of existing parquet or carpet flooring including underlay and adhesive':
      'قلع أرضيات الباركيه أو الموكيت القائمة، شاملاً الطبقة السفلية واللاصق',
  'Fixtures and services': 'التجهيزات والتمديدات',
  'Removal of existing doors with frames and architraves':
      'فك الأبواب القائمة مع الإطارات والبراويز',
  'Removal of existing windows and frames, making good of openings':
      'فك الشبابيك القائمة وإطاراتها، مع إصلاح الفتحات',
  'Removal of existing kitchen cabinets and countertops':
      'فك خزائن المطبخ وأسطح العمل القائمة',
  'Removal of existing sanitary ware and fittings, capping of pipes':
      'فك الأدوات الصحية والتجهيزات القائمة، مع سدّ القساطل',
  'Disconnection and removal of existing electrical and plumbing installations':
      'فصل وإزالة التمديدات الكهربائية والصحية القائمة',
  'Removal of existing AC units, piping and brackets':
      'فك المكيّفات القائمة مع التمديدات والحوامل',

  // 05 Earthworks.
  'Earthworks': 'أعمال الحفر والردم',
  'Excavation': 'الحفريات',
  'Site clearance, removal of vegetation, top soil and debris':
      'تنظيف الموقع، وإزالة النباتات والتربة السطحية والردميات',
  'Bulk excavation in all kinds of soil including rock, with disposal of surplus material':
      'حفر عام في جميع أنواع الأتربة بما فيها الصخر، مع نقل المواد الفائضة',
  'Excavation for foundations and tie beams in all kinds of soil including rock':
      'حفر للأساسات وجسور الربط في جميع أنواع الأتربة بما فيها الصخر',
  'Shoring and dewatering of excavations as required':
      'تدعيم جوانب الحفريات وسحب المياه منها عند اللزوم',
  'Filling and treatment': 'الردم والمعالجة',
  'Backfilling with approved selected material, in 20 cm layers, compacted to 95% modified Proctor': 'ردم بمواد منتقاة معتمدة، على طبقات 20 سم، مدكوكة حتى 95% من بروكتور المعدّل',
  'Base course (crushed aggregate) 20 cm thick under slab on grade, compacted':
      'طبقة أساس (بحص مكسّر) سماكة 20 سم تحت البلاطة الأرضية، مدكوكة',
  'Anti-termite soil treatment under slabs and foundations':
      'معالجة التربة ضد النمل الأبيض تحت البلاطات والأساسات',
  'Polyethylene sheet 1000 gauge vapour barrier under slab on grade':
      'غشاء بولي إيثيلين (نايلون) 1000 gauge عازل للرطوبة تحت البلاطة الأرضية',

  // 06 Concrete works.
  'Concrete works': 'أعمال الباطون',
  'Plain concrete': 'الباطون العادي',
  'Plain concrete blinding 10 cm thick, 250 kg/m³ cement content, under foundations':
      'باطون نظافة عادي سماكة 10 سم، بعيار 250 كغ/م³ إسمنت، تحت الأساسات',
  'Plain concrete for slopes, fillings and bases':
      'باطون عادي للميول والردميات والقواعد',
  'Reinforced concrete': 'الباطون المسلّح',
  'Reinforced concrete C30 for isolated and combined footings, including formwork':
      'باطون مسلّح C30 للقواعد المنفردة والمشتركة، شاملاً الطوبار',
  'Reinforced concrete C30 for raft foundation, including formwork':
      'باطون مسلّح C30 للأساس الحصيري (اللبشة)، شاملاً الطوبار',
  'Reinforced concrete C30 for tie beams and grade beams':
      'باطون مسلّح C30 لجسور الربط والجسور الأرضية',
  'Reinforced concrete C30 for retaining walls, including waterstops':
      'باطون مسلّح C30 لجدران الدعم، شاملاً موانع تسرّب المياه (Waterstops)',
  'Reinforced concrete C35 for columns and shear walls, fair-faced formwork':
      'باطون مسلّح C35 للأعمدة وجدران القص، بطوبار للباطون الظاهر',
  'Reinforced concrete C30 for beams and solid slabs':
      'باطون مسلّح C30 للجسور والبلاطات المصمتة',
  'Ribbed (hourdi) slab with hollow concrete blocks, total thickness 30 cm, including ribs, topping and reinforcement': 'سقف هوردي (أعصاب) مع بلوك باطون مفرّغ، بسماكة إجمالية 30 سم، شاملاً الأعصاب والطبقة العلوية والتسليح',
  'Reinforced concrete slab on grade 15 cm thick, with mesh reinforcement and power-float finish': 'بلاطة أرضية من الباطون المسلّح سماكة 15 سم، مع تسليح بالشبك وتنعيم ميكانيكي (هليكوبتر)',
  'Reinforced concrete stairs including landings and nosings':
      'أدراج من الباطون المسلّح، شاملاً البسطات وحواف الدرجات',
  'Reinforced concrete parapets, upstands and cornices':
      'دروات وقواعد مرفوعة وكرانيش من الباطون المسلّح',
  'Reinforcement and accessories': 'حديد التسليح والملحقات',
  'Deformed reinforcement steel Grade 60, supplied, cut, bent and fixed including tie wire and spacers': 'حديد تسليح محلزن Grade 60، تقديم وقص وثني وتركيب، شاملاً شريط الربط والفواصل (البسكوت)',
  'Welded steel mesh reinforcement': 'شبك حديد ملحوم للتسليح',
  'Post-installed rebar with epoxy anchoring for new to existing concrete':
      'تزريع حديد تسليح بالإيبوكسي لربط الباطون الجديد بالباطون القائم',
  'PVC waterstop at construction joints': 'مانع تسرّب مياه PVC عند فواصل الصبّ',

  // 07 Masonry.
  'Masonry': 'أعمال البلوك',
  'Block walls': 'جدران البلوك',
  'Hollow concrete block wall 20 cm thick, laid in 1:3 cement mortar, including tie beams and lintels': 'جدران بلوك باطون مفرّغ سماكة 20 سم، بمونة إسمنتية بنسبة 1:3، شاملاً الشناجات والجسور فوق الفتحات',
  'Hollow concrete block wall 15 cm thick, laid in 1:3 cement mortar':
      'جدران بلوك باطون مفرّغ سماكة 15 سم، بمونة إسمنتية بنسبة 1:3',
  'Hollow concrete block wall 10 cm thick, laid in 1:3 cement mortar':
      'جدران بلوك باطون مفرّغ سماكة 10 سم، بمونة إسمنتية بنسبة 1:3',
  'Double block cavity wall (15 + 10 cm) with 5 cm insulation board':
      'جدران بلوك مزدوجة مع فراغ (15 + 10 سم) ولوح عزل 5 سم',
  'Lightweight AAC block wall (Ytong or equal) 20 cm thick with thin-bed adhesive':
      'جدران بلوك خفيف AAC (Ytong أو ما يعادله) سماكة 20 سم، بلاصق رقيق',
  'Solid concrete block wall for shafts and fire separation':
      'جدران بلوك باطون مصمت للشفتات والفصل ضد الحريق',
  'Accessories': 'ملحقات',
  'Reinforced concrete lintels and stiffening beams over openings':
      'جسور وشناجات تقوية من الباطون المسلّح فوق الفتحات',
  'Closing of existing openings with block work and making good':
      'سدّ الفتحات القائمة بالبلوك مع الإصلاح',
  'Bonding of new walls to existing with steel dowels':
      'ربط الجدران الجديدة بالجدران القائمة بأشاير حديد',

  // 08 Stone works.
  'Stone works': 'أعمال الحجر',
  'Cladding': 'التلبيس',
  'Natural Lebanese stone cladding to external walls, 5 cm thick, hand dressed (taltish / msamsam), with backing concrete': 'تلبيس الجدران الخارجية بالحجر اللبناني الطبيعي سماكة 5 سم، منحوت يدوياً (تلطيش / مسمسم)، مع باطون خلفي',
  'Natural stone cladding 3 cm thick, sawn finish, fixed with stainless steel anchors':
      'تلبيس بالحجر الطبيعي سماكة 3 سم، منشور، مثبت بمرابط ستانلس ستيل',
  'Stone cornice, window frames (ataba) and sills':
      'كرانيش حجر، وإطارات شبابيك (عتبة) وجلسات',
  'Stone corner quoins': 'حجر زوايا',
  'Pointing of stone joints with coloured mortar':
      'تكحيل فواصل الحجر بمونة ملوّنة',
  'Cleaning and restoration of existing stone facade with water-repellent treatment':
      'تنظيف وترميم واجهة الحجر القائمة، مع معالجة بمادة طاردة للمياه',
  'Stone walls': 'الجدران الحجرية',
  'Natural stone retaining wall, dry or mortar-laid, with concrete backing':
      'جدار دعم من الحجر الطبيعي، دبش ناشف أو بالمونة، مع باطون خلفي',
  'Stone coping to boundary and parapet walls': 'طربوش حجر للأسوار والدروات',

  // 09 Waterproofing and insulation.
  'Waterproofing and insulation': 'أعمال العزل المائي والحراري',
  'Roofs': 'الأسطح',
  'Lightweight foamed concrete for roof slopes, average thickness 10 cm':
      'باطون رغوي خفيف لميول السطح، بسماكة وسطية 10 سم',
  'Torch-applied bituminous membrane, two layers 4 mm, polyester reinforced, turned up 30 cm on parapets': 'عزل بلفائف بيتومينية تُلصق بالشعلة، طبقتان 4 مم، مدعّمة بالبوليستر، مرفوعة 30 سم على الدروات',
  'Extruded polystyrene thermal insulation boards 5 cm thick':
      'ألواح عزل حراري من البوليسترين المبثوق سماكة 5 سم',
  'Protection screed 5 cm with expansion joints over membrane':
      'طبقة حماية 5 سم فوق العزل، مع فواصل تمدد',
  'Liquid-applied polyurethane waterproofing to roof with UV top coat': 'عزل مائي سائل من البولي يوريثان للسطح، مع طبقة نهائية مقاومة للأشعة فوق البنفسجية (UV)',
  'Wet areas and basements': 'المناطق الرطبة والطوابق السفلية',
  'Two-coat cementitious flexible waterproofing to bathrooms and kitchens, turned up 30 cm (full height in showers)': 'عزل مائي إسمنتي مرن على طبقتين للحمامات والمطابخ، مرفوع 30 سم (وبكامل الارتفاع في الدوش)',
  'Bituminous membrane tanking to basement walls and foundations with protection board':
      'عزل جدران وأساسات الطوابق السفلية بلفائف بيتومينية، مع ألواح حماية',
  'Waterproofing of water tanks and planters with approved coating':
      'عزل خزانات المياه وأحواض الزراعة بطلاء معتمد',
  'Waterproofing of balconies and terraces': 'عزل الشرفات والتراسات',
  'Insulation': 'العزل',
  'Rock wool acoustic insulation 5 cm in partitions and ceilings':
      'عزل صوتي بالصوف الصخري 5 سم في القواطع والأسقف',
  'Thermal insulation boards to external walls (inside cavity)':
      'ألواح عزل حراري للجدران الخارجية (داخل الفراغ بين الجدارين)',

  // 10 Plastering.
  'Plastering': 'أعمال الطينة',
  'Internal': 'داخلي',
  'Internal cement plaster to walls, two coats total 2 cm thick, with corner beads, true and plumb': 'طينة إسمنتية داخلية للجدران، على طبقتين بسماكة إجمالية 2 سم، مع زوايا معدنية، مستقيمة وعلى الشاقول',
  'Internal cement plaster to ceilings': 'طينة إسمنتية داخلية للأسقف',
  'Gypsum plaster skim coat on walls for paint finish':
      'طبقة جفصين رقيقة على الجدران تحضيراً للدهان',
  'Fibre mesh at junctions of block and concrete before plaster':
      'شبك ألياف عند التقاء البلوك بالباطون قبل الطينة',
  'External': 'خارجي',
  'External cement plaster three coats (spatter, scratch, finish) with waterproof additive': 'طينة إسمنتية خارجية على ثلاث طبقات (رشّة، طينة، ورقة)، مع مادة مانعة لتسرّب المياه',
  'Drip grooves and expansion profiles to external plaster':
      'مقاطر (حزوز تنقيط) وبروفيلات فواصل تمدد للطينة الخارجية',

  // 11 Screeds and flooring.
  'Screeds and flooring': 'أعمال التسوية والأرضيات',
  'Screeds': 'التسويات',
  'Sand and cement screed average 5 cm thick, levelled to receive floor finishes': 'تسوية بالرمل والإسمنت بسماكة وسطية 5 سم، مسوّاة لاستقبال تشطيبات الأرضيات',
  'Self-levelling screed 5 mm for parquet and vinyl':
      'طبقة تسوية ذاتية 5 مم تحت الباركيه والفينيل',
  'Lightweight concrete filling under floors, average 10 cm':
      'ردميات باطون خفيف تحت الأرضيات، بسماكة وسطية 10 سم',
  'Tiles': 'البلاط',
  'Porcelain floor tiles 60 x 60 cm, rectified, first grade, laid with tile adhesive and epoxy grout, 2 mm joints': 'بلاط بورسلان للأرضيات 60 x 60 سم، مقصوص الحواف (rectified)، نخب أول، يُركّب بلاصق بلاط مع ترويب إيبوكسي، فواصل 2 مم',
  'Large-format porcelain floor tiles 120 x 120 cm or 60 x 120 cm, rectified, with levelling clip system': 'بلاط بورسلان كبير الحجم للأرضيات 120 x 120 سم أو 60 x 120 سم، مقصوص الحواف (rectified)، مع نظام كليبسات للتسوية',
  'Porcelain skirting 10 cm high, matching floor tiles':
      'نعلات بورسلان بارتفاع 10 سم، مطابقة لبلاط الأرضية',
  'Anti-slip porcelain tiles R11 for balconies, terraces and wet areas':
      'بلاط بورسلان مانع للانزلاق R11 للشرفات والتراسات والمناطق الرطبة',
  'Terrazzo tiles 40 x 40 cm, ground and polished':
      'بلاط تيرازو (موزاييك) 40 x 40 سم، مجلي وملمّع',
  'Wood and resilient': 'الخشب والأرضيات المرنة',
  'Engineered wood parquet 15 mm (oak top layer) on acoustic underlay, with matching skirting': 'باركيه خشب هندسي 15 مم (طبقة علوية من السنديان) على طبقة عازلة للصوت، مع نعلات مطابقة',
  'Laminate flooring AC4 8 mm on underlay':
      'أرضيات لامينيت AC4 سماكة 8 مم على طبقة سفلية',
  'Luxury vinyl tiles (LVT) glued on self-levelling screed':
      'بلاط فينيل فاخر (LVT) ملصوق على طبقة تسوية ذاتية',
  'Epoxy floor coating 2 mm for parking, technical and service areas':
      'طلاء أرضيات إيبوكسي 2 مم للمواقف والمناطق الفنية والخدماتية',
  'Floor threshold / transition profile, aluminium or brass':
      'عتبة أرضية / بروفيل انتقال، ألمنيوم أو نحاس أصفر',

  // 12 Wall finishes and cladding.
  'Wall finishes and cladding': 'أعمال تشطيب وتلبيس الجدران',
  'Wall tiles': 'بلاط الجدران',
  'Porcelain wall tiles to bathrooms, full height, with tile adhesive and grout, including aluminium corner trims': 'بلاط بورسلان لجدران الحمامات بكامل الارتفاع، بلاصق بلاط وترويب، شاملاً زوايا الألمنيوم',
  'Kitchen backsplash tiles between counter and wall units':
      'بلاط جدار المطبخ بين سطح العمل والخزائن العلوية',
  'Mosaic tiles glass or stone for feature walls and showers':
      'بلاط فسيفساء زجاجي أو حجري للجدران المميّزة والدوش',
  'Shower niche with tiled or stone finish':
      'تجويف (نيش) في الدوش، بتشطيب بلاط أو حجر',
  'Wood veneer wall cladding panels on concealed frame':
      'ألواح تلبيس جدران بقشرة خشب طبيعي على هيكل مخفي',
  'Fluted wood / MDF wall panels, painted or veneered':
      'ألواح جدران مضلّعة خشب / MDF، مدهونة أو بقشرة خشب',
  'Wallpaper, vinyl backed, supply and installation':
      'تقديم وتركيب ورق جدران بخلفية فينيل',
  'Fabric or leather upholstered wall panels':
      'ألواح جدران منجّدة بالقماش أو الجلد',
  'Mirror cladding 6 mm on plywood backing':
      'تلبيس بالمرايا 6 مم على خلفية خشب معاكس',
  'Large-format porcelain slab wall cladding (sintered stone)':
      'تلبيس جدران بألواح بورسلان كبيرة الحجم (Sintered stone)',

  // 13 Marble and granite.
  'Marble and granite': 'أعمال الرخام والغرانيت',
  'Floors and stairs': 'الأرضيات والأدراج',
  'Marble flooring 2 cm thick, polished, laid on mortar bed, ground and polished after installation': 'أرضيات رخام سماكة 2 سم، ملمّعة، تُركّب على فرشة مونة، مع جلي وتلميع بعد التركيب',
  'Marble stair treads 3 cm and risers 2 cm, with polished nosing and anti-slip grooves':
      'رخام أدراج: دعسات 3 سم وقوائم 2 سم، مع حافة ملمّعة وحزوز مانعة للانزلاق',
  'Marble skirting 10 cm high': 'نعلات رخام بارتفاع 10 سم',
  'Marble door thresholds': 'عتبات أبواب من الرخام',
  'Sills and tops': 'الجلسات والأسطح',
  'Marble or granite window sills with drip groove':
      'جلسات شبابيك من الرخام أو الغرانيت، مع حزّ تنقيط',
  'Kitchen countertop in quartz or granite 2 cm, with edge profile and sink and hob cut-outs': 'سطح عمل للمطبخ من الكوارتز أو الغرانيت 2 سم، مع تشكيل الحافة وفتحات المجلى وسطح الطبخ',
  'Vanity countertop in marble with undermount basin cut-out':
      'سطح مغسلة من الرخام، مع فتحة لمغسلة مركّبة من الأسفل',
  'Marble wall cladding to bathrooms and feature walls':
      'تلبيس جدران الحمامات والجدران المميّزة بالرخام',

  // 14 Gypsum board and ceilings.
  'Gypsum board and ceilings': 'أعمال الجبس بورد والأسقف المستعارة',
  'Ceilings': 'الأسقف',
  'Gypsum board false ceiling 12.5 mm on galvanized steel suspension system, jointed, taped and ready for paint': 'سقف مستعار من ألواح الجبس بورد 12.5 مم على نظام تعليق من الحديد المغلفن، مع معالجة الفواصل بالشريط، جاهز للدهان',
  'Moisture-resistant (green) gypsum board ceiling for bathrooms and kitchens':
      'سقف جبس بورد مقاوم للرطوبة (أخضر) للحمامات والمطابخ',
  'Gypsum board bulkheads and drops, any profile':
      'تنزيلات ودرجات من الجبس بورد، بأي شكل',
  'Light cove / cornice with concealed LED profile':
      'تجويف إنارة / كورنيش مع بروفيل LED مخفي',
  'Shadow gap profile at ceiling perimeter':
      'بروفيل فاصل ظل (Shadow gap) على محيط السقف',
  'Mineral fibre acoustic ceiling tiles 60 x 60 cm on exposed grid':
      'بلاطات سقف صوتية من الألياف المعدنية 60 x 60 سم على شبكة ظاهرة',
  'Access panel 60 x 60 cm, push-to-open':
      'فتحة صيانة 60 x 60 سم، تُفتح بالضغط',
  'Curtain pocket in gypsum ceiling': 'تجويف للستائر في سقف الجبس',
  'Partitions': 'القواطع',
  'Gypsum board partition, double layer each side on 75 mm studs, with rock wool insulation':
      'قواطع جبس بورد، طبقتان من كل جهة على قوائم 75 مم، مع عزل بالصوف الصخري',
  'Gypsum board wall lining on furring channels':
      'تلبيس جدران بالجبس بورد على قنوات تثبيت',
  'Gypsum board shaft wall, fire rated 1 hour':
      'جدار شفت من الجبس بورد، مقاوم للحريق لمدة ساعة',

  // 15 Painting.
  'Painting': 'أعمال الدهان',
  'Internal walls: sealer, two coats putty sanded smooth, primer and two coats washable emulsion paint, colour to approval': 'الجدران الداخلية: سيلر، ووجهان معجونة مع صنفرة ناعمة، وأساس، ووجهان دهان إيملشن قابل للغسل، اللون حسب الموافقة',
  'Ceilings: putty, primer and two coats emulsion paint':
      'الأسقف: معجونة وأساس ووجهان دهان إيملشن',
  'Gypsum board ceilings and partitions: joint finishing, primer and two coats emulsion paint':
      'أسقف وقواطع الجبس بورد: معالجة الفواصل، وأساس، ووجهان دهان إيملشن',
  'Moisture-resistant anti-fungal paint for bathrooms and kitchens':
      'دهان مقاوم للرطوبة والفطريات للحمامات والمطابخ',
  'External walls: primer and two coats elastomeric exterior paint':
      'الجدران الخارجية: أساس ووجهان دهان خارجي مطاطي (Elastomeric)',
  'Textured exterior coating (rolled or sprayed)':
      'طلاء خارجي محبّب (بالرول أو بالرش)',
  'Water-repellent silicone treatment to stone or concrete':
      'معالجة الحجر أو الباطون بالسيليكون الطارد للمياه',
  'Special finishes': 'تشطيبات خاصة',
  'Decorative finish (microcement, stucco or limewash) to feature walls':
      'تشطيب ديكوري (مايكروسمنت أو ستوكو أو دهان كلسي) للجدران المميّزة',
  'Enamel paint on metal works: anti-rust primer and two coats':
      'دهان إينامل للأعمال المعدنية: أساس مانع للصدأ ووجهان',
  'Varnish or lacquer to timber surfaces': 'ورنيش أو لكّر للأسطح الخشبية',
  'Intumescent fire-protective paint to steel':
      'دهان منتفخ واقٍ من الحريق للحديد',

  // 16 Doors and carpentry.
  'Doors and carpentry': 'أعمال الأبواب والنجارة',
  'Doors': 'الأبواب',
  'Internal door 90 x 220 cm, solid core, natural veneer or lacquer finish, with solid wood frame, architraves, hinges, magnetic lock and lever handle': 'باب داخلي 90 x 220 سم، حشوة مصمتة، تشطيب قشرة خشب طبيعي أو لكّر، مع إطار من الخشب الصلب وبراويز ومفصلات وقفل مغناطيسي ومقبض',
  'Internal flush door, full height, with concealed hinges and concealed frame':
      'باب داخلي مسطّح بكامل الارتفاع، مع مفصلات مخفية وإطار مخفي',
  'Sliding pocket door with soft-close track':
      'باب منزلق داخل الجدار، مع سكة بإغلاق هادئ',
  'Main entrance security door, steel armoured, multipoint lock, wood or HPL finish both sides': 'باب مدخل رئيسي أمني مصفّح بالحديد، قفل متعدد النقاط، تشطيب خشب أو HPL على الوجهين',
  'Fire-rated door 60 min with closer and panic bar':
      'باب مقاوم للحريق 60 دقيقة، مع ذراع إغلاق آلي وقضيب طوارئ',
  'Bathroom door with privacy lock and ventilation grille':
      'باب حمام مع قفل خصوصية وفتحة تهوئة',
  'Carpentry': 'النجارة',
  'Wood skirting 8 cm, painted or veneered':
      'نعلات خشب 8 سم، مدهونة أو بقشرة خشب',
  'Wooden handrail on stairs, solid oak': 'مسكة درج خشبية، سنديان صلب',
  'Wood ceiling slats on battens': 'شرائح خشب للسقف على عوارض',
  'Ironmongery set for door (supply only, as per schedule)':
      'طقم إكسسوارات للباب (تقديم فقط، حسب الجدول)',

  // 17 Joinery and fitted furniture.
  'Joinery and fitted furniture': 'أعمال النجارة الداخلية والأثاث المثبّت',
  'Kitchen': 'المطبخ',
  'Kitchen base units 60 cm deep, moisture-resistant carcass, lacquer / HPL fronts, soft-close hinges and drawers': 'خزائن مطبخ سفلية بعمق 60 سم، هيكل مقاوم للرطوبة، واجهات لكّر / HPL، مفصلات وجوارير بإغلاق هادئ',
  'Kitchen wall units 35 cm deep, matching finish':
      'خزائن مطبخ علوية بعمق 35 سم، بتشطيب مطابق',
  'Kitchen tall units (fridge, oven and pantry)':
      'خزائن مطبخ طويلة (براد وفرن ومؤونة)',
  'Kitchen island with storage, excluding countertop':
      'جزيرة مطبخ مع خزائن، لا تشمل سطح العمل',
  'Kitchen accessories: corner carousel, cutlery inserts, bins and LED under-cabinet lighting': 'إكسسوارات المطبخ: رفوف زاوية دوّارة، وفواصل للأدوات، وسلال نفايات، وإنارة LED تحت الخزائن',
  'Wardrobes and units': 'الخزائن والوحدات',
  'Built-in wardrobe full height, hinged or sliding doors, with internal shelves, drawers, hanging rails and lighting': 'خزانة ملابس مدمجة بكامل الارتفاع، بأبواب مفصلية أو منزلقة، مع رفوف داخلية وجوارير وقضبان تعليق وإنارة',
  'Walk-in closet joinery, open shelving and drawers':
      'نجارة غرفة الملابس (Walk-in closet)، رفوف مفتوحة وجوارير',
  'Bathroom vanity unit, water-resistant MDF, wall hung':
      'خزانة مغسلة للحمام، MDF مقاوم للماء، معلّقة على الجدار',
  'TV wall unit with storage and cable management':
      'وحدة تلفزيون جدارية مع خزائن وتنظيم للكابلات',
  'Shoe cabinet / entrance unit': 'خزانة أحذية / وحدة مدخل',
  'Laundry room cabinets': 'خزائن غرفة الغسيل',

  // 18 Aluminium and glazing.
  'Aluminium and glazing': 'أعمال الألمنيوم والزجاج',
  'Windows and doors': 'الشبابيك والأبواب',
  'Aluminium sliding windows, thermal break profiles, double glazed 6-12-6 mm, with insect screen and powder-coated finish': 'شبابيك ألمنيوم منزلقة، بروفيلات بعازل حراري (Thermal break)، زجاج مزدوج 6-12-6 مم، مع منخل ودهان بودرة',
  'Aluminium casement / tilt-and-turn windows, thermal break, double glazed': 'شبابيك ألمنيوم مفصلية / قلّابة ودوّارة (Tilt and turn)، بعازل حراري، زجاج مزدوج',
  'Aluminium lift-and-slide doors to balconies, double glazed':
      'أبواب ألمنيوم رفع وسحب (Lift and slide) للشرفات، زجاج مزدوج',
  'Aluminium fixed glazing, double glazed':
      'زجاج ثابت بإطار ألمنيوم، زجاج مزدوج',
  'Aluminium louvres for ventilation and service areas':
      'شفرات ألمنيوم (لوفر) للتهوئة ومناطق الخدمات',
  'Motorized aluminium rolling shutters':
      'أباجورات رول من الألمنيوم بمحرك كهربائي',
  'Glass': 'الزجاج',
  'Shower glass enclosure 10 mm tempered, frameless, with stainless steel fittings': 'كابين دوش زجاج مقسّى (سيكوريت) 10 مم بدون إطار، مع إكسسوارات ستانلس ستيل',
  'Glass balustrade, laminated tempered 8+8 mm, in aluminium base channel':
      'درابزين زجاج مقسّى مزدوج (Laminated) 8+8 مم، مثبت في قناة ألمنيوم سفلية',
  'Frameless glass partition 12 mm tempered with door':
      'قاطع زجاج مقسّى 12 مم بدون إطار، مع باب',
  'Glass canopy on stainless steel brackets': 'مظلة زجاج على حوامل ستانلس ستيل',
  'Curtain wall system with double glazed units':
      'نظام واجهة زجاجية (Curtain wall) بوحدات زجاج مزدوج',

  // 19 Metal works.
  'Metal works': 'أعمال الحدادة',
  'Steel': 'الحديد',
  'Structural steel for canopies, pergolas and mezzanines, fabricated, erected and painted':
      'حديد إنشائي للمظلات والبرغولات والميزانين، تصنيع وتركيب ودهان',
  'Steel staircase with steel or wood treads': 'درج حديد مع دعسات حديد أو خشب',
  'Steel balustrade / handrail, painted': 'درابزين / مسكة حديد، مدهون',
  'Stainless steel handrail grade 316': 'مسكة درابزين ستانلس ستيل درجة 316',
  'Steel gate, painted, with provision for automation':
      'بوابة حديد مدهونة، مع تحضير للتشغيل الآلي',
  'Gate automation motor with remote controls':
      'محرك تشغيل آلي للبوابة مع أجهزة تحكم عن بعد',
  'Steel security grilles to windows': 'حمايات حديد للشبابيك',
  'Steel cat ladder with safety cage': 'سلّم حديد عمودي مع قفص أمان',

  // 20 Plumbing and drainage.
  'Plumbing and drainage': 'التمديدات الصحية والصرف',
  'Water supply': 'تغذية المياه',
  'Hot and cold water supply network in PPR pipes PN20, insulated hot water lines, per sanitary point': 'شبكة تغذية مياه ساخنة وباردة بقساطل PPR PN20، مع عزل خطوط المياه الساخنة، للنقطة الصحية الواحدة',
  'Main water supply line from tank to apartment, PPR, with valves':
      'خط التغذية الرئيسي من الخزان إلى الشقة، PPR، مع محابس',
  'Water manifold with isolation valves per bathroom':
      'موزّع مياه (Manifold) مع محابس عزل لكل حمام',
  'Polyethylene water storage tank 2,000 L on roof, with float valve and connections':
      'خزان مياه من البولي إيثيلين سعة 2,000 ليتر على السطح، مع عوّامة ووصلات',
  'Booster pump set with pressure vessel': 'مجموعة مضخات رفع ضغط مع خزان ضغط',
  'Water filtration / softening system': 'نظام فلترة / تطرية المياه',
  'Electric water heater 80 L, installed with safety valve':
      'سخان مياه كهربائي 80 ليتر، مركّب مع صمام أمان',
  'Heat pump water heater 200 L':
      'سخان مياه بمضخة حرارية (Heat pump) سعة 200 ليتر',
  'Drainage': 'الصرف',
  'Soil and waste drainage network in uPVC pipes, per sanitary point':
      'شبكة صرف المياه الآسنة والمبتذلة بقساطل uPVC، للنقطة الصحية الواحدة',
  'uPVC drainage stack 110 mm with ventilation':
      'عمود صرف uPVC قطر 110 مم، مع تهوئة',
  'Floor drain with stainless steel grating':
      'مصرف أرضي (سيفون أرض) مع غطاء ستانلس ستيل',
  'Linear shower drain, stainless steel': 'مصرف دوش طولي، ستانلس ستيل',
  'Rainwater down pipes uPVC 110 mm with roof outlets':
      'قساطل تصريف مياه الأمطار uPVC قطر 110 مم، مع مصارف السطح',
  'Manhole, concrete, with cast iron cover':
      'غرفة تفتيش (ريغار) من الباطون، مع غطاء من الحديد الصب',
  'Septic tank / connection to public sewer':
      'جورة صحية / وصل بشبكة الصرف العامة',
  'Sanitary fixtures': 'الأدوات الصحية',
  'Wall-hung WC with concealed cistern frame, soft-close seat and flush plate': 'كرسي إفرنجي معلّق مع هيكل وخزان طرد مخفي (ريزرفوار)، وغطاء بإغلاق هادئ، ولوحة كبس',
  'Floor-mounted WC close-coupled with seat':
      'كرسي إفرنجي أرضي مع خزان طرد ملاصق وغطاء',
  'Bidet shower (shattaf) with angle valve': 'شطّاف مع محبس زاوية',
  'Washbasin, counter-top or undermount, with mixer and waste':
      'مغسلة، فوق السطح أو تحت السطح، مع خلاط وصرف',
  'Concealed shower mixer with rain head shower and hand shower set':
      'خلاط دوش مخفي مع رأس دوش مطري وطقم دوش يدوي',
  'Bathtub, acrylic, with mixer and waste': 'بانيو أكريليك، مع خلاط وصرف',
  'Kitchen sink, stainless steel, with mixer and waste':
      'مجلى مطبخ ستانلس ستيل، مع خلاط وصرف',
  'Bathroom accessories set (towel bars, hooks, paper holder)':
      'طقم إكسسوارات حمام (حمّالات مناشف، علّاقات، حامل ورق)',
  'Washing machine connection point with valve and drain':
      'نقطة وصل غسالة، مع محبس وصرف',

  // 21 Electrical works.
  'Electrical works': 'التمديدات الكهربائية',
  'Distribution': 'لوحات التوزيع',
  'Main distribution board with MCBs, RCDs and surge protection, complete': 'لوحة توزيع رئيسية (طبلون) مع قواطع MCB وقواطع تفاضلية RCD وحماية من ارتفاع الجهد، كاملة',
  'Sub-distribution board per floor or apartment':
      'لوحة توزيع فرعية لكل طابق أو شقة',
  'Main feeder cable from meter to distribution board, XLPE copper':
      'كابل تغذية رئيسي من العدّاد إلى لوحة التوزيع، نحاس XLPE',
  'Changeover switch between grid (EDL) and generator subscription':
      'مفتاح تحويل (إنفرسور) بين كهرباء الدولة (EDL) واشتراك المولّد',
  'Earthing system with copper rod and test pit':
      'نظام تأريض مع قضيب نحاسي وحفرة فحص',
  'Wiring points': 'نقاط التمديدات',
  'Lighting point: PVC conduit, 1.5 mm² copper wiring and switch, complete':
      'نقطة إنارة: قسطل PVC، وأسلاك نحاس 1.5 مم²، ومفتاح، كاملة',
  'Power socket 13 A: PVC conduit, 2.5 mm² copper wiring, complete':
      'نقطة بريز 13 A: قسطل PVC، وأسلاك نحاس 2.5 مم²، كاملة',
  'Dedicated power point for AC, oven, water heater or washing machine, 4-6 mm² wiring':
      'نقطة كهرباء مستقلة للمكيّف أو الفرن أو السخان أو الغسالة، أسلاك 4-6 مم²',
  'USB / USB-C combined power socket': 'بريز كهرباء مع منافذ USB / USB-C',
  'Outdoor weatherproof power socket IP65':
      'بريز خارجي مقاوم للعوامل الجوية IP65',
  'Wiring accessories upgrade (designer switch range)':
      'ترقية إكسسوارات الكهرباء (مفاتيح وبريزات من فئة ديكورية)',
  'Lighting': 'الإنارة',
  'LED recessed downlight, 10 W, 3000 K, with driver':
      'سبوت LED غاطس، 10 W، 3000 K، مع محوّل (Driver)',
  'LED strip lighting with aluminium profile and driver':
      'شريط إنارة LED مع بروفيل ألمنيوم ومحوّل',
  'LED magnetic track lighting system': 'نظام إنارة LED على سكة مغناطيسية',
  'Outdoor wall light IP65': 'إنارة جدارية خارجية IP65',
  'Garden bollard / spike light IP65': 'إنارة حديقة عمودية / مغروسة IP65',
  'Emergency light with battery backup': 'إنارة طوارئ مع بطارية احتياطية',
  'Decorative pendant or chandelier installation':
      'تركيب ثريا أو إنارة معلّقة ديكورية',
  'Low current': 'التيار الخفيف',
  'Data outlet Cat6 including cabling to network rack':
      'مخرج بيانات Cat6، شاملاً التمديد حتى خزانة الشبكة (Rack)',
  'TV outlet with coaxial cable to satellite / IPTV point':
      'مخرج تلفزيون مع كابل محوري إلى نقطة الستلايت / IPTV',
  'Network rack with patch panel and switch':
      'خزانة شبكة (Rack) مع لوحة توصيل (Patch panel) وسويتش',
  'Wi-Fi access point, ceiling mounted': 'نقطة وصول Wi-Fi، مثبتة في السقف',
  'Video intercom system with outdoor panel and indoor monitor':
      'نظام إنترفون بالفيديو مع لوحة خارجية وشاشة داخلية',
  'CCTV IP camera with NVR recording':
      'كاميرا مراقبة IP (CCTV) مع تسجيل على NVR',
  'Alarm system with sensors and keypad': 'نظام إنذار مع حسّاسات ولوحة مفاتيح',
  'Smart home control: lighting and curtains automation':
      'نظام منزل ذكي: تحكم آلي بالإنارة والستائر',
  'Motorized curtain track with motor': 'سكة ستائر كهربائية مع محرك',

  // 22 HVAC.
  'HVAC': 'أعمال التكييف والتهوئة والتدفئة',
  'Air conditioning': 'التكييف',
  'Wall-mounted split AC unit, inverter, 12,000 BTU, installed with copper piping, drain and bracket': 'مكيّف سبليت جداري، إنفرتر، 12,000 BTU، مركّب مع تمديدات نحاس وتصريف وحامل',
  'Wall-mounted split AC unit, inverter, 18,000 BTU':
      'مكيّف سبليت جداري، إنفرتر، 18,000 BTU',
  'Wall-mounted split AC unit, inverter, 24,000 BTU':
      'مكيّف سبليت جداري، إنفرتر، 24,000 BTU',
  'Ducted concealed AC unit with ductwork, linear grilles and thermostat':
      'وحدة تكييف مخفية بمجاري هواء (Ducted)، مع الدكت وفتحات خطية وثرموستات',
  'VRF system, outdoor and indoor units, complete':
      'نظام VRF، وحدات خارجية وداخلية، كامل',
  'Insulated copper refrigerant piping with drain line':
      'تمديدات نحاس معزولة لغاز التبريد، مع خط تصريف',
  'Pre-piping for future AC units (concealed)':
      'تمديدات مسبقة لمكيّفات مستقبلية (مخفية)',
  'Ventilation and heating': 'التهوئة والتدفئة',
  'Exhaust fan for bathroom with duct to outside':
      'مروحة شفط للحمام مع مجرى إلى الخارج',
  'Kitchen hood exhaust duct to outside': 'مجرى شفط لشفّاط المطبخ إلى الخارج',
  'Fresh air unit with heat recovery': 'وحدة هواء نقي مع استرجاع الحرارة',
  'Underfloor heating, hydronic, with manifold and controls':
      'تدفئة أرضية بالمياه، مع موزّع (Manifold) وأجهزة تحكم',
  'Central heating radiator with valves and piping':
      'رادياتور تدفئة مركزية (شوفاج) مع محابس وتمديدات',
  'Boiler, diesel or gas, with chimney and controls':
      'بويلر يعمل على المازوت أو الغاز، مع مدخنة وأجهزة تحكم',
  'Fireplace, wood or bio-ethanol, installed':
      'موقدة (شومينيه) على الحطب أو البيو إيثانول، مركّبة',

  // 23 Fire fighting and safety.
  'Fire fighting and safety': 'أعمال مكافحة الحريق والسلامة',
  'Systems': 'الأنظمة',
  'Fire extinguisher CO2 / dry powder with cabinet':
      'طفاية حريق CO2 / بودرة جافة مع خزانة',
  'Fire hose reel cabinet complete': 'خزانة بكرة خرطوم حريق، كاملة',
  'Sprinkler head with piping': 'رأس رشّاش (Sprinkler) مع تمديدات',
  'Smoke detector, addressable or stand-alone':
      'كاشف دخان، معنون (Addressable) أو مستقل',
  'Fire alarm control panel with manual call points and sirens':
      'لوحة تحكم إنذار حريق مع نقاط إنذار يدوية وصفارات',
  'Fire water tank and pump set': 'خزان مياه حريق ومجموعة مضخات',

  // 24 Solar and energy.
  'Solar and energy': 'الطاقة الشمسية وأنظمة الطاقة',
  'Solar power': 'الطاقة الشمسية',
  'Solar PV panels, monocrystalline 550 W, with aluminium mounting structure on roof': 'ألواح طاقة شمسية كهروضوئية، أحادية البلورة 550 W، مع هيكل تثبيت ألمنيوم على السطح',
  'Hybrid inverter 5 kW / 8 kW with monitoring':
      'إنفرتر هجين 5 kW / 8 kW مع نظام مراقبة',
  'Lithium battery storage 5 kWh': 'بطاريات تخزين ليثيوم 5 kWh',
  'DC and AC cabling, protections, combiner box and earthing for PV system': 'تمديدات كابلات DC وAC، والحمايات، وعلبة التجميع، والتأريض لنظام الطاقة الشمسية',
  'Steel structure for solar panels (elevated / pergola)':
      'هيكل حديد للألواح الشمسية (مرفوع / برغولا)',
  'Solar water heating system with collectors and tank':
      'نظام تسخين مياه بالطاقة الشمسية مع لواقط وخزان',

  // 25 Swimming pool.
  'Swimming pool': 'أعمال المسبح',
  'Pool': 'المسبح',
  'Reinforced concrete swimming pool shell, waterproofed':
      'هيكل مسبح من الباطون المسلّح، معزول',
  'Pool mosaic or porcelain finish with coping stone':
      'تشطيب المسبح بالموزاييك أو البورسلان، مع حجر الحافة',
  'Pool filtration system: pump, sand filter, skimmers, inlets and main drain':
      'نظام فلترة المسبح: مضخة، وفلتر رمل، وسكيمرات، وفتحات دفع، ومصرف رئيسي',
  'Pool underwater LED light': 'إنارة LED تحت الماء للمسبح',
  'Pool heat pump': 'مضخة حرارية لتسخين المسبح',
  'Balance tank and overflow channel with grating':
      'خزان موازنة وقناة فائض، مع شبك',

  // 26 External works and landscape.
  'External works and landscape': 'الأعمال الخارجية وتنسيق الحدائق',
  'Hardscape': 'الرصف والأعمال الصلبة',
  'Interlocking concrete pavers 8 cm on 5 cm sand bed and compacted base course':
      'بلاط إنترلوك من الباطون 8 سم على فرشة رمل 5 سم وطبقة أساس مدكوكة',
  'Natural stone paving on mortar bed': 'رصف بالحجر الطبيعي على فرشة مونة',
  'Concrete kerbstones': 'بردورة من الباطون',
  'Exposed aggregate or stamped concrete paving':
      'رصف بالباطون الحصوي الظاهر أو الباطون المطبوع',
  'Wooden or WPC decking on aluminium joists':
      'أرضية ديك خشب أو WPC على روافد ألمنيوم',
  'External steps in stone': 'درج خارجي من الحجر',
  'Walls and fences': 'الجدران والأسوار',
  'Boundary wall in reinforced concrete with stone cladding and coping':
      'سور من الباطون المسلّح مع تلبيس حجر وطربوش',
  'Steel fence panels on low wall': 'ألواح سياج حديد على جدار منخفض',
  'Softscape': 'التشجير والمزروعات',
  'Agricultural topsoil supply and spreading': 'تقديم وفرش تربة زراعية',
  'Natural grass (sod) installation with soil preparation':
      'تركيب عشب طبيعي (رولات) مع تحضير التربة',
  'Artificial grass 35 mm on prepared base':
      'عشب اصطناعي 35 مم على قاعدة محضّرة',
  'Trees, supply and planting (olive, ficus or as specified)':
      'تقديم وزرع أشجار (زيتون أو فيكوس أو حسب المواصفات)',
  'Shrubs and ground cover planting': 'زراعة شجيرات ونباتات مغطّية للتربة',
  'Drip and sprinkler irrigation network with automatic controller':
      'شبكة ري بالتنقيط والرش، مع وحدة تحكم أوتوماتيكية',
  'Concrete or fibreglass planters': 'أحواض زراعة من الباطون أو الفايبرغلاس',
  'Pergola in steel or timber': 'برغولا من الحديد أو الخشب',

  // 27 Cleaning and handover.
  'Cleaning and handover': 'التنظيف والتسليم',
  'Handover': 'التسليم',
  'Final deep cleaning of all areas, glass, fixtures and floors before handover': 'تنظيف نهائي شامل لجميع المساحات والزجاج والتجهيزات والأرضيات قبل التسليم',
  'Testing and commissioning of all systems':
      'فحص جميع الأنظمة وتشغيلها التجريبي',
  'Snag list rectification': 'معالجة لائحة الملاحظات',
  'Maintenance during defects liability period (12 months)':
      'الصيانة خلال فترة ضمان العيوب (12 شهراً)',
};
