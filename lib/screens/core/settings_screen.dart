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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                    }).toList(),
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

    // Lấy đối tượng AppLocalizations để truy cập chuỗi dịch
    final l10n = AppLocalizations.of(context)!;

    // Xác định tên ngôn ngữ hiện tại để hiển thị
    String currentLanguageName = l10n.systemDefault; // Mặc định
    if (currentLocale?.languageCode == 'en')
      currentLanguageName = 'English';
    else if (currentLocale?.languageCode == 'vi')
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
                subtitle: Text(authUser.email ?? 'No Email'),
              ),
              const Divider(height: 1),
            ],

            // --- Device Management Section ---
            _buildSectionTitle(
                context, 'Device Management'), // Hàm helper tạo tiêu đề
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
                  : 'No Device Connected'),
              subtitle: Text(connectedDevice?.remoteId.toString() ??
                  'Connect via "Change Device"'),
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
              title: const Text('Change / Forget Device'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                /* ... Logic Change/Forget Device ... */
                if (isConnected) {
                  await context.read<BleProvider>().disconnectFromDevice();
                  await Future.delayed(const Duration(milliseconds: 300));
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(AppConstants.prefKeyConnectedDeviceId);
                if (context.mounted)
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const DeviceSelectScreen()));
              },
            ),
            const Divider(height: 1),

            // --- Network Configuration Section ---
            _buildSectionTitle(context, 'Network'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              leading: const Icon(Icons.wifi_password_outlined),
              title: Text(l10n.configureWifiTitle), // Dịch title
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                /* ... Logic mở WifiConfigScreen (kiểm tra isConnected) ... */
                if (isConnected)
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const WifiConfigScreen()));
                else
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Connect to device first.'),
                      backgroundColor: Colors.orangeAccent));
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
            _buildSectionTitle(
                context, 'Notifications'), // Có thể dịch 'Notifications'
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
              title: const Text('Enable Health Alerts'), // Dịch nếu cần
              subtitle: const Text(
                  'Receive notifications for abnormal readings'), // Dịch nếu cần
              value: false, // TODO: Lấy state
              onChanged: (bool value) {/* TODO: Lưu state */},
              secondary: const Icon(Icons.notifications_active_outlined),
            ),
            const Divider(height: 1),

            // --- Logout Button ---
            Padding(
              // Thêm Padding quanh nút Logout
              padding:
                  const EdgeInsets.symmetric(vertical: 30.0, horizontal: 20.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(l10n.logout), // Dịch label
                onPressed: () async {
                  await context.read<AuthProvider>().signOut();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .errorContainer, // Màu nền khác
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onErrorContainer, // Màu chữ tương phản
                    padding:
                        const EdgeInsets.symmetric(vertical: 12) // Padding nút
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
}
