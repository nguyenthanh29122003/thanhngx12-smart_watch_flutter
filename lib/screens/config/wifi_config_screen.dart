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
  // --- STATE VÀ LOGIC CỦA BẠN (ĐÃ TỐT, GIỮ NGUYÊN) ---
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSending = false;
  bool _isPasswordVisible = false;
  bool _isOpenNetwork = false;

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

      if (bleProvider.connectionStatus.value != BleConnectionStatus.connected) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.wifiConfigDeviceNotConnectedError),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
        }
        setState(() => _isSending = false);
        return;
      }

      final success = await bleProvider.sendWifiConfig(ssid, password);

      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              success ? l10n.wifiConfigSentSuccess : l10n.wifiConfigSentError),
          backgroundColor:
              success ? Colors.green : Theme.of(context).colorScheme.error,
        ));
        if (success) {
          Future.delayed(
              const Duration(seconds: 1), () => Navigator.of(context).pop());
        }
      }
    }
  }

  // --- HÀM BUILD ĐƯỢC THIẾT KẾ LẠI HOÀN TOÀN ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isConnected = context.watch<BleProvider>().connectionStatus.value ==
        BleConnectionStatus.connected;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.configureWifiTitle)),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.router_outlined,
                    size: 64, color: theme.colorScheme.secondary),
                const SizedBox(height: 16),
                Text(l10n.wifiConfigInstruction,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.textTheme.bodyLarge?.color?.withOpacity(0.8),
                    )),
                const SizedBox(height: 32.0),

                // SSID Field (sử dụng style từ theme)
                TextFormField(
                  controller: _ssidController,
                  enabled: !_isSending,
                  decoration: InputDecoration(
                    labelText: l10n.wifiSsidLabel,
                    hintText: l10n.wifiSsidHint,
                    prefixIcon: Icon(Icons.wifi,
                        color: theme.colorScheme.primary.withOpacity(0.8)),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(
                            color: theme.colorScheme.primary, width: 2.0)),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.wifiSsidValidation
                      : null,
                ),
                const SizedBox(height: 16.0),

                // Password Field với hiệu ứng
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: !_isOpenNetwork
                      ? TextFormField(
                          key: const ValueKey('password_field'),
                          controller: _passwordController,
                          enabled: !_isSending,
                          obscureText: !_isPasswordVisible,
                          decoration: InputDecoration(
                            labelText: l10n.wifiPasswordLabel,
                            prefixIcon: Icon(Icons.lock_outline,
                                color:
                                    theme.colorScheme.primary.withOpacity(0.8)),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6)),
                              onPressed: () => setState(() =>
                                  _isPasswordVisible = !_isPasswordVisible),
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 2.0)),
                          ),
                          validator: (value) => (value != null &&
                                  value.isNotEmpty &&
                                  value.length < 8)
                              ? l10n.wifiPasswordValidationLength
                              : null,
                        )
                      : const SizedBox(
                          height: 56, key: ValueKey('empty_space')),
                ),
                const SizedBox(height: 8.0),

                // Checkbox được style lại
                CheckboxListTile(
                  title: Text(l10n.wifiOpenNetworkCheckbox,
                      style: theme.textTheme.bodyMedium),
                  value: _isOpenNetwork,
                  // <<< SỬA LỖI LOGIC: Thêm setState >>>
                  onChanged: _isSending
                      ? null
                      : (bool? value) {
                          setState(() {
                            _isOpenNetwork = value ?? false;
                            if (_isOpenNetwork) _passwordController.clear();
                          });
                        },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 32.0),

                // Nút Gửi (style từ theme)
                ElevatedButton(
                  onPressed: (!isConnected || _isSending) ? null : _sendConfig,
                  child: _isSending
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : Text(l10n.sendWifiConfigButton.toUpperCase()),
                ),

                const SizedBox(height: 16.0),
                if (!isConnected)
                  AnimatedOpacity(
                    opacity: isConnected ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      l10n.deviceNotConnectedToSend,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
