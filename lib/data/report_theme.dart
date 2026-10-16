/// Colours of the printed documents: quotations, invoices, receipts and
/// statements. Graphite and blue is the AK brand and the default.
class ReportTheme {
  const ReportTheme(this.id, this.name, this.ink, this.accent);

  /// Saved in the settings; `custom:RRGGBB:RRGGBB` for chosen colours.
  final String id;
  final String name;

  /// Header bars, table headings, totals and rules.
  final int ink;

  /// Document number, highlights and the thin brand bar.
  final int accent;

  /// Grey for secondary text, the same in every theme so it always reads.
  int get muted => 0xFF5F6670;

  /// Light tint for shaded rows and boxes.
  int get soft => id == 'graphite' ? 0xFFF4F5F7 : _mix(ink, 0.05);

  /// Hairlines between table rows.
  int get line => id == 'graphite' ? 0xFFE2E4E8 : _mix(ink, 0.14);

  bool get custom => id.startsWith('custom:');

  /// A colour [share] of the way from white to [c].
  static int _mix(int c, double share) {
    int ch(int shift) {
      final v = (c >> shift) & 0xFF;
      return (255 - (255 - v) * share).round().clamp(0, 255);
    }

    return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
  }

  static ReportTheme customOf(int ink, int accent) => ReportTheme(
    'custom:${_hex(ink)}:${_hex(accent)}',
    'Own colours',
    ink,
    accent,
  );

  static String _hex(int c) =>
      (c & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
}

/// Ready-made themes, all quiet enough for a client document.
const reportThemes = [
  ReportTheme('graphite', 'Graphite and blue', 0xFF14171C, 0xFF2F6BEB),
  ReportTheme('navy', 'Navy', 0xFF14284B, 0xFF3D7BD9),
  ReportTheme('mono', 'Black and grey', 0xFF1A1A1A, 0xFF707070),
  ReportTheme('slate', 'Slate and teal', 0xFF1F3440, 0xFF14868C),
  ReportTheme('forest', 'Forest green', 0xFF1C3B30, 0xFF2F8A5F),
  ReportTheme('burgundy', 'Burgundy', 0xFF4A1C28, 0xFF9B2C45),
];

/// Main colours offered for own colours: deep and serious.
const reportInks = [
  0xFF14171C,
  0xFF2B2F36,
  0xFF14284B,
  0xFF1E3A5F,
  0xFF1F3440,
  0xFF0F4C5C,
  0xFF1C3B30,
  0xFF2E4A3B,
  0xFF3B2F4A,
  0xFF4A1C28,
  0xFF5A3A2E,
  0xFF3A3A3A,
];

/// Highlight colours offered for own colours.
const reportAccents = [
  0xFF2F6BEB,
  0xFF3D7BD9,
  0xFF0E7490,
  0xFF14868C,
  0xFF2F8A5F,
  0xFF5B8C3A,
  0xFF6D4BB5,
  0xFF9B2C45,
  0xFFC0392B,
  0xFFD9622B,
  0xFF707070,
  0xFF14171C,
];

/// The theme saved under [id]; the brand theme when unknown.
ReportTheme reportThemeById(String? id) {
  if (id != null && id.startsWith('custom:')) {
    final parts = id.split(':');
    final ink = parts.length > 1 ? int.tryParse(parts[1], radix: 16) : null;
    final accent = parts.length > 2 ? int.tryParse(parts[2], radix: 16) : null;
    if (ink != null && accent != null) {
      return ReportTheme.customOf(0xFF000000 | ink, 0xFF000000 | accent);
    }
  }
  return reportThemes.firstWhere(
    (t) => t.id == id,
    orElse: () => reportThemes.first,
  );
}
