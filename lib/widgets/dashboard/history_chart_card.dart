// lib/widgets/dashboard/history_chart_card.dart
import 'package:fl_chart/fl_chart.dart'; // Import thư viện biểu đồ
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/dashboard_provider.dart'; // Lấy dữ liệu lịch sử và trạng thái
import '../../models/health_data.dart'; // Cần model

class HistoryChartCard extends StatelessWidget {
  const HistoryChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe DashboardProvider
    final provider = context.watch<DashboardProvider>();

    return Card(
      elevation: 4.0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health History (Last 24h)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            // Hiển thị nội dung dựa trên trạng thái tải
            _buildChartContent(
              context,
              provider.historyStatus,
              provider.healthHistory,
              provider.historyError,
            ),
          ],
        ),
      ),
    );
  }

  // Widget con để xây dựng nội dung biểu đồ
  Widget _buildChartContent(
    BuildContext context,
    HistoryStatus status,
    List<HealthData> history,
    String? error,
  ) {
    switch (status) {
      case HistoryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HistoryStatus.error:
        return Center(
          child: Text(
            'Error loading history: ${error ?? 'Unknown error'}',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      case HistoryStatus.loaded:
        if (history.isEmpty) {
          return const Center(
            child: Text('No history data available for the selected period.'),
          );
        }
        // --- Hiển thị biểu đồ khi có dữ liệu ---
        return SizedBox(
          height: 250, // Đặt chiều cao cố định cho biểu đồ
          child: LineChart(
            _buildLineChartData(
              context,
              history,
            ), // Hàm tạo dữ liệu cho biểu đồ
            // swapAnimationDuration: Duration(milliseconds: 150), // Optional
            // swapAnimationCurve: Curves.linear, // Optional
          ),
        );
      // TODO: Thêm BarChart cho Steps nếu cần
      case HistoryStatus.initial:
      default:
        return const Center(child: Text('History data will be loaded here.'));
    }
  }

  // --- Hàm tạo dữ liệu cho LineChart ---
  LineChartData _buildLineChartData(
    BuildContext context,
    List<HealthData> history,
  ) {
    final Color hrColor = Colors.red.shade400;
    final Color spo2Color = Colors.blue.shade400;

    // Chuẩn bị danh sách các điểm FlSpot (x, y) cho mỗi đường
    List<FlSpot> hrSpots = [];
    List<FlSpot> spo2Spots = [];

    // Tìm timestamp min/max để xác định trục X
    // Chuyển timestamp thành giá trị double (ví dụ: millisecondsSinceEpoch)
    double minX = double.maxFinite;
    double maxX = double.minPositive;

    for (int i = 0; i < history.length; i++) {
      final data = history[i];
      final double xValue = data.timestamp.millisecondsSinceEpoch.toDouble();

      // Cập nhật min/max X
      if (xValue < minX) minX = xValue;
      if (xValue > maxX) maxX = xValue;

      // Thêm điểm cho HR (chỉ thêm nếu hợp lệ)
      if (data.hr >= 0) {
        hrSpots.add(FlSpot(xValue, data.hr.toDouble()));
      }
      // Thêm điểm cho SpO2 (chỉ thêm nếu hợp lệ)
      if (data.spo2 >= 0) {
        spo2Spots.add(FlSpot(xValue, data.spo2.toDouble()));
      }
    }

    // Xử lý trường hợp không có điểm nào (hiếm khi xảy ra nếu history không rỗng)
    if (minX == double.maxFinite)
      minX =
          DateTime.now()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch
              .toDouble();
    if (maxX == double.minPositive)
      maxX = DateTime.now().millisecondsSinceEpoch.toDouble();
    // Đảm bảo minX < maxX nếu chỉ có 1 điểm hoặc không có điểm
    if (minX >= maxX)
      maxX = minX + const Duration(hours: 1).inMilliseconds.toDouble();

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        getDrawingHorizontalLine:
            (value) => const FlLine(
              // color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
        getDrawingVerticalLine:
            (value) => const FlLine(
              // color: Colors.grey.withOpacity(0.2),
              strokeWidth: 1,
            ),
      ),
      titlesData: FlTitlesData(
        // --- Trục dưới (X - Thời gian) ---
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30, // Khoảng trống cho label
            interval: (maxX - minX) / 4, // Chia thành 5 khoảng thời gian chính
            getTitlesWidget: (value, meta) {
              // Chuyển đổi millisecond timestamp về dạng HH:mm
              DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                value.toInt(),
              );
              // Chỉ hiển thị giờ:phút để tránh quá dày
              String time = DateFormat('HH:mm').format(dateTime.toLocal());
              // Chỉ hiển thị ở các khoảng chính để tránh chồng chéo
              // if (value == meta.min || value == meta.max || (value - meta.min) % meta.interval == 0) {
              return SideTitleWidget(
                axisSide: meta.axisSide,
                space: 4,
                child: Text(time, style: const TextStyle(fontSize: 10)),
              );
              // }
              // return Container();
            },
          ),
        ),
        // --- Trục trái (Y - Giá trị HR/SpO2) ---
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            // interval: 10, // Hiển thị mỗi 10 đơn vị
            getTitlesWidget: (value, meta) {
              // Làm tròn giá trị và hiển thị
              return Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              );
            },
            reservedSize: 40, // Khoảng trống cho label trục Y
          ),
        ),
        // Ẩn trục trên và phải
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.5), width: 1),
      ),
      minX: minX, // Giới hạn trục X
      maxX: maxX,
      minY: 40, // Giới hạn trục Y (ví dụ: từ 40 đến 140)
      maxY: 140,
      lineBarsData: [
        // --- Đường Nhịp tim (HR) ---
        LineChartBarData(
          spots: hrSpots,
          isCurved: true, // Vẽ đường cong
          color: hrColor,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false), // Không hiển thị điểm dữ liệu
          belowBarData: BarAreaData(
            show: true,
            color: hrColor.withOpacity(0.1),
          ), // Tô màu vùng dưới đường
        ),
        // --- Đường SpO2 ---
        LineChartBarData(
          spots: spo2Spots,
          isCurved: true,
          color: spo2Color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: spo2Color.withOpacity(0.1),
          ),
        ),
      ],
      // --- Tooltip khi chạm vào điểm ---
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          // tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final flSpot = barSpot;
              // Lấy thời gian từ trục X
              DateTime time =
                  DateTime.fromMillisecondsSinceEpoch(
                    flSpot.x.toInt(),
                  ).toLocal();
              String timeStr = DateFormat('HH:mm:ss').format(time);
              String label = '';
              // Xác định xem điểm chạm thuộc đường nào
              if (barSpot.barIndex == 0)
                label = 'HR: '; // HR
              else if (barSpot.barIndex == 1)
                label = 'SpO2: '; // SpO2

              return LineTooltipItem(
                '$label${flSpot.y.toStringAsFixed(0)}\n', // Giá trị Y (làm tròn)
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: timeStr, // Hiển thị thời gian
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true, // Bật xử lý chạm mặc định
      ),
    );
  }
}
