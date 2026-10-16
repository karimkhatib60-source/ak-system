import 'package:flutter/material.dart';

import '../l10n/lang.dart';

// AK brand palette: monochrome graphite for structure, one engineering blue
// as the only accent, neutral grey surfaces. Everything in the app reads its
// colours from here.
class AkPalette {
  static const graphite = Color(0xFF14171C);
  static const graphite2 = Color(0xFF1F232A);
  static const graphite3 = Color(0xFF2C323B);
  static const blue = Color(0xFF2F6BEB);
  static const blueDeep = Color(0xFF1F4FB8);
  static const paper = Color(0xFFF4F5F7);
  static const ink = Color(0xFF14171C);
  static const slate = Color(0xFF5F6670);
  static const line = Color(0xFFE2E4E8);

  static const good = Color(0xFF2E7D5B);
  static const warn = Color(0xFFB7700F);
  static const bad = Color(0xFFC0392B);
  static const info = Color(0xFF0E7490);
}

/// Extra brand colours that Material's scheme has no slot for.
@immutable
class AkColors extends ThemeExtension<AkColors> {
  const AkColors({
    required this.chrome,
    required this.chromeHigh,
    required this.onChrome,
    required this.onChromeMuted,
    required this.accent,
    required this.card,
    required this.line,
    required this.muted,
    required this.good,
    required this.warn,
    required this.bad,
    required this.info,
  });

  /// Graphite used for headers and navigation.
  final Color chrome;
  final Color chromeHigh;
  final Color onChrome;
  final Color onChromeMuted;
  final Color accent;
  final Color card;
  final Color line;
  final Color muted;
  final Color good;
  final Color warn;
  final Color bad;
  final Color info;

  static AkColors of(BuildContext context) =>
      Theme.of(context).extension<AkColors>()!;

  @override
  AkColors copyWith() => this;

  @override
  AkColors lerp(AkColors? other, double t) => t < 0.5 ? this : other ?? this;
}

const _light = AkColors(
  chrome: AkPalette.graphite,
  chromeHigh: AkPalette.graphite2,
  onChrome: Colors.white,
  onChromeMuted: Color(0xFF9AA1AC),
  accent: AkPalette.blue,
  card: Colors.white,
  line: AkPalette.line,
  muted: AkPalette.slate,
  good: AkPalette.good,
  warn: AkPalette.warn,
  bad: AkPalette.bad,
  info: AkPalette.info,
);

const _dark = AkColors(
  chrome: Color(0xFF0B0D10),
  chromeHigh: AkPalette.graphite2,
  onChrome: Colors.white,
  onChromeMuted: Color(0xFF8C939E),
  accent: Color(0xFF5A8CF2),
  card: Color(0xFF171A1F),
  line: Color(0xFF2A2F37),
  muted: Color(0xFF9AA1AC),
  good: Color(0xFF4FB386),
  warn: Color(0xFFE0A040),
  bad: Color(0xFFE5675A),
  info: Color(0xFF3FB3CF),
);

/// Manrope is the brand font; Arabic screens use IBM Plex Sans Arabic,
/// which also has Latin letters and digits.
ThemeData buildTheme(Brightness brightness, [AppLang lang = AppLang.en]) {
  final font = lang == AppLang.ar ? 'IBMPlexSansArabic' : 'Manrope';
  const fallback = ['IBMPlexSansArabic', 'Manrope'];
  final dark = brightness == Brightness.dark;
  final ak = dark ? _dark : _light;
  final bg = dark ? const Color(0xFF101215) : AkPalette.paper;
  final ink = dark ? const Color(0xFFE9EBEE) : AkPalette.ink;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? ak.accent : AkPalette.graphite,
    onPrimary: Colors.white,
    primaryContainer: dark ? AkPalette.graphite3 : const Color(0xFFE4E7EC),
    onPrimaryContainer: dark ? Colors.white : AkPalette.graphite,
    secondary: AkPalette.blue,
    onSecondary: Colors.white,
    secondaryContainer: dark
        ? const Color(0xFF1C2A44)
        : const Color(0xFFE3ECFD),
    onSecondaryContainer: dark ? ak.accent : AkPalette.blueDeep,
    tertiary: ak.info,
    onTertiary: Colors.white,
    error: ak.bad,
    onError: Colors.white,
    surface: bg,
    onSurface: ink,
    onSurfaceVariant: ak.muted,
    surfaceContainerLowest: ak.card,
    surfaceContainerLow: ak.card,
    surfaceContainer: ak.card,
    surfaceContainerHigh: dark ? const Color(0xFF1C2026) : Colors.white,
    surfaceContainerHighest: dark
        ? const Color(0xFF22272E)
        : const Color(0xFFECEEF1),
    outline: dark ? const Color(0xFF4A515C) : const Color(0xFFB8BDC5),
    outlineVariant: ak.line,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: font,
    fontFamilyFallback: fallback,
    scaffoldBackgroundColor: bg,
    extensions: [ak],
  );
  final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);

  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: ak.chrome,
      foregroundColor: ak.onChrome,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: ak.onChrome,
        letterSpacing: 0.1,
      ),
      iconTheme: IconThemeData(color: ak.onChrome),
      actionsIconTheme: IconThemeData(color: ak.onChrome),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ak.onChrome,
      unselectedLabelColor: ak.onChromeMuted,
      indicatorColor: ak.accent,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
    cardTheme: CardThemeData(
      color: ak.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ak.line),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ak.chrome,
      indicatorColor: ak.accent,
      surfaceTintColor: Colors.transparent,
      height: 66,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Colors.white
              : ak.onChromeMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: font,
          fontFamilyFallback: fallback,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected)
              ? Colors.white
              : ak.onChromeMuted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: ak.chrome,
      indicatorColor: ak.accent,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: IconThemeData(color: ak.onChromeMuted),
      selectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        color: Colors.white,
      ),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: ak.onChromeMuted,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ak.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ak.accent,
        foregroundColor: Colors.white,
        textStyle: TextStyle(
          fontFamily: font,
          fontFamilyFallback: fallback,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: BorderSide(color: scheme.outline),
        textStyle: TextStyle(
          fontFamily: font,
          fontFamilyFallback: fallback,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ak.card,
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ak.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ak.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: ak.accent, width: 1.6),
      ),
      labelStyle: TextStyle(color: ak.muted),
      floatingLabelStyle: TextStyle(
        color: ak.accent,
        fontWeight: FontWeight.w700,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: ak.card,
      selectedColor: AkPalette.graphite,
      secondarySelectedColor: AkPalette.graphite,
      checkmarkColor: Colors.white,
      side: BorderSide(color: ak.line),
      labelStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      secondaryLabelStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? AkPalette.graphite : ak.card,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : ink,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: ak.line)),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? ak.good : Colors.transparent,
      ),
      side: BorderSide(color: scheme.outline, width: 1.6),
    ),
    dividerTheme: DividerThemeData(color: ak.line, space: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: ak.accent,
      linearTrackColor: ak.line,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AkPalette.graphite,
      contentTextStyle: TextStyle(
        fontFamily: font,
        fontFamilyFallback: fallback,
        color: Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: ak.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
