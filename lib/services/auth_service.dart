// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseAuth get firebaseAuth => _firebaseAuth;

  // --- Stream để theo dõi trạng thái đăng nhập ---
  // Trả về User? (có thể null nếu chưa đăng nhập) khi trạng thái thay đổi
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // --- Lấy người dùng hiện tại ---
  User? get currentUser => _firebaseAuth.currentUser;

  // --- Đăng nhập bằng Email & Password ---
  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      // Bây giờ hàm sẽ trả về UserCredential (không thể null)
      UserCredential userCredential =
          await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      // THAY ĐỔI QUAN TRỌNG: Ném lại lỗi thay vì return null
      // Điều này cho phép AuthProvider biết chính xác lý do thất bại.
      print("AuthService Error (signInWithEmailAndPassword): ${e.code}");
      rethrow;
    } catch (e) {
      print("AuthService Unexpected Error (signInWithEmailAndPassword): $e");
      // Ném một lỗi chung để báo hiệu có vấn đề không lường trước
      throw Exception('An unexpected error occurred during sign in.');
    }
  }

  // --- Đăng ký bằng Email & Password ---
  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
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
  Future<UserCredential> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // Người dùng đã hủy đăng nhập. Ném một lỗi cụ thể để AuthProvider có thể bắt.
        throw PlatformException(
          code: 'SIGN_IN_CANCELLED',
          message: 'Google sign-in was cancelled by the user.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Đăng nhập vào Firebase và trả về kết quả (không thể null)
      return await _firebaseAuth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      print(
          "FirebaseAuthException during Google sign in: ${e.code} - ${e.message}");
      rethrow; // Ném lại lỗi Firebase để AuthProvider xử lý
    } catch (e) {
      print("An unexpected error occurred during Google sign in: $e");
      // Đảm bảo đăng xuất khỏi Google nếu có lỗi bất ngờ xảy ra giữa chừng
      await _googleSignIn.signOut();
      rethrow; // Ném lại lỗi chung
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

  // --- Gửi email đặt lại mật khẩu ---
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(
          email: email.trim()); // <<< Thêm trim()
      print("Password reset email sent successfully to $email");
    } on FirebaseAuthException catch (e) {
      // Ném lại lỗi để Provider xử lý và map thành message dễ hiểu
      print(
          "Error sending password reset email (AuthService): ${e.code} - ${e.message}");
      rethrow; // <<< Quan trọng: Ném lại lỗi
    } catch (e) {
      print(
          "An unexpected error occurred sending password reset email (AuthService): $e");
      // Ném lại lỗi chung
      throw Exception("Failed to send password reset email."); // Hoặc throw e;
    }
  }
}

// (Tùy chọn) Định nghĩa lớp Exception tùy chỉnh để xử lý lỗi rõ ràng hơn
// class AuthException implements Exception {
//   final String code;
//   AuthException(this.code);
// }
