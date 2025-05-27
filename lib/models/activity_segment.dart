// lib/models/activity_segment.dart

import 'package:flutter/foundation.dart'; // Cho @required nếu dùng, hoặc cho kDebugMode

// Enum để định nghĩa các loại hoạt động một cách tường minh hơn là dùng string trực tiếp
// Điều này khớp với HAR_ACTIVITY_LABELS của bạn.
// Bạn có thể tạo enum này nếu muốn, hoặc tiếp tục dùng String từ HAR_ACTIVITY_LABELS.
// enum ActivityType {
//   Standing,
//   Lying,
//   Sitting,
//   Walking,
//   Running,
//   Unknown,
// }

class ActivitySegment {
  final int? id; // ID tự tăng từ cơ sở dữ liệu SQLite, có thể null khi tạo mới
  final String activityName; // Tên hoạt động, ví dụ: 'Sitting', 'Walking'
  final DateTime startTime; // Thời điểm bắt đầu của đoạn hoạt động này
  final DateTime endTime; // Thời điểm kết thúc của đoạn hoạt động này
  final int
      durationInSeconds; // Thời lượng của đoạn hoạt động này tính bằng giây
  double?
      caloriesBurned; // Lượng calo tiêu thụ ước tính (có thể được cập nhật sau)
  final String?
      userId; // ID của người dùng (nếu bạn muốn lưu trữ cho nhiều người dùng hoặc đồng bộ lên cloud)

  ActivitySegment({
    this.id,
    required this.activityName,
    required this.startTime,
    required this.endTime,
    required this.durationInSeconds,
    this.caloriesBurned,
    this.userId,
  }) : assert(durationInSeconds >= 0, 'Duration cannot be negative.');

  // Phương thức copyWith để dễ dàng tạo một bản sao với một vài giá trị được thay đổi
  // Rất hữu ích khi bạn muốn cập nhật một bản ghi (ví dụ: thêm caloriesBurned)
  ActivitySegment copyWith({
    int? id,
    String? activityName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationInSeconds,
    double? caloriesBurned,
    String? userId,
  }) {
    return ActivitySegment(
      id: id ?? this.id,
      activityName: activityName ?? this.activityName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      caloriesBurned: caloriesBurned ??
          this.caloriesBurned, // Cho phép null để xóa giá trị cũ
      userId: userId ?? this.userId,
    );
  }

  // --- Phương thức chuyển đổi sang Map để lưu vào SQLite ---
  Map<String, dynamic> toMap() {
    return {
      // 'id' không cần thiết khi insert nếu nó là INTEGER PRIMARY KEY AUTOINCREMENT
      'activityName': activityName,
      'startTime': startTime.toIso8601String(), // Lưu dưới dạng chuỗi ISO 8601
      'endTime': endTime.toIso8601String(),
      'durationInSeconds': durationInSeconds,
      'caloriesBurned': caloriesBurned,
      'userId': userId,
    };
  }

  // --- Phương thức tạo đối tượng từ Map (khi đọc từ SQLite) ---
  factory ActivitySegment.fromMap(Map<String, dynamic> map) {
    return ActivitySegment(
      id: map['id']
          as int?, // id có thể là null nếu chưa được gán hoặc không có trong map
      activityName: map['activityName'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      durationInSeconds: map['durationInSeconds'] as int,
      caloriesBurned: map['caloriesBurned'] as double?, // Cho phép null
      userId: map['userId'] as String?, // Cho phép null
    );
  }

  @override
  String toString() {
    return 'ActivitySegment(id: $id, activity: $activityName, start: $startTime, end: $endTime, duration: $durationInSeconds s, calories: ${caloriesBurned?.toStringAsFixed(2)})';
  }

  // (Tùy chọn) Triển khai toán tử == và hashCode nếu bạn cần so sánh các đối tượng ActivitySegment
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivitySegment &&
        other.id == id &&
        other.activityName == activityName &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.durationInSeconds == durationInSeconds &&
        other.caloriesBurned == caloriesBurned &&
        other.userId == userId;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        activityName.hashCode ^
        startTime.hashCode ^
        endTime.hashCode ^
        durationInSeconds.hashCode ^
        caloriesBurned.hashCode ^
        userId.hashCode;
  }
}
