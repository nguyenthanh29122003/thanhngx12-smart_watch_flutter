// lib/app_constants.dart
class AppConstants {
  // BLE Configuration
  // <<< SỬA TÊN THIẾT BỊ NẾU ĐÃ ĐỔI TRÊN FIRMWARE >>>
  static const String targetDeviceName =
      "ESP32-S3 Watch"; // Thay vì "ESP32_SmartWatch"

  // --- UUID Dịch vụ Chính (Service UUID) ---
  // Giữ nguyên nếu không đổi trên firmware
  static const String bleServiceUUID = "12345678-1234-1234-1234-123456789012";

  // --- UUIDs của Đặc tính (Characteristic UUIDs) ---
  // Giữ nguyên UUID cho Health Data và WiFi/Time Config nếu không đổi
  static const String healthDataCharacteristicUUID =
      "12345678-1234-1234-1234-123456789013";
  static const String wifiConfigCharacteristicUUID =
      "beb5483e-36e1-4688-b7f5-ea07361b26a9"; // Dùng cho cả WiFi và Time

  // <<< THÊM UUID CHO STATUS CHARACTERISTIC >>>
  static const String statusCharacteristicUUID =
      "abce0001-ef00-1234-5678-90abcdef1234";
  // -----------------------------------------

  // Firestore Collections (giữ nguyên)
  static const String usersCollection = "users";
  static const String relativesSubcollection = "relatives";
  static const String healthDataSubcollection = "health_data";
  static const String goalsSubcollection = "goals";

  // SharedPreferences Keys (giữ nguyên)
  static const String prefKeyConnectedDeviceId = "connected_device_id";
  static const String prefKeyDailyStepGoal = "daily_step_goal";
  static const String prefKeyLanguageCode = "language_code";
  static const String prefKeyThemeMode = "theme_mode";
  static const String prefKeyNotificationsEnabled = "notifications_enabled";

  // Default Values (giữ nguyên)
  static const int defaultDailyStepGoal = 8000;

  // Health Thresholds (giữ nguyên)
  static const int hrLowThreshold = 50;
  static const int hrHighThreshold = 120;
  static const int spo2LowThreshold = 90;
}
