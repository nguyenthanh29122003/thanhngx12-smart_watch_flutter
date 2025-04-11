// lib/screens/core/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../config/wifi_config_screen.dart'; // <<< Import màn hình mới

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ... (Phần hiển thị thông tin user) ...
          const Divider(),

          // --- MỤC CẤU HÌNH WIFI ---
          ListTile(
            leading: const Icon(Icons.wifi_password),
            title: const Text('Configure Device WiFi'),
            subtitle: const Text('Send WiFi credentials to ESP32'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Điều hướng đến màn hình cấu hình WiFi
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WifiConfigScreen(),
                ),
              );
            },
          ),
          // -------------------------

          // TODO: Thêm các cài đặt khác (Ngôn ngữ, Theme, Thiết bị, Thông báo)
          const Divider(),

          // ... (Nút Logout) ...
        ],
      ),
    );
  }
}
