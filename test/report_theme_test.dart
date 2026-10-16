import 'package:ak_system/data/repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('the brand theme is the default and unknown ids fall back to it', () {
    expect(reportThemeById(null).id, 'graphite');
    expect(reportThemeById('gold').id, 'graphite');
    expect(reportThemeById('custom:zz').id, 'graphite');
  });

  test('own colours are saved and read back', () {
    final t = ReportTheme.customOf(0xFF14284B, 0xFF2F8A5F);
    expect(t.id, 'custom:14284B:2F8A5F');
    final back = reportThemeById(t.id);
    expect(back.custom, isTrue);
    expect(back.ink, 0xFF14284B);
    expect(back.accent, 0xFF2F8A5F);
    // Shades for rows and lines are light tints of the main colour.
    expect(back.soft & 0xFF, greaterThan(0xEE));
    expect(back.line & 0xFF, greaterThan(0xD0));
  });

  test('the chosen theme is kept in the settings', () async {
    final repo = await memoryRepo(TestClock(DateTime(2026, 10, 16)));
    expect(repo.reportTheme.id, 'graphite');
    await repo.setReportTheme(reportThemeById('navy'));
    await repo.reload();
    expect(repo.reportTheme.id, 'navy');
    await repo.setReportTheme(ReportTheme.customOf(0xFF1C3B30, 0xFF707070));
    await repo.reload();
    expect(repo.reportTheme.ink, 0xFF1C3B30);
  });
}
