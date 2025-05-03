// lib/screens/config/wifi_config_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/ble_provider.dart';
import '../../services/ble_service.dart';
import '../../generated/app_localizations.dart';

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
  final bool _isOpenNetwork = false; // Trạng thái checkbox mạng mở

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
      final l10n = AppLocalizations.of(context)!;

      // Kiểm tra lại trạng thái kết nối trước khi gửi
      if (bleProvider.connectionStatus.value != BleConnectionStatus.connected) {
        if (mounted) {
          // >>> SỬA DÒNG NÀY <<<
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // <<< Thêm SnackBar(...)
              content: Text(l10n.wifiConfigDeviceNotConnectedError),
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
            content: Text(success
                ? l10n.wifiConfigSentSuccess
                : l10n.wifiConfigSentError),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.configureWifiTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.wifiConfigInstruction, // <<< DÙNG KEY
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24.0),

              // --- SSID Field ---
              TextFormField(
                controller: _ssidController,
                decoration: InputDecoration(
                  labelText: l10n.wifiSsidLabel, // <<< DÙNG KEY
                  prefixIcon: const Icon(Icons.wifi),
                  border: const OutlineInputBorder(),
                  hintText: l10n.wifiSsidHint, // <<< DÙNG KEY
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.wifiSsidValidation; // <<< DÙNG KEY
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),

              // --- Password Field (Ẩn/Hiện dựa trên _isOpenNetwork) ---
              // --- Password Field ---
              if (!_isOpenNetwork)
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.wifiPasswordLabel, // <<< DÙNG KEY
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (!_isOpenNetwork) {
                      if (value != null &&
                          value.isNotEmpty &&
                          value.length < 8) {
                        return l10n
                            .wifiPasswordValidationLength; // <<< DÙNG KEY
                      }
                    }
                    return null;
                  },
                ),
              if (_isOpenNetwork)
                const SizedBox(
                    height:
                        75), // Giữ bố cục/ Chiều cao tương đương TextFormField+padding

              // --- Checkbox Mạng Mở ---
              // --- Checkbox Mạng Mở ---
              CheckboxListTile(
                title: Text(l10n.wifiOpenNetworkCheckbox), // <<< DÙNG KEY
                value: _isOpenNetwork,
                onChanged: (bool? value) {/* ... logic giữ nguyên ... */},
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24.0),
              // --- Send Button ---
              ElevatedButton.icon(
                icon: _isSending ? Container() : const Icon(Icons.send),
                label: _isSending
                    ? const SizedBox(/* ... loading indicator ... */)
                    : Text(l10n.sendWifiConfigButton), // <<< DÙNG KEY
                onPressed: (!isConnected || _isSending) ? null : _sendConfig,
                style: ElevatedButton.styleFrom(/* ... style ... */),
              ),
              const SizedBox(height: 12.0),
              if (!isConnected)
                Text(
                  l10n.deviceNotConnectedToSend, // <<< DÙNG KEY
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
