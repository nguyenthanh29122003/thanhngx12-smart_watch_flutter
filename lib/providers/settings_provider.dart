// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_constants.dart'; // Cần key SharedPreferences

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system; // Mặc định theo hệ thống
  bool _isInitialized = false; // Cờ đánh dấu đã tải từ SharedPreferences chưa

  ThemeMode get themeMode => _themeMode;
  bool get isInitialized => _isInitialized;

  SettingsProvider() {
    _loadThemeMode(); // Tải theme đã lưu khi khởi tạo
    print("SettingsProvider Initialized.");
  }

  // Tải ThemeMode từ SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Đọc key đã lưu, trả về null nếu chưa có
      final themeString = prefs.getString(AppConstants.prefKeyThemeMode);
      print("[SettingsProvider] Loaded theme mode string: $themeString");

      if (themeString == 'light') {
        _themeMode = ThemeMode.light;
      } else if (themeString == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system; // Mặc định hoặc nếu giá trị không hợp lệ
      }
    } catch (e) {
      print("!!! [SettingsProvider] Error loading theme mode: $e");
      _themeMode = ThemeMode.system; // Dùng mặc định nếu có lỗi
    } finally {
      _isInitialized = true; // Đánh dấu đã khởi tạo xong
      notifyListeners(); // Thông báo để UI cập nhật (nếu cần)
      print("[SettingsProvider] Current theme mode after load: $_themeMode");
    }
  }

  // Cập nhật ThemeMode và lưu vào SharedPreferences
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    // Nếu newThemeMode là null hoặc không thay đổi thì không làm gì
    if (newThemeMode == null || newThemeMode == _themeMode) return;

    _themeMode = newThemeMode;
    print("[SettingsProvider] Updating theme mode to: $_themeMode");
    notifyListeners(); // Cập nhật UI ngay lập tức

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
      print(
        "[SettingsProvider] Saved theme mode to SharedPreferences: $themeString",
      );
    } catch (e) {
      print("!!! [SettingsProvider] Error saving theme mode: $e");
    }
  }
}
