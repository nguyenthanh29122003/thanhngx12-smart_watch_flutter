// lib/providers/relatives_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/relative.dart'; // Import model

class RelativesProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // Stream để cung cấp danh sách người thân realtime
  Stream<List<Relative>>? _relativesStream;
  Stream<List<Relative>>? get relativesStream => _relativesStream;

  RelativesProvider(this._firestoreService, this._authService) {
    // Bắt đầu lắng nghe khi provider được tạo (nếu user đã đăng nhập)
    _initStream();
    // Lắng nghe thay đổi trạng thái auth để cập nhật stream
    _authService.authStateChanges.listen((user) {
      _initStream(); // Khởi tạo lại stream khi auth thay đổi
      notifyListeners(); // Thông báo để UI biết stream có thể đã thay đổi
    });
    print("RelativesProvider Initialized.");
  }

  // Khởi tạo hoặc xóa stream dựa trên trạng thái đăng nhập
  void _initStream() {
    final user = _authService.currentUser;
    if (user != null) {
      print(
        "[RelativesProvider] User logged in (${user.uid}), setting up relatives stream.",
      );
      _relativesStream = _firestoreService
          .getRelatives(user.uid)
          .map(
            (snapshot) =>
                snapshot
                    .docs // Chuyển QuerySnapshot thành List<DocumentSnapshot>
                    .map((doc) {
                      try {
                        return Relative.fromSnapshot(
                          doc,
                        ); // Chuyển DocumentSnapshot thành Relative object
                      } catch (e) {
                        print(
                          "!!! Error parsing relative data for doc ${doc.id}: $e",
                        );
                        return null; // Bỏ qua bản ghi lỗi
                      }
                    })
                    .whereType<
                      Relative
                    >() // Lọc bỏ các giá trị null (do lỗi parse)
                    .toList(),
          );
    } else {
      print("[RelativesProvider] User logged out, clearing relatives stream.");
      _relativesStream = null; // Xóa stream nếu không đăng nhập
    }
  }

  // Hàm thêm người thân (sẽ gọi từ UI)
  Future<bool> addRelative(String name, String relationship) async {
    final user = _authService.currentUser;
    if (user == null) {
      print("[RelativesProvider] Cannot add relative: User not logged in.");
      return false;
    }
    if (name.trim().isEmpty || relationship.trim().isEmpty) {
      print(
        "[RelativesProvider] Cannot add relative: Name or relationship is empty.",
      );
      return false; // Không thêm nếu thiếu thông tin
    }

    print(
      "[RelativesProvider] Adding relative: Name=$name, Relationship=$relationship",
    );
    try {
      await _firestoreService.addRelative(user.uid, {
        'name': name.trim(),
        'relationship': relationship.trim(),
        'addedAt': FieldValue.serverTimestamp(), // Thêm thời gian thêm
      });
      print("[RelativesProvider] Relative added successfully.");
      return true;
    } catch (e) {
      print("!!! [RelativesProvider] Error adding relative: $e");
      return false;
    }
  }

  // Hàm xóa người thân (ví dụ)
  Future<bool> deleteRelative(String relativeId) async {
    final user = _authService.currentUser;
    if (user == null) return false;
    print("[RelativesProvider] Deleting relative: $relativeId");
    try {
      await _firestoreService.firestoreInstance
          .collection('users')
          .doc(user.uid)
          .collection('relatives')
          .doc(relativeId)
          .delete();
      print("[RelativesProvider] Relative deleted successfully.");
      return true;
    } catch (e) {
      print("!!! [RelativesProvider] Error deleting relative: $e");
      return false;
    }
  }

  // Dispose không cần thiết vì stream được quản lý bởi FirestoreService
  // và listener auth tự hủy khi provider dispose
}
