// lib/widgets/dashboard/realtime_metrics_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart'; // Lấy dữ liệu BLE mới nhất
import '../../services/ble_service.dart'; // Cần enum và model
import '../../models/health_data.dart'; // Cần model HealthData
import '../../generated/app_localizations.dart';

class RealtimeMetricsCard extends StatelessWidget {
  const RealtimeMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe BleProvider để lấy dữ liệu mới nhất
    final bleProvider = context.watch<BleProvider>();
    final latestData = bleProvider.latestHealthData;
    final connectionStatus = bleProvider.connectionStatus.value;
    final DateFormat formatter = DateFormat('HH:mm:ss - dd/MM');
    final bool isWifiConnected = latestData?.wifi ?? false;
    final String timestampStr = latestData != null
        ? formatter.format(latestData.timestamp.toLocal())
        : '--:--:--';
    // Chỉ hiển thị trạng thái WiFi nếu thiết bị đang kết nối
    final bool showWifiStatus =
        connectionStatus == BleConnectionStatus.connected;
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // <<< SỬ DỤNG ROW CHO TIÊU ĐỀ VÀ TRẠNG THÁI WIFI >>>
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Đẩy 2 phần tử ra 2 đầu
              crossAxisAlignment: CrossAxisAlignment.start, // Canh lề trên
              children: [
                // Tiêu đề Card
                Text(
                  l10n.realtimeMetricsTitle, // <<< DÙNG KEY
                  style: Theme.of(context).textTheme.titleLarge,
                ),

                // Trạng thái WiFi (chỉ hiển thị khi kết nối)
                if (showWifiStatus) // <<< CHỈ HIỂN THỊ KHI KẾT NỐI BLE >>>
                  Row(
                    // Dùng Row nhỏ để nhóm icon và text WiFi
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isWifiConnected ? Icons.wifi : Icons.wifi_off,
                        size: 18, // Kích thước icon nhỏ hơn chút
                        color: isWifiConnected
                            ? Colors.teal
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isWifiConnected
                            ? l10n.wifiStatusOn
                            : l10n.wifiStatusOff,
                        // TODO: Dịch
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isWifiConnected
                                  ? Colors.teal
                                  : Colors.grey.shade600,
                              // fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  )
                else
                  const SizedBox
                      .shrink(), // Hoặc không hiển thị gì nếu không kết nối
              ],
            ),
            // ------------------------------------------------

            const SizedBox(height: 15), // Khoảng cách giữa tiêu đề và nội dung
            // Nội dung dựa trên trạng thái kết nối (Hàm _buildContent không cần thay đổi)
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
    final l10n = AppLocalizations.of(context)!;
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
                  label: l10n.heartRateLabel,
                  value: (data.hr >= 0) ? data.hr.toString() : '---',
                  unit: 'bpm',
                  color: Colors.red.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.opacity,
                  label: l10n.spo2Label,
                  value: (data.spo2 >= 0) ? data.spo2.toString() : '---',
                  unit: '%',
                  color: Colors.blue.shade400,
                ),
                _buildMetricDisplay(
                  context: context,
                  icon: Icons.directions_walk,
                  label: l10n.stepsLabel,
                  value: data.steps.toString(),
                  unit: '',
                  color: Colors.orange.shade400,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Center(
              child: Text(
                "${l10n.lastUpdatedPrefix} $timestamp", // <<< DÙNG KEY
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
      } else {
        // --- Có kết nối nhưng chưa có data ---
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Text(l10n.waitingForData), // <<< DÙNG KEY
          ),
        );
      }
    } else if (status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.discovering_services) {
      // --- Đang kết nối ---
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              Text(l10n.connectingStatus),
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
                ? l10n.connectionErrorStatus
                : l10n.disconnectedStatus,
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
