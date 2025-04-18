// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../generated/app_localizations.dart'; // Import l10n

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
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
    if (_formKey.currentState?.validate() ?? false) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final l10n = AppLocalizations.of(context)!; // Lấy l10n

      // Gọi hàm signUp từ AuthProvider
      final success = await authProvider.createUserWithEmailAndPassword(
        // <<< SỬA TÊN HÀM
        _emailController.text.trim(),
        _passwordController.text, // Truyền password
        displayName: _displayNameController.text.trim(), // Truyền displayName
      );

      if (mounted) {
        // Luôn kiểm tra mounted
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // Sử dụng một key dịch lỗi chung hoặc lỗi cụ thể từ provider
              content:
                  Text(authProvider.lastErrorMessage), // Lấy lỗi từ provider
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        // Nếu thành công, AuthWrapper sẽ tự điều hướng
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;
    final l10n = AppLocalizations.of(context)!; // Lấy l10n

    return Scaffold(
      appBar: AppBar(
        // <<< SỬA TITLE >>>
        title: Text(l10n.signUpTitle), // TODO: Thêm key 'signUpTitle' vào .arb
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
                // --- Display Name Field ---
                TextFormField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    // <<< SỬA LABEL >>>
                    labelText: l10n
                        .displayNameLabel, // TODO: Thêm key 'displayNameLabel'
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      // <<< SỬA VALIDATION MESSAGE >>>
                      return l10n
                          .displayNameValidation; // TODO: Thêm key 'displayNameValidation'
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Email Field ---
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel, // Dùng key đã có
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty ||
                        !value.contains('@')) {
                      return l10n.emailValidation; // Dùng key đã có
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Password Field ---
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: l10n.passwordLabel, // Dùng key đã có
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    // <<< THÊM ICON HIỆN/ẨN MẬT KHẨU >>>
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  obscureText: _obscurePassword, // <<< DÙNG BIẾN STATE
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return l10n.passwordValidation; // Dùng key đã có
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Confirm Password Field ---
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    // <<< SỬA LABEL >>>
                    labelText: l10n
                        .confirmPasswordLabel, // TODO: Thêm key 'confirmPasswordLabel'
                    prefixIcon:
                        const Icon(Icons.lock_outline), // Icon khác chút
                    border: const OutlineInputBorder(),
                    // <<< THÊM ICON HIỆN/ẨN MẬT KHẨU >>>
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword, // <<< DÙNG BIẾN STATE
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      // <<< SỬA VALIDATION MESSAGE >>>
                      return l10n
                          .confirmPasswordValidationEmpty; // TODO: Thêm key 'confirmPasswordValidationEmpty'
                    }
                    if (value != _passwordController.text) {
                      // <<< SỬA VALIDATION MESSAGE >>>
                      return l10n
                          .confirmPasswordValidationMatch; // TODO: Thêm key 'confirmPasswordValidationMatch'
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),

                // --- Sign Up Button ---
                ElevatedButton(
                  onPressed: isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15.0),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(/* ... Indicator ... */)
                      // <<< SỬA TEXT NÚT >>>
                      : Text(
                          l10n.signUpButton), // TODO: Thêm key 'signUpButton'
                ),
                const SizedBox(height: 20.0),

                // --- Link to Login ---
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          // Quay lại màn hình Login
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            // Dự phòng nếu không thể pop (ví dụ: vào thẳng màn Sign Up)
                            Navigator.pushReplacementNamed(
                                context, '/login'); // Giả sử có route '/login'
                          }
                        },
                  // <<< SỬA TEXT LINK >>>
                  child: Text(l10n
                      .loginPrompt), // TODO: Thêm key 'loginPrompt' ("Already have an account? Login")
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
