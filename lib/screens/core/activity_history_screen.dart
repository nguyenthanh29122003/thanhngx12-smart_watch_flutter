// lib/screens/core/activity_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/dashboard_provider.dart';
import '../../models/activity_segment.dart';
import '../../generated/app_localizations.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH >>>>>>>>>>>>>>>

class ActivityHistoryScreen extends StatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  State<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends State<ActivityHistoryScreen> {
  // ScrollController để có thể thêm các tính năng như "tải thêm" trong tương lai
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- HÀM BUILD CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Dùng 'watch' ở đây để toàn bộ màn hình có thể rebuild khi provider thay đổi
    // và kích hoạt RefreshIndicator
    final dashboardProvider = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activitySummaryDetailScreenTitle), // Key mới
      ),
      body: RefreshIndicator(
        // Gọi lại hàm fetchHealthHistory, hàm này sẽ tự động tính toán lại activitySummary
        onRefresh: () => context.read<DashboardProvider>().fetchHealthHistory(),
        // Dùng Builder để đảm bảo _buildContent luôn nhận được context mới nhất
        child: Builder(
          builder: (context) => _buildContent(context, dashboardProvider),
        ),
      ),
    );
  }

  // ... tiếp theo bên trong _ActivityHistoryScreenState

  // --- WIDGET XÂY DỰNG NỘI DUNG CHÍNH DỰA TRÊN TRẠNG THÁI ---
  Widget _buildContent(BuildContext context, DashboardProvider provider) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Xử lý các trạng thái khác nhau của provider
    switch (provider.historyStatus) {
      case HistoryStatus.loading:
      case HistoryStatus.initial:
        return const Center(child: CircularProgressIndicator());

      case HistoryStatus.error:
        // Giao diện khi có lỗi
        return Center(
            child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            provider.historyError ?? l10n.chartCouldNotLoad,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ));

      case HistoryStatus.loaded:
        final activitySegments = provider.activityHistory;

        // Giao diện khi không có dữ liệu
        if (activitySegments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.hourglass_empty_rounded,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3)),
                const SizedBox(height: 24),
                Text(l10n.activitySummaryNoData,
                    style: theme.textTheme.titleLarge),
              ],
            ),
          );
        }

        // Sắp xếp các phân đoạn hoạt động theo thời gian mới nhất lên đầu
        final sortedHistory = List<ActivitySegment>.from(activitySegments)
          ..sort((a, b) => b.startTime.compareTo(a.startTime));

        // Sử dụng CustomScrollView để có thể kết hợp nhiều loại Sliver
        return CustomScrollView(
          controller: _scrollController,
          // Luôn cho phép cuộn để RefreshIndicator hoạt động
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header tóm tắt tổng thời gian
            SliverToBoxAdapter(
                child: _buildSummaryHeader(
                    context, provider.todayTotalActivityDuration, l10n)),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            // Danh sách các item trên dòng thời gian
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return _ActivityTimelineItem(
                      segment: sortedHistory[index],
                      isLast: index == sortedHistory.length - 1,
                    );
                  },
                  childCount: sortedHistory.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: 32)), // Padding dưới cùng
          ],
        );
    }
  }

  // --- WIDGET HEADER TÓM TẮT TỔNG THỜI GIAN HOẠT ĐỘNG ---
  Widget _buildSummaryHeader(
      BuildContext context, Duration totalDuration, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            Text(
              l10n.totalActiveTimeTodayTitle, // Key mới
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Sử dụng Text.rich để style giờ và phút khác nhau
            Text.rich(
              TextSpan(
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                children: [
                  TextSpan(text: '$hours'),
                  TextSpan(
                    text: 'h ',
                    style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.primary.withOpacity(0.8)),
                  ),
                  TextSpan(text: '$minutes'),
                  TextSpan(
                    text: 'm',
                    style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.primary.withOpacity(0.8)),
                  ),
                ],
              ),
            ),
          ],
        ));
  }
}

// --- WIDGET HIỂN THỊ MỘT ITEM TRONG DÒNG THỜI GIAN ---
class _ActivityTimelineItem extends StatelessWidget {
  final ActivitySegment segment;
  final bool isLast; // Để biết có phải là item cuối cùng không

  const _ActivityTimelineItem({required this.segment, required this.isLast});

  // --- Các hàm helper được đóng gói bên trong widget này ---

  // Lấy icon và màu sắc tương ứng với hoạt động
  Map<String, dynamic> _getActivityVisuals(
      BuildContext context, String activityName) {
    final theme = Theme.of(context);
    final iconMap = {
      'Sitting': Icons.chair_outlined,
      'Standing': Icons.man_2_outlined, // Dùng icon khác cho đứng
      'Walking': Icons.directions_walk_rounded,
      'Running': Icons.directions_run_rounded,
      'Lying': Icons.king_bed_outlined,
      'Unknown': Icons.question_mark_rounded,
    };

    final Color color;
    switch (activityName) {
      case 'Walking':
      case 'Running':
        color = Colors.green.shade500; // Hoạt động tích cực
        break;
      case 'Standing':
        color = theme.colorScheme.secondary; // Hoạt động trung bình
        break;
      case 'Sitting':
      case 'Lying':
        color = Colors.orange.shade600; // Hoạt động không tích cực
        break;
      default:
        color = theme.colorScheme.primary;
    }
    return {
      'icon': iconMap[activityName] ?? Icons.device_unknown_rounded,
      'color': color
    };
  }

  // Dịch tên hoạt động
  String _getLocalizedActivityName(String activityKey, AppLocalizations l10n) {
    // Logic dịch tên giữ nguyên
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

  // Định dạng thời lượng cho dễ đọc
  String _formatDuration(int totalSeconds, AppLocalizations l10n) {
    if (totalSeconds < 60) {
      return l10n.durationSeconds(totalSeconds); // Key mới
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (seconds == 0) {
      return l10n.durationMinutes(minutes); // Key mới
    }
    return l10n.durationMinutesAndSeconds(minutes, seconds); // Key mới
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    final visuals = _getActivityVisuals(context, segment.activityName);
    final color = visuals['color'] as Color;
    final icon = visuals['icon'] as IconData;
    final startTimeStr =
        DateFormat('HH:mm').format(segment.startTime.toLocal());

    // Sử dụng IntrinsicHeight để đảm bảo đường kẻ và nội dung luôn thẳng hàng
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Phần Timeline bên trái (Thời gian và đường kẻ)
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 12.0),
                  child: Text(
                    startTimeStr,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                // Đường kẻ dọc
                Expanded(
                  child: Container(
                    width: 2,
                    // Không vẽ đường kẻ cho item cuối cùng
                    color: isLast
                        ? Colors.transparent
                        : theme.dividerColor.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          // Chấm tròn trên dòng thời gian
          Container(
            margin: const EdgeInsets.only(top: 16),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.scaffoldBackgroundColor, // Màu nền để che đường kẻ
              border: Border.all(color: color, width: 2.5),
            ),
          ),

          const SizedBox(width: 8),

          // Phần nội dung bên phải (trong một Container riêng)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(
                  bottom: 16.0), // Khoảng cách giữa các item
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                // Nền hơi khác để nổi bật
                color: theme.scaffoldBackgroundColor,
                // Viền màu tinh tế
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 8),
                      // Tên hoạt động
                      Expanded(
                        child: Text(
                          _getLocalizedActivityName(segment.activityName, l10n),
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Thời lượng
                  Text(
                    l10n.durationLabel(_formatDuration(
                        segment.durationInSeconds, l10n)), // Key mới
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
