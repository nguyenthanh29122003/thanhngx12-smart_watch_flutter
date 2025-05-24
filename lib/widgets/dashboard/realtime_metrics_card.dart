// lib/widgets/dashboard/realtime_metrics_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart'; // Lấy dữ liệu BLE mới nhất và Notifier
import '../../services/ble_service.dart'; // Cần enum BleConnectionStatus
import '../../models/health_data.dart'; // Cần model HealthData
import '../../generated/app_localizations.dart'; // Import l10n

class RealtimeMetricsCard extends StatelessWidget {
  const RealtimeMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Sử dụng watch để lắng nghe cả BleProvider (cho status và data)
    final bleProvider = context.watch<BleProvider>();
    final connectionStatus = bleProvider.connectionStatus.value;
    final latestData =
        bleProvider.latestHealthData; // Dùng để lấy timestamp và các giá trị
    final DateFormat formatter = DateFormat('HH:mm:ss - dd/MM');
    final String timestampStr = latestData != null
        ? formatter.format(latestData.timestamp.toLocal())
        : '--:--:--';
    // Chỉ hiển thị trạng thái WiFi nếu thiết bị đang kết nối BLE
    final bool showWifiStatus =
        connectionStatus == BleConnectionStatus.connected;
    final l10n = AppLocalizations.of(context)!; // Lấy đối tượng dịch

    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0)), // Thêm bo góc
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Hàng Tiêu đề và Trạng thái WiFi ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tiêu đề Card
                Text(
                  l10n.realtimeMetricsTitle, // Đã dịch
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600), // Đậm hơn chút
                ),

                // Trạng thái WiFi (Lắng nghe Notifier từ Provider)
                if (showWifiStatus)
                  ValueListenableBuilder<bool?>(
                    valueListenable: bleProvider
                        .deviceWifiStatusNotifier, // Lắng nghe notifier
                    builder: (context, isWifiOn, child) {
                      bool connected = isWifiOn ??
                          false; // Mặc định false nếu null (chưa nhận status)
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Tooltip(
                            // Thêm Tooltip giải thích
                            message: connected
                                ? "Device WiFi Connected"
                                : "Device WiFi Disconnected", // TODO: Dịch tooltip
                            child: Icon(
                              connected ? Icons.wifi : Icons.wifi_off,
                              size: 18,
                              color: connected
                                  ? Colors.teal
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            connected
                                ? l10n.wifiStatusOn
                                : l10n.wifiStatusOff, // Đã dịch
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: connected
                                        ? Colors.teal
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500 // Đậm hơn chút
                                    ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  const SizedBox
                      .shrink(), // Không hiển thị gì nếu không kết nối BLE
              ],
            ),
            const SizedBox(height: 20), // Tăng khoảng cách

            // --- Nội dung chính dựa trên trạng thái kết nối ---
            _buildContent(
                context, connectionStatus, latestData, timestampStr, l10n),
          ],
        ),
      ),
    );
  }

  // --- Widget xây dựng nội dung chính (Hiển thị Metrics hoặc Trạng thái) ---
  Widget _buildContent(
    BuildContext context,
    BleConnectionStatus status,
    HealthData? data, // Dữ liệu HealthData mới nhất (có thể null)
    String timestamp, // Timestamp đã định dạng
    AppLocalizations l10n, // Đối tượng dịch
  ) {
    if (status == BleConnectionStatus.connected) {
      if (data != null) {
        // --- Đã Kết nối và Có Dữ liệu ---
        // Định dạng nhiệt độ (1 chữ số thập phân)
        final String temperatureStr = data.temperature != null
            ? data.temperature!.toStringAsFixed(1)
            : '---';

        return Column(
          children: [
            // <<< SỬ DỤNG WRAP ĐỂ TỰ ĐỘNG XUỐNG DÒNG NẾU KHÔNG ĐỦ CHỖ >>>
            Wrap(
              alignment:
                  WrapAlignment.spaceBetween, // Căn đều khoảng cách ngang
              crossAxisAlignment: WrapCrossAlignment.start,
              runSpacing: 24.0, // Khoảng cách dọc giữa các hàng
              spacing: 16.0, // Khoảng cách ngang tối thiểu giữa các item
              children: [
                _buildMetricDisplay(
                    context: context,
                    icon: Icons.favorite,
                    label: l10n.heartRateLabel,
                    value: (data.hr >= 0) ? data.hr.toString() : '---',
                    unit: 'bpm',
                    color: Colors.red.shade400),
                _buildMetricDisplay(
                    context: context,
                    icon: Icons.opacity,
                    label: l10n.spo2Label,
                    value: (data.spo2 >= 0) ? data.spo2.toString() : '---',
                    unit: '%',
                    color: Colors.blue.shade400),
                _buildMetricDisplay(
                    context: context,
                    icon: Icons.directions_walk,
                    label: l10n.stepsLabel,
                    value: data.steps.toString(),
                    unit: l10n.stepsUnit,
                    color: Colors.orange.shade400), // Thêm đơn vị steps
                _buildMetricDisplay(
                    context: context,
                    icon: Icons.thermostat,
                    label: l10n.temperatureLabel,
                    value: temperatureStr,
                    unit: l10n.tempUnit,
                    color: Colors.amber.shade700)
              ],
            ),
            // ---------------------------------------------------------
            const SizedBox(height: 20), // Tăng khoảng cách
            Center(
              // Timestamp
              child: Text(
                "${l10n.lastUpdatedPrefix} $timestamp", // Đã dịch
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600]), // Màu nhạt hơn
              ),
            ),
          ],
        );
      } else {
        // --- Đã kết nối nhưng chưa có dữ liệu ---
        return Center(
          child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 30.0), // Tăng padding
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).primaryColor)),
                  const SizedBox(height: 12),
                  Text(l10n.waitingForData,
                      style: TextStyle(color: Colors.grey[700])), // Đã dịch
                ],
              )),
        );
      }
    } else if (status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.discovering_services) {
      // --- Đang kết nối ---
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.connectingStatusDevice,
                  style: TextStyle(color: Colors.orange.shade800)), // Đã dịch
            ],
          ),
        ),
      );
    } else {
      // --- Ngắt kết nối hoặc Lỗi ---
      String message = status == BleConnectionStatus.error
          ? l10n.connectionErrorStatus // Đã dịch
          : l10n.disconnectedStatus; // Đã dịch
      IconData icon = status == BleConnectionStatus.error
          ? Icons.error_outline
          : Icons.bluetooth_disabled;
      Color color = status == BleConnectionStatus.error
          ? Theme.of(context).colorScheme.error
          : Colors.grey.shade600;

      return Center(
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color)),
              ],
            )),
      );
    }
  }

  // --- Widget helper để hiển thị từng chỉ số ---
  Widget _buildMetricDisplay({
    required BuildContext context,
    required IconData icon,
    required String label, // Label đã được dịch
    required String value,
    required String unit, // Đơn vị đã được dịch (nếu có)
    Color? color,
  }) {
    final primaryColor = color ?? Theme.of(context).primaryColor;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min, // Quan trọng khi dùng Wrap
      crossAxisAlignment:
          CrossAxisAlignment.center, // Căn giữa theo chiều ngang
      children: [
        Icon(icon,
            size: 32.0, color: primaryColor), // Kích thước icon nhỏ hơn chút
        const SizedBox(height: 6.0),
        Row(
          // Nhóm giá trị và đơn vị
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.baseline, // Căn baseline cho đẹp
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: textTheme.headlineSmall?.copyWith(
                // Dùng headlineSmall
                fontWeight: FontWeight.w600, // Bớt đậm hơn
                color: primaryColor,
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 2.0), // Khoảng cách nhỏ
                child: Text(
                  unit,
                  style: textTheme.bodySmall?.copyWith(
                      color:
                          primaryColor.withOpacity(0.8)), // Đơn vị mờ hơn chút
                ),
              ),
          ],
        ),
        const SizedBox(height: 2.0), // Giảm khoảng cách
        Text(label,
            style: textTheme.bodyMedium
                ?.copyWith(color: Colors.grey[700])), // Label màu xám hơn
      ],
    );
  }
}
