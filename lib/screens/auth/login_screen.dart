// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart'; // Import AuthProvider

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>(); // Key để quản lý Form
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // bool _isLoading = false; // <<< ĐÃ XÓA BIẾN NÀY

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Hàm xử lý đăng nhập Email/Password
  Future<void> _signInWithEmail() async {
    // Validate form trước
    if (_formKey.currentState?.validate() ?? false) {
      // setState(() => _isLoading = true); // <<< ĐÃ XÓA DÒNG NÀY

      // Gọi hàm signIn từ AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái loading từ AuthProvider
    // Sử dụng 'watch' để widget này rebuild khi status thay đổi
    final authProvider = context.watch<AuthProvider>();
    final isLoadingFromProvider =
        authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
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
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16.0),

                // --- Password Field ---
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Password must be at least 6 characters';
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
                          : const Text('Sign In'),
                ),
                const SizedBox(height: 16.0),

                // --- Google Sign In Button ---
                ElevatedButton.icon(
                  icon: Image.asset(
                    'assets/images/google_logo.png',
                    height: 20.0,
                  ),
                  label: const Text('Sign In with Google'),
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
                  onPressed:
                      isLoadingFromProvider
                          ? null
                          : () {
                            // Vô hiệu hóa khi đang loading
                            // TODO: Điều hướng đến màn hình đăng ký (SignUpScreen)
                            print("Navigate to Sign Up");
                          },
                  child: const Text("Don't have an account? Sign Up"),
                ),
                // --- Link Quên mật khẩu ---
                TextButton(
                  onPressed:
                      isLoadingFromProvider
                          ? null
                          : () {
                            // Vô hiệu hóa khi đang loading
                            // TODO: Hiển thị dialog/màn hình quên mật khẩu
                            print("Forgot Password?");
                          },
                  child: const Text("Forgot Password?"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
