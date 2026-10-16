import 'package:intl/intl.dart';

import 'ar_boq.dart';
import 'ar_common.dart';
import 'ar_documents.dart';
import 'ar_finance.dart';
import 'ar_money.dart';
import 'ar_projects.dart';
import 'ar_settings.dart';

/// Languages of the app and of printed documents.
enum AppLang { en, ar }

/// Language of the screens, from the settings.
AppLang appLang = AppLang.en;

/// Language of quotations, invoices, receipts and statements.
AppLang docLang = AppLang.en;

bool get isArabic => appLang == AppLang.ar;

/// Arabic for every text of the app, keyed by its English wording. Each
/// area of the app keeps its own list; a later list wins on the same key.
final Map<String, String> arabicTexts = {
  ...arCommon,
  ...arProjects,
  ...arMoney,
  ...arFinance,
  ...arDocuments,
  ...arSettings,
  ...arBoq,
};

/// [english] in [lang], with {0}, {1}… replaced by [args]. Text with no
/// Arabic yet stays in English.
String trIn(AppLang lang, String english, [List<Object?> args = const []]) {
  var s = lang == AppLang.ar ? (arabicTexts[english] ?? english) : english;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

extension Tr on String {
  /// In the language of the screens.
  String get tr => trIn(appLang, this);

  /// In the language of printed documents.
  String get td => trIn(docLang, this);

  /// In the language of the screens, with {0}, {1}… filled in.
  String trArgs(List<Object?> args) => trIn(appLang, this, args);

  /// In the language of printed documents, with {0}, {1}… filled in.
  String tdArgs(List<Object?> args) => trIn(docLang, this, args);

  /// In [lang], with {0}, {1}… filled in.
  String inLang(AppLang lang, [List<Object?> args = const []]) =>
      trIn(lang, this, args);
}

/// Month names used in Lebanon.
const arabicMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

final _enDay = DateFormat('d MMM yyyy');
final _enDayShort = DateFormat('d MMM');
final _enMonth = DateFormat('MMMM yyyy');

/// "5 Sep 2026", or "5 أيلول 2026" in Arabic. Digits stay Western, as on
/// Lebanese documents.
String dayIn(AppLang lang, DateTime d, {bool year = true}) => lang == AppLang.ar
    ? '${d.day} ${arabicMonths[d.month - 1]}${year ? ' ${d.year}' : ''}'
    : (year ? _enDay : _enDayShort).format(d);

/// "September 2026", or "أيلول 2026".
String monthIn(AppLang lang, DateTime d) => lang == AppLang.ar
    ? '${arabicMonths[d.month - 1]} ${d.year}'
    : _enMonth.format(d);

/// Weekday names, Monday first as in [DateTime.weekday].
const arabicWeekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

/// "Friday 16 October 2026", or "الجمعة 16 تشرين الأول 2026".
String longDayIn(AppLang lang, DateTime d) => lang == AppLang.ar
    ? '${arabicWeekdays[d.weekday - 1]} ${d.day} '
          '${arabicMonths[d.month - 1]} ${d.year}'
    : DateFormat('EEEE d MMMM yyyy').format(d);
