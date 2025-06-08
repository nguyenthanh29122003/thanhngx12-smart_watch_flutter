import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
import 'package:flutter/foundation.dart';

// Global key cho navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase
  try {
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('Firebase initialization timed out');
    });
    debugPrint("Firebase initialized successfully.");
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  // Khởi tạo NotificationService
  try {
    await NotificationService().init().timeout(const Duration(seconds: 5),
        onTimeout: () {
      debugPrint("Warning: Notification Service initialization timed out.");
    });
    debugPrint("Notification Service initialized.");
  } catch (e) {
    debugPrint("Error initializing Notification Service: $e");
  }

  // Tải .env
  try {
    await dotenv.load(fileName: '.env');
    debugPrint(".env file loaded successfully.");
  } catch (e) {
    debugPrint('Error loading .env: $e');
    debugPrint('Please ensure .env file exists with OPENROUTER_API_KEY.');
  }

  runApp(
    MultiProvider(
      providers: [
        // --- 1. CÁC PROVIDER ĐỘC LẬP (Không phụ thuộc vào user) ---
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

        // --- 2. AUTH PROVIDER (Nguồn của sự thay đổi) ---
        ChangeNotifierProvider<app_auth_provider.AuthProvider>(
          create: (context) => app_auth_provider.AuthProvider(
            context.read<app_auth_service.AuthService>(),
            context.read<FirestoreService>(),
          ),
        ),

        // --- 3. CÁC PROVIDER PHỤ THUỘC (Sẽ được reset khi user thay đổi) ---

        // A. Cung cấp BleService, nó sẽ được tạo lại khi user thay đổi
        ProxyProvider<app_auth_provider.AuthProvider, BleService>(
          update: (context, auth, previousBleService) {
            // Khi auth thay đổi (đăng nhập/đăng xuất), hủy service cũ và tạo service mới
            previousBleService?.dispose(); // Hủy bỏ service cũ
            return BleService(
              context.read<app_auth_service.AuthService>(),
              context.read<FirestoreService>(),
              context.read<LocalDbService>(),
              context.read<ConnectivityService>(),
              context.read<NotificationService>(),
            );
          },
          dispose: (context, service) => service.dispose(),
        ),

        // B. Cung cấp BleProvider, nó sẽ được tạo lại khi BleService thay đổi
        ChangeNotifierProxyProvider<BleService, BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
          update: (context, bleService, previousBleProvider) {
            // Khi bleService được tạo lại ở trên, chúng ta cũng tạo lại BleProvider
            // để đảm bảo nó dùng instance BleService mới nhất.
            // Điều này sẽ tự động gọi dispose() của previousBleProvider.
            return BleProvider(bleService);
          },
        ),

        // C. Các provider khác
        ChangeNotifierProxyProvider<app_auth_provider.AuthProvider,
            DashboardProvider>(
          create: (context) => DashboardProvider(
              context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
          update: (context, auth, previous) => DashboardProvider(
              context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
        ),

        ChangeNotifierProxyProvider<app_auth_provider.AuthProvider,
            RelativesProvider>(
          create: (context) => RelativesProvider(
              context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
          update: (context, auth, previous) => RelativesProvider(
              context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
        ),

        ProxyProvider<app_auth_provider.AuthProvider,
            ActivityRecognitionService>(
          update: (context, auth, previous) => ActivityRecognitionService(
            authService: context.read<app_auth_service.AuthService>(),
          ),
          dispose: (_, service) => service.dispose(),
        ),

        ProxyProvider<app_auth_provider.AuthProvider, DataSyncService>(
          update: (context, auth, previous) => DataSyncService(
            context.read<ConnectivityService>(),
            context.read<LocalDbService>(),
            context.read<FirestoreService>(),
            context.read<app_auth_service.AuthService>(),
          ),
          dispose: (_, service) => service.dispose(),
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
      navigatorKey: navigatorKey, // Sử dụng navigatorKey
      home: const AuthWrapper(),
      routes: {
        '/device_select': (context) => const DeviceSelectScreen(),
        '/main': (context) => MainNavigator(),
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
  VoidCallback? _bleStatusListenerForAutoConnect;
  VoidCallback? _bleStatusListenerForHAR;
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
        _initializeProviders();
        _setupNotificationHandler();
      }
    });
  }

  void _initializeProviders() {
    _authProviderRef =
        Provider.of<app_auth_provider.AuthProvider>(context, listen: false);
    _bleProviderRef = Provider.of<BleProvider>(context, listen: false);
    _activityServiceRef =
        Provider.of<ActivityRecognitionService>(context, listen: false);

    _authProviderRef!.addListener(_handleAuthChange);
    _handleAuthChange();

    // Listener cho BLE để kích hoạt HAR
    _bleStatusListenerForHAR = _handleBleConnectionChangeForHAR;
    _bleProviderRef!.connectionStatus.addListener(_bleStatusListenerForHAR!);
    _handleBleConnectionChangeForHAR(); // Kiểm tra trạng thái ban đầu

    // Listener cho cảnh báo hoạt động
    _listenToActivityWarnings();

    debugPrint(
        "[AuthWrapper initState] Providers initialized and listeners set up.");
  }

  // Xử lý thông báo từ NotificationService
  void _setupNotificationHandler() {
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);
    FlutterLocalNotificationsPlugin().initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && mounted) {
          if (payload.startsWith('reconnect_success')) {
            navigatorKey.currentState?.pushReplacementNamed('/main');
          } else if (payload.startsWith('reconnect_failed')) {
            showDialog(
              context: navigatorKey.currentContext!,
              builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.reconnectFailedTitle),
                content: Text(
                    AppLocalizations.of(context)!.reconnectFailedBody('3')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocalizations.of(context)!.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Provider.of<BleProvider>(context, listen: false)
                          .tryReconnect();
                    },
                    child: Text(AppLocalizations.of(context)!.tryAgain),
                  ),
                ],
              ),
            );
          }
        }
      },
    );
  }

  StreamSubscription? _warningStreamSubscription;
  void _listenToActivityWarnings() {
    if (_activityServiceRef == null) return;
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);

    _warningStreamSubscription?.cancel();
    _warningStreamSubscription =
        _activityServiceRef!.warningStream.listen((warning) {
      if (mounted && warning.message.isNotEmpty) {
        final notificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);
        String channelId = 'activity_warnings';
        String channelName =
            AppLocalizations.of(context)!.activityAlertsChannelName;
        String channelDescription =
            AppLocalizations.of(context)!.activityAlertsChannelDescription;
        String notificationTitle =
            AppLocalizations.of(context)!.activityWarningTitle;

        switch (warning.type) {
          case ActivityWarningType.prolongedSitting:
            notificationTitle =
                AppLocalizations.of(context)!.prolongedSittingWarningTitle;
            channelId = 'sitting_alerts';
            channelName =
                AppLocalizations.of(context)!.sittingAlertsChannelName;
            break;
          case ActivityWarningType.prolongedLyingDaytime:
            notificationTitle =
                AppLocalizations.of(context)!.prolongedLyingWarningTitle;
            channelId = 'lying_alerts';
            channelName = AppLocalizations.of(context)!.lyingAlertsChannelName;
            break;
          case ActivityWarningType.smartReminderToMove:
            notificationTitle =
                AppLocalizations.of(context)!.smartReminderTitle;
            channelId = 'smart_reminders';
            channelName =
                AppLocalizations.of(context)!.smartReminderChannelName;
            break;
          case ActivityWarningType.positiveReinforcement:
            notificationTitle =
                AppLocalizations.of(context)!.positiveFeedbackTitle;
            channelId = 'positive_feedback';
            channelName =
                AppLocalizations.of(context)!.positiveFeedbackChannelName;
            break;
        }

        notificationService.showSimpleNotification(
          id: notificationId,
          title: notificationTitle,
          body: warning.message,
          payload:
              "warning_${warning.type.toString()}_${DateTime.now().millisecondsSinceEpoch}",
          channelId: channelId,
          channelName: channelName,
          channelDescription: channelDescription,
        );
      }
    }, onError: (error) {
      if (kDebugMode)
        print("!!! [AuthWrapper] Error on warning stream: $error");
    });
  }

  @override
  void dispose() {
    debugPrint("[AuthWrapper dispose] Disposing...");
    _authProviderRef?.removeListener(_handleAuthChange);
    if (_bleStatusListenerForAutoConnect != null && _bleProviderRef != null) {
      _bleProviderRef!.connectionStatus
          .removeListener(_bleStatusListenerForAutoConnect!);
    }
    if (_bleStatusListenerForHAR != null && _bleProviderRef != null) {
      _bleProviderRef!.connectionStatus
          .removeListener(_bleStatusListenerForHAR!);
    }
    _warningStreamSubscription?.cancel();
    _bleProviderRef = null;
    _authProviderRef = null;
    _activityServiceRef = null;
    super.dispose();
  }

  void _handleBleConnectionChangeForHAR() {
    if (!mounted || _activityServiceRef == null || _bleProviderRef == null) {
      debugPrint(
          "[HAR Listener] Not mounted or services null. Skipping HAR logic.");
      return;
    }

    final bleStatus = _bleProviderRef!.connectionStatus.value;
    final bleService = Provider.of<BleService>(context, listen: false);

    if (bleStatus == BleConnectionStatus.connected) {
      debugPrint("[HAR Listener] BLE Connected. Starting HAR processing.");
      _activityServiceRef!
          .startProcessingHealthData(bleService.healthDataStream);
    } else {
      debugPrint("[HAR Listener] BLE Disconnected. Stopping HAR processing.");
      _activityServiceRef!.stopProcessingHealthData();
    }
  }

  void _handleAuthChange() {
    if (!mounted) return;
    final authStatus = _authProviderRef?.status;
    debugPrint("[AuthWrapper _handleAuthChange] Auth status: $authStatus");

    if (authStatus == app_auth_provider.AuthStatus.authenticated) {
      if (!_checkingDevice &&
          (_deviceCheckStatus == 'initial' ||
              _deviceCheckStatus == 'failed' ||
              _deviceCheckStatus == 'no_device')) {
        debugPrint("[AuthWrapper _handleAuthChange] Checking device...");
        _checkSavedDeviceAndConnect();
      }
    } else {
      debugPrint(
          "[AuthWrapper _handleAuthChange] Not authenticated. Resetting.");
      if (_checkingDevice) _checkingDevice = false;
      if (_bleStatusListenerForAutoConnect != null && _bleProviderRef != null) {
        _bleProviderRef!.connectionStatus
            .removeListener(_bleStatusListenerForAutoConnect!);
        _bleStatusListenerForAutoConnect = null;
      }
      setStateIfMounted(() => _deviceCheckStatus = 'initial');
    }
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!mounted || _checkingDevice) return;
    _checkingDevice = true;
    setStateIfMounted(() => _deviceCheckStatus = 'checking');
    debugPrint("[AuthWrapper] Checking saved device ID...");

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedDeviceId =
          prefs.getString(AppConstants.prefKeyConnectedDeviceId);

      if (!mounted) {
        _checkingDevice = false;
        return;
      }

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        debugPrint(
            "[AuthWrapper] Found saved ID: $savedDeviceId. Auto-connecting...");
        setStateIfMounted(() => _deviceCheckStatus = 'connecting');

        // Kích hoạt auto reconnect
        _bleProviderRef!.setAutoReconnect(true);
        _bleProviderRef!.tryReconnect();

        // Listener cho auto-connect
        _bleStatusListenerForAutoConnect = () {
          if (!mounted || _bleProviderRef == null) {
            _bleProviderRef?.connectionStatus
                .removeListener(_bleStatusListenerForAutoConnect!);
            _bleStatusListenerForAutoConnect = null;
            return;
          }
          final status = _bleProviderRef!.connectionStatus.value;
          debugPrint("[AuthWrapper] Auto-connect status: $status");

          if (_deviceCheckStatus == 'connecting') {
            if (status == BleConnectionStatus.connected) {
              debugPrint("[AuthWrapper] Auto-connect SUCCESSFUL.");
              setStateIfMounted(() => _deviceCheckStatus = 'connected');
              _bleProviderRef!.connectionStatus
                  .removeListener(_bleStatusListenerForAutoConnect!);
              _bleStatusListenerForAutoConnect = null;
            } else if (status == BleConnectionStatus.error ||
                status == BleConnectionStatus.disconnected) {
              debugPrint("[AuthWrapper] Auto-connect FAILED.");
              prefs.remove(AppConstants.prefKeyConnectedDeviceId);
              setStateIfMounted(() => _deviceCheckStatus = 'failed');
              _bleProviderRef!.connectionStatus
                  .removeListener(_bleStatusListenerForAutoConnect!);
              _bleStatusListenerForAutoConnect = null;
            }
          }
        };

        _bleProviderRef!.connectionStatus
            .addListener(_bleStatusListenerForAutoConnect!);
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
          "[AuthWrapper] Device check finished. Status: $_deviceCheckStatus");
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth_provider.AuthProvider>();
    debugPrint(
        "[AuthWrapper build] AuthStatus: ${authProvider.status}, DeviceCheckStatus: $_deviceCheckStatus");

    switch (authProvider.status) {
      case app_auth_provider.AuthStatus.uninitialized:
      case app_auth_provider.AuthStatus.authenticating:
        // Hiển thị Splash Screen trong khi khởi tạo hoặc đang đăng nhập
        return const SplashScreen();

      case app_auth_provider.AuthStatus.unauthenticated:
      case app_auth_provider.AuthStatus.error:
        // Nếu chưa đăng nhập hoặc có lỗi, quay về màn hình Login
        return const LoginScreen();

      case app_auth_provider.AuthStatus.authenticated:
        // --- LOGIC ĐIỀU HƯỚNG QUAN TRỌNG KHI ĐÃ ĐĂNG NHẬP ---

        // 1. Luôn hiển thị loading khi đang kiểm tra hoặc kết nối thiết bị
        if (_deviceCheckStatus == 'checking' ||
            _deviceCheckStatus == 'connecting') {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    _deviceCheckStatus == 'checking'
                        ? "Checking for saved device..."
                        : "Connecting to device...",
                  ),
                ],
              ),
            ),
          );
        }

        // 2. Nếu không có thiết bị hoặc kết nối tự động thất bại -> BẮT BUỘC đến màn hình chọn thiết bị
        if (_deviceCheckStatus == 'no_device' ||
            _deviceCheckStatus == 'failed') {
          debugPrint(
              "[AuthWrapper build] No device or connection failed. Navigating to DeviceSelectScreen.");
          // Sử dụng Future.microtask để điều hướng một cách an toàn sau khi build xong
          Future.microtask(() {
            if (mounted) {
              // Sử dụng pushReplacement để người dùng không thể nhấn back quay lại màn hình này
              navigatorKey.currentState?.pushReplacementNamed('/device_select');
            }
          });
          // Trả về một màn hình chờ trong khi điều hướng
          return const SplashScreen();
        }

        // 3. Nếu đã kết nối thành công, vào màn hình chính
        if (_deviceCheckStatus == 'connected') {
          debugPrint(
              "[AuthWrapper build] Device connected. Navigating to MainNavigator.");
          return const MainNavigator();
        }

        // 4. Trường hợp mặc định (ví dụ: trạng thái 'initial' khi mới vào), hiển thị chờ
        // trong khi logic trong initState/handleAuthChange đang chạy.
        return const SplashScreen();
    }
  }
}
