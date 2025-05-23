// lib/services/activity_recognition_service.dart
import 'dart:async';
import 'dart:typed_data'; // Cho Float32List nếu cần
import 'package:flutter/foundation.dart'; // Cho kDebugMode
// import 'package:flutter/services.dart' show rootBundle; // Không cần nếu model trong assets và dùng Interpreter.fromAsset
import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:tflite_flutter_helper/tflite_flutter_helper.dart'; // Bỏ comment nếu bạn quyết định dùng

import '../models/health_data.dart'; // Để nhận HealthData object

// --- CÁC HẰNG SỐ CHO MODEL HAR CỦA BẠN ---
// <<< ĐÃ CẬP NHẬT THEO SCRIPT PYTHON >>>
const String TFLITE_MODEL_HAR_FILE =
    'models/har_cnn_float32.tflite'; // Tên file model từ Python Cell 7
const int HAR_WINDOW_SIZE = 256; // Từ WINDOW_SIZE của Python (2.56s * 100Hz)
const int HAR_NUM_FEATURES =
    6; // ax, ay, az, gx, gy, gz (Từ NUM_FEATURES của Python)
const int HAR_STEP_SIZE = 128; // Từ STEP của Python (WINDOW_SIZE // 2)
const int HAR_NUM_CLASSES =
    8; // Từ NUM_CLASSES của Python (Lying, Sitting, Standing, Walking, Running, Cycling, Ascending, Descending)

// Map từ index đầu ra của model sang tên hoạt động
// <<< ĐÃ CẬP NHẬT THEO id_to_activity_name TỪ PYTHON CELL 2 >>>
const Map<int, String> HAR_ACTIVITY_LABELS = {
  0: 'Lying',
  1: 'Sitting',
  2: 'Standing',
  3: 'Walking',
  4: 'Running',
  5: 'Cycling',
  6: 'Ascending_Stairs',
  7: 'Descending_Stairs',
};

// Giá trị MEAN và STD DEV của từng feature từ tập huấn luyện
// <<< QUAN TRỌNG: DỰA TRÊN PYTHON SCRIPT, MODEL CNN CÓ BATCHNORMALIZATION NÊN KHÔNG CẦN CHUẨN HÓA THỦ CÔNG Ở ĐÂY >>>
// Model đã được huấn luyện với dữ liệu không qua StandardScaler tường minh.
// Các lớp BatchNormalization trong model sẽ xử lý việc chuẩn hóa.
// Do đó, giữ mean là 0 và std_dev là 1, và không gọi hàm _normalizeWindow.
const List<double> HAR_FEATURE_MEANS = [
  0.0, 0.0, 0.0, // ax, ay, az
  0.0, 0.0, 0.0 // gx, gy, gz
];
const List<double> HAR_FEATURE_STD_DEVS = [
  1.0, 1.0, 1.0, // ax, ay, az
  1.0, 1.0, 1.0 // gx, gy, gz
];
// -------------------------------------------------------------------

class ActivityRecognitionService {
  Interpreter? _harInterpreter; // Interpreter cho model HAR
  bool _isHarModelLoaded = false;

  // Thông tin tensor của model HAR
  List<int>? _harInputShape;
  List<int>? _harOutputShape;
  TensorType? _harInputType;
  TensorType? _harOutputType;

  // Buffer để lưu trữ dữ liệu IMU
  final List<List<double>> _imuDataBuffer = [];

  // StreamController để phát ra hoạt động được dự đoán
  final StreamController<String> _activityPredictionController =
      StreamController<String>.broadcast();
  Stream<String> get activityPredictionStream =>
      _activityPredictionController.stream;

  // StreamSubscription để lắng nghe HealthData
  StreamSubscription? _healthDataSubscriptionForHar;

  // Trạng thái hoạt động hiện tại (để tránh phát lại nếu không đổi)
  String? _currentPredictedActivity;

  ActivityRecognitionService() {
    if (kDebugMode) {
      print("[ActivityRecognitionService] Initializing...");
    }
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadHarModel();
  }

  Future<void> _loadHarModel() async {
    if (_isHarModelLoaded) return;
    if (kDebugMode) {
      print("[ARService] Loading HAR TFLite model: $TFLITE_MODEL_HAR_FILE");
    }
    try {
      _harInterpreter = await Interpreter.fromAsset(TFLITE_MODEL_HAR_FILE);

      if (_harInterpreter != null) {
        _harInputShape = _harInterpreter!.getInputTensor(0).shape;
        _harOutputShape = _harInterpreter!.getOutputTensor(0).shape;
        _harInputType = _harInterpreter!.getInputTensor(0).type;
        _harOutputType = _harInterpreter!.getOutputTensor(0).type;

        if (kDebugMode) {
          print('---------------------------------------------------');
          print('[ARService] HAR TFLite Model Loaded:');
          print('  Input Shape: $_harInputShape, Type: $_harInputType');
          print('  Output Shape: $_harOutputShape, Type: $_harOutputType');
          print('---------------------------------------------------');
        }

        // Kiểm tra Shape (Rất quan trọng!)
        // Model CNN 1D thường có input shape [batch, window_size, num_features]
        // Ví dụ: [1, 256, 6]
        if (!(_harInputShape != null &&
            _harInputShape!.length == 3 && // [batch, window_size, num_features]
            _harInputShape![0] ==
                1 && // Thường batch size là 1 cho inference trên thiết bị
            _harInputShape![1] == HAR_WINDOW_SIZE &&
            _harInputShape![2] == HAR_NUM_FEATURES)) {
          final errorMsg =
              "HAR Model input shape mismatch! Expected [1, $HAR_WINDOW_SIZE, $HAR_NUM_FEATURES], Got $_harInputShape";
          if (kDebugMode) print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        // Model CNN 1D thường có output shape [batch, num_classes]
        // Ví dụ: [1, 8]
        if (!(_harOutputShape != null &&
            _harOutputShape!.length == 2 && // [batch, num_classes]
            _harOutputShape![0] == 1 && // Thường batch size là 1
            _harOutputShape![1] == HAR_NUM_CLASSES)) {
          final errorMsg =
              "HAR Model output shape mismatch! Expected [1, $HAR_NUM_CLASSES], Got $_harOutputShape";
          if (kDebugMode) print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        _isHarModelLoaded = true;
      } else {
        throw Exception("HAR Interpreter is null after loading model.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("!!! [ARService] Error loading HAR TFLite model: $e");
      }
      _isHarModelLoaded = false;
      _harInterpreter?.close();
      _harInterpreter = null;
    }
  }

  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (!_isHarModelLoaded) {
      if (kDebugMode) {
        print("[ARService] HAR Model not loaded. Cannot start processing.");
      }
      // Cân nhắc thử tải lại model hoặc báo lỗi rõ ràng hơn cho UI
      // _loadHarModel().then((_) {
      //   if(_isHarModelLoaded) startProcessingHealthData(healthDataStream);
      // });
      return;
    }
    _healthDataSubscriptionForHar?.cancel();
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
  }

  void _addImuToBufferAndPredict(List<double> imuSample) {
    if (!_isHarModelLoaded || _harInterpreter == null) {
      if (kDebugMode) {
        print("[ARService] HAR Model not ready for prediction.");
      }
      return;
    }

    if (imuSample.length != HAR_NUM_FEATURES) {
      if (kDebugMode) {
        print(
            "!!! [ARService] Invalid IMU sample length for HAR: ${imuSample.length}, expected $HAR_NUM_FEATURES");
      }
      return;
    }
    _imuDataBuffer.add(imuSample);

    if (_imuDataBuffer.length >= HAR_WINDOW_SIZE) {
      // Tạo cửa sổ dữ liệu từ đầu buffer
      List<List<double>> windowData =
          List.from(_imuDataBuffer.sublist(0, HAR_WINDOW_SIZE));

      // --- Chuẩn bị Input Tensor ---
      // Input tensor phải có shape [1, HAR_WINDOW_SIZE, HAR_NUM_FEATURES]
      // và kiểu dữ liệu float32 (Thường là mặc định cho model Keras nếu không chỉ định INT8)
      // KHÔNG cần gọi _normalizeWindow ở đây vì model CNN có BatchNormalization
      var inputTensor = [
        List.generate(HAR_WINDOW_SIZE, (i) => List<double>.from(windowData[i]))
      ];

      // --- Chuẩn bị Output Tensor ---
      // Output tensor có shape [1, HAR_NUM_CLASSES] và kiểu float32
      var outputTensor = List.generate(
          1, (_) => List.filled(HAR_NUM_CLASSES, 0.0, growable: false),
          growable: false);

      // --- Chạy Suy luận ---
      try {
        _harInterpreter!.run(inputTensor, outputTensor);

        List<double> probabilities = outputTensor[0].cast<double>();
        int predictedIndex = -1;
        double maxProbability = 0.0;

        for (int i = 0; i < probabilities.length; i++) {
          if (probabilities[i] > maxProbability) {
            maxProbability = probabilities[i];
            predictedIndex = i;
          }
        }

        String predictedActivity =
            HAR_ACTIVITY_LABELS[predictedIndex] ?? "Unknown";

        if (predictedIndex != -1 &&
            maxProbability > 0.65 && // Ngưỡng tin cậy, có thể điều chỉnh
            predictedActivity != _currentPredictedActivity) {
          _currentPredictedActivity = predictedActivity;
          if (kDebugMode) {
            print(
                ">>> HAR Prediction: $_currentPredictedActivity (Prob: ${maxProbability.toStringAsFixed(2)}) Raw: ${probabilities.map((p) => p.toStringAsFixed(2)).toList()}");
          }
          if (!_activityPredictionController.isClosed) {
            _activityPredictionController.add(_currentPredictedActivity!);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("!!! [ARService] Error running HAR TFLite model: $e");
        }
        if (!_activityPredictionController.isClosed) {
          _activityPredictionController.addError("HAR Inference Error: $e");
        }
      }

      // --- Trượt cửa sổ: Xóa HAR_STEP_SIZE mẫu đầu tiên khỏi buffer ---
      if (_imuDataBuffer.length >= HAR_STEP_SIZE) {
        _imuDataBuffer.removeRange(0, HAR_STEP_SIZE);
      } else {
        _imuDataBuffer
            .clear(); // Nên clear nếu còn ít hơn step_size để tránh lỗi
      }
    }
  }

  // Hàm chuẩn hóa (KHÔNG CẦN DÙNG NẾU MODEL CÓ BATCHNORMALIZATION VÀ ĐƯỢC HUẤN LUYỆN VỚI DỮ LIỆU KHÔNG QUA SCALER TƯỜNG MINH)
  // List<List<double>> _normalizeWindow(List<List<double>> windowData) {
  //   List<List<double>> normalizedWindow = [];
  //   for (int i = 0; i < windowData.length; i++) {
  //     List<double> normalizedSample = List.filled(HAR_NUM_FEATURES, 0.0);
  //     for (int j = 0; j < windowData[i].length; j++) {
  //       double stdDev = HAR_FEATURE_STD_DEVS[j];
  //       normalizedSample[j] = (windowData[i][j] - HAR_FEATURE_MEANS[j]) / (stdDev != 0 ? stdDev : 1.0);
  //     }
  //     normalizedWindow.add(normalizedSample);
  //   }
  //   return normalizedWindow;
  // }

  void dispose() {
    if (kDebugMode) {
      print("[ActivityRecognitionService] Disposing...");
    }
    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close();
    _activityPredictionController.close();
    _isHarModelLoaded = false;
    _imuDataBuffer.clear();
    if (kDebugMode) {
      print("[ActivityRecognitionService] Disposed.");
    }
  }
}
