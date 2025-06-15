// lib/services/activity_recognition_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data'; // Cần cho Int8List
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
// HẰNG SỐ CỦA MÔ HÌNH (Lấy từ Notebook)
// ===================================================================
const String TFLITE_MODEL_HAR_FILE =
    'assets/ml_models/HAR_CNN_1D_Custom_best_val_accuracy_int8.tflite';
const String SCALER_PARAMS_FILE = 'assets/ml_models/scaler_params.json';

const int HAR_WINDOW_SIZE = 20;
const int HAR_NUM_FEATURES = 6;
const int HAR_STEP_SIZE = 10; // Cửa sổ trượt đi 10 mẫu (overlap 50%)
const int HAR_SAMPLING_FREQUENCY_HZ = 1; // 1 Hz
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
  QuantizationParams? _inputQuantizationParams;
  QuantizationParams? _outputQuantizationParams;
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

  // Các biến cấu hình (sẽ được cập nhật bởi applySettings)
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
        // <<< SỬA LỖI Ở ĐÂY: Thêm (event) {} để Dart hiểu kiểu dữ liệu >>>
        .listen((event) {
      // Biến event ở đây có thể là dynamic, chúng ta cần đảm bảo nó là HealthData
      // Mặc dù trong trường hợp này, trình phân tích của Dart thường đủ thông minh,
      // nhưng để chắc chắn, ta có thể kiểm tra kiểu.
      if (event is HealthData) {
        if (_isDisposed) return;
        _processImuSample(
            [event.ax, event.ay, event.az, event.gx, event.gy, event.gz]);
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

  // void _processImuSample(List<double> imuSample) {
  //   // Thêm mẫu mới vào buffer
  //   _imuDataBuffer.add(imuSample);

  //   // Nếu buffer có nhiều hơn số mẫu cần thiết cho 1 cửa sổ,
  //   // xóa bớt mẫu cũ nhất đi để đảm bảo cửa sổ luôn "trượt" về phía trước.
  //   while (_imuDataBuffer.length > HAR_WINDOW_SIZE) {
  //     _imuDataBuffer.removeAt(0);
  //   }

  //   // Chỉ khi buffer có chính xác số lượng mẫu cần thiết (20), thì mới chạy dự đoán.
  //   // Điều này đảm bảo rằng mỗi lần dự đoán đều dựa trên một cửa sổ dữ liệu hoàn chỉnh.
  //   if (_imuDataBuffer.length == HAR_WINDOW_SIZE) {
  //     // In log để xác nhận buffer đã đầy và inference sắp được gọi
  //     if (kDebugMode) {
  //       print(
  //           "[ARService] Buffer is full (${_imuDataBuffer.length}/$HAR_WINDOW_SIZE). Running inference...");
  //     }
  //     _runInferenceOnWindow(List.from(_imuDataBuffer)); // Chạy trên một bản sao
  //   } else {
  //     // In log để biết buffer đang được lấp đầy, giúp gỡ lỗi
  //     if (kDebugMode) {
  //       print(
  //           "[ARService] Filling buffer: ${_imuDataBuffer.length}/$HAR_WINDOW_SIZE");
  //     }
  //   }
  // }

  void _processImuSample(List<double> imuSample) {
    if (_isDisposed ||
        !_isHarModelLoaded ||
        imuSample.length != HAR_NUM_FEATURES) {
      return;
    }

    _imuDataBuffer.add(imuSample);

    // LOGIC CỬA SỔ TRƯỢT ĐÚNG: Luôn giữ buffer có kích thước tối đa là WINDOW_SIZE
    while (_imuDataBuffer.length > HAR_WINDOW_SIZE) {
      _imuDataBuffer.removeAt(0); // Xóa mẫu cũ nhất
    }

    // In log để theo dõi
    if (kDebugMode) {
      print(
          "[ARService] Filling buffer: ${_imuDataBuffer.length}/$HAR_WINDOW_SIZE");
    }

    // Chỉ khi buffer ĐỦ 20 MẪU, mới chạy dự đoán.
    if (_imuDataBuffer.length == HAR_WINDOW_SIZE) {
      if (kDebugMode) {
        print(">>> Buffer is full. Running inference on current window.");
      }
      // Tạo bản sao với kiểu dữ liệu tường minh để tránh lỗi
      final List<List<double>> windowData =
          _imuDataBuffer.map((sample) => List<double>.from(sample)).toList();

      _runInferenceOnWindow(windowData);
    }
  }

  void _runInferenceOnWindow(List<List<double>> windowData) {
    if (_harInterpreter == null ||
        _scalerMeans == null ||
        _scalerStdDevs == null ||
        _inputQuantizationParams == null ||
        _outputQuantizationParams == null) {
      if (kDebugMode)
        print("[ARService] Inference skipped: resources not ready.");
      return;
    }

    // --- BƯỚC 1 & 2: CHUẨN BỊ, SCALE VÀ LƯỢNG TỬ HÓA ĐẦU VÀO ---
    final inputScale = _inputQuantizationParams!.scale;
    final inputZeroPoint = _inputQuantizationParams!.zeroPoint;

    // Tạo một list 2D phẳng trước
    var flatQuantizedInput = Int8List(HAR_WINDOW_SIZE * HAR_NUM_FEATURES);
    int index = 0;
    for (int i = 0; i < HAR_WINDOW_SIZE; i++) {
      for (int j = 0; j < HAR_NUM_FEATURES; j++) {
        double stdDev =
            _scalerStdDevs![j].abs() < 1e-9 ? 1.0 : _scalerStdDevs![j];
        final scaledValue = (windowData[i][j] - _scalerMeans![j]) / stdDev;
        flatQuantizedInput[index++] =
            (scaledValue / inputScale + inputZeroPoint).round();
      }
    }

    // <<< SỬA LỖI QUAN TRỌNG: Reshape thành đúng hình dạng [1, 20, 6] >>>
    // TFLite interpreter rất nhạy cảm với hình dạng và kiểu dữ liệu.
    var inputTensor =
        flatQuantizedInput.reshape([1, HAR_WINDOW_SIZE, HAR_NUM_FEATURES]);

    // --- BƯỚC 3: CHUẨN BỊ TENSOR ĐẦU RA ---
    // Tạo một list 2D phẳng
    var flatOutputTensor = Int8List(1 * HAR_NUM_CLASSES);
    // Reshape nó thành hình dạng mà interpreter mong đợi
    var outputTensor = flatOutputTensor.reshape([1, HAR_NUM_CLASSES]);

    // --- BƯỚC 4: CHẠY DỰ ĐOÁN (INFERENCE) ---
    try {
      _harInterpreter!.run(inputTensor, outputTensor);
    } catch (e) {
      if (kDebugMode)
        print("!!! [ARService] Error running INT8 model inference: $e");
      return;
    }

    // --- BƯỚC 5: GIẢI LƯỢNG TỬ HÓA ĐẦU RA ---
    final outputScale = _outputQuantizationParams!.scale;
    final outputZeroPoint = _outputQuantizationParams!.zeroPoint;

    // Lấy dòng đầu tiên của outputTensor (vì batch size là 1)
    List<double> probabilities = outputTensor[0].map((quantizedValue) {
      return (quantizedValue - outputZeroPoint) * outputScale;
    }).toList();

    // Debug log
    if (kDebugMode) {
      print("--- Running INT8 Inference (SUCCESS) ---");
      final probString =
          probabilities.map((p) => p.toStringAsFixed(3)).toList();
      print("Dequantized Output Probabilities: $probString");
    }

    // --- BƯỚC 6: XỬ LÝ KẾT QUẢ ---
    // ... (logic tìm max probability và gọi _handleActivityChange giữ nguyên) ...
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
        // Lấy và lưu tham số lượng tử hóa cho mô hình INT8
        _inputQuantizationParams = _harInterpreter!.getInputTensor(0).params;
        _outputQuantizationParams = _harInterpreter!.getOutputTensor(0).params;

        _isHarModelLoaded = true;

        if (kDebugMode) {
          print("[ARService] INT8 Model and Scaler loaded successfully.");
          print(
              "  - Input Quantization: scale=${_inputQuantizationParams?.scale}, zeroPoint=${_inputQuantizationParams?.zeroPoint}");
          print(
              "  - Output Quantization: scale=${_outputQuantizationParams?.scale}, zeroPoint=${_outputQuantizationParams?.zeroPoint}");
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

  // ===================================================================
  // LOGIC XỬ LÝ DỮ LIỆU VÀ DỰ ĐOÁN
  // ===================================================================
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

  // ===================================================================
  // LOGIC XỬ LÝ THAY ĐỔI HOẠT ĐỘNG VÀ CẢNH BÁO
  // ===================================================================

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

  // ===================================================================
  // LƯU TRỮ DỮ LIỆU VÀ QUẢN LÝ VÒNG ĐỜI
  // ===================================================================

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
    // Logic này giữ nguyên như code của bạn
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
    stopProcessingHealthData();
    // Logic còn lại giữ nguyên
  }
}
