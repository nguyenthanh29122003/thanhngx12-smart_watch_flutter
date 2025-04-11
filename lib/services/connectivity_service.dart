// lib/services/connectivity_service.dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'; // Cho ValueNotifier (tùy chọn)

// Enum để biểu diễn trạng thái mạng đơn giản hơn (tùy chọn nhưng khuyến nghị)
enum NetworkStatus { online, offline }

class ConnectivityService {
  // --- Sử dụng StreamController để thông báo thay đổi ---
  // Dùng broadcast nếu có nhiều nơi muốn lắng nghe trực tiếp stream
  final StreamController<NetworkStatus> _networkStatusController =
      StreamController.broadcast();

  /// Stream phát ra NetworkStatus.online hoặc NetworkStatus.offline mỗi khi trạng thái thay đổi.
  Stream<NetworkStatus> get networkStatusStream =>
      _networkStatusController.stream;

  // --- Biến lưu trạng thái hiện tại ---
  NetworkStatus _currentStatus =
      NetworkStatus.offline; // Mặc định ban đầu là offline

  // --- Subscription để lắng nghe thay đổi từ plugin ---
  StreamSubscription? _connectivitySubscription;

  /// Constructor: Khởi tạo và bắt đầu lắng nghe trạng thái mạng.
  ConnectivityService() {
    _initialize(); // Gọi hàm khởi tạo bất đồng bộ
    print("ConnectivityService Initialized.");
  }

  // Hàm khởi tạo bất đồng bộ
  Future<void> _initialize() async {
    // Lấy trạng thái kết nối ban đầu khi service khởi tạo
    try {
      final initialResult = await Connectivity().checkConnectivity();
      _updateStatus(
        initialResult,
      ); // Cập nhật trạng thái ban đầu dựa trên kết quả kiểm tra
      print("Initial network status: $_currentStatus");
    } catch (e) {
      print("!!! Error checking initial connectivity: $e");
      _updateStatus(
        ConnectivityResult.none,
      ); // Đặt là offline nếu có lỗi khi kiểm tra ban đầu
    }

    // Lắng nghe những thay đổi trạng thái mạng trong tương lai
    _connectivitySubscription
        ?.cancel(); // Hủy subscription cũ nếu có (phòng trường hợp gọi lại _initialize)
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        print("Connectivity changed event received: $result");
        _updateStatus(result); // Gọi hàm cập nhật khi có thay đổi
      },
      onError: (error) {
        print("!!! Error listening to connectivity changes: $error");
        // Nếu stream báo lỗi, giả định là offline
        _updateStatus(ConnectivityResult.none);
      },
    );
  }

  // Hàm nội bộ để xử lý kết quả từ Connectivity và cập nhật trạng thái
  void _updateStatus(ConnectivityResult result) {
    // Xác định trạng thái online/offline
    NetworkStatus newStatus;
    if (result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn) {
      newStatus = NetworkStatus.online;
    } else {
      // Bao gồm ConnectivityResult.none và ConnectivityResult.bluetooth
      newStatus = NetworkStatus.offline;
    }

    // Chỉ cập nhật và thông báo nếu trạng thái thực sự thay đổi
    if (_currentStatus != newStatus) {
      print("Network Status changing: $_currentStatus -> $newStatus");
      _currentStatus = newStatus; // Cập nhật trạng thái nội bộ
      _networkStatusController.add(
        newStatus,
      ); // Phát sự kiện thay đổi qua Stream
    } else {
      // print("Network status unchanged: $newStatus"); // Bỏ log này nếu không cần
    }
  }

  /// Kiểm tra nhanh xem hiện tại có đang online hay không.
  bool isOnline() {
    return _currentStatus == NetworkStatus.online;
  }

  /// Lấy trạng thái NetworkStatus hiện tại (online hoặc offline).
  NetworkStatus getCurrentNetworkStatus() {
    return _currentStatus;
  }

  // Hàm dọn dẹp tài nguyên khi service không còn được sử dụng
  void dispose() {
    print("Disposing ConnectivityService...");
    _connectivitySubscription?.cancel(); // Hủy việc lắng nghe thay đổi
    _networkStatusController.close(); // Đóng StreamController
    print("ConnectivityService disposed.");
  }
}
