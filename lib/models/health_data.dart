// lib/models/health_data.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho Timestamp
import 'package:flutter/foundation.dart'; // Cho kDebugMode
// Import chỉ class LocalDbService để lấy tên cột tĩnh
import '../services/local_db_service.dart' show LocalDbService;

class HealthData {
  final double ax, ay, az, gx, gy, gz;
  final int steps, hr, spo2, ir, red;
  final bool wifi;
  final DateTime timestamp; // Nên luôn là UTC trong model này
  // <<< THÊM TRƯỜNG MỚI (NULLABLE) >>>
  final double? temperature; // Độ C
  final double? pressure; // Pascal (Pa)

  HealthData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.steps,
    required this.hr,
    required this.spo2,
    required this.ir,
    required this.red,
    required this.wifi,
    required this.timestamp,
    // <<< THÊM VÀO CONSTRUCTOR >>>
    this.temperature,
    this.pressure,
  });

  // --- Factory constructor để tạo từ JSON (nhận từ BLE) ---
  factory HealthData.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      final timestampString = json['timestamp'];
      if (timestampString == null ||
          timestampString == "Not initialized" ||
          timestampString is! String) {
        if (kDebugMode)
          print(
              "[HealthData fromJson] Invalid or missing timestamp in JSON, using current UTC time.");
        parsedTimestamp = DateTime.now().toUtc();
      } else {
        // Cố gắng parse, nếu thất bại thì dùng thời gian hiện tại
        parsedTimestamp = DateTime.tryParse(timestampString)?.toUtc() ??
            DateTime.now().toUtc();
        if (DateTime.tryParse(timestampString) == null && kDebugMode) {
          print(
              "[HealthData fromJson] Could not parse timestamp string: '$timestampString', using current UTC time.");
        }
      }
    } catch (e) {
      if (kDebugMode)
        print(
            "[HealthData fromJson] Error parsing timestamp: ${json['timestamp']}. Using current UTC time. Error: $e");
      parsedTimestamp = DateTime.now().toUtc();
    }

    // Hàm helper parse số non-nullable
    T _parseNum<T extends num>(dynamic value, T defaultValue) {
      if (value is num) {
        if (defaultValue is double) return value.toDouble() as T;
        if (defaultValue is int) return value.toInt() as T;
      }
      if (value is String) {
        // Thử parse từ String
        if (defaultValue is double)
          return (double.tryParse(value) ?? defaultValue) as T;
        if (defaultValue is int)
          return (int.tryParse(value) ?? defaultValue) as T;
      }
      // Trả về default nếu là null hoặc kiểu không đúng
      if (value != null && kDebugMode)
        print(
            "[HealthData _parseNum] Unexpected type for value '$value' (expected $T), returning default $defaultValue");
      return defaultValue;
    }

    // Hàm helper parse số nullable (cho temp, pres)
    double? _parseNullableDouble(dynamic value) {
      if (value == null) return null; // Trả về null nếu input là null
      if (value is num) return value.toDouble();
      if (value is String)
        return double.tryParse(value); // Thử parse nếu là string
      if (kDebugMode)
        print(
            "[HealthData _parseNullableDouble] Unexpected type for value '$value' (expected double?), returning null");
      return null; // Trả về null cho các kiểu khác
    }

    return HealthData(
      ax: _parseNum(json['ax'], 0.0), ay: _parseNum(json['ay'], 0.0),
      az: _parseNum(json['az'], 0.0),
      gx: _parseNum(json['gx'], 0.0), gy: _parseNum(json['gy'], 0.0),
      gz: _parseNum(json['gz'], 0.0),
      steps: _parseNum(json['steps'], 0),
      hr: _parseNum(json['hr'], -1), // Giữ -1 nếu không có hoặc lỗi
      spo2: _parseNum(json['spo2'], -1), // Giữ -1 nếu không có hoặc lỗi
      ir: _parseNum(json['ir'], 0),
      red: _parseNum(json['red'], 0),
      wifi: (json['wifi'] as bool?) ?? false, // Xử lý null cho bool
      timestamp: parsedTimestamp, // Đã là UTC
      // <<< PARSE TRƯỜNG MỚI TỪ JSON >>>
      temperature: _parseNullableDouble(json['temp']), // Key 'temp'
      pressure: _parseNullableDouble(json['pres']), // Key 'pres'
    );
  }

  // --- Chuyển đổi thành Map để lưu vào Firestore (KHÔNG bao gồm recordedAt) ---
  Map<String, dynamic> toJsonForFirestore() {
    final Map<String, dynamic> data = {
      'ax': ax, 'ay': ay, 'az': az,
      'gx': gx, 'gy': gy, 'gz': gz,
      'steps': steps, 'hr': hr, 'spo2': spo2,
      'ir': ir, 'red': red, 'wifi': wifi,
      // <<< THÊM TEMP/PRES NẾU KHÔNG NULL >>>
      if (temperature != null) 'temp': temperature,
      if (pressure != null) 'pres': pressure,
    };
    // Trường 'recordedAt' sẽ được FirestoreService thêm vào bằng FieldValue.serverTimestamp()
    // hoặc được lấy từ this.timestamp nếu cần độ chính xác từ client/thiết bị
    return data;
  }

  // --- Factory constructor để tạo từ Map của SQLite ---
  factory HealthData.fromDbMap(Map<String, dynamic> map) {
    // Hàm helper parse số nullable từ DB (thường là num? hoặc double?)
    if (kDebugMode) {
      print("--- [RAW DATA FROM BLE] --- \n$map\n--------------------------");
    }
    double? _parseNullableDoubleFromDb(dynamic value) {
      if (value is num) return value.toDouble();
      return null;
    }

    return HealthData(
      ax: (map[LocalDbService.columnAx] as num?)?.toDouble() ?? 0.0,
      ay: (map[LocalDbService.columnAy] as num?)?.toDouble() ?? 0.0,
      az: (map[LocalDbService.columnAz] as num?)?.toDouble() ?? 0.0,
      gx: (map[LocalDbService.columnGx] as num?)?.toDouble() ?? 0.0,
      gy: (map[LocalDbService.columnGy] as num?)?.toDouble() ?? 0.0,
      gz: (map[LocalDbService.columnGz] as num?)?.toDouble() ?? 0.0,
      steps: (map[LocalDbService.columnSteps] as num?)?.toInt() ?? 0,
      hr: (map[LocalDbService.columnHr] as num?)?.toInt() ?? -1,
      spo2: (map[LocalDbService.columnSpo2] as num?)?.toInt() ?? -1,
      ir: (map[LocalDbService.columnIr] as num?)?.toInt() ?? 0,
      red: (map[LocalDbService.columnRed] as num?)?.toInt() ?? 0,
      wifi: (map[LocalDbService.columnWifi] as int?) == 1,
      // Chuyển int milliseconds (đã lưu là UTC) thành DateTime UTC
      timestamp: DateTime.fromMillisecondsSinceEpoch(
          map[LocalDbService.columnTimestamp] as int? ?? 0,
          isUtc: true),
      // <<< ĐỌC TRƯỜNG MỚI TỪ SQLITE >>>
      temperature: _parseNullableDoubleFromDb(map[LocalDbService.columnTemp]),
      pressure: _parseNullableDoubleFromDb(map[LocalDbService.columnPres]),
    );
  }

  // --- Factory constructor để tạo từ Map của Firestore ---
  factory HealthData.fromFirestoreMap(Map<String, dynamic> map) {
    Timestamp? recordTimestamp = map['recordedAt'] as Timestamp?;
    final DateTime timestampUTC = recordTimestamp?.toDate().toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    // Hàm helper parse số non-nullable
    T _parseNum<T extends num>(dynamic value, T defaultValue) {
      if (value is num) {
        if (defaultValue is double) return value.toDouble() as T;
        if (defaultValue is int) return value.toInt() as T;
      }
      if (value is String) {
        if (defaultValue is double)
          return (double.tryParse(value) ?? defaultValue) as T;
        if (defaultValue is int)
          return (int.tryParse(value) ?? defaultValue) as T;
      }
      return defaultValue;
    }

    // Hàm helper parse số nullable
    double? _parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return HealthData(
      ax: _parseNum(map['ax'], 0.0), ay: _parseNum(map['ay'], 0.0),
      az: _parseNum(map['az'], 0.0),
      gx: _parseNum(map['gx'], 0.0), gy: _parseNum(map['gy'], 0.0),
      gz: _parseNum(map['gz'], 0.0),
      steps: _parseNum(map['steps'], 0),
      hr: _parseNum(map['hr'], -1), spo2: _parseNum(map['spo2'], -1),
      ir: _parseNum(map['ir'], 0), red: _parseNum(map['red'], 0),
      wifi: (map['wifi'] as bool?) ?? false,
      timestamp: timestampUTC, // Đã là UTC
      // <<< ĐỌC TRƯỜNG MỚI TỪ FIRESTORE >>>
      temperature: _parseNullableDouble(map['temp']),
      pressure: _parseNullableDouble(map['pres']),
    );
  }
}
