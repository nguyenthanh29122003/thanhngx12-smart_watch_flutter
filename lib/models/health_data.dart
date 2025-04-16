// lib/models/health_data.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho Timestamp
import 'package:flutter/foundation.dart';
import '../services/local_db_service.dart';

class HealthData {
  final double ax, ay, az, gx, gy, gz;
  final int steps, hr, spo2, ir, red;
  final bool wifi;
  final DateTime
      timestamp; // Lưu ý: Timestamp này nên là UTC nếu lấy từ DB/Server

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
  });

  // Factory constructor để tạo từ JSON (dùng khi nhận từ BLE)
  factory HealthData.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      final timestampString = json['timestamp'];
      if (timestampString == null ||
          timestampString == "Not initialized" ||
          timestampString is! String) {
        parsedTimestamp = DateTime.now().toUtc(); // Luôn dùng UTC để nhất quán
      } else {
        // Giả sử timestamp từ ESP32 là giờ địa phương, chuyển sang UTC
        // Hoặc nếu ESP32 đã gửi UTC thì không cần .toUtc()
        parsedTimestamp = DateTime.parse(timestampString).toUtc();
      }
    } catch (e) {
      print(
        "[HealthData] Error parsing timestamp: ${json['timestamp']}. Using DateTime.now(). Error: $e",
      );
      parsedTimestamp = DateTime.now().toUtc();
    }

    T _parseNum<T extends num>(dynamic value, T defaultValue) {
      if (value is num) {
        if (defaultValue is double) return value.toDouble() as T;
        if (defaultValue is int) return value.toInt() as T;
      }
      return defaultValue;
    }

    return HealthData(
      ax: _parseNum(json['ax'], 0.0),
      ay: _parseNum(json['ay'], 0.0),
      az: _parseNum(json['az'], 0.0),
      gx: _parseNum(json['gx'], 0.0),
      gy: _parseNum(json['gy'], 0.0),
      gz: _parseNum(json['gz'], 0.0),
      steps: _parseNum(json['steps'], 0),
      hr: _parseNum(json['hr'], -1),
      spo2: _parseNum(json['spo2'], -1),
      ir: _parseNum(json['ir'], 0),
      red: _parseNum(json['red'], 0),
      wifi: (json['wifi'] as bool?) ?? false,
      timestamp: parsedTimestamp, // Đã là UTC
    );
  }

  // Chuyển đổi thành Map để lưu vào Firestore
  Map<String, dynamic> toJsonForFirestore() => {
        'ax': ax, 'ay': ay, 'az': az,
        'gx': gx, 'gy': gy, 'gz': gz,
        'steps': steps, 'hr': hr, 'spo2': spo2,
        'ir': ir, 'red': red, 'wifi': wifi,
        // Firestore Timestamp lưu trực tiếp từ DateTime (nên là UTC)
        'recordedAt': Timestamp.fromDate(timestamp),
      };

  // (Tùy chọn) Thêm factory constructor để tạo từ Map của SQLite
  factory HealthData.fromDbMap(Map<String, dynamic> map) {
    // Lấy giá trị từ map, kiểm tra null hoặc dùng giá trị mặc định nếu cần
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
      wifi: (map[LocalDbService.columnWifi] as int?) ==
          1, // Chuyển int thành bool
      // Chuyển int milliseconds (đã lưu là UTC) thành DateTime UTC
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map[LocalDbService.columnTimestamp] as int? ?? 0,
        isUtc: true,
      ),
    );
  }

  // Factory mới để tạo từ Map của Firestore
  factory HealthData.fromFirestoreMap(Map<String, dynamic> map) {
    // Lấy Timestamp từ Firestore và kiểm tra null
    Timestamp? recordTimestamp = map['recordedAt'] as Timestamp?;
    // Chuyển đổi Timestamp Firestore thành DateTime (giữ UTC để nhất quán)
    final DateTime timestampUTC = recordTimestamp?.toDate().toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0,
            isUtc: true); // Hoặc dùng DateTime.now().toUtc() nếu muốn

    // Hàm helper parse số, trả về giá trị mặc định nếu null hoặc sai kiểu
    T _parseNum<T extends num>(dynamic value, T defaultValue) {
      if (value == null) return defaultValue;
      if (value is String) {
        // Xử lý nếu lỡ lưu thành String
        if (defaultValue is double)
          return (double.tryParse(value) ?? defaultValue) as T;
        if (defaultValue is int)
          return (int.tryParse(value) ?? defaultValue) as T;
      }
      if (value is num) {
        if (defaultValue is double) return value.toDouble() as T;
        if (defaultValue is int) return value.toInt() as T;
      }
      return defaultValue;
    }

    return HealthData(
      ax: _parseNum(map['ax'], 0.0),
      ay: _parseNum(map['ay'], 0.0),
      az: _parseNum(map['az'], 0.0),
      gx: _parseNum(map['gx'], 0.0),
      gy: _parseNum(map['gy'], 0.0),
      gz: _parseNum(map['gz'], 0.0),
      steps: _parseNum(map['steps'], 0),
      hr: _parseNum(map['hr'], -1), // Giữ -1 nếu không có hoặc null
      spo2: _parseNum(map['spo2'], -1), // Giữ -1 nếu không có hoặc null
      ir: _parseNum(map['ir'], 0),
      red: _parseNum(map['red'], 0),
      wifi: (map['wifi'] as bool?) ?? false,
      timestamp: timestampUTC, // Sử dụng DateTime UTC đã parse
    );
  }

  // // Factory mới để tạo từ Map của Firestore
  // factory HealthData.fromFirestoreMap(Map<String, dynamic> map) {
  //   // Lấy Timestamp từ Firestore
  //   Timestamp? timestamp = map['recordedAt'] as Timestamp?;

  //   T _parseNum<T extends num>(dynamic value, T defaultValue) {
  //     /* ... */
  //   }

  //   return HealthData(
  //     ax: _parseNum(map['ax'], 0.0),
  //     ay: _parseNum(map['ay'], 0.0),
  //     az: _parseNum(map['az'], 0.0),
  //     // ... các trường khác tương tự ...
  //     steps: _parseNum(map['steps'], 0),
  //     hr: _parseNum(map['hr'], -1),
  //     spo2: _parseNum(map['spo2'], -1),
  //     ir: _parseNum(map['ir'], 0),
  //     red: _parseNum(map['red'], 0),
  //     wifi: (map['wifi'] as bool?) ?? false,
  //     // Chuyển đổi Timestamp Firestore thành DateTime (giữ UTC hoặc toLocal tùy ý)
  //     timestamp:
  //         timestamp?.toDate().toUtc() ?? DateTime.now().toUtc(), // Giữ UTC
  //   );
  // }
}

// --- Thêm LocalDbService vào đây nếu không muốn import ngược ---
// class LocalDbService {
//   static const columnAx = 'ax';
//   // ... định nghĩa các tên cột khác ...
// }
