// lib/services/notification_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ble_provider.dart';
import '../generated/app_localizations.dart';
import '../main.dart'; // Để sử dụng navigatorKey

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionRequested = false;
  bool _permissionGranted = false;

  bool get permissionGranted => _permissionGranted;

  Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) print("[NotificationService] Already initialized.");
      return;
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('notification_icon');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _initialized = true;
      if (kDebugMode) print("[NotificationService] Initialization successful.");
      await requestPermissions();
    } catch (e) {
      if (kDebugMode)
        print("!!! [NotificationService] Initialization failed: $e");
    }
  }

  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      if (kDebugMode) {
        print('[NotificationService] Notification Tapped - Payload: $payload');
      }
      final context = navigatorKey.currentContext;
      if (context == null) {
        if (kDebugMode) {
          print('[NotificationService] No context available for navigation.');
        }
        return;
      }

      if (payload == 'reconnect_success') {
        if (kDebugMode) {
          print(
              '[NotificationService] Handling reconnect_success: Navigating to MainNavigator.');
        }
        // Điều hướng đến MainNavigator
        navigatorKey.currentState?.pushReplacementNamed('/main');
      } else if (payload == 'reconnect_failed') {
        if (kDebugMode) {
          print(
              '[NotificationService] Handling reconnect_failed: Showing retry dialog.');
        }
        // Hiển thị dialog retry
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title:
                Text(AppLocalizations.of(dialogContext)!.reconnectFailedTitle),
            content: Text(
                AppLocalizations.of(dialogContext)!.reconnectFailedBody('3')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(AppLocalizations.of(dialogContext)!.cancel),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  // Gọi tryReconnect từ BleProvider
                  Provider.of<BleProvider>(context, listen: false)
                      .tryReconnect();
                },
                child: Text(AppLocalizations.of(dialogContext)!.tryAgain),
              ),
            ],
          ),
        );
      } else if (payload == 'reconnect_attempt') {
        if (kDebugMode) {
          print(
              '[NotificationService] Handling reconnect_attempt: Updating reconnect status.');
        }
        // Cập nhật trạng thái reconnect trong BleProvider
        Provider.of<BleProvider>(context, listen: false)
            .updateReconnectStatus(true);
        // Hiển thị SnackBar thông báo đang reconnect
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reconnectAttemptBody),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (kDebugMode) {
        print('[NotificationService] Notification Tapped - No Payload');
      }
    }
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    if (kDebugMode) {
      print(
          '[NotificationService] Notification Tapped (terminated) - Payload: ${notificationResponse.payload}');
    }
    // Xử lý khi ứng dụng ở trạng thái terminated
    final payload = notificationResponse.payload;
    if (payload == 'reconnect_success') {
      // Lưu ý: Điều hướng ở đây cần được xử lý sau khi ứng dụng khởi động
      // Có thể lưu payload vào SharedPreferences để xử lý trong main.dart
      if (kDebugMode) {
        print(
            '[NotificationService] Background: reconnect_success detected. Deferring navigation.');
      }
    }
  }

  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {
    if (kDebugMode) {
      print(
          "[NotificationService] Received notification (iOS < 10): ID $id, Title: $title");
    }
  }

  Future<bool> requestPermissions() async {
    if (!_initialized) {
      if (kDebugMode) print("[NotificationService] Not initialized.");
      return false;
    }
    if (_permissionRequested) {
      if (kDebugMode)
        print(
            "[NotificationService] Permissions already requested: $_permissionGranted");
      return _permissionGranted;
    }

    if (kDebugMode) print("[NotificationService] Requesting permissions...");
    bool? granted = false;

    try {
      if (Platform.isIOS || Platform.isMacOS) {
        granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        granted ??= await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
      } else if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        granted = await androidImplementation?.requestNotificationsPermission();
        granted ??= true;
      }
    } catch (e) {
      if (kDebugMode)
        print("!!! [NotificationService] Error requesting permissions: $e");
      granted = false;
    }

    _permissionGranted = granted ?? false;
    _permissionRequested = true;
    if (kDebugMode)
      print(
          "[NotificationService] Permission request complete: $_permissionGranted");
    return _permissionGranted;
  }

  Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'default_channel',
    String channelName = 'General Notifications',
    String? channelDescription = 'General app notifications',
    String? payload,
  }) async {
    if (!_initialized) {
      if (kDebugMode) print("[NotificationService] Not initialized.");
      return;
    }
    if (!_permissionGranted) {
      if (kDebugMode)
        print("[NotificationService] Permission not granted. Requesting...");
      bool granted = await requestPermissions();
      if (!granted) {
        if (kDebugMode) print("[NotificationService] Permission denied.");
        return;
      }
    }

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notification_icon',
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    try {
      await _flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      if (kDebugMode)
        print(
            "[NotificationService] Notification displayed (ID: $id). Title: $title");
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [NotificationService] Failed to display notification (ID: $id): $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      if (kDebugMode)
        print("[NotificationService] Notification cancelled (ID: $id).");
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [NotificationService] Failed to cancel notification (ID: $id): $e");
    }
  }

  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      if (kDebugMode)
        print("[NotificationService] All notifications cancelled.");
    } catch (e) {
      if (kDebugMode)
        print(
            "!!! [NotificationService] Failed to cancel all notifications: $e");
    }
  }
}
