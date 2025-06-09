// lib/providers/dashboard_provider.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // <<< Cần thiết cho 'Color'

// Import các Services
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';

// Import các Models
import '../models/health_data.dart';
import '../models/activity_segment.dart';

// --- Cấu trúc dữ liệu và Enum ---

class HourlyStepsData {
  final DateTime hourStart;
  final int steps;
  HourlyStepsData(this.hourStart, this.steps);
  @override
  String toString() =>
      'HourlyStepsData(hour: ${hourStart.hour}, steps: $steps)';
}

class ActivitySummaryData {
  final String activityName;
  final Duration totalDuration;
  final Color color;

  ActivitySummaryData({
    required this.activityName,
    required this.totalDuration,
    required this.color,
  });
}

enum HistoryStatus { initial, loading, loaded, error }

class DashboardProvider with ChangeNotifier {
  final FirestoreService _firestoreService;
  final AuthService _authService;
  final LocalDbService _localDbService = LocalDbService.instance;

  bool _isDisposed = false;

  // --- State cho Health History ---
  List<HealthData> _healthHistory = [];
  List<HourlyStepsData> _hourlyStepsData = [];
  HistoryStatus _historyStatus = HistoryStatus.initial;
  String? _historyError;

  // --- State cho Activity History ---
  List<ActivitySegment> _activityHistory = [];
  List<ActivitySummaryData> _activitySummary = [];

  // --- Getters ---
  List<HealthData> get healthHistory => _healthHistory;
  HistoryStatus get historyStatus => _historyStatus;
  String? get historyError => _historyError;
  List<HourlyStepsData> get hourlyStepsData => _hourlyStepsData;
  List<ActivitySummaryData> get activitySummary => _activitySummary;

  // <<< SỬA LỖI: THÊM GETTER CÒN THIẾU Ở ĐÂY >>>
  List<ActivitySegment> get activityHistory => _activityHistory;
  // ---------------------------------------------

  Duration get todayTotalActivityDuration {
    if (_activitySummary.isEmpty) return Duration.zero;
    return _activitySummary.fold(Duration.zero,
        (previousValue, element) => previousValue + element.totalDuration);
  }

  int get todayTotalSteps {
    if (_hourlyStepsData.isEmpty) return 0;
    int calculatedSteps = 0;
    final nowLocal = DateTime.now();
    final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    for (var hourlyData in _hourlyStepsData) {
      final dataHourLocal = hourlyData.hourStart.toLocal();
      if (!dataHourLocal.isBefore(todayStart) &&
          dataHourLocal.isBefore(todayEnd)) {
        calculatedSteps += hourlyData.steps;
      }
    }
    return calculatedSteps;
  }

  // Constructor
  DashboardProvider(this._firestoreService, this._authService) {
    if (kDebugMode) print("[DashboardProvider] Initialized.");
    if (_authService.currentUser != null) {
      if (kDebugMode)
        print(
            "[DashboardProvider] User found on init. Fetching initial history.");
      fetchHealthHistory();
    }
  }

  List<HourlyStepsData> _calculateHourlySteps(List<HealthData> history) {
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
          if (kDebugMode)
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
    if (kDebugMode)
      print(
          "[_calculateHourlySteps] Calculated hourly steps result: ${result.length} hours");
    return result;
  }

  List<ActivitySummaryData> _calculateActivitySummary(
      List<ActivitySegment> segments) {
    if (segments.isEmpty) return [];
    final Map<String, int> durationMap = {};
    for (final segment in segments) {
      durationMap.update(
        segment.activityName,
        (value) => value + segment.durationInSeconds,
        ifAbsent: () => segment.durationInSeconds,
      );
    }
    final Map<String, Color> colorMap = {
      'Sitting': Colors.orange.shade400,
      'Standing': Colors.blue.shade400,
      'Walking': Colors.green.shade400,
      'Running': Colors.red.shade400,
      'Lying': Colors.purple.shade400,
      'Unknown': Colors.grey.shade400,
    };
    return durationMap.entries.map((entry) {
      return ActivitySummaryData(
        activityName: entry.key,
        totalDuration: Duration(seconds: entry.value),
        color: colorMap[entry.key] ?? Colors.grey,
      );
    }).toList()
      ..sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
  }

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
      final results = await Future.wait([
        if (useDummyData)
          Future.value(generateDummyHealthData(
              count: 200, duration: duration, simulateGaps: true))
        else
          _firestoreService.getHealthDataForPeriod(currentUser!.uid,
              DateTime.now().subtract(duration), DateTime.now()),
        if (!useDummyData)
          _localDbService.getActivitySegmentsForDay(DateTime.now(),
              userId: currentUser!.uid)
        else
          Future.value(<ActivitySegment>[])
      ]);

      if (_isDisposed) {
        if (kDebugMode)
          print(
              "[DashboardProvider] Aborting state update because provider was disposed.");
        return;
      }

      final List<HealthData> fetchedHealthData = results[0] as List<HealthData>;
      final List<ActivitySegment> fetchedActivitySegments =
          results[1] as List<ActivitySegment>;

      _healthHistory = fetchedHealthData;
      _hourlyStepsData = _calculateHourlySteps(_healthHistory);

      _activityHistory = fetchedActivitySegments;
      _activitySummary = _calculateActivitySummary(_activityHistory);

      _updateHistoryStatus(HistoryStatus.loaded);
      if (kDebugMode)
        print(
            "[DashboardProvider] Data fetch/calculation successful (including ${fetchedActivitySegments.length} activity segments).");
    } catch (e) {
      if (kDebugMode)
        print("!!! [DashboardProvider] Error during fetchHealthHistory: $e");
      if (_isDisposed) {
        if (kDebugMode)
          print(
              "[DashboardProvider] Aborting error state update because provider was disposed.");
        return;
      }
      _updateHistoryStatus(HistoryStatus.error, "Failed to load history data.");
      _clearHistoryData();
    }
  }

  void _clearHistoryData() {
    _healthHistory = [];
    _hourlyStepsData = [];
    _activityHistory = [];
    _activitySummary = [];
  }

  void _updateHistoryStatus(HistoryStatus newStatus, [String? errorMessage]) {
    if (_isDisposed) return;
    _historyStatus = newStatus;
    _historyError = errorMessage;
    notifyListeners();
  }

  @override
  void dispose() {
    if (kDebugMode) print("[DashboardProvider] Disposing...");
    _isDisposed = true;
    super.dispose();
  }

  void clearDataOnLogout() {
    _clearHistoryData();
    _historyStatus = HistoryStatus.initial;
    _historyError = null;
    notifyListeners();
    if (kDebugMode) print("[DashboardProvider] Cleared data on logout.");
  }

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
