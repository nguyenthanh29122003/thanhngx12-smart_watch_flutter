// lib/services/ble_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

import '../generated/app_localizations.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'local_db_service.dart';
import 'connectivity_service.dart';
import '../models/health_data.dart';
import '../models/navigation_data.dart';
import '../app_constants.dart';
import 'notification_service.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  discovering_services,
  error,
}

class BleService {
  // --- Value Notifiers cho UI truy cập trạng thái hiện tại ---
  final ValueNotifier<BleConnectionStatus> connectionStatus =
      ValueNotifier(BleConnectionStatus.disconnected);
  final ValueNotifier<List<ScanResult>> scanResults = ValueNotifier([]);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  // --- Stream Controllers để phân phối dữ liệu/trạng thái ---
  final StreamController<HealthData> _healthDataStreamController =
      StreamController<HealthData>.broadcast();
  final StreamController<Map<String, dynamic>> _statusStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<BleConnectionStatus> _connectionStatusController =
      StreamController<BleConnectionStatus>.broadcast();
  final StreamController<void> _deviceReadyController =
      StreamController<void>.broadcast();

  // --- Getters cho Streams ---
  Stream<HealthData> get healthDataStream => _healthDataStreamController.stream;
  Stream<Map<String, dynamic>> get statusStream =>
      _statusStreamController.stream;
  Stream<BleConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;
  Stream<void> get deviceReadyStream => _deviceReadyController.stream;

  // --- Dependencies ---
  final AuthService _authService;
  final FirestoreService _firestoreService;
  final LocalDbService _localDbService;
  final ConnectivityService _connectivityService;
  final NotificationService _notificationService;

  // --- Auto Reconnect ---
  bool _autoReconnectEnabled = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 5);
  String? _lastConnectedDeviceId;
  Timer? _reconnectTimer;

  // --- Trạng thái nội bộ ---
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _healthCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _statusCharacteristic;
  BluetoothCharacteristic? _navigationCharacteristic;

  // --- Subscriptions ---
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _healthDataSubscription;
  StreamSubscription? _statusDataSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  BleService(
    this._authService,
    this._firestoreService,
    this._localDbService,
    this._connectivityService,
    this._notificationService,
  ) {
    _listenToAdapterState();
    print("[BleService] Initialized.");
  }

  void _listenToAdapterState() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      print("[BleService] Bluetooth Adapter State Changed: $state");
      if (state == BluetoothAdapterState.off) {
        _handleDisconnect(
            isError: false, clearDevice: true, reason: "Bluetooth turned off");
      }
    });
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    List<Permission> permissionsToRequest = [];
    if (Platform.isAndroid) {
      permissionsToRequest.addAll([
        Permission.location,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ]);
    } else if (Platform.isIOS) {
      permissionsToRequest.addAll([
        Permission.bluetooth,
        Permission.locationWhenInUse,
      ]);
    }
    if (permissionsToRequest.isEmpty) return true;
    print("[BleService] Requesting permissions: $permissionsToRequest");
    statuses = await permissionsToRequest.request();
    bool allGranted = true;
    statuses.forEach((p, s) {
      if (!s.isGranted) allGranted = false;
    });
    if (!allGranted)
      print("!!! [BleService] BLE Permissions Denied.");
    else
      print("[BleService] All necessary BLE Permissions Granted.");
    return allGranted;
  }

  Future<void> startScan({bool force = false}) async {
    if (isScanning.value && !force) {
      print("[BleService] Already scanning.");
      return;
    }
    if (!await _requestPermissions()) {
      _updateStatus(BleConnectionStatus.error, "Permissions denied");
      return;
    }
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      _updateStatus(BleConnectionStatus.error, "Bluetooth is off");
      return;
    }

    _updateStatus(BleConnectionStatus.scanning, "Scan started");
    scanResults.value = [];

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _isScanningSubscription?.cancel();

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
        if (isScanning.value != state) {
          isScanning.value = state;
        }
        if (!state && connectionStatus.value == BleConnectionStatus.scanning) {
          _updateStatus(
              BleConnectionStatus.disconnected, "Scan finished/stopped");
        }
      });

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        final List<ScanResult> currentScanResults = scanResults.value.toList();
        final List<ScanResult> newFound = [];
        for (var r in results) {
          print(
              "[BleService] Found device: ${r.device.platformName}, ID: ${r.device.remoteId}, RSSI: ${r.rssi}");
          if (r.device.platformName.contains(AppConstants.targetDeviceName) &&
              !currentScanResults
                  .any((old) => old.device.remoteId == r.device.remoteId)) {
            newFound.add(r);
          }
        }
        if (newFound.isNotEmpty) {
          scanResults.value = [...currentScanResults, ...newFound];
          print(
              "[BleService] Added ${newFound.length} new matching device(s). Total: ${scanResults.value.length}");
        }
      }, onError: (error) {
        print("!!! [BleService] Scan Error: $error");
        _updateStatus(BleConnectionStatus.error, "Scan error");
      });

      print("[BleService] Starting BLE Scan (timeout 15s)...");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print("!!! [BleService] Error during scan process: $e");
      _cleanUpScanSubscriptions();
      _updateStatus(BleConnectionStatus.error, "Error starting scan");
      isScanning.value = false;
    }
  }

  Future<void> stopScan() async {
    if (!isScanning.value) {
      print("[BleService] Scan already stopped, ignoring.");
      return;
    }
    try {
      await FlutterBluePlus.stopScan();
      print("[BleService] Scan manually stopped.");
    } catch (e) {
      print("!!! [BleService] Error stopping scan: $e");
    } finally {
      _cleanUpScanSubscriptions();
    }
  }

  void _cleanUpScanSubscriptions() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanningSubscription?.cancel();
    _isScanningSubscription = null;
    if (isScanning.value) isScanning.value = false;
    if (connectionStatus.value == BleConnectionStatus.scanning) {
      _updateStatus(BleConnectionStatus.disconnected, "Scan stopped");
    }
  }

  bool _areScanListsEqual(List<ScanResult> list1, List<ScanResult> list2) {
    if (list1.length != list2.length) return false;
    final ids1 = list1.map((r) => r.device.remoteId).toSet();
    final ids2 = list2.map((r) => r.device.remoteId).toSet();
    return setEquals(ids1, ids2);
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (connectionStatus.value == BleConnectionStatus.connecting ||
        connectionStatus.value == BleConnectionStatus.connected) {
      print(
          "[BleService] Connection attempt ignored: Already connecting or connected to ${connectedDevice?.remoteId}");
      return;
    }
    if (isScanning.value) await stopScan();

    print(
        "[BleService] Attempting connection to ${device.platformName} (${device.remoteId})");
    _updateStatus(BleConnectionStatus.connecting, "Connecting...");
    _connectionStateSubscription?.cancel();

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      print("[BleService] connect() Future completed.");

      if (device.isConnected) {
        print(
            "[BleService] device.isConnected is true. Proceeding to discover services.");
        _connectedDevice = device;
        _lastConnectedDeviceId = device.remoteId.toString();
        _reconnectAttempts = 0;

        _connectionStateSubscription = device.connectionState
            .where((state) => state == BluetoothConnectionState.disconnected)
            .listen((state) {
          _handleDisconnect(
              isError: false, reason: "Device disconnected event");
        }, onError: (error) {
          _handleDisconnect(
              isError: true, reason: "Connection state stream error");
        });

        _updateStatus(BleConnectionStatus.discovering_services,
            "Discovering services...");
        await _discoverServicesAndSubscribe(device);
      } else {
        print(
            "!!! [BleService] connect() Future completed but device is not connected.");
        _handleDisconnect(
            isError: true, reason: "Connection failed after connect call");
      }
    } catch (e) {
      print("!!! [BleService] Error during connect: $e");
      _handleDisconnect(isError: true, reason: "Connection failed: $e");
    }
  }

  Future<bool> syncTime() async {
    // Hàm này đóng gói logic tạo JSON và gọi hàm ghi dữ liệu
    if (_writeCharacteristic == null) {
      if (kDebugMode)
        print(
            "!!! [BleService] Time sync failed: Write Characteristic is null.");
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
      final bytesToSend = utf8.encode(jsonString);

      if (kDebugMode)
        print("[BleService] Sending Time Sync command: $jsonString");
      return await writeDataToDevice(_writeCharacteristic!, bytesToSend);
    } catch (e) {
      if (kDebugMode)
        print("!!! [BleService] Error encoding or sending time sync data: $e");
      return false;
    }
  }

  Future<void> disconnectFromDevice() async {
    final deviceToDisconnect = _connectedDevice;
    if (deviceToDisconnect == null) {
      print("[BleService] No device currently connected.");
      if (connectionStatus.value != BleConnectionStatus.disconnected) {
        _handleDisconnect(
            isError: false, clearDevice: true, reason: "No device connected");
      }
      return;
    }

    print(
        "[BleService] Initiating disconnect from ${deviceToDisconnect.remoteId}...");
    _handleDisconnect(
        isError: false, clearDevice: true, reason: "Manual disconnect");
    try {
      await deviceToDisconnect.disconnect();
      print("[BleService] Disconnect call completed.");
    } catch (e) {
      print("!!! [BleService] Error during disconnect: $e");
    }
  }

  void _handleDisconnect({
    bool isError = false,
    bool clearDevice = false,
    String reason = "Unknown",
  }) {
    print("[BleService] Handling disconnect: IsError=$isError, Reason=$reason");
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    _statusDataSubscription?.cancel();
    _statusDataSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _healthCharacteristic = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;

    final deviceIdBefore = _connectedDevice?.remoteId;
    if (clearDevice) {
      _connectedDevice = null;
      _lastConnectedDeviceId = null;
      _reconnectAttempts = 0;
    } else if (deviceIdBefore != null) {
      _lastConnectedDeviceId = deviceIdBefore.toString();
    }

    _updateStatus(
        isError ? BleConnectionStatus.error : BleConnectionStatus.disconnected,
        reason);

    if (_autoReconnectEnabled &&
        !clearDevice &&
        isError &&
        _lastConnectedDeviceId != null &&
        _reconnectAttempts < _maxReconnectAttempts) {
      print(
          "[BleService] Scheduling auto reconnect attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts...");
      _reconnectTimer = Timer(_reconnectDelay, () {
        _attemptReconnect();
      });
    }
  }

  Future<void> _attemptReconnect() async {
    if (_lastConnectedDeviceId == null) {
      print("[BleService] No device ID saved for reconnect.");
      _reconnectAttempts = 0;
      return;
    }

    if (connectionStatus.value == BleConnectionStatus.connected ||
        connectionStatus.value == BleConnectionStatus.connecting) {
      print("[BleService] Device already connected or connecting.");
      _reconnectAttempts = 0;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(AppConstants.prefKeyLanguageCode) ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final locale = Locale(localeCode);
    final l10n = lookupAppLocalizations(locale);

    _reconnectAttempts++;
    print(
        "[BleService] Attempting reconnect ($_reconnectAttempts/$_maxReconnectAttempts)...");
    if (_reconnectAttempts == 1) {
      await _notificationService.showSimpleNotification(
        id: 6,
        title: l10n.reconnectAttemptTitle,
        body: l10n.reconnectAttemptBody,
        channelId: AppConstants.bleReconnectChannelId,
        channelName: l10n.bleReconnectChannelName,
        channelDescription: AppConstants.bleReconnectChannelDescription,
        payload: "reconnect_attempt",
      );
    }

    BluetoothDevice? targetDevice;
    for (var result in scanResults.value) {
      if (result.device.remoteId.toString() == _lastConnectedDeviceId) {
        targetDevice = result.device;
        break;
      }
    }

    if (targetDevice == null) {
      print(
          "[BleService] Device not found in recent scan. Starting new scan...");
      await startScan(force: true);
      await Future.delayed(const Duration(seconds: 15));
      for (var result in scanResults.value) {
        if (result.device.remoteId.toString() == _lastConnectedDeviceId) {
          targetDevice = result.device;
          break;
        }
      }
    }

    if (targetDevice == null) {
      print("[BleService] Reconnect failed: Device not found.");
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        print("[BleService] Max reconnect attempts reached.");
        await _notificationService.showSimpleNotification(
          id: 5,
          title: l10n.reconnectFailedTitle,
          body: l10n.reconnectFailedBody(_maxReconnectAttempts.toString()),
          channelId: AppConstants.bleReconnectChannelId,
          channelName: l10n.bleReconnectChannelName,
          channelDescription: AppConstants.bleReconnectChannelDescription,
          payload: "reconnect_failed",
        );
        _updateStatus(BleConnectionStatus.error, "Reconnect failed");
        _reconnectAttempts = 0;
        _lastConnectedDeviceId = null;
      } else {
        _reconnectTimer = Timer(_reconnectDelay, () {
          _attemptReconnect();
        });
      }
      return;
    }
    await _notificationService.cancelNotification(6);
    try {
      await connectToDevice(targetDevice);
      if (connectionStatus.value == BleConnectionStatus.connected) {
        await _notificationService.showSimpleNotification(
          id: 4,
          title: l10n.reconnectSuccessTitle,
          body: l10n.reconnectSuccessBody,
          channelId: AppConstants.bleReconnectChannelId,
          channelName: l10n.bleReconnectChannelName,
          channelDescription: AppConstants.bleReconnectChannelDescription,
          payload: "reconnect_success",
        );
        _reconnectAttempts = 0;
      }
    } catch (e) {
      print("[BleService] Reconnect attempt failed: $e");
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        await _notificationService.showSimpleNotification(
          id: 5,
          title: l10n.reconnectFailedTitle,
          body: l10n.reconnectFailedBody(_maxReconnectAttempts.toString()),
          channelId: AppConstants.bleReconnectChannelId,
          channelName: l10n.bleReconnectChannelName,
          channelDescription: AppConstants.bleReconnectChannelDescription,
          payload: "reconnect_failed",
        );
        _updateStatus(BleConnectionStatus.error, "Reconnect failed");
        _reconnectAttempts = 0;
        _lastConnectedDeviceId = null;
      } else {
        _reconnectTimer = Timer(_reconnectDelay, () {
          _attemptReconnect();
        });
      }
    }
  }

  void _updateStatus(BleConnectionStatus newStatus, String reason) {
    if (connectionStatus.value != newStatus) {
      print(
          "[BleService] Status changing: ${connectionStatus.value} -> $newStatus (Reason: $reason)");
      connectionStatus.value = newStatus;
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(newStatus);
      }
    }
  }

  Future<void> _discoverServicesAndSubscribe(BluetoothDevice device) async {
    print("[BleService] Discovering services...");
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
      print("[BleService] Discovered ${services.length} services.");
    } catch (e) {
      print("!!! [BleService] Error discovering services: $e");
      _handleDisconnect(isError: true, reason: "Service discovery failed");
      return;
    }

    _healthCharacteristic = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;
    _navigationCharacteristic = null;
    bool foundTargetService = false;

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() ==
          AppConstants.bleServiceUUID.toLowerCase()) {
        foundTargetService = true;
        print("+++ [BleService] Matched Target Service: ${service.uuid}");
        for (var char in service.characteristics) {
          String charUUID = char.uuid.toString().toLowerCase();
          bool isHealth = charUUID ==
              AppConstants.healthDataCharacteristicUUID.toLowerCase();
          bool isWrite = charUUID ==
              AppConstants.wifiConfigCharacteristicUUID.toLowerCase();
          bool isStatus =
              charUUID == AppConstants.statusCharacteristicUUID.toLowerCase();
          bool isNavigation = charUUID ==
              AppConstants.navigationCharacteristicUUID.toLowerCase();

          if (isHealth && char.properties.notify) {
            _healthCharacteristic = char;
            print("+++ Stored Health Char (Notify OK)");
          }
          if (isWrite && char.properties.write) {
            _writeCharacteristic = char;
            print("+++ Stored Write Char (Write OK)");
          }
          if (isStatus && char.properties.notify) {
            _statusCharacteristic = char;
            print("+++ Stored Status Char (Notify OK)");
          }
          if (isNavigation && char.properties.write) {
            _navigationCharacteristic = char;
            print("+++ Stored Navigation Char (Write OK)");
          }
        }
        break;
      }
    }

    if (!foundTargetService) {
      _handleDisconnect(isError: true, reason: "Target service not found");
      return;
    }

    if (_healthCharacteristic != null &&
        _writeCharacteristic != null &&
        _statusCharacteristic != null &&
        _navigationCharacteristic != null) {
      print("[BleService] All characteristics found. Subscribing...");
      List<Future<bool>> subsFutures = [
        _subscribeToHealthData(_healthCharacteristic!),
        _subscribeToStatusUpdates(_statusCharacteristic!),
      ];
      try {
        List<bool> subResults =
            await Future.wait(subsFutures).timeout(const Duration(seconds: 10));
        bool allSubscribed = subResults.every((ok) => ok);

        if (allSubscribed &&
            connectionStatus.value != BleConnectionStatus.disconnected &&
            connectionStatus.value != BleConnectionStatus.error) {
          _updateStatus(BleConnectionStatus.connected, "Connected");
          print("[BleService] Device setup complete.");
          if (!_deviceReadyController.isClosed) {
            _deviceReadyController.add(null);
          }
        } else {
          _handleDisconnect(isError: true, reason: "Subscription failed");
        }
      } catch (e) {
        print("!!! [BleService] Error during subscription: $e");
        _handleDisconnect(isError: true, reason: "Subscription error");
      }
    } else {
      String missing = "";
      if (_healthCharacteristic == null) missing += "Health(N) ";
      if (_writeCharacteristic == null) missing += "Config(W) ";
      if (_statusCharacteristic == null) missing += "Status(N)";
      if (_navigationCharacteristic == null) missing += "Navigation(W) ";
      print("!!! [BleService] Missing characteristic(s): $missing");
      _handleDisconnect(isError: true, reason: "Missing characteristics");
    }
  }

  Future<bool> sendNavigationData(NavigationData navData) async {
    // Kiểm tra xem characteristic có tồn tại không
    if (_navigationCharacteristic == null) {
      if (kDebugMode)
        print(
            "!!! [BleService] Navigation Characteristic is null. Cannot send.");
      return false;
    }

    // Chuyển đối tượng NavigationData thành chuỗi JSON, rồi thành mảng byte
    try {
      final jsonString = jsonEncode(navData.toJson());
      final bytesToSend = utf8.encode(jsonString);

      if (kDebugMode)
        print("[BleService] Sending Navigation Data: $jsonString");

      // Gọi hàm writeDataToDevice để gửi (giả sử bạn đã tái cấu trúc nó, nếu không thì copy logic write)
      return await writeDataToDevice(_navigationCharacteristic!, bytesToSend);
    } catch (e) {
      if (kDebugMode)
        print("!!! [BleService] Error encoding or sending navigation data: $e");
      return false;
    }
  }

  Future<bool> _subscribeToHealthData(
      BluetoothCharacteristic characteristic) async {
    print("[BleService] Subscribing to Health Data...");
    await _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    try {
      await characteristic.setNotifyValue(true);
      _healthDataSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          try {
            final jsonString = utf8.decode(value, allowMalformed: true);
            final jsonData = jsonDecode(jsonString);
            final data = HealthData.fromJson(jsonData);
            final user = _authService.currentUser;
            if (user != null) {
              if (_connectivityService.isOnline()) {
                _firestoreService.saveHealthData(user.uid, data);
              } else {
                _localDbService.saveHealthRecordLocally(data);
              }
            }
            if (!_healthDataStreamController.isClosed) {
              _healthDataStreamController.add(data);
            }
            _checkThresholdsAndNotify(data);
          } catch (e) {
            print("!!! [BleService] Error processing health data: $e");
          }
        },
        onError: (error) {
          print("!!! [BleService] Health data stream error: $error");
        },
        onDone: () {
          print("[BleService] Health data stream closed.");
        },
        cancelOnError: false,
      );
      print("[BleService] Health Data subscription successful.");
      return true;
    } catch (e) {
      print("!!! [BleService] Error subscribing to Health Data: $e");
      return false;
    }
  }

  Future<bool> _subscribeToStatusUpdates(
      BluetoothCharacteristic characteristic) async {
    print("[BleService] Subscribing to Status Updates...");
    await _statusDataSubscription?.cancel();
    _statusDataSubscription = null;
    try {
      await characteristic.setNotifyValue(true);
      _statusDataSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          try {
            final jsonString = utf8.decode(value, allowMalformed: true);
            final statusData = jsonDecode(jsonString) as Map<String, dynamic>;
            if (!_statusStreamController.isClosed) {
              _statusStreamController.add(statusData);
            }
          } catch (e) {
            print("!!! [BleService] Error processing status: $e");
          }
        },
        onError: (error) {
          print("!!! [BleService] Status stream error: $error");
        },
        onDone: () {
          print("[BleService] Status stream closed.");
        },
        cancelOnError: false,
      );
      print("[BleService] Status Updates subscription successful.");
      return true;
    } catch (e) {
      print("!!! [BleService] Error subscribing to Status Updates: $e");
      return false;
    }
  }

  Future<bool> writeDataToDevice(
      BluetoothCharacteristic characteristic, List<int> dataToWrite) async {
    if (connectionStatus.value != BleConnectionStatus.connected) {
      if (kDebugMode) print("!!! [BleService] Device not connected for write.");
      return false;
    }
    try {
      if (kDebugMode)
        print(
            "[BleService] Writing ${dataToWrite.length} bytes to ${characteristic.uuid}...");
      // Ghi dữ liệu, `withoutResponse: false` có nghĩa là đợi xác nhận từ thiết bị
      await characteristic.write(dataToWrite, withoutResponse: false);
      if (kDebugMode) print("[BleService] Write successful.");
      return true;
    } catch (e) {
      if (kDebugMode) print("!!! [BleService] Error writing data: $e");
      _updateStatus(BleConnectionStatus.error, "Write failed");
      return false;
    }
  }

  Future<bool> sendWifiConfig(String ssid, String password) async {
    if (_writeCharacteristic == null) {
      if (kDebugMode)
        print("!!! [BleService] WiFi Write Characteristic is null!");
      return false;
    }
    try {
      Map<String, String> configData = {'ssid': ssid, 'password': password};
      String jsonString = jsonEncode(configData);
      List<int> bytesToSend = utf8.encode(jsonString);
      if (kDebugMode) print("[BleService] Sending WiFi config: $jsonString");
      return await writeDataToDevice(_writeCharacteristic!, bytesToSend);
    } catch (e) {
      if (kDebugMode) print("!!! [BleService] Error encoding WiFi config: $e");
      return false;
    }
  }

  DateTime? _lastHighHrNotificationTime;
  DateTime? _lastLowHrNotificationTime;
  DateTime? _lastLowSpo2NotificationTime;
  final Duration _notificationCooldown = const Duration(minutes: 5);

  Future<void> _checkThresholdsAndNotify(HealthData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool notificationsEnabled =
          prefs.getBool(AppConstants.prefKeyNotificationsEnabled) ?? true;
      if (!notificationsEnabled) return;

      final localeCode = prefs.getString(AppConstants.prefKeyLanguageCode) ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final locale = Locale(localeCode);
      final l10n = lookupAppLocalizations(locale);

      final now = DateTime.now();

      if (data.hr > AppConstants.hrHighThreshold && data.hr > 0) {
        if (_lastHighHrNotificationTime == null ||
            now.difference(_lastHighHrNotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: High Heart Rate: ${data.hr}");
          _notificationService.showSimpleNotification(
              id: 1,
              title: l10n.alertHrHighTitle,
              body: l10n.alertHrHighBody(
                  data.hr.toString(), AppConstants.hrHighThreshold.toString()),
              channelId: 'health_alerts_hr_high',
              channelName: l10n.channelNameHrHigh,
              payload: 'alert_hr_high');
          _lastHighHrNotificationTime = now;
        }
      }
      if (data.hr < AppConstants.hrLowThreshold && data.hr > 0) {
        if (_lastLowHrNotificationTime == null ||
            now.difference(_lastLowHrNotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: Low Heart Rate: ${data.hr}");
          _notificationService.showSimpleNotification(
              id: 2,
              title: l10n.alertHrLowTitle,
              body: l10n.alertHrLowBody(
                  data.hr.toString(), AppConstants.hrLowThreshold.toString()),
              channelId: 'health_alerts_hr_low',
              channelName: l10n.channelNameHrLow,
              payload: 'alert_hr_low');
          _lastLowHrNotificationTime = now;
        }
      }
      if (data.spo2 < AppConstants.spo2LowThreshold && data.spo2 > 0) {
        if (_lastLowSpo2NotificationTime == null ||
            now.difference(_lastLowSpo2NotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: Low SpO2: ${data.spo2}");
          _notificationService.showSimpleNotification(
              id: 3,
              title: l10n.alertSpo2LowTitle,
              body: l10n.alertSpo2LowBody(data.spo2.toString(),
                  AppConstants.spo2LowThreshold.toString()),
              channelId: 'health_alerts_spo2_low',
              channelName: l10n.channelNameSpo2Low,
              payload: 'alert_spo2_low');
          _lastLowSpo2NotificationTime = now;
        }
      }
    } catch (e) {
      print("!!! [BleService] Error checking thresholds: $e");
    }
  }

  void setAutoReconnect(bool enabled) {
    _autoReconnectEnabled = enabled;
    print("[BleService] Auto reconnect set to: $enabled");
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnectAttempts = 0;
    }
  }

  void dispose() {
    print("[BleService] Disposing...");
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _statusDataSubscription?.cancel();
    _reconnectTimer?.cancel();
    _healthDataStreamController.close();
    _statusStreamController.close();
    _connectionStatusController.close();
    _deviceReadyController.close();

    final device = _connectedDevice;
    if (device != null &&
        connectionStatus.value != BleConnectionStatus.disconnected) {
      print("[BleService] Disconnecting device on dispose...");
      device.disconnect().catchError((e) {
        print("!!! [BleService] Error disconnecting on dispose: $e");
      });
    }
    _connectedDevice = null;
    _lastConnectedDeviceId = null;
    _reconnectAttempts = 0;
    _healthCharacteristic = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;
    print("[BleService] Disposed.");
  }
}
