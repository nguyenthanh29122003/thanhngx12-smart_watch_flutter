// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // Import Provider

import 'firebase_options.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'services/firestore_service.dart'; // Import FirestoreService
import 'providers/auth_provider.dart'; // Import AuthProvider
import 'screens/core/main_navigator.dart'; // Màn hình chính sau khi đăng nhập (sẽ tạo sau)
import 'screens/auth/login_screen.dart'; // Màn hình đăng nhập (sẽ tạo sau)
import 'screens/splash_screen.dart'; // Màn hình chờ (sẽ tạo sau)
import 'screens/device/device_select_screen.dart'; // Màn hình chờ (sẽ tạo sau)

import 'services/ble_service.dart'; // Import BleService
import 'providers/ble_provider.dart'; // Import BleProvider

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Tạo instance BleService ở đây để quản lý vòng đời của nó
  final bleService = BleService();

  runApp(
    MultiProvider(
      providers: [
        // 1. Cung cấp các Service cơ bản
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        // Cung cấp instance BleService đã tạo
        Provider<BleService>.value(
          value: bleService,
        ), // Sử dụng .value để cung cấp instance có sẵn
        // 2. Cung cấp các ChangeNotifierProvider
        ChangeNotifierProvider<AuthProvider>(
          create:
              (context) => AuthProvider(
                context.read<AuthService>(),
                context.read<FirestoreService>(),
              ),
        ),
        // Cung cấp BleProvider, phụ thuộc vào BleService
        ChangeNotifierProvider<BleProvider>(
          create:
              (context) => BleProvider(
                context.read<BleService>(), // Lấy BleService đã cung cấp
              ),
        ),

        // --- Thêm các Provider khác ở đây nếu cần ---
      ],
      // QUAN TRỌNG: Sử dụng Consumer hoặc Builder để gọi dispose cho BleService khi app đóng
      child: Builder(
        builder: (context) {
          // Lắng nghe AppLifecycleState để gọi dispose khi app không còn dùng
          // Cách này không hoàn hảo 100% nhưng là một giải pháp
          return LifecycleWatcher(
            onDispose: () {
              print(
                "App lifecycle reached detached state, disposing BleService.",
              );
              bleService.dispose(); // Gọi dispose cho BleService
            },
            child: const MyApp(), // Widget gốc của ứng dụng
          );
        },
      ),
    ),
  );
}

// Widget helper để theo dõi lifecycle (đặt ở cuối file main.dart hoặc file riêng)
class LifecycleWatcher extends StatefulWidget {
  final Widget child;
  final VoidCallback onDispose;

  const LifecycleWatcher({
    super.key,
    required this.child,
    required this.onDispose,
  });

  @override
  _LifecycleWatcherState createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      // Gọi callback khi app chuẩn bị bị hủy hoàn toàn
      widget.onDispose();
    }
    print('App Lifecycle State: $state');
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Wearable App',
      theme: ThemeData(
        // Theme sáng mặc định
        brightness: Brightness.light,
        primarySwatch: Colors.teal, // Đổi màu chủ đạo
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        // Theme tối
        brightness: Brightness.dark,
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // Thêm các tùy chỉnh khác cho theme tối nếu muốn
      ),
      themeMode:
          ThemeMode.system, // Mặc định theo hệ thống, có thể thay đổi sau
      //home: const MyHomePage(title: 'Flutter Demo Home Page'), // Không dùng màn hình demo nữa

      // Sử dụng AuthWrapper để quyết định hiển thị màn hình nào
      home: const AuthWrapper(),
    );
  }
}

// Widget để quyết định hiển thị Login hay MainNavigator dựa vào trạng thái Auth
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe trạng thái từ AuthProvider
    final authProvider = context.watch<AuthProvider>();

    print(
      "AuthWrapper build triggered. Status: ${authProvider.status}",
    ); // Debug log

    // Dựa vào trạng thái để quyết định màn hình
    switch (authProvider.status) {
      case AuthStatus.uninitialized:
      case AuthStatus.authenticating:
        // Hiển thị màn hình chờ khi đang kiểm tra hoặc đang đăng nhập
        return const SplashScreen(); // (Sẽ tạo SplashScreen sau)
      case AuthStatus.authenticated:
        // Nếu đã đăng nhập, chuyển đến màn hình chính
        // return const MainNavigator(); // (Sẽ tạo MainNavigator sau)
        return const DeviceSelectScreen(); // Luôn đi đến đây để test
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
      default:
        // Nếu chưa đăng nhập hoặc có lỗi, hiển thị màn hình đăng nhập
        return const LoginScreen(); // (Sẽ tạo LoginScreen sau)
    }
  }
}
