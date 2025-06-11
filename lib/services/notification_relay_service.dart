// // lib/services/notification_relay_service.dart

// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:notification_listener_service/notification_listener_service.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// import 'ble_service.dart';
// import '../models/relay_data.dart';
// import '../app_constants.dart';

// class NotificationRelayService {
//   final BleService _bleService;
//   bool _isListenerRunning = false;

//   static const String googleMapsPackage = "com.google.android.apps.maps";

//   NotificationRelayService(this._bleService) {
//     print("[NotificationRelayService] Initialized.");
//     startListening();
//   }

//   void startListening() {
//     if (_isListenerRunning) return;
//     print("[NotificationRelayService] Starting to listen for notifications...");

//     NotificationListenerService.notificationsStream.listen(
//       // <<< SỬA ĐỔI QUAN TRỌNG: DÙNG KIỂU `dynamic` >>>
//       (dynamic event) {
//         // --- BƯỚC THÁM TỬ ---
//         // In ra kiểu dữ liệu thực tế của đối tượng event
//         print(
//             "🕵️‍ DETECTIVE LOG: Event runtimeType is [${event.runtimeType}]");
//         // In ra toàn bộ nội dung của event để xem cấu trúc
//         print("🕵️‍ DETECTIVE LOG: Event content is [${event.toString()}]");
//         // ----------------------

//         // Sau khi đã có thông tin, chúng ta sẽ xử lý nó như một Map
//         if (event is Map<String, dynamic>) {
//           _processEvent(event);
//         } else {
//           print(
//               "!!! [NotificationRelayService] Received event of unknown type: ${event.runtimeType}");
//         }
//       },
//       onError: (e) => print("!!! [NotificationRelayService] Stream Error: $e"),
//     );
//     _isListenerRunning = true;
//   }

//   /// Hàm bất đồng bộ để xử lý logic thực tế
//   Future<void> _processEvent(Map<String, dynamic> eventData) async {
//     if (_bleService.connectionStatus.value != BleConnectionStatus.connected) {
//       return;
//     }

//     final prefs = await SharedPreferences.getInstance();

//     final String? packageName = eventData['packageName'];
//     if (packageName == null) return;

//     if (packageName == googleMapsPackage) {
//       final bool isEnabled =
//           prefs.getBool(AppConstants.prefKeyRelayGoogleMapsEnabled) ?? false;
//       if (isEnabled) _handleGoogleMapsNotification(eventData);
//     }
//   }

//   void _handleGoogleMapsNotification(Map<String, dynamic> eventData) {
//     final String? title = eventData['title'];
//     final String? text = eventData['text'];

//     if (title == null || text == null) {
//       print(
//           "[NotificationRelayService] Ignored GMaps notification with null title/text.");
//       return;
//     }

//     // --- LOGIC PHÂN TÍCH GIỮ NGUYÊN ---
//     final timeAndDistanceRegex = RegExp(r"(\d+\s+min|\d+\s+hr).*\((.*?)\)");
//     final nextTurnDistanceRegex = RegExp(r"(?:·\s*)?([^·]+)$");

//     String totalTime = timeAndDistanceRegex.firstMatch(title)?.group(1) ?? "";
//     String totalDistance =
//         timeAndDistanceRegex.firstMatch(title)?.group(2) ?? "";
//     String nextTurnDistance =
//         nextTurnDistanceRegex.firstMatch(title)?.group(1)?.trim() ?? title;

//     String instruction = text;
//     NavigationDirection direction = _parseDirectionFromText(instruction);

//     final relayData = RelayData(
//       type: RelayDataType.googleMapsNavigation,
//       source: "Google Maps",
//       title: nextTurnDistance,
//       content: instruction,
//       iconId: direction.index,
//       time: totalTime.isNotEmpty ? totalTime : null,
//     );

//     print("[NotificationRelayService] Parsed GMaps Data: $relayData");
//     _bleService.sendRelayData(relayData);
//   }

//   NavigationDirection _parseDirectionFromText(String text) {
//     String lowerText = text.toLowerCase();
//     if (lowerText.contains("sharp left")) return NavigationDirection.sharpLeft;
//     if (lowerText.contains("sharp right"))
//       return NavigationDirection.sharpRight;
//     if (lowerText.contains("turn left") || lowerText.contains("on the left"))
//       return NavigationDirection.turnLeft;
//     if (lowerText.contains("turn right") || lowerText.contains("on the right"))
//       return NavigationDirection.turnRight;
//     if (lowerText.contains("u-turn")) return NavigationDirection.uTurn;
//     if (lowerText.contains("roundabout")) return NavigationDirection.roundabout;
//     if (lowerText.contains("keep left")) return NavigationDirection.keepLeft;
//     if (lowerText.contains("keep right")) return NavigationDirection.keepRight;
//     // if (lowerText.contains("straight")) return NavigationDirection.straight;
//     if (lowerText.contains("merge")) return NavigationDirection.merge;
//     if (lowerText.contains("fork")) return NavigationDirection.fork;
//     if (lowerText.contains("destination"))
//       return NavigationDirection.destination;
//     return NavigationDirection.unknown;
//   }

//   void dispose() {
//     print("[NotificationRelayService] Disposing.");
//   }
// }
