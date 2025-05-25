// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'Ứng dụng Đeo Thông minh';

  @override
  String get settingsTitle => 'Cài đặt';

  @override
  String get dashboardTitle => 'Bảng điều khiển';

  @override
  String get relativesTitle => 'Người thân';

  @override
  String get goalsTitle => 'Mục tiêu';

  @override
  String get loginTitle => 'Đăng nhập';

  @override
  String get selectDeviceTitle => 'Chọn Thiết bị';

  @override
  String get configureWifiTitle => 'Cấu hình WiFi Thiết bị';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get appearance => 'Giao diện';

  @override
  String get systemDefault => 'Mặc định Hệ thống';

  @override
  String get lightMode => 'Chế độ Sáng';

  @override
  String get darkMode => 'Chế độ Tối';

  @override
  String get logout => 'Đăng xuất';

  @override
  String get addRelative => 'Thêm Người thân';

  @override
  String get name => 'Tên';

  @override
  String get relationship => 'Mối quan hệ';

  @override
  String get cancel => 'Hủy';

  @override
  String get add => 'Thêm';

  @override
  String get delete => 'Xóa';

  @override
  String get confirmDeletion => 'Xác nhận Xóa';

  @override
  String confirmDeleteRelative(String relativeName, String relativeRelationship) {
    return 'Bạn chắc chắn muốn xóa $relativeName ($relativeRelationship)?';
  }

  @override
  String get relativeAddedSuccess => 'Đã thêm người thân thành công!';

  @override
  String get relativeAddedError => 'Thêm người thân thất bại.';

  @override
  String get relativeDeletedSuccess => 'Đã xóa người thân.';

  @override
  String get relativeDeletedError => 'Xóa người thân thất bại.';

  @override
  String get confirmLogoutTitle => 'Xác nhận Đăng xuất';

  @override
  String get confirmLogoutMessage => 'Bạn có chắc chắn muốn đăng xuất?';

  @override
  String get confirm => 'Đồng ý';

  @override
  String get chatbotTitle => 'Trò chuyện với AI';

  @override
  String get predictTitle => 'Dự đoán';

  @override
  String get connectDevice => 'Kết nối Thiết bị';

  @override
  String get predictPlaceholder => 'Chức năng dự đoán đang được phát triển!';

  @override
  String get sendMessage => 'Gửi';

  @override
  String get enterMessage => 'Nhập tin nhắn hoặc câu hỏi của bạn';

  @override
  String get imageUrlLabel => 'Nhập URL hình ảnh (tùy chọn)';

  @override
  String get errorSendingMessage => 'Lỗi khi gửi tin nhắn';

  @override
  String get healthDisclaimer => 'Đây là thông tin chung, không phải lời khuyên y tế. Hãy tham khảo ý kiến bác sĩ để được tư vấn chuyên nghiệp.';

  @override
  String get relativesScreenTitle => 'Người thân';

  @override
  String get addRelativeTooltip => 'Thêm Người thân';

  @override
  String get addRelativeDialogTitle => 'Thêm Người thân Mới';

  @override
  String get relativeNameLabel => 'Tên';

  @override
  String get relativeNameHint => 'Nhập họ và tên người thân';

  @override
  String get relativeNameValidation => 'Vui lòng nhập tên';

  @override
  String get relationshipLabel => 'Mối quan hệ';

  @override
  String get relationshipHint => 'Chọn mối quan hệ';

  @override
  String get relationshipValidation => 'Vui lòng chọn mối quan hệ';

  @override
  String get addRelativeButton => 'Thêm Người thân';

  @override
  String get deleteButton => 'Xóa';

  @override
  String get deleteRelativeConfirmationTitle => 'Xác nhận Xóa';

  @override
  String relativeDeletedSnackbar(String relativeName) {
    return 'Đã xóa người thân \'$relativeName\'.';
  }

  @override
  String get pleaseLoginRelatives => 'Vui lòng đăng nhập để quản lý người thân.';

  @override
  String get noRelativesYet => 'Chưa có người thân nào.';

  @override
  String get addFirstRelativeHint => 'Nhấn nút + phía trên để thêm người thân đầu tiên.';

  @override
  String get addRelativeEmptyButton => 'Thêm Người thân';

  @override
  String deleteRelativeTooltip(String relativeName) {
    return 'Xóa $relativeName';
  }

  @override
  String get editRelativeDialogTitle => 'Sửa Người thân';

  @override
  String get saveChangesButton => 'Lưu Thay đổi';

  @override
  String get relativeUpdatedSuccess => 'Đã cập nhật người thân thành công!';

  @override
  String get relativeUpdatedError => 'Cập nhật người thân thất bại.';

  @override
  String editRelativeTooltip(String relativeName) {
    return 'Sửa $relativeName';
  }

  @override
  String get relationFather => 'Bố';

  @override
  String get relationMother => 'Mẹ';

  @override
  String get relationSon => 'Con trai';

  @override
  String get relationDaughter => 'Con gái';

  @override
  String get relationBrother => 'Anh/Em trai';

  @override
  String get relationSister => 'Chị/Em gái';

  @override
  String get relationGrandfather => 'Ông';

  @override
  String get relationGrandmother => 'Bà';

  @override
  String get relationFriend => 'Bạn bè';

  @override
  String get relationSpouse => 'Vợ/Chồng';

  @override
  String get relationPartner => 'Bạn đời';

  @override
  String get relationGuardian => 'Người giám hộ';

  @override
  String get relationDoctor => 'Bác sĩ';

  @override
  String get relationCaregiver => 'Người chăm sóc';

  @override
  String get relationOther => 'Khác';

  @override
  String get sectionDeviceManagement => 'Quản lý Thiết bị';

  @override
  String get sectionNetwork => 'Mạng';

  @override
  String get sectionNotifications => 'Thông báo';

  @override
  String get noDeviceConnected => 'Chưa kết nối Thiết bị';

  @override
  String get connectPrompt => 'Kết nối qua \"Đổi Thiết bị\"';

  @override
  String get disconnectButton => 'Ngắt kết nối';

  @override
  String get changeForgetDevice => 'Đổi / Quên Thiết bị';

  @override
  String get connectDeviceFirstSnackbar => 'Vui lòng kết nối thiết bị trước.';

  @override
  String get noEmail => 'Không có Email';

  @override
  String welcomeUser(String userName) {
    return 'Chào mừng, $userName!';
  }

  @override
  String get defaultUser => 'Người dùng';

  @override
  String get bleStatusConnected => 'BLE: Đã kết nối';

  @override
  String get bleStatusConnecting => 'BLE: Đang kết nối';

  @override
  String get bleStatusDisconnected => 'BLE: Đã ngắt';

  @override
  String get bleStatusScanning => 'BLE: Đang quét';

  @override
  String get bleStatusError => 'BLE: Lỗi';

  @override
  String get bleStatusUnknown => 'BLE: Không rõ';

  @override
  String get wifiStatusOn => 'WiFi Bật';

  @override
  String get wifiStatusOff => 'WiFi Tắt';

  @override
  String get testNotificationButton => 'Thử Thông báo';

  @override
  String get testNotificationSent => 'Đã gửi thông báo thử! Kiểm tra hệ thống.';

  @override
  String get goalProgressTitle => 'Tiến độ Mục tiêu Ngày';

  @override
  String get goalLoading => 'Đang tải mục tiêu...';

  @override
  String get stepsCalculating => 'Đang tính số bước...';

  @override
  String stepsProgress(String steps, String goal) {
    return 'Bước: $steps / $goal';
  }

  @override
  String get errorNavigateGoals => 'Không thể điều hướng đến màn hình Mục tiêu.';

  @override
  String get realtimeMetricsTitle => 'Chỉ số Thời gian thực';

  @override
  String get heartRateLabel => 'Nhịp tim';

  @override
  String get spo2Label => 'SpO2';

  @override
  String get stepsLabel => 'Số bước';

  @override
  String get lastUpdatedPrefix => 'Cập nhật:';

  @override
  String get waitingForData => 'Đã kết nối. Đang chờ dữ liệu...';

  @override
  String get connectingStatus => 'Đang kết nối...';

  @override
  String get connectionErrorStatus => 'Lỗi kết nối.';

  @override
  String get disconnectedStatus => 'Thiết bị đã ngắt kết nối.';

  @override
  String get hrHistoryTitle => 'Lịch sử Nhịp tim (24 giờ qua)';

  @override
  String get spo2HistoryTitle => 'Lịch sử SpO₂ (24 giờ qua)';

  @override
  String get stepsHistoryTitle => 'Số bước Mỗi giờ (24 giờ qua)';

  @override
  String get chartErrorPrefix => 'Lỗi:';

  @override
  String get chartCouldNotLoad => 'Không thể tải lịch sử';

  @override
  String get chartNoDataPeriod => 'Không có dữ liệu lịch sử cho khoảng thời gian này.';

  @override
  String get chartNoValidHr => 'Không tìm thấy dữ liệu nhịp tim hợp lệ trong khoảng này.';

  @override
  String chartNoValidSpo2(int minSpo2) {
    return 'Không tìm thấy dữ liệu SpO₂ hợp lệ (>= $minSpo2%) trong khoảng này.';
  }

  @override
  String get chartNoStepsCalculated => 'Không có dữ liệu bước được tính cho khoảng này.';

  @override
  String get emailLabel => 'Email';

  @override
  String get emailValidation => 'Vui lòng nhập email hợp lệ';

  @override
  String get passwordLabel => 'Mật khẩu';

  @override
  String get passwordValidation => 'Mật khẩu phải có ít nhất 6 ký tự';

  @override
  String get signInButton => 'Đăng nhập';

  @override
  String get signInWithGoogleButton => 'Đăng nhập với Google';

  @override
  String get signUpPrompt => 'Chưa có tài khoản? Đăng ký';

  @override
  String get forgotPasswordPrompt => 'Quên mật khẩu?';

  @override
  String loginFailedError(String errorDetails) {
    return 'Đăng nhập Thất bại: $errorDetails';
  }

  @override
  String get signUpTitle => 'Đăng ký';

  @override
  String get displayNameLabel => 'Tên hiển thị';

  @override
  String get displayNameValidation => 'Vui lòng nhập tên của bạn';

  @override
  String get confirmPasswordLabel => 'Xác nhận Mật khẩu';

  @override
  String get confirmPasswordValidationEmpty => 'Vui lòng xác nhận mật khẩu';

  @override
  String get confirmPasswordValidationMatch => 'Mật khẩu không khớp';

  @override
  String get signUpButton => 'Đăng ký';

  @override
  String get loginPrompt => 'Đã có tài khoản? Đăng nhập';

  @override
  String get resetPasswordDialogTitle => 'Đặt lại Mật khẩu';

  @override
  String get enterYourEmailHint => 'Nhập email tài khoản của bạn';

  @override
  String get sendResetEmailButton => 'Gửi Email Đặt lại';

  @override
  String resetEmailSentSuccess(String email) {
    return 'Email đặt lại mật khẩu đã được gửi đến $email. Vui lòng kiểm tra hộp thư đến (và thư mục spam).';
  }

  @override
  String resetEmailSentError(String errorDetails) {
    return 'Gửi email đặt lại thất bại: $errorDetails';
  }

  @override
  String get wifiConfigInstruction => 'Nhập thông tin mạng WiFi cho thiết bị ESP32 của bạn.';

  @override
  String get wifiSsidLabel => 'Tên mạng WiFi (SSID)';

  @override
  String get wifiSsidHint => 'VD: MyHomeWiFi';

  @override
  String get wifiSsidValidation => 'Vui lòng nhập tên mạng WiFi';

  @override
  String get wifiPasswordLabel => 'Mật khẩu WiFi';

  @override
  String get wifiPasswordValidationLength => 'Mật khẩu cần ít nhất 8 ký tự';

  @override
  String get wifiOpenNetworkCheckbox => 'Đây là mạng mở (không có mật khẩu)';

  @override
  String get sendWifiConfigButton => 'Gửi Cấu hình';

  @override
  String get deviceNotConnectedToSend => 'Cần kết nối thiết bị để gửi cấu hình.';

  @override
  String get wifiConfigSentSuccess => 'Đã gửi cấu hình WiFi!';

  @override
  String get wifiConfigSentError => 'Gửi cấu hình thất bại.';

  @override
  String get wifiConfigDeviceNotConnectedError => 'Thiết bị chưa kết nối. Vui lòng kết nối trước.';

  @override
  String get scanDevicesButton => 'Quét Thiết bị';

  @override
  String get stopScanButton => 'Dừng Quét';

  @override
  String get scanningTooltip => 'Đang quét...';

  @override
  String get scanTooltip => 'Quét thiết bị';

  @override
  String get scanningStatus => 'Đang quét thiết bị...';

  @override
  String get statusDisconnectedScan => 'Đã ngắt kết nối. Nhấn quét.';

  @override
  String get statusConnecting => 'Đang kết nối...';

  @override
  String get statusSettingUp => 'Đang thiết lập...';

  @override
  String get statusConnected => 'Đã kết nối!';

  @override
  String get statusErrorPermissions => 'Lỗi. Kiểm tra quyền/Bluetooth.';

  @override
  String get statusUnknown => 'Không xác định';

  @override
  String get noDevicesFound => 'Không tìm thấy thiết bị nào.';

  @override
  String get ensureDeviceNearby => 'Đảm bảo thiết bị của bạn đã bật và ở gần.';

  @override
  String get pullToScan => 'Kéo xuống để quét lại.';

  @override
  String get availableDevices => 'Thiết bị Khả dụng';

  @override
  String get unknownDeviceName => 'Thiết bị không rõ';

  @override
  String get deviceIdPrefix => 'ID:';

  @override
  String get connectButton => 'Kết nối';

  @override
  String get connectingStatusDevice => 'Đang kết nối...';

  @override
  String get enableBluetoothPrompt => 'Vui lòng bật Bluetooth để quét thiết bị.';

  @override
  String get permissionRequiredPrompt => 'Cần cấp quyền Vị trí và Bluetooth để tìm thiết bị xung quanh. Vui lòng cấp quyền trong cài đặt ứng dụng.';

  @override
  String get permissionDeniedSnackbar => 'Các quyền cần thiết bị từ chối. Vui lòng cấp quyền trong cài đặt.';

  @override
  String get connectionFailedTitle => 'Kết nối Thất bại';

  @override
  String connectionFailedMessage(String deviceName) {
    return 'Không thể kết nối đến $deviceName. Vui lòng đảm bảo thiết bị ở gần và thử lại.';
  }

  @override
  String get connectionFailedSnackbar => 'Kết nối thiết bị thất bại. Vui lòng thử lại.';

  @override
  String get connectionTimeout => 'Kết nối quá thời gian. Vui lòng thử lại.';

  @override
  String get deviceDisconnectedUnexpectedly => 'Thiết bị đột ngột ngắt kết nối.';

  @override
  String get bluetoothRequiredTitle => 'Yêu cầu Bluetooth';

  @override
  String get bluetoothRequiredMessage => 'Ứng dụng này yêu cầu bật Bluetooth để quét thiết bị.';

  @override
  String get turnOnButton => 'Bật';

  @override
  String get enableBluetoothIOS => 'Vui lòng bật Bluetooth trong cài đặt hệ thống.';

  @override
  String get dailyStepGoalCardTitle => 'Mục tiêu Bước chân Ngày';

  @override
  String get setNewGoalTooltip => 'Đặt Mục tiêu Mới';

  @override
  String get stepsUnit => 'bước';

  @override
  String get goalAchievedMessage => 'Đã đạt Mục tiêu! Làm tốt lắm! 🎉';

  @override
  String goalRemainingMessage(String remainingSteps) {
    return 'Còn lại $remainingSteps bước';
  }

  @override
  String get setGoalDialogTitle => 'Đặt Mục tiêu Bước chân Hàng ngày';

  @override
  String get newGoalLabel => 'Mục tiêu Mới (VD: 10000)';

  @override
  String get pleaseEnterNumber => 'Vui lòng nhập một số';

  @override
  String get invalidNumber => 'Số không hợp lệ';

  @override
  String get goalGreaterThanZero => 'Mục tiêu phải > 0';

  @override
  String get goalTooHigh => 'Mục tiêu có vẻ quá cao!';

  @override
  String get saveGoalButton => 'Lưu Mục tiêu';

  @override
  String get goalSavedSuccess => 'Đã lưu mục tiêu bước mới!';

  @override
  String get goalSavedError => 'Lưu mục tiêu mới thất bại.';

  @override
  String get activityTimeGoalTitle => 'Mục tiêu Thời gian Hoạt động';

  @override
  String get activityTimeGoalProgress => 'Tiến độ: ... / ... phút';

  @override
  String get calculatingStepsStatus => 'Đang tính số bước...';

  @override
  String get enableHealthAlerts => 'Bật Cảnh báo Sức khỏe';

  @override
  String get receiveAbnormalNotifications => 'Nhận thông báo khi chỉ số bất thường';

  @override
  String get loadingMessage => 'Đang tải...';

  @override
  String get notificationChannelHealthAlertsName => 'Cảnh báo Sức khỏe';

  @override
  String get notificationChannelHealthAlertsDesc => 'Thông báo khi chỉ số sức khỏe bất thường';

  @override
  String get notificationChannelHrHighName => 'Cảnh báo Nhịp tim Cao';

  @override
  String get notificationChannelHrHighDesc => 'Cảnh báo khi nhịp tim quá cao';

  @override
  String get notificationChannelHrLowName => 'Cảnh báo Nhịp tim Thấp';

  @override
  String get notificationChannelHrLowDesc => 'Cảnh báo khi nhịp tim quá thấp';

  @override
  String get notificationChannelSpo2LowName => 'Cảnh báo SpO2 Thấp';

  @override
  String get notificationChannelSpo2LowDesc => 'Cảnh báo khi mức SpO2 quá thấp';

  @override
  String get notificationChannelTestName => 'Thông báo Kiểm tra';

  @override
  String get notificationChannelTestDesc => 'Kênh để kiểm tra thông báo thủ công';

  @override
  String get alertHrHighTitle => 'Cảnh báo Nhịp tim Cao!';

  @override
  String alertHrHighBody(Object hrValue, Object threshold) {
    return 'Nhịp tim hiện tại là $hrValue bpm, cao hơn ngưỡng $threshold bpm.';
  }

  @override
  String get channelNameHrHigh => 'Cảnh báo Nhịp tim Cao';

  @override
  String get alertHrLowTitle => 'Cảnh báo Nhịp tim Thấp!';

  @override
  String alertHrLowBody(Object hrValue, Object threshold) {
    return 'Nhịp tim hiện tại là $hrValue bpm, thấp hơn ngưỡng $threshold bpm.';
  }

  @override
  String get channelNameHrLow => 'Cảnh báo Nhịp tim Thấp';

  @override
  String get alertSpo2LowTitle => 'Cảnh báo SpO2 Thấp!';

  @override
  String alertSpo2LowBody(Object spo2Value, Object threshold) {
    return 'SpO2 hiện tại là $spo2Value%, thấp hơn ngưỡng $threshold%.';
  }

  @override
  String get channelNameSpo2Low => 'Cảnh báo SpO2 Thấp';

  @override
  String get loginWelcomeTitle => 'Chào mừng trở lại!';

  @override
  String get loginSubtitle => 'Đăng nhập để tiếp tục';

  @override
  String get orDividerText => 'HOẶC';

  @override
  String get noAccountPrompt => 'Chưa có tài khoản?';

  @override
  String get signUpLinkText => 'Đăng ký ngay';

  @override
  String get temperatureLabel => 'Nhiệt độ';

  @override
  String get pressureLabel => 'Áp suất';

  @override
  String get tempUnit => '°C';

  @override
  String get pressureUnitHpa => 'hPa';

  @override
  String get currentActivityTitle => 'Hoạt động Hiện tại';

  @override
  String get activityInitializing => 'Đang khởi tạo...';

  @override
  String get activityUnknown => 'Hoạt động Không rõ';

  @override
  String get activityError => 'Lỗi Hoạt động';

  @override
  String get activityLying => 'Nằm';

  @override
  String get activitySitting => 'Ngồi';

  @override
  String get activityStanding => 'Đứng';

  @override
  String get activityWalking => 'Đi bộ';

  @override
  String get activityRunning => 'Chạy';

  @override
  String get activityCycling => 'Đạp xe';

  @override
  String get activityAscendingStairs => 'Leo cầu thang';

  @override
  String get activityDescendingStairs => 'Xuống cầu thang';

  @override
  String get recordActivityTitle => 'Ghi Dữ liệu Hoạt động';

  @override
  String get selectActivityLabel => 'Chọn Hoạt động để Ghi';

  @override
  String get startRecordingButton => 'Bắt đầu Ghi';

  @override
  String get stopRecordingButton => 'Dừng Ghi';

  @override
  String get statusLabel => 'Trạng thái:';

  @override
  String get samplesRecordedLabel => 'Số mẫu đã ghi:';

  @override
  String get viewRecordedDataHint => 'Đường dẫn dữ liệu đã ghi (thông tin)';

  @override
  String get pathCopiedSnackbar => 'Thông tin đường dẫn hiển thị trong console.';
}
