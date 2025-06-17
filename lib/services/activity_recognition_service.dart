import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Cần cho Float32List
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import các file cần thiết trong dự án của bạn
import '../models/health_data.dart';
import '../models/activity_segment.dart';
import 'local_db_service.dart';
import 'auth_service.dart';
import '../app_constants.dart';

// ===================================================================
// HẰNG SỐ CỦA MÔ HÌNH
// ===================================================================
const String TFLITE_MODEL_HAR_FILE =
    'assets/ml_models/HAR_CNN_1D_Custom_best_val_accuracy_float32_V2.tflite'; // Cập nhật tên file mô hình float32
const String SCALER_PARAMS_FILE = 'assets/ml_models/scaler_params.json';

const int HAR_WINDOW_SIZE = 20;
const int HAR_NUM_FEATURES = 6;
const int HAR_STEP_SIZE = 10;
const int HAR_SAMPLING_FREQUENCY_HZ = 1;
const int HAR_NUM_CLASSES = 5;

const Map<int, String> HAR_ACTIVITY_LABELS = {
  0: 'Standing',
  1: 'Lying',
  2: 'Sitting',
  3: 'Walking',
  4: 'Running',
};

// ===================================================================
// ENUM VÀ CLASS CHO CẢNH BÁO
// ===================================================================
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

  ActivityWarning(
      {required this.type,
      required this.message,
      required this.timestamp,
      this.suggestedAction});

  @override
  String toString() {
    return 'ActivityWarning(type: $type, message: "$message", timestamp: $timestamp, suggestion: "$suggestedAction")';
  }
}

// ===================================================================
// ĐỊNH NGHĨA SERVICE
// ===================================================================
class ActivityRecognitionService {
  // --- TFLite & Scaler ---
  Interpreter? _harInterpreter;
  bool _isHarModelLoaded = false;
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

  // --- State Nội bộ & Cảnh báo ---
  String _currentActivityInternal = "Initializing...";
  DateTime? _currentActivityStartTime;
  bool _isDisposed = false;
  Timer? _sittingTimer;
  Timer? _lyingTimer;
  Duration _sittingDuration = Duration.zero;
  Duration _lyingDuration = Duration.zero;
  bool _hasWarnedForCurrentSitting = false;
  bool _hasWarnedForCurrentLyingDaytime = false;
  ActivityWarningType? _lastWarningTypeSent;
  Timer? _sittingWarningResetTimer;
  Timer? _lyingWarningResetTimer;
  Timer? _periodicAnalysisTimer;

  // Các biến cấu hình
  Duration _sittingWarningThreshold =
      AppConstants.defaultSittingWarningThreshold;
  Duration _lyingDaytimeWarningThreshold =
      AppConstants.defaultLyingWarningDaytimeThreshold;
  bool _smartRemindersEnabled = AppConstants.defaultSmartRemindersEnabled;
  Duration _minMovementToResetWarning =
      AppConstants.minMovementDurationToResetWarning;
  Duration _periodicAnalysisInterval = AppConstants.periodicAnalysisInterval;

  // --- Singleton Pattern ---
  static final ActivityRecognitionService _instance =
      ActivityRecognitionService._internal(authService: AuthService());
  factory ActivityRecognitionService({required AuthService authService}) =>
      _instance;
  ActivityRecognitionService._internal({required AuthService authService})
      : _authService = authService {
    if (kDebugMode) print("[ARService] Singleton Initializing...");
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadResources();
  }

  Future<void> _loadResources() async {
    if (_isDisposed || _isHarModelLoaded) return;

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
        _isHarModelLoaded = true;

        if (kDebugMode) {
          print("[ARService] Float32 Model and Scaler loaded successfully.");
        }
        await _restoreLastKnownActivity();
      } else {
        throw Exception("Interpreter or Scaler Params are null after loading.");
      }
    } catch (e) {
      if (kDebugMode) print("!!! [ARService] Error loading resources: $e");
      _isHarModelLoaded = false;
      if (!_activityPredictionController.isClosed) {
        _activityPredictionController.addError("Failed to load ML model");
      }
    }
  }

  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (_isDisposed || !_isHarModelLoaded) {
      if (kDebugMode) print("[ARService] Model not ready. Retrying load...");
      _loadResources().then((_) {
        if (!_isDisposed && _isHarModelLoaded) {
          startProcessingHealthData(healthDataStream);
        }
      });
      return;
    }

    _healthDataSubscriptionForHar?.cancel();
    if (kDebugMode) {
      print(
          "[ARService] Subscribing to health data stream with 1Hz throttling...");
    }

    _healthDataSubscriptionForHar = healthDataStream
        .throttleTime(
      const Duration(milliseconds: 1000 ~/ HAR_SAMPLING_FREQUENCY_HZ),
      trailing: true,
    )
        .listen((event) {
      if (event is HealthData) {
        if (_isDisposed) return;
        final List<double> imuSample = [
          event.ax,
          event.ay,
          event.az,
          event.gx,
          event.gy,
          event.gz,
        ].cast<double>();
        _processImuSample(imuSample);
      }
    }, onError: (error) {
      if (kDebugMode) {
        print("!!! [ARService] Error on health data stream: $error");
      }
    });

    _periodicAnalysisTimer?.cancel();
    _periodicAnalysisTimer = Timer.periodic(
        _periodicAnalysisInterval, (_) => _runPeriodicAnalysis());
  }

  void _processImuSample(List<double> imuSample) {
    if (_isDisposed ||
        !_isHarModelLoaded ||
        imuSample.length != HAR_NUM_FEATURES) {
      if (kDebugMode) {
        print(
            "[ARService] Invalid sample: length=${imuSample.length}, expected=$HAR_NUM_FEATURES");
      }
      return;
    }

    if (!imuSample.every((element) => element is double && element.isFinite)) {
      if (kDebugMode) {
        print(
            "[ARService] Invalid sample: contains non-double or non-finite values: $imuSample");
      }
      return;
    }

    _imuDataBuffer.add(imuSample);

    while (_imuDataBuffer.length > HAR_WINDOW_SIZE) {
      _imuDataBuffer.removeAt(0);
    }

    if (kDebugMode) {
      print(
          "[ARService] Filling buffer: ${_imuDataBuffer.length}/$HAR_WINDOW_SIZE");
    }

    if (_imuDataBuffer.length == HAR_WINDOW_SIZE) {
      if (kDebugMode) {
        print(">>> Buffer is full. Running inference on current window.");
      }
      final List<List<double>> windowData =
          _imuDataBuffer.map((sample) => List<double>.from(sample)).toList();
      _runInferenceOnWindow(windowData);
    }
  }

  void _runInferenceOnWindow(List<List<double>> windowData) {
    if (_harInterpreter == null ||
        _scalerMeans == null ||
        _scalerStdDevs == null) {
      if (kDebugMode)
        print("[ARService] Inference skipped: resources not ready.");
      return;
    }

    // --- BƯỚC 1: CHUẨN HÓA ĐẦU VÀO ---
    // Tạo một Float32List phẳng trước
    var flatInput = Float32List(HAR_WINDOW_SIZE * HAR_NUM_FEATURES);
    int index = 0;
    for (int i = 0; i < HAR_WINDOW_SIZE; i++) {
      for (int j = 0; j < HAR_NUM_FEATURES; j++) {
        double stdDev =
            _scalerStdDevs![j].abs() < 1e-9 ? 1.0 : _scalerStdDevs![j];
        flatInput[index++] =
            ((windowData[i][j] - _scalerMeans![j]) / stdDev).toDouble();
      }
    }

    // Reshape thành hình dạng [1, 20, 6]
    var inputTensor = flatInput.reshape([1, HAR_WINDOW_SIZE, HAR_NUM_FEATURES]);

    // --- BƯỚC 2: CHUẨN BỊ TENSOR ĐẦU RA ---
    var flatOutputTensor = Float32List(1 * HAR_NUM_CLASSES);
    var outputTensor = flatOutputTensor.reshape([1, HAR_NUM_CLASSES]);

    // --- BƯỚC 3: CHẠY DỰ ĐOÁN (INFERENCE) ---
    try {
      _harInterpreter!.run(inputTensor, outputTensor);
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error running Float32 model inference: $e");
      return;
    }

    // --- BƯỚC 4: XỬ LÝ ĐẦU RA ---
    List<double> probabilities = outputTensor[0].toList();

    // Debug log
    if (kDebugMode) {
      print("--- Running Float32 Inference (SUCCESS) ---");
      final probString =
          probabilities.map((p) => p.toStringAsFixed(3)).toList();
      print("Output Probabilities: $probString");
    }

    // --- BƯỚC 5: XỬ LÝ KẾT QUẢ ---
    int predictedIndex = 0;
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
      if (predictedActivityName != _currentActivityInternal) {
        _handleActivityChange(predictedActivityName);
      }
    }
  }

  Future<void> _restoreLastKnownActivity() async {
    if (_isDisposed || !_isHarModelLoaded) {
      if (kDebugMode)
        print("[ARService] Conditions not met for restoring last activity.");
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
          lastActivity != "Initializing...") {
        _currentActivityInternal = lastActivity;
        _currentActivityStartTime = (lastActivityTimeStr != null)
            ? DateTime.tryParse(lastActivityTimeStr)?.toUtc()
            : DateTime.now().toUtc();

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
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error restoring last known activity: $e");
    }
  }

  void stopProcessingHealthData() {
    if (kDebugMode)
      print("[ARService] Stopping health data processing for HAR.");
    _healthDataSubscriptionForHar?.cancel();
    _periodicAnalysisTimer?.cancel();

    if (_currentActivityInternal != "Initializing..." &&
        _currentActivityStartTime != null) {
      _handleActivityEnd(_currentActivityInternal);
    }

    _manageTimersOnActivityChange(_currentActivityInternal, "Unknown");

    _currentActivityInternal = "Unknown";
    _currentActivityStartTime = null;
    if (!_isDisposed && !_activityPredictionController.isClosed) {
      _activityPredictionController.add(_currentActivityInternal);
    }
    _saveLastKnownActivity();
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
    _sittingTimer?.cancel();
    _lyingTimer?.cancel();

    _handleWarningResetLogic(oldActivity, newActivity);

    if (newActivity != oldActivity || isInitialRestore) {
      if (kDebugMode)
        print("[ARService] Activity changed or restored. Resetting durations.");
      _sittingDuration = Duration.zero;
      _lyingDuration = Duration.zero;

      // <<< SỬA LỖI LOGIC: Khi chuyển hoạt động, cờ cảnh báo của hoạt động mới phải được reset >>>
      if (newActivity == 'Sitting') {
        _hasWarnedForCurrentSitting = false;
      }
      if (newActivity == 'Lying') {
        _hasWarnedForCurrentLyingDaytime = false;
      }
    }

    if (isInitialRestore && _currentActivityStartTime != null) {
      final restoredDuration =
          DateTime.now().toUtc().difference(_currentActivityStartTime!);
      if (newActivity == 'Sitting') _sittingDuration = restoredDuration;
      if (newActivity == 'Lying') _lyingDuration = restoredDuration;
    }

    if (newActivity == 'Sitting') _startSittingTimer();
    if (newActivity == 'Lying') _startLyingTimer();
  }

  void _handleWarningResetLogic(String oldActivity, String newActivity) {
    final bool isMovingNow = (newActivity == 'Walking' ||
        newActivity == 'Running' ||
        newActivity == 'Standing');

    // <<< SỬA LỖI LOGIC: Chỉ khởi động timer reset khi người dùng CHUYỂN từ trạng thái tĩnh sang vận động >>>
    if ((oldActivity == 'Sitting' || oldActivity == 'Lying') && isMovingNow) {
      if (_hasWarnedForCurrentSitting) {
        if (kDebugMode)
          print(
              "[ARService] User is moving after sitting warning. Starting cooldown to reset flag.");
        _sittingWarningResetTimer?.cancel();
        _sittingWarningResetTimer = Timer(_minMovementToResetWarning, () {
          if (kDebugMode)
            print("[ARService] Cooldown for sitting ended. Resetting flag.");
          _hasWarnedForCurrentSitting = false;
          _sittingWarningResetTimer = null;
        });
      }
      if (_hasWarnedForCurrentLyingDaytime) {
        if (kDebugMode)
          print(
              "[ARService] User is moving after lying warning. Starting cooldown to reset flag.");
        _lyingWarningResetTimer?.cancel();
        _lyingWarningResetTimer = Timer(_minMovementToResetWarning, () {
          if (kDebugMode)
            print("[ARService] Cooldown for lying ended. Resetting flag.");
          _hasWarnedForCurrentLyingDaytime = false;
          _lyingWarningResetTimer = null;
        });
      }
    }
    // <<< SỬA LỖI LOGIC: Nếu người dùng dừng vận động, hủy ngay timer reset >>>
    else if (!isMovingNow) {
      _sittingWarningResetTimer?.cancel();
      _lyingWarningResetTimer?.cancel();
      _sittingWarningResetTimer = null;
      _lyingWarningResetTimer = null;
    }
  }

  void _startSittingTimer() {
    _sittingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isDisposed || _currentActivityInternal != 'Sitting') {
        timer.cancel();
        return;
      }
      _sittingDuration += const Duration(minutes: 1);
      if (!_hasWarnedForCurrentSitting &&
          _sittingDuration >= _sittingWarningThreshold) {
        _warningController.add(ActivityWarning(
            type: ActivityWarningType.prolongedSitting,
            message:
                "Bạn đã ngồi ${_sittingDuration.inMinutes} phút. Hãy vận động!",
            timestamp: DateTime.now()));
        _hasWarnedForCurrentSitting = true;
        _lastWarningTypeSent = ActivityWarningType.prolongedSitting;
      }
    });
  }

  void _startLyingTimer() {
    _lyingTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (_isDisposed || _currentActivityInternal != 'Lying') {
        timer.cancel();
        return;
      }
      _lyingDuration += const Duration(minutes: 10);
      final now = DateTime.now();
      bool isDaytime = now.hour >= AppConstants.daytimeStartHour &&
          now.hour < AppConstants.daytimeEndHour;

      if (!_hasWarnedForCurrentLyingDaytime &&
          isDaytime &&
          _lyingDuration >= _lyingDaytimeWarningThreshold) {
        _warningController.add(ActivityWarning(
            type: ActivityWarningType.prolongedLyingDaytime,
            message:
                "Bạn đã nằm khoảng ${_lyingDuration.inHours} giờ ban ngày. Hãy vận động nếu có thể.",
            timestamp: now));
        _hasWarnedForCurrentLyingDaytime = true;
        _lastWarningTypeSent = ActivityWarningType.prolongedLyingDaytime;
      }
    });
  }

  void _checkPositiveReinforcement(String oldActivity, String newActivity) {
    bool isMovingNow = (newActivity == 'Walking' ||
        newActivity == 'Running' ||
        newActivity == 'Standing');
    if (_smartRemindersEnabled && _lastWarningTypeSent != null && isMovingNow) {
      _warningController.add(ActivityWarning(
        type: ActivityWarningType.positiveReinforcement,
        message: "Tuyệt vời! Bạn đã vận động trở lại.",
        timestamp: DateTime.now(),
      ));
      _lastWarningTypeSent = null;
    }
  }

  Future<void> _handleActivityEnd(String endedActivity) async {
    if (_isDisposed ||
        _currentActivityStartTime == null ||
        endedActivity == "Unknown") return;
    final endTime = DateTime.now().toUtc();
    final duration = endTime.difference(_currentActivityStartTime!);

    if (duration.inSeconds < AppConstants.minActivityDurationToLogSeconds)
      return;

    final segment = ActivitySegment(
      activityName: endedActivity,
      startTime: _currentActivityStartTime!,
      endTime: endTime,
      durationInSeconds: duration.inSeconds,
      userId: _authService.currentUser?.uid,
      isSynced: false,
    );
    await _localDbService.insertActivitySegment(segment);
  }

  Future<void> _runPeriodicAnalysis() async {
    if (_isDisposed || _authService.currentUser == null) {
      if (kDebugMode) {
        print(
            "[ARService] Skipping periodic analysis: Service disposed or user not logged in.");
      }
      return;
    }

    // Chỉ chạy phân tích nếu người dùng bật nhắc nhở thông minh
    if (!_smartRemindersEnabled) {
      if (kDebugMode)
        print(
            "[ARService] Skipping periodic analysis: Smart reminders are disabled.");
      return;
    }

    final String currentUserId = _authService.currentUser!.uid;
    final now = DateTime.now().toUtc();
    final startTime = now.subtract(_periodicAnalysisInterval);

    if (kDebugMode) {
      print(
          "[ARService] Running periodic analysis for the last ${_periodicAnalysisInterval.inHours} hour(s)...");
    }

    try {
      // Lấy các phân đoạn hoạt động trong khoảng thời gian phân tích
      final segments = await _localDbService.getActivitySegmentsForDateRange(
        startTime,
        now,
        userId: currentUserId,
      );

      if (segments.isEmpty) {
        if (kDebugMode)
          print(
              "[ARService] No activity segments found for periodic analysis.");
        // Nếu không có hoạt động nào được ghi lại, có thể người dùng đang ở trạng thái tĩnh
        // Kiểm tra hoạt động hiện tại để đưa ra nhắc nhở nếu cần
        if (_currentActivityInternal == 'Sitting' ||
            _currentActivityInternal == 'Lying') {
          final warning = ActivityWarning(
            type: ActivityWarningType.smartReminderToMove,
            message:
                "Có vẻ như bạn đã không vận động trong một khoảng thời gian. Hãy đứng dậy và đi lại một chút nhé!",
            timestamp: now,
          );
          if (!_warningController.isClosed) _warningController.add(warning);
        }
        return;
      }

      int totalSittingSeconds = 0;
      int totalLyingSeconds = 0;
      int totalMovementSeconds = 0;

      for (var segment in segments) {
        switch (segment.activityName) {
          case 'Sitting':
            totalSittingSeconds += segment.durationInSeconds;
            break;
          case 'Lying':
            totalLyingSeconds += segment.durationInSeconds;
            break;
          case 'Walking':
          case 'Running':
          case 'Standing':
            totalMovementSeconds += segment.durationInSeconds;
            break;
        }
      }

      // Thêm thời gian của hoạt động hiện tại nếu nó là tĩnh
      if (_currentActivityInternal == 'Sitting' &&
          _currentActivityStartTime != null) {
        totalSittingSeconds +=
            now.difference(_currentActivityStartTime!).inSeconds;
      } else if (_currentActivityInternal == 'Lying' &&
          _currentActivityStartTime != null) {
        totalLyingSeconds +=
            now.difference(_currentActivityStartTime!).inSeconds;
      }

      final int totalSittingMinutes = totalSittingSeconds ~/ 60;
      final int totalMovementMinutes = totalMovementSeconds ~/ 60;
      final int totalMinutesInInterval = _periodicAnalysisInterval.inMinutes;

      if (kDebugMode) {
        print(
            "[ARService] Analysis result: Sitting=${totalSittingMinutes}min, Movement=${totalMovementMinutes}min in a ${totalMinutesInInterval}min period.");
      }

      // Đưa ra nhắc nhở nếu thời gian ngồi quá nhiều
      if (totalSittingMinutes > totalMinutesInInterval * 0.75) {
        // Ví dụ: ngồi hơn 75% thời gian
        final warning = ActivityWarning(
          type: ActivityWarningType.smartReminderToMove,
          message:
              "Trong giờ qua, bạn đã ngồi khoảng $totalSittingMinutes phút. Hãy cố gắng vận động nhiều hơn trong giờ tới nhé!",
          timestamp: now,
        );
        if (!_warningController.isClosed) _warningController.add(warning);
      }
      // Khen ngợi nếu người dùng vận động đủ nhiều
      else if (totalMovementMinutes > totalMinutesInInterval * 0.20) {
        // Ví dụ: vận động hơn 20% thời gian
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AppConstants.prefKeyLastKnownActivity, _currentActivityInternal);
    if (_currentActivityStartTime != null) {
      await prefs.setString(AppConstants.prefKeyLastKnownActivityTimestamp,
          _currentActivityStartTime!.toIso8601String());
    }
  }

  void applySettings({
    // Logic này giữ nguyên như code của bạn
    required Duration sittingThreshold,
    required Duration lyingThreshold,
    required bool smartRemindersEnabled,
    required Duration minMovementDuration,
    required Duration periodicAnalysisInterval,
  }) {
    _sittingWarningThreshold = sittingThreshold;
    _lyingDaytimeWarningThreshold = lyingThreshold;
    _smartRemindersEnabled = smartRemindersEnabled;
    _minMovementToResetWarning = minMovementDuration;
    _periodicAnalysisInterval = periodicAnalysisInterval;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close();
    _sittingTimer?.cancel();
    _lyingTimer?.cancel();
    _sittingWarningResetTimer?.cancel();
    _lyingWarningResetTimer?.cancel();
    _periodicAnalysisTimer?.cancel();
    _activityPredictionController.close();
    _warningController.close();
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
