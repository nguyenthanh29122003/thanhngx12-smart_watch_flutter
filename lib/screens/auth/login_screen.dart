// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../generated/app_localizations.dart'; // Đảm bảo import đúng
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final l10n = AppLocalizations.of(context)!; // Lấy l10n
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // <<< SỬ DỤNG KEY loginFailedError >>>
              content: Text(
                l10n.loginFailedError(authProvider.lastErrorMessage),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n =
        AppLocalizations.of(context)!; // Lấy l10n (có thể cần cho lỗi chung)
    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // <<< Vẫn dùng lastErrorMessage trực tiếp cho Google hoặc dùng loginFailedError nếu muốn >>>
            // content: Text(l10n.loginFailedError(authProvider.lastErrorMessage)),
            content: Text(authProvider
                .lastErrorMessage), // Giữ nguyên như bản nâng cấp trước
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final formKeyDialog = GlobalKey<FormState>();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!; // Lấy l10n
    // Tự động điền email từ form đăng nhập nếu hợp lệ
    if (_emailController.text.trim().contains('@')) {
      _resetEmailController.text = _emailController.text.trim();
    } else {
      _resetEmailController.clear();
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isSending = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15.0)),
            // <<< SỬ DỤNG KEY >>>
            title: Text(l10n.resetPasswordDialogTitle),
            content: Form(
              key: formKeyDialog,
              child: TextFormField(
                controller: _resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  // <<< SỬ DỤNG KEY >>>
                  labelText: l10n.emailLabel,
                  // <<< SỬ DỤNG KEY >>>
                  hintText: l10n.enterYourEmailHint,
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                  filled: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty ||
                      !value.contains('@')) {
                    // <<< SỬ DỤNG KEY >>>
                    return l10n.emailValidation;
                  }
                  return null;
                },
                // initialValue: _emailController.text.contains('@') ? _emailController.text : null, // Controller quản lý giá trị rồi
              ),
            ),
            actions: [
              TextButton(
                onPressed:
                    isSending ? null : () => Navigator.of(dialogContext).pop(),
                // <<< SỬ DỤNG KEY >>>
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: isSending
                    ? null
                    : () async {
                        if (formKeyDialog.currentState?.validate() ?? false) {
                          setDialogState(() => isSending = true);

                          final email = _resetEmailController.text.trim();
                          bool success =
                              await authProvider.sendPasswordResetEmail(email);

                          if (Navigator.of(dialogContext).canPop()) {
                            Navigator.of(dialogContext).pop();
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                // <<< SỬ DỤNG KEY VỚI PLACEHOLDER >>>
                                content: Text(success
                                    ? l10n.resetEmailSentSuccess(email)
                                    : l10n.resetEmailSentError(
                                        authProvider.lastErrorMessage)),
                                backgroundColor: success
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                child: isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    // <<< SỬ DỤNG KEY >>>
                    : Text(l10n.sendResetEmailButton),
              ),
            ],
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // <<< Lấy l10n một lần ở đầu build >>>
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final isLoadingFromProvider =
        authProvider.status == AuthStatus.authenticating;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Thay bằng logo của bạn nếu có
                  const FlutterLogo(size: 80),
                  const SizedBox(height: 24.0),

                  // <<< SỬ DỤNG KEY >>>
                  Text(
                    l10n.loginWelcomeTitle, // Key mới thêm
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // <<< SỬ DỤNG KEY >>>
                  Text(
                    l10n.loginSubtitle, // Key mới thêm
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  // --- Email Field ---
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      // <<< SỬ DỤNG KEY >>>
                      labelText: l10n.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 12.0),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty ||
                          !value.contains('@')) {
                        // <<< SỬ DỤNG KEY >>>
                        return l10n.emailValidation;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16.0),

                  // --- Password Field ---
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      // <<< SỬ DỤNG KEY >>>
                      labelText: l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      filled: true,
                      fillColor: colorScheme.surface.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16.0, horizontal: 12.0),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 6) {
                        // <<< SỬ DỤNG KEY >>>
                        return l10n.passwordValidation;
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!isLoadingFromProvider) {
                        _signInWithEmail();
                      }
                    },
                  ),
                  // --- Forgot Password Link ---
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoadingFromProvider
                          ? null
                          : _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                      ),
                      // <<< SỬ DỤNG KEY >>>
                      child: Text(l10n.forgotPasswordPrompt),
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // --- Email/Password Sign In Button ---
                  ElevatedButton(
                    onPressed: isLoadingFromProvider ? null : _signInWithEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 4.0,
                    ),
                    child: isLoadingFromProvider
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        // <<< SỬ DỤNG KEY >>>
                        : Text(l10n.signInButton),
                  ),
                  const SizedBox(height: 16.0),

                  // --- Divider ---
                  Row(
                    children: [
                      const Expanded(child: Divider(thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        // <<< SỬ DỤNG KEY >>>
                        child: Text(
                          l10n.orDividerText, // Key mới thêm
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                      const Expanded(child: Divider(thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // --- Google Sign In Button ---
                  ElevatedButton.icon(
                    icon: Image.asset(
                      'assets/images/google_logo.png', // Đảm bảo file tồn tại
                      height: 22.0,
                    ),
                    // <<< SỬ DỤNG KEY >>>
                    label: Text(l10n.signInWithGoogleButton),
                    onPressed: isLoadingFromProvider ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.surface,
                      foregroundColor: colorScheme.onSurface.withOpacity(0.8),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      textStyle: theme.textTheme.titleMedium,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(color: Colors.grey.shade300)),
                      elevation: 1.0,
                    ),
                  ),

                  const SizedBox(height: 24.0),

                  // --- Link to Sign Up ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // <<< SỬ DỤNG KEY >>>
                      Text(
                        l10n.noAccountPrompt, // Key mới thêm
                        style: theme.textTheme.bodyMedium,
                      ),
                      TextButton(
                        onPressed: isLoadingFromProvider
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const SignUpScreen()),
                                );
                              },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        // <<< SỬ DỤNG KEY >>>
                        child: Text(
                          l10n.signUpLinkText, // Key mới thêm
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
