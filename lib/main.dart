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
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/local_db_service.dart';
import 'services/ble_service.dart';
import 'services/connectivity_service.dart';
import 'services/data_sync_service.dart';
import 'services/notification_service.dart';
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
    debugPrint('Loaded .env successfully: ${dotenv.env['OPENROUTER_API_KEY']}');
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
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(),
          dispose: (_, s) => s.dispose(),
        ),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(
            context.read<AuthService>(),
            context.read<FirestoreService>(),
          ),
        ),
        Provider<BleService>(
          create: (context) => BleService(
            context.read<AuthService>(),
            context.read<FirestoreService>(),
            context.read<LocalDbService>(),
            context.read<ConnectivityService>(),
            context.read<NotificationService>(),
          ),
          dispose: (_, s) => s.dispose(),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (context) => BleProvider(context.read<BleService>()),
        ),
        ChangeNotifierProvider<DashboardProvider>(
          create: (context) => DashboardProvider(
            context.read<FirestoreService>(),
            context.read<AuthService>(),
          ),
        ),
        ChangeNotifierProvider<RelativesProvider>(
          create: (context) => RelativesProvider(
            context.read<FirestoreService>(),
            context.read<AuthService>(),
          ),
        ),
        Provider<DataSyncService>(
          create: (context) => DataSyncService(
            context.read<ConnectivityService>(),
            context.read<LocalDbService>(),
            context.read<FirestoreService>(),
            context.read<AuthService>(),
          ),
          dispose: (_, s) => s.dispose(),
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
        if (ap.status == AuthStatus.authenticated &&
            !_checkingDevice &&
            _deviceCheckStatus == 'initial') {
          debugPrint(
              "[AuthWrapper initState] Already authenticated, checking device...");
          _checkSavedDeviceAndConnect();
        } else {
          debugPrint("[AuthWrapper initState] Not authenticated initially.");
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
      debugPrint('Error removing auth listener: $e');
    }
    if (_bleStatusListener != null && _bleProviderRef != null) {
      try {
        _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
        debugPrint("[AuthWrapper dispose] Removed BLE connection listener.");
      } catch (e) {
        debugPrint('Error removing BLE listener in dispose: $e');
      }
    }
    _bleProviderRef = null;
    super.dispose();
  }

  void _handleAuthChange() {
    if (!_isMounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final authStatus = authProvider.status;
    debugPrint(
        "[AuthWrapper _handleAuthChange] Auth status changed to: $authStatus");
    if (authStatus == AuthStatus.authenticated) {
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
      if (_bleStatusListener != null && _bleProviderRef != null) {
        try {
          _bleProviderRef!.connectionStatus.removeListener(_bleStatusListener!);
          _bleStatusListener = null;
        } catch (e) {
          debugPrint('Error removing BLE listener on auth change: $e');
        }
      }
      if (mounted) setState(() => _deviceCheckStatus = 'initial');
    }
  }

  Future<void> _checkSavedDeviceAndConnect() async {
    if (!_isMounted || _checkingDevice) return;
    _checkingDevice = true;
    if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'checking');
    debugPrint("[AuthWrapper] Checking saved device ID...");
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      final savedDeviceId =
          prefs.getString(AppConstants.prefKeyConnectedDeviceId);

      if (!_isMounted) {
        _checkingDevice = false;
        return;
      }

      if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
        debugPrint(
            "[AuthWrapper] Found saved ID: $savedDeviceId. Trying auto-connect...");
        if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'connecting');

        _bleProviderRef ??= Provider.of<BleProvider>(context, listen: false);
        if (_bleProviderRef == null) {
          debugPrint(
              "[AuthWrapper] BleProvider is null during auto-connect check.");
          if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'failed');
          _checkingDevice = false;
          return;
        }

        if (_bleStatusListener != null) {
          try {
            _bleProviderRef!.connectionStatus
                .removeListener(_bleStatusListener!);
          } catch (e) {
            debugPrint('Error removing previous BLE listener: $e');
          }
        }

        _bleStatusListener = () {
          if (!_isMounted || _bleProviderRef == null) {
            _bleStatusListener = null;
            return;
          }
          final status = _bleProviderRef!.connectionStatus.value;
          debugPrint(
              "[AuthWrapper] Auto-connect listener received status: $status");

          if (_deviceCheckStatus == 'connecting') {
            if (status == BleConnectionStatus.connected) {
              debugPrint("[AuthWrapper] Auto-connect SUCCESSFUL.");
              if (mounted)
                setStateIfMounted(() => _deviceCheckStatus = 'connected');
              if (_bleStatusListener != null) {
                try {
                  _bleProviderRef!.connectionStatus
                      .removeListener(_bleStatusListener!);
                } catch (e) {}
                _bleStatusListener = null;
              }
            } else if (status == BleConnectionStatus.error ||
                status == BleConnectionStatus.disconnected) {
              debugPrint(
                  "[AuthWrapper] Auto-connect FAILED or disconnected during connect.");
              prefs.remove(AppConstants.prefKeyConnectedDeviceId);
              if (mounted)
                setStateIfMounted(() => _deviceCheckStatus = 'failed');
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
              debugPrint(
                  "[AuthWrapper] Auto-connect listener active but deviceCheckStatus is $_deviceCheckStatus. Removing listener.");
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
          debugPrint('Error adding BLE listener: $e');
        }

        try {
          debugPrint(
              "[AuthWrapper] Calling connectToDevice for $savedDeviceId");
          final targetDeviceId = DeviceIdentifier(savedDeviceId);
          final targetDevice = BluetoothDevice(remoteId: targetDeviceId);
          await _bleProviderRef!.connectToDevice(targetDevice).timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              throw TimeoutException('BLE auto-connection timed out');
            },
          );
          debugPrint(
              "[AuthWrapper] connectToDevice call completed (waiting for listener).");
        } catch (e) {
          debugPrint("[AuthWrapper] Error initiating auto-connect call: $e");
          await prefs.remove(AppConstants.prefKeyConnectedDeviceId);
          if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'failed');
          if (_bleStatusListener != null) {
            try {
              _bleProviderRef!.connectionStatus
                  .removeListener(_bleStatusListener!);
            } catch (e) {}
            _bleStatusListener = null;
          }
          _checkingDevice = false;
          return;
        }
      } else {
        debugPrint("[AuthWrapper] No saved device ID found.");
        if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'no_device');
      }
    } catch (e) {
      debugPrint("[AuthWrapper] Error in _checkSavedDeviceAndConnect: $e");
      if (mounted) setStateIfMounted(() => _deviceCheckStatus = 'failed');
    } finally {
      _checkingDevice = false;
      if (mounted &&
          (_deviceCheckStatus == 'checking' ||
              _deviceCheckStatus == 'connecting')) {
        setStateIfMounted(() => _deviceCheckStatus = 'failed');
      }
      debugPrint(
          "[AuthWrapper] _checkSavedDeviceAndConnect finished. Status: $_deviceCheckStatus");
    }
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    debugPrint(
        "[AuthWrapper] build triggered. AuthStatus: ${authProvider.status}, DeviceCheckStatus: $_deviceCheckStatus");
    switch (authProvider.status) {
      case AuthStatus.uninitialized:
      case AuthStatus.authenticating:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
      case AuthStatus.error:
        return const LoginScreen();
      case AuthStatus.authenticated:
        debugPrint(
            "[AuthWrapper] Authenticated. Navigating to MainNavigator regardless of device status ($_deviceCheckStatus).");
        return MainNavigator(key: mainNavigatorKey);
    }
  }
}
