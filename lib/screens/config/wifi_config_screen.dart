// lib/screens/config/wifi_config_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';

class WifiConfigScreen extends StatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  State<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends State<WifiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSending = false;
  bool _isPasswordVisible = false; // Để ẩn/hiện mật khẩu
  bool _isOpenNetwork = false; // Trạng thái checkbox mạng mở

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendConfig() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSending = true);

      final bleProvider = Provider.of<BleProvider>(context, listen: false);
      final ssid = _ssidController.text.trim();
      final password = _isOpenNetwork ? "" : _passwordController.text;

      // Kiểm tra lại trạng thái kết nối trước khi gửi
      if (bleProvider.connectionStatus.value != BleConnectionStatus.connected) {
        if (mounted) {
          // >>> SỬA DÒNG NÀY <<<
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              // <<< Thêm SnackBar(...)
              content: Text('Device not connected. Please connect first.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
          // >>> KẾT THÚC SỬA <<<
        }
        setState(() => _isSending = false);
        return; // Không gửi nếu không kết nối
      }

      print(
        "Sending WiFi Config - SSID: $ssid, Password: ${_isOpenNetwork ? '<Open Network>' : '********'}",
      );

      final success = await bleProvider.sendWifiConfig(ssid, password);

      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'WiFi configuration sent!'
                  : 'Failed to send configuration.',
            ),
            backgroundColor: success ? Colors.green : Colors.redAccent,
          ),
        );
        // if (success) { /* ... Tùy chọn pop màn hình ... */ }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectionStatus =
        context.watch<BleProvider>().connectionStatus.value;
    final isConnected = connectionStatus == BleConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: const Text('Configure Device WiFi')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the WiFi network details for your ESP32 device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24.0),

              // --- SSID Field ---
              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'WiFi Network Name (SSID)',
                  prefixIcon: Icon(Icons.wifi),
                  border: OutlineInputBorder(),
                  hintText: 'e.g., MyHomeWiFi',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the WiFi network name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // --- Password Field (Ẩn/Hiện dựa trên _isOpenNetwork) ---
              // Sử dụng Visibility hoặc if để ẩn/hiện
              if (!_isOpenNetwork) // Chỉ hiển thị nếu KHÔNG phải mạng mở
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    // Thêm suffixIcon để ẩn/hiện pw
                    labelText: 'WiFi Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible, // Đảo ngược logic ẩn/hiện
                  validator: (value) {
                    // Chỉ validate nếu không phải mạng mở
                    if (!_isOpenNetwork) {
                      // Có thể vẫn cho phép trống nếu người dùng cố tình bỏ qua
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 8) {
                        return 'Password should be at least 8 characters';
                      }
                    }
                    return null; // Hợp lệ nếu là mạng mở hoặc đủ dài/trống
                  },
                ),
              // Nếu là mạng mở thì thêm khoảng cách để giữ bố cục
              if (_isOpenNetwork)
                const SizedBox(
                  height: 75,
                ), // Chiều cao tương đương TextFormField+padding
              // --- Checkbox Mạng Mở ---
              CheckboxListTile(
                title: const Text("This is an open network (no password)"),
                value: _isOpenNetwork,
                onChanged: (bool? value) {
                  setState(() {
                    _isOpenNetwork = value ?? false;
                    // Nếu là mạng mở, xóa nội dung password và reset form validation
                    if (_isOpenNetwork) {
                      _passwordController.clear();
                      _formKey.currentState?.reset(); // Reset validation state
                    }
                    // Trigger validate lại nếu người dùng bỏ chọn checkbox
                    _formKey.currentState?.validate();
                  });
                },
                controlAffinity:
                    ListTileControlAffinity.leading, // Checkbox ở bên trái
                contentPadding: EdgeInsets.zero, // Bỏ padding mặc định
              ),
              const SizedBox(height: 24.0), // Tăng khoảng cách một chút
              // --- Send Button ---
              ElevatedButton.icon(
                icon: _isSending ? Container() : const Icon(Icons.send),
                label:
                    _isSending
                        ? const SizedBox(
                          /* ... loading indicator ... */
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text('Send Configuration'),
                onPressed: (!isConnected || _isSending) ? null : _sendConfig,
                style: ElevatedButton.styleFrom(
                  /* ... style cũ ... */
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  textStyle: const TextStyle(fontSize: 16),
                  backgroundColor:
                      isConnected
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                ),
              ),
              const SizedBox(height: 12.0),
              if (!isConnected)
                Text(
                  /* ... thông báo chưa kết nối ... */
                  'Device must be connected to send configuration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
