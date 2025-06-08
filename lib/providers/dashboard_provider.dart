// lib/providers/dashboard_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../models/health_data.dart';
import 'dart:math';

// Cấu trúc dữ liệu và Enum không đổi...
class HourlyStepsData {
  final DateTime hourStart;
  final int steps;
  HourlyStepsData(this.hourStart, this.steps);
  @override
  String toString() =>
      'HourlyStepsData(hour: ${hourStart.hour}, steps: $steps)';
}

enum HistoryStatus { initial, loading, loaded, error }

class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;

  // CỜ QUAN TRỌNG ĐỂ THEO DÕI TRẠNG THÁI DISPOSE
  bool _isDisposed = false;

  List<HourlyStepsData> _hourlyStepsData = [];
  List<HealthData> _healthHistory = [];
  HistoryStatus _historyStatus = HistoryStatus.initial;
  String? _historyError;

  List<HealthData> get healthHistory => _healthHistory;
  HistoryStatus get historyStatus => _historyStatus;
  String? get historyError => _historyError;
  List<HourlyStepsData> get hourlyStepsData => _hourlyStepsData;

  // Constructor
  DashboardProvider(this._firestoreService, this._authService) {
    print("[DashboardProvider] Initialized.");
    // TỰ ĐỘNG TẢI DỮ LIỆU KHI PROVIDER ĐƯỢC TẠO VÀ CÓ USER
    if (_authService.currentUser != null) {
      print(
          "[DashboardProvider] User found on init. Fetching initial history.");
      fetchHealthHistory();
    }
  }

  // --- HÀM TÍNH TOÁN (Không đổi) ---
  List<HourlyStepsData> _calculateHourlySteps(List<HealthData> history) {
    // ... code của bạn ở đây, không cần thay đổi ...
    if (history.isEmpty) return [];
    Map<DateTime, int> hourlyStepsMap = {};
    int previousSteps = -1;
    for (int i = 0; i < history.length; i++) {
      final currentData = history[i];
      final currentSteps = currentData.steps;
      if (currentSteps < 0) {
        if (previousSteps >= 0) {
          previousSteps = currentSteps;
        }
        continue;
      }
      final DateTime currentHourStart = DateTime.utc(
        currentData.timestamp.year,
        currentData.timestamp.month,
        currentData.timestamp.day,
        currentData.timestamp.hour,
      );
      int stepsInThisInterval = 0;
      if (previousSteps != -1) {
        if (currentSteps >= previousSteps) {
          stepsInThisInterval = currentSteps - previousSteps;
        } else {
          stepsInThisInterval = currentSteps;
          print(
              "[_calculateHourlySteps] Detected step count decrease/reset: prev=$previousSteps, curr=$currentSteps at ${currentData.timestamp.toLocal()}");
        }
      } else {
        stepsInThisInterval = currentSteps;
      }
      hourlyStepsMap.update(
        currentHourStart,
        (existingValue) => existingValue + stepsInThisInterval,
        ifAbsent: () => stepsInThisInterval,
      );
      previousSteps = currentSteps;
    }
    List<HourlyStepsData> result = hourlyStepsMap.entries
        .map((entry) => HourlyStepsData(entry.key, entry.value))
        .toList();
    result.sort((a, b) => a.hourStart.compareTo(b.hourStart));
    print(
        "[_calculateHourlySteps] Calculated hourly steps result: ${result.length} hours");
    return result;
  }

  // --- HÀM TẢI DỮ LIỆU (ĐÃ SỬA LỖI) ---
  Future<void> fetchHealthHistory({
    Duration duration = const Duration(hours: 24),
    bool useDummyData = false,
  }) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null && !useDummyData) {
      _updateHistoryStatus(HistoryStatus.error, "User not logged in");
      _clearHistoryData();
      return;
    }

    if (_historyStatus == HistoryStatus.loading) return;

    _updateHistoryStatus(HistoryStatus.loading);
    _clearHistoryData();

    try {
      List<HealthData> fetchedData;
      if (useDummyData) {
        await Future.delayed(const Duration(milliseconds: 800));
        fetchedData = generateDummyHealthData(
            count: 200, duration: duration, simulateGaps: true);
      } else {
        final endTime = DateTime.now();
        final startTime = endTime.subtract(duration);
        fetchedData = await _firestoreService.getHealthDataForPeriod(
            currentUser!.uid, startTime, endTime);
      }

      // KIỂM TRA TRƯỚC KHI CẬP NHẬT STATE
      if (_isDisposed) {
        print(
            "[DashboardProvider] Aborting state update because provider was disposed.");
        return;
      }

      _healthHistory = fetchedData;
      _hourlyStepsData = _calculateHourlySteps(_healthHistory);
      _updateHistoryStatus(HistoryStatus.loaded);
      print("[DashboardProvider] Data fetch/calculation successful.");
    } catch (e) {
      print("!!! [DashboardProvider] Error during fetchHealthHistory: $e");
      // KIỂM TRA TRƯỚC KHI CẬP NHẬT STATE LỖI
      if (_isDisposed) {
        print(
            "[DashboardProvider] Aborting error state update because provider was disposed.");
        return;
      }
      _updateHistoryStatus(HistoryStatus.error, "Failed to load history data.");
      _clearHistoryData();
    }
  }

  // Hàm helper để xóa dữ liệu lịch sử
  void _clearHistoryData() {
    _healthHistory = [];
    _hourlyStepsData = [];
  }

  // Hàm helper cập nhật trạng thái
  void _updateHistoryStatus(HistoryStatus newStatus, [String? errorMessage]) {
    // KIỂM TRA Ở ĐÂY NỮA CHO CHẮC
    if (_isDisposed) return;
    _historyStatus = newStatus;
    _historyError = errorMessage;
    notifyListeners();
  }

  // --- HÀM DISPOSE (ĐÃ CẬP NHẬT) ---
  @override
  void dispose() {
    print("[DashboardProvider] Disposing...");
    _isDisposed = true; // Đặt cờ này thành true
    super.dispose();
  }

  // --- HÀM TẠO DỮ LIỆU GIẢ (Không đổi) ---
  List<HealthData> generateDummyHealthData({
    // ... code của bạn ở đây, không cần thay đổi ...
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
    int currentSteps = random.nextInt(100);
    double lastAx = 0.0, lastAy = 0.0, lastAz = 1.0;
    for (int i = 0; i < count; i++) {
      final DateTime timestamp = start
          .add(Duration(milliseconds: (timeStepMillis * i).toInt()))
          .toUtc();
      int hrValue;
      int spo2Value;
      if (simulateGaps && random.nextDouble() < 0.05) {
        hrValue = -1;
        spo2Value = -1;
      } else {
        currentHr += random.nextDouble() * 6 - 3;
        currentHr = currentHr.clamp(50.0, 160.0);
        hrValue = currentHr.toInt();
        if (random.nextDouble() < 0.1) {
          currentSpo2 += random.nextInt(3) - 1;
          currentSpo2 = currentSpo2.clamp(90, 100);
        }
        spo2Value = currentSpo2;
      }
      if (lastAz.abs() < 0.8 || lastAx.abs() > 0.2 || lastAy.abs() > 0.2) {
        if (random.nextDouble() < 0.6) {
          currentSteps += random.nextInt(8) + 1;
        }
      } else {
        if (random.nextDouble() < 0.1) {
          currentSteps += random.nextInt(2);
        }
      }
      lastAx += random.nextDouble() * 0.1 - 0.05;
      lastAy += random.nextDouble() * 0.1 - 0.05;
      lastAz += random.nextDouble() * 0.05 - 0.025;
      dummyData.add(HealthData(
        ax: lastAx.clamp(-2.0, 2.0),
        ay: lastAy.clamp(-2.0, 2.0),
        az: lastAz.clamp(-2.0, 2.0),
        gx: random.nextDouble() * 0.5 - 0.25,
        gy: random.nextDouble() * 0.5 - 0.25,
        gz: random.nextDouble() * 0.5 - 0.25,
        steps: currentSteps,
        hr: hrValue,
        spo2: spo2Value,
        ir: 10000 + random.nextInt(5000),
        red: 2000 + random.nextInt(1000),
        wifi: random.nextBool(),
        timestamp: timestamp,
      ));
    }
    return dummyData;
  }
}
