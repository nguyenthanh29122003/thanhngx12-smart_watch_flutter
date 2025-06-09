// lib/providers/dashboard_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import các Providers cần thiết
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/goals_provider.dart';

// Import các Services và Models
import '../../services/ble_service.dart';
import '../../services/activity_recognition_service.dart';

// Import các Widgets và Constants
import '../../widgets/dashboard/realtime_metrics_card.dart';
import '../../widgets/dashboard/history_chart_card.dart';
import '../../widgets/dashboard/spo2_history_chart_card.dart';
import '../../widgets/dashboard/steps_history_chart_card.dart';
import '../../widgets/dashboard/activity_summary_chart_card.dart';
import '../../app_constants.dart';
import '../../generated/app_localizations.dart';
import 'main_navigator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // Vẫn cần tham chiếu đến service này để lắng nghe stream
  ActivityRecognitionService? _activityServiceRef;

  // <<< SỬA Ở ĐÂY: Thay vì StreamSubscription, chúng ta sẽ dùng lại VoidCallback listener >>>
  VoidCallback? _connectionStatusListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print("[DashboardScreen] Starting initialization...");

        final bleProvider = Provider.of<BleProvider>(context, listen: false);
        _activityServiceRef =
            Provider.of<ActivityRecognitionService>(context, listen: false);

        // <<< SỬA LỖI: Sử dụng addListener cho ValueNotifier thay vì .stream.listen >>>
        _connectionStatusListener = () {
          _handleConnectionChangeForRefresh(bleProvider.connectionStatus.value);
        };
        bleProvider.connectionStatus.addListener(_connectionStatusListener!);
        // --------------------------------------------------------------------

        if (_activityServiceRef != null) {
          setState(() {});
        }

        print("[DashboardScreen] Initialization completed.");
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // <<< SỬA Ở ĐÂY: Hủy listener một cách an toàn >>>
    if (_connectionStatusListener != null) {
      try {
        // Cần truy cập provider một lần nữa để xóa listener
        Provider.of<BleProvider>(context, listen: false)
            .connectionStatus
            .removeListener(_connectionStatusListener!);
      } catch (e) {
        print(
            "Error removing connection listener in DashboardScreen dispose: $e");
      }
    }
    // ----------------------------------------------------

    _activityServiceRef = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print(
          "[DashboardScreen] App Resumed - Triggering data refresh from providers.");
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);

      dashboardProvider.fetchHealthHistory();
      goalsProvider.loadDailyGoal();
    }
  }

  void _handleConnectionChangeForRefresh(BleConnectionStatus status) {
    // Không cần truy cập provider ở đây nữa vì status đã được truyền vào
    if (status == BleConnectionStatus.connected) {
      print(
          "[DashboardScreen] Reconnected to BLE, refreshing history after a short delay.");
      // Dùng Future.delayed để chờ thiết bị ổn định một chút
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Provider.of<DashboardProvider>(context, listen: false)
              .fetchHealthHistory();
        }
      });
    }
  }

  // --- Các hàm build widget (_build...Chip, _buildReconnectStatusCard) không thay đổi ---
  Widget _buildBleStatusChip(
      BleConnectionStatus status, AppLocalizations l10n) {
    String statusText;
    Color color;
    IconData icon;
    switch (status) {
      case BleConnectionStatus.connected:
        statusText = l10n.bleStatusConnected;
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.discovering_services:
        statusText = l10n.bleStatusConnecting;
        color = Colors.orange;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        statusText = l10n.bleStatusDisconnected;
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionStatus.scanning:
        statusText = l10n.bleStatusScanning;
        color = Colors.blue;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        statusText = l10n.bleStatusError;
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        statusText = l10n.bleStatusUnknown;
        color = Colors.grey;
        icon = Icons.bluetooth;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(statusText, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    );
  }

  Widget _buildWifiStatusChip(bool? isWifiConnected, AppLocalizations l10n) {
    bool connected = isWifiConnected ?? false;
    String statusText = connected ? l10n.wifiStatusOn : l10n.wifiStatusOff;
    Color color = connected ? Colors.teal : Colors.grey;
    IconData icon = connected ? Icons.wifi : Icons.wifi_off;

    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label: Text(statusText,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildReconnectStatusCard(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Lắng nghe notifier từ BleProvider
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<BleProvider>().isReconnectingNotifier,
      builder: (context, isReconnecting, child) {
        if (!isReconnecting) return const SizedBox.shrink();
        return Card(
          elevation: 2.0,
          color:
              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.7),
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ListTile(
            leading: const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            title: Text(l10n.reconnectAttemptTitle,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(l10n.reconnectAttemptBody,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        );
      },
    );
  }

  // --- Các hàm helper cho activity (không thay đổi) ---
  String _getLocalizedActivityName(String activityKey, AppLocalizations l10n) {
    switch (activityKey) {
      case 'Standing':
        return l10n.activityStanding;
      case 'Lying':
        return l10n.activityLying;
      case 'Sitting':
        return l10n.activitySitting;
      case 'Walking':
        return l10n.activityWalking;
      case 'Running':
        return l10n.activityRunning;
      default:
        return l10n.activityUnknown;
    }
  }

  IconData _getActivityIcon(String activityKey) {
    switch (activityKey) {
      case 'Standing':
        return Icons.accessibility_new_outlined;
      case 'Lying':
        return Icons.hotel_outlined;
      case 'Sitting':
        return Icons.chair_outlined;
      case 'Walking':
        return Icons.directions_walk_outlined;
      case 'Running':
        return Icons.directions_run_outlined;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final authProvider = context.watch<AuthProvider>();
    final bleProvider = context.watch<BleProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final goalsProvider = context.watch<GoalsProvider>();

    final user = authProvider.user;
    final connectionStatus = bleProvider.connectionStatus.value;
    final isDeviceConnected = connectionStatus == BleConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDeviceConnected)
                    ValueListenableBuilder<bool?>(
                        valueListenable: bleProvider.deviceWifiStatusNotifier,
                        builder: (context, isWifiOn, child) {
                          return _buildWifiStatusChip(isWifiOn, l10n);
                        }),
                  if (isDeviceConnected) const SizedBox(width: 4),
                  _buildBleStatusChip(connectionStatus, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          print("[DashboardScreen] Pull to refresh triggered.");
          await Future.wait([
            dashboardProvider.fetchHealthHistory(),
            goalsProvider.loadDailyGoal()
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  l10n.welcomeUser(
                      authProvider.preferredDisplayName ?? l10n.defaultUser),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),

            _buildReconnectStatusCard(context),

            if (_activityServiceRef != null)
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: StreamBuilder<String>(
                  stream: _activityServiceRef!.activityPredictionStream,
                  builder: (context, snapshot) {
                    IconData activityIcon;
                    String activityText;

                    if (snapshot.hasError) {
                      activityText = l10n.activityError;
                      activityIcon = Icons.error_outline;
                    } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      final currentActivity = snapshot.data!;
                      activityText =
                          _getLocalizedActivityName(currentActivity, l10n);
                      activityIcon = _getActivityIcon(currentActivity);
                    } else {
                      activityText = l10n.activityInitializing;
                      activityIcon = Icons.hourglass_empty_outlined;
                    }

                    return ListTile(
                      leading: Icon(activityIcon,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(l10n.currentActivityTitle,
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(
                        activityText,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                      ),
                    );
                  },
                ),
              ),

            const RealtimeMetricsCard(),
            const SizedBox(height: 16),

            // <<< SỬA LỖI Ở ĐÂY: Mỗi widget biểu đồ chỉ được gọi MỘT lần >>>
            const ActivitySummaryChartCard(),
            const SizedBox(height: 16),
            // -----------------------------------------------------------

            Card(
              elevation: 2.0,
              child: ListTile(
                leading:
                    const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                title: Text(l10n.goalProgressTitle),
                subtitle: (dashboardProvider.historyStatus ==
                            HistoryStatus.loading ||
                        goalsProvider.isLoadingGoal)
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 8),
                          Text(l10n.loadingMessage),
                        ],
                      )
                    : Text(l10n.stepsProgress(
                        dashboardProvider.todayTotalSteps.toString(),
                        goalsProvider.currentStepGoal.toString(),
                      )),
                trailing: Icon(Icons.settings_outlined,
                    color: Theme.of(context).colorScheme.primary),
                onTap: () {
                  try {
                    final mainNavigatorState =
                        context.findAncestorStateOfType<MainNavigatorState>();
                    if (mainNavigatorState != null) {
                      mainNavigatorState
                          .navigateTo(AppConstants.goalsScreenIndex);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(l10n.errorNavigateGoals),
                              backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  } catch (e) {
                    print("Error navigating to GoalsScreen: $e");
                  }
                },
              ),
            ),
            const SizedBox(height: 16),

            // <<< SỬA LỖI Ở ĐÂY: Xóa dòng HistoryChartCard bị lặp lại >>>
            const HistoryChartCard(),
            const SizedBox(height: 16),
            const Spo2HistoryChartCard(),
            const SizedBox(height: 16),
            StepsHistoryChartCard(),
            const SizedBox(height: 16),
            // ----------------------------------------------------
          ],
        ),
      ),
    );
  }
}
