// lib/providers/ble_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Cần cho ScanResult
import '../services/ble_service.dart'; // Import BleService và HealthData

class BleProvider with ChangeNotifier {
  final BleService _bleService;

  // Trạng thái từ BleService (sử dụng ValueListenableBuilder trong UI hoặc lắng nghe notifier)
  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;

  // Dữ liệu sức khỏe mới nhất (ví dụ)
  HealthData? _latestHealthData;
  HealthData? get latestHealthData => _latestHealthData;

  // Lịch sử dữ liệu (ví dụ, có thể quản lý ở provider khác)
  // List<HealthData> _healthDataHistory = [];
  // List<HealthData> get healthDataHistory => _healthDataHistory;

  StreamSubscription? _healthDataSub;

  BleProvider(this._bleService) {
    // Lắng nghe dữ liệu sức khỏe từ BleService
    _listenToHealthData();
    // Lắng nghe thay đổi trạng thái kết nối để có thể cập nhật UI nếu cần
    _bleService.connectionStatus.addListener(_handleConnectionChange);
    _bleService.isScanning.addListener(
      notifyListeners,
    ); // Thông báo khi trạng thái quét thay đổi
    _bleService.scanResults.addListener(
      notifyListeners,
    ); // Thông báo khi kết quả quét thay đổi
    print("BleProvider Initialized.");
  }

  void _listenToHealthData() {
    _healthDataSub?.cancel();
    _healthDataSub = _bleService.healthDataStream.listen(
      (data) {
        _latestHealthData = data;
        // print("BleProvider received new health data: Steps=${data.steps}");
        // Thêm vào lịch sử (ví dụ đơn giản)
        // _healthDataHistory.insert(0, data);
        // if (_healthDataHistory.length > 100) { // Giới hạn lịch sử
        //   _healthDataHistory.removeLast();
        // }
        notifyListeners(); // Thông báo cho UI biết có dữ liệu mới
      },
      onError: (error) {
        print("BleProvider: Error in health data stream: $error");
        // Có thể xử lý lỗi ở đây
      },
    );
  }

  void _handleConnectionChange() {
    print(
      "BleProvider detected connection status change: ${_bleService.connectionStatus.value}",
    );
    // Nếu ngắt kết nối, xóa dữ liệu cũ
    if (_bleService.connectionStatus.value ==
            BleConnectionStatus.disconnected ||
        _bleService.connectionStatus.value == BleConnectionStatus.error) {
      _latestHealthData = null;
      // _healthDataHistory = []; // Có thể muốn giữ lại lịch sử cũ
    }
    notifyListeners(); // Thông báo cho UI cập nhật (ví dụ: icon trạng thái kết nối)
  }

  // --- Các hàm gọi đến BleService ---
  Future<void> startScan() async {
    // Reset dữ liệu cũ trước khi quét mới (tùy chọn)
    _latestHealthData = null;
    // _healthDataHistory = [];
    notifyListeners();
    await _bleService.startScan();
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _bleService.connectToDevice(device);
  }

  Future<void> disconnectFromDevice() async {
    await _bleService.disconnectFromDevice();
  }

  Future<bool> sendWifiConfig(String ssid, String password) async {
    return await _bleService.sendWifiConfig(ssid, password);
  }

  @override
  void dispose() {
    print("Disposing BleProvider...");
    _healthDataSub?.cancel();
    _bleService.connectionStatus.removeListener(_handleConnectionChange);
    _bleService.isScanning.removeListener(notifyListeners);
    _bleService.scanResults.removeListener(notifyListeners);
    // Không gọi _bleService.dispose() ở đây nếu BleService được cung cấp
    // dưới dạng singleton hoặc bởi Provider khác. Việc dispose BleService
    // nên được quản lý ở nơi nó được tạo ra (ví dụ trong main.dart).
    super.dispose();
  }
}
