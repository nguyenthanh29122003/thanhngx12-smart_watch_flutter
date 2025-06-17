// lib/screens/core/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:smart_wearable_app/screens/core/activity_history_screen.dart';

// Import Providers
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/goals_provider.dart';
// Import Services
import '../../services/activity_recognition_service.dart';
// Import Widgets
import '../../widgets/dashboard/realtime_metrics_card.dart';
import '../../widgets/dashboard/history_chart_card.dart';
import '../../widgets/dashboard/spo2_history_chart_card.dart';
import '../../widgets/dashboard/steps_history_chart_card.dart';
import '../../widgets/dashboard/activity_summary_chart_card.dart';
// Import Helpers, Constants & Screens
import '../../app_constants.dart';
import '../../generated/app_localizations.dart';
import 'main_navigator.dart';

// <<<<<<<<<<<<<<< BẮT ĐẦU CODE HOÀN CHỈNH - PHẦN 1 >>>>>>>>>>>>>>>

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final TabController _tabController;

  // <<< THÊM STATE MỚI ĐỂ QUẢN LÝ NGÀY ĐANG CHỌN >>>
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    // Khởi tạo ngày đã chọn là ngày hôm nay, lấy từ provider
    _selectedDate = context.read<DashboardProvider>().selectedDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Tải dữ liệu cho ngày mặc định (hôm nay)
      _initialDataFetch();
    });
  }

  /// Hàm để tải dữ liệu ban đầu một cách tập trung
  void _initialDataFetch() {
    if (!mounted) return;
    context
        .read<DashboardProvider>()
        .fetchHealthHistory(specificDate: _selectedDate);
    context.read<GoalsProvider>().loadDailyGoal();
  }

  @override
  void dispose() {
    // Dọn dẹp các tài nguyên khi widget bị hủy
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Tải lại dữ liệu khi người dùng quay trở lại ứng dụng từ nền
    if (state == AppLifecycleState.resumed && mounted) {
      _initialDataFetch();
    }
  }

  Future<void> _selectDate() async {
    final dashboardProvider = context.read<DashboardProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked; // Cập nhật state của UI
      });
      // Yêu cầu provider tải dữ liệu cho ngày mới được chọn
      dashboardProvider.fetchHealthHistory(specificDate: picked);
    }
  }

  // ================================================================
  // --- HÀM BUILD CHÍNH VÀ CÁC HÀM HELPER BUILD UI ---
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();

    // Sử dụng Scaffold mới
    return Scaffold(
      body: SafeArea(
        // RefreshIndicator để kéo xuống làm mới
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              context.read<DashboardProvider>().fetchHealthHistory(),
              context.read<GoalsProvider>().loadDailyGoal(),
            ]);
          },
          // CustomScrollView là cách tốt nhất để tạo các hiệu ứng cuộn phức tạp
          child: CustomScrollView(
            slivers: [
              // 1. Header dính (SliverAppBar)
              _buildSliverHeader(
                  context, l10n, theme, authProvider, _selectDate),

              // 2. Nội dung chính có thể cuộn
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // Card mục tiêu chính
                      const _MainGoalCard(),
                      const SizedBox(height: 16),
                      // Card hoạt động hiện tại
                      const _CurrentActivityCard(),
                      const SizedBox(height: 32),

                      // Tiêu đề Section
                      Text(l10n.realtimeMetricsTitle,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      // Widget các chỉ số thời gian thực
                      const RealtimeMetricsCard(),
                      const SizedBox(height: 32),

                      // Tiêu đề Section
                      Text(l10n.historyAndTrendsTitle,
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 16),
                      // Biểu đồ tròn tóm tắt hoạt động
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ActivityHistoryScreen(),
                            ),
                          );
                        },
                        child: const ActivitySummaryChartCard(),
                      ),
                      const SizedBox(height: 16),
                      // Card chứa các Tab biểu đồ chi tiết
                      _buildHistoryTabBarCard(l10n, theme),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Hàm helper xây dựng SliverAppBar (header dính ở trên)
  SliverAppBar _buildSliverHeader(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    AuthProvider authProvider,
    VoidCallback onDateTap,
  ) {
    // Logic xác định lời chào dựa trên thời gian trong ngày
    final String welcomeMessage;
    final int currentHour = DateTime.now().hour;
    if (currentHour < 12) {
      welcomeMessage = l10n.greetingGoodMorning;
    } else if (currentHour < 18) {
      welcomeMessage = l10n.greetingGoodAfternoon;
    } else {
      welcomeMessage = l10n.greetingGoodEvening;
    }

    final displayName = authProvider.preferredDisplayName ?? l10n.defaultUser;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final String dateDisplay;
    if (_selectedDate == today) {
      dateDisplay = l10n.today; // Key mới
    } else if (_selectedDate == yesterday) {
      dateDisplay = l10n.yesterday; // Key mới
    } else {
      dateDisplay = DateFormat.yMMMd(l10n.localeName).format(_selectedDate);
    }

    return SliverAppBar(
      pinned: true, // "Dính" lại ở trên khi cuộn
      floating: true, // "Nổi" lên ngay khi cuộn lên một chút
      snap: true, // Tự động dính/ẩn hoàn toàn
      backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
      elevation: 0,
      surfaceTintColor:
          Colors.transparent, // Loại bỏ hiệu ứng đổ màu của Material 3
      titleSpacing: 16.0, // Khoảng cách tiêu đề

      // Nội dung của AppBar
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Text(welcomeMessage,
          //     style: theme.textTheme.bodyMedium?.copyWith(
          //       color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
          //     )),
          // Text(displayName, style: theme.textTheme.titleLarge),
          Text(
              '$welcomeMessage ${authProvider.preferredDisplayName ?? l10n.defaultUser}!',
              style: theme.textTheme.bodyMedium),
          InkWell(
            onTap: onDateTap, // Gọi hàm chọn ngày khi nhấn
            child: Row(
              mainAxisSize: MainAxisSize.min, // Co lại theo nội dung
              children: [
                Text(dateDisplay,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.expand_more_rounded,
                    size: 20, color: theme.colorScheme.primary),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_today_outlined),
          tooltip: l10n.selectDateTooltip,
          onPressed: onDateTap,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surface,
            backgroundImage: authProvider.user?.photoURL != null
                ? NetworkImage(authProvider.user!.photoURL!)
                : null,
            child: authProvider.user?.photoURL == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold))
                : null,
          ),
        ),
      ],
    );
  }

  /// Hàm helper xây dựng Card chứa TabBar và các biểu đồ lịch sử
  Widget _buildHistoryTabBarCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Container chứa TabBar tùy chỉnh
          Container(
            padding: const EdgeInsets.all(4.0),
            margin: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: theme.colorScheme.onSurface,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.6),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500),
              indicator: BoxDecoration(
                // "Con trượt" của TabBar
                borderRadius: BorderRadius.circular(10.0),
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent, // Bỏ gạch chân mặc định
              tabs: [
                Tab(text: l10n.hrTabTitle),
                Tab(text: l10n.spo2TabTitle),
                Tab(text: l10n.stepsTabTitle),
              ],
            ),
          ),

          // Container chứa nội dung của các Tab
          SizedBox(
            height: 250, // Chiều cao cố định cho các biểu đồ
            child: TabBarView(
              controller: _tabController,
              children: [
                // Thêm Padding để biểu đồ không bị sát viền
                Padding(
                    padding:
                        const EdgeInsets.only(right: 16, top: 16, bottom: 12),
                    child: HistoryChartCard()),
                Padding(
                    padding:
                        const EdgeInsets.only(right: 16, top: 16, bottom: 12),
                    child: Spo2HistoryChartCard()),
                Padding(
                    padding:
                        const EdgeInsets.only(right: 16, top: 16, bottom: 12),
                    child: StepsHistoryChartCard()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// lib/screens/core/dashboard_screen.dart

// ... code của class _DashboardScreenState ở trên ...

// <<<<<<<<<<<<<<< BẮT ĐẦU PHẦN 3 >>>>>>>>>>>>>>>

// ================================================================
// CÁC WIDGET CON ĐƯỢC TÁCH RA CHO GỌN GÀNG
// ================================================================

// --- CARD MỤC TIÊU CHÍNH (HERO SECTION) ---
class _MainGoalCard extends StatelessWidget {
  const _MainGoalCard();

  @override
  Widget build(BuildContext context) {
    // Lắng nghe cả hai provider cần thiết
    final goalsProvider = context.watch<GoalsProvider>();
    final dashboardProvider = context.watch<DashboardProvider>();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Lấy dữ liệu
    final currentSteps = dashboardProvider.todayTotalSteps;
    final currentGoal = goalsProvider.currentStepGoal;
    final double percent =
        (currentGoal > 0) ? (currentSteps / currentGoal).clamp(0.0, 1.0) : 0.0;
    final bool goalAchieved = percent >= 1.0;

    return GestureDetector(
      onTap: () {
        // Điều hướng đến màn hình Mục tiêu
        try {
          context
              .findAncestorStateOfType<MainNavigatorState>()
              ?.navigateTo(AppConstants.goalsScreenIndex);
        } catch (e) {
          print("Error navigating to GoalsScreen from _MainGoalCard: $e");
        }
      },
      child: Card(
        elevation: 4.0,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Vòng tròn tiến độ
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 12,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      goalAchieved ? Colors.green : theme.colorScheme.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              const SizedBox(width: 20),

              // Cột văn bản
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.mainGoalTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7))),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.decimalPattern().format(currentSteps),
                      style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      goalAchieved
                          ? l10n.goalAchievedMessage
                          : l10n.stepsOutOfGoal(NumberFormat.decimalPattern()
                              .format(currentGoal)),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: theme.colorScheme.primary.withOpacity(0.5)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CARD HOẠT ĐỘNG HIỆN TẠI ---
class _CurrentActivityCard extends StatelessWidget {
  const _CurrentActivityCard();

  @override
  Widget build(BuildContext context) {
    // Không lắng nghe, chỉ lấy service để cung cấp stream
    final activityService =
        Provider.of<ActivityRecognitionService>(context, listen: false);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // StreamBuilder tự động cập nhật UI khi có dữ liệu mới
        child: StreamBuilder<String>(
          stream: activityService.activityPredictionStream,
          initialData:
              activityService.currentActivityValue, // Lấy giá trị ban đầu
          builder: (context, snapshot) {
            IconData activityIcon;
            String activityText;
            Color activityColor = theme.colorScheme.primary;

            if (snapshot.hasError) {
              activityText = l10n.activityError;
              activityIcon = Icons.error_outline_rounded;
              activityColor = theme.colorScheme.error;
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              final currentActivity = snapshot.data!;
              activityText = _getLocalizedActivityName(currentActivity, l10n);
              activityIcon = _getActivityIcon(currentActivity);
            } else {
              activityText = l10n.activityInitializing;
              activityIcon = Icons.hourglass_empty_rounded;
              activityColor = theme.disabledColor;
            }

            return Row(
              children: [
                Icon(activityIcon, size: 32, color: activityColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.currentActivityTitle,
                          style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Text(
                          activityText,
                          key: ValueKey<String>(activityText),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- Các hàm helper ---
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

  IconData _getActivityIcon(String activityKey) {
    switch (activityKey) {
      case 'Standing':
        return Icons.accessibility_new_rounded;
      case 'Lying':
        return Icons.hotel_rounded;
      case 'Sitting':
        return Icons.chair_rounded;
      case 'Walking':
        return Icons.directions_walk_rounded;
      case 'Running':
        return Icons.directions_run_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}
