// lib/widgets/dashboard/spo2_history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Import để định dạng ngày giờ

import '../../providers/dashboard_provider.dart';
import '../../models/health_data.dart'; // Cần để truy cập HealthData
import '../../generated/app_localizations.dart';

class Spo2HistoryChartCard extends StatelessWidget {
  const Spo2HistoryChartCard({super.key});

  // Ngưỡng SpO2 tối thiểu hợp lệ để hiển thị trên biểu đồ
  static const int minValidSpo2 = 85;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Sử dụng Consumer để lắng nghe thay đổi từ DashboardProvider
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        Widget chartContent;

        // Xử lý các trạng thái tải dữ liệu (giống HistoryChartCard)
        switch (provider.historyStatus) {
          case HistoryStatus.initial:
          case HistoryStatus.loading:
            // Giữ yên lặng trong trạng thái initial, chỉ hiện loading khi provider báo
            chartContent = (provider.historyStatus == HistoryStatus.loading)
                ? const Center(child: CircularProgressIndicator())
                : const SizedBox(height: 200); // Placeholder giữ chiều cao
            break;
          case HistoryStatus.error:
            chartContent = Center(
              child: Text(
                "${l10n.chartErrorPrefix} ${provider.historyError ?? l10n.chartCouldNotLoad}", // <<< DÙNG KEY
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            );
            break;
          case HistoryStatus.loaded:
            if (provider.healthHistory.isEmpty) {
              chartContent = Center(
                  child: Text(l10n.chartNoDataPeriod,
                      textAlign: TextAlign.center)); // <<< DÙNG KEY
            } else {
              chartContent =
                  _buildSpo2LineChart(context, provider.healthHistory);
            }
            break;
        }

        // Trả về Card chứa nội dung biểu đồ hoặc trạng thái tải
        return Card(
          elevation: 2.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.spo2HistoryTitle, // <<< DÙNG KEY
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: chartContent),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Hàm xây dựng LineChart cho SpO2 ---
  Widget _buildSpo2LineChart(
      BuildContext context, List<HealthData> historyData) {
    final l10n = AppLocalizations.of(context)!;
    // --- 1. Chuẩn bị dữ liệu cho biểu đồ ---
    List<FlSpot> spots = [];
    List<HealthData> validData = [];

    // Lọc dữ liệu SpO2 hợp lệ (ví dụ: >= minValidSpo2)
    validData = historyData.where((data) => data.spo2 >= minValidSpo2).toList();

    // Nếu không có dữ liệu hợp lệ nào sau khi lọc
    if (validData.isEmpty) {
      return Center(
          child: Text(l10n.chartNoValidSpo2(minValidSpo2),
              textAlign: TextAlign.center));
    }

    // Tạo FlSpot và tìm min/max X
    double minX = double.infinity;
    double maxX = double.negativeInfinity;

    for (var data in validData) {
      final timeMillis = data.timestamp.millisecondsSinceEpoch.toDouble();
      // Tạo FlSpot: X là thời gian (milliseconds), Y là SpO2
      spots.add(FlSpot(
        timeMillis,
        data.spo2.toDouble(), // <<< THAY ĐỔI: Dùng spo2
      ));
      if (timeMillis < minX) minX = timeMillis;
      if (timeMillis > maxX) maxX = timeMillis;
    }

    // Thiết lập cứng min/max cho trục Y (SpO2) để có thang đo ổn định
    double minY = minValidSpo2.toDouble() - 1; // Hơi dưới ngưỡng lọc
    const double maxY = 101; // Hơi trên 100% để hiển thị đẹp

    // --- 2. Cấu hình LineChartData ---
    return LineChart(
      LineChartData(
        // --- Dữ liệu đường kẻ ---
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue, // <<< THAY ĐỔI: Màu xanh dương cho SpO2
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2), // <<< THAY ĐỔI: Màu nền
            ),
          ),
        ],

        // --- Tiêu đề trục (Titles) ---
        titlesData: FlTitlesData(
          // --- Trục Trái (Y - SpO2) ---
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                // Chỉ hiển thị các mốc chính (ví dụ: 90, 95, 100)
                if (value == 90 || value == 95 || value == 100) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0,
                    child: Text(
                      '${value.toInt()}%', // <<< THAY ĐỔI: Hiển thị %
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return Container();
              },
              // interval: 5, // Hoặc có thể đặt interval cố định là 5
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),

          // --- Trục Dưới (X - Thời gian) ---
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: _calculateBottomTitleInterval(minX, maxX), // Giữ nguyên
              getTitlesWidget: (value, meta) {
                // Giữ nguyên logic hiển thị giờ:phút
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt(),
                        isUtc: true)
                    .toLocal();
                final format = DateFormat('HH:mm');
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8.0,
                  child: Text(
                    format.format(dt),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),

        // --- Đường lưới (Grid) ---
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval:
              5, // <<< THAY ĐỔI: Khoảng cách lưới ngang (theo SpO2 %)
          verticalInterval:
              _calculateBottomTitleInterval(minX, maxX), // Giữ nguyên
          getDrawingHorizontalLine: (value) {
            return FlLine(
                color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
                color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
          },
          checkToShowHorizontalLine: (value) {
            // Chỉ vẽ lưới ngang tại các mốc chẵn 5
            return value.toInt() % 5 == 0;
          },
        ),

        // --- Đường viền (Border) ---
        borderData: FlBorderData(
          // Giữ nguyên
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        ),

        // --- Giới hạn trục (Min/Max) ---
        minX: minX, // Thời gian bắt đầu (tính từ dữ liệu lọc)
        maxX: maxX, // Thời gian kết thúc (tính từ dữ liệu lọc)
        minY: minY, // SpO2 thấp nhất (đặt cứng)
        maxY: maxY, // SpO2 cao nhất (đặt cứng)

        // --- Dữ liệu chạm (Touch Tooltip) ---
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final dt = DateTime.fromMillisecondsSinceEpoch(
                        barSpot.x.toInt(),
                        isUtc: true)
                    .toLocal();
                final timeStr = DateFormat('HH:mm:ss').format(dt);
                // <<< THAY ĐỔI: Lấy giá trị SpO2 và định dạng
                final spo2Str = '${barSpot.y.toInt()}%';

                return LineTooltipItem(
                  '$timeStr\n',
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: 'SpO₂: $spo2Str', // <<< THAY ĐỔI: Hiển thị SpO2
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                  textAlign: TextAlign.left,
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }

  // Hàm tính khoảng cách (interval) phù hợp cho trục thời gian (X) - Giữ nguyên
  double _calculateBottomTitleInterval(double minX, double maxX) {
    final double durationMillis = maxX - minX;
    // Handle case where minX == maxX (only one data point)
    if (durationMillis <= 0) return 1000 * 60 * 15; // Default to 15 mins

    final double durationHours = durationMillis / (1000 * 60 * 60);

    if (durationHours <= 1) {
      // Dưới 1 giờ: hiển thị mỗi 5 phút
      return 1000 * 60 * 5;
    } else if (durationHours <= 2) {
      // 1-2 giờ: hiển thị mỗi 15 phút
      return 1000 * 60 * 15;
    } else if (durationHours <= 6) {
      // 2-6 giờ: hiển thị mỗi 30 phút
      return 1000 * 60 * 30;
    } else if (durationHours <= 12) {
      // 6-12 giờ: hiển thị mỗi giờ
      return 1000 * 60 * 60;
    } else if (durationHours <= 24) {
      // 12-24 giờ: hiển thị mỗi 2 giờ
      return 1000 * 60 * 60 * 2;
    } else {
      // Hơn 24 giờ: hiển thị mỗi 6 giờ
      return 1000 * 60 * 60 * 6;
    }
  }
}
