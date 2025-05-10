// lib/services/ble_service.dart
import 'dart:async';
import 'dart:convert'; // Để mã hóa/giải mã JSON
import 'dart:io'; // Để kiểm tra Platform
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<< Cần cho đọc cài đặt và locale
import 'package:flutter/widgets.dart'; // <<< Cần cho Locale

import '../generated/app_localizations.dart'; // <<< Import cho l10n lookup
import 'auth_service.dart';
import 'firestore_service.dart'; // Service đã sửa saveHealthData
import 'local_db_service.dart';
import 'connectivity_service.dart';
import '../models/health_data.dart'; // Model đã cập nhật
import '../app_constants.dart'; // Constants đã cập nhật
import 'notification_service.dart';

enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected, // <<< Sẽ dùng trạng thái này khi mọi thứ sẵn sàng
  discovering_services,
  error,
}

class BleService {
  // --- Value Notifiers cho UI truy cập trạng thái hiện tại ---
  final ValueNotifier<BleConnectionStatus> connectionStatus =
      ValueNotifier(BleConnectionStatus.disconnected);
  final ValueNotifier<List<ScanResult>> scanResults = ValueNotifier([]);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  // --- Stream Controllers để phân phối dữ liệu/trạng thái cho các listeners khác (Provider) ---
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

  // --- Trạng thái nội bộ ---
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _healthCharacteristic; // Đọc HealthData (Notify)
  BluetoothCharacteristic? _writeCharacteristic; // Ghi Config (Write)
  BluetoothCharacteristic? _statusCharacteristic; // Đọc Status (Notify)

  // --- Subscriptions ---
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _healthDataSubscription;
  StreamSubscription? _statusDataSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Constructor
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

  // --- Quản lý Trạng thái Adapter và Quyền ---
  void _listenToAdapterState() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      print("[BleService] Bluetooth Adapter State Changed: $state");
      if (state == BluetoothAdapterState.off) {
        _handleDisconnect(
            isError: false, clearDevice: true, reason: "Bluetooth turned off");
      }
      // TODO: Có thể xử lý trạng thái turningOn/turningOff nếu cần
    });
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};
    List<Permission> permissionsToRequest = [];
    // ... (logic request permission giữ nguyên) ...
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

  // --- Quản lý Quét Thiết bị ---
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
    scanResults.value = []; // Xóa kết quả cũ

    try {
      await FlutterBluePlus.stopScan(); // Dừng quét cũ (nếu có)
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
        // Lọc theo tên và cập nhật nếu danh sách thay đổi
        final List<ScanResult> currentScanResults = scanResults.value.toList();
        final List<ScanResult> newFound = [];
        for (var r in results) {
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
    // Chỉ reset status nếu đang scanning
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

  // --- Quản lý Kết nối ---
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
    _connectionStateSubscription
        ?.cancel(); // Hủy listener cũ trước khi kết nối mới

    try {
      await device.connect(
          timeout: const Duration(seconds: 15)); // Timeout kết nối
      print("[BleService] connect() Future completed.");

      // Kiểm tra lại trạng thái ngay sau khi Future hoàn thành
      if (device.isConnected) {
        print(
            "[BleService] device.isConnected is true. Proceeding to discover services.");
        _connectedDevice = device; // Lưu thiết bị đã kết nối

        // Bắt đầu lắng nghe trạng thái ngắt kết nối TỪ BÂY GIỜ
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
        await _discoverServicesAndSubscribe(device); // Khám phá và subscribe
      } else {
        print(
            "!!! [BleService] connect() Future completed but device is not connected. Handling disconnect.");
        _handleDisconnect(
            isError: true,
            reason: "Connection failed immediately after connect call");
      }
    } catch (e) {
      print(
          "!!! [BleService] Error during connect() or subsequent operations for ${device.remoteId}: $e");
      // Đảm bảo trạng thái là lỗi nếu đang connecting
      if (connectionStatus.value == BleConnectionStatus.connecting ||
          connectionStatus.value == BleConnectionStatus.discovering_services) {
        _handleDisconnect(
            isError: true,
            reason: "Connection/Discovery failed: ${e.runtimeType}");
      }
    }
  }

  Future<void> disconnectFromDevice() async {
    final deviceToDisconnect =
        _connectedDevice; // Lấy tham chiếu trước khi reset
    if (deviceToDisconnect == null) {
      print("[BleService] No device currently connected.");
      // Đảm bảo trạng thái là disconnected nếu chưa phải
      if (connectionStatus.value != BleConnectionStatus.disconnected) {
        _handleDisconnect(
            isError: false,
            clearDevice: true,
            reason: "Disconnect called with no device");
      }
      return;
    }

    print(
        "[BleService] Initiating disconnect from ${deviceToDisconnect.remoteId}...");
    // Reset trạng thái nội bộ và hủy listeners trước khi gọi disconnect
    _handleDisconnect(
        isError: false,
        clearDevice: true,
        reason: "Manual disconnect initiated");
    try {
      await deviceToDisconnect
          .disconnect(); // Gọi hàm disconnect của flutter_blue_plus
      print(
          "[BleService] Disconnect call completed for ${deviceToDisconnect.remoteId}.");
    } catch (e) {
      print("!!! [BleService] Error during physical disconnect call: $e");
      // Trạng thái đã được xử lý trong _handleDisconnect
    }
  }

  // Xử lý ngắt kết nối hoặc lỗi
  void _handleDisconnect(
      {bool isError = false,
      bool clearDevice = false,
      String reason = "Unknown"}) {
    print(
        "[BleService] Handling disconnect/error: IsError=$isError, ClearDevice=$clearDevice, Reason=$reason");
    // Hủy tất cả các subscriptions liên quan đến device
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    _statusDataSubscription?.cancel();
    _statusDataSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Reset các characteristics
    _healthCharacteristic = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;

    final deviceIdBefore = _connectedDevice?.remoteId;
    if (clearDevice || !isError) {
      _connectedDevice = null; // Xóa tham chiếu thiết bị
    }

    // Cập nhật trạng thái cuối cùng
    _updateStatus(
        isError ? BleConnectionStatus.error : BleConnectionStatus.disconnected,
        reason);

    if (deviceIdBefore != null && _connectedDevice == null)
      print(
          "[BleService] Device $deviceIdBefore fully disconnected internally.");
    else if (isError && _connectedDevice != null)
      print(
          "[BleService] Device ${_connectedDevice?.remoteId} encountered error, internal ref kept (will be cleared on next disconnect).");
  }

  // Cập nhật trạng thái và thông báo listeners
  void _updateStatus(BleConnectionStatus newStatus, String reason) {
    if (connectionStatus.value != newStatus) {
      print(
          "[BleService] Status changing: ${connectionStatus.value} -> $newStatus (Reason: $reason)");
      connectionStatus.value = newStatus;
      // Đẩy trạng thái mới vào stream controller
      if (!_connectionStatusController.isClosed) {
        _connectionStatusController.add(newStatus);
      }
    } else {
      // Log nếu lý do thay đổi nhưng status không đổi (hữu ích để debug)
      // print("[BleService] Status unchanged (${connectionStatus.value}) but reason updated: $reason");
    }
  }

  // --- Khám phá Services và Subscribe ---
  Future<void> _discoverServicesAndSubscribe(BluetoothDevice device) async {
    print("[BleService] Discovering services for ${device.remoteId}...");
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
    bool foundTargetService = false;

    // Tìm đúng Service và Characteristics
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

          if (isHealth && !char.properties.notify)
            print("!!! Health Char incorrect properties!");
          if (isWrite && !char.properties.write)
            print("!!! Write Char incorrect properties!");
          if (isStatus && !char.properties.notify)
            print("!!! Status Char incorrect properties!");
        }
        break;
      }
    }

    if (!foundTargetService) {
      _handleDisconnect(isError: true, reason: "Target service not found");
      return;
    }

    // Kiểm tra và Subscribe
    if (_healthCharacteristic != null &&
        _writeCharacteristic != null &&
        _statusCharacteristic != null) {
      print("[BleService] All required characteristics found. Subscribing...");
      // Subscribe song song để tăng tốc
      List<Future<bool>> subsFutures = [
        _subscribeToHealthData(_healthCharacteristic!),
        _subscribeToStatusUpdates(_statusCharacteristic!),
      ];
      try {
        List<bool> subResults = await Future.wait(subsFutures)
            .timeout(const Duration(seconds: 10)); // Timeout cho subscribe
        bool allSubscribed =
            subResults.every((ok) => ok); // Kiểm tra tất cả thành công

        if (allSubscribed &&
            connectionStatus.value != BleConnectionStatus.disconnected &&
            connectionStatus.value != BleConnectionStatus.error) {
          _updateStatus(BleConnectionStatus.connected,
              "Connected and characteristics ready");
          print("[BleService] Device setup complete. Status: Connected.");
          if (!_deviceReadyController.isClosed) {
            _deviceReadyController.add(null);
          } // Phát sự kiện sẵn sàng
        } else {
          print(
              "!!! [BleService] Failed to subscribe to one or more characteristics ($subResults). Disconnecting.");
          _handleDisconnect(isError: true, reason: "Subscription failed");
        }
      } catch (e) {
        print("!!! [BleService] Error during subscription process: $e");
        _handleDisconnect(isError: true, reason: "Subscription error/timeout");
      }
    } else {
      // Xác định char nào bị thiếu
      String missing = "";
      if (_healthCharacteristic == null) missing += "Health(N) ";
      if (_writeCharacteristic == null) missing += "Config(W) ";
      if (_statusCharacteristic == null) missing += "Status(N)";
      print(
          "!!! [BleService] Missing characteristic(s): $missing. Connection failed.");
      _handleDisconnect(
          isError: true, reason: "Missing characteristic(s): $missing");
    }
  }

  // --- Subscribe Health Data ---
  Future<bool> _subscribeToHealthData(
      BluetoothCharacteristic characteristic) async {
    print(
        "[BleService] Subscribing to Health Data (${characteristic.uuid})...");
    await _healthDataSubscription?.cancel(); // Hủy sub cũ trước
    _healthDataSubscription = null;
    try {
      await characteristic.setNotifyValue(true);
      _healthDataSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          try {
            final jsonString = utf8.decode(value, allowMalformed: true);
            final jsonData = jsonDecode(jsonString);
            final data = HealthData.fromJson(jsonData); // Model đã cập nhật
            // print("[BleService] Parsed Health: Steps=${data.steps}, HR=${data.hr}, T=${data.temperature}, P=${data.pressure}");

            // Lưu trữ
            final user = _authService.currentUser;
            if (user != null) {
              if (_connectivityService.isOnline()) {
                _firestoreService
                    .saveHealthData(user.uid, data)
                    .catchError((e) => print("!!! Firestore Save Error: $e"));
              } else {
                _localDbService.saveHealthRecordLocally(data).then((id) {
                  if (id <= 0) print("Offline save failed/skipped ($id)");
                }).catchError((e) => print("!!! Offline Save Error: $e"));
              }
            }

            // Đẩy stream
            if (!_healthDataStreamController.isClosed) {
              _healthDataStreamController.add(data);
            }

            // Gọi kiểm tra ngưỡng (nếu logic vẫn ở đây)
            _checkThresholdsAndNotify(data);
          } catch (e) {
            print(
                "!!! Error processing health data packet: $e - Raw: ${value.toString()}");
          }
        },
        onError: (error) {
          print("!!! Health data stream error: $error");
        },
        onDone: () {
          print("[BleService] Health data stream closed.");
        },
        cancelOnError: false,
      );
      print("[BleService] Subscription to Health Data successful.");
      return true;
    } catch (e) {
      print("!!! Error subscribing to Health Data: $e");
      return false;
    }
  }

  // --- Subscribe Status Updates ---
  Future<bool> _subscribeToStatusUpdates(
      BluetoothCharacteristic characteristic) async {
    print(
        "[BleService] Subscribing to Status Updates (${characteristic.uuid})...");
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
            print("[BleService] Received Status Update: $statusData");
            if (!_statusStreamController.isClosed) {
              _statusStreamController.add(statusData);
            }
          } catch (e) {
            print(
                "!!! Error processing status packet: $e - Raw: ${value.toString()}");
          }
        },
        onError: (error) {
          print("!!! Status stream error: $error");
        },
        onDone: () {
          print("[BleService] Status stream closed.");
        },
        cancelOnError: false,
      );
      print("[BleService] Subscription to Status Updates successful.");
      return true;
    } catch (e) {
      print("!!! Error subscribing to Status Updates: $e");
      return false;
    }
  }

  // --- Ghi dữ liệu vào Write Characteristic ---
  Future<bool> writeDataToDevice(List<int> dataToWrite) async {
    if (_writeCharacteristic == null) {
      print("!!! BleService Error: Write Char is null!");
      _updateStatus(BleConnectionStatus.error, "Write char missing");
      return false;
    }
    if (connectionStatus.value != BleConnectionStatus.connected) {
      print("!!! BleService Error: Device not connected for write.");
      return false;
    }
    try {
      print(
          "[BleService] Writing ${dataToWrite.length} bytes to ${_writeCharacteristic!.uuid}...");
      await _writeCharacteristic!
          .write(dataToWrite, withoutResponse: false); // Dùng write có response
      print("[BleService] Write successful.");
      return true;
    } catch (e) {
      print("!!! BleService Error writing data: $e");
      _updateStatus(
          BleConnectionStatus.error, "Write failed: ${e.runtimeType}");
      return false;
    }
  }

  // --- Gửi WiFi Config (gọi hàm ghi chung) ---
  Future<bool> sendWifiConfig(String ssid, String password) async {
    try {
      Map<String, String> configData = {'ssid': ssid, 'password': password};
      String jsonString = jsonEncode(configData);
      List<int> bytesToSend = utf8.encode(jsonString);
      print(
          "[BleService] Sending WiFi config via writeDataToDevice: $jsonString");
      return await writeDataToDevice(bytesToSend);
    } catch (e) {
      print("!!! Error encoding WiFi config: $e");
      return false;
    }
  }

  // Trong class BleService

// --- Hàm kiểm tra ngưỡng và gửi Notification (Đã sửa lỗi) ---
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

      // Lấy Locale và l10n
      final localeCode = prefs.getString(AppConstants.prefKeyLanguageCode) ??
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final locale = Locale(localeCode);
      final l10n = lookupAppLocalizations(locale); // Đảm bảo import đúng

      final now = DateTime.now();

      // Check HR High
      if (data.hr > AppConstants.hrHighThreshold && data.hr > 0) {
        if (_lastHighHrNotificationTime == null ||
            now.difference(_lastHighHrNotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: High Heart Rate: ${data.hr}");
          _notificationService.showSimpleNotification(
              id: 1,
              title: l10n.alertHrHighTitle, // Key cho tiêu đề
              // <<< SỬA Ở ĐÂY: CHUYỂN INT THÀNH STRING >>>
              body: l10n.alertHrHighBody(
                  data.hr.toString(), // Chuyển hr thành String
                  AppConstants.hrHighThreshold
                      .toString() // Chuyển ngưỡng thành String
                  ),
              // --------------------------------------
              channelId: 'health_alerts_hr_high',
              channelName: l10n.channelNameHrHigh, // <<< DÙNG KEY CHO TÊN KÊNH
              payload: 'alert_hr_high');
          _lastHighHrNotificationTime = now;
        }
      }
      // Check HR Low
      if (data.hr < AppConstants.hrLowThreshold && data.hr > 0) {
        if (_lastLowHrNotificationTime == null ||
            now.difference(_lastLowHrNotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: Low Heart Rate: ${data.hr}");
          _notificationService.showSimpleNotification(
              id: 2,
              title: l10n.alertHrLowTitle,
              // <<< SỬA Ở ĐÂY: CHUYỂN INT THÀNH STRING >>>
              body: l10n.alertHrLowBody(
                  data.hr.toString(), AppConstants.hrLowThreshold.toString()),
              // --------------------------------------
              channelId: 'health_alerts_hr_low',
              channelName: l10n.channelNameHrLow, // <<< DÙNG KEY CHO TÊN KÊNH
              payload: 'alert_hr_low');
          _lastLowHrNotificationTime = now;
        }
      }
      // Check SpO2 Low
      if (data.spo2 < AppConstants.spo2LowThreshold && data.spo2 > 0) {
        if (_lastLowSpo2NotificationTime == null ||
            now.difference(_lastLowSpo2NotificationTime!) >
                _notificationCooldown) {
          print("[BleService] ALERT: Low SpO2: ${data.spo2}");
          _notificationService.showSimpleNotification(
              id: 3,
              title: l10n.alertSpo2LowTitle,
              // <<< SỬA Ở ĐÂY: CHUYỂN INT THÀNH STRING >>>
              body: l10n.alertSpo2LowBody(data.spo2.toString(),
                  AppConstants.spo2LowThreshold.toString()),
              // --------------------------------------
              channelId: 'health_alerts_spo2_low',
              channelName: l10n.channelNameSpo2Low, // <<< DÙNG KEY CHO TÊN KÊNH
              payload: 'alert_spo2_low');
          _lastLowSpo2NotificationTime = now;
        }
      }
    } catch (e) {
      print(
          "!!! [BleService] Error checking thresholds/sending notification: $e");
    }
  }
// -------------------------------------------------------------

  // --- Dispose ---
  void dispose() {
    print("[BleService] Disposing...");
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _statusDataSubscription?.cancel(); // Hủy sub status
    _healthDataStreamController.close();
    _statusStreamController.close(); // Đóng status stream
    _connectionStatusController.close(); // Đóng connection status stream
    _deviceReadyController.close(); // Đóng device ready stream

    // Ngắt kết nối thiết bị nếu đang kết nối
    final device = _connectedDevice; // Lưu lại trước khi reset
    if (device != null &&
        connectionStatus.value != BleConnectionStatus.disconnected) {
      print("[BleService] Disconnecting device on dispose...");
      // Gọi disconnect trực tiếp, không cần gọi hàm disconnectFromDevice vì nó sẽ reset state không cần thiết nữa
      device.disconnect().catchError((e) {
        print("!!! Error disconnecting on dispose: $e");
      });
    }
    _connectedDevice = null; // Đảm bảo reset
    _healthCharacteristic = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;
    print("[BleService] Disposed.");
  }
}
