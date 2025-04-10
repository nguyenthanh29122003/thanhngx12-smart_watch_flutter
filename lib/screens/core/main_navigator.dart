// lib/screens/core/main_navigator.dart
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'relatives_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0; // Index của tab đang được chọn

  // Danh sách các màn hình tương ứng với các tab
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    RelativesScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  // Hàm được gọi khi người dùng nhấn vào một tab
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    print(
      "MainNavigator build triggered. SelectedIndex: $_selectedIndex",
    ); // Debug log
    return Scaffold(
      // Hiển thị màn hình tương ứng với index đang được chọn
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      // Thanh điều hướng dưới cùng
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard), // Icon khi được chọn
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Relatives',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flag_outlined),
            activeIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex, // Tab hiện tại đang được chọn
        selectedItemColor:
            Theme.of(context).primaryColor, // Màu của tab được chọn
        unselectedItemColor: Colors.grey, // Màu của các tab không được chọn
        onTap: _onItemTapped, // Hàm xử lý khi nhấn tab
        type:
            BottomNavigationBarType
                .fixed, // Giữ cố định các tab (quan trọng khi có > 3 tab)
        // showSelectedLabels: false, // Tùy chọn: Ẩn label khi được chọn
        // showUnselectedLabels: false, // Tùy chọn: Ẩn label khi không được chọn
      ),
    );
  }
}
