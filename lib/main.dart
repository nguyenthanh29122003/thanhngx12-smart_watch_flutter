import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'app_constants.dart';
import 'generated/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/ble_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/relatives_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/core/main_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device/device_select_screen.dart';
import 'services/notification_service.dart'; // <<< THÊM IMPORT NÀY

final GlobalKey<MainNavigatorState> mainNavigatorKey =
    GlobalKey<MainNavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('Firebase initialization timed out');
    });
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  // --- KHỞI TẠO NOTIFICATION SERVICE --- // <<< THÊM VÀO ĐÂY
  try {
    // Lấy instance singleton và gọi init (init sẽ tự động gọi requestPermissions)
    await NotificationService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      print("!!! Warning: Notification Service initialization timed out.");
      // Có thể tiếp tục chạy app hoặc báo lỗi tùy mức độ quan trọng
    });
    print("[Main] Notification Service initialized (or timeout reached).");
  } catch (e) {
    print("!!! Error initializing Notification Service: $e");
    // Xử lý lỗi nếu cần
  }
  // ------------------------------------

  try {
    await dotenv.load(fileName: '.env');
    print('Loaded .env successfully: ${dotenv.env['OPENROUTER_API_KEY']}');
  } catch (e) {
    print('Error loading .env: $e');
    print(
        'Please ensure .env file exists in project root with OPENROUTER_API_KEY.');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalDbService>.value(value: LocalDbService.instance),
        Provider<NotificationService>.value(value: NotificationService()),
        Provider<ConnectivityService>(
            create: (_) => ConnectivityService(),
            dispose: (_, s) => s.dispose()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider()),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
              context.read<AuthService>(), context.read<FirestoreService>()),
        ),
        Provider<BleService>(
          create: (context) => BleService(
            context.read<AuthService>(),
            context.read<FirestoreService>(),
            context.read<LocalDbService>(),
            context.read<ConnectivityService>(),
            // <<< TRUYỀN NOTIFICATION SERVICE VÀO BLESERVICE >>>
            context.read<NotificationService>(),
          ),
          dispose: (context, s) => s.dispose(),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
              context.read<FirestoreService>(), context.read<AuthService>()),
        ),
        ChangeNotifierProvider<RelativesProvider>(
          create: (context) => RelativesProvider(
              context.read<FirestoreService>(), context.read<AuthService>()),
        ),
        Provider<DataSyncService>(
          create: (context) => DataSyncService(
              context.read<ConnectivityService>(),
              context.read<LocalDbService>(),
              context.read<FirestoreService>(),
              context.read<AuthService>()),
          dispose: (context, s) => s.dispose(),
          lazy: true,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'Smart Wearable App',
      locale: settingsProvider.appLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal, brightness: Brightness.dark),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      themeMode: settingsProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const AuthWrapper(),
      routes: {
        '/device_select': (context) => const DeviceSelectScreen(),
        '/main': (context) => const MainNavigator(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String _deviceCheckStatus = 'initial';
  VoidCallback? _bleStatusListener;
  bool _isMounted = false;
  bool _checkingDevice = false;
  BleProvider? _bleProviderRef;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        final ap = Provider.of<AuthProvider>(context, listen: false);
        _bleProviderRef = Provider.of<BleProvider>(context, listen: false);
        ap.addListener(_handleAuthChange);
        if (ap.status == AuthStatus.authenticated) {
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
      Provider.of<AuthProvider>(context, listen: false)
          .removeListener(_handleAuthChange);
    } catch (e) {
      print('Error removing auth listener: $e');
    }
    if (_bleStatusListener != null && _bleProviderRef != null) {
      try {
        _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
      } catch (e) {
        print('Error removing BLE listener: $e');
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
      if (mounted) setState(() => _deviceCheckStatus = 'initial');
      if (_bleStatusListener != null && _bleProviderRef != null) {
        try {
          _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
          _bleStatusListener = null;
        } catch (e) {
          print('Error removing BLE listener: $e');
        }
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!_isMounted || _checkingDevice) return;
    _checkingDevice = true;
    if (mounted) setState(() => _deviceCheckStatus = 'checking');
    print("[AuthWrapper] Checking saved device ID...");

    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('SharedPreferences timeout');
      });
      final savedDeviceId =
          prefs.getString(AppConstants.prefKeyConnectedDeviceId);

      if (!_isMounted) {
        _checkingDevice = false;
        return;
      }

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        print(
            "[AuthWrapper] Found saved ID: $savedDeviceId. Trying auto-connect...");
        if (mounted) setState(() => _deviceCheckStatus = 'connecting');
        if (_bleProviderRef == null && mounted) {
          _bleProviderRef = Provider.of<BleProvider>(context, listen: false);
        }
        if (_bleProviderRef == null) {
          if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
          _checkingDevice = false;
          return;
        }

        if (_bleStatusListener != null) {
          try {
            _bleProviderRef!.connectionStatus
                .removeListener(_bleStatusListener!);
          } catch (e) {
            print('Error removing BLE listener: $e');
          }
        }

        _bleStatusListener = () {
          if (!_isMounted || _bleProviderRef == null) {
            _bleStatusListener = null;
            return;
          }
          final status = _bleProviderRef!.connectionStatus.value;
          print("[AuthWrapper] Auto-connect listener status: $status");
          if (_deviceCheckStatus == 'connecting') {
            if (status == BleConnectionStatus.connected) {
              if (_isMounted) setState(() => _deviceCheckStatus = 'connected');
              if (_bleStatusListener != null) {
                try {
                  _bleProviderRef!.connectionStatus
                      .removeListener(_bleStatusListener!);
                } catch (e) {
                  print('Error removing BLE listener: $e');
                }
                _bleStatusListener = null;
              }
            } else if (status == BleConnectionStatus.error ||
                status == BleConnectionStatus.disconnected) {
              prefs.remove(AppConstants.prefKeyConnectedDeviceId);
              if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
              if (_bleStatusListener != null) {
                try {
                  _bleProviderRef!.connectionStatus
                      .removeListener(_bleStatusListener!);
                } catch (e) {
                  print('Error removing BLE listener: $e');
                }
                _bleStatusListener = null;
              }
            }
          }
        };

        try {
          _bleProviderRef!.connectionStatus.addListener(_bleStatusListener!);
        } catch (e) {
          print("Error adding listener: $e");
          if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
          _checkingDevice = false;
          return;
        }

        try {
          // Sửa lỗi timeout: Áp dụng trên Future
          List<BluetoothDevice> systemConnected =
              FlutterBluePlus.connectedDevices;

          BluetoothDevice? targetDevice;
          final targetDeviceId = DeviceIdentifier(savedDeviceId);
          try {
            targetDevice = systemConnected.firstWhere(
                (d) => d.remoteId == targetDeviceId,
                orElse: () => BluetoothDevice(remoteId: targetDeviceId));
          } catch (e) {
            targetDevice = BluetoothDevice(remoteId: targetDeviceId);
          }

          print("[AuthWrapper] Calling connectToDevice for $savedDeviceId");
          await _bleProviderRef!
              .connectToDevice(targetDevice)
              .timeout(const Duration(seconds: 10), onTimeout: () {
            throw TimeoutException('BLE connection timeout');
          });
        } catch (e) {
          print("!!! Error initiating auto-connect: $e");
          await prefs.remove(AppConstants.prefKeyConnectedDeviceId);
          if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
          if (_bleStatusListener != null) {
            try {
              _bleProviderRef!.connectionStatus
                  .removeListener(_bleStatusListener!);
            } catch (e) {
              print('Error removing BLE listener: $e');
            }
            _bleStatusListener = null;
          }
          _checkingDevice = false;
          return;
        }
      } else {
        print("[AuthWrapper] No saved device ID found.");
        if (_isMounted) setState(() => _deviceCheckStatus = 'no_device');
      }
    } catch (e) {
      print("!!! Error in checkSavedDeviceAndConnect: $e");
      if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
      _checkingDevice = false;
    }
    _checkingDevice = false;
  }

  // @override
  // Widget build(BuildContext context) {
  //   final authProvider = context.watch<AuthProvider>();
  //   print(
  //       "[AuthWrapper] build. Auth: ${authProvider.status}, DeviceCheck: $_deviceCheckStatus");

  //   // Timeout cho uninitialized
  //   if (authProvider.status == AuthStatus.uninitialized) {
  //     Future.delayed(const Duration(seconds: 10), () {
  //       if (mounted && authProvider.status == AuthStatus.uninitialized) {
  //         print(
  //             "[AuthWrapper] Auth uninitialized timeout, forcing unauthenticated");
  //         authProvider.forceUnauthenticated();
  //       }
  //     });
  //   }

  //   Widget nextScreen = const SplashScreen();
  //   switch (authProvider.status) {
  //     case AuthStatus.uninitialized:
  //     case AuthStatus.authenticating:
  //       nextScreen = const SplashScreen();
  //       break;
  //     case AuthStatus.unauthenticated:
  //     case AuthStatus.error:
  //       nextScreen = const LoginScreen();
  //       break;
  //     case AuthStatus.authenticated:
  //       switch (_deviceCheckStatus) {
  //         case 'initial':
  //         case 'checking':
  //         case 'connecting':
  //           // Timeout cho BLE
  //           Future.delayed(const Duration(seconds: 15), () {
  //             if (mounted &&
  //                 _deviceCheckStatus != 'connected' &&
  //                 _deviceCheckStatus != 'no_device' &&
  //                 _deviceCheckStatus != 'failed') {
  //               print("[AuthWrapper] BLE check timeout, setting to failed");
  //               setState(() => _deviceCheckStatus = 'failed');
  //             }
  //           });
  //           nextScreen = const SplashScreen();
  //           break;
  //         case 'connected':
  //           nextScreen = const MainNavigator();
  //           break;
  //         case 'no_device':
  //         case 'failed':
  //         default:
  //           // nextScreen = const DeviceSelectScreen();
  //           nextScreen = const DashboardScreen();
  //           break;
  //       }
  //       break;
  //   }
  //   return nextScreen;
  // }
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    print(
        "[AuthWrapper] build. Auth: ${authProvider.status}, DeviceCheck: $_deviceCheckStatus");
    Widget nextScreen = const SplashScreen();
    switch (authProvider.status) {
      case AuthStatus.uninitialized:
      case AuthStatus.authenticating:
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
          default:
            // nextScreen = const DashboardScreen();
            nextScreen = const MainNavigator();
            break;
        }
        break;
    }
    return nextScreen;
  }
}
