// lib/services/activity_recognition_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:rxdart/rxdart.dart'; // <<< THÊM IMPORT NÀY

import '../models/health_data.dart'; // Điều chỉnh đường dẫn nếu cần

// --- CÁC HẰNG SỐ CHO MODEL HAR MỚI CỦA BẠN (TỪ COLAB) ---
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
// -------------------------------------------------------------------

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

  // SỬA ĐỔI: Dùng BehaviorSubject
  // Khởi tạo với một giá trị mặc định nếu muốn, ví dụ "Đang khởi tạo..."
  // Hoặc để nó bắt đầu mà không có giá trị ban đầu, StreamBuilder sẽ dùng initialData của nó.
  final BehaviorSubject<String> _activityPredictionController = BehaviorSubject<
      String>(); // Có thể .seeded("Đang khởi tạo...") nếu muốn có giá trị ban đầu ngay
  Stream<String> get activityPredictionStream =>
      _activityPredictionController.stream;
  // Để truy cập giá trị hiện tại của BehaviorSubject (nếu cần từ bên ngoài stream)
  String? get currentActivityValue => _activityPredictionController.valueOrNull;

  StreamSubscription? _healthDataSubscriptionForHar;
  String? _currentPredictedActivityInternal; // Đổi tên để phân biệt với getter
  Timer? _sittingTimer;
  Timer? _lyingTimer;
  Duration _sittingDuration = Duration.zero;
  Duration _lyingDuration = Duration.zero;

  final Duration _sittingWarningThreshold = const Duration(minutes: 60);
  final Duration _lyingWarningDaytimeThreshold = const Duration(hours: 2);

  final StreamController<String> _warningController =
      StreamController<String>.broadcast();
  Stream<String> get warningStream => _warningController.stream;

  ActivityRecognitionService() {
    if (kDebugMode) {
      print("[ARService] Initializing...");
    }
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadResources();
  }

  Future<void> _loadResources() async {
    // Thêm kiểm tra để tránh load lại không cần thiết nếu đã có giá trị
    if (_isHarModelLoaded &&
        _scalerMeans != null &&
        _scalerStdDevs != null &&
        _harInterpreter != null) {
      if (kDebugMode) print("[ARService] Resources already loaded.");
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

        // ... (Log debug và kiểm tra shape/type giữ nguyên) ...
        if (kDebugMode) {
          print('---------------------------------------------------');
          print('[ARService] HAR TFLite Model Loaded:');
          print(
              '  Input Shape: $_harInputShape, Type: $_harInputType (Runtime type: ${_harInputType.runtimeType})');
          print(
              '  Output Shape: $_harOutputShape, Type: $_harOutputType (Runtime type: ${_harOutputType.runtimeType})');
          print('[ARService] Scaler Params Loaded:');
          print('  Means (count: ${_scalerMeans!.length}): $_scalerMeans');
          print(
              '  StdDevs (count: ${_scalerStdDevs!.length}): $_scalerStdDevs');
          print('---------------------------------------------------');
        }
        if (!(_harInputShape != null &&
            _harInputShape!.length == 3 &&
            _harInputShape![0] == 1 &&
            _harInputShape![1] == HAR_WINDOW_SIZE &&
            _harInputShape![2] == HAR_NUM_FEATURES)) {
          final errorMsg =
              "HAR Model input shape mismatch! Expected [1, $HAR_WINDOW_SIZE, $HAR_NUM_FEATURES], Got $_harInputShape";
          if (kDebugMode) print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        if (_harInputType != TfLiteType.kTfLiteFloat32) {
          // Sử dụng kTfLiteFloat32
          final errorMsg =
              "HAR Model input type mismatch! Expected TfLiteType.kTfLiteFloat32, Got $_harInputType (Runtime type: ${_harInputType.runtimeType})";
          if (kDebugMode)
            print("!!! $errorMsg"); /* throw Exception(errorMsg); */
        }
        if (!(_harOutputShape != null &&
            _harOutputShape!.length == 2 &&
            _harOutputShape![0] == 1 &&
            _harOutputShape![1] == HAR_NUM_CLASSES)) {
          final errorMsg =
              "HAR Model output shape mismatch! Expected [1, $HAR_NUM_CLASSES], Got $_harOutputShape";
          if (kDebugMode) print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        if (_harOutputType != TfLiteType.kTfLiteFloat32) {
          // Sử dụng kTfLiteFloat32
          final errorMsg =
              "HAR Model output type mismatch! Expected TfLiteType.kTfLiteFloat32, Got $_harOutputType (Runtime type: ${_harOutputType.runtimeType})";
          if (kDebugMode)
            print("!!! $errorMsg"); /* throw Exception(errorMsg); */
        }
        _isHarModelLoaded = true;
      } else {
        throw Exception(
            "HAR Interpreter or Scaler Params are null after loading.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("!!! [ARService] Error loading HAR TFLite model or scaler: $e");
      }
      _isHarModelLoaded = false;
      _harInterpreter?.close();
      _harInterpreter = null;
      _scalerMeans = null;
      _scalerStdDevs = null;
    }
  }

  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (!_isHarModelLoaded || _scalerMeans == null || _scalerStdDevs == null) {
      if (kDebugMode) {
        print(
            "[ARService] HAR Model or Scaler not loaded. Cannot start processing.");
      }
      _loadResources().then((_) {
        // Cố gắng load lại resources nếu chưa có
        if (_isHarModelLoaded &&
            _scalerMeans != null &&
            _scalerStdDevs != null) {
          startProcessingHealthData(healthDataStream);
        } else {
          if (kDebugMode)
            print(
                "[ARService] Failed to load resources on retry. Cannot start processing.");
        }
      });
      return;
    }

    _healthDataSubscriptionForHar?.cancel(); // Hủy sub cũ nếu có
    if (kDebugMode) {
      print("[ARService] Subscribing to health data stream for HAR...");
    }
    _healthDataSubscriptionForHar = healthDataStream.listen((healthData) {
      _addImuToBufferAndPredict([
        healthData.ax,
        healthData.ay,
        healthData.az,
        healthData.gx,
        healthData.gy,
        healthData.gz,
      ]);
    }, onError: (error) {
      if (kDebugMode) {
        print("!!! [ARService] Error on health data stream: $error");
      }
      if (!_activityPredictionController.isClosed) {
        // Phát lỗi qua stream nếu cần
        _activityPredictionController.addError("Health data stream error");
      }
    }, onDone: () {
      if (kDebugMode) {
        print("[ARService] Health data stream for HAR closed.");
      }
    });
  }

  void stopProcessingHealthData() {
    if (kDebugMode) {
      print("[ARService] Stopping health data processing for HAR.");
    }
    _healthDataSubscriptionForHar?.cancel();
    _healthDataSubscriptionForHar = null;
    _stopActivityTimers();
  }

  void _addImuToBufferAndPredict(List<double> imuSample) {
    if (!_isHarModelLoaded ||
        _harInterpreter == null ||
        _scalerMeans == null ||
        _scalerStdDevs == null) {
      if (kDebugMode)
        print("[ARService] HAR Model or Scaler not ready for prediction.");
      return;
    }

    if (imuSample.length != HAR_NUM_FEATURES) {
      if (kDebugMode)
        print(
            "!!! [ARService] Invalid IMU sample length: ${imuSample.length}, expected $HAR_NUM_FEATURES");
      return;
    }
    _imuDataBuffer.add(imuSample);

    if (_imuDataBuffer.length >= HAR_WINDOW_SIZE) {
      List<List<double>> windowData =
          List.from(_imuDataBuffer.sublist(0, HAR_WINDOW_SIZE));

      var inputTensor = List.generate(
          1,
          (batch) => List.generate(
              HAR_WINDOW_SIZE,
              (i) => List.generate(HAR_NUM_FEATURES, (j) {
                    double mean = _scalerMeans![j];
                    double stdDev = _scalerStdDevs![j];
                    return (windowData[i][j] - mean) /
                        (stdDev != 0 ? stdDev : 1.0);
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

        // Chỉ phát ra nếu hoạt động thay đổi VÀ có độ tin cậy nhất định
        // Hoặc nếu giá trị hiện tại của BehaviorSubject khác với dự đoán mới
        if (predictedIndex != -1 &&
            maxProbability > 0.60 &&
            predictedActivityName != _currentPredictedActivityInternal) {
          _currentPredictedActivityInternal =
              predictedActivityName; // Cập nhật biến nội bộ
          if (kDebugMode) {
            print(
                ">>> HAR Prediction: $_currentPredictedActivityInternal (Prob: ${maxProbability.toStringAsFixed(2)}) Raw: ${probabilities.map((p) => p.toStringAsFixed(2)).toList()}");
          }
          if (!_activityPredictionController.isClosed) {
            // Kiểm tra nếu giá trị mới khác với giá trị cuối cùng của stream để tránh phát dư thừa
            if (_activityPredictionController.valueOrNull !=
                _currentPredictedActivityInternal) {
              _activityPredictionController
                  .add(_currentPredictedActivityInternal!);
            }
          }
          _handleActivityChange(_currentPredictedActivityInternal!);
        }
      } catch (e) {
        if (kDebugMode)
          print("!!! [ARService] Error running HAR TFLite model: $e");
        if (!_activityPredictionController.isClosed) {
          _activityPredictionController.addError("HAR Inference Error: $e");
        }
      }

      if (_imuDataBuffer.length >= HAR_STEP_SIZE) {
        _imuDataBuffer.removeRange(0, HAR_STEP_SIZE);
      } else {
        _imuDataBuffer.clear();
      }
    }
  }

  void _handleActivityChange(String newActivity) {
    _stopActivityTimers();

    if (newActivity == 'Sitting') {
      _sittingDuration = Duration.zero;
      _sittingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _sittingDuration += const Duration(seconds: 1);
        if (kDebugMode)
          print("[ARService] Sitting duration: $_sittingDuration");
        if (_sittingDuration >= _sittingWarningThreshold) {
          if (!_warningController.isClosed) {
            _warningController.add(
                "CẢNH BÁO: Bạn đã ngồi quá ${_sittingWarningThreshold.inMinutes} phút!");
          }
          _sittingTimer?.cancel();
          _sittingTimer =
              null; // Quan trọng: đặt lại timer để tránh lỗi khi gọi cancel lần nữa
        }
      });
    } else if (newActivity == 'Lying') {
      _lyingDuration = Duration.zero;
      _lyingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _lyingDuration += const Duration(seconds: 1);
        if (kDebugMode) print("[ARService] Lying duration: $_lyingDuration");
        final now = DateTime.now();
        if (now.hour >= 8 && now.hour < 22) {
          if (_lyingDuration >= _lyingWarningDaytimeThreshold) {
            if (!_warningController.isClosed) {
              _warningController.add(
                  "CẢNH BÁO: Bạn đã nằm quá ${_lyingWarningDaytimeThreshold.inHours} giờ vào ban ngày!");
            }
            _lyingTimer?.cancel();
            _lyingTimer = null; // Quan trọng
          }
        }
      });
    }
  }

  void _stopActivityTimers() {
    _sittingTimer?.cancel();
    _lyingTimer?.cancel();
    _sittingTimer = null;
    _lyingTimer = null;
    // Không reset duration ở đây để nếu _handleActivityChange được gọi lại cho cùng 1 activity
    // (do ngưỡng prob thay đổi chẳng hạn) thì timer không bị reset về 0.
    // Tuy nhiên, logic hiện tại của _handleActivityChange sẽ reset duration.
    if (kDebugMode) print("[ARService] Activity timers stopped.");
  }

  void dispose() {
    if (kDebugMode) {
      print("[ARService] Disposing...");
    }
    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close();
    // Đóng BehaviorSubject và StreamController
    if (!_activityPredictionController.isClosed)
      _activityPredictionController.close();
    if (!_warningController.isClosed) _warningController.close();
    _stopActivityTimers();
    _isHarModelLoaded = false;
    _imuDataBuffer.clear();
    if (kDebugMode) {
      print("[ARService] Disposed.");
    }
  }
}
