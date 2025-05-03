// lib/widgets/dashboard/history_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; // Import để định dạng ngày giờ

import '../../providers/dashboard_provider.dart';
import '../../models/health_data.dart'; // Cần để truy cập HealthData
import '../../generated/app_localizations.dart';

class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Sử dụng Consumer để lắng nghe thay đổi từ DashboardProvider
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        Widget chartContent;

        // Xử lý các trạng thái tải dữ liệu
        switch (provider.historyStatus) {
          case HistoryStatus.initial:
          case HistoryStatus.loading:
            chartContent = const Center(child: CircularProgressIndicator());
            break;
          case HistoryStatus.error:
            chartContent = Center(
              child: Text(
                // <<< DÙNG KEY >>>
                "${l10n.chartErrorPrefix} ${provider.historyError ?? l10n.chartCouldNotLoad}",
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center, // Thêm canh giữa
              ),
            );
            break;
          case HistoryStatus.loaded:
            if (provider.healthHistory.isEmpty) {
              chartContent = Center(
                  child: Text(l10n.chartNoDataPeriod,
                      textAlign: TextAlign.center)); // <<< DÙNG KEY
            } else {
              chartContent = _buildLineChart(context, provider.healthHistory);
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
                  l10n.hrHistoryTitle, // <<< DÙNG KEY
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

  // --- Hàm xây dựng LineChart ---
  Widget _buildLineChart(BuildContext context, List<HealthData> historyData) {
    final l10n = AppLocalizations.of(context)!;
    // --- 1. Chuẩn bị dữ liệu cho biểu đồ ---
    List<FlSpot> spots = [];
    List<HealthData> validData = []; // Chỉ lấy dữ liệu hợp lệ (hr > 0)

    // Lọc dữ liệu không hợp lệ (ví dụ: hr = -1 hoặc 0)
    validData = historyData.where((data) => data.hr > 0).toList();

    // Nếu không có dữ liệu hợp lệ nào sau khi lọc
    if (validData.isEmpty) {
      return Center(
          child: Text(l10n.chartNoValidHr, textAlign: TextAlign.center));
    }

    // Tìm min/max cho trục Y (HR) từ dữ liệu hợp lệ
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (var data in validData) {
      // Tạo FlSpot: X là thời gian (milliseconds), Y là nhịp tim
      spots.add(FlSpot(
        data.timestamp.millisecondsSinceEpoch.toDouble(), // Trục X: Thời gian
        data.hr.toDouble(), // Trục Y: Nhịp tim
      ));
      // Cập nhật min/max Y
      if (data.hr < minY) minY = data.hr.toDouble();
      if (data.hr > maxY) maxY = data.hr.toDouble();
    }

    // Thêm khoảng đệm cho trục Y để đẹp hơn
    minY = (minY - 5).clamp(0, double.infinity); // Đảm bảo không âm
    maxY = maxY + 5;

    // Tìm min/max cho trục X (Timestamp) - lấy từ record đầu và cuối đã sắp xếp
    // (Giả sử historyData đã được sắp xếp theo thời gian tăng dần từ Firestore)
    double minX = validData.first.timestamp.millisecondsSinceEpoch.toDouble();
    double maxX = validData.last.timestamp.millisecondsSinceEpoch.toDouble();

    // --- 2. Cấu hình LineChartData ---
    return LineChart(
      LineChartData(
        // --- Dữ liệu đường kẻ ---
        lineBarsData: [
          LineChartBarData(
            spots: spots, // Danh sách các điểm dữ liệu
            isCurved: true, // Vẽ đường cong
            color: Colors.redAccent, // Màu đường kẻ
            barWidth: 3, // Độ dày đường kẻ
            isStrokeCapRound: true,
            dotData: const FlDotData(
                show: false), // Không hiển thị chấm trên điểm dữ liệu
            belowBarData: BarAreaData(
              // Tô màu khu vực dưới đường kẻ
              show: true,
              color: Colors.redAccent.withOpacity(0.2),
            ),
          ),
        ],

        // --- Tiêu đề trục (Titles) ---
        titlesData: FlTitlesData(
          // --- Trục Trái (Y - Heart Rate) ---
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Hiển thị tiêu đề trục Y
              reservedSize: 40, // Khoảng trống cho tiêu đề
              getTitlesWidget: (value, meta) {
                // Chỉ hiển thị một vài giá trị chính
                if (value == meta.min ||
                    value == meta.max ||
                    (value >= minY + 5 && (value.toInt() % 10 == 0))) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8.0, // Khoảng cách từ trục
                    child: Text(
                      value
                          .toInt()
                          .toString(), // Hiển thị giá trị HR (số nguyên)
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                }
                return Container(); // Không hiển thị các giá trị khác
              },
              // interval: 10, // Có thể dùng interval nếu muốn cách đều
            ),
          ),
          // Ẩn trục phải, trên
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),

          // --- Trục Dưới (X - Thời gian) ---
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Hiển thị tiêu đề trục X
              reservedSize: 30, // Khoảng trống
              interval: _calculateBottomTitleInterval(
                  minX, maxX), // Tính khoảng cách tự động
              getTitlesWidget: (value, meta) {
                // Chuyển đổi milliseconds về DateTime
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt(),
                        isUtc: true)
                    .toLocal();
                // Định dạng giờ:phút
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
          horizontalInterval: 10, // Khoảng cách lưới ngang (theo giá trị HR)
          verticalInterval: _calculateBottomTitleInterval(
              minX, maxX), // Khoảng cách lưới dọc (theo thời gian)
          getDrawingHorizontalLine: (value) {
            return FlLine(
                color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
                color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
          },
          checkToShowHorizontalLine: (value) {
            // Chỉ vẽ lưới ngang tại các mốc chẵn 10
            return value.toInt() % 10 == 0;
          },
        ),

        // --- Đường viền (Border) ---
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
        ),

        // --- Giới hạn trục (Min/Max) ---
        minX: minX, // Thời gian bắt đầu
        maxX: maxX, // Thời gian kết thúc
        minY: minY, // HR thấp nhất (có padding)
        maxY: maxY, // HR cao nhất (có padding)

        // --- Dữ liệu chạm (Touch Tooltip) ---
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                // barSpot bây giờ là một LineBarSpot

                // final flSpot = barSpot.spot; // <<< XÓA DÒNG NÀY ĐI

                // Sử dụng trực tiếp barSpot.x và barSpot.y
                // Chuyển X (milliseconds) về DateTime
                final dt = DateTime.fromMillisecondsSinceEpoch(
                        barSpot.x.toInt(),
                        isUtc: true)
                    .toLocal();
                // Định dạng tooltip
                final timeStr = DateFormat('HH:mm:ss').format(dt);
                // Lấy giá trị Y (HR) trực tiếp từ barSpot.y
                final hrStr = barSpot.y.toInt().toString();

                return LineTooltipItem(
                  '$timeStr\n', // Dòng 1: Thời gian
                  const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(
                      text: 'HR: $hrStr bpm', // Dòng 2: Giá trị HR
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
          handleBuiltInTouches: true, // Bật xử lý chạm mặc định
        ),
      ),
      // duration: Duration(milliseconds: 150), // Optional animation
      // curve: Curves.linear, // Optional animation curve
    );
  }

  // Hàm tính khoảng cách (interval) phù hợp cho trục thời gian (X)
  double _calculateBottomTitleInterval(double minX, double maxX) {
    final double durationMillis = maxX - minX;
    // Quy đổi sang giờ
    final double durationHours = durationMillis / (1000 * 60 * 60);

    if (durationHours <= 2) {
      // Dưới 2 giờ: hiển thị mỗi 15 phút
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
