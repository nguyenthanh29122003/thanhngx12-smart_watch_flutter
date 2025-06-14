// lib/screens/core/settings_screen.dart

// ================================================================
// CÁC IMPORT CẦN THIẾT
// ================================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/ble_service.dart';
import '../../app_constants.dart';
import '../config/wifi_config_screen.dart';
import '../device/device_select_screen.dart';
import '../../generated/app_localizations.dart';
import '../auth/login_screen.dart';

// ================================================================
// Widget chính của màn hình Cài đặt
// ================================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Scaffold sẽ tự động lấy style từ AppTheme của chúng ta
    return Scaffold(
      // AppBar cũng tự động lấy style, bao gồm cả nền trong suốt
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        // Padding chung cho toàn bộ danh sách để tạo không gian thoáng
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: const [
          // Mỗi section là một widget con, được ngăn cách bằng SizedBox
          _ProfileSection(),
          SizedBox(height: 24),
          _DeviceManagementSection(),
          SizedBox(height: 24),
          _AppearanceSection(),
          SizedBox(height: 24),
          _NotificationSection(),
          SizedBox(height: 24),
          _ActivitySettingsSection(),
          SizedBox(height: 32),
          _LogoutButton(),
          SizedBox(height: 16), // Padding dưới cùng
        ],
      ),
    );
  }
}

// ================================================================
// CÁC WIDGET HELPER ĐỂ TÁI SỬ DỤNG
// ================================================================

/// Widget để hiển thị tiêu đề cho một nhóm cài đặt.
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 12.0, top: 8.0),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              // Lấy màu từ colorScheme để tương thích cả light/dark mode
              color: Theme.of(context).colorScheme.primary.withOpacity(0.9),
              letterSpacing: 1.2, // Tăng giãn cách chữ một chút
            ),
      ),
    );
  }
}

/// Widget để hiển thị một hàng cài đặt chuẩn, có thể nhấn vào.
class _SettingsListItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsListItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sử dụng InkWell bọc ngoài để có hiệu ứng gợn sóng đẹp mắt khi nhấn
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12), // Bo góc cho hiệu ứng
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14), // Tăng padding dọc
        child: Row(
          children: [
            // Icon bên trái
            Icon(icon, color: iconColor ?? theme.colorScheme.primary),
            const SizedBox(width: 16),

            // Cột chứa Title và Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.center, // Căn giữa nếu chỉ có 1 dòng
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall!.color!
                              .withOpacity(0.8)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Widget ở cuối hàng (trailing), thường là giá trị hiện tại hoặc icon mũi tên
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SECTION: THÔNG TIN NGƯỜI DÙNG
// ================================================================
class _ProfileSection extends StatelessWidget {
  const _ProfileSection();

  @override
  Widget build(BuildContext context) {
    // Lắng nghe AuthProvider để lấy thông tin người dùng
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

    // Các giá trị theme và i18n
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Nếu chưa đăng nhập hoặc không có thông tin user, không hiển thị gì cả
    if (user == null) return const SizedBox.shrink();

    // Ưu tiên lấy tên từ profile Firestore, nếu không có thì lấy từ Auth object
    final displayName = authProvider.preferredDisplayName ?? l10n.defaultUser;

    return Column(
      children: [
        // Sử dụng một Card lớn, nổi bật cho khu vực hồ sơ
        Card(
          // Style của Card sẽ tự lấy từ AppTheme
          // Thêm một chút đổ bóng để nổi bật hơn
          elevation: 4,
          shadowColor: theme.colorScheme.primary.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Avatar người dùng lớn, rõ ràng
                CircleAvatar(
                  radius: 36, // Kích thước lớn hơn
                  // Nền avatar có màu nhẹ của theme
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  // Hiển thị ảnh từ Google nếu có
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : null,
                  // Nếu không có ảnh, hiển thị chữ cái đầu của tên
                  child: user.photoURL == null
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : "?",
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Cột chứa tên và email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tên người dùng
                      Text(
                        displayName,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Email người dùng
                      if (user.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.email!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // (Tùy chọn) Có thể thêm một nút "Sửa" ở đây trong tương lai
                // const Icon(Icons.edit_outlined, color: Colors.grey)
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION: QUẢN LÝ THIẾT BỊ
// ================================================================
class _DeviceManagementSection extends StatelessWidget {
  const _DeviceManagementSection();

  // Hàm hiển thị một SnackBar cảnh báo
  void _showDisabledSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.connectDeviceFirstSnackbar),
        backgroundColor: Colors.orangeAccent,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final bleProvider = context.watch<BleProvider>();
    // Lấy trạng thái kết nối và thông tin thiết bị
    final connectionStatus = bleProvider.connectionStatus.value;
    final isConnected = connectionStatus == BleConnectionStatus.connected;
    final deviceName = bleProvider.connectedDevice?.platformName;
    final deviceId = bleProvider.connectedDevice?.remoteId.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề của Section
        _SectionTitle(l10n.sectionDeviceManagement),
        // Các mục cài đặt được bọc trong một Card duy nhất
        Card(
          child: Column(
            children: [
              // --- Hàng hiển thị thiết bị đang kết nối ---
              _SettingsListItem(
                // Icon thay đổi theo trạng thái kết nối
                icon: isConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                // Màu icon cũng thay đổi
                iconColor: isConnected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                title: deviceName?.isNotEmpty == true
                    ? deviceName!
                    : l10n.noDeviceConnected,
                subtitle: deviceId ?? l10n.connectPrompt,
                // Hiển thị nút "Ngắt kết nối" nếu đang kết nối
                trailing: isConnected
                    ? TextButton(
                        child: Text(l10n.disconnectButton,
                            style: TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold)),
                        onPressed: () async => await context
                            .read<BleProvider>()
                            .disconnectFromDevice(),
                      )
                    : null,
              ),

              // Đường kẻ ngăn cách
              const Divider(height: 1, indent: 56, endIndent: 16),

              // --- Hàng Cấu hình WiFi ---
              _SettingsListItem(
                icon: Icons.wifi_password_outlined,
                iconColor: isConnected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                title: l10n.configureWifiTitle,
                // Hiển thị một icon khóa nhỏ nếu chưa kết nối để báo hiệu không thể nhấn
                trailing: isConnected
                    ? Icon(Icons.chevron_right,
                        size: 20, color: theme.unselectedWidgetColor)
                    : Icon(Icons.lock_outline,
                        size: 18, color: theme.disabledColor),
                onTap: isConnected
                    ? () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const WifiConfigScreen()));
                      }
                    : () => _showDisabledSnackbar(
                        context), // Hiển thị snackbar nếu không thể nhấn
              ),

              // Đường kẻ ngăn cách
              const Divider(height: 1, indent: 56, endIndent: 16),

              // --- Hàng Đổi / Quên Thiết bị ---
              _SettingsListItem(
                icon: Icons.swap_horizontal_circle_outlined,
                iconColor:
                    theme.colorScheme.primary, // Nút này luôn có thể nhấn
                title: l10n.changeForgetDevice,
                trailing: Icon(Icons.chevron_right,
                    size: 20, color: theme.unselectedWidgetColor),
                onTap: () async {
                  if (isConnected) {
                    await context.read<BleProvider>().disconnectFromDevice();
                  }
                  // Xóa ID thiết bị đã lưu trong bộ nhớ
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove(AppConstants.prefKeyConnectedDeviceId);

                  // Điều hướng đến màn hình chọn thiết bị và thay thế màn hình hiện tại
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (context) => const DeviceSelectScreen()),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION: GIAO DIỆN & NGÔN NGỮ
// ================================================================
class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.sectionAppearanceAndLang),
        Card(
            child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Phần Cài đặt Giao diện (Theme) ---
              Text(l10n.appearance,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              // <<< THAY ĐỔI LỚN: XÂY DỰNG TOGGLE BUTTONS TÙY CHỈNH >>>
              _CustomThemeToggle(),
              // --------------------------------------------------------

              const Divider(height: 24),

              // --- Phần Cài đặt Ngôn ngữ ---
              _SettingsListItem(
                icon: Icons.language_outlined,
                title: l10n.language,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _localeToString(context, settingsProvider.appLocale),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right,
                        size: 20, color: theme.unselectedWidgetColor),
                  ],
                ),
                onTap: () => _showLanguageDialog(
                    context, context.read<SettingsProvider>()),
              ),
            ],
          ),
        )),
      ],
    );
  }

  // --- Các hàm helper ---
  String _localeToString(BuildContext context, Locale? locale) {
    final l10n = AppLocalizations.of(context)!;
    if (locale == null) return l10n.systemDefault;
    // Có thể thêm nhiều ngôn ngữ khác ở đây trong tương lai
    if (locale.languageCode == 'vi') return "Tiếng Việt";
    if (locale.languageCode == 'en') return "English";
    return locale.languageCode.toUpperCase();
  }

  Future<void> _showLanguageDialog(
      BuildContext context, SettingsProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    Locale? currentLocale = provider.appLocale;

    // `showDialog` trả về giá trị mà `Navigator.pop(value)` trả về
    final Locale? selectedLocale = await showDialog<Locale>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(l10n.language),
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lựa chọn "Mặc định hệ thống"
                RadioListTile<Locale?>(
                  title: Text(l10n.systemDefault),
                  value: null,
                  groupValue: currentLocale,
                  onChanged: (value) => Navigator.of(dialogContext).pop(value),
                  activeColor: theme.colorScheme.secondary,
                ),
                // Lựa chọn các ngôn ngữ được hỗ trợ
                ...AppLocalizations.supportedLocales.map((locale) {
                  final languageName =
                      locale.languageCode == 'en' ? 'English' : 'Tiếng Việt';
                  return RadioListTile<Locale?>(
                    title: Text(languageName),
                    value: locale,
                    groupValue: currentLocale,
                    onChanged: (value) =>
                        Navigator.of(dialogContext).pop(value),
                    activeColor: theme.colorScheme.secondary,
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(currentLocale),
                  child: Text(l10n.cancel)),
            ],
          );
        });

    // Chỉ gọi hàm update của provider nếu người dùng thực sự chọn một giá trị khác
    if (selectedLocale != currentLocale) {
      // Dùng context.read vì đang ở trong một hàm async không thuộc cây widget build
      await context.read<SettingsProvider>().updateLocale(selectedLocale);
    }
  }
}

// ================================================================
// SECTION: THÔNG BÁO
// ================================================================
class _NotificationSection extends StatelessWidget {
  const _NotificationSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.sectionNotifications),
        Card(
          child: Column(
            children: [
              // Sử dụng SwitchListTile để có một hàng cài đặt có nút gạt
              SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(l10n.enableHealthAlerts,
                    style: theme.textTheme.titleMedium),
                subtitle: Text(l10n.receiveAbnormalNotifications,
                    style: theme.textTheme.bodySmall),
                value: settingsProvider.notificationsEnabled,
                // Gọi hàm update từ provider khi người dùng thay đổi
                onChanged: (newValue) => context
                    .read<SettingsProvider>()
                    .updateNotificationsEnabled(newValue),
                secondary: Icon(
                    settingsProvider.notificationsEnabled
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_off_outlined,
                    color: theme.colorScheme.primary),
                activeColor: theme.colorScheme.secondary,
              ),
              // (Trong tương lai có thể thêm các cài đặt chi tiết hơn về thông báo ở đây)
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SECTION: CÀI ĐẶT HOẠT ĐỘNG
// ================================================================
class _ActivitySettingsSection extends StatefulWidget {
  const _ActivitySettingsSection();

  @override
  State<_ActivitySettingsSection> createState() =>
      _ActivitySettingsSectionState();
}

class _ActivitySettingsSectionState extends State<_ActivitySettingsSection> {
  // State cục bộ để cập nhật giá trị slider một cách mượt mà
  double? _tempSittingMinutes;
  double? _tempLyingHours;

  // Controller cho ô nhập cân nặng
  late final TextEditingController _weightController;
  final _weightFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Khởi tạo controller với giá trị từ provider
    final settingsProvider = context.read<SettingsProvider>();
    _weightController = TextEditingController(
        text: settingsProvider.userWeightKg.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Dùng watch để widget rebuild khi cài đặt được lưu
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    // Đồng bộ giá trị sliders cục bộ với provider mỗi lần build
    final actualSittingMinutes =
        settingsProvider.sittingWarningThreshold.inMinutes.toDouble();
    _tempSittingMinutes ??= actualSittingMinutes;

    final actualLyingHours =
        settingsProvider.lyingDaytimeWarningThreshold.inHours.toDouble();
    _tempLyingHours ??= actualLyingHours;

    // Cập nhật text field nếu giá trị provider thay đổi (ví dụ: do load lại)
    final weightFromProvider = settingsProvider.userWeightKg.toStringAsFixed(1);
    if (_weightController.text != weightFromProvider) {
      _weightController.text = weightFromProvider;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.sectionActivitySettings), // Key mới
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. Cài đặt Cân nặng ---
                _SettingsListItem(
                    icon: Icons.monitor_weight_outlined,
                    title: l10n.settingUserWeight, // Key mới
                    subtitle: l10n.settingUserWeightDesc, // Key mới
                    trailing: SizedBox(
                      width: 80,
                      child: Form(
                        // Bọc trong Form để validate
                        key: _weightFormKey,
                        child: TextFormField(
                          controller: _weightController,
                          textAlign: TextAlign.end,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            suffixText: ' kg',
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            isDense: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onFieldSubmitted: (value) {
                            // Tự động lưu khi nhấn "done" trên bàn phím
                            if (_weightFormKey.currentState?.validate() ??
                                false) {
                              final newWeight = double.tryParse(value);
                              if (newWeight != null) {
                                context
                                    .read<SettingsProvider>()
                                    .updateUserWeight(newWeight);
                              }
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return l10n.errorFieldRequired; // Key mới
                            final n = double.tryParse(value);
                            if (n == null) return l10n.invalidNumber;
                            if (n < 20 || n > 200)
                              return l10n.errorWeightRange; // Key mới
                            return null;
                          },
                        ),
                      ),
                    )),

                const Divider(height: 24),

                // --- 2. Cài đặt Cảnh báo Ngồi Lâu ---
                Text(l10n.settingSittingWarning,
                    style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    Icon(Icons.chair_alt_outlined,
                        size: 20, color: theme.disabledColor),
                    Expanded(
                      child: Slider(
                        value: _tempSittingMinutes ?? actualSittingMinutes,
                        min: 15, max: 120,
                        divisions: 7, // 15, 30, 45, 60, 75, 90, 105, 120
                        label: l10n.minutesLabel(
                            (_tempSittingMinutes ?? actualSittingMinutes)
                                .toInt()),
                        onChanged: (newValue) =>
                            setState(() => _tempSittingMinutes = newValue),
                        onChangeEnd: (finalValue) => context
                            .read<SettingsProvider>()
                            .updateSittingWarningThreshold(
                                Duration(minutes: finalValue.toInt())),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                          l10n.minutesLabel(
                              (_tempSittingMinutes ?? actualSittingMinutes)
                                  .toInt()),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // --- 3. Cài đặt Cảnh báo Nằm Lâu (Ban Ngày) ---
                Text(l10n.settingLyingWarning,
                    style: theme.textTheme.titleMedium), // Key mới
                Row(
                  children: [
                    Icon(Icons.hotel_outlined,
                        size: 20, color: theme.disabledColor),
                    Expanded(
                      child: Slider(
                        value: _tempLyingHours ?? actualLyingHours,
                        min: 1, max: 4, divisions: 3, // 1h, 2h, 3h, 4h
                        label: l10n.hoursLabel(
                            (_tempLyingHours ?? actualLyingHours)
                                .toInt()), // Key mới
                        onChanged: (newValue) =>
                            setState(() => _tempLyingHours = newValue),
                        onChangeEnd: (finalValue) => context
                            .read<SettingsProvider>()
                            .updateLyingDaytimeWarningThreshold(
                                Duration(hours: finalValue.toInt())),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                          l10n.hoursLabel(
                              (_tempLyingHours ?? actualLyingHours).toInt()),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),

                const Divider(height: 24),

                // --- 4. Cài đặt Nhắc nhở Thông minh ---
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingSmartReminders,
                      style: theme.textTheme.titleMedium),
                  subtitle: Text(l10n.settingSmartRemindersDesc,
                      style: theme.textTheme.bodySmall),
                  value: settingsProvider.smartRemindersEnabled,
                  onChanged: (newValue) => context
                      .read<SettingsProvider>()
                      .updateSmartRemindersEnabled(newValue),
                  secondary: Icon(Icons.psychology_outlined,
                      color: theme.colorScheme.primary),
                  activeColor: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// <<< WIDGET TÙY CHỈNH MỚI CHO CÁC NÚT CHỌN THEME >>>
class _CustomThemeToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsProvider = context.watch<SettingsProvider>();

    // Dữ liệu cho các nút
    final List<({ThemeMode mode, IconData icon, String label})> themeOptions = [
      (
        mode: ThemeMode.light,
        icon: Icons.light_mode_outlined,
        label: l10n.lightMode
      ),
      (
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_outlined,
        label: l10n.darkMode
      ),
      (
        mode: ThemeMode.system,
        icon: Icons.settings_brightness_outlined,
        label: l10n.systemDefault
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Row(
        children: themeOptions.map((option) {
          // Kiểm tra xem nút hiện tại có phải là nút đang được chọn không
          final bool isSelected = settingsProvider.themeMode == option.mode;

          return Expanded(
            // <<< SỬ DỤNG EXPANDED >>>
            // Expanded đảm bảo mỗi nút sẽ chiếm một không gian bằng nhau
            child: Material(
              // Dùng Material để có hiệu ứng InkWell
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surface,
              child: InkWell(
                onTap: () => context
                    .read<SettingsProvider>()
                    .updateThemeMode(option.mode),
                child: Container(
                  // Thêm viền để ngăn cách các nút
                  decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    width: option.mode == ThemeMode.system
                        ? 0
                        : 1, // Không có viền cho nút cuối
                  ))),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option.icon,
                        size: 20,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          option.label,
                          style: TextStyle(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ================================================================
// WIDGET NÚT ĐĂNG XUẤT
// ================================================================
class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      // Đặt nút ra giữa cho đẹp
      child: TextButton.icon(
        icon: Icon(Icons.logout, color: theme.colorScheme.error),
        label: Text(l10n.logout,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            )),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          // Tạo một viền nhẹ xung quanh nút để nó không quá "chìm"
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  BorderSide(color: theme.colorScheme.error.withOpacity(0.3))),
        ),
        onPressed: () async {
          // --- Logic xác nhận đăng xuất ---
          // Logic này đã rất tốt và được giữ lại, chỉ style lại dialog
          final confirm = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              // Style AlertDialog để nhất quán với theme
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(l10n.confirmLogoutTitle),
              content: Text(l10n.confirmLogoutMessage),
              actions: [
                // Nút "Hủy"
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                // Nút "Đăng xuất" (Hành động chính)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    l10n.logout, // Dùng chữ "Đăng xuất"
                    style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );

          // Nếu người dùng xác nhận, thực hiện đăng xuất
          if (confirm == true && context.mounted) {
            await context.read<AuthProvider>().signOut();

            // Điều hướng về màn hình Login và xóa toàn bộ các màn hình cũ.
            // Logic này rất quan trọng và đã được viết đúng.
            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        },
      ),
    );
  }
}
