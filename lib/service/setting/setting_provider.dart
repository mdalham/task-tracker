import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // ==================== KEYS ====================
  static const String _keyFiveMinReminder = 'five_minute_reminder_enabled';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  // NEW: Font settings keys
  static const String _keyFontFamily = 'font_family';
  static const String _keyFontBold = 'font_bold';
  static const String _keyFontItalic = 'font_italic';

  // ==================== DEFAULTS ====================
  static const String _defaultFontFamily = 'Roboto';
  static const bool _defaultFontBold = false;
  static const bool _defaultFontItalic = false;

  // ==================== PRIVATE FIELDS ====================
  bool _fiveMinuteReminderEnabled = true;
  bool _notificationsEnabled = true;

  String _fontFamily = _defaultFontFamily;
  bool _fontBold = _defaultFontBold;
  bool _fontItalic = _defaultFontItalic;

  bool _isInitialized = false;

  // ==================== GETTERS ====================
  bool get fiveMinuteReminderEnabled => _fiveMinuteReminderEnabled;
  bool get notificationsEnabled => _notificationsEnabled;

  String get fontFamily => _fontFamily;
  bool get fontBold => _fontBold;
  bool get fontItalic => _fontItalic;

  bool get isInitialized => _isInitialized;

  TextStyle get noteTextStyle => TextStyle(
    fontFamily: _fontFamily,
    fontWeight: _fontBold ? FontWeight.bold : FontWeight.normal,
    fontStyle: _fontItalic ? FontStyle.italic : FontStyle.normal,
  );

  // ==================== INITIALIZATION ====================
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('Initializing SettingsProvider...');
    final prefs = await SharedPreferences.getInstance();

    _fiveMinuteReminderEnabled = prefs.getBool(_keyFiveMinReminder) ?? true;
    _notificationsEnabled = prefs.getBool(_keyNotificationsEnabled) ?? true;

    _fontFamily = prefs.getString(_keyFontFamily) ?? _defaultFontFamily;
    _fontBold = prefs.getBool(_keyFontBold) ?? _defaultFontBold;
    _fontItalic = prefs.getBool(_keyFontItalic) ?? _defaultFontItalic;

    _isInitialized = true;
    notifyListeners();

    debugPrint('Settings loaded:');
    debugPrint('  • Notifications: $_notificationsEnabled');
    debugPrint('  • 5-min reminder: $_fiveMinuteReminderEnabled');
    debugPrint('  • Font: $_fontFamily${_fontBold ? " Bold" : ""}${_fontItalic ? " Italic" : ""}');
  }

  // ==================== NOTIFICATION SETTERS ====================
  Future<void> setFiveMinuteReminderEnabled(bool enabled) async {
    if (_fiveMinuteReminderEnabled == enabled) return;
    _fiveMinuteReminderEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFiveMinReminder, enabled);
    notifyListeners();
    debugPrint('5-minute reminder ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, enabled);
    notifyListeners();
    debugPrint('Notifications ${enabled ? "enabled" : "disabled"}');
  }

  // ==================== FONT SETTERS (LIVE + SAVED) ====================
  Future<void> setFontFamily(String family) async {
    if (_fontFamily == family) return;
    _fontFamily = family;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontFamily, family);
    notifyListeners();
    debugPrint('Font family changed to: $family');
  }

  Future<void> setFontBold(bool enabled) async {
    if (_fontBold == enabled) return;
    _fontBold = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFontBold, enabled);
    notifyListeners();
    debugPrint('Font bold ${enabled ? "enabled" : "disabled"}');
  }

  Future<void> setFontItalic(bool enabled) async {
    if (_fontItalic == enabled) return;
    _fontItalic = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFontItalic, enabled);
    notifyListeners();
    debugPrint('Font italic ${enabled ? "enabled" : "disabled"}');
  }

  // ==================== RESET ALL ====================
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyFiveMinReminder),
      prefs.remove(_keyNotificationsEnabled),
      prefs.remove(_keyFontFamily),
      prefs.remove(_keyFontBold),
      prefs.remove(_keyFontItalic),
    ]);

    _fiveMinuteReminderEnabled = true;
    _notificationsEnabled = true;
    _fontFamily = _defaultFontFamily;
    _fontBold = _defaultFontBold;
    _fontItalic = _defaultFontItalic;

    notifyListeners();
    debugPrint('All settings reset to defaults');
  }
}