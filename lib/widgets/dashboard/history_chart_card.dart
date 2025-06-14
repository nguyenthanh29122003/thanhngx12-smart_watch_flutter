// lib/widgets/dashboard/history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/health_data.dart';
import '../../generated/app_localizations.dart';

// <<< THAY ĐỔI LỚN: WIDGET NÀY BÂY GIỜ KHÔNG CÒN LÀ MỘT 'CARD' NỮA >>>
// Nó chỉ là một widget nội dung biểu đồ.
class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Consumer vẫn là cách tốt nhất để lấy dữ liệu
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // --- XỬ LÝ TRẠNG THÁI (LOADING, ERROR, EMPTY) ---
        // Phần này tương tự như trước, nhưng UI được thiết kế lại một chút
        switch (provider.historyStatus) {
          case HistoryStatus.loading:
          case HistoryStatus.initial:
            return const Center(child: CircularProgressIndicator());

          case HistoryStatus.error:
            return _buildErrorState(context, l10n.chartErrorPrefix,
                provider.historyError ?? l10n.chartCouldNotLoad);

          case HistoryStatus.loaded:
            // Lọc dữ liệu hợp lệ cho nhịp tim
            final validData =
                provider.healthHistory.where((d) => d.hr > 0).toList();
            if (validData.length < 2) {
              return _buildErrorState(
                  context, l10n.chartInfo, l10n.chartNotEnoughData); // Key mới
            } else {
              // Nếu có đủ dữ liệu, xây dựng biểu đồ
              return _buildLineChart(context, validData);
            }
        }
      },
    );
  }

  // --- WIDGET HELPER MỚI CHO TRẠNG THÁI LỖI / THÔNG TIN ---
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
  Widget _buildLineChart(BuildContext context, List<HealthData> validData) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final chartColor = Colors.red.shade400; // Màu đặc trưng cho nhịp tim

    // --- 1. Chuẩn bị dữ liệu ---
    final List<FlSpot> spots = validData
        .map((data) => FlSpot(
              data.timestamp.millisecondsSinceEpoch.toDouble(),
              data.hr.toDouble(),
            ))
        .toList();

    final double minX = spots.first.x;
    final double maxX = spots.last.x;

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (var spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
    }

    // Thêm khoảng đệm cho trục Y để đẹp hơn
    minY = (minY / 10).floor() * 10 - 10; // Làm tròn xuống và trừ đi 10
    maxY = (maxY / 10).ceil() * 10 + 10; // Làm tròn lên và cộng thêm 10
    minY = minY.clamp(30, double.infinity); // Đảm bảo minY không quá thấp

    // --- 2. Cấu hình LineChartData ---
    return LineChart(
      LineChartData(
        // --- CẤU HÌNH ĐƯỜNG KẺ & VÙNG NỀN ---
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              // Dùng Gradient cho đẹp
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
        lineTouchData: _buildLineTouchData(context, l10n, "bpm"),

        // --- CẤU HÌNH CÁC TRỤC ---
        titlesData: _buildTitlesData(context, minY, maxY, minX, maxX),

        // --- CẤU HÌNH LƯỚI ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false, // Bỏ lưới dọc cho gọn gàng
          horizontalInterval: 20, // Khoảng cách lưới ngang
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),

        // --- CẤU HÌNH VIỀN ---
        // Bỏ viền để tích hợp mượt mà vào Card chứa nó
        borderData: FlBorderData(show: false),

        // --- GIỚI HẠN TRỤC ---
        minX: minX,
        maxX: maxX,
        minY: minY.floorToDouble(), // Làm tròn cho đẹp
        maxY: maxY.ceilToDouble(),
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
          reservedSize: 35, // Khoảng trống cho nhãn
          interval: 20, // Hiển thị mỗi 20 bpm
          getTitlesWidget: (value, meta) {
            // Chỉ hiển thị nhãn nếu nó không phải giá trị min/max để tránh chồng chéo
            if (value == meta.max || value == meta.min) {
              return Container();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(value.toInt().toString(), style: textStyle),
            );
          },
        ),
      ),

      // --- TRỤC DƯỚI (X) ---
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22, // Giảm khoảng trống
          interval: _calculateBottomTitleInterval(
              minX, maxX), // Tái sử dụng hàm tính interval
          getTitlesWidget: (value, meta) {
            final dt =
                DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
                    .toLocal();
            // Chỉ hiển thị tại các điểm đầu, giữa, và cuối
            if (value == meta.min || value == meta.max) {
              return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child:
                      Text(DateFormat('HH:mm').format(dt), style: textStyle));
            }
            // Logic để hiển thị điểm ở giữa nếu có
            if ((maxX - minX) > 1000 * 60 * 60 * 2) {
              // Nếu khoảng thời gian đủ lớn
              if ((value - meta.min) / (meta.max - meta.min) > 0.45 &&
                  (value - meta.min) / (meta.max - meta.min) < 0.55) {
                return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child:
                        Text(DateFormat('HH:mm').format(dt), style: textStyle));
              }
            }
            return Container();
          },
        ),
      ),

      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // --- HELPER CHO TOOLTIP ---
  LineTouchData _buildLineTouchData(
      BuildContext context, AppLocalizations l10n, String unit) {
    return LineTouchData(
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        // KHÔNG TÙY CHỈNH MÀU NỀN Ở ĐÂY NỮA
        tooltipRoundedRadius: 8,
        getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
          // Logic bên trong này không thay đổi
          return touchedBarSpots.map((barSpot) {
            final dt = DateTime.fromMillisecondsSinceEpoch(barSpot.x.toInt(),
                    isUtc: true)
                .toLocal();
            final timeStr = DateFormat('HH:mm').format(dt);
            final valueStr = barSpot.y.toInt().toString();

            return LineTooltipItem(
              '$valueStr $unit\n', // Dòng 1
              TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface, // <<< Dùng màu chữ của theme
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: timeStr,
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
            FlLine(color: Theme.of(context).primaryColor, strokeWidth: 1.5),
            FlDotData(
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 6,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: Theme.of(context).primaryColor,
                );
              },
            ),
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
