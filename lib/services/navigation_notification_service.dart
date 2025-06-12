// lib/services/navigation_notification_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';

@pragma('vm:entry-point')
void notificationCallback(NotificationEvent evt) {
  // Để trống hoặc chỉ in log
}

class NavigationNotificationService {
  // <<< SỬA DÒNG NÀY: Đổi NotificationEvent thành dynamic >>>
  StreamSubscription<dynamic>? _subscription;
  // ----------------------------------------------------

  NavigationNotificationService() {
    if (kDebugMode) print("[NaviService-TESTER] Initializing...");
    init();
  }

  Future<void> init() async {
    await NotificationsListener.initialize(
        callbackHandle: notificationCallback);

    // Bây giờ phép gán này sẽ hợp lệ
    _subscription = NotificationsListener.receivePort?.listen((dynamic evt) {
      // Chúng ta vẫn kiểm tra kiểu bên trong để đảm bảo an toàn
      if (evt is NotificationEvent) {
        _onNotificationData(evt);
      }
    });

    await _startService();
  }

  Future<void> _startService() async {
    bool? hasPermission = await NotificationsListener.hasPermission;
    if (hasPermission != true) {
      if (kDebugMode)
        print("[NaviService-TESTER] No permission, opening settings...");
      await NotificationsListener.openPermissionSettings();
      return;
    }

    bool? isRunning = await NotificationsListener.isRunning;
    if (isRunning != true) {
      await NotificationsListener.startService(
        foreground: true,
        title: "Smart Wearable Service",
        description: "Listening for notifications...",
      );
      if (kDebugMode) print("[NaviService-TESTER] Service started.");
    }
  }

  void _onNotificationData(NotificationEvent event) {
    // Logic in log giữ nguyên, không thay đổi
    if (event.packageName?.contains('com.google.android.apps.maps') ?? false) {
      final rawData = event.raw;
      final String? title = event.title;
      final String? text = event.text;
      final String? subText = rawData?['subText'];
      final String? summaryText = rawData?['summaryText'];
      final List<String>? textLines = (rawData?['textLines'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList();
      final int? progress = rawData?['progress'];
      final int? progressMax = rawData?['progressMax'];
      final bool? progressIndeterminate = rawData?['progressIndeterminate'];

      print(
          "==================== NEW GOOGLE MAPS NOTIFICATION ====================");
      print("  - Time: ${DateTime.now()}");
      print("  - Package: ${event.packageName}");
      print("  ------------------- Standard Fields -------------------");
      print("  - Title:        '$title'");
      print("  - Text:         '$text'");
      print("  --------------------- Raw Extras ----------------------");
      print("  - SubText:      '$subText'");
      print("  - SummaryText:  '$summaryText'");
      print("  - TextLines:    $textLines");
      print("  - Progress:     $progress");
      print("  - ProgressMax:  $progressMax");
      print("  - ProgressIndet:$progressIndeterminate");
      print(
          "======================================================================\n");
    }
  }

  void dispose() {
    if (kDebugMode) print("[NaviService-TESTER] Disposing...");
    _subscription?.cancel();
  }
}
