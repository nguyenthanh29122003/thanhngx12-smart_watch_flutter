// lib/providers/goals_provider.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho FieldValue
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // Cần để lấy userId
import '../app_constants.dart'; // Cần cho giá trị mặc định

class GoalsProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // --- State ---
  int _currentStepGoal = AppConstants.defaultDailyStepGoal; // Mục tiêu hiện tại
  bool _isLoadingGoal = true; // Trạng thái tải mục tiêu
  String? _goalError; // Lỗi khi tải/lưu mục tiêu

  // --- Getters ---
  int get currentStepGoal => _currentStepGoal;
  bool get isLoadingGoal => _isLoadingGoal;
  String? get goalError => _goalError;

  // --- Constructor ---
  GoalsProvider(this._firestoreService, this._authService) {
    // Tự động tải mục tiêu khi Provider được tạo lần đầu (nếu user đã đăng nhập)
    // Không cần addPostFrameCallback ở đây vì Provider thường được tạo sau khi context sẵn sàng
    if (_authService.currentUser != null) {
      loadDailyGoal();
    } else {
      // Nếu chưa đăng nhập, không cần tải và kết thúc trạng thái loading
      _isLoadingGoal = false;
      // Không cần notifyListeners() vì chưa có ai lắng nghe lúc này
    }
    print("[GoalsProvider] Initialized.");
    // Lắng nghe thay đổi trạng thái đăng nhập để tải lại mục tiêu nếu cần
    _authService.authStateChanges.listen((user) {
      if (user != null) {
        print(
            "[GoalsProvider] Auth state changed: User logged in. Loading goal.");
        loadDailyGoal();
      } else {
        print(
            "[GoalsProvider] Auth state changed: User logged out. Resetting goal.");
        _resetGoal(); // Reset về mặc định khi đăng xuất
      }
    });
  }

  /// Tải mục tiêu số bước hàng ngày từ Firestore.
  Future<void> loadDailyGoal() async {
    final user = _authService.currentUser;
    if (user == null) {
      print("[GoalsProvider] Cannot load goal: User not logged in.");
      _resetGoal(); // Reset nếu không có user
      return;
    }

    // Chỉ tải nếu đang không tải
    if (!_isLoadingGoal) {
      _isLoadingGoal = true;
      _goalError = null; // Xóa lỗi cũ
      notifyListeners(); // Báo hiệu bắt đầu tải
    }
    print("[GoalsProvider] Loading daily goal for user ${user.uid}...");

    try {
      final goalDoc = await _firestoreService.getDailyGoal(user.uid);
      if (goalDoc != null && goalDoc.exists) {
        final data = goalDoc.data();
        // Lấy giá trị 'steps', nếu không có hoặc null thì dùng default
        _currentStepGoal =
            (data?['steps'] as int?) ?? AppConstants.defaultDailyStepGoal;
        print("[GoalsProvider] Goal loaded from Firestore: $_currentStepGoal");
      } else {
        // Nếu chưa có document mục tiêu trên Firestore, dùng giá trị mặc định
        _currentStepGoal = AppConstants.defaultDailyStepGoal;
        print(
            "[GoalsProvider] No goal found in Firestore. Using default: $_currentStepGoal");
      }
      _goalError = null; // Xóa lỗi nếu thành công
    } catch (e) {
      print("!!! [GoalsProvider] Error loading daily goal: $e");
      _currentStepGoal =
          AppConstants.defaultDailyStepGoal; // Reset về default khi lỗi
      _goalError = "Failed to load goal.";
    } finally {
      _isLoadingGoal = false; // Đánh dấu đã tải xong (kể cả khi lỗi)
      notifyListeners(); // Cập nhật UI
    }
  }

  /// Cập nhật mục tiêu số bước hàng ngày lên Firestore.
  Future<bool> updateDailyGoal(int newGoal) async {
    final user = _authService.currentUser;
    if (user == null) {
      print("!!! [GoalsProvider] Cannot update goal: User not logged in.");
      _goalError = "User not logged in.";
      notifyListeners();
      return false; // Thất bại
    }
    if (newGoal <= 0) {
      print(
          "!!! [GoalsProvider] Cannot update goal: Invalid goal value ($newGoal).");
      _goalError = "Goal must be greater than 0.";
      notifyListeners();
      return false; // Thất bại
    }

    print(
        "[GoalsProvider] Updating daily step goal to $newGoal for user ${user.uid}...");
    // Có thể thêm trạng thái "isSaving" nếu muốn hiển thị loading khi lưu
    // setState(() => _isSaving = true); notifyListeners();

    try {
      final Map<String, dynamic> goalData = {
        'steps': newGoal,
        'updatedAt': FieldValue.serverTimestamp(), // Luôn cập nhật thời gian
      };
      await _firestoreService.setDailyGoal(user.uid, goalData);

      // Cập nhật state thành công
      _currentStepGoal = newGoal;
      _goalError = null;
      print("[GoalsProvider] Goal updated successfully to: $_currentStepGoal");
      notifyListeners();
      return true; // Thành công
    } catch (e) {
      print("!!! [GoalsProvider] Error updating daily goal: $e");
      _goalError = "Failed to save goal.";
      notifyListeners();
      return false; // Thất bại
    } finally {
      // setState(() => _isSaving = false); notifyListeners();
    }
  }

  /// Reset mục tiêu về giá trị mặc định (thường dùng khi đăng xuất).
  void _resetGoal() {
    _currentStepGoal = AppConstants.defaultDailyStepGoal;
    _isLoadingGoal = false; // Không còn loading nữa
    _goalError = null;
    notifyListeners();
    print("[GoalsProvider] Goal reset to default: $_currentStepGoal");
  }
}
