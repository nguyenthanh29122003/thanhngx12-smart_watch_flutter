// lib/screens/core/main_navigator.dart
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import '../../generated/app_localizations.dart';
import '../core/dashboard_screen.dart';
import '../core/relatives_screen.dart';
import '../core/goals_screen.dart';
import '../core/settings_screen.dart';
import 'chatbot_screen.dart';
import '../debug/record_activity_screen.dart'; // <<< THÊM IMPORT NÀY

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => MainNavigatorState();
}

class MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    RelativesScreen(),
    GoalsScreen(),
    SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void navigateTo(int index) {
    print("[MainNavigator] navigateTo called with index: $index");
    if (index >= 0 &&
        index < _widgetOptions.length &&
        index != _selectedIndex) {
      _onItemTapped(index);
    } else if (index == _selectedIndex) {
      print("[MainNavigator] Already on tab $index.");
    } else {
      print("[MainNavigator] Invalid index $index for navigation.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      "MainNavigator build triggered. SelectedIndex: $_selectedIndex",
    );
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: l10n.dashboardTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: l10n.relativesTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.flag_outlined),
            activeIcon: const Icon(Icons.flag),
            label: l10n.goalsTitle,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: l10n.settingsTitle,
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.chat),
            label: AppLocalizations.of(context)!.chatbotTitle,
            backgroundColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.analytics),
            label: AppLocalizations.of(context)!.predictTitle,
            backgroundColor: Colors.green,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                // Sử dụng key dịch thuật nếu có, ví dụ l10n.predictPlaceholder
                const SnackBar(
                    content: Text('Prediction functionality coming soon!')),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(
                Icons.bluetooth_searching_outlined), // Thay đổi icon một chút
            label: AppLocalizations.of(context)!
                .connectDevice, // Giả sử key này là "Connect / Change Device"
            backgroundColor: Colors.orange,
            onTap: () {
              Navigator.pushNamed(context, '/device_select');
            },
          ),
          // <<< THÊM SPEEDDIALCHILD CHO MÀN HÌNH RECORD >>>
          SpeedDialChild(
            child: const Icon(Icons.fiber_manual_record_outlined,
                color: Colors.white),
            label: l10n.recordActivityTitle, // Sử dụng key dịch thuật đã thêm
            backgroundColor: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const RecordActivityScreen()),
              );
            },
          ),
          // --------------------------------------------
        ],
      ),
    );
  }
}
