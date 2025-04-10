// lib/screens/core/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Cần để logout
import '../../providers/auth_provider.dart'; // Cần để logout

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin user từ AuthProvider (ví dụ)
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        // Dùng ListView để dễ thêm cài đặt sau
        padding: const EdgeInsets.all(16.0),
        children: [
          if (user != null) ...[
            ListTile(
              leading: CircleAvatar(
                // Hiển thị ảnh user nếu có, hoặc icon mặc định
                backgroundImage:
                    user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child: user.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.displayName ?? 'No Name'),
              subtitle: Text(user.email ?? 'No Email'),
            ),
            const Divider(),
          ],

          // TODO: Thêm các cài đặt khác ở đây (Ngôn ngữ, Theme, Thiết bị, Thông báo)
          const SizedBox(height: 30),
          // Nút Logout
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: () async {
              // Gọi hàm signOut từ AuthProvider
              await context.read<AuthProvider>().signOut();
              // AuthWrapper sẽ tự động xử lý điều hướng về LoginScreen
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
