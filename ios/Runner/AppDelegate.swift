import Flutter
import UIKit
// --- THIẾU IMPORT NÀY ---
import flutter_local_notifications // <<< CẦN THÊM

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // --- THIẾU ĐOẠN CODE ĐĂNG KÝ NOTIFICATION Ở ĐÂY ---
    // Cần thêm code đăng ký delegate trước GeneratedPluginRegistrant

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}