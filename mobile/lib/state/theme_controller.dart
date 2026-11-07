import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode mode = ThemeMode.system;
  static const _key = 'tvv_theme_mode';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (prefs.getString(_key)) {
        case 'light':
          mode = ThemeMode.light;
        case 'dark':
          mode = ThemeMode.dark;
        default:
          mode = ThemeMode.system;
      }
      notifyListeners();
    } catch (_) {
      // Preferences unavailable: stay on "system".
    }
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, m == ThemeMode.light ? 'light' : (m == ThemeMode.dark ? 'dark' : 'system'));
    } catch (_) {}
  }
}
