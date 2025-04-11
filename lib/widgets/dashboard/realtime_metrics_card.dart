// lib/widgets/dashboard/realtime_metrics_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart'; // Lấy dữ liệu BLE mới nhất
import '../../services/ble_service.dart'; // Cần enum và model
import '../../models/health_data.dart'; // Cần model HealthData

class RealtimeMetricsCard extends StatelessWidget {
  const RealtimeMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe BleProvider để lấy dữ liệu mới nhất
    final bleProvider = context.watch<BleProvider>();
    final latestData = bleProvider.latestHealthData;
    final connectionStatus = bleProvider.connectionStatus.value;
    final DateFormat formatter = DateFormat('HH:mm:ss - dd/MM');
    final String timestampStr =
        latestData != null
            ? formatter.format(latestData.timestamp.toLocal())
            : '--:--:--';

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Realtime Metrics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 15),
            // Nội dung dựa trên trạng thái kết nối
            _buildContent(context, connectionStatus, latestData, timestampStr),
          ],
        ),
      ),
    );
  }

  // Widget con để xây dựng nội dung dựa trên trạng thái
  Widget _buildContent(
    BuildContext context,
    BleConnectionStatus status,
    HealthData? data,
    String timestamp,
  ) {
    if (status == BleConnectionStatus.connected) {
      if (data != null) {
        // --- Hiển thị dữ liệu khi có kết nối và data ---
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.favorite,
                  label: 'Heart Rate',
                  value: (data.hr >= 0) ? data.hr.toString() : '---',
                  unit: 'bpm',
                  color: Colors.red.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.opacity,
                  label: 'SpO2',
                  value: (data.spo2 >= 0) ? data.spo2.toString() : '---',
                  unit: '%',
                  color: Colors.blue.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.directions_walk,
                  label: 'Steps',
                  value: data.steps.toString(),
                  unit: '',
                  color: Colors.orange.shade400,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                'Last updated: $timestamp',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      } else {
        // --- Có kết nối nhưng chưa có data ---
        return const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Text("Connected. Waiting for first data packet..."),
          ),
        );
      }
    } else if (status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.discovering_services) {
      // --- Đang kết nối ---
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Connecting..."),
            ],
          ),
        ),
      );
    } else {
      // --- Ngắt kết nối hoặc Lỗi ---
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Text(
            status == BleConnectionStatus.error
                ? 'Connection error.'
                : 'Device disconnected.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      );
    }
  }

  // Widget helper hiển thị chỉ số (giữ nguyên từ DashboardScreen cũ)
  Widget _buildMetricDisplay({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    Color? color,
  }) {
    // ... (code hàm này giữ nguyên) ...
    final primaryColor = color ?? Theme.of(context).primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36.0, color: primaryColor),
        const SizedBox(height: 8.0),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: primaryColor),
          ),
        const SizedBox(height: 4.0),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
