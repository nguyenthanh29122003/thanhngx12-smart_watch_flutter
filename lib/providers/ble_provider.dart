// lib/providers/ble_provider.dart
import 'dart:async';
import 'dart:convert'; // Cần cho việc gửi time
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/ble_service.dart'; // Cần BleService và Enum
import '../models/health_data.dart';
import '../app_constants.dart'; // Cần cho việc gửi time

class BleProvider with ChangeNotifier {
  final BleService _bleService;

  // --- Getters cho các ValueNotifier từ BleService (UI có thể dùng trực tiếp) ---
  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  // --- State cục bộ của Provider ---
  HealthData? _latestHealthData;
  HealthData? get latestHealthData =>
      _latestHealthData; // Giữ lại để tiện truy cập

  // --- ValueNotifier cho State cục bộ (Tối ưu cho UI) ---
  final ValueNotifier<HealthData?> latestHealthDataNotifier =
      ValueNotifier(null);
  // <<< THÊM NOTIFIER CHO STATUS (VÍ DỤ: WIFI) >>>
  final ValueNotifier<bool?> deviceWifiStatusNotifier =
      ValueNotifier(null); // Null khi chưa biết/mất kết nối

  // --- Subscriptions cho các Stream từ BleService ---
  StreamSubscription? _healthDataSub;
  StreamSubscription? _connectionStatusSub; // Để lắng nghe trạng thái kết nối
  StreamSubscription? _statusDataSub; // Để lắng nghe trạng thái từ ESP32
  StreamSubscription? _deviceReadySub; // Để biết khi nào sẵn sàng gửi lệnh

  // Cờ mounted để kiểm tra an toàn trong callback
  bool _mounted = true;

  BleProvider(this._bleService) {
    print("[BleProvider] Initializing...");
    // Khởi tạo tất cả các listener
    _listenToHealthData();
    _listenToConnectionStatus();
    _listenToStatusUpdates(); // <<< Lắng nghe stream status mới
    _listenToDeviceReady(); // <<< Lắng nghe stream device ready mới
    // Không cần lắng nghe isScanning, scanResults ở đây nếu UI dùng ValueListenableBuilder
    print("[BleProvider] Initialized and subscribed to BleService streams.");
  }

  // Lắng nghe dữ liệu HealthData
  void _listenToHealthData() {
    _healthDataSub?.cancel();
    _healthDataSub = _bleService.healthDataStream.listen(
      (data) {
        _latestHealthData = data;
        latestHealthDataNotifier.value = data;
        // Cập nhật trạng thái WiFi từ HealthData nếu muốn (fallback)
        // deviceWifiStatusNotifier.value = data.wifi;
        _notify();
      },
      onError: (error) {
        print("!!! [BleProvider] Error in health data stream: $error");
      },
    );
  }

  // Lắng nghe thay đổi trạng thái kết nối từ Stream
  void _listenToConnectionStatus() {
    _connectionStatusSub?.cancel();
    _connectionStatusSub = _bleService.connectionStatusStream.listen((status) {
      print(
          "[BleProvider] Received connection status update via stream: $status");
      _handleConnectionChange(status); // Gọi hàm xử lý
    }, onError: (error) {
      print("!!! [BleProvider] Error in connection status stream: $error");
      _handleConnectionChange(BleConnectionStatus.error); // Xử lý như lỗi
    });
  }

  // <<< HÀM MỚI: Lắng nghe cập nhật trạng thái từ ESP32 >>>
  void _listenToStatusUpdates() {
    _statusDataSub?.cancel();
    _statusDataSub = _bleService.statusStream.listen((statusData) {
      print("[BleProvider] Received status update from device: $statusData");
      // Xử lý dữ liệu status nhận được (Map<String, dynamic>)
      if (statusData.containsKey('wifi_status')) {
        bool? newWifiStatus;
        if (statusData['wifi_status'] == 'connected') {
          newWifiStatus = true;
        } else if (statusData['wifi_status'] == 'disconnected' ||
            statusData['wifi_status'] == 'connecting') {
          newWifiStatus = false;
        } // Có thể thêm các trạng thái khác
        // Chỉ cập nhật nếu khác giá trị hiện tại
        if (deviceWifiStatusNotifier.value != newWifiStatus) {
          deviceWifiStatusNotifier.value = newWifiStatus;
          print("[BleProvider] Device WiFi status updated to: $newWifiStatus");
          // Không cần gọi _notify() vì ValueNotifier tự thông báo
        }
      }
      // TODO: Xử lý các key status khác nếu có (ví dụ: time_status, error)
    }, onError: (error) {
      print("!!! [BleProvider] Error in status update stream: $error");
    });
  }
  // ----------------------------------------------------

  // <<< HÀM MỚI: Lắng nghe sự kiện Device Ready >>>
  void _listenToDeviceReady() {
    _deviceReadySub?.cancel();
    _deviceReadySub = _bleService.deviceReadyStream.listen((_) {
      print("[BleProvider] Received Device Ready event from BleService.");
      if (_mounted && connectionStatus.value == BleConnectionStatus.connected) {
        print(
            "[BleProvider] Attempting to sync time after Device Ready event...");
        syncTimeToDevice(); // <<< GỌI SYNC TIME KHI SẴN SÀNG >>>
      } else {
        print(
            "[BleProvider] Ignoring Device Ready event (unmounted or not connected).");
      }
    }, onError: (error) {
      print("!!! [BleProvider] Error in device ready stream: $error");
    });
  }
  // ----------------------------------------

  // Hàm xử lý khi trạng thái kết nối thay đổi (ĐƠN GIẢN HÓA)
  void _handleConnectionChange(BleConnectionStatus status) {
    if (!_mounted) return;
    print(
        "[BleProvider] Handling connection status change (from stream): $status");
    // Chỉ reset dữ liệu khi không còn kết nối
    if (status != BleConnectionStatus.connected &&
        status != BleConnectionStatus.connecting &&
        status != BleConnectionStatus.discovering_services) {
      if (_latestHealthData != null || latestHealthDataNotifier.value != null) {
        _latestHealthData = null;
        latestHealthDataNotifier.value = null;
        print(
            "[BleProvider] Cleared latest health data due to non-connected status.");
      }
      if (deviceWifiStatusNotifier.value != null) {
        deviceWifiStatusNotifier.value = null; // Reset cả trạng thái WiFi
        print("[BleProvider] Cleared device WiFi status.");
      }
    }
    // Không cần gọi syncTime ở đây nữa
    _notify(); // Vẫn notify để UI cập nhật trạng thái chung (chip BLE)
  }

  // Hàm tiện ích gọi notifyListeners
  void _notify() {
    if (_mounted && hasListeners) {
      notifyListeners();
    }
  }

  // --- Các hàm public gọi BleService (giữ nguyên) ---
  Future<void> startScan() async {
    _latestHealthData = null;
    latestHealthDataNotifier.value = null;
    deviceWifiStatusNotifier.value = null; // Reset status khi quét mới
    _notify();
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
  // -------------------------------------------------

  // Hàm gửi thời gian (giữ nguyên logic, gọi hàm ghi của BleService)
  Future<bool> syncTimeToDevice() async {
    if (!_mounted) return false;
    if (connectionStatus.value != BleConnectionStatus.connected) {
      return false;
    }
    try {
      final now = DateTime.now();
      final timeData = {
        'time': {
          'year': now.year, // Gửi năm đầy đủ (ví dụ: 2024)
          'month': now.month, // Gửi tháng dạng 1-12
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
      bool success =
          await _bleService.writeDataToDevice(dataBytes); // Gọi hàm ghi chung
      if (success)
        print("[BleProvider] Time sync command sent successfully.");
      else
        print(
            "[BleProvider] BleService reported failure sending time sync command.");
      return success;
    } catch (e) {
      print("!!! [BleProvider] Error creating/sending time sync data: $e");
      return false;
    }
  }

  // --- Hàm dispose (Cập nhật để hủy các subscription mới) ---
  @override
  void dispose() {
    print("Disposing BleProvider...");
    _mounted = false; // Đặt cờ false NGAY ĐẦU
    // Hủy tất cả các subscriptions
    _healthDataSub?.cancel();
    _connectionStatusSub?.cancel();
    _statusDataSub?.cancel(); // <<< HỦY STATUS SUB
    _deviceReadySub?.cancel(); // <<< HỦY DEVICE READY SUB
    // Hủy các listener cũ (nếu còn add)
    // try {
    //   _bleService.isScanning.removeListener(_notify);
    //   _bleService.scanResults.removeListener(_notify);
    // } catch (e) { /* ... */ }
    // Dispose các Notifier
    latestHealthDataNotifier.dispose();
    deviceWifiStatusNotifier.dispose(); // <<< DISPOSE STATUS NOTIFIER
    print("BleProvider disposed.");
    super.dispose();
  }
  // ----------------------------------------------------
}
