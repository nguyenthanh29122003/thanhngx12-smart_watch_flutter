// lib/widgets/dashboard/steps_history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';

class StepsHistoryChartCard extends StatelessWidget {
  StepsHistoryChartCard({super.key});

  final DateFormat _hourFormat = DateFormat('H'); // Chỉ hiển thị giờ (0-23)

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
            final hourlySteps = provider.hourlyStepsData;
            if (hourlySteps.isEmpty) {
              return _buildErrorState(
                  context, l10n.chartInfo, l10n.chartNoStepsCalculated);
            } else {
              return _buildStepsBarChart(context, hourlySteps);
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
  Widget _buildStepsBarChart(
      BuildContext context, List<HourlyStepsData> hourlySteps) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final chartColor = Colors.orange.shade600;

    // --- 1. Chuẩn bị dữ liệu ---
    // Tìm số bước cao nhất để xác định trục Y
    int maxHourlySteps = 0;
    if (hourlySteps.isNotEmpty) {
      maxHourlySteps =
          hourlySteps.map((d) => d.steps).reduce((a, b) => a > b ? a : b);
    }
    // Làm tròn trục Y lên một giá trị "đẹp"
    double maxY =
        (maxHourlySteps == 0) ? 100 : (maxHourlySteps * 1.2 / 50).ceil() * 50.0;

    // --- 2. Cấu hình BarChart ---
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround, // Căn đều các cột

        // --- CẤU HÌNH TOOLTIP KHI CHẠM ---
        barTouchData: _buildBarTouchData(context, l10n),

        // --- CẤU HÌNH CÁC TRỤC ---
        titlesData: _buildTitlesData(context),

        // --- CẤU HÌNH LƯỚI ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval:
              (maxY / 4).floorToDouble(), // Lưới ngang chia làm 4 khoảng
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),

        // --- CẤU HÌNH VIỀN ---
        borderData: FlBorderData(show: false),

        // --- DỮ LIỆU CÁC CỘT ---
        barGroups: hourlySteps.map((data) {
          return BarChartGroupData(
            x: data.hourStart.hour,
            barRods: [
              BarChartRodData(
                toY: data.steps.toDouble(),
                // Dùng gradient cho các cột
                gradient: LinearGradient(
                  colors: [
                    chartColor.withOpacity(0.8),
                    chartColor,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 12, // Độ rộng cột nhỏ hơn một chút
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // --- TÁCH CÁC HÀM HELPER CẤU HÌNH BIỂU ĐỒ ---

  FlTitlesData _buildTitlesData(BuildContext context) {
    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10);

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false), // Ẩn trục Y cho gọn
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 6, // Hiển thị nhãn mỗi 6 giờ
          getTitlesWidget: (value, meta) {
            final hour = value.toInt();
            String text = '';
            // Chỉ hiển thị tại các mốc chính
            if (hour == 0 || hour == 6 || hour == 12 || hour == 18) {
              text = _hourFormat.format(DateTime.now().copyWith(hour: hour));
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(text, style: textStyle),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // --- HELPER CHO TOOLTIP ---
  BarTouchData _buildBarTouchData(BuildContext context, AppLocalizations l10n) {
    return BarTouchData(
      // Cho phép tooltip hiển thị ngay cả khi chạm vào khoảng trống gần cột
      touchExtraThreshold: const EdgeInsets.symmetric(horizontal: 8),
      touchTooltipData: BarTouchTooltipData(
        // tooltipBgColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          // Lấy giờ và số bước từ dữ liệu
          final hour = group.x.toInt();
          final steps = rod.toY.toInt();
          // Định dạng giờ: 00:00 - 00:59
          final timeRange = '$hour:00 - $hour:59';

          return BarTooltipItem(
            '$steps ${l10n.stepsUnit}\n',
            const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            children: <TextSpan>[
              TextSpan(
                text: timeRange,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
