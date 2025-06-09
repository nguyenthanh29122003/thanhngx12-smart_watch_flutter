// lib/screens/core/activity_history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/activity_segment.dart';
import '../../generated/app_localizations.dart';

class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Sử dụng 'read' ở đây vì màn hình này thường không cần build lại
    // toàn bộ khi dữ liệu thay đổi (ListView.builder sẽ xử lý)
    // Nhưng nếu bạn muốn cả màn hình build lại khi onRefresh, 'watch' cũng ổn.
    final provider = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activitySummaryDetailScreenTitle),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchHealthHistory(),
        child: _buildContent(context, provider, l10n),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, DashboardProvider provider, AppLocalizations l10n) {
    switch (provider.historyStatus) {
      case HistoryStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case HistoryStatus.error:
        return Center(
            child: Text(provider.historyError ?? l10n.chartCouldNotLoad));
      case HistoryStatus.loaded:
        if (provider.activityHistory.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(l10n.activitySummaryNoData,
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );
        }

        // Sắp xếp lịch sử hoạt động, mới nhất lên trên
        final sortedHistory =
            List<ActivitySegment>.from(provider.activityHistory)
              ..sort((a, b) => b.startTime.compareTo(a.startTime));

        final totalDuration = provider.todayTotalActivityDuration;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: sortedHistory.length + 1, // +1 cho header tóm tắt
          itemBuilder: (context, index) {
            if (index == 0) {
              // Header tóm tắt
              return _buildSummaryHeader(context, totalDuration, l10n);
            }
            // Các item trong dòng thời gian
            final segment = sortedHistory[index - 1];
            return _ActivitySegmentListItem(segment: segment);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  // Widget header tóm tắt
  Widget _buildSummaryHeader(
      BuildContext context, Duration totalDuration, AppLocalizations l10n) {
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.blueGrey, size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total Active Time Today", // TODO: i18n
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.blueGrey),
              ),
              RichText(
                text: TextSpan(
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: '$hours'),
                    TextSpan(
                        text: 'h ',
                        style: Theme.of(context).textTheme.bodyLarge),
                    TextSpan(text: '$minutes'),
                    TextSpan(
                        text: 'm',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

// Widget con để hiển thị một item trong timeline
class _ActivitySegmentListItem extends StatelessWidget {
  final ActivitySegment segment;

  const _ActivitySegmentListItem({required this.segment});

  // Hàm helper để lấy Icon và Color
  Map<String, dynamic> _getActivityVisuals(
      BuildContext context, String activityName) {
    final colorMap = {
      'Sitting': Colors.orange.shade400,
      'Standing': Colors.blue.shade400,
      'Walking': Colors.green.shade400,
      'Running': Colors.red.shade400,
      'Lying': Colors.purple.shade400,
      'Unknown': Colors.grey.shade400,
    };
    final iconMap = {
      'Sitting': Icons.chair_outlined,
      'Standing': Icons.accessibility_new_outlined,
      'Walking': Icons.directions_walk,
      'Running': Icons.directions_run,
      'Lying': Icons.hotel_outlined,
      'Unknown': Icons.question_mark,
    };
    return {
      'icon': iconMap[activityName] ?? Icons.device_unknown,
      'color': colorMap[activityName] ?? Colors.grey
    };
  }

  // Hàm helper dịch tên
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
    final visuals = _getActivityVisuals(context, segment.activityName);
    final IconData icon = visuals['icon'];
    final Color color = visuals['color'];
    final l10n = AppLocalizations.of(context)!;

    // Định dạng thời gian
    final timeFormat = DateFormat('HH:mm');
    final startTimeStr = timeFormat.format(segment.startTime.toLocal());
    final endTimeStr = timeFormat.format(segment.endTime.toLocal());

    // Định dạng thời lượng
    final duration = Duration(seconds: segment.durationInSeconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cột Icon và đường kẻ dọc timeline
          Column(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(icon, color: color, size: 24),
              ),
              // Đường kẻ dọc cho timeline
              Container(
                height: 50,
                width: 2,
                color: Colors.grey.shade300,
              )
            ],
          ),
          const SizedBox(width: 16),
          // Cột nội dung chính
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getLocalizedActivityName(segment.activityName, l10n),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$startTimeStr - $endTimeStr',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Chip(
                  avatar:
                      Icon(Icons.timer, size: 16, color: Colors.grey.shade700),
                  label: Text(
                    (minutes > 0)
                        ? "$minutes min $seconds sec"
                        : "$seconds sec", // TODO: i18n
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: Colors.grey.shade200,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
