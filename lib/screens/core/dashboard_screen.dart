// lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart'; // Không thấy dùng trực tiếp trong file này nữa

// Import Providers
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart';

// Import Models and Services
// import '../../models/health_data.dart'; // Không thấy dùng trực tiếp
import '../../services/ble_service.dart'; // Cần cho enum BleConnectionStatus
// import '../../services/notification_service.dart'; // Không thấy dùng trực tiếp
import '../../services/activity_recognition_service.dart'; // <<< THÊM IMPORT NÀY

// Import Widgets and Constants
import '../../widgets/dashboard/realtime_metrics_card.dart';
import '../../widgets/dashboard/history_chart_card.dart';
import '../../widgets/dashboard/spo2_history_chart_card.dart';
import '../../widgets/dashboard/steps_history_chart_card.dart';
import '../../app_constants.dart';

// Import MainNavigator State và GlobalKey
// import '../core/main_navigator.dart'; // Không cần nếu chỉ dùng key
import '../../main.dart'; // Import main.dart để lấy mainNavigatorKey

import '../../generated/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _dashboardStepGoal = AppConstants.defaultDailyStepGoal;
  bool _isLoadingGoal = true;
  int _todaySteps = 0;
  bool _isLoadingTodaySteps = true;
  VoidCallback? _dashboardListener;

  // <<< THÊM THAM CHIẾU ĐẾN ACTIVITY RECOGNITION SERVICE >>>
  ActivityRecognitionService? _activityServiceRef;
  // ----------------------------------------------------

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardStepGoal();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);

        _dashboardListener = () {
          if (mounted) {
            _calculateTodaySteps(dashboardProvider);
          }
        };
        dashboardProvider.addListener(_dashboardListener!);
        print("[DashboardScreen] Added listener to DashboardProvider.");

        if (dashboardProvider.historyStatus == HistoryStatus.initial) {
          print("[DashboardScreen] Fetching initial health history...");
          dashboardProvider.fetchHealthHistory();
        } else {
          print(
              "[DashboardScreen] DashboardProvider already has data/error, calculating steps immediately.");
          _calculateTodaySteps(dashboardProvider);
        }

        final bleProvider = Provider.of<BleProvider>(context, listen: false);
        bleProvider.connectionStatus
            .addListener(_handleConnectionChangeForRefresh);

        // <<< LẤY THAM CHIẾU ACTIVITY SERVICE >>>
        _activityServiceRef =
            Provider.of<ActivityRecognitionService>(context, listen: false);
        // setState ở đây để build lại nếu _activityServiceRef vừa được gán
        // và StreamBuilder cần nó ngay lập tức.
        // Tuy nhiên, nếu StreamBuilder xử lý null cho stream thì không cần.
        // Hiện tại, StreamBuilder có kiểm tra _activityServiceRef != null.
        if (_activityServiceRef != null && mounted) {
          setState(
              () {}); // Để đảm bảo StreamBuilder được build với service nếu nó vừa có
        }
        // ------------------------------------
      }
    });
    print("[DashboardScreen] initState completed.");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    try {
      Provider.of<DashboardProvider>(context, listen: false)
          .removeListener(_dashboardListener!);
      print("[DashboardScreen] Removed dashboard listener.");
    } catch (e) {
      print("Error removing dashboard listener in Dashboard dispose: $e");
    }

    try {
      context
          .read<BleProvider>()
          .connectionStatus
          .removeListener(_handleConnectionChangeForRefresh);
    } catch (e) {
      print("Error removing connection listener in Dashboard dispose: $e");
    }
    _activityServiceRef = null; // Dọn dẹp tham chiếu
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print(
          "[DashboardScreen] App Resumed - Reloading goal and recalculating steps.");
      _loadDashboardStepGoal();
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      dashboardProvider.fetchHealthHistory();
    }
  }

  Future<void> _loadDashboardStepGoal() async {
    if (!mounted) return;
    if (!_isLoadingGoal) setStateIfMounted(() => _isLoadingGoal = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getInt(AppConstants.prefKeyDailyStepGoal);
      if (mounted) {
        setStateIfMounted(() {
          _dashboardStepGoal = savedGoal ?? AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false;
        });
        print(
            "[DashboardScreen] Loaded step goal from SharedPreferences: $_dashboardStepGoal");
      }
    } catch (e) {
      print(
          "!!! [DashboardScreen] Error loading step goal from SharedPreferences: $e");
      if (mounted) {
        setStateIfMounted(() {
          _dashboardStepGoal = AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false;
        });
      }
    }
  }

  void _handleConnectionChangeForRefresh() {
    if (!mounted) return;
    final bleStatus =
        Provider.of<BleProvider>(context, listen: false).connectionStatus.value;
    if (bleStatus == BleConnectionStatus.connected) {
      print(
          "[DashboardScreen] Reconnected to BLE, refreshing history (will trigger step recalc)...");
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Provider.of<DashboardProvider>(context, listen: false)
              .fetchHealthHistory();
        }
      });
    }
  }

  Widget _buildBleStatusChip(BleConnectionStatus status) {
    final l10n = AppLocalizations.of(context)!;
    String text;
    Color color;
    IconData icon;
    switch (status) {
      case BleConnectionStatus.connected:
        text = l10n.bleStatusConnected;
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.discovering_services:
        text = l10n.bleStatusConnecting;
        color = Colors.orange;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        text = l10n.bleStatusDisconnected;
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionStatus.scanning:
        text = l10n.bleStatusScanning;
        color = Colors.blue;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        text = l10n.bleStatusError;
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        text = l10n.bleStatusUnknown;
        color = Colors.grey;
        icon = Icons.bluetooth;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    );
  }

  Widget _buildWifiStatusChip(bool? isWifiConnected) {
    final l10n = AppLocalizations.of(context)!;
    String text;
    Color color;
    IconData icon;
    bool connected = isWifiConnected ?? false;
    if (connected) {
      text = l10n.wifiStatusOn;
      color = Colors.teal;
      icon = Icons.wifi;
    } else {
      text = l10n.wifiStatusOff;
      color = Colors.grey;
      icon = Icons.wifi_off;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 16),
      label:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 11)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _calculateTodaySteps(DashboardProvider dashboardProvider) {
    if (dashboardProvider.historyStatus == HistoryStatus.loading ||
        dashboardProvider.historyStatus == HistoryStatus.initial) {
      print(
          "[DashboardScreen] Waiting for DashboardProvider to load history for step calculation...");
      if (!_isLoadingTodaySteps) {
        setStateIfMounted(() => _isLoadingTodaySteps = true);
      }
      return;
    }

    if (dashboardProvider.healthHistory.isEmpty &&
        dashboardProvider.historyStatus != HistoryStatus.loading) {
      print(
          "[DashboardScreen] No health history data available to calculate steps.");
      setStateIfMounted(() {
        _todaySteps = 0;
        _isLoadingTodaySteps = false;
      });
      return;
    }

    print(
        "[DashboardScreen] Calculating today's steps using DashboardProvider data...");
    if (!_isLoadingTodaySteps) {
      setStateIfMounted(() => _isLoadingTodaySteps = true);
    }

    final List<HourlyStepsData> hourlyStepsList =
        dashboardProvider.hourlyStepsData;
    int calculatedSteps = 0;

    if (hourlyStepsList.isNotEmpty) {
      final nowLocal = DateTime.now();
      final todayStart = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      for (var hourlyData in hourlyStepsList) {
        final dataHourLocal = hourlyData.hourStart.toLocal();
        if (!dataHourLocal.isBefore(todayStart) &&
            dataHourLocal.isBefore(todayEnd)) {
          calculatedSteps += hourlyData.steps;
        }
      }
    } else {
      print(
          "[DashboardScreen] Hourly steps data calculated by DashboardProvider is empty.");
    }

    setStateIfMounted(() {
      _todaySteps = calculatedSteps;
      _isLoadingTodaySteps = false;
      print(
          "[DashboardScreen] Step calculation complete. Today's steps: $_todaySteps");
    });
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  // <<< HELPER FUNCTIONS CHO HIỂN THỊ HOẠT ĐỘNG >>>
  String _getLocalizedActivityName(String activityKey, AppLocalizations l10n) {
    switch (activityKey) {
      case 'Standing':
        return l10n.activityStanding; // Giả sử có localization key
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
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final bleProvider = context.watch<BleProvider>();
    final connectionStatus = bleProvider.connectionStatus.value;
    final latestData = bleProvider.latestHealthData;
    final isDeviceConnected = connectionStatus == BleConnectionStatus.connected;
    final bool? espWifiStatus = isDeviceConnected ? latestData?.wifi : null;

    final l10n = AppLocalizations.of(context)!;
    final bool isLoadingScreen = _isLoadingGoal;

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
                    _buildWifiStatusChip(espWifiStatus)
                  else
                    const SizedBox.shrink(),
                  if (isDeviceConnected) const SizedBox(width: 4),
                  ValueListenableBuilder<BleConnectionStatus>(
                    valueListenable: bleProvider.connectionStatus,
                    builder: (context, status, child) =>
                        _buildBleStatusChip(status),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: isLoadingScreen
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                print("[DashboardScreen] Pull to refresh triggered.");
                await _loadDashboardStepGoal();
                await Provider.of<DashboardProvider>(context, listen: false)
                    .fetchHealthHistory();
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: 16.0), // Tăng padding bottom
                      child: Text(
                        l10n.welcomeUser(
                            user.displayName ?? user.email ?? l10n.defaultUser),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall, // Thay đổi style
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // <<< WIDGET HIỂN THỊ HOẠT ĐỘNG HIỆN TẠI >>>
                  if (_activityServiceRef != null)
                    Card(
                      elevation: 2.0,
                      margin:
                          const EdgeInsets.only(bottom: 16.0), // Thêm margin
                      child: StreamBuilder<String>(
                        stream: _activityServiceRef!.activityPredictionStream,
                        builder: (context, snapshot) {
                          IconData activityIcon =
                              Icons.person_outline; // Icon mặc định chung hơn
                          String activityText = l10n
                              .activityInitializing; // Mặc định là đang khởi tạo

                          if (snapshot.hasError) {
                            activityText = l10n.activityError;
                            activityIcon = Icons.error_outline;
                            print(
                                "[DashboardScreen] Error on activity stream: ${snapshot.error}");
                          } else if (snapshot.hasData &&
                              snapshot.data!.isNotEmpty) {
                            final currentActivity = snapshot.data!;
                            activityText = _getLocalizedActivityName(
                                currentActivity, l10n);
                            activityIcon = _getActivityIcon(currentActivity);
                          } else if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !snapshot.hasData) {
                            // Giữ activityText là initializing
                            activityIcon = Icons.hourglass_empty_outlined;
                          } else if (!snapshot.hasData) {
                            activityText = l10n
                                .activityUnknown; // Nếu stream active nhưng không có data
                            activityIcon = Icons.help_outline;
                          }

                          return ListTile(
                            leading: Icon(activityIcon,
                                size: 32,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary), // Tăng size icon
                            title: Text(l10n.currentActivityTitle,
                                style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text(
                              activityText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    // Tăng size text
                                    fontWeight: FontWeight
                                        .w600, // Điều chỉnh font weight
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  // -------------------------------------------

                  const RealtimeMetricsCard(),
                  const SizedBox(height: 16),

                  Card(
                    elevation: 2.0,
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined,
                          color: Colors.orangeAccent), // Thêm màu
                      title: Text(l10n.goalProgressTitle),
                      subtitle: _isLoadingTodaySteps
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                                const SizedBox(width: 8),
                                Text(l10n.stepsCalculating),
                              ],
                            )
                          : Text(l10n.stepsProgress(
                              '$_todaySteps', '$_dashboardStepGoal')),
                      trailing: Icon(Icons.settings_outlined,
                          color: Theme.of(context)
                              .colorScheme
                              .primary), // Đổi icon
                      onTap: () {
                        try {
                          mainNavigatorKey.currentState?.navigateTo(
                              AppConstants.goalsScreenIndex); // Sử dụng hằng số
                        } catch (e) {
                          print(
                              "!!! [DashboardScreen] Error navigating using GlobalKey: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.errorNavigateGoals),
                                backgroundColor: Colors.redAccent), // Đổi màu
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  const HistoryChartCard(),
                  const SizedBox(height: 16),
                  const Spo2HistoryChartCard(),
                  const SizedBox(height: 16),
                  StepsHistoryChartCard(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
