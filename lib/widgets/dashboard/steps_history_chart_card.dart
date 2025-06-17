// lib/widgets/dashboard/steps_history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>

class StepsHistoryChartCard extends StatelessWidget {
  StepsHistoryChartCard({super.key});

  final DateFormat _hourFormat = DateFormat('H'); // Chỉ hiển thị giờ (0-23)

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // Toàn bộ logic switch-case và các widget _buildErrorState
        // được tái sử dụng từ các biểu đồ trước, không cần thay đổi.
        switch (provider.historyStatus) {
          case HistoryStatus.loading:
          case HistoryStatus.initial:
            return const Center(child: CircularProgressIndicator());

          case HistoryStatus.error:
            return _buildErrorState(
                context,
                AppLocalizations.of(context)!.chartErrorPrefix,
                provider.historyError ??
                    AppLocalizations.of(context)!.chartCouldNotLoad);

          case HistoryStatus.loaded:
            final hourlySteps = provider.hourlyStepsData;
            if (hourlySteps.isEmpty) {
              return _buildErrorState(
                  context,
                  AppLocalizations.of(context)!.chartInfo,
                  AppLocalizations.of(context)!.chartNoStepsCalculated);
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

  // --- HÀM XÂY DỰNG BIỂU ĐỒ (ĐÃ TINH CHỈNH) ---
  Widget _buildStepsBarChart(
      BuildContext context, List<HourlyStepsData> hourlySteps) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // Lấy màu từ AppTheme để nhất quán
    final chartColor = Colors.orange.shade400;

    // --- 1. Chuẩn bị dữ liệu ---
    int maxHourlySteps = 0;
    if (hourlySteps.isNotEmpty) {
      maxHourlySteps =
          hourlySteps.map((d) => d.steps).reduce((a, b) => a > b ? a : b);
    }
    // Logic làm tròn trục Y lên một giá trị "đẹp"
    double maxY = (maxHourlySteps == 0)
        ? 100
        : (maxHourlySteps * 1.2 / 100).ceil() * 100.0;

    // Tính toán interval cho lưới ngang
    final double horizontalInterval =
        (maxY > 0) ? (maxY / 4).ceilToDouble() : 25;

    // --- 2. Cấu hình BarChart ---
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,

        // --- CẤU HÌNH TOOLTIP KHI CHẠM (ĐÃ SỬA LỖI) ---
        barTouchData: _buildBarTouchData(context, l10n),

        // --- CẤU HÌNH CÁC TRỤC ---
        titlesData: _buildTitlesData(context, maxY, horizontalInterval),

        // --- CẤU HÌNH LƯỚI ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: horizontalInterval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.dividerColor.withOpacity(0.1),
            strokeWidth: 1,
          ),
        ),

        // --- CẤU HÌNH VIỀN ---
        borderData: FlBorderData(show: false),

        // --- DỮ LIỆU CÁC CỘT ---
        barGroups: List.generate(24, (index) {
          // Luôn tạo 24 cột cho 24 giờ
          final hourlyData = hourlySteps.firstWhere(
              (data) => data.hourStart.hour == index,
              orElse: () =>
                  HourlyStepsData(DateTime.now().copyWith(hour: index), 0));

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: hourlyData.steps.toDouble(),
                gradient: LinearGradient(
                  colors: [chartColor.withOpacity(0.8), chartColor],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 8, // Giảm độ rộng cột cho gọn
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
    );
  }

  // --- HÀM HELPER CẤU HÌNH CÁC TRỤC ---
  FlTitlesData _buildTitlesData(
      BuildContext context, double maxY, double intervalY) {
    final textStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10);

    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: intervalY,
          getTitlesWidget: (value, meta) {
            // Không hiển thị giá trị min và max để tránh chồng chéo
            if (value == 0 || value == meta.max) return const SizedBox();
            // Định dạng số lớn (ví dụ: 1500 -> 1.5k)
            String formattedValue;
            if (value >= 1000) {
              formattedValue = '${(value / 1000).toStringAsFixed(1)}k';
            } else {
              formattedValue = value.toInt().toString();
            }
            return SideTitleWidget(
              axisSide: meta.axisSide,
              space: 4,
              child: Text(formattedValue, style: textStyle),
            );
          },
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 4, // Hiển thị nhãn mỗi 4 giờ
          getTitlesWidget: (value, meta) {
            String text = '';
            if (value.toInt() % 4 == 0) {
              // Chỉ hiển thị tại các mốc 0, 4, 8, 12, 16, 20
              text = _hourFormat
                  .format(DateTime.now().copyWith(hour: value.toInt()));
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

  // --- HELPER CHO TOOLTIP (Sử dụng cú pháp an toàn) ---
  BarTouchData _buildBarTouchData(BuildContext context, AppLocalizations l10n) {
    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        // tooltipBgColor: Theme.of(context).colorScheme.primary.withOpacity(0.9),
        tooltipRoundedRadius: 8,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final hour = group.x.toInt();
          final steps = rod.toY.toInt();
          final timeRange = '$hour:00 - $hour:59';

          return BarTooltipItem(
            '${NumberFormat.decimalPattern().format(steps)} ${l10n.stepsUnit}\n',
            const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            children: <TextSpan>[
              TextSpan(
                text: timeRange,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ],
          );
        },
      ),
    );
  }
}
