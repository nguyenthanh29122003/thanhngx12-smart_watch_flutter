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
}
