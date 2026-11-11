import 'package:flutter/material.dart';

/// Design tokens: a clean, Instagram-style look (white / true-black, hairlines, colourful rings) in the school's violet.
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
    bg: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    inset: Color(0xFFF2F2F5),
    shadowDark: Color(0x1A000000),
    shadowLight: Color(0x00FFFFFF),
    edge: Color(0xFFE3E3E8),
    text: Color(0xFF111114),
    muted: Color(0xFF6D6D78),
    accent: Color(0xFF5D46B9),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEFEBFF),
    good: Color(0xFF0E7048),
    warn: Color(0xFF9A5B00),
    bad: Color(0xFFC62835),
  );

  static const dark = AppColors(
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF121215),
    inset: Color(0xFF1C1C21),
    shadowDark: Color(0x00000000),
    shadowLight: Color(0x00000000),
    edge: Color(0xFF2B2B31),
    text: Color(0xFFF5F5F7),
    muted: Color(0xFF9B9BA7),
    accent: Color(0xFFA997FF),
    onAccent: Color(0xFF0D0820),
    accentSoft: Color(0xFF251E48),
    good: Color(0xFF3DD68C),
    warn: Color(0xFFFFB84D),
    bad: Color(0xFFFF6B75),
  );

  /// The colourful "story ring" gradient (used around avatars and shortcut bubbles).
  static const LinearGradient storyGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFF4F5BD5)],
  );

  static AppColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ----- text styles (system fonts: no download at runtime, works offline)
  TextStyle get display => TextStyle(fontSize: 24, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: text);
  TextStyle get h1 => TextStyle(fontSize: 20, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: text);
  TextStyle get h2 => TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: text);
  TextStyle get body => TextStyle(fontSize: 14.5, height: 1.4, color: text);
  TextStyle get bodyStrong => TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, color: text);
  TextStyle get small => TextStyle(fontSize: 12.5, height: 1.35, color: muted);
  TextStyle get eyebrow => TextStyle(fontSize: 11.5, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: accent);

  /// Soft shadow for hero surfaces only (depth 3). Everything else is flat with a hairline border, like Instagram.
  List<BoxShadow> raised([int depth = 2]) {
    if (isDark || depth < 3) return const <BoxShadow>[];
    return const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8))];
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
