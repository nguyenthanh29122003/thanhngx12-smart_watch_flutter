// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_constants.dart'; // Cần key SharedPreferences
import '../generated/app_localizations.dart'; // <<< Import lớp localization đã tạo

class SettingsProvider with ChangeNotifier {
  // --- State cho Theme ---
  ThemeMode _themeMode = ThemeMode.system; // Mặc định theo hệ thống

  // --- State cho Locale ---
  Locale? _appLocale; // Null nghĩa là dùng locale hệ thống

  // --- State khởi tạo ---
  bool _isInitialized = false; // Đánh dấu đã tải cài đặt lần đầu chưa

  // --- Getters ---
  ThemeMode get themeMode => _themeMode;
  Locale? get appLocale => _appLocale;
  bool get isInitialized =>
      _isInitialized; // Có thể dùng để hiển thị loading ban đầu

  // --- Constructor ---
  SettingsProvider() {
    _loadSettings(); // Tải cả theme và locale khi khởi tạo
    print("SettingsProvider Initialized. Loading settings...");
  }

  // --- Load Cài đặt từ SharedPreferences ---
  Future<void> _loadSettings() async {
    // Đảm bảo chỉ load 1 lần
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // --- Load Theme ---
      final themeString = prefs.getString(AppConstants.prefKeyThemeMode);
      print("[SettingsProvider] Loaded theme string: $themeString");
      if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system; // Mặc định
      }

      // --- Load Locale ---
      final languageCode = prefs.getString(AppConstants.prefKeyLanguageCode);
      print("[SettingsProvider] Loaded language code: $languageCode");
      if (languageCode != null && languageCode.isNotEmpty) {
        // Kiểm tra xem languageCode có nằm trong danh sách ngôn ngữ hỗ trợ không
        if (AppLocalizations.supportedLocales
            .any((locale) => locale.languageCode == languageCode)) {
          _appLocale = Locale(languageCode); // Tạo Locale từ code đã lưu
        } else {
          print(
              "!!! [SettingsProvider] Unsupported language code '$languageCode' found in prefs. Using system default.");
          _appLocale = null; // Dùng mặc định nếu code lưu không hợp lệ
          await prefs
              .remove(AppConstants.prefKeyLanguageCode); // Xóa key không hợp lệ
        }
      } else {
        _appLocale = null; // null nghĩa là dùng locale hệ thống
      }
      // ---------------
    } catch (e) {
      print("!!! [SettingsProvider] Error loading settings: $e");
      // Reset về mặc định nếu có lỗi
      _themeMode = ThemeMode.system;
      _appLocale = null;
    } finally {
      _isInitialized = true; // Đánh dấu đã load xong
      notifyListeners(); // Thông báo cho UI cập nhật (quan trọng)
      print(
          "[SettingsProvider] Settings loaded - Theme: $_themeMode, Locale: ${_appLocale?.languageCode ?? 'system'}");
    }
  }

  // --- Cập nhật Theme ---
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null || newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;
    print("[SettingsProvider] Updating theme mode to: $_themeMode");
    notifyListeners(); // Cập nhật UI

    // Lưu vào SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (newThemeMode) {
        case ThemeMode.light:
          themeString = 'light';
          break;
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
        default:
          themeString = 'system';
          break;
      }
      await prefs.setString(AppConstants.prefKeyThemeMode, themeString);
      print("[SettingsProvider] Saved theme mode: $themeString");
    } catch (e) {
      print("!!! [SettingsProvider] Error saving theme mode: $e");
    }
  }

  // --- Cập nhật Locale ---
  Future<void> updateLocale(Locale? newLocale) async {
    // Kiểm tra xem locale có thực sự thay đổi không
    // So sánh languageCode vì Locale(null) khác Locale('en') dù cả hai có thể là null trong state
    final currentCode = _appLocale?.languageCode;
    final newCode = newLocale?.languageCode;

    if (currentCode == newCode) return; // Không thay đổi

    _appLocale = newLocale; // Cập nhật state
    print("[SettingsProvider] Updating locale to: ${newCode ?? 'system'}");
    notifyListeners(); // Cập nhật UI

    // Lưu vào SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newCode == null) {
        // Nếu người dùng chọn system default (newLocale là null)
        await prefs.remove(AppConstants.prefKeyLanguageCode);
        print(
            "[SettingsProvider] Removed language code (using system default).");
      } else {
        // Lưu language code (vd: 'en', 'vi')
        await prefs.setString(AppConstants.prefKeyLanguageCode, newCode);
        print("[SettingsProvider] Saved language code: $newCode");
      }
    } catch (e) {
      print("!!! [SettingsProvider] Error saving locale: $e");
    }
  }
  // ------------------------
}
