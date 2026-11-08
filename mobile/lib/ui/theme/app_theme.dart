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
    surfaceTint: Colors.transparent,
    outline: c.edge,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    dividerColor: c.edge,
    splashFactory: InkRipple.splashFactory,
    highlightColor: Colors.transparent,
    visualDensity: VisualDensity.standard,
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent, selectionHandleColor: c.accent),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.isDark ? const Color(0xFF2E2E36) : const Color(0xFF1F1F24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
