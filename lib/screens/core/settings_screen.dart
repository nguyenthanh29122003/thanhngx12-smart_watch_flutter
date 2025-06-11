// lib/screens/core/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/settings_provider.dart'; // Import SettingsProvider
import '../../services/ble_service.dart'; // Import BleService (cho enum)
import '../../app_constants.dart'; // Import AppConstants (cho key SharedPreferences)
import '../config/wifi_config_screen.dart'; // Import màn hình Wifi Config
import '../device/device_select_screen.dart'; // Import màn hình chọn thiết bị
import '../../generated/app_localizations.dart'; // <<< Import lớp Localization
import '../auth/login_screen.dart';
import 'package:flutter/cupertino.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showWeightInputDialog(
      BuildContext context, SettingsProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final controller =
        TextEditingController(text: provider.userWeightKg.toStringAsFixed(1));

    double? newWeight = await showDialog<double>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.settingUserWeightTitle),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.settingUserWeightLabel,
              suffixText: 'kg',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel)),
            ElevatedButton(
              onPressed: () {
                final weight = double.tryParse(controller.text);
                if (weight != null && weight > 0) {
                  Navigator.of(dialogContext).pop(weight);
                } else {
                  // Hiển thị lỗi
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                        content: Text(l10n.invalidNumber),
                        backgroundColor: Colors.red),
                  );
                }
              },
              child: Text(l10n.saveChangesButton),
            ),
          ],
        );
      },
    );

    if (newWeight != null) {
      await provider.updateUserWeight(newWeight);
    }
  }

  // --- HÀM HIỂN THỊ DIALOG CHỌN NGÔN NGỮ ---
  Future<void> _showLanguageDialog(
      BuildContext context, SettingsProvider provider) async {
    Locale? currentLocale = provider.appLocale; // Locale hiện tại từ provider
    final l10n = AppLocalizations.of(context)!; // Lấy đối tượng dịch

    Locale? selectedLocale = await showDialog<Locale>(
        context: context,
        builder: (dialogContext) {
          // Dùng StatefulBuilder để RadioListTile cập nhật state trong dialog
          String? groupValueLangCode = currentLocale?.languageCode;

          return StatefulBuilder(builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Text(l10n.language), // Dùng key đã dịch
              contentPadding:
                  const EdgeInsets.only(top: 12.0), // Giảm padding top
              content: SizedBox(
                width: double.minPositive, // Co lại theo chiều rộng tối thiểu
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Lựa chọn System Default
                    RadioListTile<String?>(
                      title: Text(l10n.systemDefault),
                      value: null, // null đại diện cho system
                      groupValue: groupValueLangCode,
                      onChanged: (String? value) {
                        // Không cần stfSetState ở đây vì pop sẽ đóng dialog
                        Navigator.of(dialogContext)
                            .pop(null); // Trả về null cho system
                      },
                    ),
                    // Lặp qua các ngôn ngữ được hỗ trợ từ AppLocalizations
                    ...AppLocalizations.supportedLocales.map((locale) {
                      // Lấy tên ngôn ngữ (có thể cần map chi tiết hơn)
                      String languageName = locale.languageCode == 'en'
                          ? 'English'
                          : locale.languageCode == 'vi'
                              ? 'Tiếng Việt'
                              : locale.languageCode;
                      return RadioListTile<String?>(
                        title: Text(languageName),
                        value: locale.languageCode, // Value là language code
                        groupValue: groupValueLangCode,
                        onChanged: (String? value) {
                          // Không cần stfSetState ở đây
                          Navigator.of(dialogContext)
                              .pop(locale); // Trả về Locale đã chọn
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext)
                      .pop(), // Đóng dialog không chọn gì
                  child: Text(l10n.cancel), // Dùng key đã dịch
                ),
              ],
            );
          });
        });

    // Nếu người dùng đã chọn một locale mới (hoặc system default - null)
    // Chỉ gọi update nếu lựa chọn thực sự khác
    if (selectedLocale != currentLocale) {
      print(
          "[SettingsScreen] Updating locale to: ${selectedLocale?.languageCode ?? 'system'}");
      // Gọi hàm cập nhật từ provider (dùng read vì chỉ gọi hàm)
      await context.read<SettingsProvider>().updateLocale(selectedLocale);
    }
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Lấy các providers
    final authUser = context.watch<AuthProvider>().user;
    final bleProvider = context.watch<BleProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    // Lấy các giá trị state
    final currentThemeMode = settingsProvider.themeMode;
    final currentLocale = settingsProvider.appLocale;
    final connectedDevice = bleProvider.connectedDevice;
    final connectionStatus = bleProvider.connectionStatus.value;
    final isConnected = connectionStatus == BleConnectionStatus.connected;
    final bool notificationsAreEnabled =
        settingsProvider.notificationsEnabled; // Lấy state

    // Lấy đối tượng AppLocalizations để truy cập chuỗi dịch
    final l10n = AppLocalizations.of(context)!;

    // Xác định tên ngôn ngữ hiện tại để hiển thị
    String currentLanguageName = l10n.systemDefault; // Mặc định
    if (currentLocale?.languageCode == 'en') {
      currentLanguageName = 'English';
    } else if (currentLocale?.languageCode == 'vi')
      currentLanguageName = 'Tiếng Việt';

    return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTitle)), // Dùng chuỗi dịch
        body: ListView(
          padding: const EdgeInsets.symmetric(
              vertical: 8.0, horizontal: 0), // Giảm padding ngang ListView
          children: [
            // --- User Info ---
            if (authUser != null) ...[
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 10.0),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: authUser.photoURL != null
                      ? NetworkImage(authUser.photoURL!)
                      : null,
                  child: authUser.photoURL == null
                      ? const Icon(Icons.person, size: 28)
                      : null,
                ),
                title: Text(authUser.displayName ?? l10n.name,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500)), // Dịch 'Name' nếu null
                subtitle: Text(authUser.email ?? l10n.noEmail),
              ),
              const Divider(height: 1),
            ],

            // --- Device Management Section ---
            _buildSectionTitle(context,
                l10n.sectionDeviceManagement), // Hàm helper tạo tiêu đề
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: isConnected ? Colors.green : Colors.grey),
              title: Text(connectedDevice != null
                  ? (connectedDevice.platformName.isNotEmpty
                      ? connectedDevice.platformName
                      : 'ESP32 Wearable')
                  : l10n.noDeviceConnected),
              subtitle: Text(
                  connectedDevice?.remoteId.toString() ?? l10n.connectPrompt),
              trailing: isConnected
                  ? TextButton(
                      child: const Text('Disconnect',
                          style: TextStyle(color: Colors.orange)),
                      onPressed: () async {
                        await context
                            .read<BleProvider>()
                            .disconnectFromDevice(); /* ... SnackBar ... */
                      })
                  : null,
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: const Icon(Icons.devices_other_outlined),
              title: Text(l10n.changeForgetDevice), // TODO: Dịch
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                // Ngắt kết nối nếu đang kết nối
                if (isConnected) {
                  print("[SettingsScreen] Disconnecting from device...");
                  await context.read<BleProvider>().disconnectFromDevice();
                  // Có thể đợi một chút để đảm bảo trạng thái cập nhật
                  await Future.delayed(const Duration(milliseconds: 300));
                }

                // Xóa ID thiết bị đã lưu
                print("[SettingsScreen] Forgetting saved device ID...");
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(AppConstants.prefKeyConnectedDeviceId);

                // Kiểm tra context còn tồn tại không trước khi điều hướng
                if (context.mounted) {
                  print(
                      "[SettingsScreen] Navigating to DeviceSelectScreen using push...");
                  // <<< SỬ DỤNG Navigator.push THAY VÌ pushReplacement >>>
                  Navigator.push(
                    // <<< THAY ĐỔI Ở ĐÂY
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeviceSelectScreen(),
                    ),
                  );
                  // --------------------------------------------------
                }
              },
            ),
            const Divider(height: 1),

            // --- Network Configuration Section ---
            _buildSectionTitle(context, l10n.sectionNetwork),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: const Icon(Icons.wifi_password_outlined),
              title: Text(l10n.configureWifiTitle), // Dịch title
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                /* ... Logic mở WifiConfigScreen (kiểm tra isConnected) ... */
                if (isConnected) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WifiConfigScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connect to device first.'),
                      backgroundColor: Colors.orangeAccent));
                }
              },
            ),
            const Divider(height: 1),

            // --- Appearance Section ---
            _buildSectionTitle(context, l10n.appearance), // Dịch tiêu đề
            RadioListTile<ThemeMode>(
                contentPadding: const EdgeInsets.only(left: 20.0, right: 12.0),
                title: Text(l10n.systemDefault),
                value: ThemeMode.system,
                groupValue: currentThemeMode,
                onChanged: (v) =>
                    context.read<SettingsProvider>().updateThemeMode(v)),
            RadioListTile<ThemeMode>(
                contentPadding: const EdgeInsets.only(left: 20.0, right: 12.0),
                title: Text(l10n.lightMode),
                value: ThemeMode.light,
                groupValue: currentThemeMode,
                onChanged: (v) =>
                    context.read<SettingsProvider>().updateThemeMode(v)),
            RadioListTile<ThemeMode>(
                contentPadding: const EdgeInsets.only(left: 20.0, right: 12.0),
                title: Text(l10n.darkMode),
                value: ThemeMode.dark,
                groupValue: currentThemeMode,
                onChanged: (v) =>
                    context.read<SettingsProvider>().updateThemeMode(v)),
            const Divider(height: 1),

            // --- Language Section ---
            _buildSectionTitle(context, l10n.language), // Dịch tiêu đề
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: const Icon(Icons.language_outlined),
              title: Text(l10n.language), // Dịch title
              subtitle:
                  Text(currentLanguageName), // Hiển thị tên ngôn ngữ hiện tại
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showLanguageDialog(context, context.read<SettingsProvider>());
              }, // Gọi dialog
            ),
            const Divider(height: 1),

            // --- Notifications Placeholder ---
            // --- Notifications Section --- // <<< CẬP NHẬT PHẦN NÀY
            _buildSectionTitle(context, l10n.sectionNotifications), // Dịch ''
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              title:
                  Text(l10n.enableHealthAlerts), // Dịch 'Enable Health Alerts'
              subtitle: Text(l10n
                  .receiveAbnormalNotifications), // Dịch 'Receive notifications...'
              // --- Lấy value từ provider ---
              value: notificationsAreEnabled,
              // --- Gọi hàm update từ provider khi thay đổi ---
              onChanged: (bool newValue) {
                context
                    .read<SettingsProvider>()
                    .updateNotificationsEnabled(newValue);
              },
              secondary: const Icon(Icons.notifications_active_outlined),
              activeColor:
                  Theme.of(context).colorScheme.primary, // Thêm màu cho đẹp
            ),
            const Divider(height: 1),

            _buildSectionTitle(context, l10n.sectionActivityRecognition),

            // Cài đặt Cân nặng
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: const Icon(Icons.fitness_center_outlined),
              title: Text(l10n.settingUserWeightTitle),
              subtitle: Text(l10n.settingUserWeightDesc),
              trailing: Text(
                '${settingsProvider.userWeightKg.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              onTap: () => _showWeightInputDialog(context, settingsProvider),
            ),

            // Cài đặt Ngưỡng ngồi lâu
            _buildDurationSlider(
              context: context,
              title: l10n.settingSittingThresholdTitle,
              currentValue: settingsProvider.sittingWarningThreshold,
              min: 15, // 15 phút
              max: 120, // 2 tiếng
              divisions: (120 - 15) ~/ 5, // Mỗi nấc là 5 phút
              onChanged: (minutes) {
                settingsProvider.updateSittingWarningThreshold(
                    Duration(minutes: minutes.toInt()));
              },
              displayFormatter: (duration) => l10n
                  .settingThresholdMinutesDesc(duration.inMinutes.toString()),
            ),

            // Cài đặt Ngưỡng nằm lâu
            _buildDurationSlider(
              context: context,
              title: l10n.settingLyingThresholdTitle,
              currentValue: settingsProvider.lyingDaytimeWarningThreshold,
              min: 1, // 1 tiếng
              max: 4, // 4 tiếng
              divisions: 3, // 1h, 2h, 3h, 4h
              onChanged: (hours) {
                settingsProvider.updateLyingDaytimeWarningThreshold(
                    Duration(hours: hours.toInt()));
              },
              displayFormatter: (duration) =>
                  l10n.settingThresholdHoursDesc(duration.inHours.toString()),
            ),

            // Bật/tắt Nhắc nhở thông minh
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              title: Text(l10n.settingSmartRemindersTitle),
              subtitle: Text(l10n.settingSmartRemindersDesc),
              value: settingsProvider.smartRemindersEnabled,
              onChanged: (newValue) {
                settingsProvider.updateSmartRemindersEnabled(newValue);
              },
              secondary: const Icon(Icons.lightbulb_outline),
            ),

            const Divider(height: 1),

            // --- Logout Button ---
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(l10n.logout), // Dịch label
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n
                          .confirmLogoutTitle), // Ví dụ: "Xác nhận đăng xuất"
                      content: Text(l10n
                          .confirmLogoutMessage), // Ví dụ: "Bạn có chắc chắn muốn đăng xuất không?"
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(l10n.cancel), // Ví dụ: "Hủy"
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: Text(l10n.confirm), // Ví dụ: "Đồng ý"
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    // <<< THÊM KIỂM TRA CONTEXT.MOUNTED
                    // Gọi signOut từ AuthProvider
                    await context.read<AuthProvider>().signOut();

                    // <<< ĐIỀU HƯỚNG VỀ LOGIN VÀ XÓA STACK >>>
                    // Sử dụng rootNavigator: true để đảm bảo pop từ Navigator gốc của MaterialApp
                    // và xóa hết các màn hình cũ (bao gồm cả MainNavigator).
                    Navigator.of(context, rootNavigator: true)
                        .pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const LoginScreen()),
                      (Route<dynamic> route) =>
                          false, // Điều kiện này xóa tất cả các route trước đó
                    );
                    // Hoặc nếu bạn đã định nghĩa route '/login' trong MaterialApp:
                    // Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                    //   '/login',
                    //   (Route<dynamic> route) => false,
                    // );
                    // ------------------------------------
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ));
  }

  // --- Hàm Helper tạo Tiêu đề Section ---
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 20.0, right: 20.0, top: 16.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(), // In hoa tiêu đề
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              // Dùng labelSmall
              color: Theme.of(context).colorScheme.primary, // Màu primary
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8, // Giãn cách chữ
            ),
      ),
    );
  }

  Widget _buildDurationSlider({
    required BuildContext context,
    required String title,
    required Duration currentValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String Function(Duration) displayFormatter,
  }) {
    double sliderValue;
    // Chuyển đổi Duration sang double cho Slider (ví dụ: phút hoặc giờ)
    if (currentValue.inHours >= 1 && min >= 1) {
      // Giả định slider này cho giờ
      sliderValue = currentValue.inHours.toDouble();
    } else {
      // Giả định slider cho phút
      sliderValue = currentValue.inMinutes.toDouble();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: sliderValue.clamp(
                      min, max), // Đảm bảo giá trị nằm trong khoảng
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: sliderValue.round().toString(),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                displayFormatter(currentValue),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
