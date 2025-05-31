// lib/providers/ble_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ble_service.dart';
import '../models/health_data.dart';
import '../app_constants.dart';
import '../generated/app_localizations.dart';
import 'package:flutter/widgets.dart';

class BleProvider with ChangeNotifier {
  final BleService _bleService;

  // --- Getters cho các ValueNotifier từ BleService ---
  ValueNotifier<BleConnectionStatus> get connectionStatus =>
      _bleService.connectionStatus;
  ValueNotifier<List<ScanResult>> get scanResults => _bleService.scanResults;
  ValueNotifier<bool> get isScanning => _bleService.isScanning;
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  // --- State cục bộ của Provider ---
  HealthData? _latestHealthData;
  HealthData? get latestHealthData => _latestHealthData;

  // --- ValueNotifier cho State cục bộ ---
  final ValueNotifier<HealthData?> latestHealthDataNotifier =
      ValueNotifier(null);
  final ValueNotifier<bool?> deviceWifiStatusNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isReconnectingNotifier = ValueNotifier(false);

  // --- Subscriptions ---
  StreamSubscription? _healthDataSub;
  StreamSubscription? _connectionStatusSub;
  StreamSubscription? _statusDataSub;
  StreamSubscription? _deviceReadySub;
  VoidCallback? _scanResultsListener;

  // --- Cờ và trạng thái ---
  bool _mounted = true;
  bool _autoReconnectEnabled = true;

  BleProvider(this._bleService) {
    print("[BleProvider] Initializing...");
    _listenToHealthData();
    _listenToConnectionStatus();
    _listenToStatusUpdates();
    _listenToDeviceReady();
    _listenToScanResults();
    _tryReconnectOnInit();
    print("[BleProvider] Initialized and subscribed to BleService streams.");
  }

  // Lắng nghe thay đổi scanResults
  void _listenToScanResults() {
    _scanResultsListener = () {
      print(
          "[BleProvider] Scan results updated: ${scanResults.value.length} devices");
      _notify();
    };
    _bleService.scanResults.addListener(_scanResultsListener!);
  }

  // Lắng nghe dữ liệu HealthData
  void _listenToHealthData() {
    _healthDataSub?.cancel();
    _healthDataSub = _bleService.healthDataStream.listen(
      (data) {
        _latestHealthData = data;
        latestHealthDataNotifier.value = data;
        _notify();
      },
      onError: (error) {
        print("!!! [BleProvider] Error in health data stream: $error");
      },
    );
  }

  // Lắng nghe thay đổi trạng thái kết nối
  void _listenToConnectionStatus() {
    _connectionStatusSub?.cancel();
    _connectionStatusSub = _bleService.connectionStatusStream.listen((status) {
      print("[BleProvider] Connection status update: $status");
      _handleConnectionChange(status);
      if (status == BleConnectionStatus.connecting ||
          status == BleConnectionStatus.discovering_services) {
        isReconnectingNotifier.value = true;
      } else {
        isReconnectingNotifier.value = false;
      }
      _notify();
    }, onError: (error) {
      print("!!! [BleProvider] Error in connection status stream: $error");
      _handleConnectionChange(BleConnectionStatus.error);
      isReconnectingNotifier.value = false;
      _notify();
    });
  }

  void updateReconnectStatus(bool isReconnecting) {
    isReconnectingNotifier.value = isReconnecting;
    print("[BleProvider] Reconnect status updated: $isReconnecting");
    _notify();
  }

  // Lắng nghe cập nhật trạng thái từ ESP32
  void _listenToStatusUpdates() {
    _statusDataSub?.cancel();
    _statusDataSub = _bleService.statusStream.listen((statusData) {
      print("[BleProvider] Status update: $statusData");
      if (statusData.containsKey('wifi_status')) {
        bool? newWifiStatus;
        if (statusData['wifi_status'] == 'connected') {
          newWifiStatus = true;
        } else if (statusData['wifi_status'] == 'disconnected' ||
            statusData['wifi_status'] == 'connecting') {
          newWifiStatus = false;
        }
        if (deviceWifiStatusNotifier.value != newWifiStatus) {
          deviceWifiStatusNotifier.value = newWifiStatus;
          print("[BleProvider] Device WiFi status updated: $newWifiStatus");
        }
      }
      _notify();
    }, onError: (error) {
      print("!!! [BleProvider] Error in status update stream: $error");
    });
  }

  // Lắng nghe sự kiện Device Ready
  void _listenToDeviceReady() {
    _deviceReadySub?.cancel();
    _deviceReadySub = _bleService.deviceReadyStream.listen((_) {
      print("[BleProvider] Device Ready event received.");
      if (_mounted && connectionStatus.value == BleConnectionStatus.connected) {
        print("[BleProvider] Syncing time after Device Ready...");
        syncTimeToDevice();
      }
    }, onError: (error) {
      print("!!! [BleProvider] Error in device ready stream: $error");
    });
  }

  // Thử reconnect khi khởi tạo
  void _tryReconnectOnInit() {
    if (_autoReconnectEnabled) {
      print("[BleProvider] Checking for auto reconnect on initialization...");
      _bleService.setAutoReconnect(true);
      SharedPreferences.getInstance().then((prefs) {
        final lastDeviceId =
            prefs.getString(AppConstants.prefKeyConnectedDeviceId);
        if (lastDeviceId != null && _mounted) {
          print(
              "[BleProvider] Found last device ID: $lastDeviceId. Triggering reconnect...");
          updateReconnectStatus(true);
          _bleService.startScan(force: true);
        }
      });
    }
  }

  // Xử lý thay đổi trạng thái kết nối
  void _handleConnectionChange(BleConnectionStatus status) {
    if (!_mounted) return;
    print("[BleProvider] Handling connection status change: $status");
    if (status != BleConnectionStatus.connected &&
        status != BleConnectionStatus.connecting &&
        status != BleConnectionStatus.discovering_services) {
      if (_latestHealthData != null || latestHealthDataNotifier.value != null) {
        _latestHealthData = null;
        latestHealthDataNotifier.value = null;
        print("[BleProvider] Cleared health data due to non-connected status.");
      }
      if (deviceWifiStatusNotifier.value != null) {
        deviceWifiStatusNotifier.value = null;
        print("[BleProvider] Cleared WiFi status.");
      }
      updateReconnectStatus(false);
    } else if (status == BleConnectionStatus.connected) {
      print("[BleProvider] Connection established.");
      updateReconnectStatus(false);
    } else if (status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.discovering_services) {
      print("[BleProvider] Reconnect in progress...");
      updateReconnectStatus(true);
    }
    _notify();
  }

  // Hàm tiện ích gọi notifyListeners
  void _notify() {
    if (_mounted && hasListeners) {
      notifyListeners();
    }
  }

  // Bật/tắt auto reconnect
  void setAutoReconnect(bool enabled) {
    _autoReconnectEnabled = enabled;
    _bleService.setAutoReconnect(enabled);
    print("[BleProvider] Auto reconnect set to: $enabled");
    if (!enabled) {
      updateReconnectStatus(false);
    }
    _notify();
  }

  // Kích hoạt reconnect thủ công
  Future<void> tryReconnect() async {
    if (!_mounted || !_autoReconnectEnabled) {
      print(
          "[BleProvider] Reconnect ignored: Unmounted or auto reconnect disabled.");
      return;
    }
    print("[BleProvider] Triggering manual reconnect...");
    updateReconnectStatus(true);
    await _bleService.startScan(force: true);
    _notify();
  }

  // --- Các hàm public gọi BleService ---
  Future<void> startScan() async {
    _latestHealthData = null;
    latestHealthDataNotifier.value = null;
    deviceWifiStatusNotifier.value = null;
    _notify();
    await _bleService.startScan();
  }

  Future<void> stopScan() async {
    await _bleService.stopScan();
    _notify();
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await _bleService.connectToDevice(device);
    _notify();
  }

  Future<void> disconnectFromDevice() async {
    await _bleService.disconnectFromDevice();
    _notify();
  }

  Future<bool> sendWifiConfig(String ssid, String password) async {
    bool result = await _bleService.sendWifiConfig(ssid, password);
    _notify();
    return result;
  }

  Future<bool> syncTimeToDevice() async {
    if (!_mounted || connectionStatus.value != BleConnectionStatus.connected) {
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
      print("[BleProvider] Sending time data: $jsonString");
      bool success = await _bleService.writeDataToDevice(dataBytes);
      if (success) {
        print("[BleProvider] Time sync successful.");
      } else {
        print("[BleProvider] Time sync failed.");
      }
      _notify();
      return success;
    } catch (e) {
      print("!!! [BleProvider] Error sending time sync data: $e");
      return false;
    }
  }

  // --- Dispose ---
  @override
  void dispose() {
    print("Disposing BleProvider...");
    _mounted = false;
    _healthDataSub?.cancel();
    _connectionStatusSub?.cancel();
    _statusDataSub?.cancel();
    _deviceReadySub?.cancel();
    if (_scanResultsListener != null) {
      _bleService.scanResults.removeListener(_scanResultsListener!);
    }
    latestHealthDataNotifier.dispose();
    deviceWifiStatusNotifier.dispose();
    isReconnectingNotifier.dispose();
    _bleService.setAutoReconnect(false);
    print("BleProvider disposed.");
    super.dispose();
  }

  void clearDataOnLogout() {
    print("[BleProvider] Clearing data on logout.");
    _latestHealthData = null;
    latestHealthDataNotifier.value = null;
    deviceWifiStatusNotifier.value = null;
    updateReconnectStatus(false);
    _notify();
  }
}
