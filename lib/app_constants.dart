// lib/app_constants.dart

import 'package:flutter/material.dart'; // Cần cho Duration nếu dùng ở đây

class AppConstants {
  // BLE Configuration
  static const String targetDeviceName = "ESP32-S3 Watch";
  static const String bleServiceUUID = "12345678-1234-1234-1234-123456789012";
  static const String healthDataCharacteristicUUID =
      "12345678-1234-1234-1234-123456789013";
  static const String wifiConfigCharacteristicUUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // Dùng cho cả WiFi và Time
  static const String statusCharacteristicUUID =
      "abce0001-ef00-1234-5678-90abcdef1234";
  static const int bleScanTimeoutSeconds = 15; // Thời gian quét BLE
  static const int bleConnectionTimeoutSeconds =
      20; // Thời gian chờ kết nối BLE
  static const int bleServiceDiscoveryTimeoutSeconds =
      10; // Thời gian chờ khám phá services

  // Firestore Collections
  static const String usersCollection = "users";
  static const String relativesSubcollection = "relatives";
  static const String healthDataSubcollection = "health_data";
  static const String goalsSubcollection = "goals";
  // <<< THÊM COLLECTION CHO ACTIVITY SEGMENTS (NẾU BẠN ĐỒNG BỘ LÊN FIRESTORE) >>>
  static const String activitySegmentsSubcollection = "activity_segments";
  // --------------------------------------------------------------------

  // Data Sync
  static const int firestoreSyncBatchLimit = 50; // <<< THÊM HẰNG SỐ NÀY

  // SharedPreferences Keys
  static const String prefKeyConnectedDeviceId = "connected_device_id";
  static const String prefKeyDailyStepGoal = "daily_step_goal";
  static const String prefKeyLanguageCode = "language_code";
  static const String prefKeyThemeMode = "theme_mode";
  static const String prefKeyNotificationsEnabled = "notifications_enabled";
  // <<< THÊM KEYS CHO ACTIVITY RECOGNITION & SETTINGS >>>
  static const String prefKeyLastKnownActivity = "last_known_activity";
  static const String prefKeyLastKnownActivityTimestamp =
      "last_known_activity_timestamp";
  static const String prefKeyUserWeightKg = "user_weight_kg";
  static const String prefKeySittingWarningMinutes = "sitting_warning_minutes";
  static const String prefKeyLyingWarningHours = "lying_warning_hours_daytime";
  static const String prefKeySmartRemindersEnabled = "smart_reminders_enabled";
  // -------------------------------------------------

  // Default Values
  static const int defaultDailyStepGoal = 8000;
  static const double defaultUserWeightKg = 70.0; // Ví dụ cân nặng mặc định
  static const Duration defaultSittingWarningThreshold = Duration(minutes: 60);
  static const Duration defaultLyingWarningDaytimeThreshold =
      Duration(hours: 2);
  static const int minActivityDurationToLogSeconds =
      60; // Ít nhất 1 phút mới lưu lịch sử
  static const double harMinConfidenceThreshold =
      0.60; // Ngưỡng tin cậy tối thiểu cho dự đoán HAR

  // Health Thresholds
  static const int hrLowThreshold = 50;
  static const int hrHighThreshold = 120;
  static const int spo2LowThreshold = 90;
  static const Duration notificationCooldownDuration =
      Duration(minutes: 15); // Thời gian chờ giữa các thông báo cùng loại

  // Activity Recognition Timing
  static const int daytimeStartHour = 8; // 8 AM
  static const int daytimeEndHour = 22; // 10 PM (trước 10 PM)

  // Navigation & UI
  static const int goalsScreenIndex = 2; // Giữ nguyên
  static const int dashboardScreenIndex = 0; // Ví dụ
  static const int settingsScreenIndex = 3; // Ví dụ

  // API Keys (Nếu có, nhưng thường nên để trong .env)
  // static const String openRouterApiKey = "YOUR_OPENROUTER_API_KEY"; // Lấy từ .env tốt hơn
}
