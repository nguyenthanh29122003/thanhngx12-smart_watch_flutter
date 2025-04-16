// lib/providers/dashboard_provider.dart
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart'; // Cần để lấy userId
import '../models/health_data.dart';
import 'dart:math'; // Cần cho Random

// lib/providers/dashboard_provider.dart
import 'package:flutter/foundation.dart';
// ... các import khác ...

// --- Cấu trúc dữ liệu cho số bước mỗi giờ ---
class HourlyStepsData {
  final DateTime hourStart; // Giờ bắt đầu (UTC)
  final int steps; // Số bước đi được trong giờ đó

  HourlyStepsData(this.hourStart, this.steps);

  // (Optional) toString để debug dễ hơn
  @override
  String toString() {
    return 'HourlyStepsData(hour: ${hourStart.hour}, steps: $steps)';
  }
}

// Enum trạng thái tải dữ liệu lịch sử
enum HistoryStatus { initial, loading, loaded, error }

class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // State cho dữ liệu lịch sử
  // --- THÊM State cho dữ liệu steps đã xử lý ---
  List<HourlyStepsData> _hourlyStepsData = [];
  // --------------------------------------------
  List<HealthData> _healthHistory = [];
  HistoryStatus _historyStatus = HistoryStatus.initial;
  String? _historyError;

  // Getters công khai
  List<HealthData> get healthHistory => _healthHistory;
  HistoryStatus get historyStatus => _historyStatus;
  String? get historyError => _historyError;
  // --- THÊM Getter cho hourly steps ---
  List<HourlyStepsData> get hourlyStepsData => _hourlyStepsData;

  // Constructor nhận các service cần thiết
  DashboardProvider(this._firestoreService, this._authService);

  // --- THÊM Hàm tính toán số bước mỗi giờ ---
  List<HourlyStepsData> _calculateHourlySteps(List<HealthData> history) {
    if (history.isEmpty) return [];

    // Sử dụng Map để tổng hợp số bước cho mỗi giờ (Key là giờ bắt đầu UTC)
    Map<DateTime, int> hourlyStepsMap = {};
    // Lưu trữ số bước của bản ghi TRƯỚC ĐÓ để tính delta
    int previousSteps = -1; // -1 cho biết đây là bản ghi đầu tiên

    // Đảm bảo history đã được sắp xếp theo timestamp tăng dần (Firestore query đã làm việc này)
    for (int i = 0; i < history.length; i++) {
      final currentData = history[i];
      final currentSteps = currentData.steps;

      // Bỏ qua nếu steps không hợp lệ (ví dụ < 0, mặc dù ít xảy ra)
      if (currentSteps < 0) {
        // Cập nhật previousSteps cho lần lặp sau nếu giá trị trước đó hợp lệ
        if (previousSteps >= 0) {
          previousSteps =
              currentSteps; // Để tránh delta lớn bất thường ở lần sau
        }
        continue;
      }

      // Xác định giờ bắt đầu (truncated to hour) của bản ghi hiện tại (DÙNG UTC)
      final DateTime currentHourStart = DateTime.utc(
        currentData.timestamp.year,
        currentData.timestamp.month,
        currentData.timestamp.day,
        currentData.timestamp.hour,
      );

      int stepsInThisInterval = 0;

      if (previousSteps != -1) {
        // Tính số bước tăng thêm từ bản ghi trước đó
        if (currentSteps >= previousSteps) {
          stepsInThisInterval = currentSteps - previousSteps;
        } else {
          // Phát hiện số bước bị giảm -> có thể là reset (ví dụ qua ngày mới trên ESP32)
          // Giả định: ESP32 reset số bước về 0 lúc nửa đêm.
          // => Số bước hiện tại chính là số bước đi được từ lúc reset.
          // Cần xác nhận lại logic reset của ESP32!
          // Nếu ESP32 KHÔNG reset mà chỉ là lỗi dữ liệu, cách xử lý này có thể sai.
          stepsInThisInterval = currentSteps;
          print(
              "[_calculateHourlySteps] Detected step count decrease/reset: prev=$previousSteps, curr=$currentSteps at ${currentData.timestamp.toLocal()}");
        }
      } else {
        // Đây là bản ghi đầu tiên trong danh sách history (hoặc bản ghi đầu tiên sau một giá trị không hợp lệ)
        // Số bước tích lũy đầu tiên này không thể xác định chính xác nó thuộc về khoảng thời gian nào
        // Có thể bỏ qua (stepsInThisInterval = 0) hoặc coi nó là bước của giờ đó.
        // Tạm thời coi là bước của giờ đó để không mất dữ liệu.
        stepsInThisInterval = currentSteps;
      }

      // Cộng dồn số bước tính được vào giờ tương ứng trong Map
      hourlyStepsMap.update(
        currentHourStart, // Key là giờ bắt đầu (UTC)
        (existingValue) => existingValue + stepsInThisInterval, // Cộng dồn
        ifAbsent: () => stepsInThisInterval, // Thêm mới nếu giờ này chưa có
      );

      // Cập nhật previousSteps cho vòng lặp tiếp theo
      previousSteps = currentSteps;
    }

    // Chuyển đổi Map thành List<HourlyStepsData>
    List<HourlyStepsData> result = hourlyStepsMap.entries
        .map((entry) => HourlyStepsData(entry.key, entry.value))
        .toList();

    // Sắp xếp kết quả theo giờ tăng dần (quan trọng cho biểu đồ)
    result.sort((a, b) => a.hourStart.compareTo(b.hourStart));

    print(
        "[_calculateHourlySteps] Calculated hourly steps result: ${result.length} hours");
    // print(result); // In chi tiết nếu cần debug

    return result;
  }
  // ----------------------------------------

  /// Tải dữ liệu sức khỏe, có tùy chọn sử dụng dữ liệu giả.
  Future<void> fetchHealthHistory({
    Duration duration = const Duration(hours: 24),
    bool useDummyData = true, // <<< Cờ để bật/tắt dữ liệu giả
  }) async {
    // Không cần kiểm tra user nếu dùng dummy
    final currentUser = _authService.currentUser;
    if (currentUser == null && !useDummyData) {
      print("[DashboardProvider] Cannot fetch history: No user logged in.");
      _updateHistoryStatus(HistoryStatus.error, "User not logged in");
      _clearHistoryData(); // Xóa dữ liệu cũ khi lỗi
      return;
    }

    // Tránh tải lại khi đang load
    if (_historyStatus == HistoryStatus.loading) return;

    print(
      "[DashboardProvider] Fetching health history (Dummy: $useDummyData)...",
    );
    _updateHistoryStatus(HistoryStatus.loading);
    _clearHistoryData(); // Xóa dữ liệu cũ trước khi tải mới

    // ---- Lựa chọn nguồn dữ liệu ----
    if (useDummyData) {
      // --- SỬ DỤNG DỮ LIỆU GIẢ ---
      try {
        await Future.delayed(
            const Duration(milliseconds: 800)); // Giả lập độ trễ mạng ngắn
        _healthHistory = generateDummyHealthData(
          count: 200, // Tăng số điểm dữ liệu giả
          duration: duration,
          simulateGaps: true,
        );
        // Quan trọng: Tính toán hourly steps TỪ dữ liệu giả
        _hourlyStepsData = _calculateHourlySteps(
            _healthHistory); // <<< TÍNH TOÁN TỪ DUMMY DATA

        _updateHistoryStatus(HistoryStatus.loaded); // Báo tải xong
        print(
          "[DashboardProvider] Loaded ${_healthHistory.length} DUMMY history records.",
        );
        print(
          "[DashboardProvider] Calculated ${_hourlyStepsData.length} DUMMY hourly step records.", // <<< Log cho dummy steps
        );
      } catch (e) {
        print("!!! [DashboardProvider] Error generating dummy data: $e");
        _updateHistoryStatus(
            HistoryStatus.error, "Failed to generate dummy data.");
        _clearHistoryData(); // Xóa dữ liệu cũ khi lỗi
      }
    } else {
      // --- SỬ DỤNG DỮ LIỆU THẬT TỪ FIRESTORE ---
      if (currentUser == null) return; // Vẫn cần double check user ở đây
      try {
        final endTime = DateTime.now();
        final startTime = endTime.subtract(duration);
        final List<HealthData> fetchedData = await _firestoreService
            .getHealthDataForPeriod(currentUser.uid, startTime, endTime);

        _healthHistory = fetchedData; // Cập nhật dữ liệu gốc
        // Tính toán hourly steps từ dữ liệu Firestore
        _hourlyStepsData = _calculateHourlySteps(
            _healthHistory); // <<< TÍNH TOÁN TỪ FIRESTORE DATA

        _updateHistoryStatus(HistoryStatus.loaded); // Báo tải xong
        print(
          "[DashboardProvider] Fetched ${_healthHistory.length} history records from Firestore.",
        );
        print(
          "[DashboardProvider] Calculated ${_hourlyStepsData.length} hourly step records from Firestore.", // <<< Log cho Firestore steps
        );
      } catch (e) {
        print("!!! [DashboardProvider] Error fetching Firestore history: $e");
        _updateHistoryStatus(
            HistoryStatus.error, "Failed to load history data.");
        _clearHistoryData(); // Xóa dữ liệu cũ khi lỗi
      }
    }
    // ------------------------------
  }

  // Hàm helper để xóa dữ liệu lịch sử
  void _clearHistoryData() {
    _healthHistory = [];
    _hourlyStepsData = [];
    // Không cần notifyListeners() ở đây vì _updateHistoryStatus sẽ gọi
  }

  // Hàm helper cập nhật trạng thái và thông báo listeners
  void _updateHistoryStatus(HistoryStatus newStatus, [String? errorMessage]) {
    _historyStatus = newStatus;
    _historyError = errorMessage;
    notifyListeners(); // Thông báo cho UI cập nhật
  }

  // --- HÀM TẠO DỮ LIỆU GIẢ (GIỮ NGUYÊN HOẶC ĐẶT Ở FILE KHÁC) ---
  List<HealthData> generateDummyHealthData({
    int count = 100,
    Duration duration = const Duration(hours: 24),
    DateTime? endTime,
    bool simulateGaps = true,
  }) {
    final Random random = Random();
    final List<HealthData> dummyData = [];
    final DateTime end = (endTime ?? DateTime.now()).toUtc();
    final DateTime start = end.subtract(duration);
    final double timeStepMillis =
        duration.inMilliseconds.toDouble() / (count > 1 ? count - 1 : 1);

    double currentHr = 75.0 + random.nextDouble() * 10 - 5;
    int currentSpo2 = 96 + random.nextInt(4);
    // Quan trọng: Khởi tạo số bước ban đầu cho dữ liệu giả
    int currentSteps =
        random.nextInt(100); // Bắt đầu với số bước ngẫu nhiên nhỏ

    double lastAx = 0.0, lastAy = 0.0, lastAz = 1.0;

    for (int i = 0; i < count; i++) {
      final DateTime timestamp = start
          .add(Duration(milliseconds: (timeStepMillis * i).toInt()))
          .toUtc();

      int hrValue;
      int spo2Value;
      // Simulate gaps
      if (simulateGaps && random.nextDouble() < 0.05) {
        hrValue = -1;
        spo2Value = -1;
      } else {
        currentHr +=
            random.nextDouble() * 6 - 3; // Biến thiên HR nhiều hơn chút
        currentHr = currentHr.clamp(50.0, 160.0);
        hrValue = currentHr.toInt();

        if (random.nextDouble() < 0.1) {
          currentSpo2 += random.nextInt(3) - 1;
          currentSpo2 = currentSpo2.clamp(90, 100);
        }
        spo2Value = currentSpo2;
      }

      // Simulate steps: Tăng nhiều hơn khi không ngồi yên
      if (lastAz.abs() < 0.8 || lastAx.abs() > 0.2 || lastAy.abs() > 0.2) {
        // Giả định khi có chuyển động IMU
        if (random.nextDouble() < 0.6) {
          // 60% cơ hội tăng bước khi chuyển động
          currentSteps += random.nextInt(8) + 1; // Tăng 1-8 bước
        }
      } else {
        if (random.nextDouble() < 0.1) {
          // 10% cơ hội tăng bước khi ngồi yên
          currentSteps += random.nextInt(2); // Tăng 0-1 bước
        }
      }

      lastAx += random.nextDouble() * 0.1 - 0.05;
      lastAy += random.nextDouble() * 0.1 - 0.05;
      lastAz += random.nextDouble() * 0.05 - 0.025;

      dummyData.add(
        HealthData(
          ax: lastAx.clamp(-2.0, 2.0), ay: lastAy.clamp(-2.0, 2.0),
          az: lastAz.clamp(-2.0, 2.0),
          gx: random.nextDouble() * 0.5 - 0.25,
          gy: random.nextDouble() * 0.5 - 0.25,
          gz: random.nextDouble() * 0.5 - 0.25,
          steps: currentSteps, // << Sử dụng currentSteps đã mô phỏng
          hr: hrValue, spo2: spo2Value,
          ir: 10000 + random.nextInt(5000), red: 2000 + random.nextInt(1000),
          wifi: random.nextBool(),
          timestamp: timestamp,
        ),
      );
    }
    // print("Generated Dummy Data Sample (last): ${dummyData.last.steps}");
    return dummyData;
  }
  // --------------------------------------------------

  // /// Tải dữ liệu sức khỏe trong khoảng thời gian gần đây.
  // Future<void> fetchHealthHistory({
  //   Duration duration = const Duration(hours: 24),
  //   // bool useDummyData = false, // Bỏ hoặc đặt lại thành false nếu không dùng dummy nữa
  // }) async {
  //   final currentUser = _authService.currentUser;
  //   if (currentUser == null /*&& !useDummyData*/) {
  //     // Bỏ check dummy
  //     print("[DashboardProvider] Cannot fetch history: No user logged in.");
  //     _updateHistoryStatus(HistoryStatus.error, "User not logged in");
  //     _clearHistoryData(); // Xóa dữ liệu cũ khi lỗi
  //     return;
  //   }

  //   if (_historyStatus == HistoryStatus.loading) return;

  //   print(
  //     "[DashboardProvider] Fetching health history for the last ${duration.inHours} hours...",
  //   );
  //   _updateHistoryStatus(HistoryStatus.loading);
  //   _clearHistoryData(); // Xóa dữ liệu cũ trước khi tải mới

  //   // ---- Sử dụng dữ liệu thật từ Firestore ----
  //   try {
  //     final endTime = DateTime.now();
  //     final startTime = endTime.subtract(duration);

  //     final List<HealthData> fetchedData = await _firestoreService
  //         .getHealthDataForPeriod(currentUser.uid, startTime, endTime);

  //     _healthHistory = fetchedData; // Cập nhật state dữ liệu gốc

  //     // --- GỌI HÀM TÍNH TOÁN STEPS ---
  //     _hourlyStepsData = _calculateHourlySteps(_healthHistory);
  //     // -----------------------------

  //     _updateHistoryStatus(HistoryStatus.loaded); // Báo tải xong
  //     print(
  //       "[DashboardProvider] Fetched ${_healthHistory.length} history records from Firestore.",
  //     );
  //     print(
  //       "[DashboardProvider] Calculated ${_hourlyStepsData.length} hourly step records.",
  //     );
  //   } catch (e) {
  //     print("!!! [DashboardProvider] Error fetching Firestore history: $e");
  //     _updateHistoryStatus(HistoryStatus.error, "Failed to load history data.");
  //     _clearHistoryData(); // Xóa dữ liệu cũ khi lỗi
  //   }
  //   // ------------------------------
  // }

  /// Tải dữ liệu sức khỏe (PHIÊN BẢN DÙNG DỮ LIỆU GIẢ)
  // Future<void> fetchHealthHistory({
  //   Duration duration = const Duration(hours: 24),
  //   bool useDummyData = true, // <<< Thêm cờ để bật/tắt dữ liệu giả
  // }) async {
  //   final currentUser = _authService.currentUser;
  //   // Kiểm tra user vẫn cần thiết nếu có logic khác phụ thuộc
  //   if (currentUser == null && !useDummyData) {
  //     // Chỉ báo lỗi nếu không dùng dummy
  //     print("[DashboardProvider] Cannot fetch history: No user logged in.");
  //     _updateHistoryStatus(HistoryStatus.error, "User not logged in");
  //     return;
  //   }

  //   if (_historyStatus == HistoryStatus.loading) return;

  //   print(
  //     "[DashboardProvider] Fetching health history (Dummy: $useDummyData)...",
  //   );
  //   _updateHistoryStatus(HistoryStatus.loading);

  //   // ---- Lựa chọn nguồn dữ liệu ----
  //   if (useDummyData) {
  //     // Sử dụng dữ liệu giả
  //     await Future.delayed(const Duration(seconds: 1)); // Giả lập độ trễ mạng
  //     _healthHistory = generateDummyHealthData(
  //       count: 150, // Tạo 150 điểm dữ liệu
  //       duration: duration, // Trong khoảng thời gian yêu cầu
  //       simulateGaps: true, // Mô phỏng có khoảng trống dữ liệu
  //     );
  //     _updateHistoryStatus(HistoryStatus.loaded);
  //     print(
  //       "[DashboardProvider] Loaded ${_healthHistory.length} DUMMY history records.",
  //     );
  //   } else {
  //     // Sử dụng dữ liệu thật từ Firestore (code gốc)
  //     if (currentUser == null) return; // Double check user nếu dùng firestore
  //     try {
  //       final endTime = DateTime.now();
  //       final startTime = endTime.subtract(duration);
  //       final List<HealthData> fetchedData = await _firestoreService
  //           .getHealthDataForPeriod(currentUser.uid, startTime, endTime);
  //       _healthHistory = fetchedData;
  //       _updateHistoryStatus(HistoryStatus.loaded);
  //       print(
  //         "[DashboardProvider] Fetched ${_healthHistory.length} history records from Firestore.",
  //       );
  //     } catch (e) {
  //       print("!!! [DashboardProvider] Error fetching Firestore history: $e");
  //       _updateHistoryStatus(
  //           HistoryStatus.error, "Failed to load history data.");
  //     }
  //   }
  //   // ------------------------------
  // }

  // Có thể thêm các hàm khác sau này, ví dụ: tải theo ngày cụ thể, lọc dữ liệu,...

  /// Tạo danh sách dữ liệu HealthData giả lập cho mục đích kiểm thử.
  ///
  /// - [count]: Số lượng bản ghi cần tạo.
  /// - [duration]: Khoảng thời gian bao phủ bởi dữ liệu (ví dụ: Duration(hours: 24)).
  /// - [endTime]: Thời điểm kết thúc của dữ liệu (mặc định là DateTime.now()).
  /// - [simulateGaps]: Nếu true, thỉnh thoảng sẽ tạo ra giá trị HR/SpO2 không hợp lệ (-1) để mô phỏng mất dữ liệu.
}
