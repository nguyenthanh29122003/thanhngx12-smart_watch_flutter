// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Options, Constants, and generated files
import 'firebase_options.dart';
import 'app_constants.dart';
import 'generated/app_localizations.dart';

// Services
import 'services/auth_service.dart' as app_auth_service;
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'services/notification_service.dart';
import 'services/activity_recognition_service.dart';
import 'services/open_router_service.dart';
import 'services/navigation_notification_service.dart';

// Providers
import 'providers/auth_provider.dart' as app_auth_provider;
import 'providers/ble_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/relatives_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/goals_provider.dart';

// Screens
import 'screens/core/main_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device/device_select_screen.dart';

// Theme
import 'theme/app_theme.dart';

// ===================================================================
// KHỞI TẠO SINGLETON & GLOBAL KEY
// ===================================================================

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Service không phụ thuộc
final LocalDbService localDbService = LocalDbService.instance;
final NotificationService notificationService = NotificationService();
final FirestoreService firestoreService = FirestoreService();
final ConnectivityService connectivityService = ConnectivityService();
final app_auth_service.AuthService authService = app_auth_service.AuthService();
final OpenRouterService openRouterService = OpenRouterService();
final NavigationNotificationService navigationNotificationService =
    NavigationNotificationService();

// Service phụ thuộc - sẽ được khởi tạo trong main()
late final BleService bleService;
late final ActivityRecognitionService activityRecognitionService;
late final DataSyncService dataSyncService;

// ===================================================================
// HÀM MAIN() - ĐIỂM BẮT ĐẦU CỦA ỨNG DỤNG
// ===================================================================

Future<void> main() async {
  // Đảm bảo Flutter đã được khởi tạo
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo các thư viện và service bất đồng bộ
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await dotenv.load(fileName: '.env');
  await notificationService.init();

  // Khởi tạo các service phụ thuộc (chỉ một lần)
  bleService = BleService(
    authService,
    firestoreService,
    localDbService,
    connectivityService,
    notificationService,
  );

  activityRecognitionService =
      ActivityRecognitionService(authService: authService);

  dataSyncService = DataSyncService(
    connectivityService,
    localDbService,
    firestoreService,
    authService,
  );

  // Khởi tạo các phụ thuộc chéo
  navigationNotificationService.setBleService(bleService);

  // Chạy ứng dụng
  runApp(const MyApp());
}

// ===================================================================
// LỚP MYAPP - WIDGET GỐC CỦA ỨNG DỤNG
// ===================================================================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider sẽ là widget gốc của ứng dụng
    return MultiProvider(
      providers: [
        // --- Nhóm 1: Cung cấp các service Singleton bằng .value ---
        // Provider.value không tạo mới hay hủy bỏ đối tượng.
        Provider<LocalDbService>.value(value: localDbService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<app_auth_service.AuthService>.value(value: authService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<OpenRouterService>.value(value: openRouterService),
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<NavigationNotificationService>.value(
            value: navigationNotificationService),
        Provider<BleService>.value(value: bleService),
        Provider<ActivityRecognitionService>.value(
            value: activityRecognitionService),
        Provider<DataSyncService>.value(value: dataSyncService),

        // --- Nhóm 2: Các ChangeNotifierProvider tạo mới trạng thái cho UI ---
        // Chúng sẽ phụ thuộc vào các service đã được cung cấp ở trên.
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<app_auth_provider.AuthProvider>(
          create: (context) => app_auth_provider.AuthProvider(
            context.read<app_auth_service.AuthService>(),
            context.read<FirestoreService>(),
          ),
        ),

        // Sửa lỗi: Dùng ChangeNotifierProvider đơn giản cho BleProvider
        // Nó được tạo một lần và sẽ tự lắng nghe các stream từ BleService (singleton).
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
        ),

        // --- Nhóm 3: Các provider phụ thuộc vào provider khác ---
        ChangeNotifierProxyProvider<app_auth_provider.AuthProvider,
            DashboardProvider>(
          create: (context) => DashboardProvider(
            context.read<FirestoreService>(),
            context.read<app_auth_service.AuthService>(),
          ),
          update: (context, auth, previous) {
            if (auth.status == app_auth_provider.AuthStatus.unauthenticated &&
                previous != null) {
              previous.clearDataOnLogout();
            }
            return previous!;
          },
        ),
        ChangeNotifierProxyProvider<app_auth_provider.AuthProvider,
            RelativesProvider>(
          create: (context) => RelativesProvider(
              context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
          update: (context, auth, previous) => previous!,
        ),
        ChangeNotifierProxyProvider<app_auth_provider.AuthProvider,
            GoalsProvider>(
          create: (context) => GoalsProvider(context.read<FirestoreService>(),
              context.read<app_auth_service.AuthService>()),
          update: (context, auth, previous) => previous!,
        ),

        // ProxyProvider này dùng để cập nhật Settings vào ARService mỗi khi settings thay đổi
        ProxyProvider<SettingsProvider, void>(
          update: (_, settings, __) {
            activityRecognitionService.applySettings(
              sittingThreshold: settings.sittingWarningThreshold,
              lyingThreshold: settings.lyingDaytimeWarningThreshold,
              smartRemindersEnabled: settings.smartRemindersEnabled,
              minMovementDuration: settings.minMovementDurationToResetWarning,
              periodicAnalysisInterval: settings.periodicAnalysisInterval,
            );
          },
        ),
      ],
      // Consumer để rebuild MaterialApp khi Settings (theme, locale) thay đổi
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: 'Smart Wearable App',
            locale: settingsProvider.appLocale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsProvider.themeMode,
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            home: const AuthWrapper(),
            routes: {
              '/device_select': (context) => const DeviceSelectScreen(),
              '/main': (context) => const MainNavigator(),
              '/login': (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}

// ===================================================================
// AUTHWRAPPER - WIDGET ĐIỀU HƯỚNG CHÍNH
// ===================================================================

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription? _warningStreamSubscription;
  BleConnectionStatus? _lastHandledBleStatus;

  // <<< THÊM: Biến trạng thái để quản lý việc kiểm tra thiết bị ban đầu >>>
  bool _isInitialDeviceCheckDone = false;

  @override
  void initState() {
    super.initState();
    debugPrint("[AuthWrapper initState] Initializing...");
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final activityService =
            Provider.of<ActivityRecognitionService>(context, listen: false);
        _listenToActivityWarnings(activityService);

        // <<< SỬA ĐỔI: Bắt đầu kiểm tra thiết bị ngay khi có thể >>>
        _checkSavedDeviceAndConnect();
      }
    });
  }

  void _listenToActivityWarnings(ActivityRecognitionService activityService) {
    // Lấy NotificationService một lần từ context
    final notificationService =
        Provider.of<NotificationService>(context, listen: false);

    // Hủy bỏ listener cũ nếu có để tránh đăng ký nhiều lần
    _warningStreamSubscription?.cancel();

    // Bắt đầu lắng nghe stream cảnh báo mới
    _warningStreamSubscription =
        activityService.warningStream.listen((warning) {
      // Đảm bảo widget vẫn còn trên cây widget trước khi thực hiện hành động
      if (mounted && warning.message.isNotEmpty) {
        // Lấy AppLocalizations để dịch các chuỗi.
        // Phải lấy context từ GlobalKey vì context của build có thể không còn hợp lệ
        // nếu người dùng đã điều hướng đi nơi khác.
        final BuildContext? currentContext = navigatorKey.currentContext;
        if (currentContext == null) {
          if (kDebugMode)
            print("[AuthWrapper] Cannot show warning, no valid context.");
          return;
        }
        final l10n = AppLocalizations.of(currentContext)!;

        // Tạo một ID thông báo duy nhất để tránh ghi đè
        final notificationId =
            DateTime.now().millisecondsSinceEpoch.remainder(100000);

        // Các biến cho thông báo
        String channelId;
        String channelName;
        String notificationTitle;

        // Quyết định nội dung thông báo dựa trên loại cảnh báo
        switch (warning.type) {
          case ActivityWarningType.prolongedSitting:
            notificationTitle = l10n.prolongedSittingWarningTitle;
            channelId = 'sitting_alerts';
            channelName = l10n.sittingAlertsChannelName;
            break;
          case ActivityWarningType.prolongedLyingDaytime:
            notificationTitle = l10n.prolongedLyingWarningTitle;
            channelId = 'lying_alerts';
            channelName = l10n.lyingAlertsChannelName;
            break;
          case ActivityWarningType.smartReminderToMove:
            notificationTitle = l10n.smartReminderTitle;
            channelId = 'smart_reminders';
            channelName = l10n.smartReminderChannelName;
            break;
          case ActivityWarningType.positiveReinforcement:
            notificationTitle = l10n.positiveFeedbackTitle;
            channelId = 'positive_feedback';
            channelName = l10n.positiveFeedbackChannelName;
            break;
        }

        // Gọi service để hiển thị thông báo
        notificationService.showSimpleNotification(
          id: notificationId,
          title: notificationTitle,
          body: warning.message, // Message đã được tạo sẵn trong service
          payload:
              "warning_${warning.type.toString()}_${DateTime.now().millisecondsSinceEpoch}",
          channelId: channelId,
          channelName: channelName,
          channelDescription:
              "Activity alerts from your wearable device.", // Mô tả chung
        );
      }
    }, onError: (error) {
      if (kDebugMode)
        print("!!! [AuthWrapper] Error on warning stream: $error");
    });
  }

  // Hàm này chỉ chạy một lần để cố gắng tự động kết nối lại
  Future<void> _checkSavedDeviceAndConnect() async {
    // Nếu đã kiểm tra rồi thì không làm lại
    if (_isInitialDeviceCheckDone || !mounted) return;

    final authProvider =
        Provider.of<app_auth_provider.AuthProvider>(context, listen: false);

    // Chỉ kiểm tra khi đã đăng nhập
    if (authProvider.status == app_auth_provider.AuthStatus.authenticated) {
      debugPrint("[AuthWrapper] Performing initial device check...");
      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(AppConstants.prefKeyConnectedDeviceId);

      if (deviceId != null && deviceId.isNotEmpty) {
        debugPrint(
            "[AuthWrapper] Found saved device ID. Attempting auto-reconnect...");
        bleProvider.tryReconnect();
      }

      // Đánh dấu là đã kiểm tra xong, bất kể kết quả
      if (mounted) {
        setState(() {
          _isInitialDeviceCheckDone = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _warningStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth_provider.AuthProvider>();
    final bleProvider = context.watch<BleProvider>();
    final bleStatus = bleProvider.connectionStatus.value;

    // --- LOGIC KÍCH HOẠT HAR SERVICE (Giữ nguyên) ---
    if (bleStatus != _lastHandledBleStatus) {
      final activityService =
          Provider.of<ActivityRecognitionService>(context, listen: false);
      if (bleStatus == BleConnectionStatus.connected) {
        activityService.startProcessingHealthData(bleService.healthDataStream);
      } else {
        activityService.stopProcessingHealthData();
      }
      _lastHandledBleStatus = bleStatus;
    }

    debugPrint(
        "[AuthWrapper build] Auth: ${authProvider.status}, BLE: $bleStatus, InitialCheckDone: $_isInitialDeviceCheckDone");

    // --- LOGIC ĐIỀU HƯỚNG ĐÃ ĐƠN GIẢN HÓA ---

    // 1. Nếu chưa xác thực xong, luôn hiển thị Splash
    if (authProvider.status == app_auth_provider.AuthStatus.uninitialized ||
        authProvider.status == app_auth_provider.AuthStatus.authenticating) {
      return const SplashScreen();
    }

    // 2. Nếu xác thực thất bại, hiển thị Login
    if (authProvider.status == app_auth_provider.AuthStatus.unauthenticated ||
        authProvider.status == app_auth_provider.AuthStatus.error) {
      return const LoginScreen();
    }

    // 3. Nếu đã xác thực (authenticated)
    if (authProvider.status == app_auth_provider.AuthStatus.authenticated) {
      // 3a. Nếu đã kết nối BLE, vào màn hình chính
      if (bleStatus == BleConnectionStatus.connected) {
        return const MainNavigator();
      }

      // // 3b. Nếu chưa kết nối BLE, nhưng việc kiểm tra ban đầu CHƯA xong,
      // // (tức là đang trong quá trình auto-reconnect) -> hiển thị Splash
      // if (!_isInitialDeviceCheckDone) {
      //   return const SplashScreen(message: "Checking for device...");
      // }

      // 3c. Nếu kiểm tra ban đầu đã xong và vẫn chưa kết nối
      // -> người dùng cần phải chọn thiết bị
      return const DeviceSelectScreen();
    }

    // Trường hợp dự phòng
    return const SplashScreen(message: "An unexpected error occurred.");
  }
}
