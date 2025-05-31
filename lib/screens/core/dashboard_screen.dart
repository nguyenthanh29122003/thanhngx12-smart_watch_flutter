//lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/ble_service.dart';
import '../../services/activity_recognition_service.dart';
import '../../widgets/dashboard/realtime_metrics_card.dart';
import '../../widgets/dashboard/history_chart_card.dart';
import '../../widgets/dashboard/spo2_history_chart_card.dart';
import '../../widgets/dashboard/steps_history_chart_card.dart';
import '../../app_constants.dart';
import '../../generated/app_localizations.dart';
import 'main_navigator.dart'; // Import MainNavigator để truy cập MainNavigatorState

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
  ActivityRecognitionService? _activityServiceRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboardStepGoal();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        print("[DashboardScreen] Starting initialization...");
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);
        _dashboardListener = () {
          if (mounted) _calculateTodaySteps(dashboardProvider);
        };
        dashboardProvider.addListener(_dashboardListener!);
        print("[DashboardScreen] Added dashboard listener.");

        try {
          if (dashboardProvider.historyStatus == HistoryStatus.initial) {
            print("[DashboardScreen] Fetching health history...");
            await dashboardProvider.fetchHealthHistory().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print("[DashboardScreen] fetchHealthHistory timed out.");
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            AppLocalizations.of(context)!.errorLoadingData)),
                  );
                }
              },
            );
          } else {
            print("[DashboardScreen] Calculating steps immediately.");
            _calculateTodaySteps(dashboardProvider);
          }

          final bleProvider = Provider.of<BleProvider>(context, listen: false);
          bleProvider.connectionStatus
              .addListener(_handleConnectionChangeForRefresh);
          _activityServiceRef =
              Provider.of<ActivityRecognitionService>(context, listen: false);
          if (_activityServiceRef != null && mounted) setState(() {});
        } catch (e) {
          print("[DashboardScreen] Initialization error: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text(AppLocalizations.of(context)!.errorLoadingData)),
            );
          }
        }
        print("[DashboardScreen] Initialization completed.");
      }
    });
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
    _activityServiceRef = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print(
          "[DashboardScreen] App Resumed - Reloading goal and recalculating steps.");
      _loadDashboardStepGoal();
      Provider.of<DashboardProvider>(context, listen: false)
          .fetchHealthHistory();
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
      print("Error loading step goal: $e");
      setStateIfMounted(() {
        _dashboardStepGoal = AppConstants.defaultDailyStepGoal;
        _isLoadingGoal = false;
      });
    }
  }

  void _handleConnectionChangeForRefresh() {
    if (!mounted) return;
    final bleStatus =
        Provider.of<BleProvider>(context, listen: false).connectionStatus.value;
    if (bleStatus == BleConnectionStatus.connected) {
      print("[DashboardScreen] Reconnected to BLE, refreshing history.");
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

  Widget _buildWifiStatusChip(bool? isWifiConnected) {
    final l10n = AppLocalizations.of(context)!;
    String statusText;
    Color color;
    IconData icon;
    bool connected = isWifiConnected ?? false;
    if (connected) {
      statusText = l10n.wifiStatusOn;
      color = Colors.teal;
      icon = Icons.wifi;
    } else {
      statusText = l10n.wifiStatusOff;
      color = Colors.grey;
      icon = Icons.wifi_off;
    }
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

  Widget _buildReconnectStatusCard() {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: Provider.of<BleProvider>(context).isReconnectingNotifier,
      builder: (context, isReconnecting, child) {
        if (!isReconnecting) return const SizedBox.shrink();
        return Card(
          elevation: 2.0,
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ListTile(
            leading: const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            title: Text(
              l10n.reconnectAttemptTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              l10n.reconnectAttemptBody,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      },
    );
  }

  void _calculateTodaySteps(DashboardProvider dashboardProvider) {
    if (dashboardProvider.historyStatus == HistoryStatus.loading ||
        dashboardProvider.historyStatus == HistoryStatus.initial) {
      print(
          "[DashboardScreen] Waiting for DashboardProvider to load history...");
      if (!_isLoadingTodaySteps)
        setStateIfMounted(() => _isLoadingTodaySteps = true);
      return;
    }

    if (dashboardProvider.healthHistory.isEmpty &&
        dashboardProvider.historyStatus != HistoryStatus.loading) {
      print("[DashboardScreen] No health history data available.");
      setStateIfMounted(() {
        _todaySteps = 0;
        _isLoadingTodaySteps = false;
      });
      return;
    }

    print("[DashboardScreen] Calculating today's steps...");
    if (!_isLoadingTodaySteps)
      setStateIfMounted(() => _isLoadingTodaySteps = true);

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
      print("[DashboardScreen] Hourly steps data is empty.");
    }

    setStateIfMounted(() {
      _todaySteps = calculatedSteps;
      _isLoadingTodaySteps = false;
      print("[DashboardScreen] Today's steps: $_todaySteps");
    });
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

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
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        l10n.welcomeUser(
                            user.displayName ?? user.email ?? l10n.defaultUser),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  _buildReconnectStatusCard(),
                  if (_activityServiceRef != null)
                    Card(
                      elevation: 2.0,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      child: StreamBuilder<String>(
                        stream: _activityServiceRef!.activityPredictionStream,
                        builder: (context, snapshot) {
                          IconData activityIcon = Icons.person_outline;
                          String activityText = l10n.activityInitializing;

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
                            activityIcon = Icons.hourglass_empty_outlined;
                          } else if (!snapshot.hasData) {
                            activityText = l10n.activityUnknown;
                            activityIcon = Icons.help_outline;
                          }

                          return ListTile(
                            leading: Icon(activityIcon,
                                size: 32,
                                color: Theme.of(context).colorScheme.primary),
                            title: Text(l10n.currentActivityTitle,
                                style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Text(
                              activityText,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  const RealtimeMetricsCard(),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2.0,
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined,
                          color: Colors.orangeAccent),
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
                          color: Theme.of(context).colorScheme.primary),
                      onTap: () {
                        try {
                          // Tìm MainNavigatorState trong context
                          final mainNavigatorState = context
                              .findAncestorStateOfType<MainNavigatorState>();
                          if (mainNavigatorState != null) {
                            mainNavigatorState
                                .navigateTo(AppConstants.goalsScreenIndex);
                          } else {
                            print(
                                "[DashboardScreen] MainNavigatorState not found in context.");
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.errorNavigateGoals),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        } catch (e) {
                          print("Error navigating to GoalsScreen: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.errorNavigateGoals),
                              backgroundColor: Colors.redAccent,
                            ),
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
