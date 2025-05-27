// lib/models/activity_segment.dart
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho Timestamp
import 'package:flutter/foundation.dart';

class ActivitySegment {
  final int? id;
  final String activityName;
  final DateTime startTime; // Nên là UTC
  final DateTime endTime; // Nên là UTC
  final int durationInSeconds;
  double? caloriesBurned;
  final String?
      userId; // ID của người dùng локально, có thể không cần khi lên Firestore nếu đã có path
  bool
      isSynced; // <<< THÊM MỚI: Trạng thái đồng bộ, mặc định là false khi tạo mới

  ActivitySegment({
    this.id,
    required this.activityName,
    required this.startTime,
    required this.endTime,
    required this.durationInSeconds,
    this.caloriesBurned,
    this.userId,
    this.isSynced = false, // <<< THÊM MỚI: Mặc định
  }) : assert(durationInSeconds >= 0, 'Duration cannot be negative.');

  ActivitySegment copyWith({
    int? id,
    String? activityName,
    DateTime? startTime,
    DateTime? endTime,
    int? durationInSeconds,
    double? caloriesBurned,
    String? userId,
    bool? isSynced, // <<< THÊM MỚI
  }) {
    return ActivitySegment(
      id: id ?? this.id,
      activityName: activityName ?? this.activityName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced, // <<< THÊM MỚI
    );
  }

  Map<String, dynamic> toMap() {
    // Dùng cho SQLite
    return {
      // 'id' sẽ được SQLite tự tạo nếu là null khi insert
      if (id != null) 'id': id, // Chỉ thêm id vào map nếu nó không null
      'activityName': activityName,
      'startTime': startTime.toIso8601String(), // UTC
      'endTime': endTime.toIso8601String(), // UTC
      'durationInSeconds': durationInSeconds,
      'caloriesBurned': caloriesBurned,
      'userId': userId,
      'is_synced': isSynced ? 1 : 0, // <<< THÊM MỚI: Lưu 0 hoặc 1 vào SQLite
    };
  }

  factory ActivitySegment.fromMap(Map<String, dynamic> map) {
    // Đọc từ SQLite
    return ActivitySegment(
      id: map['id'] as int?,
      activityName: map['activityName'] as String,
      startTime: DateTime.parse(map['startTime'] as String)
          .toUtc(), // Đảm bảo đọc là UTC
      endTime: DateTime.parse(map['endTime'] as String)
          .toUtc(), // Đảm bảo đọc là UTC
      durationInSeconds: map['durationInSeconds'] as int,
      caloriesBurned: map['caloriesBurned'] as double?,
      userId: map['userId'] as String?,
      isSynced:
          (map['is_synced'] as int? ?? 0) == 1, // <<< THÊM MỚI: Đọc từ SQLite
    );
  }

  // --- Phương thức chuyển đổi sang Map để lưu vào Firestore ---
  Map<String, dynamic> toJsonForFirestore() {
    final Map<String, dynamic> data = {
      'activityName': activityName,
      // Chuyển DateTime sang Timestamp của Firestore
      'startTime': Timestamp.fromDate(startTime), // startTime đã là UTC
      'endTime': Timestamp.fromDate(endTime), // endTime đã là UTC
      'durationInSeconds': durationInSeconds,
      if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
      // 'userId' có thể không cần thiết nếu document được lưu dưới users/{userId}/activity_segments
      // 'isSynced' không cần thiết trên Firestore, vì chỉ những cái đã synced mới lên đây
    };
    return data;
  }

  // Factory constructor để tạo từ Map của Firestore (nếu bạn cần đọc lại từ Firestore)
  factory ActivitySegment.fromFirestoreMap(Map<String, dynamic> map,
      String documentId /* Hoặc lấy id nếu bạn lưu id trong document */) {
    return ActivitySegment(
      // id: documentId, // Nếu bạn dùng documentId làm id cục bộ, hoặc parse từ trường 'id' nếu có
      activityName: map['activityName'] as String,
      startTime: (map['startTime'] as Timestamp).toDate().toUtc(),
      endTime: (map['endTime'] as Timestamp).toDate().toUtc(),
      durationInSeconds: map['durationInSeconds'] as int,
      caloriesBurned: map['caloriesBurned'] as double?,
      // userId: map['userId'] as String?, // Nếu có
      isSynced: true, // Mặc định là true vì nó đến từ Firestore
    );
  }

  @override
  String toString() {
    return 'ActivitySegment(id: $id, activity: $activityName, start: $startTime, end: $endTime, duration: $durationInSeconds s, calories: ${caloriesBurned?.toStringAsFixed(2)}, synced: $isSynced)';
  }

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
        other.userId == userId &&
        other.isSynced == isSynced; // <<< THÊM MỚI
  }

  @override
  int get hashCode {
    return id.hashCode ^
        activityName.hashCode ^
        startTime.hashCode ^
        endTime.hashCode ^
        durationInSeconds.hashCode ^
        caloriesBurned.hashCode ^
        userId.hashCode ^
        isSynced.hashCode; // <<< THÊM MỚI
  }
}
