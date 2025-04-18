// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart'; // Import AuthProvider
import '../../generated/app_localizations.dart';
import 'signup_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Key để quản lý Form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _resetEmailController = TextEditingController();
  // bool _isLoading = false; // <<< ĐÃ XÓA BIẾN NÀY

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    super.dispose();
  }

  // Hàm xử lý đăng nhập Email/Password
  Future<void> _signInWithEmail() async {
    // Validate form trước
    if (_formKey.currentState?.validate() ?? false) {
      // setState(() => _isLoading = true); // <<< ĐÃ XÓA DÒNG NÀY

      // Gọi hàm signIn từ AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final l10n = AppLocalizations.of(context)!;
      final success = await authProvider.signInWithEmailAndPassword(
        _emailController.text,
        _passwordController.text,
      );

      // Kiểm tra mounted trước khi truy cập context hoặc setState (dù không còn setState ở đây)
      if (mounted) {
        // setState(() => _isLoading = false); // <<< ĐÃ XÓA DÒNG NÀY

        // Kiểm tra kết quả và hiển thị thông báo lỗi nếu cần
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // >>> SỬ DỤNG lastErrorMessage <<<
              content: Text(
                authProvider.lastErrorMessage, // Lấy lỗi cụ thể từ provider
              ),
              // content: Text(l10n.loginFailedError(authProvider.lastErrorMessage)),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        // Nếu thành công, AuthWrapper sẽ tự động điều hướng
      }
    }
  }

  // Hàm xử lý đăng nhập Google
  Future<void> _signInWithGoogle() async {
    // setState(() => _isLoading = true); // <<< ĐÃ XÓA DÒNG NÀY
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    // Kiểm tra mounted trước khi truy cập context hoặc setState
    if (mounted) {
      // setState(() => _isLoading = false); // <<< ĐÃ XÓA DÒNG NÀY

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // >>> SỬ DỤNG lastErrorMessage <<<
            content: Text(
              authProvider.lastErrorMessage, // Lấy lỗi cụ thể từ provider
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      // Nếu thành công, AuthWrapper sẽ tự động điều hướng
    }
  }

  // <<< HÀM MỚI ĐỂ HIỂN THỊ DIALOG QUÊN MẬT KHẨU >>>
  Future<void> _showForgotPasswordDialog() async {
    final formKeyDialog = GlobalKey<FormState>(); // Key riêng cho form dialog
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;
    _resetEmailController.clear(); // Xóa email cũ trong dialog (nếu có)

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n
              .resetPasswordDialogTitle), // TODO: Thêm key 'resetPasswordDialogTitle'
          content: Form(
            key: formKeyDialog,
            child: TextFormField(
              controller: _resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.emailLabel, // Dùng lại key email label
                hintText: l10n
                    .enterYourEmailHint, // TODO: Thêm key 'enterYourEmailHint'
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty ||
                    !value.contains('@')) {
                  return l10n.emailValidation; // Dùng lại key validation
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel), // Dùng lại key cancel
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKeyDialog.currentState?.validate() ?? false) {
                  final email = _resetEmailController.text.trim();
                  // Đóng dialog trước khi gọi hàm async
                  Navigator.of(dialogContext).pop();
                  // Gọi hàm từ provider
                  bool success =
                      await authProvider.sendPasswordResetEmail(email);
                  // Hiển thị SnackBar kết quả (kiểm tra mounted của context gốc)
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                                ? l10n.resetEmailSentSuccess(
                                    email) // TODO: Thêm key 'resetEmailSentSuccess' với placeholder {email}
                                : l10n.resetEmailSentError(authProvider
                                    .lastErrorMessage) // TODO: Thêm key 'resetEmailSentError' với placeholder {errorDetails}
                            ),
                        backgroundColor:
                            success ? Colors.green : Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: Text(l10n
                  .sendResetEmailButton), // TODO: Thêm key 'sendResetEmailButton'
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái loading từ AuthProvider
    // Sử dụng 'watch' để widget này rebuild khi status thay đổi
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final isLoadingFromProvider =
        authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginTitle),
        automaticallyImplyLeading: false, // Ẩn nút back
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Email Field ---
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return l10n.emailValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Password Field ---
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel,
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return l10n.passwordValidation;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),

                // --- Email/Password Sign In Button ---
                ElevatedButton(
                  // >>> CHỈ DỰA VÀO isLoadingFromProvider <<<
                  onPressed: isLoadingFromProvider ? null : _signInWithEmail,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child:
                      isLoadingFromProvider // >>> CHỈ DỰA VÀO isLoadingFromProvider <<<
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.signInButton),
                ),
                const SizedBox(height: 16.0),

                // --- Google Sign In Button ---
                ElevatedButton.icon(
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    height: 20.0,
                  ),
                  label: Text(l10n.signInWithGoogleButton),
                  // >>> CHỈ DỰA VÀO isLoadingFromProvider <<<
                  onPressed: isLoadingFromProvider ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),

                const SizedBox(height: 20.0),

                // --- Link to Sign Up ---
                TextButton(
                  onPressed: isLoadingFromProvider
                      ? null
                      : () {
                          // <<< ĐIỀU HƯỚNG ĐẾN SIGNUPSCREEN >>>
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SignUpScreen()),
                          );
                        },
                  child: Text(l10n.signUpPrompt), // Đã dịch
                ),
                // --- Link Quên mật khẩu ---
                TextButton(
                  onPressed:
                      isLoadingFromProvider ? null : _showForgotPasswordDialog,
                  child: Text(l10n.forgotPasswordPrompt), // Đã dịch
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
