// lib/models/relative.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Relative {
  final String id; // Document ID từ Firestore
  final String name;
  final String relationship;
  // Thêm các trường khác nếu cần, ví dụ: deviceId, photoUrl
  // final String? linkedDeviceId;

  Relative({
    required this.id,
    required this.name,
    required this.relationship,
    // this.linkedDeviceId,
  });

  // Factory constructor để tạo từ Firestore DocumentSnapshot
  factory Relative.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) {
      // Xử lý trường hợp data là null (ít xảy ra với snapshot tồn tại)
      throw StateError('Missing data for Relative snapshot ${snapshot.id}');
    }
    return Relative(
      id: snapshot.id, // Lấy ID của document
      name:
          data['name'] as String? ??
          'Unknown Name', // Lấy tên, có giá trị mặc định
      relationship:
          data['relationship'] as String? ??
          'Unknown Relationship', // Lấy quan hệ
      // linkedDeviceId: data['linkedDeviceId'] as String?, // Lấy deviceId nếu có
    );
  }

  // (Tùy chọn) Hàm toJson để lưu (nếu cần)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'relationship': relationship,
      // if (linkedDeviceId != null) 'linkedDeviceId': linkedDeviceId,
    };
  }
}
