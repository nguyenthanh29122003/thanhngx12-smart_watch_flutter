// lib/main.dart (Trạng thái trước khi sửa lỗi treo loading)
// lib/main.dart (Phiên bản KHÔNG dùng Key, inject Provider đúng)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Import các file cấu hình và services
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'app_constants.dart';
import 'generated/app_localizations.dart';

// Import các Providers quản lý state
import 'providers/auth_provider.dart'; // <<< Phiên bản đã sửa lỗi treo
import 'providers/ble_provider.dart'; // <<< Phiên bản không có Auth reset
import 'providers/dashboard_provider.dart';
import 'providers/relatives_provider.dart';
import 'providers/settings_provider.dart';

// Import các màn hình
import 'screens/core/main_navigator.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/device/device_select_screen.dart';

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
            dispose: (_, s) => s.dispose()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<SettingsProvider>(
            create: (_) => SettingsProvider()),

        // --- 2. Cung cấp các Service/Provider phụ thuộc ---
        // AuthProvider (Phiên bản đã sửa)
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
              context.read<AuthService>(), context.read<FirestoreService>()),
        ),
        // BleService
        Provider<BleService>(
          create: (context) => BleService(
              context.read<AuthService>(),
              context.read<FirestoreService>(),
              context.read<LocalDbService>(),
              context.read<ConnectivityService>()),
          dispose: (context, s) => s.dispose(),
        ),
        // BleProvider (KHÔNG inject AuthService)
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(
              context.read<BleService>()), // <<< Chỉ nhận BleService
        ),
        // DashboardProvider
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
              context.read<FirestoreService>(), context.read<AuthService>()),
        ),
        // RelativesProvider
        ChangeNotifierProvider<RelativesProvider>(
          create: (context) => RelativesProvider(
              context.read<FirestoreService>(), context.read<AuthService>()),
        ),
        // DataSyncService
        Provider<DataSyncService>(
          create: (context) => DataSyncService(
              context.read<ConnectivityService>(),
              context.read<LocalDbService>(),
              context.read<FirestoreService>(),
              context.read<AuthService>()),
          dispose: (context, s) => s.dispose(),
          lazy: false,
        ),
      ],
      // <<< KHÔNG DÙNG Consumer và Key ở đây >>>
      child: const MyApp(),
    ),
  );
}

// --- MyApp (Không cần Key) ---
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
    );
  }
}

// --- AuthWrapper (StatefulWidget với logic kiểm tra thiết bị) ---
// Giữ nguyên phiên bản StatefulWidget bạn đã cung cấp gần nhất
// vì logic này không phải là nguyên nhân chính gây treo
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
          if (!_checkingDevice && _deviceCheckStatus == 'initial')
            _checkSavedDeviceAndConnect();
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
    } catch (e) {}
    if (_bleStatusListener != null && _bleProviderRef != null) {
      try {
        _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
      } catch (e) {}
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
        } catch (e) {}
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!_isMounted || _checkingDevice) return;
    _checkingDevice = true;
    if (mounted) setState(() => _deviceCheckStatus = 'checking');
    print("[AuthWrapper] Checking saved device ID...");
    SharedPreferences prefs;
    String? savedDeviceId;
    try {
      prefs = await SharedPreferences.getInstance();
      savedDeviceId = prefs.getString(AppConstants.prefKeyConnectedDeviceId);
    } catch (e) {
      print("!!! SharedPreferences Error: $e");
      if (_isMounted) setState(() => _deviceCheckStatus = 'no_device');
      _checkingDevice = false;
      return;
    }
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
          _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
        } catch (e) {}
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
              } catch (e) {}
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
              } catch (e) {}
              _bleStatusListener = null;
            }
          }
        } else {
          if (_bleStatusListener != null) {
            try {
              _bleProviderRef!.connectionStatus
                  .removeListener(_bleStatusListener!);
            } catch (e) {}
            _bleStatusListener = null;
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
        List<BluetoothDevice> systemConnected =
            FlutterBluePlus.connectedDevices;
        BluetoothDevice? targetDevice;
        final targetDeviceId = DeviceIdentifier(savedDeviceId);
        try {
          targetDevice =
              systemConnected.firstWhere((d) => d.remoteId == targetDeviceId);
        } catch (e) {
          targetDevice = null;
        }
        targetDevice ??= BluetoothDevice(remoteId: targetDeviceId);
        print("[AuthWrapper] Calling connectToDevice for $savedDeviceId");
        await _bleProviderRef!.connectToDevice(targetDevice);
      } catch (e) {
        print("!!! Error initiating auto-connect: $e");
        prefs.remove(AppConstants.prefKeyConnectedDeviceId);
        if (_isMounted) setState(() => _deviceCheckStatus = 'failed');
        if (_bleStatusListener != null) {
          try {
            _bleProviderRef!.connectionStatus
                .removeListener(_bleStatusListener!);
          } catch (e) {}
          _bleStatusListener = null;
        }
      }
    } else {
      print("[AuthWrapper] No saved device ID found.");
      if (_isMounted) setState(() => _deviceCheckStatus = 'no_device');
    }
    _checkingDevice = false;
  }

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
            nextScreen = const DeviceSelectScreen();
            break;
        }
        break;
    }
    return nextScreen;
  }
}
