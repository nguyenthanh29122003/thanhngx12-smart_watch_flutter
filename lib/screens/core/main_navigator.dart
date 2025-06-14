// lib/screens/core/main_navigator.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

// Imports của dự án
import '../../generated/app_localizations.dart';
import '../core/dashboard_screen.dart';
import '../core/relatives_screen.dart';
import '../core/goals_screen.dart';
import '../core/settings_screen.dart';
import 'chatbot_screen.dart';
import '../debug/record_activity_screen.dart';
import 'activity_history_screen.dart';

// Đây là phiên bản đã được nâng cấp và rà soát đầy đủ
class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => MainNavigatorState();
}

class MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  // Giữ nguyên logic cốt lõi
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    RelativesScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateTo(int index) {
    if (index >= 0 &&
        index < _widgetOptions.length &&
        index != _selectedIndex) {
      _onItemTapped(index);
    }
  }

  // --- HÀM BUILD ĐƯỢC THIẾT KẾ LẠI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack giữ lại trạng thái của các trang
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // Thanh điều hướng và FAB đã được thiết kế lại
      bottomNavigationBar: _CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _ModernSpeedDial(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// --- WIDGET CON CHO SPEED DIAL ---
class _ModernSpeedDial extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDarkMode = theme.brightness == Brightness.dark;

    return SpeedDial(
      // Các thuộc tính cơ bản
      icon: Icons.add_rounded,
      activeIcon: Icons.close_rounded,
      spacing: 12,
      childMargin: const EdgeInsets.all(8.0),
      // childOffset: 10.0,

      // Style cho nút chính (lấy từ theme)
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      elevation: 6.0,

      // Style cho overlay
      overlayColor: isDarkMode ? Colors.white : Colors.black,
      overlayOpacity: 0.4,

      // Danh sách các hành động
      children: [
        _buildSpeedDialChild(
          context: context,
          icon: Icons.chat_bubble_outline_rounded,
          label: l10n.chatbotTitle,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const ChatbotScreen())),
        ),
        _buildSpeedDialChild(
          context: context,
          icon: Icons.history_edu_outlined,
          label: l10n.activityHistoryTitle,
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ActivityHistoryScreen())),
        ),
        _buildSpeedDialChild(
          context: context,
          icon: Icons.bluetooth_searching_rounded,
          label: l10n.changeForgetDevice, // Dùng key "Đổi/Quên thiết bị"
          onTap: () => Navigator.pushNamed(context, '/device_select'),
        ),
        // Nút debug chỉ hiển thị trong debug mode
        if (kDebugMode)
          _buildSpeedDialChild(
            context: context,
            icon: Icons.bug_report_outlined,
            label: l10n.recordActivityTitle,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordActivityScreen())),
            backgroundColor: Colors.deepPurple,
          ),
      ],
    );
  }

  // Hàm helper để tạo SpeedDialChild nhất quán
  SpeedDialChild _buildSpeedDialChild(
      {required BuildContext context,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? backgroundColor}) {
    final theme = Theme.of(context);
    return SpeedDialChild(
      child: Icon(icon),
      label: label,
      labelStyle: theme.textTheme.titleSmall,
      backgroundColor: backgroundColor ?? theme.colorScheme.secondary,
      foregroundColor: theme.colorScheme.onSecondary,
      onTap: onTap,
      shape: const CircleBorder(),
    );
  }
}

// --- WIDGET TÙY CHỈNH CHO BOTTOM NAVIGATION BAR ---
class _CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BottomAppBar(
      // Style thanh BottomAppBar
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 8.0,

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Nhóm nút trái
          Row(
            children: [
              _buildNavItem(context, icon: Icons.dashboard_rounded, index: 0),
              _buildNavItem(context, icon: Icons.people_rounded, index: 1),
            ],
          ),

          // Nhóm nút phải
          Row(
            children: [
              _buildNavItem(context, icon: Icons.flag_rounded, index: 2),
              _buildNavItem(context, icon: Icons.settings_rounded, index: 3),
            ],
          ),
        ],
      ),
    );
  }

  // Hàm helper xây dựng từng item
  Widget _buildNavItem(BuildContext context,
      {required IconData icon, required int index}) {
    final bool isSelected = currentIndex == index;
    final Color color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6);

    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(50), // Bo tròn để hiệu ứng đẹp
      child: SizedBox(
        width: MediaQuery.of(context).size.width / 5, // Chia đều không gian
        height: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Hiệu ứng dịch chuyển nhẹ khi được chọn
            AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              offset: isSelected ? const Offset(0, -0.2) : Offset.zero,
              child: Icon(icon, color: color, size: 26),
            ),

            // Chấm nhỏ chỉ báo item được chọn
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              width: isSelected ? 20 : 0,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
