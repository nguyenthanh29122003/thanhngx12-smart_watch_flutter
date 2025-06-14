// lib/widgets/dashboard/realtime_metrics_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart'; // <<< Import Lottie cho animation

import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';
import '../../models/health_data.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>

class RealtimeMetricsCard extends StatelessWidget {
  const RealtimeMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe provider để lấy trạng thái và dữ liệu
    final bleProvider = context.watch<BleProvider>();
    final connectionStatus = bleProvider.connectionStatus.value;
    final latestData = bleProvider.latestHealthData;

    // --- Xử lý nội dung dựa trên trạng thái kết nối ---
    // Trường hợp đang kết nối hoặc ngắt kết nối
    if (connectionStatus != BleConnectionStatus.connected) {
      return _StatusCard(status: connectionStatus);
    }

    // Trường hợp đã kết nối nhưng đang chờ dữ liệu
    if (latestData == null) {
      return _StatusCard(status: connectionStatus, isWaiting: true);
    }

    // --- Trường hợp chính: Đã kết nối và có dữ liệu ---
    // Sử dụng GridView để hiển thị các chỉ số
    return GridView.count(
      // Các thuộc tính của GridView
      crossAxisCount: 2, // 2 cột
      mainAxisSpacing: 16, // Khoảng cách dọc
      crossAxisSpacing: 16, // Khoảng cách ngang
      shrinkWrap: true, // Để GridView co lại theo nội dung
      physics:
          const NeverScrollableScrollPhysics(), // Không cho phép GridView cuộn
      childAspectRatio: 1.2, // Tỉ lệ chiều rộng/cao của mỗi item

      // Danh sách các "pod" chỉ số
      children: [
        _MetricPod(
          icon: Icons.favorite_rounded,
          iconColor: Colors.red.shade400,
          label: AppLocalizations.of(context)!.heartRateLabel,
          value: (latestData.hr > 0) ? latestData.hr.toString() : '--',
          unit: 'bpm',
        ),
        _MetricPod(
          icon: Icons.opacity_rounded,
          iconColor: Colors.blue.shade400,
          label: AppLocalizations.of(context)!.spo2Label,
          value: (latestData.spo2 > 0) ? latestData.spo2.toString() : '--',
          unit: '%',
        ),
        // --- Có thể thêm các chỉ số khác ở đây trong tương lai ---
      ],
    );
  }
}

// ================================================================
// WIDGET CON ĐỂ HIỂN THỊ TRẠNG THÁI (KẾT NỐI/NGẮT/LỖI)
// ================================================================
class _StatusCard extends StatelessWidget {
  final BleConnectionStatus status;
  final bool isWaiting; // Cờ để biết là đang chờ dữ liệu hay chưa kết nối

  const _StatusCard({required this.status, this.isWaiting = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    String message;
    Widget animation;
    Color textColor;

    if (isWaiting) {
      message = l10n.waitingForData;
      textColor = theme.colorScheme.primary;
      animation = SizedBox(
          height: 120,
          child: Lottie.asset('assets/animations/data_loading.json'));
    } else if (status == BleConnectionStatus.connecting ||
        status == BleConnectionStatus.discovering_services) {
      message = l10n.connectingStatusDevice;
      textColor = Colors.orange.shade800;
      animation =
          const SizedBox(height: 120, child: CircularProgressIndicator());
    } else {
      message = (status == BleConnectionStatus.error)
          ? l10n.connectionErrorStatus
          : l10n.disconnectedStatus;
      textColor = (status == BleConnectionStatus.error)
          ? theme.colorScheme.error
          : theme.disabledColor;
      animation = Icon(
          (status == BleConnectionStatus.error)
              ? Icons.error_outline_rounded
              : Icons.bluetooth_disabled_rounded,
          size: 80,
          color: textColor.withOpacity(0.5));
    }

    // Card lớn hiển thị trạng thái
    return Card(
      elevation: 2,
      child: Container(
        height: 180, // Chiều cao cố định
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: animation),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style:
                      theme.textTheme.titleMedium?.copyWith(color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// WIDGET CON CHO MỘT "POD" CHỈ SỐ
// ================================================================
class _MetricPod extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  const _MetricPod({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Card(
      elevation: 2.0, // Đổ bóng nhẹ cho mỗi pod
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween, // Căn đều các phần tử
          children: [
            // Icon
            Icon(icon, size: 32, color: iconColor),

            // Giá trị và đơn vị
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sử dụng AnimatedSwitcher để tạo hiệu ứng mờ dần khi giá trị thay đổi
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    value,
                    // Key rất quan trọng để AnimatedSwitcher biết khi nào cần chạy animation
                    key: ValueKey<String>(value),
                    style: textTheme.headlineMedium?.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: textTheme.bodyMedium?.copyWith(
                    color: iconColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),

            // Nhãn chỉ số
            Text(label, style: textTheme.bodyMedium)
          ],
        ),
      ),
    );
  }
}
