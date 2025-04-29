// lib/providers/ble_provider.dart (Phiên bản gốc - KHÔNG có Auth reset)
import 'dart:async';
import 'dart:convert';
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
    final status =
        connectionStatus.value; // Lấy trạng thái hiện tại từ Notifier
    print("[BleProvider] Handling connection status change: $status");

    if (status == BleConnectionStatus.connected) {
      // <<< GỌI HÀM ĐỒNG BỘ THỜI GIAN KHI KẾT NỐI >>>
      // Có thể thêm delay nhỏ nếu cần
      Future.delayed(const Duration(milliseconds: 500), () {
        if (connectionStatus.value == BleConnectionStatus.connected) {
          print("[BleProvider] Attempting to sync time after connection...");
          syncTimeToDevice();
        }
      });
      // ------------------------------------------
    } else {
      // Disconnected hoặc Error
      if (_latestHealthData != null) {
        _latestHealthData = null;
        print(
            "[BleProvider] Cleared latest health data due to disconnect/error.");
        // Gọi notify ở cuối
      }
    }
    _notify();
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

  // <<< HÀM MỚI ĐỂ GỬI THỜI GIAN >>>
  Future<bool> syncTimeToDevice() async {
    if (connectionStatus.value != BleConnectionStatus.connected) {
      print("[BleProvider] Cannot sync time: Device not connected.");
      return false;
    }

    try {
      final now = DateTime.now();
      final timeData = {
        'time': {
          'year': now.year,
          'month': now.month,
          'day': now.day,
          'hour': now.hour,
          'minute': now.minute,
          'second': now.second,
        }
      };
      final jsonString = jsonEncode(timeData);
      final dataBytes = utf8.encode(jsonString);

      print(
          "[BleProvider] Preparing to send time data via BleService: $jsonString");

      // Gọi hàm ghi của BleService
      bool success = await _bleService.writeDataToDevice(dataBytes);

      if (success) {
        print(
            "[BleProvider] Time sync command sent successfully via BleService.");
      } else {
        print(
            "[BleProvider] BleService reported failure sending time sync command.");
      }
      return success;
    } catch (e) {
      print("!!! [BleProvider] Error creating/sending time sync data: $e");
      return false;
    }
  }
  // -----------------------------

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
