// lib/screens/device/device_select_screen.dart
import 'dart:io'; // Để kiểm tra Platform
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<< Import SharedPreferences
import '../../app_constants.dart'; // <<< Import AppConstants
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart'; // <<< Import BleService (cho enum)
import '../core/main_navigator.dart'; // Màn hình chính sau khi kết nối

class DeviceSelectScreen extends StatefulWidget {
  const DeviceSelectScreen({super.key});

  @override
  State<DeviceSelectScreen> createState() => _DeviceSelectScreenState();
}

class _DeviceSelectScreenState extends State<DeviceSelectScreen> {
  late BleProvider _bleProvider;
  bool _hasInitialScanStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bleProvider = Provider.of<BleProvider>(context, listen: false);

    // Dùng try-catch khi remove/add listener phòng trường hợp provider đã bị dispose
    try {
      _bleProvider.connectionStatus.removeListener(
        _handleConnectionStatusChange,
      );
      _bleProvider.connectionStatus.addListener(_handleConnectionStatusChange);
    } catch (e) {
      print("Error setting up connection listener: $e");
    }

    if (!_hasInitialScanStarted) {
      _hasInitialScanStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Kiểm tra mounted trước khi gọi
          _checkAndScan();
        }
      });
    }
  }

  @override
  void dispose() {
    try {
      _bleProvider.connectionStatus.removeListener(
        _handleConnectionStatusChange,
      );
    } catch (e) {
      print("Error removing connection listener on dispose: $e");
    }
    super.dispose();
  }

  // Listener xử lý thay đổi trạng thái kết nối
  void _handleConnectionStatusChange() async {
    // Kiểm tra mounted trước khi truy cập state hoặc context
    if (!mounted) return;

    final status = _bleProvider.connectionStatus.value;
    print("DeviceSelectScreen received connection status: $status");

    if (status == BleConnectionStatus.connected) {
      // --- LƯU DEVICE ID KHI KẾT NỐI THÀNH CÔNG ---
      // Dùng read<BleProvider> vì không cần rebuild khi gọi hàm này
      final connectedDevice = context.read<BleProvider>().connectedDevice;
      if (connectedDevice != null) {
        final deviceId = connectedDevice.remoteId.toString();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            AppConstants.prefKeyConnectedDeviceId,
            deviceId,
          );
          print("[DeviceSelectScreen] Saved connected device ID: $deviceId");
        } catch (e) {
          print("!!! [DeviceSelectScreen] Error saving device ID: $e");
        }
      } else {
        print(
          "!!! [DeviceSelectScreen] Warning: Connected but connectedDevice is null?",
        );
      }
      // -----------------------------------------

      print("Navigating to MainNavigator...");
      // Đảm bảo không lỗi nếu context không còn hợp lệ (dù đã check mounted)
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigator()),
        );
      }
    } else if (status == BleConnectionStatus.error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect to the device. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // Hàm kiểm tra quyền và trạng thái Bluetooth trước khi quét
  Future<void> _checkAndScan() async {
    if (!mounted) return; // Kiểm tra mounted
    if (!await _checkPermissions()) {
      return;
    }
    if (!await _checkBluetoothState()) {
      return;
    }
    // Dùng read vì chỉ gọi hàm, không cần rebuild
    context.read<BleProvider>().startScan();
  }

  // Hàm kiểm tra và yêu cầu quyền
  Future<bool> _checkPermissions() async {
    if (!mounted) return false; // Kiểm tra mounted
    Map<Permission, PermissionStatus> statuses = {};
    if (Platform.isAndroid) {
      statuses =
          await [
            Permission.location,
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
          ].request();
    } else if (Platform.isIOS) {
      statuses =
          await [Permission.bluetooth, Permission.locationWhenInUse].request();
    }
    bool allGranted = true;
    statuses.forEach((p, s) {
      if (!s.isGranted) allGranted = false;
    });
    if (!allGranted && mounted) {
      // <<< SỬA LỖI showSnackBar >>>
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // <<< Thêm SnackBar(...)
          content: Text(
            'Required permissions were denied. Please grant permissions in settings.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
    return allGranted;
  }

  // Hàm kiểm tra trạng thái Bluetooth và yêu cầu bật
  Future<bool> _checkBluetoothState() async {
    if (!mounted) return false; // Kiểm tra mounted
    await Future.delayed(const Duration(milliseconds: 200));
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on)
      return true;
    else {
      bool? userAllowedTurnOn = await showDialog<bool>(
        // Lưu kết quả dialog
        context: context,
        builder:
            (context) => AlertDialog(
              /* ... dialog content ... */
              title: const Text('Bluetooth Required'),
              content: const Text(
                'This app requires Bluetooth to be enabled to scan for devices.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop(true);
                    try {
                      if (Platform.isAndroid) {
                        await FlutterBluePlus.turnOn();
                      } else {
                        print("Please enable Bluetooth in settings.");
                      }
                    } catch (e) {
                      print("Error turning on Bluetooth: $e");
                    }
                  },
                  child: const Text('Turn On'),
                ),
              ],
            ),
      );

      if (userAllowedTurnOn == true) {
        // Chỉ kiểm tra lại nếu người dùng nhấn "Turn On"
        await Future.delayed(const Duration(milliseconds: 500));
        return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
      } else {
        return false; // Người dùng nhấn Cancel
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Device'),
        actions: [
          // Sử dụng watch ở đây vì icon/tooltip thay đổi theo trạng thái isScanning
          Consumer<BleProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon:
                    provider.isScanning.value
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Icon(Icons.refresh),
                tooltip:
                    provider.isScanning.value
                        ? 'Scanning...'
                        : 'Scan for devices',
                // Gọi hàm thông qua read khi nhấn nút
                onPressed:
                    provider.isScanning.value
                        ? null
                        : () =>
                            context
                                .read<BleProvider>()
                                .startScan(), // Gọi lại startScan qua provider
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh trạng thái (dùng ValueListenableBuilder để tối ưu)
          ValueListenableBuilder<BleConnectionStatus>(
            valueListenable:
                context
                    .read<BleProvider>()
                    .connectionStatus, // Dùng read để lấy listenable
            builder: (context, status, child) {
              String statusText = '';
              Color statusColor = Colors.grey;
              Widget? statusIndicator;
              // ... (switch case để xác định text, color, indicator như cũ) ...
              switch (status) {
                case BleConnectionStatus.disconnected:
                  statusText =
                      context.watch<BleProvider>().isScanning.value
                          ? 'Scanning...'
                          : 'Disconnected. Tap scan.';
                  if (context.watch<BleProvider>().isScanning.value)
                    statusIndicator = LinearProgressIndicator();
                  break;
                case BleConnectionStatus.scanning:
                  statusText = 'Scanning...';
                  statusIndicator = LinearProgressIndicator();
                  break;
                case BleConnectionStatus.connecting:
                  statusText = 'Connecting...';
                  statusIndicator = LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.discovering_services:
                  statusText = 'Setting up...';
                  statusIndicator = LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.connected:
                  statusText = 'Connected!';
                  statusColor = Colors.green;
                  break;
                case BleConnectionStatus.error:
                  statusText = 'Error. Check permissions/BT.';
                  statusColor = Colors.red;
                  break;
                default:
                  statusText = 'Unknown';
              }

              return Container(
                width: double.infinity,
                color: statusColor.withAlpha((0.1 * 255).round()),
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                child: Column(
                  children: [
                    if (statusIndicator != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: statusIndicator,
                      ),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: statusColor),
                    ),
                  ],
                ),
              );
            },
          ),

          // Danh sách thiết bị
          Expanded(
            // Dùng Consumer vì cần rebuild khi scanResults hoặc connectionStatus thay đổi
            child: Consumer<BleProvider>(
              builder: (context, provider, child) {
                final currentStatus = provider.connectionStatus.value;
                // >>> THÊM LẠI DÒNG NÀY <<<
                final bool isConnectingOrConnected =
                    currentStatus == BleConnectionStatus.connecting ||
                    currentStatus == BleConnectionStatus.discovering_services ||
                    currentStatus == BleConnectionStatus.connected;
                // --------------------------
                final scanResults =
                    provider.scanResults.value; // Lấy kết quả quét

                // ... (logic hiển thị "No devices found" hoặc "Scanning..." như cũ) ...
                if (!provider.isScanning.value &&
                    scanResults.isEmpty &&
                    currentStatus == BleConnectionStatus.disconnected) {
                  return const Center(
                    child: Text(
                      'No devices found...\nTap refresh to scan.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (scanResults.isEmpty && provider.isScanning.value) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Scanning..."),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    ScanResult result = scanResults[index];
                    String deviceName =
                        result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Unknown Device';
                    String deviceId = result.device.remoteId.toString();

                    return ListTile(
                      leading: const Icon(Icons.watch),
                      title: Text(deviceName),
                      subtitle: Text("ID: $deviceId\nRSSI: ${result.rssi} dBm"),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        // Vô hiệu hóa nút dựa trên trạng thái kết nối tổng thể
                        onPressed:
                            isConnectingOrConnected
                                ? null
                                : () {
                                  print(
                                    "Connect button pressed for ${result.device.remoteId}",
                                  );
                                  // Gọi connect qua provider (dùng read vì chỉ gọi hàm)
                                  context.read<BleProvider>().connectToDevice(
                                    result.device,
                                  );
                                },
                        child:
                            (currentStatus == BleConnectionStatus.connecting ||
                                    currentStatus ==
                                        BleConnectionStatus
                                            .discovering_services)
                                // (Tùy chọn) Thêm kiểm tra xem có đang kết nối đúng thiết bị này không
                                // if (_bleProvider.connectingDeviceId == deviceId) // Cần thêm state này vào provider
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Connect'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
