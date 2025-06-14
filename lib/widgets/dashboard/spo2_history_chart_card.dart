// lib/widgets/dashboard/spo2_history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/health_data.dart';
import '../../generated/app_localizations.dart';

class Spo2HistoryChartCard extends StatelessWidget {
  const Spo2HistoryChartCard({super.key});

  // Ngưỡng SpO2 tối thiểu hợp lệ để hiển thị trên biểu đồ
  static const int minValidSpo2 = 85;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        switch (provider.historyStatus) {
          case HistoryStatus.loading:
          case HistoryStatus.initial:
            return const Center(child: CircularProgressIndicator());

          case HistoryStatus.error:
            return _buildErrorState(context, l10n.chartErrorPrefix,
                provider.historyError ?? l10n.chartCouldNotLoad);

          case HistoryStatus.loaded:
            // Lọc dữ liệu hợp lệ cho SpO2
            final validData = provider.healthHistory
                .where((d) => d.spo2 >= minValidSpo2)
                .toList();
            if (validData.length < 2) {
              return _buildErrorState(
                  context, l10n.chartInfo, l10n.chartNoValidSpo2(minValidSpo2));
            } else {
              return _buildSpo2LineChart(context, validData);
            }
        }
      },
    );
  }

  // --- WIDGET HELPER CHO TRẠNG THÁI LỖI / THÔNG TIN ---
  Widget _buildErrorState(BuildContext context, String title, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline,
              color: theme.textTheme.bodySmall?.color, size: 32),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message,
              style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // --- HÀM XÂY DỰNG BIỂU ĐỒ (ĐƯỢC THIẾT KẾ LẠI) ---
  Widget _buildSpo2LineChart(BuildContext context, List<HealthData> validData) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Màu đặc trưng cho SpO2, lấy từ theme
    final chartColor = theme.colorScheme.secondary; // Hoặc một màu xanh cố định

    // --- 1. Chuẩn bị dữ liệu ---
    final List<FlSpot> spots = validData
        .map((data) => FlSpot(
              data.timestamp.millisecondsSinceEpoch.toDouble(),
              data.spo2.toDouble(),
            ))
        .toList();

    final double minX = spots.first.x;
    final double maxX = spots.last.x;

    // Trục Y của SpO2 có thang đo khá cố định, nên đặt cứng để dễ so sánh
    const double minY = 84;
    const double maxY = 101;

    // --- 2. Cấu hình LineChartData ---
    return LineChart(
      LineChartData(
        // --- CẤU HÌNH ĐƯỜNG KẺ & VÙNG NỀN ---
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [chartColor.withOpacity(0.8), chartColor],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  chartColor.withOpacity(0.3),
                  chartColor.withOpacity(0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],

        // --- CẤU HÌNH TOOLTIP KHI CHẠM ---
        lineTouchData: _buildLineTouchData(context, l10n),

        // --- CẤU HÌNH CÁC TRỤC ---
        titlesData: _buildTitlesData(context, minY, maxY, minX, maxX),

        // --- CẤU HÌNH LƯỚI ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 5, // Mỗi 5%
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),

        // --- CẤU HÌNH VIỀN ---
        borderData: FlBorderData(show: false),

        // --- GIỚI HẠN TRỤC ---
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
      ),
    );
  }

  // --- TÁCH CÁC HÀM HELPER CẤU HÌNH BIỂU ĐỒ ---

  FlTitlesData _buildTitlesData(BuildContext context, double minY, double maxY,
      double minX, double maxX) {
    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10);

    return FlTitlesData(
      // --- TRỤC TRÁI (Y) ---
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 5, // Hiển thị mỗi 5%
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) return Container();
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text('${value.toInt()}%', style: textStyle),
            );
          },
        ),
      ),

      // --- TRỤC DƯỚI (X) ---
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: _calculateBottomTitleInterval(minX, maxX),
          getTitlesWidget: (value, meta) {
            // Logic tương tự biểu đồ HR để hiển thị các mốc thời gian quan trọng
            if (value == meta.min || value == meta.max) {
              final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt(),
                      isUtc: true)
                  .toLocal();
              return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child:
                      Text(DateFormat('HH:mm').format(dt), style: textStyle));
            }
            return Container();
          },
        ),
      ),

      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // --- HELPER CHO TOOLTIP (Tương thích với phiên bản fl_chart của bạn) ---
  LineTouchData _buildLineTouchData(
      BuildContext context, AppLocalizations l10n) {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        // Đã xóa dòng "tooltipBgColor"
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          return touchedBarSpots.map((barSpot) {
            final dt = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt(),
                    isUtc: true)
                .toLocal();
            final timeStr = DateFormat('HH:mm').format(dt);
            final valueStr = '${barSpot.y.toInt()}%';

            return LineTooltipItem(
              valueStr, // Dòng 1: Giá trị + Đơn vị
              TextStyle(
                // <<< THAY ĐỔI MÀU CHỮ CHO DỄ ĐỌC TRÊN NỀN MẶC ĐỊNH
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: '  $timeStr',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.8),
                      fontWeight: FontWeight.normal),
                ),
              ],
            );
          }).toList();
        },
      ),
      getTouchedSpotIndicator: (barData, spotIndexes) {
        return spotIndexes.map((spotIndex) {
          return TouchedSpotIndicatorData(
            FlLine(
                color: Theme.of(context).colorScheme.secondary,
                strokeWidth: 1.5), // <<< SỬ DỤNG MÀU SECONDARY
            FlDotData(getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 6,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: Theme.of(context)
                    .colorScheme
                    .secondary, // <<< SỬ DỤNG MÀU SECONDARY
              );
            }),
          );
        }).toList();
      },
    );
  }

  // --- HÀM HELPER TÍNH INTERVAL TRỤC X (Giữ nguyên) ---
  double _calculateBottomTitleInterval(double minX, double maxX) {
    final double durationMillis = maxX - minX;
    if (durationMillis <= 0) return 1000 * 60 * 60; // 1 hour
    final double durationHours = durationMillis / (1000 * 60 * 60);

    if (durationHours <= 6) return 1000 * 60 * 60; // Mỗi giờ
    if (durationHours <= 12) return 1000 * 60 * 60 * 2; // Mỗi 2 giờ
    if (durationHours <= 24) return 1000 * 60 * 60 * 4; // Mỗi 4 giờ
    return 1000 * 60 * 60 * 6; // Mỗi 6 giờ
  }
}
