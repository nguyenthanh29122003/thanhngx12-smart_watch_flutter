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

class DashboardScreen extends StatefulWidget {
  // <<< CHUYỂN THÀNH STATEFUL
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // <<< TẠO STATE

  @override
  void initState() {
    super.initState();
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
    final bleStatus =
        Provider.of<BleProvider>(context, listen: false).connectionStatus.value;
    if (bleStatus == BleConnectionStatus.connected) {
      print("[DashboardScreen] Reconnected to BLE, refreshing history...");
      // Gọi fetch lại sau một khoảng delay nhỏ
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          // Kiểm tra mounted trước khi truy cập provider
          Provider.of<DashboardProvider>(
            context,
            listen: false,
          ).fetchHealthHistory();
        }
      });
    }
  }

  // Hàm helper để lấy text và màu cho trạng thái BLE (giữ nguyên)
  Widget _buildBleStatusChip(BleConnectionStatus status) {
    // ... (code hàm này giữ nguyên) ...
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

            // --- Widget Chỉ Số Realtime ---
            const RealtimeMetricsCard(), // <<< SỬ DỤNG WIDGET CON
            const SizedBox(height: 16),

            // --- Placeholder Mục Tiêu (Ví dụ) ---
            Card(
              elevation: 2.0,
              child: ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Daily Goal Progress'),
                subtitle: Consumer<BleProvider>(
                  // Lấy steps realtime
                  builder: (context, bleProvider, child) {
                    final steps = bleProvider.latestHealthData?.steps ?? 0;
                    final goal =
                        10000; // TODO: Lấy mục tiêu từ Settings/Provider
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
