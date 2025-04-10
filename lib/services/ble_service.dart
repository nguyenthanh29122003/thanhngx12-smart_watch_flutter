// lib/services/ble_service.dart
import 'dart:async';
import 'dart:convert'; // Để mã hóa/giải mã JSON
import 'dart:io'; // Để kiểm tra Platform
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart'; // Để yêu cầu quyền
import 'package:cloud_firestore/cloud_firestore.dart'; // Cần cho Timestamp
import '../app_constants.dart'; // UUIDs, Tên thiết bị

// *** Nhắc nhở: Nên di chuyển enum và class HealthData sang file riêng ***
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  discovering_services,
  error,
}

class HealthData {
  final double ax, ay, az, gx, gy, gz;
  final int steps, hr, spo2, ir, red;
  final bool wifi;
  final DateTime timestamp;

  HealthData({
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.steps,
    required this.hr,
    required this.spo2,
    required this.ir,
    required this.red,
    required this.wifi,
    required this.timestamp,
  });

  factory HealthData.fromJson(Map<String, dynamic> json) {
    DateTime parsedTimestamp;
    try {
      final timestampString = json['timestamp'];
      if (timestampString == null ||
          timestampString == "Not initialized" ||
          timestampString is! String) {
        parsedTimestamp = DateTime.now();
      } else {
        parsedTimestamp = DateTime.parse(timestampString);
      }
    } catch (e) {
      print(
        "Error parsing timestamp in HealthData.fromJson: ${json['timestamp']}. Using DateTime.now(). Error: $e",
      );
      parsedTimestamp = DateTime.now();
    }

    T _parseNum<T extends num>(dynamic value, T defaultValue) {
      if (value is num) {
        if (defaultValue is double) return value.toDouble() as T;
        if (defaultValue is int) return value.toInt() as T;
      }
      // Nếu không phải num, log cảnh báo (tùy chọn)
      // if (value != null) { print("Warning: Expected num but got ${value.runtimeType} for value $value. Using default $defaultValue.");}
      return defaultValue;
    }

    return HealthData(
      ax: _parseNum(json['ax'], 0.0),
      ay: _parseNum(json['ay'], 0.0),
      az: _parseNum(json['az'], 0.0),
      gx: _parseNum(json['gx'], 0.0),
      gy: _parseNum(json['gy'], 0.0),
      gz: _parseNum(json['gz'], 0.0),
      steps: _parseNum(json['steps'], 0),
      hr: _parseNum(json['hr'], -1),
      spo2: _parseNum(json['spo2'], -1),
      ir: _parseNum(json['ir'], 0),
      red: _parseNum(json['red'], 0),
      wifi: (json['wifi'] as bool?) ?? false,
      timestamp: parsedTimestamp,
    );
  }

  Map<String, dynamic> toJsonForFirestore() => {
    'ax': ax,
    'ay': ay,
    'az': az,
    'gx': gx,
    'gy': gy,
    'gz': gz,
    'steps': steps,
    'hr': hr,
    'spo2': spo2,
    'ir': ir,
    'red': red,
    'wifi': wifi,
    'recordedAt': Timestamp.fromDate(timestamp),
  };
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

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic?
  _healthCharacteristic; // Lưu trữ characteristic để dùng lại
  BluetoothCharacteristic?
  _wifiCharacteristic; // Lưu trữ characteristic để dùng lại

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;
  StreamSubscription? _healthDataSubscription;
  StreamSubscription? _isScanningSubscription;
  StreamSubscription? _adapterStateSubscription;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  BleService() {
    _listenToAdapterState();
    print("BleService Initialized.");
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

    if (!allGranted)
      print("BLE Permissions Denied.");
    else
      print("All necessary BLE Permissions Granted.");
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
      await FlutterBluePlus.stopScan(); // Đảm bảo dừng quét cũ
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;

      _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
        // Cập nhật trạng thái isScanning dựa trên plugin
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
          final filtered =
              results
                  .where(
                    (r) => r.device.platformName.contains(
                      AppConstants.targetDeviceName,
                    ),
                  )
                  .toList();
          // Tối ưu: Chỉ cập nhật nếu list thay đổi ID thiết bị
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
      isScanning.value = false; // Đảm bảo reset trạng thái quét
    }
  }

  // Helper so sánh scan results dựa trên ID
  bool _areScanListsEqual(List<ScanResult> list1, List<ScanResult> list2) {
    if (list1.length != list2.length) return false;
    final ids1 = list1.map((r) => r.device.remoteId).toSet();
    final ids2 = list2.map((r) => r.device.remoteId).toSet();
    return setEquals(ids1, ids2);
  }

  Future<void> stopScan() async {
    try {
      // Chỉ dừng nếu đang thực sự quét (tránh gọi thừa)
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
        print("Scan manually stopped.");
      } else {
        print("Scan already stopped.");
      }
    } catch (e) {
      print("Error stopping scan: $e");
    } finally {
      // Dù có lỗi hay không, đảm bảo các sub được hủy và trạng thái reset nếu cần
      _isScanningSubscription?.cancel();
      _isScanningSubscription = null;
      _scanSubscription?.cancel();
      _scanSubscription = null;
      if (isScanning.value)
        isScanning.value = false; // Cập nhật thủ công nếu stream chưa kịp
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

    // Hủy listener cũ trước khi gọi connect mới
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    try {
      // Thực hiện kết nối với timeout
      await device.connect(timeout: const Duration(seconds: 15));

      // Nếu connect() hoàn thành mà không ném lỗi:
      print(">>> Connect Future completed successfully.");

      // KIỂM TRA TRẠNG THÁI NGAY LẬP TỨC SAU KHI FUTURE HOÀN THÀNH
      // Dùng device.connectionState.first để lấy trạng thái hiện tại đáng tin cậy hơn isConnected (đôi khi isConnected chưa cập nhật kịp)
      // Hoặc dùng FlutterBluePlus.connectedSystemDevices để kiểm tra
      // Tạm thời dùng cách đơn giản: kiểm tra isConnected trước
      // await Future.delayed(Duration(milliseconds: 100)); // Thêm delay nhỏ nếu isConnected chưa kịp cập nhật

      if (device.isConnected) {
        // Kiểm tra thuộc tính isConnected
        print(">>> Device is reported as connected after Future completion.");
        _connectedDevice = device;
        _updateStatus(
          BleConnectionStatus.discovering_services,
          "Discovering services...",
        );
        print(">>> Discovering services...");
        await _discoverServicesAndSubscribe(
          device,
        ); // Chỉ khám phá nếu kết nối thực sự thành công

        // Gắn listener CHỈ để xử lý ngắt kết nối SAU KHI đã kết nối thành công
        _connectionStateSubscription = device.connectionState
            .where(
              (state) => state == BluetoothConnectionState.disconnected,
            ) // Chỉ lắng nghe disconnected
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
        // Trường hợp lạ: Future connect thành công nhưng device.isConnected là false
        print(
          ">>> WARNING: Connect Future completed but device.isConnected is false. Handling as error.",
        );
        _handleDisconnect(
          isError: true,
          reason: "Inconsistent state after connect Future",
        );
      }
    } catch (e) {
      // Bắt lỗi xảy ra trong quá trình gọi device.connect() (ví dụ: timeout)
      print("Error during device.connect() Future for ${device.remoteId}: $e");
      // Không cần thiết phải gọi _handleDisconnect ở đây vì listener (nếu có) hoặc trạng thái connecting sẽ được xử lý
      // Chỉ cần cập nhật trạng thái lỗi
      if (connectionStatus.value == BleConnectionStatus.connecting) {
        _updateStatus(
          BleConnectionStatus.error,
          "Connection failed: ${e.toString()}",
        );
      }
    }
  }

  Future<void> disconnectFromDevice() async {
    final deviceToDisconnect = _connectedDevice;
    if (deviceToDisconnect != null) {
      print("Disconnecting from ${deviceToDisconnect.remoteId}...");
      try {
        // Listener sẽ xử lý việc cập nhật trạng thái khi nhận disconnected
        await deviceToDisconnect.disconnect();
        print("Disconnect call initiated for ${deviceToDisconnect.remoteId}.");
      } catch (e) {
        print("Error during disconnect call: $e");
        _handleDisconnect(isError: true, reason: "Error calling disconnect()");
      }
    } else {
      print("No device connected to disconnect from.");
      // Đảm bảo trạng thái là disconnected nếu không có thiết bị
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

    // Hủy các subscription liên quan đến thiết bị cụ thể
    _healthDataSubscription?.cancel();
    _healthDataSubscription = null;
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Reset các characteristics đã lưu
    _healthCharacteristic = null;
    _wifiCharacteristic = null;

    final deviceBeforeDisconnectId = _connectedDevice?.remoteId;
    if (clearDevice || !isError) {
      // Xóa thiết bị nếu yêu cầu hoặc là disconnect bình thường
      _connectedDevice = null;
    }
    // Nếu là lỗi nhưng không clearDevice, _connectedDevice vẫn giữ nguyên
    // cho phép thử kết nối lại mà không cần quét lại (tùy logic mong muốn)

    // Cập nhật trạng thái
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
        "Device ${_connectedDevice?.remoteId} encountered an error but internal reference is kept (potential retry?).",
      );
    }
  }

  // Hàm helper để cập nhật trạng thái và log
  void _updateStatus(BleConnectionStatus newStatus, String reason) {
    if (connectionStatus.value != newStatus) {
      print(
        "Status changing: ${connectionStatus.value} -> $newStatus (Reason: $reason)",
      );
      connectionStatus.value = newStatus;
    } else {
      // print("Status already $newStatus. Reason: $reason"); // Có thể bỏ log này nếu quá nhiều
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

    _healthCharacteristic = null; // Reset trước khi tìm
    _wifiCharacteristic = null; // Reset trước khi tìm
    bool foundTargetService = false;

    for (var service in services) {
      // >>> THÊM LOGGING UUID TÌM THẤY <<<
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
          // Lưu Health Characteristic
          if (char.uuid.toString().toLowerCase() ==
              AppConstants.healthDataCharacteristicUUID.toLowerCase()) {
            if (char.properties.notify) {
              _healthCharacteristic = char;
              print("+++     Stored Health Characteristic (Notify OK)");
            } else {
              print("!!!     Health Characteristic does NOT support notify!");
            }
          }
          // Lưu WiFi Characteristic
          if (char.uuid.toString().toLowerCase() ==
              AppConstants.wifiConfigCharacteristicUUID.toLowerCase()) {
            if (char.properties.write) {
              // Hoặc writeWithoutResponse tùy firmware
              _wifiCharacteristic = char;
              print("+++     Stored WiFi Characteristic (Write OK)");
            } else {
              print(
                "!!!     WiFi Config Characteristic does NOT support write!",
              );
            }
          }
        }
        break; // Đã tìm thấy service mục tiêu
      }
    }

    if (!foundTargetService) {
      print(
        "Target BLE service (${AppConstants.bleServiceUUID}) not found amongst discovered services.",
      );
      _handleDisconnect(isError: true, reason: "Target service not found");
      return;
    }

    // Nếu tìm thấy Health Characteristic -> Subscribe
    if (_healthCharacteristic != null) {
      await _subscribeToHealthData(_healthCharacteristic!);
      // Chỉ chuyển sang connected nếu subscribe thành công (hoặc ít nhất là bắt đầu thành công)
      if (connectionStatus.value != BleConnectionStatus.error) {
        // Kiểm tra nếu _subscribeToHealthData báo lỗi
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
      // Quyết định trạng thái ở đây: Có thể vẫn là Connected nếu các chức năng khác OK
      // Hoặc là Error nếu Health Data là bắt buộc.
      _updateStatus(
        BleConnectionStatus.error,
        "Health characteristic missing/unsuitable",
      ); // Tạm coi là lỗi
      // await disconnectFromDevice(); // Ngắt kết nối nếu bắt buộc
    }
  }

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
          if (value.isEmpty) {
            print("Received empty data packet.");
            return;
          }

          String? jsonString; // Khai báo ngoài try-catch để log lỗi
          try {
            // --- QUAY LẠI GIẢI MÃ UTF-8 VÀ JSON ---
            jsonString = utf8.decode(
              value,
              allowMalformed: true,
            ); // Thêm allowMalformed

            // Log dữ liệu thô nhận được (quan trọng để debug)
            // print("Received raw string (len ${jsonString.length}): $jsonString");

            // Parse JSON
            Map<String, dynamic> jsonData = jsonDecode(jsonString);

            // Tạo đối tượng HealthData (đã bao gồm xử lý timestamp trong factory)
            HealthData data = HealthData.fromJson(jsonData);

            // Đẩy dữ liệu đã parse vào stream controller
            _healthDataStreamController.add(data);
            // print("Parsed JSON to HealthData: Steps=${data.steps}"); // Giảm log
          } on FormatException catch (e) {
            // LỖI QUAN TRỌNG: Xảy ra khi utf8.decode hoặc jsonDecode thất bại
            print("!!! FormatException decoding/parsing health data: $e");
            print("    Raw bytes: $value");
            if (jsonString != null) {
              print("    Decoded string (may be corrupt): $jsonString");
            }
            // KHÔNG ngắt kết nối ngay, có thể chỉ là gói tin lỗi tạm thời.
            // Có thể thêm bộ đếm lỗi và chỉ ngắt nếu lỗi xảy ra liên tục.
          } catch (e) {
            // Bắt các lỗi khác không mong muốn
            print(
              "!!! Unexpected error processing health data: $e. Raw bytes: $value",
            );
            if (jsonString != null) {
              print("    Decoded string (may be corrupt): $jsonString");
            }
          }
        },
        onError: (error) {
          print("Health data stream subscription error: $error");
          _handleDisconnect(
            isError: true,
            reason: "Health data stream subscription error",
          );
        },
        onDone: () {
          print("Health data stream ended (Notifications stopped?).");
          if (connectionStatus.value == BleConnectionStatus.connected) {
            _handleDisconnect(
              isError: false,
              reason: "Health data stream ended",
            );
          }
        },
        cancelOnError: true,
      ); // Giữ cancelOnError để dừng nếu có lỗi nghiêm trọng từ stream

      print("Subscription to Health Data successful.");
    } catch (e) {
      print("Error setting notify value or subscribing to Health Data: $e");
      _handleDisconnect(
        isError: true,
        reason: "Failed to enable health notifications",
      );
    }
  }

  Future<bool> sendWifiConfig(String ssid, String password) async {
    if (connectionStatus.value != BleConnectionStatus.connected ||
        _connectedDevice == null) {
      print("Cannot send WiFi config: Not connected.");
      return false;
    }

    // 1. Ưu tiên sử dụng characteristic đã lưu
    BluetoothCharacteristic? charToWrite = _wifiCharacteristic;

    // 2. Nếu chưa có, thử khám phá lại (không khuyến khích làm thường xuyên)
    if (charToWrite == null) {
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
                  _wifiCharacteristic = char; // Lưu lại cho lần sau
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

    // 3. Kiểm tra lại sau khi đã thử khám phá
    if (charToWrite == null) {
      print(
        "Writable WiFi Config Characteristic not found after check/discovery.",
      );
      return false;
    }

    // 4. Chuẩn bị và Gửi Dữ liệu
    try {
      Map<String, String> configData = {'ssid': ssid, 'password': password};
      String jsonString = jsonEncode(configData);
      List<int> bytesToSend = utf8.encode(jsonString);
      print("Sending WiFi config JSON: $jsonString (Bytes: $bytesToSend)");

      await charToWrite.write(
        bytesToSend,
        withoutResponse: false,
      ); // Dùng write có response
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

    // Cố gắng ngắt kết nối thiết bị nếu đang kết nối
    if (_connectedDevice != null &&
        connectionStatus.value != BleConnectionStatus.disconnected) {
      print("Disconnecting device on BleService dispose...");
      disconnectFromDevice().catchError((e) {
        // Gọi hàm disconnect đã có sẵn
        print("Error disconnecting device on dispose: $e");
      });
    }
    print("BleService disposed.");
  }
}
