// lib/services/activity_recognition_service.dart
import 'dart:async';
import 'dart:typed_data'; // Cho Float32List nếu cần
import 'package:flutter/foundation.dart'; // Cho kDebugMode
// import 'package:flutter/services.dart' show rootBundle; // Không cần nếu model trong assets và dùng Interpreter.fromAsset
import 'package:tflite_flutter/tflite_flutter.dart';
// import 'package:tflite_flutter_helper/tflite_flutter_helper.dart'; // Bỏ comment nếu bạn quyết định dùng

import '../models/health_data.dart'; // Để nhận HealthData object

// --- CÁC HẰNG SỐ CHO MODEL HAR CỦA BẠN ---
// <<< CẦN THAY ĐỔI THEO MODEL THỰC TẾ CỦA BẠN >>>
const String TFLITE_MODEL_HAR_FILE =
    'models/your_har_model.tflite'; // Đặt đúng tên file model của bạn
const int HAR_WINDOW_SIZE =
    128; // Ví dụ: Số mẫu IMU trong một cửa sổ (ví dụ: 1.28 giây nếu 100Hz)
const int HAR_NUM_FEATURES = 6; // ax, ay, az, gx, gy, gz
const int HAR_STEP_SIZE =
    64; // Bước trượt cửa sổ (overlap = WINDOW_SIZE - STEP_SIZE)
const int HAR_NUM_CLASSES =
    6; // Ví dụ: Số lớp hoạt động (Đi, Đứng, Ngồi, Chạy, Lên, Xuống...)

// Map từ index đầu ra của model sang tên hoạt động
// <<< CẦN THAY ĐỔI THEO MODEL THỰC TẾ CỦA BẠN >>>
const Map<int, String> HAR_ACTIVITY_LABELS = {
  0: 'Walking',
  1: 'Running',
  2: 'Sitting',
  3: 'Standing',
  4: 'Lying',
  5: 'Stairs', // Ví dụ
  // ... (thêm các lớp khác của bạn)
};

// Giá trị MEAN và STD DEV của từng feature từ tập huấn luyện
// <<< CẦN LẤY TỪ QUÁ TRÌNH HUẤN LUYỆN MODEL - NẾU MODEL YÊU CẦU CHUẨN HÓA >>>
// Nếu model của bạn huấn luyện trên dữ liệu thô (chưa chuẩn hóa), bạn có thể không cần chúng
// Thứ tự phải khớp với NUM_FEATURES: ax, ay, az, gx, gy, gz
const List<double> HAR_FEATURE_MEANS = [
  0.0,
  0.0,
  0.0,
  0.0,
  0.0,
  0.0
]; // Thay bằng giá trị thực
const List<double> HAR_FEATURE_STD_DEVS = [
  1.0,
  1.0,
  1.0,
  1.0,
  1.0,
  1.0
]; // Thay bằng giá trị thực
// -------------------------------------------------------------------

class ActivityRecognitionService {
  Interpreter? _harInterpreter; // Interpreter cho model HAR
  bool _isHarModelLoaded = false;

  // Thông tin tensor của model HAR
  List<int>? _harInputShape;
  List<int>? _harOutputShape;
  TensorType? _harInputType; // Thay TfLiteType? bằng TensorType?
  TensorType? _harOutputType; // Thay TfLiteType? bằng TensorType?

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
    print("[ActivityRecognitionService] Initializing...");
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _loadHarModel();
    // Logic bắt đầu lắng nghe health data sẽ được gọi từ bên ngoài
  }

  Future<void> _loadHarModel() async {
    if (_isHarModelLoaded) return;
    print("[ARService] Loading HAR TFLite model: $TFLITE_MODEL_HAR_FILE");
    try {
      _harInterpreter = await Interpreter.fromAsset(TFLITE_MODEL_HAR_FILE);
      // _harInterpreter?.allocateTensors(); // Có thể cần cho một số trường hợp

      if (_harInterpreter != null) {
        _harInputShape = _harInterpreter!.getInputTensor(0).shape;
        _harOutputShape = _harInterpreter!.getOutputTensor(0).shape;
        _harInputType = _harInterpreter!.getInputTensor(0).type;
        _harOutputType = _harInterpreter!.getOutputTensor(0).type;

        print('---------------------------------------------------');
        print('[ARService] HAR TFLite Model Loaded:');
        print('  Input Shape: $_harInputShape, Type: $_harInputType');
        print('  Output Shape: $_harOutputShape, Type: $_harOutputType');
        print('---------------------------------------------------');

        // Kiểm tra Shape (Rất quan trọng!)
        if (!(_harInputShape != null &&
            _harInputShape!.length >=
                3 && // Thường là [batch, window_size, num_features]
            _harInputShape![1] == HAR_WINDOW_SIZE &&
            _harInputShape![2] == HAR_NUM_FEATURES)) {
          final errorMsg =
              "HAR Model input shape mismatch! Expected [batch, $HAR_WINDOW_SIZE, $HAR_NUM_FEATURES], Got $_harInputShape";
          print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        if (!(_harOutputShape != null &&
            _harOutputShape!.length >= 2 && // Thường là [batch, num_classes]
            _harOutputShape![1] == HAR_NUM_CLASSES)) {
          final errorMsg =
              "HAR Model output shape mismatch! Expected [batch, $HAR_NUM_CLASSES], Got $_harOutputShape";
          print("!!! $errorMsg");
          throw Exception(errorMsg);
        }
        _isHarModelLoaded = true;
      } else {
        throw Exception("HAR Interpreter is null after loading model.");
      }
    } catch (e) {
      print("!!! [ARService] Error loading HAR TFLite model: $e");
      _isHarModelLoaded = false;
      _harInterpreter?.close();
      _harInterpreter = null;
    }
  }

  /// Bắt đầu lắng nghe HealthData stream từ BleService để lấy dữ liệu IMU.
  void startProcessingHealthData(Stream<HealthData> healthDataStream) {
    if (!_isHarModelLoaded) {
      print("[ARService] HAR Model not loaded. Cannot start processing.");
      // Có thể thử tải lại model ở đây hoặc báo lỗi
      // _loadHarModel().then((_) {
      //   if(_isHarModelLoaded) startProcessingHealthData(healthDataStream);
      // });
      return;
    }
    _healthDataSubscriptionForHar?.cancel(); // Hủy sub cũ nếu có
    print("[ARService] Subscribing to health data stream for HAR...");
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
      print("!!! [ARService] Error on health data stream: $error");
    }, onDone: () {
      print("[ARService] Health data stream for HAR closed.");
    });
  }

  /// Dừng lắng nghe HealthData stream.
  void stopProcessingHealthData() {
    print("[ARService] Stopping health data processing for HAR.");
    _healthDataSubscriptionForHar?.cancel();
    _healthDataSubscriptionForHar = null;
  }

  void _addImuToBufferAndPredict(List<double> imuSample) {
    if (imuSample.length != HAR_NUM_FEATURES) {
      print(
          "!!! [ARService] Invalid IMU sample length for HAR: ${imuSample.length}");
      return;
    }
    _imuDataBuffer.add(imuSample);

    // Nếu buffer có đủ dữ liệu để tạo ít nhất một cửa sổ mới kể từ lần xử lý cuối
    // hoặc khi buffer đủ lớn bằng WINDOW_SIZE
    if (_imuDataBuffer.length >= HAR_WINDOW_SIZE) {
      // Tạo cửa sổ dữ liệu
      List<List<double>> windowData =
          List.from(_imuDataBuffer.sublist(0, HAR_WINDOW_SIZE));

      // --- Chuẩn bị Input Tensor ---
      // (Giả định model nhận input shape [1, HAR_WINDOW_SIZE, HAR_NUM_FEATURES] và kiểu float32)
      // Và dữ liệu không cần chuẩn hóa thêm ở đây (đã chuẩn hóa khi huấn luyện hoặc model dùng dữ liệu thô)
      // Nếu cần chuẩn hóa, hãy gọi hàm _normalizeWindow(windowData) và dùng kết quả đó.

      // Tạo List 3 chiều
      var inputTensor = List.generate(
        1, // Batch size
        (_) => List.generate(
            HAR_WINDOW_SIZE,
            (i) => List.generate(HAR_NUM_FEATURES, (j) => windowData[i][j],
                growable: false),
            growable: false),
        growable: false,
      );

      // --- Chuẩn bị Output Tensor ---
      // (Giả định model output shape [1, HAR_NUM_CLASSES] và kiểu float32)
      var outputTensor = List.generate(
          1, (_) => List.filled(HAR_NUM_CLASSES, 0.0, growable: false),
          growable: false);

      // --- Chạy Suy luận ---
      if (_harInterpreter != null) {
        try {
          _harInterpreter!.run(inputTensor, outputTensor);

          // --- Hậu xử lý Kết quả ---
          List<double> probabilities = outputTensor[0].cast<double>();
          int predictedIndex = -1;
          double maxProbability = 0.0;

          for (int i = 0; i < probabilities.length; i++) {
            if (probabilities[i] > maxProbability) {
              maxProbability = probabilities[i];
              predictedIndex = i;
            }
          }

          String predictedActivity = HAR_ACTIVITY_LABELS[predictedIndex] ??
              "Unknown"; // TODO: i18n "Unknown"

          // Chỉ phát nếu hoạt động thay đổi và có độ tin cậy nhất định
          if (predictedIndex != -1 &&
              maxProbability > 0.6 &&
              predictedActivity != _currentPredictedActivity) {
            // Ngưỡng tin cậy ví dụ
            _currentPredictedActivity = predictedActivity;
            if (kDebugMode) {
              print(
                  ">>> HAR Prediction: $_currentPredictedActivity (Prob: ${maxProbability.toStringAsFixed(2)})");
            }
            if (!_activityPredictionController.isClosed) {
              _activityPredictionController.add(_currentPredictedActivity!);
            }
          }
        } catch (e) {
          print("!!! [ARService] Error running HAR TFLite model: $e");
          if (!_activityPredictionController.isClosed) {
            _activityPredictionController.addError("HAR Inference Error");
          }
        }
      }

      // --- Trượt cửa sổ: Xóa HAR_STEP_SIZE mẫu đầu tiên khỏi buffer ---
      if (_imuDataBuffer.length >= HAR_STEP_SIZE) {
        _imuDataBuffer.removeRange(0, HAR_STEP_SIZE);
      } else {
        _imuDataBuffer.clear();
      }
    }
  }

  // Hàm chuẩn hóa (nếu model của bạn yêu cầu)
  // List<List<double>> _normalizeWindow(List<List<double>> windowData) {
  //   List<List<double>> normalizedWindow = [];
  //   for (int i = 0; i < windowData.length; i++) { // Iterate through each sample in the window
  //     List<double> normalizedSample = [];
  //     for (int j = 0; j < windowData[i].length; j++) { // Iterate through each feature in the sample
  //       // Apply Z-score scaling: (value - mean) / std_dev
  //       // Ensure std_dev is not zero to avoid division by zero error
  //       double stdDev = HAR_FEATURE_STD_DEVS[j];
  //       normalizedSample.add( (windowData[i][j] - HAR_FEATURE_MEANS[j]) / (stdDev != 0 ? stdDev : 1.0) );
  //     }
  //     normalizedWindow.add(normalizedSample);
  //   }
  //   return normalizedWindow;
  // }

  void dispose() {
    print("[ActivityRecognitionService] Disposing...");
    _healthDataSubscriptionForHar?.cancel();
    _harInterpreter?.close(); // Quan trọng: Giải phóng tài nguyên model
    _activityPredictionController.close();
    _isHarModelLoaded = false;
    print("[ActivityRecognitionService] Disposed.");
  }
}
