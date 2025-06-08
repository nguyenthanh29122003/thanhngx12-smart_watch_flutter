// lib/app_constants.dart
class AppConstants {
  // BLE Configuration
  static const String targetDeviceName = "ESP32-S3 Watch";
  static const String bleServiceUUID = "12345678-1234-1234-1234-123456789012";
  static const String healthDataCharacteristicUUID =
      "12345678-1234-1234-1234-123456789013";
  static const String wifiConfigCharacteristicUUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  static const String statusCharacteristicUUID =
      "abce0001-ef00-1234-5678-90abcdef1234";
  static const int bleScanTimeoutSeconds = 15;
  static const int bleConnectionTimeoutSeconds = 20;
  static const int bleServiceDiscoveryTimeoutSeconds = 10;

  // Firestore Collections
  static const String usersCollection = "users";
  static const String relativesSubcollection = "relatives";
  static const String healthDataSubcollection = "health_data";
  static const String goalsSubcollection = "goals";
  static const String activitySegmentsSubcollection = "activity_segments";

  // Data Sync
  static const int firestoreSyncBatchLimit = 50;

  // SharedPreferences Keys
  static const String prefKeyConnectedDeviceId = "connected_device_id";
  static const String prefKeyDailyStepGoal = "daily_step_goal";
  static const String prefKeyLanguageCode = "language_code";
  static const String prefKeyThemeMode = "theme_mode";
  static const String prefKeyNotificationsEnabled = "notifications_enabled";
  static const String prefKeyLastKnownActivity = "last_known_activity";
  static const String prefKeyLastKnownActivityTimestamp =
      "last_known_activity_timestamp";
  static const String prefKeyUserWeightKg = "user_weight_kg";
  // <<< ĐÃ THÊM CÁC KEYS MỚI CHO CÀI ĐẶT CẢNH BÁO >>>
  static const String prefKeySittingWarningMinutes =
      "pref_sitting_warning_minutes";
  static const String prefKeyLyingWarningHours =
      "pref_lying_warning_hours_daytime";
  static const String prefKeySmartRemindersEnabled =
      "pref_smart_reminders_enabled";
  // -------------------------------------------------

  // Default Values
  static const int defaultDailyStepGoal = 8000;
  static const double defaultUserWeightKg = 70.0;
  static const Duration defaultSittingWarningThreshold = Duration(minutes: 1);
  static const Duration defaultLyingWarningDaytimeThreshold =
      Duration(hours: 2);
  static const int minActivityDurationToLogSeconds = 60;
  static const double harMinConfidenceThreshold = 0.60;
  static const bool defaultSmartRemindersEnabled =
      true; // <<< GIÁ TRỊ MẶC ĐỊNH CHO SMART REMINDERS
  // <<< THÊM HẰNG SỐ CHO KHOẢNG THỜI GIAN NHẮC NHỞ THÔNG MINH >>>
  static const int smartReminderIntervalMinutes =
      30; // Ví dụ: nhắc sau mỗi 30 phút ngồi
  // ---------------------------------------------------------

  // Health Thresholds
  static const int hrLowThreshold = 50;
  static const int hrHighThreshold = 120;
  static const int spo2LowThreshold = 90;
  static const Duration notificationCooldownDuration = Duration(minutes: 15);

  // Activity Recognition Timing
  static const Duration minMovementDurationToResetWarning =
      Duration(minutes: 5); // <<< THÊM HẰNG SỐ NÀY
  static const int daytimeStartHour = 8; // 8 AM
  static const int daytimeEndHour = 22; // 10 PM (trước 10 PM)

  // Navigation & UI
  static const int goalsScreenIndex = 2;
  static const int dashboardScreenIndex = 0;
  static const int settingsScreenIndex = 3;

  // API Keys (Nên để trong .env)
  // static const String openRouterApiKey = "YOUR_OPENROUTER_API_KEY";

  // Notification Channels for Reconnect
  static const String bleReconnectChannelId = "ble_reconnect";
  static const String bleReconnectChannelName = "BLE Reconnect";
  static const String bleReconnectChannelDescription =
      "Notifications for BLE reconnection events";
}
