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
}
