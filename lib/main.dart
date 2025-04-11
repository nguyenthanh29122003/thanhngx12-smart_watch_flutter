// lib/main.dart
import 'dart:async'; // <<< THÊM Import cho StreamSubscription
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<< THÊM Import
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // <<< THÊM Import

// Import các file cấu hình và services
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'app_constants.dart'; // <<< THÊM Import AppConstants

// Import các Providers quản lý state
import 'providers/auth_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/dashboard_provider.dart'; // Import DashboardProvider

// Import các màn hình
import 'screens/core/main_navigator.dart'; // <<< IMPORT LẠI
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device/device_select_screen.dart';

import 'providers/relatives_provider.dart'; // <<< Import RelativesProvider
import 'providers/settings_provider.dart'; // <<< Import SettingsProvider

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        // --- 1. Cung cấp các Service cơ bản/Singleton ---
        Provider<LocalDbService>.value(value: LocalDbService.instance),
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),

        // --- 2. Cung cấp các Service/Provider phụ thuộc (Thứ tự quan trọng) ---
        Provider<BleService>(
          create:
              (context) => BleService(
                context.read<AuthService>(),
                context.read<FirestoreService>(),
                context.read<LocalDbService>(),
                context.read<ConnectivityService>(),
              ),
          dispose: (context, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create:
              (context) => AuthProvider(
                context.read<AuthService>(),
                context.read<FirestoreService>(),
              ),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create:
              (context) => DashboardProvider(
                context.read<FirestoreService>(),
                context.read<AuthService>(),
              ),
        ),
        Provider<DataSyncService>(
          create:
              (context) => DataSyncService(
                context.read<ConnectivityService>(),
                context.read<LocalDbService>(),
                context.read<FirestoreService>(),
                context.read<AuthService>(),
              ),
          dispose: (context, service) => service.dispose(),
          lazy: false, // Đảm bảo DataSyncService khởi tạo ngay
        ),
        // >>> THÊM RELATIVES PROVIDER <<<
        ChangeNotifierProvider<RelativesProvider>(
          create:
              (context) => RelativesProvider(
                context.read<FirestoreService>(),
                context.read<AuthService>(),
              ),
        ),
        // >>> THÊM SETTINGS PROVIDER <<<
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
          // SettingsProvider không cần dispose phức tạp
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// --- MyApp ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return MaterialApp(
      title: 'Smart Wearable App',
      theme: ThemeData(
        // Theme sáng
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // ... các tùy chỉnh khác cho theme sáng ...
        useMaterial3: true, // <<< Bật Material 3
      ),
      darkTheme: ThemeData(
        // Theme tối
        brightness: Brightness.dark,
        primarySwatch: Colors.teal, // Có thể dùng colorScheme thay thế
        // <<< Dùng colorScheme cho Material 3 >>>
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal, // Màu gốc
          brightness: Brightness.dark, // Chỉ định là theme tối
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        // ... các tùy chỉnh khác cho theme tối ...
        useMaterial3: true, // <<< Bật Material 3
      ),
      // <<< SỬ DỤNG THEME MODE TỪ PROVIDER >>>
      themeMode: settingsProvider.themeMode, // Lấy từ state của provider
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
    );
  }
}

// --- AuthWrapper (StatefulWidget để xử lý logic khởi tạo) ---
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String _deviceCheckStatus = 'initial';
  // StreamSubscription? _bleConnectionSub; // <<< KHÔNG DÙNG StreamSubscription cho ValueNotifier
  VoidCallback? _bleStatusListener; // <<< Dùng VoidCallback để lưu hàm listener
  bool _isMounted = false;
  bool _checkingDevice = false; // Cờ tránh gọi _checkSavedDevice nhiều lần

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        authProvider.addListener(_handleAuthChange);
        if (authProvider.status == AuthStatus.authenticated) {
          // Chỉ bắt đầu kiểm tra nếu chưa kiểm tra
          if (!_checkingDevice && _deviceCheckStatus == 'initial') {
            _checkSavedDeviceAndConnect();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    try {
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).removeListener(_handleAuthChange);
    } catch (e) {
      print("[AuthWrapper] Error removing auth listener: $e");
    }
    // Hủy listener của ValueNotifier nếu đã tạo
    if (_bleStatusListener != null) {
      try {
        Provider.of<BleProvider>(
          context,
          listen: false,
        ).connectionStatus.removeListener(_bleStatusListener!);
      } catch (e) {
        print("[AuthWrapper] Error removing BLE listener: $e");
      }
    }
    super.dispose();
  }

  void _handleAuthChange() {
    if (!_isMounted) return;
    final authStatus = Provider.of<AuthProvider>(context, listen: false).status;
    print("[AuthWrapper] Auth status changed to: $authStatus");

    if (authStatus == AuthStatus.authenticated &&
        !_checkingDevice &&
        _deviceCheckStatus == 'initial') {
      _checkSavedDeviceAndConnect();
    } else if (authStatus != AuthStatus.authenticated) {
      if (mounted)
        setState(() {
          _deviceCheckStatus = 'initial';
        });
      // Hủy listener BLE cũ nếu có
      if (_bleStatusListener != null) {
        try {
          Provider.of<BleProvider>(
            context,
            listen: false,
          ).connectionStatus.removeListener(_bleStatusListener!);
          _bleStatusListener = null;
        } catch (e) {
          print("[AuthWrapper] Error removing BLE listener on auth change: $e");
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!_isMounted || _checkingDevice) return; // Tránh chạy nhiều lần

    print("[AuthWrapper] Checking saved device ID...");
    _checkingDevice = true; // Đánh dấu đang kiểm tra
    if (mounted)
      setState(() {
        _deviceCheckStatus = 'checking';
      });

    SharedPreferences prefs;
    String? savedDeviceId;
    try {
      prefs = await SharedPreferences.getInstance();
      savedDeviceId = prefs.getString(AppConstants.prefKeyConnectedDeviceId);
    } catch (e) {
      print("!!! [AuthWrapper] Error reading SharedPreferences: $e");
      if (_isMounted)
        setState(() {
          _deviceCheckStatus = 'no_device';
        });
      _checkingDevice = false; // Reset cờ
      return;
    }

    if (!_isMounted) {
      _checkingDevice = false;
      return;
    }

    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      print(
        "[AuthWrapper] Found saved device ID: $savedDeviceId. Attempting auto-connect...",
      );
      if (mounted)
        setState(() {
          _deviceCheckStatus = 'connecting';
        });

      final bleProvider = Provider.of<BleProvider>(context, listen: false);

      // --- SỬA LẠI PHẦN LẮNG NGHE ---
      // Hủy listener cũ nếu có
      if (_bleStatusListener != null) {
        try {
          bleProvider.connectionStatus.removeListener(_bleStatusListener!);
        } catch (e) {
          print("Error removing old BLE listener: $e");
        }
      }

      // Tạo hàm listener mới
      _bleStatusListener = () {
        if (!_isMounted) {
          // Kiểm tra trong listener
          if (_bleStatusListener != null) {
            try {
              bleProvider.connectionStatus.removeListener(_bleStatusListener!);
            } catch (e) {}
            _bleStatusListener = null;
          }
          return;
        }
        final status = bleProvider.connectionStatus.value;
        print("[AuthWrapper] Auto-connect listener received status: $status");

        // Chỉ xử lý khi đang ở trạng thái 'connecting' (tránh xử lý thừa)
        if (_deviceCheckStatus == 'connecting') {
          if (status == BleConnectionStatus.connected) {
            print("[AuthWrapper] Auto-connect successful!");
            if (_isMounted)
              setState(() {
                _deviceCheckStatus = 'connected';
              });
            // Hủy listener sau khi thành công
            if (_bleStatusListener != null) {
              try {
                bleProvider.connectionStatus.removeListener(
                  _bleStatusListener!,
                );
              } catch (e) {}
              _bleStatusListener = null;
            }
          } else if (status == BleConnectionStatus.error ||
              status == BleConnectionStatus.disconnected) {
            print("[AuthWrapper] Auto-connect failed (status: $status).");
            prefs.remove(AppConstants.prefKeyConnectedDeviceId);
            if (_isMounted)
              setState(() {
                _deviceCheckStatus = 'failed';
              });
            // Hủy listener sau khi thất bại
            if (_bleStatusListener != null) {
              try {
                bleProvider.connectionStatus.removeListener(
                  _bleStatusListener!,
                );
              } catch (e) {}
              _bleStatusListener = null;
            }
          }
        } else {
          // Trạng thái khác -> Hủy listener
          if (_bleStatusListener != null) {
            try {
              bleProvider.connectionStatus.removeListener(_bleStatusListener!);
            } catch (e) {}
            _bleStatusListener = null;
          }
        }
      };

      // Đăng ký listener mới
      try {
        bleProvider.connectionStatus.addListener(_bleStatusListener!);
      } catch (e) {
        print("Error adding BLE listener: $e");
        if (_isMounted)
          setState(() {
            _deviceCheckStatus = 'failed';
          });
        _checkingDevice = false;
        return;
      }
      // -----------------------------

      // Thực hiện kết nối (giữ nguyên)
      try {
        List<BluetoothDevice> systemConnected =
            FlutterBluePlus.connectedDevices;
        BluetoothDevice? targetDevice;
        final targetDeviceId = DeviceIdentifier(savedDeviceId);
        try {
          targetDevice = systemConnected.firstWhere(
            (d) => d.remoteId == targetDeviceId,
          );
        } catch (e) {
          targetDevice = null;
        }
        targetDevice ??= BluetoothDevice(remoteId: targetDeviceId);

        print("[AuthWrapper] Calling connectToDevice for $savedDeviceId");
        await bleProvider.connectToDevice(targetDevice);
      } catch (e) {
        print("!!! [AuthWrapper] Error initiating auto-connect: $e");
        prefs.remove(AppConstants.prefKeyConnectedDeviceId);
        if (_isMounted)
          setState(() {
            _deviceCheckStatus = 'failed';
          });
        if (_bleStatusListener != null) {
          // Hủy listener nếu có lỗi ngay khi gọi connect
          try {
            bleProvider.connectionStatus.removeListener(_bleStatusListener!);
          } catch (e) {}
          _bleStatusListener = null;
        }
      }
    } else {
      print("[AuthWrapper] No saved device ID found.");
      if (_isMounted)
        setState(() {
          _deviceCheckStatus = 'no_device';
        });
    }
    _checkingDevice = false; // Reset cờ sau khi hoàn tất kiểm tra
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    print(
      "[AuthWrapper] build. Auth: ${authProvider.status}, DeviceCheck: $_deviceCheckStatus",
    );

    Widget nextScreen = const SplashScreen();

    switch (authProvider.status) {
      case AuthStatus.uninitialized:
      case AuthStatus.authenticating: // <<< THÊM TRƯỜNG HỢP NÀY
        nextScreen = const SplashScreen();
        break;
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        nextScreen = const LoginScreen();
        break;
      case AuthStatus.authenticated:
        switch (_deviceCheckStatus) {
          case 'initial':
          case 'checking':
          case 'connecting':
            nextScreen = const SplashScreen();
            break;
          case 'connected':
            nextScreen = const MainNavigator();
            break;
          case 'no_device':
          case 'failed':
            // default: // <<< XÓA DEFAULT CASE NÀY
            nextScreen = const DeviceSelectScreen();
            break;
        }
        break;
      // Không cần default ở ngoài vì đã xử lý hết AuthStatus
    }
    return nextScreen;
  }
}
