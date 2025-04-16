// lib/widgets/dashboard/steps_history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

// Import HourlyStepsData và DashboardProvider
import '../../providers/dashboard_provider.dart';

class StepsHistoryChartCard extends StatelessWidget {
  // Bỏ const vì widget này phụ thuộc vào dữ liệu runtime
  StepsHistoryChartCard({super.key});

  // Định dạng giờ cho tooltip và trục X
  final DateFormat _hourFormat = DateFormat('Ha'); // Ví dụ: 9AM, 10PM

  @override
  Widget build(BuildContext context) {
    // Lắng nghe DashboardProvider
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        Widget chartContent;

        // Xử lý trạng thái tải (tương tự các chart khác)
        switch (provider.historyStatus) {
          case HistoryStatus.initial:
          case HistoryStatus.loading:
            chartContent = (provider.historyStatus == HistoryStatus.loading)
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox(height: 200); // Placeholder giữ chiều cao
            break;
          case HistoryStatus.error:
            chartContent = Center(
              child: Text(
                'Error: ${provider.historyError ?? "Could not load history"}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            );
            break;
          case HistoryStatus.loaded:
            // Lấy dữ liệu steps đã xử lý từ provider
            final List<HourlyStepsData> hourlySteps = provider.hourlyStepsData;

            // Kiểm tra nếu không có dữ liệu steps (ngay cả khi history gốc có)
            if (hourlySteps.isEmpty) {
              chartContent = const Center(
                  child:
                      Text('No step data calculated for the selected period.'));
            } else {
              // Tạo biểu đồ cột nếu có dữ liệu
              chartContent = _buildStepsBarChart(context, hourlySteps);
            }
            break;
        }

        // Trả về Card chứa biểu đồ
        return Card(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                16.0, 16.0, 16.0, 8.0), // Giảm padding bottom
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hourly Steps (Last 24h)', // Tiêu đề
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                // Container chứa biểu đồ
                SizedBox(
                  height: 200, // Chiều cao cố định
                  child: chartContent,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Hàm xây dựng BarChart cho Steps ---
  Widget _buildStepsBarChart(
      BuildContext context, List<HourlyStepsData> hourlySteps) {
    int maxHourlySteps = 0;
    for (var data in hourlySteps) {
      if (data.steps > maxHourlySteps) maxHourlySteps = data.steps;
    }
    double maxY = (maxHourlySteps / 50).ceil() * 50.0;
    if (maxHourlySteps > 0 && maxY == 0) maxY = 50;
    if (maxHourlySteps == 0) maxY = 50;
    if (maxY < 100 && maxHourlySteps > 20)
      maxY = (maxHourlySteps / 20).ceil() * 20.0;

    // --- TÍNH TOÁN INTERVAL CHO TRỤC Y TRƯỚC ---
    final double yInterval = (maxY / 4) >= 10 ? (maxY / 4).floorToDouble() : 10;
    // Đảm bảo interval không bao giờ là 0 nếu maxY > 0
    final double safeYInterval = (yInterval == 0 && maxY > 0) ? 10 : yInterval;
    // -------------------------------------------

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < hourlySteps.length; i++) {
      final data = hourlySteps[i];
      barGroups.add(BarChartGroupData(
        x: data.hourStart.hour,
        barRods: [
          BarChartRodData(
            toY: data.steps.toDouble().clamp(0, maxY),
            color: Colors.orange,
            width: 14,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4), topRight: Radius.circular(4)),
          ),
        ],
      ));
    }

    // Cấu hình BarChart
    return BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        barGroups: barGroups,
        alignment: BarChartAlignment.spaceBetween,

        titlesData: FlTitlesData(
          // --- Trục Trái (Y - Số bước) ---
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              // --- SỬ DỤNG BIẾN INTERVAL ĐÃ TÍNH ---
              interval: safeYInterval,
              // ------------------------------------
              getTitlesWidget: (value, meta) {
                // Chỉ hiển thị giá trị nguyên, là bội số của interval (hoặc là max) và khác 0
                // So sánh giá trị với interval đã tính toán (safeYInterval)
                if (value == meta.max ||
                    (value % safeYInterval == 0 &&
                        value != 0 &&
                        value != meta.min)) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4,
                    child: Text(value.toInt().toString(),
                        style: const TextStyle(fontSize: 9)),
                  );
                }
                return Container();
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),

          // --- Trục Dưới (X - Giờ) ---
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // --- INTERVAL CỐ ĐỊNH CHO TRỤC X ---
              interval: 3,
              // ----------------------------------
              getTitlesWidget: (value, meta) {
                final hour = value.toInt();
                String text = '';
                // --- KIỂM TRA TRỰC TIẾP VỚI INTERVAL CỐ ĐỊNH LÀ 3 ---
                if (hour % 3 == 0) {
                  // Không cần dùng meta.interval
                  final dtLocal = DateTime.now().copyWith(hour: hour).toLocal();
                  text = _hourFormat.format(dtLocal);
                }
                // --------------------------------------------------
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(text, style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
        ),

        // Cấu hình GridData, sử dụng lại safeYInterval
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: safeYInterval, // Sử dụng interval đã tính
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
          checkToShowHorizontalLine: (value) =>
              value % safeYInterval == 0 &&
              value != 0, // Kiểm tra với interval đã tính
        ),

        // ... Phần còn lại của BarChartData (borderData, barTouchData) giữ nguyên ...
        borderData: FlBorderData(/* ... */),
        barTouchData: BarTouchData(/* ... */),
      ),
    );
  }
}
