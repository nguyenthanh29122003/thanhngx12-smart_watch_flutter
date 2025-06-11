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
  // --- TFLite & Scaler ---
  Interpreter? _harInterpreter;
  bool _isHarModelLoaded = false;
  List<int>? _harInputShape;
  List<int>? _harOutputShape;
  dynamic _harInputType;
  dynamic _harOutputType;
  List<double>? _scalerMeans;
  List<double>? _scalerStdDevs;

  // --- Buffers & Streams ---
  final List<List<double>> _imuDataBuffer = [];
  final BehaviorSubject<String> _activityPredictionController =
      BehaviorSubject<String>.seeded("Initializing...");
  final PublishSubject<ActivityWarning> _warningController =
      PublishSubject<ActivityWarning>();
  StreamSubscription? _healthDataSubscriptionForHar;

  Stream<String> get activityPredictionStream =>
      _activityPredictionController.stream;
  String? get currentActivityValue => _activityPredictionController.valueOrNull;
  Stream<ActivityWarning> get warningStream => _warningController.stream;

  // --- Dependencies ---
  final LocalDbService _localDbService = LocalDbService.instance;
  final AuthService _authService;

  // --- State Nội bộ ---
  String _currentActivityInternal = "Initializing...";
  DateTime? _currentActivityStartTime;
  bool _isDisposed = false;

  // --- State cho Cảnh báo Ngưỡng ---
  Timer? _sittingTimer;
  Timer? _lyingTimer;
  Duration _sittingDuration = Duration.zero;
  Duration _lyingDuration = Duration.zero;
  bool _hasWarnedForCurrentSitting = false;
  bool _hasWarnedForCurrentLyingDaytime = false;
  ActivityWarningType? _lastWarningTypeSent;
  Timer? _sittingWarningResetTimer;
  Timer? _lyingWarningResetTimer;

  // --- State cho Phân tích Định kỳ ---
  Timer? _periodicAnalysisTimer;

  ActivityRecognitionService({required AuthService authService})
      : _authService = authService {
    if (kDebugMode) print("[ARService] Initializing...");
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadResources();
  }

  Future<void> _loadResources() async {
    // Nếu service đã bị dispose, không làm gì cả
    if (_isDisposed) return;

    // Nếu các tài nguyên đã được tải, không cần tải lại
    if (_isHarModelLoaded &&
        _scalerMeans != null &&
        _scalerStdDevs != null &&
        _harInterpreter != null) {
      if (kDebugMode) print("[ARService] Resources already loaded.");

      // Đảm bảo trạng thái ban đầu được khôi phục nếu nó vẫn đang là "Initializing"
      if (_activityPredictionController.valueOrNull == "Initializing..." ||
          _activityPredictionController.valueOrNull == "Model Loading...") {
        await _restoreLastKnownActivity();
      }
      return;
    }

    if (kDebugMode)
      print("[ARService] Loading HAR TFLite model and Scaler params...");

    try {
      // Tải mô hình TFLite từ assets
      _harInterpreter = await Interpreter.fromAsset(TFLITE_MODEL_HAR_FILE);

      // Tải và parse file JSON chứa các tham số scaler
      final scalerJsonString = await rootBundle.loadString(SCALER_PARAMS_FILE);
      final scalerData = jsonDecode(scalerJsonString) as Map<String, dynamic>;

      // Chuyển đổi dữ liệu từ JSON thành List<double>
      _scalerMeans = (scalerData['mean'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();
      _scalerStdDevs = (scalerData['std_dev'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList();

      // Kiểm tra xem tất cả đã được tải thành công chưa
      if (_harInterpreter != null &&
          _scalerMeans != null &&
          _scalerStdDevs != null) {
        // Lấy thông tin chi tiết về input/output của model
        _harInputShape = _harInterpreter!.getInputTensor(0).shape;
        _harOutputShape = _harInterpreter!.getOutputTensor(0).shape;
        _harInputType = _harInterpreter!.getInputTensor(0).type;
        _harOutputType = _harInterpreter!.getOutputTensor(0).type;

        _isHarModelLoaded = true;

        if (kDebugMode) {
          print("[ARService] HAR Model and Scaler loaded successfully.");
          print("  - Model Input: $_harInputShape $_harInputType");
          print("  - Model Output: $_harOutputShape $_harOutputType");
        }

        // Sau khi tải model thành công, khôi phục lại hoạt động cuối cùng đã biết
        await _restoreLastKnownActivity();
      } else {
        // Ném lỗi nếu một trong các tài nguyên không tải được
        throw Exception(
            "HAR Interpreter or Scaler Params are null after loading.");
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error loading HAR TFLite model or scaler: $e");

      // Reset lại trạng thái nếu có lỗi
      _isHarModelLoaded = false;
      _harInterpreter?.close();
      _harInterpreter = null;
      _scalerMeans = null;
      _scalerStdDevs = null;

      // Thông báo lỗi qua stream để UI có thể biết
      if (!_activityPredictionController.isClosed) {
        _activityPredictionController.addError("Failed to load ML model");
      }
    }
  }

  void applySettings({
    required Duration sittingThreshold,
    required Duration lyingThreshold,
    required bool smartRemindersEnabled,
    required Duration minMovementDuration,
    required Duration periodicAnalysisInterval,
  }) {
    // Chỉ cập nhật và khởi động lại logic nếu có sự thay đổi
    bool settingsChanged = (_sittingWarningThreshold != sittingThreshold) ||
        (_lyingDaytimeWarningThreshold != lyingThreshold) ||
        (_smartRemindersEnabled != smartRemindersEnabled) ||
        (_minMovementToResetWarning != minMovementDuration) ||
        (_periodicAnalysisInterval != periodicAnalysisInterval);

    // Cập nhật các biến nội bộ của service
    _sittingWarningThreshold = sittingThreshold;
    _lyingDaytimeWarningThreshold = lyingThreshold;
    _smartRemindersEnabled = smartRemindersEnabled;
    _minMovementToResetWarning = minMovementDuration;
    _periodicAnalysisInterval = periodicAnalysisInterval;

    if (settingsChanged && !_isDisposed) {
      if (kDebugMode) {
        print(
            "[ARService applySettings] Settings changed. Re-evaluating current activity logic.");
        print("  - Sit Threshold: ${_sittingWarningThreshold.inMinutes} min");
        print("  - Lie Threshold: ${_lyingDaytimeWarningThreshold.inHours} hr");
        print("  - Smart Reminders: $_smartRemindersEnabled");
        print("  - Min Movement: ${_minMovementToResetWarning.inMinutes} min");
        print("  - Analysis Interval: ${_periodicAnalysisInterval.inHours} hr");
      }
      // Nếu có hoạt động đang diễn ra, hãy kích hoạt lại `_handleActivityChange`
      // để áp dụng ngay các ngưỡng mới cho các timer.
      if (_currentActivityInternal != "Initializing..." &&
          _currentActivityInternal != "Unknown") {
        _handleActivityChange(_currentActivityInternal, isInitialRestore: true);
      }
    }
  }

  Duration _sittingWarningThreshold =
      AppConstants.defaultSittingWarningThreshold;
  Duration _lyingDaytimeWarningThreshold =
      AppConstants.defaultLyingWarningDaytimeThreshold;
  bool _smartRemindersEnabled = AppConstants.defaultSmartRemindersEnabled;
  Duration _minMovementToResetWarning =
      AppConstants.minMovementDurationToResetWarning;
  Duration _periodicAnalysisInterval = AppConstants.periodicAnalysisInterval;

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
        _handleActivityChange(_currentActivityInternal,
            isInitialRestore: false);
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error restoring last known activity: $e");
    }
  }

  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (_isDisposed) return;
    if (!_isHarModelLoaded || _scalerMeans == null || _scalerStdDevs == null) {
      if (kDebugMode)
        print(
            "[ARService] Model/Scaler not ready. Attempting to load then start.");
      _loadResources().then((_) {
        if (!_isDisposed && _isHarModelLoaded) {
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
        healthData.gz
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

    _periodicAnalysisTimer?.cancel();
    _periodicAnalysisTimer =
        Timer.periodic(AppConstants.periodicAnalysisInterval, (_) {
      _runPeriodicAnalysis();
    });
    if (kDebugMode) print("[ARService] Periodic analysis timer started.");
  }

  void stopProcessingHealthData() {
    if (kDebugMode)
      print("[ARService] Stopping health data processing for HAR.");

    _healthDataSubscriptionForHar?.cancel();
    _healthDataSubscriptionForHar = null;

    _periodicAnalysisTimer?.cancel();
    _periodicAnalysisTimer = null;
    if (kDebugMode) print("[ARService] Periodic analysis timer stopped.");

    if (_currentActivityInternal != "Initializing..." &&
        _currentActivityInternal != "Unknown" &&
        _currentActivityStartTime != null) {
      _handleActivityEnd(_currentActivityInternal);
    }

    _manageTimersOnActivityChange(_currentActivityInternal, "Unknown");

    _currentActivityInternal = "Unknown";
    _currentActivityStartTime = null;
    if (!_isDisposed &&
        !_activityPredictionController.isClosed &&
        _activityPredictionController.valueOrNull != _currentActivityInternal) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _saveLastKnownActivity();
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
          final String oldActivity = _currentActivityInternal;
          if (predictedActivityName != oldActivity) {
            if (kDebugMode)
              print(
                  ">>> HAR New Activity: $predictedActivityName (Prob: ${maxProbability.toStringAsFixed(2)})");
            _handleActivityChange(predictedActivityName);
          }
        }
      } catch (e) {
        if (kDebugMode)
          print("!!! [ARService] Error running HAR TFLite model: $e");
        if (!_activityPredictionController.isClosed)
          _activityPredictionController.addError("HAR Inference Error");
      }

      if (_imuDataBuffer.length >= HAR_STEP_SIZE) {
        _imuDataBuffer.removeRange(0, HAR_STEP_SIZE);
      } else {
        _imuDataBuffer.clear();
      }
    }
  }

  void _handleActivityChange(String newActivity,
      {bool isInitialRestore = false}) {
    if (_isDisposed) return;

    final String oldActivity = _currentActivityInternal;

    if (oldActivity != "Initializing..." &&
        oldActivity != "Unknown" &&
        _currentActivityStartTime != null &&
        oldActivity != newActivity) {
      _handleActivityEnd(oldActivity);
    }

    _currentActivityInternal = newActivity;
    if (!isInitialRestore || _currentActivityStartTime == null) {
      _currentActivityStartTime = DateTime.now().toUtc();
    }

    _manageTimersOnActivityChange(oldActivity, newActivity,
        isInitialRestore: isInitialRestore);

    if (!_activityPredictionController.isClosed &&
        _activityPredictionController.valueOrNull != _currentActivityInternal) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _saveLastKnownActivity();

    _checkPositiveReinforcement(oldActivity, newActivity);
  }

  void _manageTimersOnActivityChange(String oldActivity, String newActivity,
      {bool isInitialRestore = false}) {
    // 1. Dọn dẹp các timer cũ
    _sittingTimer?.cancel();
    _lyingTimer?.cancel();
    _sittingTimer = null;
    _lyingTimer = null;

    // 2. Xử lý logic reset cờ cảnh báo khi người dùng vận động
    _handleWarningResetLogic(oldActivity, newActivity);

    // 3. Reset hoặc khôi phục thời gian tích lũy của hoạt động
    if (!isInitialRestore) {
      // Nếu là một sự thay đổi hoạt động bình thường, reset thời gian về 0
      _sittingDuration = Duration.zero;
      _lyingDuration = Duration.zero;
    } else if (_currentActivityStartTime != null) {
      // Nếu là khôi phục trạng thái (ví dụ: app khởi động lại), tính toán thời gian đã trôi qua
      final restoredDuration =
          DateTime.now().toUtc().difference(_currentActivityStartTime!);
      _sittingDuration =
          (newActivity == 'Sitting') ? restoredDuration : Duration.zero;
      _lyingDuration =
          (newActivity == 'Lying') ? restoredDuration : Duration.zero;
      if (kDebugMode)
        print(
            "[ARService] Restored duration for $newActivity: ${restoredDuration.inMinutes}min.");
    }

    // 4. Khởi động timer mới cho hoạt động hiện tại (nếu cần)
    if (newActivity == 'Sitting') {
      _startSittingTimer();
    } else if (newActivity == 'Lying') {
      _startLyingTimer();
    }
  }

  /// Helper function để xử lý logic reset cờ cảnh báo
  void _handleWarningResetLogic(String oldActivity, String newActivity) {
    final bool isMovingNow = (newActivity == 'Standing' ||
        newActivity == 'Walking' ||
        newActivity == 'Running');

    // Logic cho việc reset cảnh báo ngồi lâu
    if (oldActivity == 'Sitting' && isMovingNow) {
      if (_hasWarnedForCurrentSitting) {
        if (kDebugMode)
          print(
              "[ARService] User is moving after sitting warning. Starting cooldown timer to reset flag.");
        _sittingWarningResetTimer?.cancel();
        _sittingWarningResetTimer = Timer(_minMovementToResetWarning, () {
          if (kDebugMode)
            print(
                "[ARService] Cooldown period for sitting warning ended. Resetting flag.");
          _hasWarnedForCurrentSitting = false;
          _sittingWarningResetTimer = null;
        });
      }
    } else if (oldActivity != 'Sitting' || !isMovingNow) {
      // Nếu người dùng không còn vận động nữa (ví dụ: ngồi lại) trong khi đang trong thời gian cooldown
      if (_sittingWarningResetTimer != null) {
        if (kDebugMode)
          print(
              "[ARService] User stopped moving during sitting cooldown. Cancelling warning reset timer.");
        _sittingWarningResetTimer?.cancel();
        _sittingWarningResetTimer = null;
      }
    }

    // Logic cho việc reset cảnh báo nằm lâu (tương tự)
    if (oldActivity == 'Lying' && isMovingNow) {
      if (_hasWarnedForCurrentLyingDaytime) {
        if (kDebugMode)
          print(
              "[ARService] User is moving after lying warning. Starting cooldown timer to reset flag.");
        _lyingWarningResetTimer?.cancel();
        _lyingWarningResetTimer = Timer(_minMovementToResetWarning, () {
          if (kDebugMode)
            print(
                "[ARService] Cooldown period for lying warning ended. Resetting flag.");
          _hasWarnedForCurrentLyingDaytime = false;
          _lyingWarningResetTimer = null;
        });
      }
    } else if (oldActivity != 'Lying' || !isMovingNow) {
      if (_lyingWarningResetTimer != null) {
        if (kDebugMode)
          print(
              "[ARService] User stopped moving during lying cooldown. Cancelling warning reset timer.");
        _lyingWarningResetTimer?.cancel();
        _lyingWarningResetTimer = null;
      }
    }
  }

  /// Helper function để khởi động timer theo dõi việc ngồi
  void _startSittingTimer() {
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

      // Lấy đối tượng l10n để dịch (cần một cách để lấy context, sẽ thảo luận sau)
      // final l10n = AppLocalizations.of(context)!;

      // A. Kiểm tra cảnh báo chính (ngồi lâu)
      if (!_hasWarnedForCurrentSitting &&
          _sittingDuration >= _sittingWarningThreshold) {
        final warning = ActivityWarning(
            type: ActivityWarningType.prolongedSitting,
            // Ví dụ về cách dùng chuỗi đã dịch (cần cơ chế để lấy l10n)
            message:
                "Bạn đã ngồi ${_sittingDuration.inMinutes} phút. Hãy đứng dậy và vận động một chút!",
            timestamp: DateTime.now(),
            suggestedAction:
                "Đứng dậy, đi lại hoặc thực hiện vài động tác giãn cơ.");
        if (!_warningController.isClosed) _warningController.add(warning);
        _lastWarningTypeSent = ActivityWarningType.prolongedSitting;
        _hasWarnedForCurrentSitting = true;
      }
      // B. Kiểm tra nhắc nhở thông minh
      else if (_smartRemindersEnabled &&
          !_hasWarnedForCurrentSitting &&
          _sittingDuration.inMinutes > 0 &&
          _sittingDuration.inMinutes < _sittingWarningThreshold.inMinutes &&
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
  }

  /// Helper function để khởi động timer theo dõi việc nằm
  void _startLyingTimer() {
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

  void _checkPositiveReinforcement(String oldActivity, String newActivity) {
    bool isMovingNow = (newActivity == 'Standing' ||
        newActivity == 'Walking' ||
        newActivity == 'Running');
    if (_smartRemindersEnabled &&
        _lastWarningTypeSent == ActivityWarningType.prolongedSitting &&
        oldActivity == 'Sitting' &&
        isMovingNow) {
      final positiveWarning = ActivityWarning(
        type: ActivityWarningType.positiveReinforcement,
        message: "Tuyệt vời! Bạn đã đứng dậy và vận động sau khi ngồi lâu.",
        timestamp: DateTime.now(),
      );
      if (!_warningController.isClosed) _warningController.add(positiveWarning);
      _lastWarningTypeSent = null; // Reset
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
  }

  Future<void> _runPeriodicAnalysis() async {
    if (_isDisposed || _authService.currentUser == null) {
      if (kDebugMode)
        print(
            "[ARService] Skipping periodic analysis: Service disposed or user not logged in.");
      return;
    }

    final String currentUserId = _authService.currentUser!.uid;
    if (kDebugMode)
      print(
          "[ARService] Running periodic analysis for the last ${AppConstants.periodicAnalysisInterval.inHours} hour(s)...");

    final now = DateTime.now();
    final startTime = now.subtract(AppConstants.periodicAnalysisInterval);

    try {
      final segments = await _localDbService.getActivitySegmentsForDateRange(
          startTime, now,
          userId: currentUserId);

      if (segments.isEmpty) {
        if (kDebugMode)
          print(
              "[ARService] No activity segments found for periodic analysis.");
        return;
      }

      int totalSittingSeconds = 0;
      int totalMovementSeconds = 0;

      for (var segment in segments) {
        if (segment.activityName == 'Sitting') {
          totalSittingSeconds += segment.durationInSeconds;
        } else if (segment.activityName == 'Walking' ||
            segment.activityName == 'Running' ||
            segment.activityName == 'Standing') {
          totalMovementSeconds += segment.durationInSeconds;
        }
      }

      final int totalSittingMinutes = totalSittingSeconds ~/ 60;
      final int totalMovementMinutes = totalMovementSeconds ~/ 60;
      final int totalMinutes = AppConstants.periodicAnalysisInterval.inMinutes;

      if (kDebugMode)
        print(
            "[ARService] Analysis result: Sitting=${totalSittingMinutes}min, Movement=${totalMovementMinutes}min in a ${totalMinutes}min period.");

      if (totalSittingMinutes > totalMinutes * 0.75) {
        final warning = ActivityWarning(
          type: ActivityWarningType.smartReminderToMove,
          message:
              "Trong giờ qua, bạn đã ngồi khoảng $totalSittingMinutes phút. Hãy cố gắng vận động nhiều hơn trong giờ tới nhé!",
          timestamp: now,
        );
        if (!_warningController.isClosed) _warningController.add(warning);
      } else if (totalMovementMinutes > totalMinutes * 0.20) {
        final warning = ActivityWarning(
          type: ActivityWarningType.positiveReinforcement,
          message:
              "Làm tốt lắm! Bạn đã vận động khoảng $totalMovementMinutes phút trong giờ qua. Hãy tiếp tục duy trì nhé!",
          timestamp: now,
        );
        if (!_warningController.isClosed) _warningController.add(warning);
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error during periodic analysis: $e");
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
        await prefs.remove(AppConstants.prefKeyLastKnownActivityTimestamp);
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error saving last known activity: $e");
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
      if (_currentActivityInternal != "Initializing..." &&
          _currentActivityInternal != "Unknown") {
        _handleActivityChange(_currentActivityInternal, isInitialRestore: true);
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

    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close();

    _sittingTimer?.cancel();
    _lyingTimer?.cancel();
    _sittingWarningResetTimer?.cancel();
    _lyingWarningResetTimer?.cancel();
    _periodicAnalysisTimer?.cancel();

    if (!_activityPredictionController.isClosed)
      _activityPredictionController.close();
    if (!_warningController.isClosed) _warningController.close();

    _isHarModelLoaded = false;
    _imuDataBuffer.clear();
    if (kDebugMode) print("[ARService] Disposed.");
  }

  Future<void> prepareForLogout() async {
    if (kDebugMode) print("[ARService] Preparing for logout...");
    stopProcessingHealthData();

    _currentActivityInternal = "Initializing...";
    _currentActivityStartTime = null;
    if (!_activityPredictionController.isClosed &&
        _activityPredictionController.valueOrNull != _currentActivityInternal) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _imuDataBuffer.clear();
    _lastWarningTypeSent = null;
    _hasWarnedForCurrentSitting = false;
    _hasWarnedForCurrentLyingDaytime = false;

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
