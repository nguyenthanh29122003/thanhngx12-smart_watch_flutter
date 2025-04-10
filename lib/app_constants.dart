// lib/app_constants.dart
class AppConstants {
  // BLE Configuration
  static const String targetDeviceName = "ESP32_SmartWatch";

  // --- UUID Dịch vụ Chính (Service UUID) ---
  // Khớp với Config.h và log
  static const String bleServiceUUID = "12345678-1234-1234-1234-123456789012";

  // --- UUIDs của Đặc tính (Characteristic UUIDs) ---
  // >>> ĐÃ SỬA ĐỂ KHỚP VỚI Config.h VÀ LOG <<<

  // UUID cho Health Data (có Notify trong log và Config.h)
  static const String healthDataCharacteristicUUID =
      "12345678-1234-1234-1234-123456789013";
  // static const String healthDataCharacteristicUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"; // UUID cũ không dùng

  // UUID cho WiFi Config (có Write trong log và Config.h)
  static const String wifiConfigCharacteristicUUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9";
  // static const String wifiConfigCharacteristicUUID = "1c95d5e3-d8f7-413a-bf3d-7d6d388e31c9"; // UUID cũ không dùng

  // Firestore Collections
  static const String usersCollection = "users";
  static const String relativesSubcollection = "relatives";
  static const String healthDataSubcollection = "health_data";
  static const String goalsSubcollection = "goals";
  // static const String devicesCollection = "devices"; // Tùy chọn

  // SharedPreferences Keys
  static const String prefKeyConnectedDeviceId = "connected_device_id";
  static const String prefKeyDailyStepGoal = "daily_step_goal";
  static const String prefKeyLanguageCode = "language_code";
  static const String prefKeyThemeMode = "theme_mode";
  static const String prefKeyNotificationsEnabled = "notifications_enabled";

  // Default Values
  static const int defaultDailyStepGoal = 8000;

  // Health Thresholds (Ví dụ)
  static const int hrLowThreshold = 50;
  static const int hrHighThreshold = 120;
  static const int spo2LowThreshold = 90;
}
