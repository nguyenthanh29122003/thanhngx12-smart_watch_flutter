// lib/services/navigation_notification_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../models/navigation_data.dart';
import 'ble_service.dart';

@pragma('vm:entry-point')
void notificationCallback(NotificationEvent evt) {}

class NavigationNotificationService {
  // --- Singleton Pattern ---
  static final NavigationNotificationService _instance =
      NavigationNotificationService._internal();
  factory NavigationNotificationService() => _instance;
  NavigationNotificationService._internal() {
    // Constructor này bây giờ sẽ gọi init một lần duy nhất.
    init();
  }

  BleService? _bleService;
  StreamSubscription<dynamic>? _subscription;
  NavigationData? _lastSentData;
  NavigationData? _lastReceivedData;
  Timer? _throttleTimer;
  bool _isReadyToSend = true;
  static const Duration _throttleDuration = Duration(milliseconds: 1500);

  bool _isInitialized = false;

  // Hàm này bây giờ chỉ có nhiệm vụ cập nhật dependency
  void setBleService(BleService bleService) {
    _bleService = bleService;
    if (kDebugMode) print("[NaviService] BleService dependency was updated.");
  }

  Future<void> init() async {
    // Đảm bảo logic khởi tạo chỉ chạy một lần trong suốt vòng đời của app
    if (_isInitialized) return;
    _isInitialized = true;

    if (kDebugMode)
      print("[NaviService] Singleton first-time initialization...");

    try {
      await NotificationsListener.initialize(
          callbackHandle: notificationCallback);
      _subscription?.cancel();
      _subscription = NotificationsListener.receivePort?.listen((dynamic evt) {
        if (evt is NotificationEvent) {
          _onNotificationReceived(evt);
        }
      });
      await _startService();
    } catch (e) {
      if (kDebugMode) print("!!! [NaviService] Error during init: $e");
    }
  }

  // Hàm startService giữ nguyên
  Future<void> _startService() async {
    bool? hasPermission = await NotificationsListener.hasPermission;
    if (hasPermission != true) {
      await NotificationsListener.openPermissionSettings();
      return;
    }

    bool? isRunning = await NotificationsListener.isRunning;
    if (isRunning != true) {
      await NotificationsListener.startService(
        foreground: false,
        title: "Smart Wearable Service",
        description: "Listening for map notifications...",
      );
    }
  }

  // <<< BƯỚC 2.4: THÊM LẠI CÁC HÀM LOGIC (GIỮ NGUYÊN) >>>
  // Các hàm này bây giờ sẽ hoạt động đúng trong môi trường Singleton.

  void _onNotificationReceived(NotificationEvent event) {
    if (_bleService == null) return; // Không làm gì nếu chưa có dependency

    if (event.packageName?.contains('com.google.android.apps.maps') ?? false) {
      final navData = _parseGoogleMapsNotification(event);
      if (navData != null) {
        _lastReceivedData = navData;
        if (_isReadyToSend) {
          _sendData(navData);
        }
      }
    }
  }

  void _sendData(NavigationData data) {
    if (data == _lastSentData) return;
    if (_bleService == null) return;

    if (kDebugMode) print("[NaviService] SENDING DATA: ${data.toString()}");

    _bleService!.sendNavigationData(data); // Dùng ! vì đã kiểm tra null
    _lastSentData = data;

    _isReadyToSend = false;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(_throttleDuration, () {
      _isReadyToSend = true;
      if (_lastReceivedData != null && _lastReceivedData != _lastSentData) {
        _sendData(_lastReceivedData!);
      }
    });
  }

  NavigationData? _parseGoogleMapsNotification(NotificationEvent event) {
    final title = event.title?.trim() ?? '';
    final text = event.text?.trim() ?? '';
    final subText = (event.raw?['subText'] as String?)?.trim() ?? '';

    if (text.contains('Đang định tuyến lại')) {
      if (kDebugMode) print("[NaviParser] Ignoring 'rerouting' notification.");
      return null;
    }
    // Bỏ qua nếu không có thông tin gì cả
    if (title.isEmpty && text.isEmpty && subText.isEmpty) return null;

    String totalRemainingTime = '';
    String totalRemainingDistance = '';
    String eta = '';

    final subTextRegex = RegExp(r"(.+?)\s·\s(.+?)\s·\s(.+)");
    final subTextMatch = subTextRegex.firstMatch(subText);
    if (subTextMatch != null) {
      totalRemainingTime = subTextMatch.group(1)?.trim() ?? '';
      totalRemainingDistance = subTextMatch.group(2)?.trim() ?? '';
      eta = subTextMatch.group(3)?.trim() ?? '';
    }

    String nextTurnDistance =
        title.isNotEmpty ? title : "Ngay"; // "Now" -> "Ngay"
    String nextTurnDirection = '';
    String streetName = '';

    const actionKeywords = [
      'Rẽ trái',
      'Rẽ phải',
      'Đi thẳng',
      'Đi về bên trái',
      'Đi về bên phải',
      'Lối ra',
      'Quay đầu'
    ];

    bool isAction = actionKeywords.any((keyword) => text.startsWith(keyword));

    if (isAction) {
      nextTurnDirection = text;
      // Khi có hành động rẽ rõ ràng, thường không có tên đường đi kèm trong trường 'text'
      streetName = '';
    } else {
      // Nếu không, coi 'text' là chỉ dẫn chung hoặc tên đường.
      // Chúng ta sẽ đặt nó vào 'nextTurnDirection' để hiển thị.
      nextTurnDirection = text;
      // Ví dụ: 'vào Đ. Pasteur' hoặc 'Trần Quốc Nghiễn'
      if (text.startsWith("vào ")) {
        streetName = text; // Nếu có chữ "vào", có thể coi là tên đường
        nextTurnDirection = ""; // Để trống chỉ dẫn chính
      } else {
        streetName = "";
      }
    }

    return NavigationData(
      nextTurnDistance: nextTurnDistance,
      nextTurnDirection: nextTurnDirection,
      streetName: streetName,
      totalRemainingDistance: totalRemainingDistance,
      totalRemainingTime: totalRemainingTime,
      eta: eta,
    );
  }

  // Hàm dispose bây giờ có thể để trống, vì Singleton sẽ sống suốt vòng đời app
  void dispose() {
    if (kDebugMode)
      print("[NaviService] dispose() called, but singleton instance lives on.");
  }
}
