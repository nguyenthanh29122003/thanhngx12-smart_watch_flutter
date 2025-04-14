// lib/providers/ble_provider.dart (Phiên bản gốc - KHÔNG có Auth reset)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart';
import '../models/health_data.dart';

class BleProvider with ChangeNotifier {
  // Chỉ phụ thuộc vào BleService
  final BleService _bleService;

  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;
  HealthData? _latestHealthData;
  HealthData? get latestHealthData => _latestHealthData;
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;
  StreamSubscription? _healthDataSub;

  // --- Constructor (Chỉ nhận BleService) ---
  BleProvider(this._bleService) {
    _listenToHealthData();
    _bleService.connectionStatus.addListener(_handleConnectionChange);
    _bleService.isScanning.addListener(_notify);
    _bleService.scanResults.addListener(_notify);
    // <<< KHÔNG gọi listen auth >>>
    print("BleProvider Initialized (No Auth Dependency).");
  }

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
    print("Disposing BleProvider (No Auth Dependency)...");
    _healthDataSub?.cancel();
    // <<< KHÔNG có _authSub?.cancel() >>>
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
