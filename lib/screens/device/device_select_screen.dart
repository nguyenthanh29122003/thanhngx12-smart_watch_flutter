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
import '../../generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context)!;
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
          SnackBar(
            content: Text(l10n.connectionFailedSnackbar), // <<< DÙNG KEY
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
    final l10n = AppLocalizations.of(context)!;
    Map<Permission, PermissionStatus> statuses = {};
    if (Platform.isAndroid) {
      statuses = await [
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.permissionDeniedSnackbar), // <<< DÙNG KEY
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
    return allGranted;
  }

  // Hàm kiểm tra trạng thái Bluetooth và yêu cầu bật
  Future<bool> _checkBluetoothState() async {
    if (!mounted) return false; // Kiểm tra mounted
    final l10n = AppLocalizations.of(context)!;
    await Future.delayed(const Duration(milliseconds: 200));
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    } else {
      bool? userAllowedTurnOn = await showDialog<bool>(
        // Lưu kết quả dialog
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.bluetoothRequiredTitle), // <<< DÙNG KEY
          content: Text(l10n.bluetoothRequiredMessage), // <<< DÙNG KEY
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel), // <<< DÙNG KEY
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                try {
                  if (Platform.isAndroid) {
                    await FlutterBluePlus.turnOn();
                  } else {
                    // Có thể hiển thị SnackBar hướng dẫn cho iOS
                    print(l10n.enableBluetoothIOS); // <<< DÙNG KEY
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.enableBluetoothIOS)));
                  }
                } catch (e) {
                  print("Error turning on Bluetooth: $e");
                }
              },
              child: Text(l10n.turnOnButton),
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectDeviceTitle),
        actions: [
          // Sử dụng watch ở đây vì icon/tooltip thay đổi theo trạng thái isScanning
          Consumer<BleProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: provider.isScanning.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh),
                tooltip: provider.isScanning.value
                    ? l10n.scanningTooltip
                    : l10n.scanTooltip,
                // Gọi hàm thông qua read khi nhấn nút
                onPressed: provider.isScanning.value
                    ? null
                    : () => context
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
            valueListenable: context
                .read<BleProvider>()
                .connectionStatus, // Dùng read để lấy listenable
            builder: (context, status, child) {
              String statusText = '';
              Color statusColor = Colors.grey;
              Widget? statusIndicator;
              switch (status) {
                case BleConnectionStatus.disconnected:
                  statusText = context.watch<BleProvider>().isScanning.value
                      ? l10n.scanningStatus
                      : l10n.statusDisconnectedScan;
                  if (context.watch<BleProvider>().isScanning.value) {
                    statusIndicator = const LinearProgressIndicator();
                  }
                  break;
                case BleConnectionStatus.scanning:
                  statusText = l10n.scanningStatus;
                  statusIndicator = const LinearProgressIndicator();
                  break;
                case BleConnectionStatus.connecting:
                  statusText = l10n.statusConnecting;
                  statusIndicator = const LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.discovering_services:
                  statusText = l10n.statusSettingUp;
                  statusIndicator = const LinearProgressIndicator();
                  statusColor = Colors.orange;
                  break;
                case BleConnectionStatus.connected:
                  statusText = l10n.statusConnected;
                  statusColor = Colors.green;
                  break;
                case BleConnectionStatus.error:
                  statusText = l10n.statusErrorPermissions;
                  statusColor = Colors.red;
                  break;
                default:
                  statusText = l10n.statusUnknown;
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
                final bool isConnectingOrConnected = currentStatus ==
                        BleConnectionStatus.connecting ||
                    currentStatus == BleConnectionStatus.discovering_services ||
                    currentStatus == BleConnectionStatus.connected;
                // --------------------------
                final scanResults =
                    provider.scanResults.value; // Lấy kết quả quét

                // ... (logic hiển thị "No devices found" hoặc "Scanning..." như cũ) ...
                if (!provider.isScanning.value &&
                    scanResults.isEmpty &&
                    currentStatus == BleConnectionStatus.disconnected) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.noDevicesFound,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium), // <<< DÙNG KEY
                          const SizedBox(height: 8),
                          Text(l10n.ensureDeviceNearby,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall), // <<< DÙNG KEY
                          const SizedBox(height: 8),
                          Text(l10n.pullToScan,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall), // <<< DÙNG KEY
                        ],
                      ),
                    ),
                  );
                }
                if (scanResults.isEmpty && provider.isScanning.value) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        Text(l10n.scanningStatus), // <<< DÙNG KEY
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: scanResults.length,
                  itemBuilder: (context, index) {
                    ScanResult result = scanResults[index];
                    String deviceName = result.device.platformName.isNotEmpty
                        ? result.device.platformName
                        : l10n.unknownDeviceName;
                    String deviceId = result.device.remoteId.toString();

                    return ListTile(
                      leading: const Icon(Icons.watch),
                      title: Text(deviceName),
                      subtitle: Text(
                          "${l10n.deviceIdPrefix} $deviceId\nRSSI: ${result.rssi} dBm"),
                      isThreeLine: true,
                      trailing: ElevatedButton(
                        // Vô hiệu hóa nút dựa trên trạng thái kết nối tổng thể
                        onPressed: isConnectingOrConnected
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
                        child: (currentStatus ==
                                    BleConnectionStatus.connecting ||
                                currentStatus ==
                                    BleConnectionStatus.discovering_services)
                            // (Tùy chọn) Thêm kiểm tra xem có đang kết nối đúng thiết bị này không
                            // if (_bleProvider.connectingDeviceId == deviceId) // Cần thêm state này vào provider
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.connectButton),
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
