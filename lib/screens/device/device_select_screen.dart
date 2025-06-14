// lib/screens/device/device_select_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Các import từ dự án của bạn
import '../../app_constants.dart';
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';
import '../core/main_navigator.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>>

class DeviceSelectScreen extends StatefulWidget {
  const DeviceSelectScreen({super.key});

  @override
  State<DeviceSelectScreen> createState() => _DeviceSelectScreenState();
}

class _DeviceSelectScreenState extends State<DeviceSelectScreen> {
  // --- STATE VÀ LOGIC GIỮ NGUYÊN ---
  late BleProvider _bleProvider;
  bool _hasInitialScanStarted = false;
  BleProvider? _bleProviderRef;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasInitialScanStarted) {
      _bleProvider = Provider.of<BleProvider>(context, listen: false);

      _bleProvider.connectionStatus.addListener(_handleConnectionStatusChange);
      _bleProvider.isReconnectingNotifier
          .addListener(_handleReconnectStatusChange);

      _hasInitialScanStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndScan();
      });
    }
  }

  @override
  void dispose() {
    if (_bleProviderRef != null) {
      _bleProviderRef!.connectionStatus
          .removeListener(_handleConnectionStatusChange);
      _bleProviderRef!.isReconnectingNotifier
          .removeListener(_handleReconnectStatusChange);
      if (_bleProviderRef!.isScanning.value) {
        _bleProviderRef!.stopScan();
      }
    }
    super.dispose();
  }

  // --- LOGIC XỬ LÝ SỰ KIỆN ---

  void _handleConnectionStatusChange() async {
    if (!mounted) return;
    final status = _bleProvider.connectionStatus.value;

    if (status == BleConnectionStatus.connected) {
      final connectedDevice = context.read<BleProvider>().connectedDevice;
      if (connectedDevice != null) {
        final deviceId = connectedDevice.remoteId.toString();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              AppConstants.prefKeyConnectedDeviceId, deviceId);
        } catch (e) {
          print("!!! [DeviceSelectScreen] Error saving device ID: $e");
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainNavigator()),
          );
        }
      }
    } else if (status == BleConnectionStatus.error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.connectionFailedSnackbar),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleReconnectStatusChange() {
    if (!mounted) return;
    if (_bleProvider.isReconnectingNotifier.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.reconnectAttemptBody),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --- LOGIC XỬ LÝ QUYỀN VÀ QUÉT ---

  Future<void> _checkAndScan() async {
    if (!mounted) return;
    if (!await _checkPermissions()) return;
    if (!await _checkBluetoothState()) return;

    // Ở đây không cần logic retry, vì BleService đã có logic retry riêng
    context.read<BleProvider>().startScan();
  }

  Future<bool> _checkPermissions() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    List<Permission> permissionsToRequest = [];

    if (Platform.isAndroid) {
      permissionsToRequest
          .addAll([Permission.bluetoothScan, Permission.bluetoothConnect]);
    } else if (Platform.isIOS) {
      permissionsToRequest.add(Permission.bluetooth);
    }
    // Location permission có thể cần cho một số trường hợp, tạm thời để lại
    permissionsToRequest.add(Permission.locationWhenInUse);

    if (permissionsToRequest.isEmpty) return true;

    Map<Permission, PermissionStatus> statuses =
        await permissionsToRequest.request();
    bool allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.permissionDeniedSnackbar),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.settingsTitle.toUpperCase(),
            onPressed: openAppSettings,
          ),
        ),
      );
    }
    return allGranted;
  }

  Future<bool> _checkBluetoothState() async {
    if (!mounted) return false;
    await Future.delayed(const Duration(milliseconds: 200));

    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    }

    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.bluetoothRequestTitle),
            content: Text(l10n.bluetoothRequestMessage),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.cancel)),
              ElevatedButton(
                onPressed: () async {
                  if (Platform.isAndroid) {
                    await FlutterBluePlus.turnOn();
                  }
                  Navigator.of(context).pop(true);
                },
                child: Text(l10n.turnOn),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ================================================================
  // --- HÀM BUILD CHÍNH VÀ CÁC UI HELPER ---
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectDeviceTitle),
        actions: [
          _buildRefreshButton(),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBanner(),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<BleProvider>(
      builder: (context, provider, child) {
        bool isLoading =
            provider.isScanning.value || provider.isReconnectingNotifier.value;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5)))
              : IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 28),
                  tooltip: l10n.scanTooltip,
                  onPressed: _checkAndScan),
        );
      },
    );
  }

  Widget _buildStatusBanner() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ValueListenableBuilder<BleConnectionStatus>(
      valueListenable: _bleProvider.connectionStatus,
      builder: (context, status, child) {
        String statusText;
        Color statusColor;
        IconData statusIcon;

        // Ưu tiên trạng thái Reconnecting
        if (_bleProvider.isReconnectingNotifier.value) {
          statusText = l10n.reconnectAttemptBody;
          statusColor = theme.colorScheme.secondary;
          statusIcon = Icons.bluetooth_searching_rounded;
        } else {
          switch (status) {
            case BleConnectionStatus.scanning:
              statusText = l10n.scanningStatus;
              statusColor = theme.colorScheme.secondary;
              statusIcon = Icons.bluetooth_searching_rounded;
              break;
            case BleConnectionStatus.connecting:
            case BleConnectionStatus.discovering_services:
              statusText = l10n.statusConnecting;
              statusColor = Colors.orange.shade700;
              statusIcon = Icons.bluetooth_drive_rounded;
              break;
            case BleConnectionStatus.connected:
              statusText = l10n.statusConnected;
              statusColor = Colors.green.shade600;
              statusIcon = Icons.bluetooth_connected_rounded;
              break;
            case BleConnectionStatus.error:
              statusText = l10n.statusErrorPermissions;
              statusColor = theme.colorScheme.error;
              statusIcon = Icons.error_outline_rounded;
              break;
            case BleConnectionStatus.disconnected:
            default:
              statusText = l10n.statusDisconnectedScan;
              statusColor = theme.textTheme.bodySmall!.color!;
              statusIcon = Icons.bluetooth_disabled_rounded;
          }
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          color: statusColor.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: statusColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainContent() {
    return Consumer<BleProvider>(
      builder: (context, provider, child) {
        final l10n = AppLocalizations.of(context)!;
        final bool isLoading =
            provider.isScanning.value || provider.isReconnectingNotifier.value;
        final scanResults = provider.scanResults.value;

        if (scanResults.isNotEmpty) {
          return _buildDeviceList(scanResults);
        }
        if (isLoading) {
          return _buildLoadingState(l10n);
        }
        return _buildEmptyState(l10n);
      },
    );
  }

  Widget _buildDeviceList(List<ScanResult> scanResults) {
    scanResults.sort((a, b) => b.rssi.compareTo(a.rssi));
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: scanResults.length,
      itemBuilder: (context, index) {
        return _DeviceListItem(scanResult: scanResults[index]);
      },
    );
  }

  Widget _buildLoadingState(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // --- THAY ĐỔI Ở ĐÂY ---
        // Thay thế Lottie.asset bằng CircularProgressIndicator
        const CircularProgressIndicator(
          strokeWidth: 3,
        ),
        const SizedBox(height: 24), // Tăng khoảng cách một chút
        // -----------------------
        Text(l10n.scanningStatus,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            l10n.ensureDeviceNearby,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _checkAndScan,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.watch_off_outlined,
                    size: 80, color: Theme.of(context).disabledColor),
                const SizedBox(height: 24),
                Text(l10n.noDevicesFound,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(l10n.pullToScan,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// WIDGET CON CHO MỘT ITEM TRONG DANH SÁCH THIẾT BỊ
// ================================================================
class _DeviceListItem extends StatelessWidget {
  final ScanResult scanResult;
  const _DeviceListItem({required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final provider = context.watch<BleProvider>();
    final status = provider.connectionStatus.value;

    // Logic mới không cần 'connectingDeviceId'
    // Một nút sẽ bị vô hiệu hóa nếu có một hành động kết nối ĐANG diễn ra
    final bool isAnyDeviceConnecting =
        status == BleConnectionStatus.connecting ||
            status == BleConnectionStatus.discovering_services;

    // Nút sẽ hiển thị vòng xoay nếu ứng dụng đang kết nối tới CHÍNH thiết bị này.
    // Chúng ta biết điều này nếu thiết bị hiện tại đã là `connectedDevice` (trong quá trình discover)
    // HOẶC nếu trạng thái là connecting VÀ _DeviceListItem là thiết bị duy nhất trong list
    // (logic này không hoàn hảo, nhưng là cách tốt nhất mà không cần thay đổi provider)
    // CÁCH TỐT HƠN: Giả định là nếu 'isConnecting' thì nút nào cũng có thể là nó.
    // Chúng ta không biết được thiết bị nào đang được kết nối cho đến khi nó thực sự kết nối.
    // Vì vậy, để đơn giản và đúng, chúng ta chỉ cần biết LÀ đang kết nối hay không.

    final deviceName = scanResult.device.platformName.isNotEmpty
        ? scanResult.device.platformName
        : l10n.unknownDeviceName;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRssiIcon(scanResult.rssi, theme.colorScheme.primary),
            const SizedBox(height: 2),
            Text('${scanResult.rssi}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary, fontSize: 10)),
          ],
        ),
        title: Text(deviceName,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text("${l10n.deviceIdPrefix} ${scanResult.device.remoteId}",
            style: theme.textTheme.bodySmall),
        trailing: ElevatedButton(
          // Nút bị vô hiệu hóa nếu đang có một kết nối bất kỳ diễn ra
          onPressed: isAnyDeviceConnecting
              ? null
              : () {
                  provider.connectToDevice(scanResult.device);
                },
          // <<<<<< THAY ĐỔI LOGIC HIỂN THỊ >>>>>>>
          // Chỉ hiển thị vòng xoay trên TẤT CẢ các nút nếu một kết nối đang diễn ra.
          // Đây là một sự đánh đổi nhỏ về UI nhưng đảm bảo không cần thay đổi backend.
          child: isAnyDeviceConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l10n.connectButton),
        ),
      ),
    );
  }

  // Hàm này giữ nguyên
  /// Helper để hiển thị icon tín hiệu dựa trên RSSI
  Widget _buildRssiIcon(int rssi, Color color) {
    if (rssi > -67)
      return Icon(Icons.signal_cellular_4_bar_rounded, color: color);
    if (rssi > -80)
      return Icon(Icons.signal_cellular_alt_2_bar_rounded,
          color: color); // SỬA: Thêm "alt" và số
    if (rssi > -90)
      return Icon(Icons.signal_cellular_alt_1_bar_rounded,
          color: color); // SỬA: Thêm "alt" và số
    if (rssi > -100)
      return Icon(Icons.signal_cellular_alt_rounded,
          color: color); // SỬA: Chỉ có "alt"
    return Icon(Icons.signal_cellular_0_bar_rounded, color: color);
  }
}

// <<<<<<<<<<<<<<<< KẾT THÚC CODE HOÀN CHỈNH >>>>>>>>>>>>>>>>
