// lib/screens/core/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart'; // Để lấy thông tin user

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin user từ AuthProvider
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        // Không cần nút back vì đây là màn hình gốc sau login
        automaticallyImplyLeading: false,
        actions: const [
          // IconButton( // Tạm thời bỏ nút logout ở đây, chuyển sang Settings
          //   icon: const Icon(Icons.logout),
          //   tooltip: 'Logout',
          //   onPressed: () async {
          //     await context.read<AuthProvider>().signOut();
          //   },
          // ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Smart Wearable!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (user != null) // Hiển thị email nếu user không null
              Text('Logged in as: ${user.email ?? 'Unknown Email'}'),
            const SizedBox(height: 30),
            const Text('Realtime Data & Charts will be here.'),
            // TODO: Thêm các Card hiển thị dữ liệu và biểu đồ
          ],
        ),
      ),
    );
  }
}
