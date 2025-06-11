// lib/models/relay_data.dart
import 'dart:math';
import 'dart:convert';

// Loại dữ liệu được gửi đi
enum RelayDataType {
  unknown,
  googleMapsNavigation,
  genericNotification,
  phoneCall,
  wifiConfig, // Cho cấu hình WiFi
  timeSync, // Cho đồng bộ thời gian
}

// Loại chỉ dẫn/biểu tượng cho Google Maps
enum NavigationDirection {
  unknown,
  straight,
  turnLeft,
  turnRight,
  sharpLeft,
  sharpRight,
  uTurn,
  roundabout,
  merge,
  fork,
  destination,
  keepLeft,
  keepRight,
}

class RelayData {
  final RelayDataType type;
  final String source; // Ví dụ: "Google Maps", "App"
  final String title; // Tiêu đề chính (VD: khoảng cách, tên người gọi, SSID)
  final String content; // Nội dung (VD: hướng dẫn, nội dung tin nhắn, password)
  final int? iconId; // ID của icon để đồng hồ hiển thị
  final int? progress; // Tiến độ (0-100), ví dụ cho % quãng đường
  final String? time; // Ví dụ: Tổng thời gian còn lại "15 min"

  RelayData({
    required this.type,
    required this.source,
    required this.title,
    required this.content,
    this.iconId,
    this.progress,
    this.time,
  });

  /// Chuyển đổi thành một Map nhỏ gọn để gửi qua BLE.
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      't': type.index, // type (QUAN TRỌNG NHẤT)
      's': source, // source
      'ti': title, // title
      'c': content, // content
    };
    if (iconId != null) data['i'] = iconId; // iconId
    if (progress != null) data['p'] = progress; // progress
    if (time != null) data['tm'] = time; // time

    return data;
  }
}
