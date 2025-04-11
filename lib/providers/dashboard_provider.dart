// lib/providers/dashboard_provider.dart
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // Cần để lấy userId
import '../models/health_data.dart';

// Enum trạng thái tải dữ liệu lịch sử
enum HistoryStatus { initial, loading, loaded, error }

class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // State cho dữ liệu lịch sử
  List<HealthData> _healthHistory = [];
  HistoryStatus _historyStatus = HistoryStatus.initial;
  String? _historyError;

  // Getters công khai
  List<HealthData> get healthHistory => _healthHistory;
  HistoryStatus get historyStatus => _historyStatus;
  String? get historyError => _historyError;

  // Constructor nhận các service cần thiết
  DashboardProvider(this._firestoreService, this._authService);

  /// Tải dữ liệu sức khỏe trong khoảng thời gian gần đây (ví dụ: 24 giờ qua).
  Future<void> fetchHealthHistory({
    Duration duration = const Duration(hours: 24),
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) {
      print("[DashboardProvider] Cannot fetch history: No user logged in.");
      _updateHistoryStatus(HistoryStatus.error, "User not logged in");
      return;
    }

    // Chỉ tải nếu trạng thái đang là initial hoặc error (tránh tải lại khi đang load)
    if (_historyStatus == HistoryStatus.loading) return;

    print(
      "[DashboardProvider] Fetching health history for the last ${duration.inHours} hours...",
    );
    _updateHistoryStatus(HistoryStatus.loading); // Báo đang tải

    try {
      final endTime = DateTime.now(); // Thời điểm hiện tại
      final startTime = endTime.subtract(duration); // Lùi lại khoảng thời gian

      // Gọi hàm từ FirestoreService
      final List<HealthData> fetchedData = await _firestoreService
          .getHealthDataForPeriod(currentUser.uid, startTime, endTime);

      _healthHistory = fetchedData; // Cập nhật state
      _updateHistoryStatus(HistoryStatus.loaded); // Báo tải xong
      print(
        "[DashboardProvider] Fetched ${_healthHistory.length} history records.",
      );
    } catch (e) {
      print("!!! [DashboardProvider] Error fetching health history: $e");
      _updateHistoryStatus(HistoryStatus.error, "Failed to load history data.");
    }
  }

  // Hàm helper cập nhật trạng thái và thông báo listeners
  void _updateHistoryStatus(HistoryStatus newStatus, [String? errorMessage]) {
    _historyStatus = newStatus;
    _historyError = errorMessage;
    notifyListeners(); // Thông báo cho UI cập nhật
  }

  // Có thể thêm các hàm khác sau này, ví dụ: tải theo ngày cụ thể, lọc dữ liệu,...
}
