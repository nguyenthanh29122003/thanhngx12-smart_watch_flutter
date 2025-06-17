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

  late DateTime _uiSelectedDate;
  bool _isDateInitialized = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chỉ khởi tạo ngày một lần duy nhất
    if (!_isDateInitialized) {
      // Lấy giá trị ban đầu từ provider một cách an toàn
      _uiSelectedDate = context.read<DashboardProvider>().selectedDate;
      _isDateInitialized = true;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final dashboardProvider = context.read<DashboardProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _uiSelectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(), // Không cho chọn ngày tương lai
    );

    if (picked != null && picked != _uiSelectedDate) {
      setState(() => _uiSelectedDate = picked);
      // Yêu cầu provider tải dữ liệu cho ngày mới
      dashboardProvider.fetchHealthHistory(specificDate: picked);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  // --- HÀM BUILD CHÍNH ---
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardProvider = context.watch<DashboardProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activitySummaryDetailScreenTitle),
        actions: [
          // Nút chọn ngày
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: l10n.selectDateTooltip, // Key mới
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            dashboardProvider.fetchHealthHistory(specificDate: _uiSelectedDate),
        child: Builder(
            builder: (context) => _buildContent(context, dashboardProvider)),
      ),
    );
  }

  // --- WIDGET XÂY DỰNG NỘI DUNG CHÍNH DỰA TRÊN TRẠNG THÁI ---
  Widget _buildContent(BuildContext context, DashboardProvider provider) {
    final l10n = AppLocalizations.of(context)!;

    switch (provider.historyStatus) {
      case HistoryStatus.loading:
      case HistoryStatus.initial:
        return const Center(child: CircularProgressIndicator());

      case HistoryStatus.error:
        return Center(
            child: Text(provider.historyError ?? l10n.chartCouldNotLoad));

      case HistoryStatus.loaded:
        final sortedHistory =
            List<ActivitySegment>.from(provider.activityHistory)
              ..sort((a, b) => b.startTime.compareTo(a.startTime));

        return CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
                child: _buildSummaryHeader(context, provider, l10n)),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            if (sortedHistory.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Text(
                  l10n.activitySummaryNoDataForDate,
                  textAlign: TextAlign.center,
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ActivityTimelineItem(
                      segment: sortedHistory[index],
                      isLast: index == sortedHistory.length - 1,
                    ),
                    childCount: sortedHistory.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
    }
  }

  // --- WIDGET HEADER TÓM TẮT TỔNG THỜI GIAN HOẠT ĐỘNG ---
  Widget _buildSummaryHeader(
      BuildContext context, DashboardProvider provider, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final totalDuration = provider.todayTotalActivityDuration;
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    final String formattedDate =
        DateFormat.yMMMMd(l10n.localeName).format(_uiSelectedDate);

    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Column(
          children: [
            Text(formattedDate, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
                children: [
                  TextSpan(text: '$hours'),
                  TextSpan(
                      text: 'h ',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.primary.withOpacity(0.8))),
                  TextSpan(text: '$minutes'),
                  TextSpan(
                      text: 'm',
                      style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.primary.withOpacity(0.8))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(l10n.totalActiveTimeTodayTitle,
                style: theme.textTheme.bodyMedium),
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
