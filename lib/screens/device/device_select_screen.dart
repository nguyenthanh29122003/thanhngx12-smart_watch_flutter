// lib/screens/device/device_select_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app_constants.dart';
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';
import '../core/main_navigator.dart';
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

    try {
      _bleProvider.connectionStatus
          .removeListener(_handleConnectionStatusChange);
      _bleProvider.connectionStatus.addListener(_handleConnectionStatusChange);
      _bleProvider.isReconnectingNotifier
          .removeListener(_handleReconnectStatusChange);
      _bleProvider.isReconnectingNotifier
          .addListener(_handleReconnectStatusChange);
    } catch (e) {
      print("Error setting up listeners: $e");
    }

    if (!_hasInitialScanStarted) {
      _hasInitialScanStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndScan();
        }
      });
    }
  }

  @override
  void dispose() {
    try {
      _bleProvider.connectionStatus
          .removeListener(_handleConnectionStatusChange);
      _bleProvider.isReconnectingNotifier
          .removeListener(_handleReconnectStatusChange);
    } catch (e) {
      print("Error removing listeners on dispose: $e");
    }
    super.dispose();
  }

  void _handleConnectionStatusChange() async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final status = _bleProvider.connectionStatus.value;
    print("DeviceSelectScreen received connection status: $status");

    if (status == BleConnectionStatus.connected) {
      final connectedDevice = context.read<BleProvider>().connectedDevice;
      if (connectedDevice != null) {
        final deviceId = connectedDevice.remoteId.toString();
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              AppConstants.prefKeyConnectedDeviceId, deviceId);
          print("[DeviceSelectScreen] Saved device ID: $deviceId");
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
            content: Text(l10n.errorLoadingData),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleReconnectStatusChange() {
    if (!mounted) return;
    final isReconnecting = _bleProvider.isReconnectingNotifier.value;
    print("DeviceSelectScreen received reconnect status: $isReconnecting");
    if (isReconnecting && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.reconnectAttemptBody),
          backgroundColor: Colors.blueAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _checkAndScan() async {
    if (!mounted) return;
    if (!await _checkPermissions()) return;
    if (!await _checkBluetoothState()) return;
    print("[DeviceSelectScreen] Starting scan with retry...");
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        print("[DeviceSelectScreen] Scan attempt $attempt/3");
        await context.read<BleProvider>().startScan().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print("[DeviceSelectScreen] Scan timed out.");
            context.read<BleProvider>().stopScan();
            if (mounted && attempt == 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.errorLoadingData),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
        );
        if (context.read<BleProvider>().scanResults.value.isNotEmpty) {
          print("[DeviceSelectScreen] Devices found, stopping scan.");
          break;
        }
      } catch (e) {
        print("[DeviceSelectScreen] Scan error: $e");
        if (mounted && attempt == 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.errorLoadingData),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<bool> _checkPermissions() async {
    if (!mounted) return false;
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
    bool allGranted = statuses.values.every((s) => s.isGranted);
    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.permissionDeniedSnackbar),
          backgroundColor: Colors.orangeAccent,
        ),
      );
    }
    return allGranted;
  }

  Future<bool> _checkBluetoothState() async {
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context)!;
    await Future.delayed(const Duration(milliseconds: 200));
    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    }
    bool? userAllowedTurnOn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bluetoothRequestTitle),
        content: Text(l10n.bluetoothRequestMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop(true);
              try {
                if (Platform.isAndroid) {
                  await FlutterBluePlus.turnOn();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.enableBluetoothIOS)),
                  );
                }
              } catch (e) {
                print("Error turning on Bluetooth: $e");
              }
            },
            child: Text(l10n.turnOn),
          ),
        ],
      ),
    );

    if (userAllowedTurnOn == true) {
      await Future.delayed(const Duration(milliseconds: 500));
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.selectDeviceTitle),
        actions: [
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
                onPressed: provider.isScanning.value ||
                        provider.isReconnectingNotifier.value
                    ? null
                    : () {
                        print("[DeviceSelectScreen] Refresh button pressed.");
                        _checkAndScan();
                      },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ValueListenableBuilder<BleConnectionStatus>(
            valueListenable: _bleProvider.connectionStatus,
            builder: (context, status, child) {
              return ValueListenableBuilder<bool>(
                valueListenable: _bleProvider.isReconnectingNotifier,
                builder: (context, isReconnecting, child) {
                  String statusText = '';
                  Color statusColor = Colors.grey;
                  Widget? statusIndicator;
                  if (isReconnecting) {
                    statusText = l10n.reconnectAttemptBody;
                    statusIndicator = const LinearProgressIndicator();
                    statusColor = Colors.blue;
                  } else {
                    switch (status) {
                      case BleConnectionStatus.disconnected:
                        statusText = _bleProvider.isScanning.value
                            ? l10n.scanningStatus
                            : l10n.statusDisconnectedScan;
                        if (_bleProvider.isScanning.value) {
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
                    }
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
              );
            },
          ),
          Expanded(
            child: Consumer<BleProvider>(
              builder: (context, provider, child) {
                return ValueListenableBuilder<List<ScanResult>>(
                  valueListenable: provider.scanResults,
                  builder: (context, scanResults, child) {
                    final currentStatus = provider.connectionStatus.value;
                    final isConnectingOrConnected =
                        currentStatus == BleConnectionStatus.connecting ||
                            currentStatus ==
                                BleConnectionStatus.discovering_services ||
                            currentStatus == BleConnectionStatus.connected ||
                            provider.isReconnectingNotifier.value;

                    print(
                        "[DeviceSelectScreen] Scan results count: ${scanResults.length}, "
                        "isScanning: ${provider.isScanning.value}, "
                        "status: $currentStatus, "
                        "isReconnecting: ${provider.isReconnectingNotifier.value}");

                    if (scanResults.isNotEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          if (!provider.isScanning.value &&
                              !isConnectingOrConnected) {
                            print(
                                "[DeviceSelectScreen] Pull to refresh triggered.");
                            await _checkAndScan();
                          }
                        },
                        child: ListView.builder(
                          itemCount: scanResults.length,
                          itemBuilder: (context, index) {
                            ScanResult result = scanResults[index];
                            String deviceName =
                                result.device.platformName.isNotEmpty
                                    ? result.device.platformName
                                    : l10n.unknownDeviceName;
                            String deviceId = result.device.remoteId.toString();

                            print(
                                "[DeviceSelectScreen] Displaying device: $deviceName, "
                                "ID: $deviceId, RSSI: ${result.rssi}");

                            return ListTile(
                              leading: const Icon(Icons.watch),
                              title: Text(deviceName),
                              subtitle: Text(
                                  "${l10n.deviceIdPrefix} $deviceId\nRSSI: ${result.rssi} dBm"),
                              isThreeLine: true,
                              trailing: ElevatedButton(
                                onPressed: isConnectingOrConnected
                                    ? null
                                    : () {
                                        print(
                                            "Connect button pressed for $deviceId");
                                        context
                                            .read<BleProvider>()
                                            .connectToDevice(result.device);
                                      },
                                child: (currentStatus ==
                                            BleConnectionStatus.connecting ||
                                        currentStatus ==
                                            BleConnectionStatus
                                                .discovering_services ||
                                        provider.isReconnectingNotifier.value)
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text(l10n.connectButton),
                              ),
                            );
                          },
                        ),
                      );
                    }

                    if (provider.isScanning.value || isConnectingOrConnected) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 10),
                            Text(l10n.scanningStatus),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        if (!provider.isScanning.value &&
                            !isConnectingOrConnected) {
                          print(
                              "[DeviceSelectScreen] Pull to refresh triggered.");
                          await _checkAndScan();
                        }
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height - 100,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.noDevicesFound,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.ensureDeviceNearby,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.pullToScan,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      print(
                                          "[DeviceSelectScreen] Try Again button pressed.");
                                      _checkAndScan();
                                    },
                                    child: Text(l10n.tryAgain),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
