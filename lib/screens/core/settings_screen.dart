// lib/screens/core/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <<< Import SharedPreferences
import '../../providers/auth_provider.dart';
import '../../providers/ble_provider.dart'; // <<< Import BleProvider
import '../../services/ble_service.dart'; // <<< Import BleService (cho enum)
import '../../app_constants.dart'; // <<< Import AppConstants (cho key SharedPreferences)
import '../config/wifi_config_screen.dart';
import '../device/device_select_screen.dart'; // <<< Import màn hình chọn thiết bị
import '../../providers/settings_provider.dart'; // <<< Import SettingsProvider

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy thông tin người dùng từ AuthProvider
    final authUser = context.watch<AuthProvider>().user;
    // Lấy thông tin BLE từ BleProvider
    final bleProvider = context.watch<BleProvider>();
    final connectedDevice = bleProvider.connectedDevice;
    final connectionStatus = bleProvider.connectionStatus.value;
    final bool isConnected = connectionStatus == BleConnectionStatus.connected;

    // <<< LẤY SETTINGS PROVIDER >>>
    final settingsProvider = context.watch<SettingsProvider>();
    final currentThemeMode = settingsProvider.themeMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        // Sử dụng ListView để dễ dàng thêm/bớt các mục cài đặt
        padding: const EdgeInsets.all(16.0),
        children: [
          // --- Phần Thông tin Người dùng ---
          if (authUser != null) ...[
            // Sử dụng collection-if để thêm nếu user tồn tại
            ListTile(
              leading: CircleAvatar(
                // Hiển thị ảnh user nếu có, hoặc icon mặc định
                backgroundImage:
                    authUser.photoURL != null
                        ? NetworkImage(authUser.photoURL!)
                        : null,
                child:
                    authUser.photoURL == null ? const Icon(Icons.person) : null,
              ),
              title: Text(authUser.displayName ?? 'No Name Provided'),
              subtitle: Text(authUser.email ?? 'No Email Provided'),
            ),
            const Divider(),
          ],

          // --- Phần Quản lý Thiết bị ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Device Management',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.green : Colors.grey,
            ),
            title: Text(
              connectedDevice != null
                  ? (connectedDevice.platformName.isNotEmpty
                      ? connectedDevice.platformName
                      : 'ESP32 Wearable') // Tên mặc định nếu trống
                  : 'No Device Connected',
              style: TextStyle(
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              connectedDevice?.remoteId.toString() ??
                  'Connect via "Change Device"',
            ),
            // Chỉ hiển thị nút Disconnect khi đang thực sự kết nối
            trailing:
                isConnected
                    ? TextButton(
                      child: const Text(
                        'Disconnect',
                        style: TextStyle(color: Colors.orange),
                      ),
                      onPressed: () async {
                        print("[SettingsScreen] Disconnect button pressed.");
                        // Gọi hàm disconnect từ BleProvider (dùng read vì chỉ gọi hàm)
                        await context
                            .read<BleProvider>()
                            .disconnectFromDevice();
                        // Không cần xóa SharedPreferences ở đây
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Device disconnected.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    )
                    : null,
          ),
          ListTile(
            leading: const Icon(Icons.devices_other_outlined),
            title: const Text('Change / Forget Device'),
            subtitle: const Text('Scan and connect to a new device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              print("[SettingsScreen] Change/Forget device tapped.");
              // 1. Ngắt kết nối thiết bị hiện tại (nếu có)
              if (isConnected) {
                await context.read<BleProvider>().disconnectFromDevice();
                // Thêm delay nhỏ để đảm bảo disconnect hoàn tất trước khi xóa prefs
                await Future.delayed(const Duration(milliseconds: 300));
              }
              // 2. Xóa device ID đã lưu trong SharedPreferences
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(AppConstants.prefKeyConnectedDeviceId);
                print(
                  "[SettingsScreen] Removed saved device ID from SharedPreferences.",
                );
              } catch (e) {
                print("!!! [SettingsScreen] Error removing device ID: $e");
              }
              // 3. Điều hướng đến màn hình chọn thiết bị (thay thế màn hình hiện tại)
              if (context.mounted) {
                Navigator.pushReplacement(
                  // Dùng pushReplacement
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceSelectScreen(),
                  ),
                );
              }
            },
          ),
          const Divider(),

          // --- Phần Cấu hình WiFi (Giữ nguyên) ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Network Configuration',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.wifi_password),
            title: const Text('Configure Device WiFi'),
            subtitle: const Text('Send WiFi credentials to ESP32'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Chỉ cho phép cấu hình khi đang kết nối
              if (isConnected) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WifiConfigScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Connect to a device first to configure WiFi.',
                    ),
                    backgroundColor: Colors.orangeAccent,
                  ),
                );
              }
            },
          ),
          const Divider(),

          // TODO: Thêm các mục cài đặt khác (Ngôn ngữ, Theme, Thông báo)
          // Ví dụ:
          // ListTile(leading: Icon(Icons.language), title: Text('Language'), trailing: Icon(Icons.chevron_right), onTap: () {}),
          // ListTile(leading: Icon(Icons.brightness_6), title: Text('Appearance (Theme)'), trailing: Icon(Icons.chevron_right), onTap: () {}),
          // SwitchListTile(title: Text('Enable Health Alerts'), value: true, onChanged: (val){}),

          // --- APPEARANCE (THEME) SECTION ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Appearance',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            subtitle: const Text('Follows your device theme'),
            value: ThemeMode.system,
            groupValue: currentThemeMode, // Giá trị hiện tại đang được chọn
            onChanged: (ThemeMode? value) {
              // Gọi hàm cập nhật từ provider (dùng read)
              context.read<SettingsProvider>().updateThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light Mode'),
            value: ThemeMode.light,
            groupValue: currentThemeMode,
            onChanged: (ThemeMode? value) {
              context.read<SettingsProvider>().updateThemeMode(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark Mode'),
            value: ThemeMode.dark,
            groupValue: currentThemeMode,
            onChanged: (ThemeMode? value) {
              context.read<SettingsProvider>().updateThemeMode(value);
            },
          ),
          const Divider(),
          // --------------------------------

          // --- LANGUAGE SECTION (Placeholder) ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Language',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('App Language'),
            subtitle: const Text('English'), // TODO: Lấy ngôn ngữ hiện tại
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Hiển thị dialog/màn hình chọn ngôn ngữ
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Language selection coming soon!'),
                ),
              );
            },
          ),
          const Divider(),
          // -------------------------------------

          // --- HEALTH ALERTS (Placeholder) ---
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Enable Health Alerts'),
            subtitle: const Text('Receive notifications for abnormal readings'),
            value:
                false, // TODO: Lấy trạng thái từ SharedPreferences/SettingsProvider
            onChanged: (bool value) {
              // TODO: Lưu trạng thái mới
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert settings coming soon!')),
              );
            },
            secondary: const Icon(Icons.notifications_active_outlined),
          ),
          const Divider(),
          // ----------------------------------

          // --- Nút Logout (Giữ nguyên) ---
          const SizedBox(height: 40), // Thêm khoảng cách trước nút logout
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            onPressed: () async {
              // Gọi hàm signOut từ AuthProvider
              await context.read<AuthProvider>().signOut();
              // AuthWrapper sẽ tự động xử lý điều hướng về LoginScreen
              // Không cần gọi Navigator.pushAndRemoveUntil ở đây
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(
                    context,
                  ).colorScheme.error, // Dùng màu error của theme
              foregroundColor:
                  Theme.of(context).colorScheme.onError, // Màu chữ tương phản
            ),
          ),
          const SizedBox(height: 20), // Padding dưới cùng
        ],
      ),
    );
  }
}
