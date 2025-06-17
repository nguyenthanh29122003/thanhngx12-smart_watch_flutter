// lib/widgets/dashboard/activity_summary_chart_card.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:smart_wearable_app/models/activity_segment.dart';
import 'package:smart_wearable_app/screens/core/activity_history_screen.dart';

import '../../providers/dashboard_provider.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>

class ActivitySummaryChartCard extends StatefulWidget {
  const ActivitySummaryChartCard({super.key});

  @override
  State<ActivitySummaryChartCard> createState() =>
      _ActivitySummaryChartCardState();
}

class _ActivitySummaryChartCardState extends State<ActivitySummaryChartCard> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      elevation: 2.0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          // Điều hướng đến màn hình chi tiết
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
              // Tiêu đề
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.activitySummaryTitle,
                      style: theme.textTheme.titleMedium),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 18, color: theme.unselectedWidgetColor)
                ],
              ),
              const SizedBox(height: 16),
              // Nội dung biểu đồ
              Consumer<DashboardProvider>(
                builder: (context, provider, child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: SizedBox(
                      key: ValueKey(
                          'activity-summary-${provider.historyStatus}'),
                      height: 190, // Tăng chiều cao một chút
                      child: _buildChartContent(context, provider, l10n),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CÁC HÀM HELPER ---

  Widget _buildChartContent(
      BuildContext context, DashboardProvider provider, AppLocalizations l10n) {
    switch (provider.historyStatus) {
      case HistoryStatus.loading:
      case HistoryStatus.initial:
        return const Center(child: CircularProgressIndicator());
      case HistoryStatus.error:
        return _MessageState(
            icon: Icons.error_outline_rounded,
            message: provider.historyError ?? l10n.chartCouldNotLoad,
            color: Theme.of(context).colorScheme.error);
      case HistoryStatus.loaded:
        final summary = provider.activitySummary;
        final double totalSeconds = summary.fold(
            0, (prev, element) => prev + element.totalDuration.inSeconds);

        if (summary.isEmpty || totalSeconds < 60) {
          return _MessageState(
              icon: Icons.insights_rounded,
              message: l10n.activitySummaryNoData,
              color: Theme.of(context).disabledColor);
        } else {
          // <<< THAY ĐỔI LỚN Ở ĐÂY: DÙNG LAYOUTBUILDER >>>
          return LayoutBuilder(
            builder: (context, constraints) {
              // Nếu chiều rộng có sẵn nhỏ hơn 320 (một ngưỡng an toàn cho điện thoại nhỏ)
              if (constraints.maxWidth < 320) {
                // Sử dụng layout dạng CỘT
                return _buildPieChartColumnLayout(
                    context, summary, totalSeconds, l10n);
              } else {
                // Sử dụng layout dạng HÀNG (như cũ)
                return _buildPieChartRowLayout(
                    context, summary, totalSeconds, l10n);
              }
            },
          );
        }
    }
  }

  // --- LAYOUT DẠNG HÀNG (CHO MÀN HÌNH RỘNG) ---
  Widget _buildPieChartRowLayout(
      BuildContext context,
      List<ActivitySummaryData> summary,
      double totalSeconds,
      AppLocalizations l10n) {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 3, // Biểu đồ chiếm nhiều không gian hơn một chút
          child: _buildPieChart(summary, totalSeconds, l10n),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2, // Chú thích chiếm ít không gian hơn
          child: _buildLegend(summary, l10n),
        ),
      ],
    );
  }

  // --- LAYOUT DẠNG CỘT (CHO MÀN HÌNH HẸP) ---
  Widget _buildPieChartColumnLayout(
      BuildContext context,
      List<ActivitySummaryData> summary,
      double totalSeconds,
      AppLocalizations l10n) {
    return Column(
      children: <Widget>[
        Expanded(
          flex: 2, // Biểu đồ chiếm không gian trên
          child: _buildPieChart(summary, totalSeconds, l10n),
        ),
        const SizedBox(height: 16),
        // Chú thích được đặt trong một GridView 2 cột để tiết kiệm không gian
        Expanded(
          flex: 1, // Chú thích chiếm không gian dưới
          child: _buildLegend(summary, l10n, isGridView: true),
        ),
      ],
    );
  }

  // --- WIDGET CHUNG ĐỂ VẼ BIỂU ĐỒ TRÒN ---
  Widget _buildPieChart(List<ActivitySummaryData> summary, double totalSeconds,
      AppLocalizations l10n) {
    return PieChart(
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
        sectionsSpace: 2,
        centerSpaceRadius: 35,
        sections: List.generate(summary.length, (i) {
          final isTouched = (i == touchedIndex);
          final radius = isTouched ? 65.0 : 55.0;
          final percentage =
              (summary[i].totalDuration.inSeconds / totalSeconds) * 100;
          return PieChartSectionData(
            color: summary[i].color,
            value: summary[i].totalDuration.inSeconds.toDouble(),
            title: (percentage > 8) ? '${percentage.toStringAsFixed(0)}%' : '',
            radius: radius,
            titleStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: Colors.black45, blurRadius: 3)]),
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
      swapAnimationCurve: Curves.easeInOut,
    );
  }

  // --- WIDGET CHUNG ĐỂ VẼ CHÚ THÍCH (LEGEND) ---
  Widget _buildLegend(List<ActivitySummaryData> summary, AppLocalizations l10n,
      {bool isGridView = false}) {
    if (isGridView) {
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // 2 cột
          childAspectRatio: 3.5, // Tỉ lệ của mỗi item
          mainAxisSpacing: 4,
          crossAxisSpacing: 8,
        ),
        itemCount: summary.length,
        itemBuilder: (context, index) {
          final item = summary[index];
          return _Indicator(
              activity: item, isTouched: (index == touchedIndex), l10n: l10n);
        },
      );
    }

    return ListView(
      children: summary.map((item) {
        return _Indicator(
            activity: item,
            isTouched: (summary.indexOf(item) == touchedIndex),
            l10n: l10n);
      }).toList(),
    );
  }
}

// --- WIDGET HELPER ---

// Widget hiển thị thông báo chung (Lỗi, Rỗng, ...)
class _MessageState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  const _MessageState(
      {required this.icon, required this.color, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.7,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget cho mỗi dòng chú thích trong Legend
class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.activity,
    required this.isTouched,
    required this.l10n,
  });

  final ActivitySummaryData activity;
  final bool isTouched;
  final AppLocalizations l10n;

  String _getTranslatedActivityName(String key) {
    // Logic dịch tên hoạt động
    switch (key) {
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
    final theme = Theme.of(context);
    final minutes = activity.totalDuration.inMinutes;
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    String durationStr;
    if (hours > 0) {
      durationStr =
          remainingMinutes > 0 ? '${hours}h ${remainingMinutes}m' : '${hours}h';
    } else {
      durationStr = (minutes > 0) ? '${minutes}m' : '< 1m';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      // Highlight hàng được chọn
      decoration: BoxDecoration(
        color:
            isTouched ? activity.color.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          // Chấm tròn màu
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activity.color,
                // Thêm viền trắng nhẹ nếu được chọn
                border: isTouched
                    ? Border.all(color: Colors.white, width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: activity.color.withOpacity(0.5),
                    blurRadius: isTouched ? 5 : 2,
                  )
                ]),
          ),
          const SizedBox(width: 12),
          // Cột chứa tên hoạt động và thời gian
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTranslatedActivityName(activity.activityName),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  durationStr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color
                        ?.withOpacity(isTouched ? 1.0 : 0.7),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
