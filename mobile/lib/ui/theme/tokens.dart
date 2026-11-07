import 'package:flutter/material.dart';

/// Design tokens: the website's soft "neumorphic" lilac identity, in light and dark.
class AppColors {
  const AppColors({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.inset,
    required this.shadowDark,
    required this.shadowLight,
    required this.edge,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.good,
    required this.warn,
    required this.bad,
  });

  final Brightness brightness;
  final Color bg;
  final Color surface;
  final Color inset;
  final Color shadowDark;
  final Color shadowLight;
  final Color edge;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color good;
  final Color warn;
  final Color bad;

  bool get isDark => brightness == Brightness.dark;

  static const light = AppColors(
    brightness: Brightness.light,
    bg: Color(0xFFE6E9F2),
    surface: Color(0xFFE6E9F2),
    inset: Color(0xFFDDE1EC),
    shadowDark: Color(0xFFB9BFD3),
    shadowLight: Color(0xFFFFFFFF),
    edge: Color(0xFFD3D8E6),
    text: Color(0xFF262B40),
    muted: Color(0xFF666E8C),
    accent: Color(0xFF6A5CFF),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFDCD8FF),
    good: Color(0xFF1E9E69),
    warn: Color(0xFFC98A00),
    bad: Color(0xFFD9444A),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF1B1E2E),
    surface: Color(0xFF1F2335),
    inset: Color(0xFF181B29),
    shadowDark: Color(0xFF11131F),
    shadowLight: Color(0xFF292E45),
    edge: Color(0xFF2A2F46),
    text: Color(0xFFEDEFF8),
    muted: Color(0xFFA0A8C6),
    accent: Color(0xFF8B7FFF),
    onAccent: Color(0xFF14122B),
    accentSoft: Color(0xFF34305F),
    good: Color(0xFF45C795),
    warn: Color(0xFFE8B63A),
    bad: Color(0xFFFF7478),
  );

  static AppColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ----- text styles (system fonts: no download at runtime, works offline)
  static const List<String> _serif = ['Georgia', 'Noto Serif', 'serif'];

  TextStyle get display => TextStyle(fontSize: 26, height: 1.15, fontWeight: FontWeight.w700, color: text, fontFamilyFallback: _serif);
  TextStyle get h1 => TextStyle(fontSize: 21, height: 1.2, fontWeight: FontWeight.w700, color: text);
  TextStyle get h2 => TextStyle(fontSize: 16.5, height: 1.25, fontWeight: FontWeight.w700, color: text);
  TextStyle get body => TextStyle(fontSize: 14.5, height: 1.4, color: text);
  TextStyle get bodyStrong => TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, color: text);
  TextStyle get small => TextStyle(fontSize: 12.5, height: 1.35, color: muted);
  TextStyle get eyebrow => TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: accent);

  /// Shadows for raised surfaces. [depth] 1 = small chips, 2 = cards, 3 = hero.
  List<BoxShadow> raised([int depth = 2]) {
    final o = 3.0 * depth;
    final b = 7.0 * depth;
    return [
      BoxShadow(color: shadowDark, offset: Offset(o, o), blurRadius: b),
      BoxShadow(color: shadowLight, offset: Offset(-o, -o), blurRadius: b),
    ];
  }

  Color tone(String name) {
    switch (name) {
      case 'good':
        return good;
      case 'warn':
        return warn;
      case 'bad':
        return bad;
      default:
        return accent;
    }
  }
}
