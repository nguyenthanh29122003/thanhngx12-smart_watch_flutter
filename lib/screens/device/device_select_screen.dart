// lib/screens/device/device_select_screen.dart
import 'dart:io'; // Để kiểm tra Platform
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../services/ble_service.dart';
import '../../app_constants.dart'; // Tên thiết bị
import '../../providers/ble_provider.dart';
import '../core/main_navigator.dart'; // Màn hình chính sau khi kết nối

class DeviceSelectScreen extends StatefulWidget {
  const DeviceSelectScreen({super.key});

  @override
  State<DeviceSelectScreen> createState() => _DeviceSelectScreenState();
}

class _DeviceSelectScreenState extends State<DeviceSelectScreen> {
  late BleProvider _bleProvider; // Khởi tạo trong didChangeDependencies
  bool _hasInitialScanStarted = false; // Đảm bảo chỉ quét tự động lần đầu

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy provider và đăng ký listener ở đây an toàn hơn initState
    // vì context đã sẵn sàng
    _bleProvider = Provider.of<BleProvider>(context, listen: false);

    // Xóa listener cũ trước khi thêm mới (quan trọng khi hot reload)
    _bleProvider.connectionStatus.removeListener(_handleConnectionStatusChange);
    _bleProvider.connectionStatus.addListener(_handleConnectionStatusChange);

    // Bắt đầu quét tự động lần đầu vào màn hình nếu chưa quét
    if (!_hasInitialScanStarted) {
      _hasInitialScanStarted = true;
      // Đợi một chút để màn hình build xong rồi mới quét
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndScan();
      });
    }
  }

  @override
  void dispose() {
    // Gỡ bỏ listener khi widget bị hủy
    _bleProvider.connectionStatus.removeListener(_handleConnectionStatusChange);
    // Cân nhắc dừng quét khi rời màn hình này?
    // _bleProvider.stopScan(); // Tùy thuộc yêu cầu
    super.dispose();
  }

  // Listener để xử lý thay đổi trạng thái kết nối
  void _handleConnectionStatusChange() {
    final status = _bleProvider.connectionStatus.value;
    print("DeviceSelectScreen received connection status: $status");
    if (status == BleConnectionStatus.connected && mounted) {
      // Đã kết nối thành công -> Chuyển sang màn hình chính
      print("Navigating to MainNavigator...");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigator()),
      );
    } else if (status == BleConnectionStatus.error && mounted) {
      // Hiển thị lỗi nếu kết nối thất bại
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to the device.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Hàm kiểm tra quyền và trạng thái Bluetooth trước khi quét
  Future<void> _checkAndScan() async {
    // 1. Kiểm tra quyền
    if (!await _checkPermissions()) {
      return; // Dừng lại nếu quyền không được cấp
    }

    // 2. Kiểm tra trạng thái Bluetooth
    if (!await _checkBluetoothState()) {
      return; // Dừng lại nếu Bluetooth không bật
    }

    // 3. Bắt đầu quét
    _bleProvider.startScan();
  }

  // Hàm kiểm tra và yêu cầu quyền
  Future<bool> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = {};

    // Yêu cầu các quyền cần thiết dựa trên nền tảng
    if (Platform.isAndroid) {
      statuses =
          await [
            Permission.location, // Luôn cần cho Android < 12
            Permission.bluetoothScan, // Android 12+
            Permission.bluetoothConnect, // Android 12+
          ].request();
    } else if (Platform.isIOS) {
      statuses =
          await [
            Permission.bluetooth, // Quyền Bluetooth chung cho iOS
            Permission.locationWhenInUse, // Cần cho quét BLE trên iOS
          ].request();
    }

    // Kiểm tra kết quả
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
        print("${permission.toString()} permission denied.");
      }
    });

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Required permissions were denied. Please grant permissions in settings.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      // Cân nhắc mở cài đặt ứng dụng: await openAppSettings();
    }
    return allGranted;
  }

  // Hàm kiểm tra trạng thái Bluetooth và yêu cầu bật
  Future<bool> _checkBluetoothState() async {
    // Chờ một chút để đảm bảo trạng thái adapter được cập nhật
    await Future.delayed(const Duration(milliseconds: 200));

    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true; // Bluetooth đã bật
    } else {
      if (mounted) {
        // Chỉ hiển thị dialog nếu widget còn tồn tại
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Bluetooth Required'),
                content: const Text(
                  'This app requires Bluetooth to be enabled to scan for devices.',
                ),
                actions: [
                  TextButton(
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pop(false), // Người dùng từ chối
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.of(context).pop(true); // Người dùng đồng ý
                      try {
                        if (Platform.isAndroid) {
                          // Cố gắng yêu cầu hệ thống bật Bluetooth trên Android
                          await FlutterBluePlus.turnOn();
                        } else {
                          // Trên iOS, không thể bật tự động, cần hướng dẫn người dùng
                          // (Thông báo này có thể hiển thị trong dialog)
                          print(
                            "Please enable Bluetooth in your device settings.",
                          );
                          // Có thể mở cài đặt: openAppSettings();
                        }
                      } catch (e) {
                        print("Error trying to turn on Bluetooth: $e");
                      }
                    },
                    child: const Text('Turn On'),
                  ),
                ],
              ),
        );

        // Kiểm tra lại trạng thái sau khi dialog đóng
        await Future.delayed(const Duration(milliseconds: 500)); // Đợi một chút
        return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
      } else {
        return false; // Widget không còn mounted
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Device'),
        // Không cần nút back nếu đây là màn hình đầu tiên sau login
        // automaticallyImplyLeading: false,
        actions: [
          // Nút quét/làm mới
          Consumer<BleProvider>(
            // Dùng Consumer để lấy trạng thái isScanning
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
                onPressed:
                    provider.isScanning.value
                        ? null
                        : _checkAndScan, // Vô hiệu hóa khi đang quét
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Hiển thị trạng thái ---
          Consumer<BleProvider>(
            // Dùng Consumer để lấy các trạng thái
            builder: (context, provider, child) {
              String statusText = '';
              Color statusColor = Colors.grey;
              Widget? statusIndicator;

              switch (provider.connectionStatus.value) {
                case BleConnectionStatus.disconnected:
                  statusText =
                      provider.isScanning.value
                          ? 'Scanning for devices...'
                          : 'Disconnected. Tap scan to find devices.';
                  if (provider.isScanning.value) {
                    statusIndicator = const LinearProgressIndicator();
                  }
                  break;
                case BleConnectionStatus.scanning:
                  statusText = 'Scanning...';
                  statusIndicator = const LinearProgressIndicator();
                  break;
                case BleConnectionStatus.connecting:
                  statusText = 'Connecting...';
                  statusIndicator = const LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.discovering_services:
                  statusText = 'Setting up device...';
                  statusIndicator = const LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.connected:
                  // Trường hợp này sẽ nhanh chóng bị điều hướng đi, nhưng để cho đủ
                  statusText = 'Connected!';
                  statusColor = Colors.green;
                  break;
                case BleConnectionStatus.error:
                  statusText =
                      'Error. Please check permissions/Bluetooth and scan again.';
                  statusColor = Colors.red;
                  break;
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

          // --- Danh sách thiết bị ---
          Expanded(
            child: Consumer<BleProvider>(
              // Lắng nghe thay đổi scanResults và connectionStatus
              builder: (context, provider, child) {
                // Lấy trạng thái hiện tại để quyết định có disable nút connect không
                final currentStatus = provider.connectionStatus.value;
                final bool isConnectingOrConnected =
                    currentStatus == BleConnectionStatus.connecting ||
                    currentStatus == BleConnectionStatus.discovering_services ||
                    currentStatus == BleConnectionStatus.connected;

                if (!provider.isScanning.value &&
                    provider.scanResults.value.isEmpty &&
                    currentStatus == BleConnectionStatus.disconnected) {
                  // Nếu không quét, không có kết quả, và đang disconnected
                  return const Center(
                    child: Text(
                      'No devices found.\nMake sure your ESP32 is turned on and nearby.\nTap the refresh icon to scan.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (provider.scanResults.value.isEmpty &&
                    provider.isScanning.value) {
                  // Nếu đang quét mà chưa có kết quả
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text("Scanning for ESP32_SmartWatch..."),
                      ],
                    ),
                  );
                }

                // Hiển thị danh sách kết quả
                return ListView.builder(
                  itemCount: provider.scanResults.value.length,
                  itemBuilder: (context, index) {
                    ScanResult result = provider.scanResults.value[index];
                    String deviceName =
                        result.device.platformName.isNotEmpty
                            ? result.device.platformName
                            : 'Unknown Device';
                    String deviceId = result.device.remoteId.toString();

                    return ListTile(
                      leading: const Icon(Icons.watch), // Icon thiết bị
                      title: Text(deviceName),
                      subtitle: Text("ID: $deviceId\nRSSI: ${result.rssi} dBm"),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        // Vô hiệu hóa nếu đang kết nối/đã kết nối với thiết bị khác
                        // Hoặc nếu đang kết nối chính thiết bị này
                        onPressed:
                            isConnectingOrConnected
                                ? null
                                : () {
                                  print(
                                    "Connect button pressed for ${result.device.remoteId}",
                                  );
                                  provider.connectToDevice(result.device);
                                },
                        child:
                            (currentStatus == BleConnectionStatus.connecting ||
                                    currentStatus ==
                                        BleConnectionStatus
                                            .discovering_services)
                                // && provider.connectingDeviceId == deviceId // Cần thêm biến để biết đang kết nối thiết bị nào
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Connect'),
                      ),
                      // Có thể thêm onTap cho cả ListTile nếu muốn
                      // onTap: isConnectingOrConnected ? null : () {
                      //    provider.connectToDevice(result.device);
                      // },
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
