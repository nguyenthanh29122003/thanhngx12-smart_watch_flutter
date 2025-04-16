// lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart'; // <<< Import DashboardProvider
import '../../services/ble_service.dart';
import '../../widgets/dashboard/realtime_metrics_card.dart'; // <<< Import Widget Con
import '../../widgets/dashboard/history_chart_card.dart'; // <<< Import Widget Con
import '../../widgets/dashboard/spo2_history_chart_card.dart'; // <<< Import Widget Con
import '../../widgets/dashboard/steps_history_chart_card.dart'; // <<< Import Widget Con
import '../../app_constants.dart'; // <<< Import AppConstants
import '../../services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/main_navigator.dart';

class DashboardScreen extends StatefulWidget {
  // <<< CHUYỂN THÀNH STATEFUL
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // <<< TẠO STATE
  // --- THÊM STATE CHO MỤC TIÊU CỦA DASHBOARD ---
  int _dashboardStepGoal = AppConstants.defaultDailyStepGoal;
  bool _isLoadingDashboardGoal = true;
  // ------------------------------------------
  @override
  void initState() {
    super.initState();
    _loadDashboardGoal();
    // Gọi fetch data lần đầu khi màn hình được tạo
    // Dùng addPostFrameCallback để đảm bảo context đã sẵn sàng và provider đã được build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Lấy DashboardProvider (listen: false vì chỉ gọi hàm)
      final dashboardProvider = Provider.of<DashboardProvider>(
        context,
        listen: false,
      );
      // Chỉ fetch nếu trạng thái là initial để tránh gọi lại khi hot reload/rebuild
      if (dashboardProvider.historyStatus == HistoryStatus.initial) {
        dashboardProvider.fetchHealthHistory();
      }
      // Lắng nghe thay đổi trạng thái kết nối để refresh nếu cần
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      bleProvider.connectionStatus.addListener(
        _handleConnectionChangeForRefresh,
      );
    });
  }

  // --- THÊM HÀM ĐỌC MỤC TIÊU TỪ SHAREDPREFERENCES ---
  Future<void> _loadDashboardGoal() async {
    // Không cần setState isLoading = true vì giá trị khởi tạo đã là true
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGoal = prefs.getInt(AppConstants.prefKeyDailyStepGoal);
      if (mounted) {
        // Kiểm tra mounted trước khi setState
        setState(() {
          _dashboardStepGoal = savedGoal ?? AppConstants.defaultDailyStepGoal;
          _isLoadingDashboardGoal = false; // Đánh dấu đã tải xong
        });
        print(
            "[DashboardScreen] Loaded step goal from Prefs: $_dashboardStepGoal");
      }
    } catch (e) {
      print("!!! [DashboardScreen] Error loading step goal from Prefs: $e");
      if (mounted) {
        setState(() {
          _dashboardStepGoal =
              AppConstants.defaultDailyStepGoal; // Dùng default nếu lỗi
          _isLoadingDashboardGoal = false; // Đánh dấu đã tải xong (dù là lỗi)
        });
      }
    }
  }
  // -------------------------------------------------

  @override
  void dispose() {
    // Hủy listener khi màn hình bị hủy
    // Dùng try-read để tránh lỗi nếu provider bị dispose trước
    try {
      Provider.of<BleProvider>(
        context,
        listen: false,
      ).connectionStatus.removeListener(_handleConnectionChangeForRefresh);
    } catch (e) {
      print("Error removing connection listener in Dashboard dispose: $e");
    }
    super.dispose();
  }

  // Hàm để tải lại dữ liệu lịch sử khi kết nối lại BLE (tùy chọn)
  void _handleConnectionChangeForRefresh() {
    if (!mounted) {
      print(
          "[DashboardScreen] _handleConnectionChangeForRefresh called but widget is unmounted. Ignoring.");
      return;
    }
    final bleStatus =
        Provider.of<BleProvider>(context, listen: false).connectionStatus.value;
    if (bleStatus == BleConnectionStatus.connected) {
      print("[DashboardScreen] Reconnected to BLE, refreshing history...");
      Future.delayed(const Duration(seconds: 2), () {
        // Kiểm tra mounted lần nữa trước khi thực hiện thao tác bất đồng bộ
        if (mounted) {
          Provider.of<DashboardProvider>(context, listen: false)
              .fetchHealthHistory();
        }
      });
    }
  }

  // Hàm helper để lấy text và màu cho trạng thái BLE (giữ nguyên)
  Widget _buildBleStatusChip(BleConnectionStatus status) {
    String text;
    Color color;
    IconData icon;
    switch (status) {
      /*...*/
      case BleConnectionStatus.connected:
        text = 'Connected';
        color = Colors.green;
        icon = Icons.bluetooth_connected;
        break;
      case BleConnectionStatus.connecting:
      case BleConnectionStatus.discovering_services:
        text = 'Connecting...';
        color = Colors.orange;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.disconnected:
        text = 'Disconnected';
        color = Colors.grey;
        icon = Icons.bluetooth_disabled;
        break;
      case BleConnectionStatus.scanning:
        text = 'Scanning...';
        color = Colors.blue;
        icon = Icons.bluetooth_searching;
        break;
      case BleConnectionStatus.error:
        text = 'Error';
        color = Colors.red;
        icon = Icons.error_outline;
        break;
      default:
        text = 'Unknown';
        color = Colors.grey;
        icon = Icons.bluetooth;
    }
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: TextStyle(color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ValueListenableBuilder<BleConnectionStatus>(
                valueListenable: context.read<BleProvider>().connectionStatus,
                builder: (context, status, child) =>
                    _buildBleStatusChip(status),
              ),
            ),
          ),
        ],
      ),
      // Sử dụng RefreshIndicator để cho phép kéo xuống làm mới dữ liệu lịch sử
      body: RefreshIndicator(
        onRefresh: () async {
          print("[DashboardScreen] Pull to refresh triggered.");
          // Gọi hàm fetch lại từ DashboardProvider
          await Provider.of<DashboardProvider>(
            context,
            listen: false,
          ).fetchHealthHistory();
        },
        child: ListView(
          // ListView là cần thiết cho RefreshIndicator hoạt động
          padding: const EdgeInsets.all(16.0),
          children: [
            // --- Lời chào ---
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0), // Giảm padding
                child: Text(
                  'Welcome, ${user.displayName ?? user.email ?? 'User'}!',
                  style:
                      Theme.of(context).textTheme.titleLarge, // Dùng titleLarge
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 16),
            // --- NÚT TEST THÔNG BÁO TẠM THỜI --- // <<< THÊM VÀO ĐÂY
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 40.0), // Canh giữa chút
              child: ElevatedButton.icon(
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, // Màu nổi bật
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  // Lấy instance NotificationService (đã được cung cấp trong main.dart)
                  final notificationService =
                      context.read<NotificationService>();

                  // Gọi hàm hiển thị thông báo
                  notificationService.showSimpleNotification(
                    id: 999, // ID duy nhất cho thông báo test này
                    title: "Smart Wearable Test",
                    body:
                        "Đây là thông báo kiểm tra hoạt động! ${DateTime.now().second}s",
                    payload: "test_button_tapped", // Dữ liệu gửi kèm (tùy chọn)
                    // Chỉ định kênh riêng cho test nếu muốn
                    channelId: 'test_channel',
                    channelName: 'Test Notifications',
                    channelDescription:
                        'Channel for testing notifications manually.',
                  );
                  print("[DashboardScreen] Test notification button pressed.");
                  // Hiển thị SnackBar để xác nhận đã nhấn nút
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Sent test notification! Check system tray.'),
                        duration: Duration(seconds: 2)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20), // Thêm khoảng cách
            // --- Widget Chỉ Số Realtime ---
            const RealtimeMetricsCard(), // <<< SỬ DỤNG WIDGET CON
            const SizedBox(height: 16),

            // --- Placeholder Mục Tiêu (Ví dụ) ---
            Card(
              elevation: 2.0,
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily Goal Progress'), // TODO: Dịch
                // <<< SỬA LẠI SUBTITLE >>>
                subtitle: _isLoadingDashboardGoal
                    ? const Text('Loading goal...') // Hiển thị loading
                    : Consumer<BleProvider>(
                        // Chỉ cần BleProvider
                        builder: (context, bleProvider, child) {
                          final steps =
                              bleProvider.latestHealthData?.steps ?? 0;
                          // Dùng _dashboardStepGoal từ state của màn hình này
                          final goal = _dashboardStepGoal;
                          return Text('Steps: $steps / $goal');
                        },
                      ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  /* Điều hướng tới GoalsScreen qua BottomNavBar */
                },
              ),
            ),

            // --- Widget Biểu Đồ Lịch Sử ---
            const HistoryChartCard(), // <<< SỬ DỤNG WIDGET CON
            const SizedBox(height: 16),

            // --- Widget Biểu Đồ Lịch Sử SpO2 --- // <<< THÊM VÀO ĐÂY
            const Spo2HistoryChartCard(),
            const SizedBox(height: 16),

            // --- Widget Biểu Đồ Lịch Sử Steps --- // <<< THÊM VÀO ĐÂY
            StepsHistoryChartCard(), // <<< KHÔNG DÙNG CONST
            const SizedBox(height: 16),

            // Có thể thêm lại các Card khác nếu muốn (IMU, Other Sensors)
            // Hoặc di chuyển chúng vào widget con riêng
          ],
        ),
      ),
    );
  }
}
