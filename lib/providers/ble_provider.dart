// lib/providers/ble_provider.dart (Phiên bản gốc - KHÔNG có Auth reset)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Cần cho ScanResult và BluetoothDevice
import '../services/ble_service.dart'; // Import BleService và Enum BleConnectionStatus
import '../models/health_data.dart'; // Import model HealthData

// <<< KHÔNG import AuthService >>>

class BleProvider with ChangeNotifier {
  // Chỉ phụ thuộc vào BleService
  final BleService _bleService;
  // <<< KHÔNG có final AuthService _authService; >>>

  // --- State và Notifiers từ BleService ---
  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;

  // --- State nội bộ của Provider ---
  HealthData? _latestHealthData; // Lưu trữ dữ liệu sức khỏe mới nhất nhận được
  HealthData? get latestHealthData => _latestHealthData;

  // --- Getter cho thiết bị kết nối ---
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  // --- Stream Subscription ---
  StreamSubscription? _healthDataSub; // Lắng nghe dữ liệu health data
  // <<< KHÔNG có StreamSubscription? _authSub; >>>

  // --- Constructor (Chỉ nhận BleService) ---
  BleProvider(this._bleService) {
    // <<< CHỈ NHẬN 1 THAM SỐ
    _listenToHealthData();
    _bleService.connectionStatus.addListener(_handleConnectionChange);
    _bleService.isScanning.addListener(_notify);
    _bleService.scanResults.addListener(_notify);
    // <<< KHÔNG có gọi _listenToAuthChanges(); >>>
    print("BleProvider Initialized (Original Version - No Auth dependency).");
  }

  // <<< KHÔNG CÓ HÀM _listenToAuthChanges() >>>
  // <<< KHÔNG CÓ HÀM _resetState() >>>

  // --- Hàm lắng nghe dữ liệu HealthData từ BleService ---
  void _listenToHealthData() {
    _healthDataSub?.cancel();
    _healthDataSub = _bleService.healthDataStream.listen(
      (data) {
        _latestHealthData = data;
        notifyListeners();
      },
      onError: (error) {
        print("!!! [BleProvider] Error in health data stream: $error");
      },
    );
  }

  // --- Hàm xử lý khi trạng thái kết nối BLE thay đổi ---
  void _handleConnectionChange() {
    final status = connectionStatus.value;
    print(
        "[BleProvider] Detected connection status change from BleService: $status");
    if (status == BleConnectionStatus.disconnected ||
        status == BleConnectionStatus.error) {
      if (_latestHealthData != null) {
        _latestHealthData = null;
        // Gọi notifyListeners ở cuối hàm này
      }
    }
    // Luôn notify để UI cập nhật chip trạng thái, v.v.
    notifyListeners();
  }

  // --- Hàm tiện ích để gọi notifyListeners ---
  void _notify() {
    if (hasListeners) {
      notifyListeners();
    }
  }

  // --- Các hàm public để gọi hành động trong BleService ---
  Future<void> startScan() async {
    // Reset dữ liệu cũ khi quét mới
    if (_latestHealthData != null) {
      _latestHealthData = null;
      notifyListeners();
    }
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

  // --- Hàm dispose ---
  @override
  void dispose() {
    print("Disposing BleProvider (Original Version)...");
    _healthDataSub?.cancel();
    // <<< KHÔNG có _authSub?.cancel(); >>>

    // Hủy các listeners đã đăng ký với ValueNotifiers của BleService
    try {
      _bleService.connectionStatus.removeListener(_handleConnectionChange);
      _bleService.isScanning.removeListener(_notify);
      _bleService.scanResults.removeListener(_notify);
    } catch (e) {
      print("Error removing listeners in BleProvider dispose: $e");
    }
    print("BleProvider disposed.");
    super.dispose();
  }
}
