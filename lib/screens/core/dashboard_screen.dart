// lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // Cần cho xử lý ngày tháng

// Import Providers
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart'; // Cần để lấy hourlyStepsData

// Import Models and Services
import '../../models/health_data.dart'; // Cần cho ValueListenableBuilder nếu dùng
import '../../services/ble_service.dart'; // Cần cho enum BleConnectionStatus
import '../../services/notification_service.dart'; // Cần cho nút Test (nếu còn giữ)

// Import Widgets and Constants
import '../../widgets/dashboard/realtime_metrics_card.dart';
import '../../widgets/dashboard/history_chart_card.dart';
import '../../widgets/dashboard/spo2_history_chart_card.dart';
import '../../widgets/dashboard/steps_history_chart_card.dart';
import '../../app_constants.dart';

// Import MainNavigator State và GlobalKey (cần đảm bảo main.dart export key)
import '../core/main_navigator.dart'; // Import để có thể tham chiếu State (nếu dùng cách khác)
import '../../main.dart'; // <<< Import main.dart để lấy mainNavigatorKey (Cách tạm)

import '../../generated/app_localizations.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// Thêm 'with WidgetsBindingObserver' để lắng nghe vòng đời app
class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  // State cho mục tiêu (đọc từ Prefs)
  int _dashboardStepGoal = AppConstants.defaultDailyStepGoal;
  bool _isLoadingGoal = true;

  // State cho tổng số bước hôm nay và trạng thái tải/tính toán
  int _todaySteps = 0;
  bool _isLoadingTodaySteps = true;

  // Listener để theo dõi thay đổi trong DashboardProvider
  VoidCallback? _dashboardListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Đăng ký observer
    _loadDashboardStepGoal(); // Tải mục tiêu khi màn hình khởi tạo

    // Lắng nghe DashboardProvider và fetch lịch sử sau khi frame đầu tiên build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Luôn kiểm tra mounted
        final dashboardProvider =
            Provider.of<DashboardProvider>(context, listen: false);

        // Khởi tạo và đăng ký listener cho DashboardProvider
        _dashboardListener = () {
          if (mounted) {
            _calculateTodaySteps(
                dashboardProvider); // Tính lại steps khi provider báo thay đổi
          }
        };
        dashboardProvider.addListener(_dashboardListener!);
        print("[DashboardScreen] Added listener to DashboardProvider.");

        // Fetch dữ liệu lịch sử nếu cần (việc này sẽ trigger listener khi xong)
        if (dashboardProvider.historyStatus == HistoryStatus.initial) {
          print("[DashboardScreen] Fetching initial health history...");
          dashboardProvider.fetchHealthHistory();
        } else {
          // Nếu provider đã có dữ liệu (hoặc lỗi), tính toán steps ngay
          print(
              "[DashboardScreen] DashboardProvider already has data/error, calculating steps immediately.");
          _calculateTodaySteps(dashboardProvider);
        }

        // Lắng nghe trạng thái kết nối BLE (giữ nguyên)
        final bleProvider = Provider.of<BleProvider>(context, listen: false);
        bleProvider.connectionStatus
            .addListener(_handleConnectionChangeForRefresh);
      }
    });
    print("[DashboardScreen] initState completed.");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Hủy đăng ký observer

    // Hủy đăng ký listener DashboardProvider
    try {
      // Dùng tryRead hoặc Provider.of(listen: false) để an toàn
      Provider.of<DashboardProvider>(context, listen: false)
          .removeListener(_dashboardListener!);
      print("[DashboardScreen] Removed dashboard listener.");
    } catch (e) {
      print("Error removing dashboard listener in Dashboard dispose: $e");
    }

    // Hủy đăng ký listener BLE (giữ nguyên)
    try {
      context
          .read<BleProvider>()
          .connectionStatus
          .removeListener(_handleConnectionChangeForRefresh);
    } catch (e) {
      print("Error removing connection listener in Dashboard dispose: $e");
    }

    super.dispose();
  }

  // Hàm được gọi khi trạng thái vòng đời App thay đổi
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      print(
          "[DashboardScreen] App Resumed - Reloading goal and recalculating steps.");
      // Tải lại mục tiêu từ prefs và yêu cầu tính lại số bước khi app quay lại
      _loadDashboardStepGoal();
      final dashboardProvider =
          Provider.of<DashboardProvider>(context, listen: false);
      // Gọi fetch lại lịch sử (an toàn nhất, sẽ tự trigger tính lại steps)
      dashboardProvider.fetchHealthHistory();
      // Hoặc chỉ tính lại nếu bạn chắc chắn dữ liệu provider không cũ
      // _calculateTodaySteps(dashboardProvider);
    }
  }

  // Hàm tải mục tiêu từ SharedPreferences
  Future<void> _loadDashboardStepGoal() async {
    if (!mounted) return;
    // Đặt loading true để có phản hồi nếu người dùng vào lại màn hình nhanh
    if (!_isLoadingGoal) setStateIfMounted(() => _isLoadingGoal = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getInt(AppConstants.prefKeyDailyStepGoal);
      if (mounted) {
        setStateIfMounted(() {
          _dashboardStepGoal = savedGoal ?? AppConstants.defaultDailyStepGoal;
          _isLoadingGoal = false; // Mục tiêu đã tải xong
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

  // Hàm xử lý refresh khi kết nối lại BLE
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

  // Hàm build chip trạng thái BLE
  Widget _buildBleStatusChip(BleConnectionStatus status) {
    final l10n = AppLocalizations.of(context)!; // Lấy l10n
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
      label: Text(text, style: TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    ); // Giữ nguyên phần UI của Chip
  }

  // Hàm build chip trạng thái WiFi
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
    ); // Giữ nguyên phần UI của Chip
  }

  // Hàm tính toán tổng số bước hôm nay từ dữ liệu của DashboardProvider
  void _calculateTodaySteps(DashboardProvider dashboardProvider) {
    // Chỉ tính nếu provider không còn đang tải dữ liệu lịch sử
    if (dashboardProvider.historyStatus == HistoryStatus.loading ||
        dashboardProvider.historyStatus == HistoryStatus.initial) {
      print(
          "[DashboardScreen] Waiting for DashboardProvider to load history for step calculation...");
      if (!_isLoadingTodaySteps)
        setStateIfMounted(() => _isLoadingTodaySteps = true);
      return;
    }

    // Nếu không có dữ liệu lịch sử (ví dụ lỗi tải)
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
    if (!_isLoadingTodaySteps)
      setStateIfMounted(
          () => _isLoadingTodaySteps = true); // Đặt loading trước khi tính

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

    // Cập nhật state an toàn
    setStateIfMounted(() {
      _todaySteps = calculatedSteps;
      _isLoadingTodaySteps = false; // Đánh dấu đã tính xong
      print(
          "[DashboardScreen] Step calculation complete. Today's steps: $_todaySteps");
    });
  }

  // Hàm helper setState an toàn
  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
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

    // Trạng thái loading chính (chỉ check tải mục tiêu cho đơn giản)
    final bool isLoadingScreen = _isLoadingGoal;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle), // TODO: Dịch
        automaticallyImplyLeading: false,
        actions: [
          // Hiển thị Chip WiFi và BLE
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // <<< SỬA LẠI PHẦN HIỂN THỊ WIFI CHIP >>>
                  if (isDeviceConnected) // Chỉ hiển thị khi kết nối
                    _buildWifiStatusChip(
                        espWifiStatus) // Gọi trực tiếp với giá trị đã lấy
                  else
                    const SizedBox
                        .shrink(), // Không hiển thị gì nếu không kết nối
                  // --------------------------------------
                  if (isDeviceConnected)
                    const SizedBox(width: 4), // Khoảng cách
                  // Chip BLE giữ nguyên ValueListenableBuilder vì connectionStatus là ValueNotifier
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
                await _loadDashboardStepGoal(); // Tải lại mục tiêu
                await Provider.of<DashboardProvider>(context, listen: false)
                    .fetchHealthHistory(); // Tải lại lịch sử
              },
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Lời chào
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        // <<< DÙNG KEY VÀ PLACEHOLDER >>>
                        l10n.welcomeUser(
                            user.displayName ?? user.email ?? l10n.defaultUser),
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ), // Giữ nguyên UI Lời chào

                  // Nút Test Notification (Nếu còn giữ)
                  // Padding(
                  //   child: ElevatedButton.icon(
                  //     label: Text(l10n.testNotificationButton), // <<< DÙNG KEY
                  //     onPressed: () {
                  //        // ...
                  //        ScaffoldMessenger.of(context).showSnackBar(
                  //          SnackBar(content: Text(l10n.testNotificationSent)), // <<< DÙNG KEY
                  //        );
                  //     }
                  //   )
                  // ),
                  // const SizedBox(height: 20),

                  // Widget Chỉ Số Realtime
                  const RealtimeMetricsCard(),
                  const SizedBox(height: 16),

                  // --- Placeholder Mục Tiêu (ĐÃ SỬA LẠI HOÀN CHỈNH) ---
                  Card(
                    elevation: 2.0,
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(l10n.goalProgressTitle), // TODO: Dịch
                      subtitle:
                          _isLoadingTodaySteps // <<< KIỂM TRA LOADING STEPS >>>
                              ? Row(
                                  // Hiển thị indicator nhỏ khi đang tính/chờ
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                    SizedBox(width: 8),
                                    Text(l10n.stepsCalculating), // TODO: Dịch
                                  ],
                                )
                              // <<< HIỂN THỊ _todaySteps và _dashboardStepGoal >>>
                              : Text(l10n.stepsProgress('$_todaySteps',
                                  '$_dashboardStepGoal')), // TODO: Dịch 'Steps:'
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // <<< SỬ DỤNG GLOBAL KEY ĐỂ ĐIỀU HƯỚNG >>>
                        try {
                          // Truy cập GlobalKey từ main.dart (cần import main.dart)
                          // Đảm bảo key đã được tạo và truyền vào MainNavigator
                          mainNavigatorKey.currentState
                              ?.navigateTo(2); // Giả sử index 2 là Goals
                        } catch (e) {
                          print(
                              "!!! [DashboardScreen] Error navigating using GlobalKey: $e");
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(l10n.errorNavigateGoals),
                                backgroundColor: Colors.orange),
                          );
                        }
                        // ------------------------------------------
                      },
                    ),
                  ),
                  // ------------------------------------------------------

                  const SizedBox(height: 16),

                  // --- Các Widget Biểu Đồ ---
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
