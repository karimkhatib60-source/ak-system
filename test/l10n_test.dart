import 'package:ak_system/l10n/lang.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_check.dart';

void main() {
  test('the source has translated texts', () {
    expect(translatedTexts().length, greaterThan(50));
  });

  test('every translated text has its Arabic, with the same placeholders', () {
    expect(problems(), isEmpty);
  });

  test('dates read in each language', () {
    final d = DateTime(2026, 9, 5);
    expect(dayIn(AppLang.en, d), '5 Sep 2026');
    expect(dayIn(AppLang.ar, d), '5 أيلول 2026');
    expect(trIn(AppLang.ar, 'Language'), 'اللغة');
    expect(trIn(AppLang.en, 'Language'), 'Language');
    expect(trIn(AppLang.ar, 'Not translated {0}', ['x']), 'Not translated x');
    // A note after @@ tells two meanings apart and never shows.
    expect(trIn(AppLang.en, 'Credit@@column'), 'Credit');
    expect(trIn(AppLang.ar, 'Credit@@column'), 'دائن');
    expect(trIn(AppLang.ar, 'Credit'), 'رصيد دائن');
  });
}
