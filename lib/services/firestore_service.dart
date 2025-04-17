// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Cần để lấy User object
import '../app_constants.dart'; // Import các hằng số
import '../models/health_data.dart'; // <<< Import HealthData model

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Provides access to the Firestore instance for batch operations, etc.
  FirebaseFirestore get firestoreInstance => _db;

  // --- User Profile Operations ---

  // Tạo hoặc cập nhật hồ sơ người dùng khi đăng ký/đăng nhập lần đầu
  Future<void> updateUserProfile(
    User user, {
    String? displayName,
    String? photoURL,
  }) async {
    // Sử dụng Map để chứa dữ liệu, có thể mở rộng sau này
    final Map<String, dynamic> userData = {
      'uid': user.uid,
      'email': user.email,
      // Chỉ cập nhật displayName nếu được cung cấp và khác giá trị hiện tại
      if (displayName != null && displayName.isNotEmpty)
        'displayName': displayName,
      // Chỉ cập nhật photoURL nếu được cung cấp và khác giá trị hiện tại
      if (photoURL != null && photoURL.isNotEmpty) 'photoURL': photoURL,
      'lastLogin':
          FieldValue.serverTimestamp(), // Cập nhật thời gian đăng nhập cuối
      'createdAt': FieldValue
          .serverTimestamp(), // Chỉ ghi khi tạo mới (dùng set với merge:false)
    };

    try {
      // Dùng set với merge: true để tạo mới nếu chưa có, hoặc cập nhật các trường cung cấp nếu đã tồn tại
      await _db
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userData, SetOptions(merge: true)); // merge:true là quan trọng
      print("User profile updated/created for ${user.uid}");
    } catch (e) {
      print("Error updating/creating user profile: $e");
      // throw FirestoreException("user_profile_update_failed");
    }
  }

  // Lấy thông tin hồ sơ người dùng
  Future<DocumentSnapshot<Map<String, dynamic>>?> getUserProfile(
    String userId,
  ) async {
    try {
      final docSnap =
          await _db.collection(AppConstants.usersCollection).doc(userId).get();
      if (docSnap.exists) {
        return docSnap;
      } else {
        print("User profile not found for $userId");
        return null;
      }
    } catch (e) {
      print("Error getting user profile: $e");
      return null;
    }
  }

  // --- Health Data Operations ---

  // Lưu một bản ghi dữ liệu sức khỏe
  // healthData nên là một Map<String, dynamic> khớp với cấu trúc JSON từ ESP32
  Future<void> saveHealthData(
    String userId,
    Map<String, dynamic> healthData,
  ) async {
    // Thêm timestamp từ server nếu trong healthData chưa có hoặc không hợp lệ
    if (healthData['timestamp'] == null ||
        healthData['timestamp'] == "Not initialized") {
      // Nếu không có timestamp từ ESP32 hoặc không hợp lệ, dùng timestamp của server
      healthData['recordedAt'] = FieldValue.serverTimestamp();
      // Xóa trường timestamp gốc nếu không muốn lưu giá trị không hợp lệ
      healthData.remove('timestamp');
    } else {
      // Nếu có timestamp từ ESP32, chuyển đổi nó thành kiểu Timestamp của Firestore
      try {
        // Cố gắng parse timestamp ISO 8601 từ ESP32
        DateTime parsedTimestamp = DateTime.parse(healthData['timestamp']);
        healthData['recordedAt'] = Timestamp.fromDate(parsedTimestamp);
        // Xóa trường timestamp gốc sau khi đã chuyển đổi
        healthData.remove('timestamp');
      } catch (e) {
        print(
          "Error parsing timestamp from ESP32: ${healthData['timestamp']}. Using server timestamp. Error: $e",
        );
        // Nếu parse lỗi, vẫn dùng timestamp server
        healthData['recordedAt'] = FieldValue.serverTimestamp();
        healthData.remove('timestamp');
      }
    }

    try {
      // Tạo document mới với ID tự động trong subcollection 'health_data'
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.healthDataSubcollection)
          .add(healthData); // add() sẽ tự tạo ID
      // print("Health data saved for user $userId"); // Giảm log để tránh spam
    } catch (e) {
      print("Error saving health data: $e");
      // throw FirestoreException("health_data_save_failed");
    }
  }

  // Lấy lịch sử dữ liệu sức khỏe (ví dụ: 24 giờ qua)
  // Cần có Index trong Firestore cho trường 'recordedAt' (descending)
  Stream<QuerySnapshot<Map<String, dynamic>>> getHealthDataHistory(
    String userId, {
    int limit = 100,
  }) {
    // Lấy dữ liệu được sắp xếp theo thời gian gần nhất
    return _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.healthDataSubcollection)
        .orderBy(
          'recordedAt',
          descending: true,
        ) // Sắp xếp theo timestamp đã xử lý
        .limit(limit) // Giới hạn số lượng bản ghi lấy về
        .snapshots(); // snapshots() trả về Stream để cập nhật realtime
  }

  // Lấy bản ghi dữ liệu sức khỏe mới nhất
  Future<DocumentSnapshot<Map<String, dynamic>>?> getLatestHealthData(
    String userId,
  ) async {
    try {
      final querySnap = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.healthDataSubcollection)
          .orderBy('recordedAt', descending: true)
          .limit(1)
          .get();

      if (querySnap.docs.isNotEmpty) {
        return querySnap.docs.first;
      } else {
        return null; // Không có dữ liệu
      }
    } catch (e) {
      print("Error getting latest health data: $e");
      return null;
    }
  }

  // --- Relatives Operations --- (Sẽ thêm chi tiết sau nếu cần)

  Future<void> addRelative(
    String userId,
    Map<String, dynamic> relativeData,
  ) async {
    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.relativesSubcollection)
          .add(relativeData); // ID tự động
      print("Relative added for user $userId");
    } catch (e) {
      print("Error adding relative: $e");
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getRelatives(String userId) {
    return _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.relativesSubcollection)
        .snapshots();
  }

  // --- Goals Operations --- (Sẽ thêm chi tiết sau nếu cần)

  Future<void> setDailyGoal(
    String userId,
    Map<String, dynamic> goalData,
  ) async {
    try {
      // Dùng doc('daily') để luôn cập nhật cùng một document mục tiêu
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.goalsSubcollection)
          .doc('daily') // ID cố định cho mục tiêu hàng ngày
          .set(
            goalData,
            SetOptions(merge: true),
          ); // Merge để chỉ cập nhật các trường mới
      print("Daily goal set/updated for user $userId");
    } catch (e) {
      print("Error setting daily goal: $e");
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> getDailyGoal(
    String userId,
  ) async {
    try {
      final docSnap = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.goalsSubcollection)
          .doc('daily')
          .get();
      if (docSnap.exists) {
        return docSnap;
      } else {
        return null; // Chưa có mục tiêu nào được đặt
      }
    } catch (e) {
      print("Error getting daily goal: $e");
      return null;
    }
  }

  // --- HÀM MỚI ĐỂ LẤY DỮ LIỆU LỊCH SỬ ---
  /// Lấy danh sách HealthData trong một khoảng thời gian.
  /// Cần có Index trên Firestore cho collection 'health_data' với trường 'recordedAt' (ASC hoặc DESC).
  Future<List<HealthData>> getHealthDataForPeriod(
    String userId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    List<HealthData> historyData = [];
    try {
      print(
        "[FirestoreService] Fetching health data for $userId from $startTime to $endTime",
      );

      // Chuyển đổi DateTime sang Timestamp của Firestore (nên dùng UTC để query)
      final Timestamp startTimestamp = Timestamp.fromDate(startTime.toUtc());
      final Timestamp endTimestamp = Timestamp.fromDate(endTime.toUtc());

      final querySnapshot = await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.healthDataSubcollection)
          .where(
            // Lọc theo trường timestamp đã lưu (phải là kiểu Timestamp)
            'recordedAt',
            isGreaterThanOrEqualTo:
                startTimestamp, // Lớn hơn hoặc bằng startTime
            isLessThanOrEqualTo: endTimestamp, // Nhỏ hơn hoặc bằng endTime
          )
          .orderBy(
            'recordedAt',
            descending: false,
          ) // Sắp xếp tăng dần theo thời gian
          // .limit(1000) // Có thể thêm giới hạn nếu cần
          .get();

      print(
        "[FirestoreService] Found ${querySnapshot.docs.length} records in period.",
      );

      // Chuyển đổi các document snapshot thành đối tượng HealthData
      // lib/services/firestore_service.dart
      // Trong hàm getHealthDataForPeriod:
      // Trong hàm getHealthDataForPeriod:
      historyData = querySnapshot.docs
          .map((doc) {
            try {
              // Lấy dữ liệu từ document snapshot
              final map = doc.data();
              // Gọi hàm factory mới để parse từ map của Firestore
              return HealthData.fromFirestoreMap(map); // <<< SỬA Ở ĐÂY
            } catch (e) {
              print("!!! Error parsing Firestore document ${doc.id}: $e");
              print("Document data: ${doc.data()}"); // In ra dữ liệu gây lỗi
              return null; // Trả về null nếu parse lỗi
            }
          })
// Lọc bỏ các giá trị null có thể xảy ra do lỗi parsing
          .whereType<HealthData>()
          .toList();
    } catch (e) {
      print("!!! Error fetching health data history: $e");
      // Nếu có lỗi, trả về danh sách rỗng
      // Có thể ném lỗi ra ngoài để xử lý ở tầng trên nếu muốn
    }
    return historyData;
  }

  // Trong class FirestoreService
  Future<void> deleteRelative(String userId, String relativeId) async {
    try {
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.relativesSubcollection)
          .doc(relativeId)
          .delete();
      print("Relative $relativeId deleted for user $userId");
    } catch (e) {
      print("Error deleting relative $relativeId: $e");
      // Ném lại lỗi để Provider có thể bắt và xử lý
      throw FirebaseException(
          plugin: 'FirestoreService',
          code: 'delete-failed',
          message: e.toString());
    }
  }

  // <<< THÊM HÀM CẬP NHẬT NGƯỜI THÂN >>>
  Future<void> updateRelative(String userId, String relativeId,
      Map<String, dynamic> updatedData) async {
    // Chỉ cho phép cập nhật 'name' và 'relationship', thêm 'updatedAt'
    final Map<String, dynamic> dataToUpdate = {
      if (updatedData.containsKey('name')) 'name': updatedData['name'],
      if (updatedData.containsKey('relationship'))
        'relationship': updatedData['relationship'],
      'updatedAt':
          FieldValue.serverTimestamp(), // Luôn cập nhật thời gian sửa đổi
    };

    // Chỉ thực hiện cập nhật nếu có dữ liệu cần cập nhật (tránh ghi timestamp không cần thiết)
    if (dataToUpdate.length > 1) {
      // Luôn có updatedAt
      try {
        await _db
            .collection(AppConstants.usersCollection)
            .doc(userId)
            .collection(AppConstants.relativesSubcollection)
            .doc(relativeId)
            .update(dataToUpdate); // Dùng update()
        print("Relative $relativeId updated for user $userId");
      } catch (e) {
        print("Error updating relative $relativeId: $e");
        throw FirebaseException(
            plugin: 'FirestoreService',
            code: 'update-failed',
            message: e.toString());
      }
    } else {
      print("No changes detected for relative $relativeId. Update skipped.");
      // Có thể throw lỗi nhẹ hoặc trả về gì đó nếu muốn báo không có gì thay đổi
    }
  }
}
