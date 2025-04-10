// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        // Hiển thị một vòng tròn loading đơn giản
        child: CircularProgressIndicator(),
      ),
    );
  }
}
