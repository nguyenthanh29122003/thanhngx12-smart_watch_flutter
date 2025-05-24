// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart' as app_auth_service;
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'services/notification_service.dart';
import 'app_constants.dart';
import 'generated/app_localizations.dart';
import 'providers/auth_provider.dart' as app_auth_provider;
import 'providers/ble_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/relatives_provider.dart';
import 'providers/settings_provider.dart';
import 'services/activity_recognition_service.dart';
import 'screens/core/main_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device/device_select_screen.dart';

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
    debugPrint('Error initializing Firebase: $e');
  }

  try {
    await NotificationService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint("Warning: Notification Service initialization timed out.");
    });
    debugPrint("Notification Service initialized (or timeout reached).");
  } catch (e) {
    debugPrint("Error initializing Notification Service: $e");
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Error loading .env: $e');
    debugPrint(
        'Please ensure .env file exists in project root with OPENROUTER_API_KEY.');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<LocalDbService>.value(value: LocalDbService.instance),
        Provider<NotificationService>.value(value: NotificationService()),
        Provider<app_auth_service.AuthService>(
            create: (_) => app_auth_service.AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, s) => s.dispose(),
        ),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<app_auth_provider.AuthProvider>(
          create: (context) => app_auth_provider.AuthProvider(
            context.read<app_auth_service.AuthService>(),
            context.read<FirestoreService>(),
          ),
        ),
        Provider<BleService>(
          create: (context) => BleService(
            context.read<app_auth_service.AuthService>(),
            context.read<FirestoreService>(),
            context.read<LocalDbService>(),
            context.read<ConnectivityService>(),
            context.read<NotificationService>(),
          ),
          dispose: (context, service) => service.dispose(),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
            context.read<FirestoreService>(),
            context.read<app_auth_service.AuthService>(),
          ),
        ),
        ChangeNotifierProvider<RelativesProvider>(
          create: (context) => RelativesProvider(
            context.read<FirestoreService>(),
            context.read<app_auth_service.AuthService>(),
          ),
        ),
        Provider<ActivityRecognitionService>(
          create: (_) => ActivityRecognitionService(),
          dispose: (_, service) => service.dispose(),
        ),
        Provider<DataSyncService>(
          create: (context) => DataSyncService(
            context.read<ConnectivityService>(),
            context.read<LocalDbService>(),
            context.read<FirestoreService>(),
            context.read<app_auth_service.AuthService>(),
          ),
          dispose: (context, service) => service.dispose(),
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
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
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
  VoidCallback? _bleStatusListenerForAutoConnect; // Đổi tên để rõ ràng hơn
  VoidCallback? _bleStatusListenerForHAR; // Listener mới cho HAR
  bool _checkingDevice = false;
  BleProvider? _bleProviderRef;
  app_auth_provider.AuthProvider? _authProviderRef;
  ActivityRecognitionService? _activityServiceRef;

  @override
  void initState() {
    super.initState();
    debugPrint("[AuthWrapper initState] Initializing...");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _authProviderRef =
            Provider.of<app_auth_provider.AuthProvider>(context, listen: false);
        _bleProviderRef = Provider.of<BleProvider>(context, listen: false);
        _activityServiceRef =
            Provider.of<ActivityRecognitionService>(context, listen: false);

        _authProviderRef!.addListener(_handleAuthChange);
        _handleAuthChange(); // Xử lý trạng thái ban đầu

        // <<< ĐĂNG KÝ LISTENER CHO BLE CONNECTION STATUS ĐỂ KÍCH HOẠT HAR >>>
        if (_bleProviderRef != null) {
          _bleStatusListenerForHAR = _handleBleConnectionChangeForHAR;
          _bleProviderRef!.connectionStatus
              .addListener(_bleStatusListenerForHAR!);
          // Gọi một lần để kiểm tra trạng thái ban đầu của BLE connection
          // (nếu app khởi động lại và BLE đã kết nối từ trước)
          _handleBleConnectionChangeForHAR();
          debugPrint(
              "[AuthWrapper initState] Added BLE listener for HAR activation.");
        } else {
          debugPrint(
              "!!! [AuthWrapper initState] BleProvider is null. Cannot add listener for HAR.");
        }
        // -----------------------------------------------------------------
      }
    });
  }

  @override
  void dispose() {
    debugPrint("[AuthWrapper dispose] Disposing...");
    _authProviderRef?.removeListener(_handleAuthChange);

    if (_bleStatusListenerForAutoConnect != null && _bleProviderRef != null) {
      try {
        _bleProviderRef!.connectionStatus
            .removeListener(_bleStatusListenerForAutoConnect!);
        debugPrint("[AuthWrapper dispose] Removed BLE auto-connect listener.");
      } catch (e) {
        debugPrint('Error removing BLE auto-connect listener in dispose: $e');
      }
    }
    // <<< HỦY ĐĂNG KÝ LISTENER CHO HAR >>>
    if (_bleStatusListenerForHAR != null && _bleProviderRef != null) {
      try {
        _bleProviderRef!.connectionStatus
            .removeListener(_bleStatusListenerForHAR!);
        debugPrint(
            "[AuthWrapper dispose] Removed BLE listener for HAR activation.");
      } catch (e) {
        debugPrint('Error removing BLE listener for HAR in dispose: $e');
      }
    }
    // -----------------------------------

    _bleProviderRef = null;
    _authProviderRef = null;
    _activityServiceRef = null;
    super.dispose();
  }

  // <<< LISTENER MỚI CHO TRẠNG THÁI KẾT NỐI BLE ĐỂ KÍCH HOẠT/DỪNG HAR >>>
  void _handleBleConnectionChangeForHAR() {
    if (!mounted || _activityServiceRef == null || _bleProviderRef == null) {
      debugPrint(
          "[HAR Listener] Not mounted or services are null. Skipping HAR logic.");
      return;
    }

    final bleStatus = _bleProviderRef!.connectionStatus.value;
    // bleService có thể cần lấy lại nếu không được lưu trữ như một biến instance
    // Hoặc nếu bạn chắc chắn nó không thay đổi, có thể lấy một lần trong initState
    final bleService = Provider.of<BleService>(context, listen: false);

    if (bleStatus == BleConnectionStatus.connected) {
      debugPrint(
          "[HAR Listener] BLE Connected. Starting/Ensuring HAR processing.");
      // ActivityRecognitionService sẽ tự kiểm tra model đã load hay chưa
      _activityServiceRef!
          .startProcessingHealthData(bleService.healthDataStream);
    } else {
      // Khi BLE ngắt kết nối (disconnected, error, etc.)
      // ActivityRecognitionService.dispose() sẽ được gọi bởi MultiProvider,
      // và trong đó _healthDataSubscriptionForHar sẽ được cancel.
      // Nếu bạn muốn dừng ngay lập tức một cách tường minh hơn:
      // _activityServiceRef!.stopProcessingHealthData();
      debugPrint(
          "[HAR Listener] BLE Disconnected/Error. HAR should stop or pause receiving data.");
      // Không cần gọi stopProcessingHealthData ở đây nữa nếu dispose của service đã xử lý.
      // Việc ActivityRecognitionService tiếp tục "lắng nghe" một stream không có dữ liệu
      // cũng không gây hại, và nó sẽ nhận lại dữ liệu khi stream đó bắt đầu phát lại.
    }
  }
  // ------------------------------------------------------------------------

  void _handleAuthChange() {
    if (!mounted) return;
    final authStatus = _authProviderRef?.status;
    debugPrint(
        "[AuthWrapper _handleAuthChange] Auth status changed to: $authStatus");

    if (authStatus == app_auth_provider.AuthStatus.authenticated) {
      if (!_checkingDevice &&
          (_deviceCheckStatus == 'initial' ||
              _deviceCheckStatus == 'failed' ||
              _deviceCheckStatus == 'no_device')) {
        debugPrint(
            "[AuthWrapper _handleAuthChange] Authenticated! Checking device...");
        _checkSavedDeviceAndConnect();
      }
    } else {
      debugPrint(
          "[AuthWrapper _handleAuthChange] Not authenticated. Resetting device check.");
      if (_checkingDevice) _checkingDevice = false;
      if (_bleStatusListenerForAutoConnect != null && _bleProviderRef != null) {
        try {
          _bleProviderRef!.connectionStatus
              .removeListener(_bleStatusListenerForAutoConnect!);
          _bleStatusListenerForAutoConnect = null;
        } catch (e) {
          debugPrint('Error removing BLE listener on auth change: $e');
        }
      }
      if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'initial');
    }
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!mounted || _checkingDevice) return;
    _checkingDevice = true;
    setStateIfMounted(() => _deviceCheckStatus = 'checking');
    debugPrint("[AuthWrapper] Checking saved device ID...");

    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      final savedDeviceId =
          prefs.getString(AppConstants.prefKeyConnectedDeviceId);

      if (!mounted) {
        _checkingDevice = false;
        return;
      }

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        debugPrint(
            "[AuthWrapper] Found saved ID: $savedDeviceId. Trying auto-connect...");
        setStateIfMounted(() => _deviceCheckStatus = 'connecting');

        _bleProviderRef ??= Provider.of<BleProvider>(context, listen: false);
        if (_bleProviderRef == null) {
          debugPrint(
              "[AuthWrapper] BleProvider is null during auto-connect check.");
          setStateIfMounted(() => _deviceCheckStatus = 'failed');
          _checkingDevice = false;
          return;
        }

        if (_bleStatusListenerForAutoConnect != null) {
          try {
            _bleProviderRef!.connectionStatus
                .removeListener(_bleStatusListenerForAutoConnect!);
            _bleStatusListenerForAutoConnect = null;
            debugPrint(
                "[AuthWrapper _checkSavedDeviceAndConnect] Removed previous BLE auto-connect listener.");
          } catch (e) {
            debugPrint('Error removing previous BLE auto-connect listener: $e');
          }
        }

        _bleStatusListenerForAutoConnect = () {
          // Đổi tên biến
          if (!mounted || _bleProviderRef == null) {
            _bleProviderRef?.connectionStatus
                .removeListener(_bleStatusListenerForAutoConnect!);
            _bleStatusListenerForAutoConnect = null;
            return;
          }
          final status = _bleProviderRef!.connectionStatus.value;
          debugPrint(
              "[AuthWrapper] Auto-connect listener received status: $status");

          if (_deviceCheckStatus == 'connecting') {
            if (status == BleConnectionStatus.connected) {
              debugPrint("[AuthWrapper] Auto-connect SUCCESSFUL.");
              setStateIfMounted(() => _deviceCheckStatus = 'connected');
              _bleProviderRef?.connectionStatus
                  .removeListener(_bleStatusListenerForAutoConnect!);
              _bleStatusListenerForAutoConnect = null;
            } else if (status == BleConnectionStatus.error ||
                status == BleConnectionStatus.disconnected) {
              debugPrint(
                  "[AuthWrapper] Auto-connect FAILED or disconnected during connect.");
              prefs.remove(AppConstants.prefKeyConnectedDeviceId);
              setStateIfMounted(() => _deviceCheckStatus = 'failed');
              _bleProviderRef?.connectionStatus
                  .removeListener(_bleStatusListenerForAutoConnect!);
              _bleStatusListenerForAutoConnect = null;
            }
          } else {
            debugPrint(
                "[AuthWrapper] Auto-connect listener active but deviceCheckStatus is $_deviceCheckStatus. Removing listener.");
            _bleProviderRef?.connectionStatus
                .removeListener(_bleStatusListenerForAutoConnect!);
            _bleStatusListenerForAutoConnect = null;
          }
        };

        _bleProviderRef!.connectionStatus
            .addListener(_bleStatusListenerForAutoConnect!);
        debugPrint(
            "[AuthWrapper _checkSavedDeviceAndConnect] Added new BLE auto-connect listener.");

        try {
          debugPrint(
              "[AuthWrapper] Calling connectToDevice for $savedDeviceId");
          final targetDeviceId = DeviceIdentifier(savedDeviceId);
          final targetDevice = BluetoothDevice(remoteId: targetDeviceId);
          await _bleProviderRef!.connectToDevice(targetDevice).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint("[AuthWrapper] Auto-connection TIMED OUT.");
              if (_deviceCheckStatus == 'connecting') {
                prefs.remove(AppConstants.prefKeyConnectedDeviceId);
                setStateIfMounted(() => _deviceCheckStatus = 'failed');
              }
              _bleProviderRef?.connectionStatus
                  .removeListener(_bleStatusListenerForAutoConnect!);
              _bleStatusListenerForAutoConnect = null;
              throw TimeoutException('BLE auto-connection timed out');
            },
          );
          debugPrint(
              "[AuthWrapper] connectToDevice call completed (waiting for listener if not already resolved).");
        } catch (e) {
          debugPrint("[AuthWrapper] Error initiating auto-connect call: $e");
          if (e is! TimeoutException && _deviceCheckStatus == 'connecting') {
            await prefs.remove(AppConstants.prefKeyConnectedDeviceId);
            setStateIfMounted(() => _deviceCheckStatus = 'failed');
          }
          _bleProviderRef?.connectionStatus
              .removeListener(_bleStatusListenerForAutoConnect!);
          _bleStatusListenerForAutoConnect = null;
          _checkingDevice = false;
          return;
        }
      } else {
        debugPrint("[AuthWrapper] No saved device ID found.");
        setStateIfMounted(() => _deviceCheckStatus = 'no_device');
      }
    } catch (e) {
      debugPrint("[AuthWrapper] Error in _checkSavedDeviceAndConnect: $e");
      setStateIfMounted(() => _deviceCheckStatus = 'failed');
    } finally {
      _checkingDevice = false;
      debugPrint(
          "[AuthWrapper] _checkSavedDeviceAndConnect finished. Current Status: $_deviceCheckStatus");
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth_provider.AuthProvider>();
    debugPrint(
        "[AuthWrapper] build triggered. AuthStatus: ${authProvider.status}, DeviceCheckStatus: $_deviceCheckStatus");

    switch (authProvider.status) {
      case app_auth_provider.AuthStatus.uninitialized:
      case app_auth_provider.AuthStatus.authenticating:
        return const SplashScreen();
      case app_auth_provider.AuthStatus.unauthenticated:
      case app_auth_provider.AuthStatus.error:
        return const LoginScreen();
      case app_auth_provider.AuthStatus.authenticated:
        debugPrint("[AuthWrapper] Authenticated. Navigating to MainNavigator.");
        return MainNavigator(key: mainNavigatorKey);
    }
  }
}
