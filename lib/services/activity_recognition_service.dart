// lib/services/activity_recognition_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Models
import '../models/health_data.dart';
import '../models/activity_segment.dart';

// Import Services
import 'local_db_service.dart';
import 'auth_service.dart';

// Import Constants
import '../app_constants.dart';

// --- Hằng số Model ---
const String TFLITE_MODEL_HAR_FILE =
    'assets/ml_models/HAR_CNN_1D_Custom_best_val_accuracy_float32.tflite';
const String SCALER_PARAMS_FILE = 'assets/ml_models/scaler_params.json';
const int HAR_WINDOW_SIZE = 20;
const int HAR_NUM_FEATURES = 6;
const int HAR_STEP_SIZE = 10;
const int HAR_NUM_CLASSES = 5;
const Map<int, String> HAR_ACTIVITY_LABELS = {
  0: 'Standing',
  1: 'Lying',
  2: 'Sitting',
  3: 'Walking',
  4: 'Running',
};

// --- Enum và Class cho Cảnh báo ---
enum ActivityWarningType {
  prolongedSitting,
  prolongedLyingDaytime,
  smartReminderToMove,
  positiveReinforcement,
}

class ActivityWarning {
  final ActivityWarningType type;
  final String message;
  final DateTime timestamp;
  final String? suggestedAction;

  ActivityWarning({
    required this.type,
    required this.message,
    required this.timestamp,
    this.suggestedAction,
  });

  @override
  String toString() {
    return 'ActivityWarning(type: $type, message: "$message", timestamp: $timestamp, suggestion: "$suggestedAction")';
  }
}

class ActivityRecognitionService {
  Interpreter? _harInterpreter;
  bool _isHarModelLoaded = false;
  List<int>? _harInputShape;
  List<int>? _harOutputShape;
  dynamic _harInputType;
  dynamic _harOutputType;
  List<double>? _scalerMeans;
  List<double>? _scalerStdDevs;

  final List<List<double>> _imuDataBuffer = [];

  final BehaviorSubject<String> _activityPredictionController =
      BehaviorSubject<String>.seeded("Initializing...");
  Stream<String> get activityPredictionStream =>
      _activityPredictionController.stream;
  String? get currentActivityValue => _activityPredictionController.valueOrNull;

  final PublishSubject<ActivityWarning> _warningController =
      PublishSubject<ActivityWarning>();
  Stream<ActivityWarning> get warningStream => _warningController.stream;

  String _currentActivityInternal = "Initializing...";
  DateTime? _currentActivityStartTime;

  final LocalDbService _localDbService = LocalDbService.instance;
  final AuthService _authService;

  Timer? _sittingTimer;
  Timer? _lyingTimer;
  Duration _sittingDuration = Duration.zero;
  Duration _lyingDuration = Duration.zero;

  // <<< KHAI BÁO CÁC BIẾN CỜ VÀ THEO DÕI CẢNH BÁO >>>
  bool _hasWarnedForCurrentSitting = false;
  bool _hasWarnedForCurrentLyingDaytime = false;
  ActivityWarningType?
      _lastWarningTypeSent; // Để theo dõi loại cảnh báo cuối cùng đã gửi
  // ----------------------------------------------------

  Duration _sittingWarningThreshold =
      AppConstants.defaultSittingWarningThreshold;
  Duration _lyingDaytimeWarningThreshold =
      AppConstants.defaultLyingWarningDaytimeThreshold;
  bool _smartRemindersEnabled = AppConstants.defaultSmartRemindersEnabled;

  StreamSubscription? _healthDataSubscriptionForHar;
  bool _isDisposed = false;

  ActivityRecognitionService({required AuthService authService})
      : _authService = authService {
    if (kDebugMode) print("[ARService] Initializing...");
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadSettings();
    await _loadResources();
    // _restoreLastKnownActivity sẽ được gọi trong _loadResources sau khi model sẵn sàng
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sittingWarningThreshold = Duration(
          minutes: prefs.getInt(AppConstants.prefKeySittingWarningMinutes) ??
              AppConstants.defaultSittingWarningThreshold.inMinutes);
      _lyingDaytimeWarningThreshold = Duration(
          hours: prefs.getInt(AppConstants.prefKeyLyingWarningHours) ??
              AppConstants.defaultLyingWarningDaytimeThreshold.inHours);
      _smartRemindersEnabled =
          prefs.getBool(AppConstants.prefKeySmartRemindersEnabled) ??
              AppConstants.defaultSmartRemindersEnabled;
      if (kDebugMode)
        print(
            "[ARService] Settings loaded. SitThr: ${_sittingWarningThreshold.inMinutes}m, LieThr: ${_lyingDaytimeWarningThreshold.inHours}h, SmartRem: $_smartRemindersEnabled");
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error loading settings, using defaults: $e");
    }
  }

  Future<void> _restoreLastKnownActivity() async {
    if (_isDisposed || !_isHarModelLoaded) {
      if (kDebugMode)
        print(
            "[ARService] Conditions not met for restoring last activity (disposed: $_isDisposed, modelLoaded: $_isHarModelLoaded).");
      if (!_isHarModelLoaded && !_activityPredictionController.isClosed) {
        _activityPredictionController.add("Model Loading...");
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActivity =
          prefs.getString(AppConstants.prefKeyLastKnownActivity);
      final lastActivityTimeStr =
          prefs.getString(AppConstants.prefKeyLastKnownActivityTimestamp);

      if (lastActivity != null &&
          lastActivity.isNotEmpty &&
          lastActivity != "Initializing..." &&
          lastActivity != "Model Loading...") {
        _currentActivityInternal = lastActivity;
        _currentActivityStartTime = (lastActivityTimeStr != null)
            ? DateTime.tryParse(lastActivityTimeStr)?.toUtc()
            : null;
        _currentActivityStartTime ??= DateTime.now().toUtc();

        if (!_activityPredictionController.isClosed &&
            _activityPredictionController.valueOrNull !=
                _currentActivityInternal) {
          _activityPredictionController.add(_currentActivityInternal);
        }
        // Khởi động lại timer và tính toán duration đã trôi qua
        _handleActivityChange(_currentActivityInternal, isInitialRestore: true);
        if (kDebugMode)
          print(
              "[ARService] Restored last known activity: $_currentActivityInternal since $_currentActivityStartTime");
      } else {
        _currentActivityInternal = "Unknown";
        _currentActivityStartTime = DateTime.now().toUtc();
        if (!_activityPredictionController.isClosed &&
            _activityPredictionController.valueOrNull !=
                _currentActivityInternal) {
          _activityPredictionController.add(_currentActivityInternal);
        }
        if (kDebugMode)
          print(
              "[ARService] No valid last known activity found, starting fresh.");
        // Gọi handleActivityChange để đảm bảo timer không chạy cho "Unknown"
        _handleActivityChange(_currentActivityInternal,
            isInitialRestore: false);
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error restoring last known activity: $e");
    }
  }

  Future<void> _loadResources() async {
    if (_isDisposed) return;
    if (_isHarModelLoaded &&
        _scalerMeans != null &&
        _scalerStdDevs != null &&
        _harInterpreter != null) {
      if (kDebugMode) print("[ARService] Resources already loaded.");
      if (_activityPredictionController.valueOrNull == "Initializing..." ||
          _activityPredictionController.valueOrNull == "Model Loading...") {
        await _restoreLastKnownActivity();
      }
      return;
    }
    if (kDebugMode)
      print("[ARService] Loading HAR TFLite model and Scaler params...");
    try {
      _harInterpreter = await Interpreter.fromAsset(TFLITE_MODEL_HAR_FILE);
      final scalerJsonString = await rootBundle.loadString(SCALER_PARAMS_FILE);
      final scalerData = jsonDecode(scalerJsonString) as Map<String, dynamic>;
      _scalerMeans = (scalerData['mean'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      _scalerStdDevs = (scalerData['std_dev'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();

      if (_harInterpreter != null &&
          _scalerMeans != null &&
          _scalerStdDevs != null) {
        _harInputShape = _harInterpreter!.getInputTensor(0).shape;
        _harOutputShape = _harInterpreter!.getOutputTensor(0).shape;
        _harInputType = _harInterpreter!.getInputTensor(0).type;
        _harOutputType = _harInterpreter!.getOutputTensor(0).type;
        _isHarModelLoaded = true;
        if (kDebugMode)
          print("[ARService] HAR Model and Scaler loaded successfully.");
        // ... (log debug và kiểm tra shape/type như trước) ...
        await _restoreLastKnownActivity();
      } else {
        throw Exception(
            "HAR Interpreter or Scaler Params are null after loading.");
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error loading HAR TFLite model or scaler: $e");
      _isHarModelLoaded = false;
      _harInterpreter?.close();
      _harInterpreter = null;
      _scalerMeans = null;
      _scalerStdDevs = null;
      if (!_activityPredictionController.isClosed)
        _activityPredictionController.addError("Failed to load ML model");
    }
  }

  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (_isDisposed) return;
    if (!_isHarModelLoaded || _scalerMeans == null || _scalerStdDevs == null) {
      if (kDebugMode)
        print(
            "[ARService] Model/Scaler not ready. Attempting to load then start.");
      _loadResources().then((_) {
        if (!_isDisposed &&
            _isHarModelLoaded &&
            _scalerMeans != null &&
            _scalerStdDevs != null) {
          startProcessingHealthData(healthDataStream);
        } else if (!_isDisposed) {
          if (kDebugMode)
            print(
                "[ARService] Failed to load resources on retry. Cannot start processing.");
          if (!_activityPredictionController.isClosed)
            _activityPredictionController.addError("Model/Scaler not loaded");
        }
      });
      return;
    }
    _healthDataSubscriptionForHar?.cancel();
    if (kDebugMode)
      print("[ARService] Subscribing to health data stream for HAR...");
    _healthDataSubscriptionForHar = healthDataStream.listen((healthData) {
      if (_isDisposed) return;
      _addImuToBufferAndPredict([
        healthData.ax,
        healthData.ay,
        healthData.az,
        healthData.gx,
        healthData.gy,
        healthData.gz,
      ]);
    }, onError: (error) {
      if (_isDisposed) return;
      if (kDebugMode)
        print("!!! [ARService] Error on health data stream: $error");
      if (!_activityPredictionController.isClosed)
        _activityPredictionController.addError("Health data stream error");
    }, onDone: () {
      if (_isDisposed) return;
      if (kDebugMode) print("[ARService] Health data stream for HAR closed.");
    });
  }

  void stopProcessingHealthData() {
    if (kDebugMode)
      print("[ARService] Stopping health data processing for HAR.");
    _healthDataSubscriptionForHar?.cancel();
    _healthDataSubscriptionForHar = null;
    // Lưu segment cuối cùng nếu có hoạt động đang diễn ra có ý nghĩa
    if (_currentActivityInternal != "Initializing..." &&
        _currentActivityInternal != "Unknown" &&
        _currentActivityStartTime != null) {
      _handleActivityEnd(_currentActivityInternal);
    }
    _stopActivityTimers(); // Dừng và reset timer, cờ warning
    _currentActivityInternal = "Unknown";
    _currentActivityStartTime = null;
    if (!_isDisposed &&
        !_activityPredictionController.isClosed &&
        _activityPredictionController.valueOrNull != _currentActivityInternal) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _saveLastKnownActivity(); // Lưu trạng thái "Unknown"
  }

  void _addImuToBufferAndPredict(List<double> imuSample) {
    if (_isDisposed ||
        !_isHarModelLoaded ||
        _harInterpreter == null ||
        _scalerMeans == null ||
        _scalerStdDevs == null) return;
    if (imuSample.length != HAR_NUM_FEATURES) return;
    _imuDataBuffer.add(imuSample);

    if (_imuDataBuffer.length >= HAR_WINDOW_SIZE) {
      List<List<double>> windowData =
          List.from(_imuDataBuffer.sublist(0, HAR_WINDOW_SIZE));
      var inputTensor = List.generate(
          1,
          (b) => List.generate(
              HAR_WINDOW_SIZE,
              (i) => List.generate(HAR_NUM_FEATURES, (j) {
                    double mean = _scalerMeans![j];
                    double stdDev = _scalerStdDevs![j];
                    return (windowData[i][j] - mean) /
                        (stdDev.abs() < 1e-6 ? 1.0 : stdDev);
                  })));
      var outputTensor =
          List.generate(1, (_) => List.filled(HAR_NUM_CLASSES, 0.0));

      try {
        _harInterpreter!.run(inputTensor, outputTensor);
        List<double> probabilities = outputTensor[0];
        int predictedIndex = -1;
        double maxProbability = 0.0;
        for (int i = 0; i < probabilities.length; i++) {
          if (probabilities[i] > maxProbability) {
            maxProbability = probabilities[i];
            predictedIndex = i;
          }
        }
        String predictedActivityName =
            HAR_ACTIVITY_LABELS[predictedIndex] ?? "Unknown";

        if (predictedActivityName != "Unknown" &&
            maxProbability > AppConstants.harMinConfidenceThreshold) {
          String oldActivity =
              _currentActivityInternal; // Lưu lại hoạt động cũ TRƯỚC KHI cập nhật

          if (predictedActivityName != oldActivity) {
            // Chỉ gọi _handleActivityEnd nếu hoạt động cũ có ý nghĩa
            if (oldActivity != "Initializing..." &&
                oldActivity != "Unknown" &&
                _currentActivityStartTime != null) {
              _handleActivityEnd(oldActivity);
            }

            // Cập nhật sang hoạt động mới
            _currentActivityInternal = predictedActivityName;
            _currentActivityStartTime = DateTime.now().toUtc();

            if (kDebugMode)
              print(
                  ">>> HAR New Activity: $_currentActivityInternal (Prob: ${maxProbability.toStringAsFixed(2)})");
            if (!_isDisposed &&
                !_activityPredictionController.isClosed &&
                _activityPredictionController.valueOrNull !=
                    _currentActivityInternal) {
              _activityPredictionController.add(_currentActivityInternal);
            }
            _saveLastKnownActivity(); // Lưu trạng thái mới

            // Xử lý logic phản hồi tích cực
            if (_smartRemindersEnabled &&
                _lastWarningTypeSent == ActivityWarningType.prolongedSitting &&
                oldActivity == 'Sitting' &&
                (_currentActivityInternal == 'Standing' ||
                    _currentActivityInternal == 'Walking' ||
                    _currentActivityInternal == 'Running')) {
              final positiveWarning = ActivityWarning(
                type: ActivityWarningType.positiveReinforcement,
                message:
                    "Tuyệt vời! Bạn đã đứng dậy và vận động sau khi ngồi lâu.",
                timestamp: DateTime.now(),
              );
              if (!_warningController.isClosed)
                _warningController.add(positiveWarning);
              _lastWarningTypeSent = null; // Reset
            }
            // Gọi _handleActivityChange cho hoạt động mới
            _handleActivityChange(_currentActivityInternal,
                isInitialRestore: false);
          }
        }
      } catch (e) {
        if (kDebugMode)
          print("!!! [ARService] Error running HAR TFLite model: $e");
        if (!_activityPredictionController.isClosed)
          _activityPredictionController.addError("HAR Inference Error");
      }
      if (_imuDataBuffer.length >= HAR_STEP_SIZE)
        _imuDataBuffer.removeRange(0, HAR_STEP_SIZE);
      else
        _imuDataBuffer.clear();
    }
  }

  Future<void> _saveLastKnownActivity() async {
    if (_isDisposed) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.prefKeyLastKnownActivity, _currentActivityInternal);
      if (_currentActivityStartTime != null) {
        await prefs.setString(AppConstants.prefKeyLastKnownActivityTimestamp,
            _currentActivityStartTime!.toIso8601String());
      } else {
        // Nếu startTime là null (ví dụ sau khi stop), xóa timestamp đã lưu
        await prefs.remove(AppConstants.prefKeyLastKnownActivityTimestamp);
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error saving last known activity: $e");
    }
  }

  Future<void> _handleActivityEnd(String endedActivity) async {
    if (_isDisposed ||
        _currentActivityStartTime == null ||
        endedActivity == "Unknown" ||
        endedActivity == "Initializing...") return;

    final endTime = DateTime.now().toUtc();
    final duration = endTime.difference(_currentActivityStartTime!);

    if (duration.inSeconds < AppConstants.minActivityDurationToLogSeconds) {
      if (kDebugMode)
        print(
            "[ARService] Activity '$endedActivity' (ended) duration ${duration.inSeconds}s < ${AppConstants.minActivityDurationToLogSeconds}s. Not logging.");
      // Không reset _currentActivityStartTime ở đây nếu không log, vì hoạt động "ngắn" này
      // không nên làm gián đoạn việc theo dõi một hoạt động dài hơn nếu nó quay lại ngay.
      // Tuy nhiên, logic _addImuToBufferAndPredict sẽ cập nhật _currentActivityStartTime khi có hoạt động MỚI.
      return;
    }

    final segment = ActivitySegment(
      activityName: endedActivity,
      startTime: _currentActivityStartTime!,
      endTime: endTime,
      durationInSeconds: duration.inSeconds,
      userId: _authService.currentUser?.uid,
      isSynced: false,
    );

    try {
      final id = await _localDbService.insertActivitySegment(segment);
      if (id > 0 && kDebugMode) {
        print(
            "[ARService] Activity Segment Saved to Local DB: ID $id, ${segment.activityName}, Duration: ${segment.durationInSeconds}s");
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error saving activity segment to local DB: $e");
    }
    // _currentActivityStartTime sẽ được reset khi một hoạt động MỚI bắt đầu trong _addImuToBufferAndPredict
  }

  void _handleActivityChange(String newActivity,
      {bool isInitialRestore = false}) {
    if (_isDisposed) return;

    // Dừng timer cũ và reset cờ warning nếu hoạt động thay đổi hoặc không phải restore
    _stopActivityTimers(
        preserveCurrentActivityDuration: isInitialRestore,
        resetSittingWarningFlag:
            (newActivity != 'Sitting') || !isInitialRestore,
        resetLyingWarningFlag: (newActivity != 'Lying') || !isInitialRestore);

    // Tính toán lại duration nếu là khôi phục trạng thái
    if (isInitialRestore && _currentActivityStartTime != null) {
      final now = DateTime.now().toUtc();
      if (now.isAfter(_currentActivityStartTime!)) {
        final restoredDuration = now.difference(_currentActivityStartTime!);
        if (newActivity == 'Sitting') _sittingDuration = restoredDuration;
        if (newActivity == 'Lying') _lyingDuration = restoredDuration;
        if (kDebugMode)
          print(
              "[ARService] Restored duration for $newActivity: ${_getActivityDuration(newActivity).inMinutes}min. SittingWarned: $_hasWarnedForCurrentSitting, LyingWarned: $_hasWarnedForCurrentLyingDaytime");
      } else {
        if (kDebugMode)
          print(
              "[ARService] Start time for restored activity is in the future. Resetting duration.");
        if (newActivity == 'Sitting') _sittingDuration = Duration.zero;
        if (newActivity == 'Lying') _lyingDuration = Duration.zero;
      }
    }
    // Nếu không phải restore, duration đã được reset bởi _stopActivityTimers

    // Khởi động timer cho hoạt động mới
    if (newActivity == 'Sitting') {
      _sittingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_isDisposed || _currentActivityInternal != 'Sitting') {
          timer.cancel();
          _sittingTimer = null;
          return;
        }
        _sittingDuration += const Duration(minutes: 1);
        if (kDebugMode)
          print(
              "[ARService] Sitting duration: ${_sittingDuration.inMinutes} min. Warned: $_hasWarnedForCurrentSitting");

        if (!_hasWarnedForCurrentSitting &&
            _sittingDuration >= _sittingWarningThreshold) {
          final warning = ActivityWarning(
              type: ActivityWarningType.prolongedSitting,
              message:
                  "Bạn đã ngồi ${_sittingDuration.inMinutes} phút. Hãy đứng dậy và vận động một chút!",
              timestamp: DateTime.now(),
              suggestedAction:
                  "Đứng dậy, đi lại hoặc thực hiện vài động tác giãn cơ.");
          if (!_warningController.isClosed) _warningController.add(warning);
          _lastWarningTypeSent = ActivityWarningType.prolongedSitting;
          _hasWarnedForCurrentSitting = true;
        } else if (_smartRemindersEnabled &&
            !_hasWarnedForCurrentSitting &&
            _sittingDuration.inMinutes > 0 &&
            _sittingDuration < _sittingWarningThreshold &&
            _sittingDuration.inMinutes %
                    AppConstants.smartReminderIntervalMinutes ==
                0) {
          final warning = ActivityWarning(
              type: ActivityWarningType.smartReminderToMove,
              message:
                  "Bạn đã ngồi được ${_sittingDuration.inMinutes} phút rồi. Cân nhắc thay đổi tư thế hoặc vận động nhẹ nhé.",
              timestamp: DateTime.now());
          if (!_warningController.isClosed) _warningController.add(warning);
        }
      });
    } else if (newActivity == 'Lying') {
      _lyingTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
        if (_isDisposed || _currentActivityInternal != 'Lying') {
          timer.cancel();
          _lyingTimer = null;
          return;
        }
        _lyingDuration += const Duration(minutes: 10);
        if (kDebugMode)
          print(
              "[ARService] Lying duration: ${_lyingDuration.inHours}h ${_lyingDuration.inMinutes % 60}m. Warned: $_hasWarnedForCurrentLyingDaytime");
        final now = DateTime.now();
        bool isDaytime = now.hour >= AppConstants.daytimeStartHour &&
            now.hour < AppConstants.daytimeEndHour;

        if (!_hasWarnedForCurrentLyingDaytime &&
            isDaytime &&
            _lyingDuration >= _lyingDaytimeWarningThreshold) {
          final warning = ActivityWarning(
              type: ActivityWarningType.prolongedLyingDaytime,
              message:
                  "Bạn đã nằm khoảng ${_lyingDuration.inHours} giờ và ${_lyingDuration.inMinutes % 60} phút vào ban ngày. Hãy vận động nếu có thể.",
              timestamp: DateTime.now());
          if (!_warningController.isClosed) _warningController.add(warning);
          _lastWarningTypeSent = ActivityWarningType.prolongedLyingDaytime;
          _hasWarnedForCurrentLyingDaytime = true;
        }
      });
    }
    // Logic phản hồi tích cực đã được chuyển vào _addImuToBufferAndPredict
  }

  // Helper để lấy duration hiện tại của một hoạt động cụ thể
  Duration _getActivityDuration(String activity) {
    if (activity == 'Sitting') return _sittingDuration;
    if (activity == 'Lying') return _lyingDuration;
    return Duration.zero;
  }

  void _stopActivityTimers({
    bool preserveCurrentActivityDuration = false,
    bool resetSittingWarningFlag = true, // Mặc định là reset cờ khi dừng timer
    bool resetLyingWarningFlag = true,
  }) {
    _sittingTimer?.cancel();
    _sittingTimer = null;
    _lyingTimer?.cancel();
    _lyingTimer = null;

    if (!preserveCurrentActivityDuration) {
      _sittingDuration = Duration.zero;
      _lyingDuration = Duration.zero;
    }
    // Chỉ reset cờ nếu được yêu cầu (thường là khi hoạt động thay đổi, không phải khi restore)
    if (resetSittingWarningFlag) _hasWarnedForCurrentSitting = false;
    if (resetLyingWarningFlag) _hasWarnedForCurrentLyingDaytime = false;

    if (kDebugMode) {
      String log = "[ARService] Activity timers stopped.";
      if (!preserveCurrentActivityDuration) log += " Durations reset.";
      if (resetSittingWarningFlag && !preserveCurrentActivityDuration)
        log +=
            " Sitting warning flag reset."; // Chỉ log reset nếu duration cũng reset
      if (resetLyingWarningFlag && !preserveCurrentActivityDuration)
        log += " Lying warning flag reset.";
      print(log);
    }
  }

  Future<void> updateWarningSettings({
    Duration? newSittingThreshold,
    Duration? newLyingThreshold,
    bool? smartReminders,
  }) async {
    if (_isDisposed) return;
    bool changed = false;
    final prefs = await SharedPreferences.getInstance();

    if (newSittingThreshold != null &&
        newSittingThreshold != _sittingWarningThreshold) {
      _sittingWarningThreshold = newSittingThreshold;
      await prefs.setInt(AppConstants.prefKeySittingWarningMinutes,
          newSittingThreshold.inMinutes);
      changed = true;
    }
    // ... (tương tự cho lying và smartReminders)
    if (newLyingThreshold != null &&
        newLyingThreshold != _lyingDaytimeWarningThreshold) {
      _lyingDaytimeWarningThreshold = newLyingThreshold;
      await prefs.setInt(
          AppConstants.prefKeyLyingWarningHours, newLyingThreshold.inHours);
      changed = true;
    }
    if (smartReminders != null && smartReminders != _smartRemindersEnabled) {
      _smartRemindersEnabled = smartReminders;
      await prefs.setBool(
          AppConstants.prefKeySmartRemindersEnabled, smartReminders);
      changed = true;
    }

    if (changed) {
      if (kDebugMode)
        print(
            "[ARService] Warning settings updated and saved. SitThr: ${_sittingWarningThreshold.inMinutes}m, LieThr: ${_lyingDaytimeWarningThreshold.inHours}h, SmartRem: $_smartRemindersEnabled");
      // Nếu cài đặt thay đổi và có hoạt động đang được theo dõi, khởi động lại logic _handleActivityChange
      // để áp dụng ngưỡng mới ngay lập tức.
      if (_currentActivityInternal != "Initializing..." &&
          _currentActivityInternal != "Unknown") {
        _handleActivityChange(_currentActivityInternal,
            isInitialRestore:
                true); // Coi như restore để nó tính lại duration và áp dụng ngưỡng mới
      }
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (kDebugMode) print("[ARService] Disposing...");

    if (_currentActivityInternal != "Initializing..." &&
        _currentActivityInternal != "Unknown" &&
        _currentActivityStartTime != null) {
      _handleActivityEnd(_currentActivityInternal);
    }
    _stopActivityTimers(
        resetSittingWarningFlag: true,
        resetLyingWarningFlag: true); // Reset hết cờ khi dispose

    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close();

    if (!_activityPredictionController.isClosed)
      _activityPredictionController.close();
    if (!_warningController.isClosed) _warningController.close();

    _isHarModelLoaded = false;
    _imuDataBuffer.clear();
    if (kDebugMode) print("[ARService] Disposed.");
  }

  Future<void> prepareForLogout() async {
    if (kDebugMode) print("[ARService] Preparing for logout...");
    stopProcessingHealthData(); // Hàm này đã gọi _handleActivityEnd và _stopActivityTimers

    // Reset các trạng thái nội bộ liên quan đến hoạt động
    _currentActivityInternal = "Initializing..."; // Hoặc "Unknown"
    _currentActivityStartTime = null;
    if (!_activityPredictionController.isClosed &&
        _activityPredictionController.valueOrNull != _currentActivityInternal) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _imuDataBuffer.clear();
    _lastWarningTypeSent = null;
    _hasWarnedForCurrentSitting = false;
    _hasWarnedForCurrentLyingDaytime = false;

    // Xóa trạng thái đã lưu trong SharedPreferences nếu bạn muốn người dùng mới bắt đầu sạch
    // Hoặc giữ lại nếu bạn muốn khôi phục cho cùng người dùng đó nếu họ đăng nhập lại ngay.
    // Để đảm bảo "sạch" khi người dùng khác đăng nhập, nên xóa:
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.prefKeyLastKnownActivity);
      await prefs.remove(AppConstants.prefKeyLastKnownActivityTimestamp);
      if (kDebugMode)
        print(
            "[ARService] Cleared last known activity from SharedPreferences.");
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error clearing SharedPreferences on logout: $e");
    }
    if (kDebugMode) print("[ARService] State prepared for logout.");
  }
}
