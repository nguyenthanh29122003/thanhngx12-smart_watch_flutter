// lib/providers/ble_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // Cần cho ScanResult và BluetoothDevice
import '../services/ble_service.dart'; // Import BleService và HealthData
import '../models/health_data.dart'; // Import model

class BleProvider with ChangeNotifier {
  final BleService _bleService;

  // Trạng thái từ BleService (dùng ValueListenableBuilder hoặc lắng nghe notifier)
  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;

  // Dữ liệu sức khỏe mới nhất
  HealthData? _latestHealthData;
  HealthData? get latestHealthData => _latestHealthData;

  // >>> THÊM GETTER NÀY <<<
  /// Lấy thông tin thiết bị đang kết nối (nếu có) từ BleService.
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;
  // -----------------------

  StreamSubscription? _healthDataSub;

  BleProvider(this._bleService) {
    _listenToHealthData();
    _bleService.connectionStatus.addListener(_handleConnectionChange);
    _bleService.isScanning.addListener(notifyListeners);
    _bleService.scanResults.addListener(notifyListeners);
    print("BleProvider Initialized.");
  }

  void _listenToHealthData() {
    _healthDataSub?.cancel();
    _healthDataSub = _bleService.healthDataStream.listen(
      (data) {
        _latestHealthData = data;
        notifyListeners();
      },
      onError: (error) {
        print("BleProvider: Error in health data stream: $error");
      },
    );
  }

  void _handleConnectionChange() {
    print(
      "BleProvider detected connection status change: ${connectionStatus.value}",
    );
    if (connectionStatus.value == BleConnectionStatus.disconnected ||
        connectionStatus.value == BleConnectionStatus.error) {
      _latestHealthData = null;
      // Giữ lại scanResults và isScanning để UI tự cập nhật từ notifier
    }
    notifyListeners(); // Thông báo thay đổi trạng thái kết nối
  }

  Future<void> startScan() async {
    _latestHealthData = null; // Reset data cũ
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
    // Remove listeners khỏi ValueNotifier của BleService
    // Cách tốt hơn là để BleService tự quản lý Notifier của nó
    // và Provider này chỉ đọc giá trị khi cần hoặc dùng ValueListenableBuilder
    // Tạm thời remove ở đây:
    try {
      connectionStatus.removeListener(_handleConnectionChange);
      isScanning.removeListener(notifyListeners);
      scanResults.removeListener(notifyListeners);
    } catch (e) {
      print("Error removing listeners in BleProvider dispose: $e");
    }
    super.dispose();
  }
}
