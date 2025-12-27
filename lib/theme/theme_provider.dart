// lib/provider/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  // Constructor: Load saved theme on init
  ThemeProvider() {
    _loadTheme();
  }

  // ────── Check if current theme is dark (handles system mode) ──────
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.system) {
      return View.of(context).platformDispatcher.platformBrightness == Brightness.dark;
      // OR: MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  // ────── Toggle between Light / Dark (called from switch) ──────
  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme();
    notifyListeners();
  }

  // ────── Set any theme mode (useful if you add "System" option later) ──────
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _saveTheme();
    notifyListeners();
  }

  // ────── Private: Save to SharedPreferences ──────
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, _themeMode.toString());
  }

  // ────── Private: Load from SharedPreferences ──────
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyThemeMode);

      if (saved != null) {
        _themeMode = ThemeMode.values.firstWhere(
              (e) => e.toString() == saved,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      debugPrint('Theme load error: $e');
      _themeMode = ThemeMode.system;
    }

    notifyListeners(); // Always notify so UI updates on app start
  }

  // ────── Optional: Reset to system default ──────
  Future<void> resetToSystem() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyThemeMode);
    _themeMode = ThemeMode.system;
    notifyListeners();
  }
}