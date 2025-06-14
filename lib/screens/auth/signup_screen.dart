// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../generated/app_localizations.dart';

// Đây là phiên bản đã được nâng cấp giao diện hoàn chỉnh
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- STATE VÀ LOGIC GIỮ NGUYÊN ---
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    // Logic của bạn đã rất tốt, giữ nguyên
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        displayName: _displayNameController.text.trim(),
      );

      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(authProvider.lastErrorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
      // Nếu thành công, AuthWrapper sẽ tự điều hướng, không cần pop
    }
  }

  // --- HÀM BUILD ĐƯỢC THIẾT KẾ LẠI ---
  @override
  Widget build(BuildContext context) {
    // Lấy các giá trị cần thiết từ theme và provider
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        // AppBar trong suốt và không có đổ bóng (style từ AppTheme)
        // Flutter sẽ tự động thêm nút "Back"
        // Tùy chỉnh màu nút Back để hợp với nền
        leading: BackButton(color: colorScheme.onBackground),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // PHẦN HEADER
                Text(
                  l10n.signUpTitle,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 8.0),
                Text(
                  l10n.signUpSubtitle, // Sử dụng key mới đã thêm
                  textAlign: TextAlign.center,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32.0),

                // TRƯỜNG NHẬP TÊN HIỂN THỊ
                TextFormField(
                  controller: _displayNameController,
                  enabled: !isLoading,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.displayNameLabel,
                    prefixIcon: Icon(Icons.person_outline,
                        color: colorScheme.primary.withOpacity(0.8)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0)),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? l10n.displayNameValidation
                      : null,
                ),
                const SizedBox(height: 16.0),

                // TRƯỜNG NHẬP EMAIL
                TextFormField(
                  controller: _emailController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    prefixIcon: Icon(Icons.email_outlined,
                        color: colorScheme.primary.withOpacity(0.8)),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0)),
                  ),
                  validator: (value) => (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@'))
                      ? l10n.emailValidation
                      : null,
                ),
                const SizedBox(height: 16.0),

                // TRƯỜNG NHẬP MẬT KHẨU
                TextFormField(
                  controller: _passwordController,
                  enabled: !isLoading,
                  obscureText: !_obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: Icon(Icons.lock_outline,
                        color: colorScheme.primary.withOpacity(0.8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0)),
                  ),
                  validator: (value) => (value == null || value.length < 6)
                      ? l10n.passwordValidation
                      : null,
                ),
                const SizedBox(height: 16.0),

                // TRƯỜNG XÁC NHẬN MẬT KHẨU
                TextFormField(
                  controller: _confirmPasswordController,
                  enabled: !isLoading,
                  obscureText: !_obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: isLoading ? null : (_) => _signUp(),
                  decoration: InputDecoration(
                    labelText: l10n.confirmPasswordLabel,
                    prefixIcon: Icon(Icons.lock_person_outlined,
                        color: colorScheme.primary.withOpacity(0.8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorScheme.onSurface.withOpacity(0.6)),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0)),
                  ),
                  validator: (value) => (value != _passwordController.text)
                      ? l10n.confirmPasswordValidationMatch
                      : null,
                ),
                const SizedBox(height: 32.0),

                // NÚT ĐĂNG KÝ
                ElevatedButton(
                  onPressed: isLoading ? null : _signUp,
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 3, color: Colors.white),
                        )
                      : Text(l10n.signUpButton.toUpperCase()),
                ),
                const SizedBox(height: 24.0),

                // LINK QUAY LẠI ĐĂNG NHẬP
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n.loginPrompt, style: textTheme.bodyMedium),
                    TextButton(
                      onPressed:
                          isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        l10n.signInButton,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
