// lib/widgets/dashboard/activity_summary_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';
import '../../screens/core/activity_history_screen.dart';

// (Tùy chọn) Import màn hình chi tiết nếu bạn tạo nó
// import '../../screens/core/activity_history_screen.dart';

class ActivitySummaryChartCard extends StatefulWidget {
  const ActivitySummaryChartCard({super.key});

  @override
  State<ActivitySummaryChartCard> createState() =>
      _ActivitySummaryChartCardState();
}

class _ActivitySummaryChartCardState extends State<ActivitySummaryChartCard> {
  int touchedIndex = -1; // -1 nghĩa là không có section nào đang được chạm

  // Hàm helper để dịch tên hoạt động, giúp code gọn hơn
  String _getLocalizedActivityName(String activityKey, AppLocalizations l10n) {
    switch (activityKey) {
      case 'Standing':
        return l10n.activityStanding;
      case 'Lying':
        return l10n.activityLying;
      case 'Sitting':
        return l10n.activitySitting;
      case 'Walking':
        return l10n.activityWalking;
      case 'Running':
        return l10n.activityRunning;
      default:
        return l10n.activityUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        Widget chartContent;

        // Xử lý các trạng thái tải dữ liệu
        switch (provider.historyStatus) {
          case HistoryStatus.loading:
            chartContent = const Center(child: CircularProgressIndicator());
            break;
          case HistoryStatus.error:
            chartContent = Center(
                child: Text(provider.historyError ?? l10n.chartCouldNotLoad));
            break;
          case HistoryStatus.loaded:
            if (provider.activitySummary.isEmpty) {
              // Giao diện đẹp mắt hơn khi không có dữ liệu
              chartContent = _buildEmptyState(l10n);
            } else {
              chartContent =
                  _buildPieChart(context, provider.activitySummary, l10n);
            }
            break;
          default:
            chartContent = const SizedBox(
                height: 180); // Giữ chiều cao khi ở trạng thái initial
        }

        return Card(
          elevation: 4.0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          clipBehavior: Clip.antiAlias, // Giúp InkWell có hiệu ứng bo tròn
          child: InkWell(
            onTap: () {
              // <<< LOGIC ĐIỀU HƯỚNG >>>
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ActivityHistoryScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.activitySummaryTitle, // Sử dụng key đã dịch
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right, color: Colors.grey.shade400)
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: SizedBox(
                        key: ValueKey(provider
                            .historyStatus), // Đổi key để trigger animation
                        height: 180,
                        child: chartContent),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insights, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          l10n.activitySummaryNoData,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  Widget _buildPieChart(BuildContext context, List<ActivitySummaryData> summary,
      AppLocalizations l10n) {
    final double totalSeconds = summary.fold(
        0, (prev, element) => prev + element.totalDuration.inSeconds);

    if (totalSeconds < 60) {
      // Nếu tổng hoạt động dưới 1 phút thì cũng coi như không có gì
      return _buildEmptyState(l10n);
    }

    return Row(
      children: <Widget>[
        // --- Phần biểu đồ tròn ---
        Expanded(
          flex: 3, // Tăng không gian cho biểu đồ
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace:
                  isLandscape(context) ? 2 : 1, // Giảm khoảng cách trên mobile
              centerSpaceRadius: isLandscape(context)
                  ? 45
                  : 35, // Giảm bán kính giữa trên mobile
              sections: List.generate(summary.length, (i) {
                final isTouched = (i == touchedIndex);
                final fontSize = isTouched ? 18.0 : 14.0;
                final radius = isTouched ? 65.0 : 55.0;
                final percentage =
                    (summary[i].totalDuration.inSeconds / totalSeconds) * 100;

                return PieChartSectionData(
                  color: summary[i].color,
                  value: summary[i].totalDuration.inSeconds.toDouble(),
                  title: (percentage > 5)
                      ? '${percentage.toStringAsFixed(0)}%'
                      : '', // Chỉ hiện % nếu lớn
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 3)
                    ],
                  ),
                );
              }),
            ),
            swapAnimationDuration: const Duration(milliseconds: 250),
            swapAnimationCurve: Curves.easeInOut,
          ),
        ),

        const SizedBox(width: 16),

        // --- Phần Chú thích (Legend) ---
        Expanded(
          flex: 2, // Tăng không gian cho chú thích
          child: ListView(
            // Dùng ListView để có thể cuộn nếu có nhiều hoạt động
            shrinkWrap: true,
            children: summary.map((item) {
              final minutes = item.totalDuration.inMinutes;
              final hours = minutes ~/ 60;
              final remainingMinutes = minutes % 60;

              String durationStr = '';
              if (hours > 0) {
                durationStr += '${hours}h ';
              }
              // Chỉ hiện phút nếu có giá trị, hoặc nếu là 0 giờ thì hiện 0 phút
              if (remainingMinutes > 0 || hours == 0) {
                durationStr += '${remainingMinutes}m';
              }
              durationStr = durationStr.trim();

              return _Indicator(
                color: item.color,
                text: _getLocalizedActivityName(item.activityName, l10n),
                subText: durationStr.isEmpty ? "< 1m" : durationStr,
                isTouched: (summary.indexOf(item) == touchedIndex),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Helper để check hướng màn hình
  bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
}

// Widget helper cho Chú thích
class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.color,
    required this.text,
    required this.subText,
    this.isTouched = false,
  });

  final Color color;
  final String text;
  final String subText;
  final bool isTouched;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      decoration: BoxDecoration(
          color: isTouched ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: isTouched ? color.withOpacity(0.3) : Colors.transparent,
              width: 1.5)),
      child: Row(
        children: <Widget>[
          Container(
            width: isTouched ? 16 : 12,
            height: isTouched ? 16 : 12,
            decoration: BoxDecoration(
                shape: isTouched ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isTouched ? BorderRadius.circular(4) : null,
                color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subText,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.8),
                      fontWeight:
                          isTouched ? FontWeight.w600 : FontWeight.normal),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
