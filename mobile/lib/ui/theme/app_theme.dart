import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    surface: c.surface,
    onSurface: c.text,
    error: c.bad,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionHandleColor: c.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.isDark ? const Color(0xFF2E3350) : const Color(0xFF2A2F46),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
