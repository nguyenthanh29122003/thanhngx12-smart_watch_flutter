// // lib/screens/core/dashboard_screen.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:smart_wearable_app/screens/core/main_navigator.dart';
// import 'package:smart_wearable_app/widgets/dashboard/activity_summary_chart_card.dart';
// import 'dart:math';

// // Import Providers
// import '../../providers/auth_provider.dart';
// import '../../providers/ble_provider.dart';
// import '../../providers/dashboard_provider.dart';
// import '../../providers/goals_provider.dart';
// // Import Services
// import '../../services/ble_service.dart';
// import '../../services/activity_recognition_service.dart';
// // Import Widgets
// import '../../widgets/dashboard/realtime_metrics_card.dart'; // <<< TẠM THỜI GIỮ LẠI
// import '../../widgets/dashboard/history_chart_card.dart';
// import '../../widgets/dashboard/spo2_history_chart_card.dart';
// import '../../widgets/dashboard/steps_history_chart_card.dart';
// // Import Helpers & Constants
// import '../../app_constants.dart';
// import '../../generated/app_localizations.dart';

// // <<< PHẦN 1: MÀN HÌNH CHÍNH & CÁC HÀM BUILD HELPER >>>

// class DashboardScreen extends StatefulWidget {
//   const DashboardScreen({super.key});

//   @override
//   State<DashboardScreen> createState() => _DashboardScreenState();
// }

// class _DashboardScreenState extends State<DashboardScreen>
//     with WidgetsBindingObserver, TickerProviderStateMixin {
//   // TickerProviderStateMixin cần cho TabController

//   late final TabController _tabController;

//   @override
//   void initState() {
//     super.initState();
//     _tabController =
//         TabController(length: 3, vsync: this); // 3 tab cho 3 biểu đồ

//     // Phần logic initState cũ của bạn (addObserver) vẫn giữ nguyên
//     WidgetsBinding.instance.addObserver(this);

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       // Logic cũ trong addPostFrameCallback cũng có thể giữ lại nếu cần
//       // Ví dụ: để làm mới dữ liệu khi màn hình được tải lần đầu
//       Provider.of<DashboardProvider>(context, listen: false)
//           .fetchHealthHistory();
//       Provider.of<GoalsProvider>(context, listen: false).loadDailyGoal();
//     });
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _tabController.dispose(); // Hủy TabController
//     super.dispose();
//   }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     if (state == AppLifecycleState.resumed && mounted) {
//       // Kích hoạt làm mới dữ liệu khi người dùng quay lại app
//       final dashboardProvider =
//           Provider.of<DashboardProvider>(context, listen: false);
//       final goalsProvider = Provider.of<GoalsProvider>(context, listen: false);

//       dashboardProvider.fetchHealthHistory();
//       goalsProvider.loadDailyGoal();
//     }
//   }

//   // --- HÀM BUILD CHÍNH - ĐÃ THAY ĐỔI HOÀN TOÀN ---
//   @override
//   Widget build(BuildContext context) {
//     // Lấy theme và l10n một lần ở đây
//     final l10n = AppLocalizations.of(context)!;
//     final theme = Theme.of(context);
//     final authProvider = context.watch<AuthProvider>();

//     // Sử dụng Scaffold mới, không có AppBar để chúng ta có thể tạo header tùy chỉnh
//     return Scaffold(
//       // SafeArea để đảm bảo nội dung không bị che khuất
//       body: SafeArea(
//         // RefreshIndicator để người dùng có thể kéo xuống để làm mới
//         child: RefreshIndicator(
//           onRefresh: () async {
//             // Khi làm mới, tải lại cả dữ liệu dashboard và mục tiêu
//             await Future.wait([
//               context.read<DashboardProvider>().fetchHealthHistory(),
//               context.read<GoalsProvider>().loadDailyGoal(),
//             ]);
//           },
//           child: CustomScrollView(
//             // Sử dụng CustomScrollView với Slivers để có header "dính"
//             slivers: [
//               // Header tùy chỉnh của chúng ta
//               _buildSliverHeader(context, l10n, theme, authProvider),

//               // Nội dung chính, có thể cuộn
//               SliverToBoxAdapter(
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const SizedBox(height: 24),
//                       // "Hero" section - Card mục tiêu chính
//                       _MainGoalCard(),
//                       const SizedBox(height: 32),

//                       // Tiêu đề cho các chỉ số
//                       Text(l10n.realtimeMetricsTitle,
//                           style: theme.textTheme.titleLarge),
//                       const SizedBox(height: 16),

//                       // Card chỉ số thời gian thực (tạm thời giữ lại widget cũ)
//                       const RealtimeMetricsCard(),
//                       const SizedBox(height: 32),

//                       // Tiêu đề cho các biểu đồ
//                       Text(l10n.historyAndTrendsTitle,
//                           style: theme.textTheme.titleLarge),
//                       const SizedBox(height: 16),

//                       // Card Lịch sử Hoạt động
//                       // Widget mới này sẽ được thêm vào
//                       ActivitySummaryChartCard(),
//                       const SizedBox(height: 16),

//                       // Card Lịch sử Sức khỏe với các Tab
//                       _buildHistoryTabBarCard(l10n, theme),
//                       const SizedBox(height: 32), // Padding ở dưới cùng
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // --- HÀM BUILD HELPER CHO CÁC PHẦN GIAO DIỆN MỚI ---

//   // Xây dựng Header tùy chỉnh dính ở trên
//   SliverAppBar _buildSliverHeader(
//     BuildContext context,
//     AppLocalizations l10n,
//     ThemeData theme,
//     AuthProvider authProvider,
//   ) {
//     final String welcomeMessage;
//     final int currentHour = DateTime.now().hour;

//     if (currentHour < 12) {
//       welcomeMessage = l10n.greetingGoodMorning; // Key mới
//     } else if (currentHour < 18) {
//       welcomeMessage = l10n.greetingGoodAfternoon; // Key mới
//     } else {
//       welcomeMessage = l10n.greetingGoodEvening; // Key mới
//     }

//     final displayName = authProvider.preferredDisplayName ?? l10n.defaultUser;

//     return SliverAppBar(
//       // Các thuộc tính để AppBar "dính" lại khi cuộn
//       pinned: true,
//       floating: true,
//       snap: true,

//       // Nội dung của AppBar
//       backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
//       elevation: 0,
//       surfaceTintColor:
//           Colors.transparent, // Loại bỏ hiệu ứng đổ màu của Material 3
//       titleSpacing: 16.0,

//       // Cột chứa lời chào và tên
//       title: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(welcomeMessage,
//               style: theme.textTheme.bodyMedium?.copyWith(
//                 color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
//               )),
//           Text(displayName, style: theme.textTheme.titleLarge),
//         ],
//       ),
//       actions: [
//         // Avatar người dùng ở góc phải
//         Padding(
//           padding: const EdgeInsets.only(right: 16.0),
//           child: CircleAvatar(
//             radius: 20,
//             backgroundColor: theme.colorScheme.surface,
//             backgroundImage: authProvider.user?.photoURL != null
//                 ? NetworkImage(authProvider.user!.photoURL!)
//                 : null,
//             child: authProvider.user?.photoURL == null
//                 ? Text(
//                     displayName.isNotEmpty ? displayName[0].toUpperCase() : "?",
//                     style: TextStyle(
//                         color: theme.colorScheme.primary,
//                         fontWeight: FontWeight.bold),
//                   )
//                 : null,
//           ),
//         ),
//       ],
//     );
//   }

//   // Xây dựng Card chứa các Tab biểu đồ
//   Widget _buildHistoryTabBarCard(AppLocalizations l10n, ThemeData theme) {
//     return Card(
//       // Card này sẽ không có padding bên trong để TabBar và TabBarView có thể chiếm toàn bộ không gian
//       // và có style riêng
//       clipBehavior: Clip.antiAlias, // Cần thiết để các góc bo tròn hoạt động
//       child: Column(
//         children: [
//           // Phần TabBar tùy chỉnh
//           Container(
//             padding: const EdgeInsets.all(4.0),
//             margin: const EdgeInsets.all(8.0),
//             decoration: BoxDecoration(
//               color:
//                   theme.scaffoldBackgroundColor, // Màu nền hơi khác để nổi bật
//               borderRadius: BorderRadius.circular(12.0),
//             ),
//             child: TabBar(
//               controller: _tabController,
//               labelColor: theme.colorScheme.onSurface,
//               unselectedLabelColor:
//                   theme.colorScheme.onSurface.withOpacity(0.6),
//               labelStyle: const TextStyle(fontWeight: FontWeight.w600),
//               unselectedLabelStyle:
//                   const TextStyle(fontWeight: FontWeight.w500),
//               // Indicator là một hình chữ nhật bo tròn có màu nhấn
//               indicator: BoxDecoration(
//                 borderRadius: BorderRadius.circular(10.0),
//                 color: theme.colorScheme.surface,
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.1),
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               indicatorSize:
//                   TabBarIndicatorSize.tab, // Indicator chiếm hết chiều rộng tab
//               dividerColor: Colors.transparent, // Bỏ đường gạch mặc định
//               tabs: [
//                 Tab(text: l10n.hrTabTitle), // Key mới
//                 Tab(text: l10n.spo2TabTitle), // Key mới
//                 Tab(text: l10n.stepsTabTitle), // Key mới
//               ],
//             ),
//           ),

//           // Phần chứa nội dung các biểu đồ
//           SizedBox(
//             height: 250, // Chiều cao cố định cho các biểu đồ
//             child: TabBarView(
//               controller: _tabController,
//               children: [
//                 // Các widget biểu đồ cũ của bạn sẽ được đặt ở đây
//                 Padding(
//                   padding:
//                       const EdgeInsets.only(right: 16, top: 16, bottom: 12),
//                   child: HistoryChartCard(), // Biểu đồ nhịp tim
//                 ),
//                 Padding(
//                   padding:
//                       const EdgeInsets.only(right: 16, top: 16, bottom: 12),
//                   child: Spo2HistoryChartCard(), // Biểu đồ SpO2
//                 ),
//                 Padding(
//                   padding:
//                       const EdgeInsets.only(right: 16, top: 16, bottom: 12),
//                   child: StepsHistoryChartCard(), // Biểu đồ Bước chân
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
// // lib/screens/core/dashboard_screen.dart

// // ... code của class DashboardScreen và _DashboardScreenState ở trên ...

// // <<< BẮT ĐẦU PHẦN 2: CÁC WIDGET CON MỚI >>>

// // --- WIDGET: CARD MỤC TIÊU CHÍNH ---
// // Widget này sẽ hiển thị vòng tròn tiến độ mục tiêu số bước.
// class _MainGoalCard extends StatelessWidget {
//   const _MainGoalCard({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     // Lắng nghe cả hai provider cần thiết: GoalsProvider và DashboardProvider
//     final goalsProvider = context.watch<GoalsProvider>();
//     final dashboardProvider = context.watch<DashboardProvider>();
//     final l10n = AppLocalizations.of(context)!;
//     final theme = Theme.of(context);

//     // Lấy các giá trị cần thiết
//     final currentSteps = dashboardProvider.todayTotalSteps;
//     final currentGoal = goalsProvider.currentStepGoal;

//     // Xử lý trường hợp goal là 0 để tránh lỗi chia cho 0
//     final double percent =
//         (currentGoal > 0) ? (currentSteps / currentGoal).clamp(0.0, 1.0) : 0.0;

//     final bool goalAchieved = percent >= 1.0;

//     return GestureDetector(
//       onTap: () {
//         // Điều hướng đến màn hình Mục tiêu khi nhấn vào card này
//         // Sử dụng GlobalKey hoặc tìm kiếm MainNavigatorState như code cũ của bạn
//         try {
//           final mainNavigatorState =
//               context.findAncestorStateOfType<MainNavigatorState>();
//           mainNavigatorState?.navigateTo(AppConstants.goalsScreenIndex);
//         } catch (e) {
//           print("Error navigating to GoalsScreen from _MainGoalCard: $e");
//         }
//       },
//       child: Card(
//         // Card này sẽ tự lấy style từ AppTheme, chúng ta có thể tùy chỉnh thêm nếu cần
//         elevation: 4.0, // Tăng độ nổi bật một chút
//         child: Padding(
//           padding: const EdgeInsets.all(20.0),
//           child: Row(
//             children: [
//               // Vòng tròn tiến độ ở bên trái
//               SizedBox(
//                 width: 110,
//                 height: 110,
//                 child: CircularProgressIndicator(
//                   // << Thay bằng CircularProgressIndicator cho hiệu ứng đẹp hơn
//                   value: percent,
//                   strokeWidth: 12,
//                   backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
//                   valueColor: AlwaysStoppedAnimation<Color>(
//                     goalAchieved ? Colors.green : theme.colorScheme.primary,
//                   ),
//                   strokeCap: StrokeCap.round,
//                 ),
//               ),

//               const SizedBox(width: 20),

//               // Thông tin văn bản ở bên phải
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       l10n.mainGoalTitle, // Key mới: "Hôm nay"
//                       style: theme.textTheme.titleMedium?.copyWith(
//                           color: theme.textTheme.titleMedium?.color
//                               ?.withOpacity(0.8)),
//                     ),
//                     const SizedBox(height: 4),

//                     // Hiển thị số bước hiện tại với style lớn, nổi bật
//                     Text(
//                       NumberFormat.decimalPattern().format(currentSteps),
//                       style: theme.textTheme.headlineSmall?.copyWith(
//                           fontWeight: FontWeight.bold,
//                           color: theme.colorScheme.primary),
//                     ),

//                     const SizedBox(height: 4),

//                     // Hiển thị mục tiêu và số bước còn lại
//                     Text(
//                       goalAchieved
//                           ? l10n.goalAchievedMessage // Dùng lại key cũ
//                           : l10n.stepsOutOfGoal(NumberFormat.decimalPattern()
//                               .format(currentGoal)), // Key mới: "/ {goal} bước"
//                       style: theme.textTheme.bodyMedium?.copyWith(
//                           color: theme.textTheme.bodyMedium?.color
//                               ?.withOpacity(0.7)),
//                     ),
//                   ],
//                 ),
//               ),
//               // Icon mũi tên để gợi ý có thể nhấn vào
//               Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 size: 16,
//                 color: theme.colorScheme.primary.withOpacity(0.5),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

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

  @override
  void initState() {
    super.initState();
    // Khởi tạo TabController cho các biểu đồ
    _tabController = TabController(length: 3, vsync: this);

    // Đăng ký observer để lắng nghe vòng đời ứng dụng
    WidgetsBinding.instance.addObserver(this);

    // Lên lịch tải dữ liệu ban đầu ngay sau khi frame đầu tiên được vẽ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialDataFetch();
    });
  }

  /// Hàm để tải dữ liệu ban đầu một cách tập trung
  void _initialDataFetch() {
    if (!mounted) return; // Luôn kiểm tra mounted trước khi dùng context
    // Không lắng nghe (listen: false) vì chúng ta không muốn rebuild khi gọi hàm này
    Provider.of<DashboardProvider>(context, listen: false).fetchHealthHistory();
    Provider.of<GoalsProvider>(context, listen: false).loadDailyGoal();
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

  // ================================================================
  // --- HÀM BUILD CHÍNH VÀ CÁC HÀM HELPER BUILD UI ---
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

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
              _buildSliverHeader(context, l10n, theme, authProvider),

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
          Text(welcomeMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              )),
          Text(displayName, style: theme.textTheme.titleLarge),
        ],
      ),
      actions: [
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
