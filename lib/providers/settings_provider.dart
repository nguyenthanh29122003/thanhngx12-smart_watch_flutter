// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_constants.dart'; // Đã có các key mới
import '../generated/app_localizations.dart';

class SettingsProvider with ChangeNotifier {
  // --- State cho Theme ---
  ThemeMode _themeMode = ThemeMode.system;

  // --- State cho Locale ---
  Locale? _appLocale;

  // --- State cho Notifications chung ---
  bool _notificationsEnabled = true; // Đã có

  // --- State khởi tạo ---
  bool _isInitialized = false;

  // <<< THÊM STATE CHO CÀI ĐẶT ACTIVITY RECOGNITION >>>
  Duration _sittingWarningThreshold =
      AppConstants.defaultSittingWarningThreshold;
  Duration _lyingDaytimeWarningThreshold =
      AppConstants.defaultLyingWarningDaytimeThreshold;
  bool _smartRemindersEnabled = AppConstants.defaultSmartRemindersEnabled;
  double _userWeightKg = AppConstants.defaultUserWeightKg;
  Duration _minMovementDurationToResetWarning =
      AppConstants.minMovementDurationToResetWarning;
  Duration _periodicAnalysisInterval = AppConstants.periodicAnalysisInterval;
  // ----------------------------------------------------

  // --- Getters ---
  ThemeMode get themeMode => _themeMode;
  Locale? get appLocale => _appLocale;
  bool get isInitialized => _isInitialized;
  bool get notificationsEnabled => _notificationsEnabled;

  // <<< THÊM GETTERS CHO CÀI ĐẶT MỚI >>>
  Duration get sittingWarningThreshold => _sittingWarningThreshold;
  Duration get lyingDaytimeWarningThreshold => _lyingDaytimeWarningThreshold;
  bool get smartRemindersEnabled => _smartRemindersEnabled;
  double get userWeightKg => _userWeightKg;
  Duration get minMovementDurationToResetWarning =>
      _minMovementDurationToResetWarning;
  Duration get periodicAnalysisInterval => _periodicAnalysisInterval;
  // ------------------------------------

  SettingsProvider() {
    _loadSettings();
    if (kDebugMode)
      print("[SettingsProvider] Initialized. Loading settings...");
  }

  Future<void> _loadSettings() async {
    if (_isInitialized && WidgetsBinding.instance.lifecycleState != null) {
      // Nếu đã init và app đang chạy (không phải lần đầu), không cần load lại trừ khi có lý do đặc biệt
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load Theme
      final themeString = prefs.getString(AppConstants.prefKeyThemeMode);
      if (themeString == 'light')
        _themeMode = ThemeMode.light;
      else if (themeString == 'dark')
        _themeMode = ThemeMode.dark;
      else
        _themeMode = ThemeMode.system;

      // Load Locale
      final languageCode = prefs.getString(AppConstants.prefKeyLanguageCode);
      if (languageCode != null && languageCode.isNotEmpty) {
        if (AppLocalizations.supportedLocales
            .any((locale) => locale.languageCode == languageCode)) {
          _appLocale = Locale(languageCode);
        } else {
          _appLocale = null; // Fallback
          await prefs.remove(AppConstants.prefKeyLanguageCode);
        }
      } else {
        _appLocale = null;
      }

      // Load Notifications Enabled State
      _notificationsEnabled =
          prefs.getBool(AppConstants.prefKeyNotificationsEnabled) ?? true;

      // <<< LOAD CÀI ĐẶT CHO ACTIVITY RECOGNITION >>>
      _sittingWarningThreshold = Duration(
          minutes: prefs.getInt(AppConstants.prefKeySittingWarningMinutes) ??
              AppConstants.defaultSittingWarningThreshold.inMinutes);
      _lyingDaytimeWarningThreshold = Duration(
          hours: prefs.getInt(AppConstants.prefKeyLyingWarningHours) ??
              AppConstants.defaultLyingWarningDaytimeThreshold.inHours);
      _smartRemindersEnabled =
          prefs.getBool(AppConstants.prefKeySmartRemindersEnabled) ??
              AppConstants.defaultSmartRemindersEnabled;
      _userWeightKg = prefs.getDouble(AppConstants.prefKeyUserWeightKg) ??
          AppConstants.defaultUserWeightKg;

      _minMovementDurationToResetWarning = Duration(
          minutes:
              prefs.getInt(AppConstants.prefKeyMinMovementToResetMinutes) ??
                  AppConstants.minMovementDurationToResetWarning.inMinutes);
      _periodicAnalysisInterval = Duration(
          hours: prefs.getInt(AppConstants.prefKeyPeriodicAnalysisHours) ??
              AppConstants.periodicAnalysisInterval.inHours);
      // ---------------------------------------------

      if (kDebugMode) {
        print("[SettingsProvider] Settings loaded from SharedPreferences:");
        print(
            "  Theme: $_themeMode, Locale: ${_appLocale?.languageCode ?? 'system'}");
        print("  Notifications Enabled: $_notificationsEnabled");
        print("  Sitting Threshold: ${_sittingWarningThreshold.inMinutes} min");
        print(
            "  Lying Threshold: ${_lyingDaytimeWarningThreshold.inHours} hours");
        print("  Smart Reminders: $_smartRemindersEnabled");
        print("  User Weight: $_userWeightKg kg");
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [SettingsProvider] Error loading settings: $e. Using defaults.");
      // Reset về mặc định nếu có lỗi nghiêm trọng
      _themeMode = ThemeMode.system;
      _appLocale = null;
      _notificationsEnabled = true;
      _sittingWarningThreshold = AppConstants.defaultSittingWarningThreshold;
      _lyingDaytimeWarningThreshold =
          AppConstants.defaultLyingWarningDaytimeThreshold;
      _smartRemindersEnabled = AppConstants.defaultSmartRemindersEnabled;
      _userWeightKg = AppConstants.defaultUserWeightKg;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  // --- Cập nhật Theme --- (Giữ nguyên)
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    /* ... */
    if (newThemeMode == null || newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    notifyListeners();
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
        default:
          themeString = 'system';
          break;
      }
      await prefs.setString(AppConstants.prefKeyThemeMode, themeString);
    } catch (e) {
      if (kDebugMode) print("!!! [SettingsProvider] Error saving theme: $e");
    }
  }

  // --- Cập nhật Locale --- (Giữ nguyên)
  Future<void> updateLocale(Locale? newLocale) async {
    /* ... */
    final currentCode = _appLocale?.languageCode;
    final newCode = newLocale?.languageCode;
    if (currentCode == newCode && newLocale != null && _appLocale != null)
      return; // Thêm kiểm tra null
    if (currentCode == null && newCode == null) return;

    _appLocale = newLocale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (newCode == null) {
        await prefs.remove(AppConstants.prefKeyLanguageCode);
      } else {
        await prefs.setString(AppConstants.prefKeyLanguageCode, newCode);
      }
    } catch (e) {
      if (kDebugMode) print("!!! [SettingsProvider] Error saving locale: $e");
    }
  }

  // --- Cập nhật Trạng thái Notifications Chung --- (Giữ nguyên)
  Future<void> updateNotificationsEnabled(bool isEnabled) async {
    /* ... */
    if (_notificationsEnabled == isEnabled) return;
    _notificationsEnabled = isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
          AppConstants.prefKeyNotificationsEnabled, _notificationsEnabled);
    } catch (e) {
      if (kDebugMode)
        print("!!! [SettingsProvider] Error saving notifications enabled: $e");
    }
  }

  // <<< THÊM CÁC HÀM UPDATE CHO CÀI ĐẶT ACTIVITY RECOGNITION >>>

  Future<void> updateSittingWarningThreshold(Duration newThreshold) async {
    if (_sittingWarningThreshold == newThreshold) return;
    _sittingWarningThreshold = newThreshold;
    notifyListeners(); // Thông báo cho UI và ActivityRecognitionService (nếu nó lắng nghe provider này)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          AppConstants.prefKeySittingWarningMinutes, newThreshold.inMinutes);
      if (kDebugMode)
        print(
            "[SettingsProvider] Saved sitting warning threshold: ${newThreshold.inMinutes} min");
    } catch (e) {
      if (kDebugMode)
        print("!!! [SettingsProvider] Error saving sitting threshold: $e");
    }
  }

  Future<void> updateMinMovementDuration(Duration newDuration) async {
    if (_minMovementDurationToResetWarning == newDuration) return;
    _minMovementDurationToResetWarning = newDuration;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        AppConstants.prefKeyMinMovementToResetMinutes, newDuration.inMinutes);
  }

  Future<void> updateLyingDaytimeWarningThreshold(Duration newThreshold) async {
    if (_lyingDaytimeWarningThreshold == newThreshold) return;
    _lyingDaytimeWarningThreshold = newThreshold;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          AppConstants.prefKeyLyingWarningHours, newThreshold.inHours);
      if (kDebugMode)
        print(
            "[SettingsProvider] Saved lying daytime warning threshold: ${newThreshold.inHours} hours");
    } catch (e) {
      if (kDebugMode)
        print("!!! [SettingsProvider] Error saving lying threshold: $e");
    }
  }

  Future<void> updateSmartRemindersEnabled(bool isEnabled) async {
    if (_smartRemindersEnabled == isEnabled) return;
    _smartRemindersEnabled = isEnabled;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefKeySmartRemindersEnabled, isEnabled);
      if (kDebugMode)
        print("[SettingsProvider] Saved smart reminders enabled: $isEnabled");
    } catch (e) {
      if (kDebugMode)
        print("!!! [SettingsProvider] Error saving smart reminders state: $e");
    }
  }

  Future<void> updateUserWeight(double newWeight) async {
    if (_userWeightKg == newWeight || newWeight <= 0)
      return; // Thêm kiểm tra newWeight > 0
    _userWeightKg = newWeight;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(AppConstants.prefKeyUserWeightKg, newWeight);
      if (kDebugMode)
        print("[SettingsProvider] Saved user weight: $newWeight kg");
    } catch (e) {
      if (kDebugMode)
        print("!!! [SettingsProvider] Error saving user weight: $e");
    }
  }
  // -----------------------------------------------------------
}
