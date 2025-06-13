// lib/models/navigation_data.dart

import 'package:flutter/foundation.dart';

@immutable
class NavigationData {
  // Dữ liệu đã được xử lý để gửi đi
  final String nextTurnDistance; // Ví dụ: "350 m", "Bây giờ"
  final String nextTurnDirection; // Ví dụ: "Rẽ phải", "Đi thẳng"
  final String streetName; // Ví dụ: "vào Đ. Pasteur", "" (rỗng nếu không có)
  final String totalRemainingDistance; // Ví dụ: "1,3 km"
  final String totalRemainingTime; // Ví dụ: "2 phút"
  final String eta; // Ví dụ: "Dự kiến 2:21"

  const NavigationData({
    required this.nextTurnDistance,
    required this.nextTurnDirection,
    required this.streetName,
    required this.totalRemainingDistance,
    required this.totalRemainingTime,
    required this.eta,
  });

  // Hàm toJson để đóng gói dữ liệu gửi qua BLE
  Map<String, dynamic> toJson() {
    return {
      'type': 'navigation', // Để firmware biết đây là loại thông báo gì
      'nextTurnDistance': nextTurnDistance,
      'nextTurnDirection': nextTurnDirection,
      'streetName': streetName,
      'totalRemainingDistance': totalRemainingDistance,
      'totalRemainingTime': totalRemainingTime,
      'eta': eta,
    };
  }

  // Override operator == để so sánh 2 đối tượng, tránh gửi dữ liệu trùng lặp
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NavigationData &&
        other.nextTurnDistance == nextTurnDistance &&
        other.nextTurnDirection == nextTurnDirection &&
        other.streetName == streetName &&
        other.totalRemainingDistance == totalRemainingDistance &&
        other.totalRemainingTime == totalRemainingTime &&
        other.eta == eta;
  }

  @override
  int get hashCode {
    return nextTurnDistance.hashCode ^
        nextTurnDirection.hashCode ^
        streetName.hashCode ^
        totalRemainingDistance.hashCode ^
        totalRemainingTime.hashCode ^
        eta.hashCode;
  }

  // (Tùy chọn) Hàm toString để debug
  @override
  String toString() {
    return 'NavData(dist: $nextTurnDistance, dir: $nextTurnDirection, street: $streetName, totalDist: $totalRemainingDistance, totalTime: $totalRemainingTime, eta: $eta)';
  }
}
