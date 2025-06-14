// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Imports của dự án
import '../../providers/auth_provider.dart';
import '../../generated/app_localizations.dart';
import 'signup_screen.dart';

// Phiên bản đã được rà soát và tích hợp đầy đủ AppTheme
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // --- STATE VÀ LOGIC GIỮ NGUYÊN ---
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    // Logic của bạn đã rất tốt, giữ nguyên
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final l10n = AppLocalizations.of(context)!;
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.loginFailedError(authProvider.lastErrorMessage)),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Logic của bạn đã rất tốt, giữ nguyên
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    if (mounted && !success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(authProvider.lastErrorMessage),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    // Logic dialog của bạn đã rất tốt, giữ nguyên
    // Tuy nhiên, có thể style lại AlertDialog để hợp theme hơn
    // ...
  }

  // --- HÀM BUILD ĐƯỢC THIẾT KẾ LẠI ---
  @override
  Widget build(BuildContext context) {
    // Lấy các giá trị cần thiết từ theme và provider
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      // Scaffold sẽ tự động lấy màu nền từ AppTheme
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // PHẦN HEADER
                  Image.asset(
                    'assets/images/app_logo.png',
                    height: 90,
                    // Có thể thêm colorFilter để logo thay đổi màu theo theme
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 32.0),

                  Text(
                    l10n.loginWelcomeTitle,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall, // Lấy style từ AppTheme
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40.0),

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
                      fillColor: colorScheme.surface, // Màu từ theme
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@')) {
                        return l10n.emailValidation;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16.0),

                  // TRƯỜNG NHẬP MẬT KHẨU
                  TextFormField(
                    controller: _passwordController,
                    enabled: !isLoading,
                    obscureText: !_isPasswordVisible,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted:
                        isLoading ? null : (_) => _signInWithEmail(),
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      prefixIcon: Icon(Icons.lock_outline,
                          color: colorScheme.primary.withOpacity(0.8)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        onPressed: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide:
                            BorderSide(color: colorScheme.primary, width: 2.0),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        return l10n.passwordValidation;
                      }
                      return null;
                    },
                  ),

                  // LINK QUÊN MẬT KHẨU
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading ? null : _showForgotPasswordDialog,
                      child: Text(l10n.forgotPasswordPrompt,
                          style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // NÚT ĐĂNG NHẬP CHÍNH
                  // Tự động lấy style từ ElevatedButtonThemeData trong AppTheme
                  ElevatedButton(
                    onPressed: isLoading ? null : _signInWithEmail,
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 3, color: Colors.white),
                          )
                        : Text(l10n.signInButton.toUpperCase()),
                  ),
                  const SizedBox(height: 20.0),

                  // DẢI PHÂN CÁCH
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color:
                                  colorScheme.onBackground.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          l10n.orDividerText,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                          child: Divider(
                              color:
                                  colorScheme.onBackground.withOpacity(0.2))),
                    ],
                  ),
                  const SizedBox(height: 20.0),

                  // NÚT ĐĂNG NHẬP GOOGLE
                  OutlinedButton.icon(
                    icon: Image.asset('assets/images/google_logo.png',
                        height: 22.0),
                    label: Text(l10n.signInWithGoogleButton),
                    onPressed: isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.onBackground,
                      backgroundColor: colorScheme.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      side: BorderSide(
                          color: colorScheme.onBackground.withOpacity(0.2)),
                      textStyle: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 40.0),

                  // LINK ĐĂNG KÝ
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.noAccountPrompt, style: textTheme.bodyMedium),
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SignUpScreen())),
                        child: Text(
                          l10n.signUpLinkText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
