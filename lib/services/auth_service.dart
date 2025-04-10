// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // --- Stream để theo dõi trạng thái đăng nhập ---
  // Trả về User? (có thể null nếu chưa đăng nhập) khi trạng thái thay đổi
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // --- Lấy người dùng hiện tại ---
  User? get currentUser => _firebaseAuth.currentUser;

  // --- Đăng nhập bằng Email & Password ---
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email.trim(), // Trim để loại bỏ khoảng trắng thừa
            password: password,
          );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Xử lý các lỗi cụ thể (ví dụ: sai mật khẩu, không tìm thấy user)
      // Bạn có thể log lỗi hoặc ném ra một exception tùy chỉnh ở đây
      print("Error signing in with email/password: ${e.code} - ${e.message}");
      // throw AuthException(e.code); // Ví dụ ném lỗi tùy chỉnh
      return null; // Hoặc trả về null để báo lỗi
    } catch (e) {
      print("An unexpected error occurred during email/password sign in: $e");
      return null;
    }
  }

  // --- Đăng ký bằng Email & Password ---
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
      // Bạn có thể thực hiện các hành động khác sau khi đăng ký thành công
      // Ví dụ: gửi email xác thực, tạo hồ sơ người dùng trong Firestore
      // await userCredential.user?.sendEmailVerification();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print(
        "Error creating user with email/password: ${e.code} - ${e.message}",
      );
      // throw AuthException(e.code);
      return null;
    } catch (e) {
      print("An unexpected error occurred during email/password sign up: $e");
      return null;
    }
  }

  // --- Đăng nhập bằng Google ---
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Bắt đầu quy trình đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Nếu người dùng hủy bỏ
      if (googleUser == null) {
        print("Google Sign In cancelled by user.");
        return null;
      }

      // Lấy thông tin xác thực OAuth2 từ tài khoản Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Tạo một credential Firebase từ token Google
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase bằng credential Google
      UserCredential userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      print(
        "FirebaseAuthException during Google sign in: ${e.code} - ${e.message}",
      );
      return null;
    } catch (e) {
      print("An unexpected error occurred during Google sign in: $e");
      // Đảm bảo đăng xuất khỏi Google nếu có lỗi bất ngờ xảy ra giữa chừng
      await _googleSignIn.signOut();
      return null;
    }
  }

  // --- Đăng xuất ---
  Future<void> signOut() async {
    try {
      // Đăng xuất khỏi cả Google và Firebase
      await _googleSignIn.signOut(); // Đăng xuất Google trước
      await _firebaseAuth.signOut(); // Sau đó đăng xuất Firebase
      print("User signed out successfully.");
    } catch (e) {
      print("Error signing out: $e");
      // throw AuthException("sign_out_failed");
    }
  }

  // --- (Tùy chọn) Gửi lại email xác thực ---
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        print("Verification email sent to ${user.email}");
      } catch (e) {
        print("Error sending verification email: $e");
      }
    } else if (user == null) {
      print("Cannot send verification email: No user logged in.");
    } else {
      print("Cannot send verification email: Email already verified.");
    }
  }

  // --- (Tùy chọn) Gửi email đặt lại mật khẩu ---
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      print("Password reset email sent to $email");
    } on FirebaseAuthException catch (e) {
      print("Error sending password reset email: ${e.code} - ${e.message}");
      // throw AuthException(e.code);
    } catch (e) {
      print("An unexpected error occurred sending password reset email: $e");
    }
  }
}

// (Tùy chọn) Định nghĩa lớp Exception tùy chỉnh để xử lý lỗi rõ ràng hơn
// class AuthException implements Exception {
//   final String code;
//   AuthException(this.code);
// }
