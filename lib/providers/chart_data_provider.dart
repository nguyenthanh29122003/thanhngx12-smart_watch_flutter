// lib/providers/chart_data_provider.dart
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/health_data.dart';

// Enum để biểu diễn các khoảng thời gian (ví dụ)
enum TimeRange { lastHour, lastDay, lastWeek }

class ChartDataProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // Trạng thái dữ liệu
  List<HealthData> _chartData = [];
  bool _isLoading = false;
  String? _errorMessage;
  TimeRange _selectedRange = TimeRange.lastDay; // Khoảng thời gian mặc định

  // Getters
  List<HealthData> get chartData => _chartData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  TimeRange get selectedRange => _selectedRange;

  ChartDataProvider(this._firestoreService, this._authService);

  // Hàm để thay đổi khoảng thời gian và fetch dữ liệu mới
  Future<void> setTimeRangeAndFetch(TimeRange newRange) async {
    if (_selectedRange == newRange && _chartData.isNotEmpty && !_isLoading) {
      print("[ChartData] Range $newRange already selected and data loaded.");
      // Không fetch lại nếu đã chọn và có dữ liệu (trừ khi muốn refresh)
      // Hoặc có thể thêm nút refresh riêng
      return;
    }
    _selectedRange = newRange;
    // Reset dữ liệu cũ trước khi fetch mới (tùy chọn)
    // _chartData = [];
    // _errorMessage = null;
    // notifyListeners(); // Thông báo để UI hiển thị loading ngay
    await fetchChartData(); // Gọi hàm fetch chính
  }

  // Hàm chính để lấy dữ liệu từ Firestore
  Future<void> fetchChartData() async {
    final user = _authService.currentUser;
    if (user == null) {
      _errorMessage = "User not logged in.";
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null; // Xóa lỗi cũ
    notifyListeners(); // Thông báo bắt đầu loading

    print("[ChartData] Fetching data for range: $_selectedRange");

    try {
      // Xác định startTime và endTime dựa trên _selectedRange
      final now = DateTime.now();
      DateTime startTime;
      DateTime endTime = now; // Luôn kết thúc ở hiện tại

      switch (_selectedRange) {
        case TimeRange.lastHour:
          startTime = now.subtract(const Duration(hours: 1));
          break;
        case TimeRange.lastDay:
          startTime = now.subtract(const Duration(days: 1));
          break;
        case TimeRange.lastWeek:
          startTime = now.subtract(const Duration(days: 7));
          break;
      }

      // Gọi hàm từ FirestoreService
      _chartData = await _firestoreService.getHealthDataForPeriod(
        user.uid,
        startTime,
        endTime,
      );
      print(
        "[ChartData] Fetched ${_chartData.length} data points for $_selectedRange.",
      );
    } catch (e) {
      print("!!! [ChartData] Error fetching chart data: $e");
      _errorMessage = "Failed to load chart data.";
      _chartData = []; // Xóa dữ liệu cũ nếu có lỗi
    } finally {
      _isLoading = false; // Kết thúc loading dù thành công hay lỗi
      notifyListeners(); // Thông báo cập nhật UI
    }
  }
}
