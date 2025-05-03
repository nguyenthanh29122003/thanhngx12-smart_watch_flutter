// lib/services/notification_service.dart
import 'package:flutter/foundation.dart'; // Cho kDebugMode
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io' show Platform; // Để kiểm tra nền tảng

class NotificationService {
  // --- Singleton Pattern ---
  // Đảm bảo chỉ có một instance của NotificationService trong toàn bộ ứng dụng.
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  // -------------------------

  // Instance của plugin thông báo
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Cờ trạng thái nội bộ của service
  bool _initialized = false;
  bool _permissionRequested = false;
  bool _permissionGranted = false;

  /// Lấy trạng thái quyền thông báo hiện tại (sau khi đã yêu cầu).
  bool get permissionGranted => _permissionGranted;

  /// Khởi tạo NotificationService.
  /// Cần được gọi một lần khi ứng dụng khởi động (ví dụ: trong main.dart).
  Future<void> init() async {
    // Nếu đã khởi tạo rồi thì không làm gì cả
    if (_initialized) {
      if (kDebugMode) {
        print("[NotificationService] Already initialized.");
      }
      return;
    }

    // 1. --- Cài đặt khởi tạo cho từng nền tảng ---

    // Android: Cần tên file icon trong thư mục drawable (không có đuôi file)
    // !!! QUAN TRỌNG: Đảm bảo bạn đã tạo file 'app_icon.png' (hoặc tên khác)
    // trong thư mục android/app/src/main/res/drawable/
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            'notification_icon'); // <<< THAY 'app_icon' NẾU TÊN FILE ICON KHÁC

    // iOS & macOS: Cấu hình cách xử lý quyền và callback
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission:
          false, // Không yêu cầu quyền ngay, sẽ yêu cầu tường minh
      requestBadgePermission: false,
      requestSoundPermission: false,
      onDidReceiveLocalNotification:
          _onDidReceiveLocalNotification, // Callback cho iOS < 10 foreground
    );

    // Kết hợp cài đặt cho các nền tảng
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS:
          initializationSettingsDarwin, // Áp dụng tương tự cho macOS nếu hỗ trợ
    );

    // 2. --- Khởi tạo plugin với các cài đặt và callbacks ---
    try {
      await _flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        // Callback khi người dùng nhấn vào thông báo (khi app đang chạy/nền)
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
        // Callback khi người dùng nhấn vào thông báo (khi app bị tắt hoàn toàn)
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );
      _initialized = true; // Đánh dấu đã khởi tạo thành công
      if (kDebugMode) {
        print("[NotificationService] Initialization successful.");
      }

      // 3. --- Yêu cầu quyền sau khi khởi tạo ---
      // Chúng ta gọi riêng hàm này để có thể kiểm soát thời điểm hỏi quyền
      await requestPermissions();
    } catch (e) {
      if (kDebugMode) {
        print("!!! [NotificationService] Initialization failed: $e");
      }
      // Xử lý lỗi khởi tạo nếu cần
    }
  }

  /// Callback xử lý khi người dùng chạm vào thông báo (App đang chạy hoặc nền).
  void _onDidReceiveNotificationResponse(
      NotificationResponse notificationResponse) {
    final String? payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      if (kDebugMode) {
        print(
            '[NotificationService] Notification Tapped (running/background) - Payload: $payload');
      }
      // TODO: Xử lý payload ở đây (ví dụ: điều hướng màn hình)
      // Ví dụ: if (payload == 'hr_alert') { navigatorKey?.currentState?.pushNamed('/health_details'); }
    } else {
      if (kDebugMode) {
        print(
            '[NotificationService] Notification Tapped (running/background) - No Payload');
      }
    }
  }

  /// Callback xử lý khi người dùng chạm vào thông báo (App đã bị tắt hoàn toàn).
  /// Cần đánh dấu @pragma('vm:entry-point') để hoạt động đúng.
  @pragma('vm:entry-point')
  static void notificationTapBackground(
      NotificationResponse notificationResponse) {
    // Lưu ý: Logic ở đây cần đơn giản vì app đang khởi chạy lại từ đầu.
    // Thường dùng để lưu trữ thông tin hoặc thực hiện hành động rất cơ bản.
    if (kDebugMode) {
      print(
          '[NotificationService] Notification Tapped (terminated) - Payload: ${notificationResponse.payload}');
    }
    // Ví dụ: Lưu payload vào SharedPreferences để xử lý khi app khởi động xong
    // SharedPreferences.getInstance().then((prefs) {
    //   prefs.setString('tapped_notification_payload', notificationResponse.payload ?? '');
    // });
  }

  /// Callback xử lý khi nhận thông báo lúc app đang chạy ở foreground (chỉ dành cho iOS < 10).
  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Với iOS 10+, thông báo sẽ tự hiển thị. Hàm này chủ yếu cho các phiên bản cũ hơn.
    if (kDebugMode) {
      print(
          "[NotificationService] Received notification while app is in foreground (iOS < 10): ID $id, Title: $title");
    }
    // Có thể hiển thị một dialog, snackbar hoặc không làm gì cả tùy theo yêu cầu UX.
  }

  /// Yêu cầu quyền gửi thông báo từ người dùng (cho iOS và Android 13+).
  Future<bool> requestPermissions() async {
    // Chỉ yêu cầu nếu đã khởi tạo và chưa yêu cầu trước đó
    if (!_initialized) {
      if (kDebugMode) {
        print(
            "[NotificationService] Cannot request permissions: Not initialized.");
      }
      return false;
    }
    if (_permissionRequested) {
      if (kDebugMode) {
        print(
            "[NotificationService] Permissions already requested. Granted: $_permissionGranted");
      }
      return _permissionGranted; // Trả về trạng thái đã lưu
    }

    if (kDebugMode) {
      print("[NotificationService] Requesting notification permissions...");
    }
    bool? granted = false;

    try {
      if (Platform.isIOS || Platform.isMacOS) {
        // Yêu cầu quyền cụ thể cho iOS/macOS
        granted = await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true, // Yêu cầu hiển thị thông báo
              badge: true, // Yêu cầu cập nhật badge icon
              sound: true, // Yêu cầu phát âm thanh
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
        // Yêu cầu quyền cho Android (plugin tự xử lý Android 13+)
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>();
        // Hàm này sẽ hiện dialog yêu cầu quyền trên Android 13+
        granted = await androidImplementation?.requestNotificationsPermission();
        // Đối với Android < 13, quyền được cấp mặc định, hàm này trả về true (hoặc null nếu có lỗi)
        granted ??=
            true; // Giả định là true nếu không phải Android 13+ hoặc implementation null
      }
    } catch (e) {
      if (kDebugMode) {
        print("!!! [NotificationService] Error requesting permissions: $e");
      }
      granted = false;
    }

    _permissionGranted =
        granted ?? false; // Lưu kết quả (mặc định là false nếu null)
    _permissionRequested = true; // Đánh dấu là đã yêu cầu
    if (kDebugMode) {
      print(
          "[NotificationService] Permission request complete. Granted: $_permissionGranted");
    }
    return _permissionGranted;
  }

  /// Hiển thị một thông báo đơn giản với tiêu đề và nội dung.
  ///
  /// - [id]: ID số nguyên *duy nhất* cho thông báo này. Nếu hiển thị thông báo mới
  ///   với cùng ID, thông báo cũ sẽ bị cập nhật/thay thế.
  /// - [title]: Tiêu đề của thông báo.
  /// - [body]: Nội dung chính của thông báo.
  /// - [channelId]: ID của kênh thông báo Android (nên đặt theo loại thông báo).
  /// - [channelName]: Tên kênh thông báo Android (hiển thị cho người dùng).
  /// - [channelDescription]: Mô tả kênh thông báo Android.
  /// - [payload]: Dữ liệu chuỗi tùy chọn để gửi kèm, dùng để xử lý khi người dùng nhấn vào.
  Future<void> showSimpleNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'default_channel', // Kênh mặc định
    String channelName = 'General Notifications',
    String? channelDescription = 'General app notifications',
    String? payload,
  }) async {
    // Kiểm tra khởi tạo và quyền trước khi hiển thị
    if (!_initialized) {
      if (kDebugMode) {
        print(
            "[NotificationService] Cannot show notification: Not initialized.");
      }
      return;
    }
    if (!_permissionGranted) {
      if (kDebugMode) {
        print(
            "[NotificationService] Cannot show notification: Permission not granted.");
      }
      // Cân nhắc: Có nên thử yêu cầu lại quyền ở đây không?
      // bool granted = await requestPermissions();
      // if (!granted) return;
      return; // Không hiển thị nếu chưa được cấp quyền
    }

    // --- Định nghĩa chi tiết thông báo cho Android ---
    // Quan trọng: Mỗi kênh (channelId) chỉ cần tạo một lần,
    // nhưng việc định nghĩa lại ở đây không gây hại.
    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      channelId, // Ví dụ: 'health_alerts_channel'
      channelName, // Ví dụ: 'Health Alerts'
      channelDescription: channelDescription,
      // --- ĐẢM BẢO HAI DÒNG NÀY CÓ GIÁ TRỊ CAO ---
      importance: Importance.max, // <<< QUAN TRỌNG: Dùng .max hoặc .high
      priority: Priority.high, // <<< QUAN TRỌNG: Dùng .high
      // ---------------------------------------------
      icon: 'notification_icon', // Thay bằng tên icon của bạn
      styleInformation:
          BigTextStyleInformation(body), // Hiển thị nội dung dài hơn
      // ... các tùy chọn khác ...
    );
    // final AndroidNotificationDetails androidNotificationDetails =
    //     AndroidNotificationDetails(
    //   channelId,
    //   channelName,
    //   channelDescription: channelDescription,
    //   importance: Importance.max, // Hiển thị thông báo một cách nổi bật
    //   priority: Priority.high, // Ưu tiên cao
    //   icon:
    //       'notification_icon', // Icon hiển thị trên status bar (phải tồn tại trong drawable)
    //   // Tùy chọn khác:
    //   // largeIcon: const DrawableResourceAndroidBitmap('large_icon'), // Icon lớn hơn hiển thị trong thông báo
    //   // styleInformation: BigTextStyleInformation(body), // Hiển thị nội dung dài hơn
    //   // actions: [...], // Thêm nút hành động
    //   // sound: ..., // Âm thanh tùy chỉnh
    //   // enableVibration: true, // Bật rung
    // );

    // --- Định nghĩa chi tiết thông báo cho iOS/macOS ---
    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true, // Hiển thị nội dung thông báo
      presentBadge: true, // Cho phép cập nhật badge trên icon app
      presentSound: true, // Phát âm thanh mặc định
      // sound: 'custom_sound.aiff', // Âm thanh tùy chỉnh nếu có
      // badgeNumber: 1, // Đặt số cụ thể cho badge
    );

    // --- Kết hợp chi tiết cho các nền tảng ---
    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
      macOS: darwinNotificationDetails,
    );

    // --- Hiển thị thông báo ---
    try {
      await _flutterLocalNotificationsPlugin.show(
        id, // ID của thông báo
        title, // Tiêu đề
        body, // Nội dung
        notificationDetails, // Chi tiết đã cấu hình
        payload: payload, // Dữ liệu kèm theo (nếu có)
      );
      if (kDebugMode) {
        print(
            "[NotificationService] Notification displayed successfully (ID: $id). Title: $title");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "!!! [NotificationService] Failed to display notification (ID: $id): $e");
      }
    }
  }

  // --- Các hàm tiện ích khác (ví dụ) ---

  /// Hủy một thông báo cụ thể bằng ID của nó.
  Future<void> cancelNotification(int id) async {
    if (!_initialized) return;
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      if (kDebugMode) {
        print("[NotificationService] Notification cancelled (ID: $id).");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "!!! [NotificationService] Failed to cancel notification (ID: $id): $e");
      }
    }
  }

  /// Hủy tất cả thông báo mà ứng dụng đã hiển thị.
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      if (kDebugMode) {
        print("[NotificationService] All notifications cancelled.");
      }
    } catch (e) {
      if (kDebugMode) {
        print(
            "!!! [NotificationService] Failed to cancel all notifications: $e");
      }
    }
  }
}
