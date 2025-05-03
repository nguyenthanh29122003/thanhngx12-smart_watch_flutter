// lib/services/ble_service.dart
import 'dart:async';
import 'dart:convert'; // Để mã hóa/giải mã JSON
import 'dart:io'; // Để kiểm tra Platform
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Để yêu cầu quyền
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho Timestamp
// import 'dart:typed_data'; // Import nếu bạn cần dùng Uint8List ở đâu đó

import 'auth_service.dart'; // <<< ĐẢM BẢO CÓ DÒNG NÀY
import 'firestore_service.dart'; // <<< ĐẢM BẢO CÓ DÒNG NÀY

import 'local_db_service.dart'; // <<< Import LocalDbService
import 'connectivity_service.dart'; // <<< Import ConnectivityService
import '../models/health_data.dart'; // <<< Đảm bảo import model

import '../app_constants.dart'; // UUIDs, Tên thiết bị

import 'notification_service.dart'; // Import service

// *** Nhắc nhở: Nên di chuyển enum và class HealthData sang file riêng lib/models/ ***
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  discovering_services,
  error,
}

class BleService {
  final ValueNotifier<BleConnectionStatus> connectionStatus = ValueNotifier(
    BleConnectionStatus.disconnected,
  );
  final ValueNotifier<List<ScanResult>> scanResults = ValueNotifier([]);
  final ValueNotifier<bool> isScanning = ValueNotifier(false);

  final StreamController<HealthData> _healthDataStreamController =
      StreamController.broadcast();
  Stream<HealthData> get healthDataStream => _healthDataStreamController.stream;

  final AuthService _authService;
  final FirestoreService _firestoreService;
  final LocalDbService _localDbService; // <<< Thêm Local DB Service
  final ConnectivityService
      _connectivityService; // <<< Thêm Connectivity Service
  final NotificationService _notificationService;

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _healthCharacteristic;
  BluetoothCharacteristic? _writeCharacteristic;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _healthDataSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  // >>> ĐẢM BẢO CONSTRUCTOR NHẬN SERVICES <<<
  BleService(
    this._authService,
    this._firestoreService,
    this._localDbService, // <<< Nhận Local DB Service
    this._connectivityService, // <<< Nhận Connectivity Service
    this._notificationService,
  ) {
    _listenToAdapterState();
    print("BleService Initialized with ALL required services.");
  }

  void _listenToAdapterState() {
    _adapterStateSubscription?.cancel();
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((
      BluetoothAdapterState state,
    ) {
      print("Bluetooth Adapter State Changed: $state");
      if (state == BluetoothAdapterState.off) {
        _handleDisconnect(
          isError: false,
          clearDevice: true,
          reason: "Bluetooth turned off",
        );
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

    print("Requesting permissions: $permissionsToRequest");
    statuses = await permissionsToRequest.request();

    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        print("Permission denied: $permission");
      } else {
        print("Permission granted: $permission");
      }
    });

    if (!allGranted) {
      print("BLE Permissions Denied.");
    } else {
      print("All necessary BLE Permissions Granted.");
    }
    return allGranted;
  }

  Future<void> startScan() async {
    if (isScanning.value) {
      print("Already scanning.");
      return;
    }
    if (!await _requestPermissions()) {
      print("Cannot scan without required permissions.");
      _updateStatus(BleConnectionStatus.error, "Permissions denied");
      return;
    }
    await Future.delayed(const Duration(milliseconds: 200));
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      print("Bluetooth is off. Cannot start scan.");
      _updateStatus(BleConnectionStatus.error, "Bluetooth is off");
      return;
    }

    _updateStatus(BleConnectionStatus.scanning, "Scan started");
    scanResults.value = [];

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
        if (isScanning.value != state) {
          isScanning.value = state;
          print("Plugin isScanning state: $state");
          if (!state &&
              connectionStatus.value == BleConnectionStatus.scanning) {
            _updateStatus(BleConnectionStatus.disconnected, "Scan finished");
          }
        }
      });

      _scanSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          final filtered = results
              .where(
                (r) => r.device.platformName.contains(
                  AppConstants.targetDeviceName,
                ),
              )
              .toList();
          if (!_areScanListsEqual(scanResults.value, filtered)) {
            scanResults.value = filtered;
            print("Scan results updated: ${filtered.length} matching devices.");
          }
        },
        onError: (error) {
          print("Scan Error: $error");
          _updateStatus(BleConnectionStatus.error, "Scan error");
        },
      );

      print("Starting BLE Scan...");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    } catch (e) {
      print("Error starting scan: $e");
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _updateStatus(BleConnectionStatus.error, "Error starting scan");
      isScanning.value = false;
    }
  }

  bool _areScanListsEqual(List<ScanResult> list1, List<ScanResult> list2) {
    if (list1.length != list2.length) return false;
    final ids1 = list1.map((r) => r.device.remoteId).toSet();
    final ids2 = list2.map((r) => r.device.remoteId).toSet();
    return setEquals(ids1, ids2);
  }

  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
        print("Scan manually stopped.");
      } else {
        print("Scan already stopped.");
      }
    } catch (e) {
      print("Error stopping scan: $e");
    } finally {
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
      _scanSubscription?.cancel();
      _scanSubscription = null;
      if (isScanning.value) isScanning.value = false;
      if (connectionStatus.value == BleConnectionStatus.scanning) {
        _updateStatus(
          BleConnectionStatus.disconnected,
          "Scan stopped manually",
        );
      }
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (connectionStatus.value == BleConnectionStatus.connecting ||
        connectionStatus.value == BleConnectionStatus.connected ||
        connectionStatus.value == BleConnectionStatus.discovering_services) {
      print(
        "Connection attempt ignored: Already connecting/connected/discovering.",
      );
      return;
    }

    if (isScanning.value) await stopScan();

    print(
      "Attempting to connect to ${device.platformName} (${device.remoteId})",
    );
    _updateStatus(BleConnectionStatus.connecting, "Connecting...");

    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    try {
      await device.connect(timeout: const Duration(seconds: 15));
      print(">>> Connect Future completed successfully.");

      // Thêm delay nhỏ để chờ trạng thái isConnected ổn định hơn (tùy chọn)
      // await Future.delayed(const Duration(milliseconds: 100));

      if (device.isConnected) {
        print(">>> Device is reported as connected after Future completion.");
        _connectedDevice = device;
        _updateStatus(
          BleConnectionStatus.discovering_services,
          "Discovering services...",
        );
        print(">>> Discovering services...");
        await _discoverServicesAndSubscribe(device);

        // Gắn listener sau khi khám phá xong (hoặc ngay đây nếu muốn xử lý disconnect sớm hơn)
        _connectionStateSubscription = device.connectionState
            .where((state) => state == BluetoothConnectionState.disconnected)
            .listen(
          (state) {
            print(
              ">>> [STATE STREAM - POST CONNECT] Received disconnect event.",
            );
            _handleDisconnect(
              isError: false,
              reason: "Disconnected event received post-connection",
            );
          },
          onError: (error) {
            print(
              ">>> [STATE STREAM - POST CONNECT] Connection state listener error: $error",
            );
            _handleDisconnect(
              isError: true,
              reason: "Connection stream error post-connection",
            );
          },
        );
      } else {
        print(
          ">>> WARNING: Connect Future completed but device.isConnected is false. Handling as error.",
        );
        _handleDisconnect(
          isError: true,
          reason: "Inconsistent state after connect Future",
        );
      }
    } catch (e) {
      print("Error during device.connect() Future for ${device.remoteId}: $e");
      if (connectionStatus.value == BleConnectionStatus.connecting) {
        // Chỉ cập nhật lỗi nếu vẫn đang ở trạng thái connecting
        _updateStatus(
          BleConnectionStatus.error,
          "Connection failed: ${e.toString()}",
        );
      } else {
        // Nếu trạng thái đã khác (ví dụ đã disconnect do stream), không ghi đè
        print(
          "Connect Future error caught, but status is already ${connectionStatus.value}",
        );
      }
      // Đảm bảo listener cũ bị hủy nếu có lỗi ở đây
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = null;
    }
  }

  Future<void> disconnectFromDevice() async {
    final deviceToDisconnect = _connectedDevice;
    if (deviceToDisconnect != null) {
      print("Disconnecting from ${deviceToDisconnect.remoteId}...");
      try {
        await deviceToDisconnect.disconnect();
        print("Disconnect call initiated for ${deviceToDisconnect.remoteId}.");
        // Listener (nếu còn tồn tại) sẽ gọi _handleDisconnect
        // Nếu listener đã bị hủy hoặc không nhận sự kiện, cần xử lý ở đây
        // Tạm thời dựa vào listener hoặc timeout
      } catch (e) {
        print("Error during disconnect call: $e");
        _handleDisconnect(isError: true, reason: "Error calling disconnect()");
      }
    } else {
      print("No device connected to disconnect from.");
      _updateStatus(
        BleConnectionStatus.disconnected,
        "No device was connected",
      );
    }
  }

  void _handleDisconnect({
    bool isError = false,
    bool clearDevice = false,
    String reason = "Unknown",
  }) {
    print(
      "Handling disconnect: IsError=$isError, ClearDevice=$clearDevice, Reason=$reason",
    );
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    _healthCharacteristic = null;
    _writeCharacteristic = null;

    final deviceBeforeDisconnectId = _connectedDevice?.remoteId;
    if (clearDevice || !isError) {
      _connectedDevice = null;
    }

    _updateStatus(
      isError ? BleConnectionStatus.error : BleConnectionStatus.disconnected,
      reason,
    );

    if (deviceBeforeDisconnectId != null && _connectedDevice == null) {
      print(
        "Device $deviceBeforeDisconnectId is now fully disconnected internally.",
      );
    } else if (isError && _connectedDevice != null) {
      print(
        "Device ${_connectedDevice?.remoteId} encountered an error but internal reference is kept.",
      );
    }
  }

  void _updateStatus(BleConnectionStatus newStatus, String reason) {
    if (connectionStatus.value != newStatus) {
      print(
        "Status changing: ${connectionStatus.value} -> $newStatus (Reason: $reason)",
      );
      connectionStatus.value = newStatus;
    }
  }

  Future<void> _discoverServicesAndSubscribe(BluetoothDevice device) async {
    print("Discovering services for ${device.remoteId}...");
    List<BluetoothService> services;
    try {
      services = await device.discoverServices();
      print("Services discovered: ${services.length}");
    } catch (e) {
      print("Error discovering services: $e");
      _handleDisconnect(isError: true, reason: "Failed to discover services");
      return;
    }

    _healthCharacteristic = null;
    _writeCharacteristic = null;
    bool foundTargetService = false;

    for (var service in services) {
      print(
        "--- Service Found: UUID = ${service.uuid.toString().toLowerCase()}",
      );
      if (service.uuid.toString().toLowerCase() ==
          AppConstants.bleServiceUUID.toLowerCase()) {
        print("+++ Matched Target Service: ${service.uuid}");
        foundTargetService = true;
        for (var char in service.characteristics) {
          print(
            "---   Characteristic Found: UUID = ${char.uuid.toString().toLowerCase()} | Properties = ${char.properties}",
          );
          if (char.uuid.toString().toLowerCase() ==
              AppConstants.healthDataCharacteristicUUID.toLowerCase()) {
            if (char.properties.notify) {
              _healthCharacteristic = char;
              print("+++     Stored Health Characteristic (Notify OK)");
            } else {
              print("!!!     Health Characteristic does NOT support notify!");
            }
          }
          if (char.uuid.toString().toLowerCase() ==
              AppConstants.wifiConfigCharacteristicUUID.toLowerCase()) {
            if (char.properties.write) {
              _writeCharacteristic = char;
              print("+++     Stored WiFi Characteristic (Write OK)");
            } else {
              print(
                "!!!     WiFi Config Characteristic does NOT support write!",
              );
            }
          }
        }
        break;
      }
    }

    if (!foundTargetService) {
      print("Target BLE service (${AppConstants.bleServiceUUID}) not found.");
      _handleDisconnect(isError: true, reason: "Target service not found");
      return;
    }

    if (_healthCharacteristic != null) {
      // <<< GỌI HÀM SUBSCRIBE ĐÃ SỬA LẠI >>>
      await _subscribeToHealthData(_healthCharacteristic!);
      if (connectionStatus.value != BleConnectionStatus.error) {
        _updateStatus(
          BleConnectionStatus.connected,
          "Connected and subscribed",
        );
        print("Device setup complete. Status: Connected.");
      }
    } else {
      print(
        "Health Data Characteristic not found or not suitable. Connection may be limited.",
      );
      _updateStatus(
        BleConnectionStatus.error,
        "Health characteristic missing/unsuitable",
      );
    }
  }

  // --- HÀM SUBSCRIBE ĐÃ SỬA LẠI ĐỂ ĐỌC JSON ---
  Future<void> _subscribeToHealthData(
    BluetoothCharacteristic characteristic,
  ) async {
    print("Subscribing to Health Data (${characteristic.uuid})...");
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;

    try {
      await characteristic.setNotifyValue(true); // Bật thông báo

      _healthDataSubscription = characteristic.lastValueStream.listen(
        (value) {
          if (value.isEmpty) return;
          String? jsonString;
          try {
            jsonString = utf8.decode(value, allowMalformed: true);
            Map<String, dynamic> jsonData = jsonDecode(jsonString);
            HealthData data = HealthData.fromJson(jsonData);

            print(
              "Successfully parsed Health Data: Steps=${data.steps}, HR=${data.hr}",
            );

            // --- LOGIC LƯU TRỮ ONLINE/OFFLINE ---
            final currentUser = _authService.currentUser;
            if (currentUser != null) {
              // Kiểm tra trạng thái mạng BẰNG ConnectivityService ĐÃ INJECT
              if (_connectivityService.isOnline()) {
                // --- ONLINE: Lưu vào Firestore ---
                print(
                  "[ONLINE] Queuing data for Firestore save (User: ${currentUser.uid})...",
                );
                _firestoreService
                    .saveHealthData(currentUser.uid, data.toJsonForFirestore())
                    .catchError((e) {
                  print("!!! [ONLINE] Error saving to Firestore: $e");
                  // Cân nhắc lưu vào local khi Firestore lỗi?
                  // _localDbService.saveHealthRecordLocally(data);
                });
              } else {
                // --- OFFLINE: Lưu vào SQLite cục bộ ---
                print(
                  "[OFFLINE] Saving data locally (User: ${currentUser.uid})...",
                );
                _localDbService.saveHealthRecordLocally(data).then((id) {
                  if (id <= 0) {
                    // id=0 là do ignore, id=-1 là do lỗi khác
                    print(
                      "!!! [OFFLINE] Failed or skipped saving data locally (id: $id).",
                    );
                  }
                }).catchError((e) {
                  print("!!! [OFFLINE] Exception saving data locally: $e");
                });
              }
            } else {
              print("!!! Cannot save health data: No user logged in.");
            }
            // -------------------------------------

            _healthDataStreamController.add(data); // Vẫn đẩy data cho UI
          } on FormatException {
            /* ... log lỗi parse ... */
          } catch (e) {
            /* ... log lỗi khác ... */
          }
        },
        onError: (error) {
          /* ... */
        },
        onDone: () {
          /* ... */
        },
        cancelOnError: true,
      );
      print("Subscription to Health Data successful.");
    } catch (e) {
      // Lỗi khi gọi setNotifyValue
      print("Error setting notify value or subscribing to Health Data: $e");
      _handleDisconnect(
        isError: true,
        reason: "Failed to enable health notifications",
      );
    }
  }
  // ----------------------------------------------

  // --- HÀM MỚI: Thực hiện ghi dữ liệu byte vào Write Characteristic ---
  Future<bool> writeDataToDevice(List<int> dataToWrite) async {
    // Kiểm tra xem đã kết nối và đã tìm thấy write characteristic chưa
    if (_writeCharacteristic == null) {
      print(
          "!!! BleService Error: Write Characteristic is null! Cannot write.");
      _updateStatus(BleConnectionStatus.error,
          "Write characteristic missing"); // Cập nhật trạng thái lỗi
      return false;
    }
    if (connectionStatus.value != BleConnectionStatus.connected) {
      print("!!! BleService Error: Device not connected. Cannot write.");
      return false; // Không cần cập nhật status vì đã là disconnected/error
    }

    try {
      // Ghi dữ liệu (ưu tiên có response)
      print(
          "[BleService] Writing ${dataToWrite.length} bytes to ${_writeCharacteristic!.uuid}...");
      await _writeCharacteristic!.write(dataToWrite, withoutResponse: false);
      print("[BleService] Successfully wrote data.");
      return true; // Ghi thành công
    } catch (e) {
      print("!!! BleService Error writing data: $e");
      _updateStatus(BleConnectionStatus.error,
          "Write failed: $e"); // Cập nhật trạng thái lỗi
      return false; // Ghi thất bại
    }
  }

  Future<bool> sendWifiConfig(String ssid, String password) async {
    if (connectionStatus.value != BleConnectionStatus.connected ||
        _connectedDevice == null) {
      print("Cannot send WiFi config: Not connected.");
      return false;
    }

    BluetoothCharacteristic? charToWrite =
        _writeCharacteristic; // Ưu tiên dùng char đã lưu

    if (charToWrite == null) {
      // Nếu chưa lưu, thử khám phá lại
      print("WiFi characteristic not stored. Re-discovering services...");
      try {
        List<BluetoothService> services =
            await _connectedDevice!.discoverServices();
        for (var service in services) {
          if (service.uuid.toString().toLowerCase() ==
              AppConstants.bleServiceUUID.toLowerCase()) {
            for (var char in service.characteristics) {
              if (char.uuid.toString().toLowerCase() ==
                  AppConstants.wifiConfigCharacteristicUUID.toLowerCase()) {
                if (char.properties.write) {
                  charToWrite = char;
                  _writeCharacteristic = char; // Lưu lại
                  print(
                    "Found and stored writable WiFi Config Characteristic.",
                  );
                  break;
                }
              }
            }
            break;
          }
        }
      } catch (e) {
        print("Error re-discovering services for WiFi config: $e");
        return false;
      }
    }

    if (charToWrite == null) {
      print(
        "Writable WiFi Config Characteristic not found after check/discovery.",
      );
      return false;
    }

    try {
      Map<String, String> configData = {'ssid': ssid, 'password': password};
      String jsonString = jsonEncode(configData);
      List<int> bytesToSend = utf8.encode(jsonString);
      print("Sending WiFi config JSON: $jsonString (Bytes: $bytesToSend)");

      await charToWrite.write(bytesToSend, withoutResponse: false);
      print("WiFi config sent successfully.");
      return true;
    } catch (e) {
      print("Error writing WiFi config: $e");
      return false;
    }
  }

  void dispose() {
    print("Disposing BleService...");
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _isScanningSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _healthDataSubscription?.cancel();
    _healthDataStreamController.close();

    if (_connectedDevice != null &&
        connectionStatus.value != BleConnectionStatus.disconnected) {
      print("Disconnecting device on BleService dispose...");
      disconnectFromDevice().catchError((e) {
        print("Error disconnecting device on dispose: $e");
      });
    }
    print("BleService disposed.");
  }
}
