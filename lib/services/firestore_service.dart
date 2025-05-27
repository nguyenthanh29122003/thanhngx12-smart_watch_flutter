// lib/services/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Cần để lấy User object
import '../app_constants.dart'; // Import các hằng số
import '../models/health_data.dart'; // <<< Import HealthData model
import '../models/activity_segment.dart';

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
    bool isNewUser = false, // <<< Tham số để biết đây là user mới tạo
    bool updateLastLogin =
        false, // <<< Tham số để chỉ định có cập nhật lastLogin không
  }) async {
    // Map chứa dữ liệu sẽ được ghi/cập nhật lên Firestore
    final Map<String, dynamic> userDataToSet = {};

    // Luôn thêm uid và email (nếu có)
    userDataToSet['uid'] = user.uid;
    if (user.email != null) {
      userDataToSet['email'] = user.email;
    }

    // Chỉ thêm/cập nhật displayName nếu được cung cấp và không rỗng
    if (displayName != null && displayName.trim().isNotEmpty) {
      userDataToSet['displayName'] = displayName.trim();
    } else if (isNewUser &&
        (user.displayName == null || user.displayName!.isEmpty)) {
      // Nếu là user mới và không có displayName nào được cung cấp (kể cả từ Auth object)
      // thì không thêm trường displayName để tránh ghi giá trị null/rỗng không cần thiết
    } else if (isNewUser &&
        user.displayName != null &&
        user.displayName!.isNotEmpty) {
      // Nếu là user mới và Auth object có displayName (ví dụ từ Google Sign-In)
      userDataToSet['displayName'] = user.displayName;
    }

    // Chỉ thêm/cập nhật photoURL nếu được cung cấp và không rỗng
    if (photoURL != null && photoURL.isNotEmpty) {
      userDataToSet['photoURL'] = photoURL;
    } else if (isNewUser &&
        user.photoURL != null &&
        user.photoURL!.isNotEmpty) {
      // Nếu là user mới và Auth object có photoURL
      userDataToSet['photoURL'] = user.photoURL;
    }

    // Chỉ thêm trường 'createdAt' nếu đây là một người dùng mới
    if (isNewUser) {
      userDataToSet['createdAt'] = FieldValue.serverTimestamp();
    }

    // Luôn cập nhật 'lastLogin' nếu là user mới HOẶC được yêu cầu tường minh
    if (isNewUser || updateLastLogin) {
      userDataToSet['lastLogin'] = FieldValue.serverTimestamp();
    }

    // Nếu không có gì để cập nhật ngoài uid và email (ví dụ khi chỉ updateLastLogin cho user cũ không có thay đổi khác)
    // và không phải user mới, thì có thể cân nhắc dùng update() thay vì set(merge:true)
    // Tuy nhiên, set(merge:true) vẫn an toàn và xử lý cả trường hợp tạo mới.

    if (userDataToSet.isEmpty && !isNewUser && !updateLastLogin) {
      print(
          "[FirestoreService] No new data to update for user profile ${user.uid}. Skipping Firestore write.");
      return; // Không có gì để ghi
    }

    try {
      print(
          "[FirestoreService] Updating/Creating user profile for ${user.uid} with data: $userDataToSet");
      // Sử dụng set với merge: true để:
      // - Tạo mới document nếu chưa tồn tại (trường hợp isNewUser).
      // - Cập nhật các trường được cung cấp trong `userDataToSet` nếu document đã tồn tại,
      //   giữ nguyên các trường khác không có trong `userDataToSet`.
      await _db.collection(AppConstants.usersCollection).doc(user.uid).set(
          userDataToSet, SetOptions(merge: true)); // merge:true là quan trọng

      print(
          "[FirestoreService] User profile ${isNewUser ? 'created' : 'updated'} successfully for ${user.uid}.");
    } catch (e) {
      print(
          "!!! [FirestoreService] Error updating/creating user profile for ${user.uid}: $e");
      // Cân nhắc ném lại lỗi để AuthProvider có thể xử lý (ví dụ, báo lỗi cho người dùng)
      // throw FirebaseException(plugin: 'FirestoreService', code: 'profile-update-failed', message: e.toString());
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
      String userId, HealthData healthDataObject) async {
    try {
      // 1. Lấy Map dữ liệu từ object (đã bao gồm temp, pres nếu có)
      //    Hàm toJsonForFirestore() đã được cập nhật để KHÔNG bao gồm 'recordedAt'
      final Map<String, dynamic> dataToSave =
          healthDataObject.toJsonForFirestore();

      // 2. Thêm trường 'recordedAt' vào Map, sử dụng timestamp từ object HealthData
      //    Đảm bảo timestamp trong HealthData object là UTC
      dataToSave['recordedAt'] =
          Timestamp.fromDate(healthDataObject.timestamp.toUtc());

      // 3. Tạo document mới với ID tự động trong subcollection 'health_data'
      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants.healthDataSubcollection)
          .add(dataToSave); // Dùng add() để Firestore tự tạo ID

      // Log tối giản hơn để tránh spam console
      // print("Health data saved for user $userId at ${healthDataObject.timestamp.toIso8601String()}");
    } catch (e) {
      print("!!! Error saving health data to Firestore for user $userId: $e");
      // Cân nhắc ném lỗi ra ngoài để BleService/DataSyncService xử lý (ví dụ: không đánh dấu đã đồng bộ)
      // throw FirebaseException(plugin: 'FirestoreService', code: 'save-failed', message: e.toString());
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

  /// Lưu một bản ghi ActivitySegment lên Firestore.
  Future<void> saveActivitySegment(
      String userId, ActivitySegment segment) async {
    try {
      // Sử dụng toJsonForFirestore() từ model ActivitySegment
      // Hàm này đã chuyển đổi startTime và endTime sang Timestamp của Firestore
      final Map<String, dynamic> dataToSave = segment.toJsonForFirestore();

      // (Tùy chọn) Thêm một trường 'syncedAt' hoặc 'createdAtServer' nếu bạn muốn
      // biết khi nào bản ghi này được đồng bộ lên server.
      // dataToSave['syncedAt'] = FieldValue.serverTimestamp();

      await _db
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .collection(AppConstants
              .activitySegmentsSubcollection) // <<< SỬ DỤNG HẰNG SỐ ĐÚNG
          .add(dataToSave); // Dùng add() để Firestore tự tạo ID cho document

      // Log tối giản hơn để tránh spam console
      // print("ActivitySegment saved for user $userId: ${segment.activityName} from ${segment.startTime.toIso8601String()}");
    } catch (e) {
      print(
          "!!! Error saving ActivitySegment to Firestore for user $userId: $e");
      // Cân nhắc ném lỗi ra ngoài để DataSyncService có thể xử lý
      // (ví dụ: không đánh dấu segment này là đã đồng bộ ở local)
      throw FirebaseException(
        plugin: 'FirestoreService',
        code: 'save-activity-segment-failed',
        message: e.toString(),
      );
    }
  }

  /// (Tùy chọn) Lấy lịch sử ActivitySegment từ Firestore.
  Stream<QuerySnapshot<Map<String, dynamic>>> getActivitySegmentsHistory(
    String userId, {
    int limit = 100, // Giới hạn số lượng
    DateTime?
        startAfterTimestamp, // Cho phân trang (lấy các bản ghi sau một thời điểm nhất định)
  }) {
    Query<Map<String, dynamic>> query = _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .collection(AppConstants.activitySegmentsSubcollection)
        .orderBy('startTime',
            descending: true); // Sắp xếp theo startTime, mới nhất trước

    if (startAfterTimestamp != null) {
      query =
          query.startAfter([Timestamp.fromDate(startAfterTimestamp.toUtc())]);
    }

    return query.limit(limit).snapshots();
  }
}
