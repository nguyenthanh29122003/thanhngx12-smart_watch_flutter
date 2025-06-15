// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  // Thêm một tham số message, mặc định là chuỗi rỗng.
  final String message;

  const SplashScreen({
    super.key,
    this.message = '', // Mặc định là rỗng
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bạn có thể bỏ comment dòng này nếu có logo
            // const Image.asset('assets/images/app_logo.png', width: 100),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
                // Bạn có thể dùng màu từ theme nếu muốn
                // valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
            const SizedBox(height: 24), // Thêm khoảng cách

            // Chỉ hiển thị Text nếu message không rỗng
            if (message.isNotEmpty)
              Text(
                message,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
