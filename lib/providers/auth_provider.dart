// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Cần cho lỗi Google Sign In
import 'package:flutter/services.dart'; // Cần cho PlatformException

import '../services/auth_service.dart';
import '../services/firestore_service.dart'; // Cần để cập nhật profile

// Enum để biểu diễn trạng thái xác thực chi tiết hơn
enum AuthStatus {
  uninitialized, // Trạng thái ban đầu, chưa biết
  authenticated, // Đã đăng nhập thành công
  authenticating, // Đang trong quá trình đăng nhập/đăng ký
  unauthenticated, // Chưa đăng nhập hoặc đã đăng xuất
  error, // Có lỗi xảy ra trong quá trình xác thực
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService; // Inject FirestoreService

  User? _user;
  AuthStatus _status = AuthStatus.uninitialized;
  String _lastErrorMessage =
      "An unknown error occurred."; // Lưu thông báo lỗi cuối cùng
  StreamSubscription<User?>? _authStateSubscription;

  // Getters để bên ngoài truy cập trạng thái
  User? get user => _user;
  AuthStatus get status => _status;
  // >>> THÊM DÒNG GETTER NÀY <<<
  String get lastErrorMessage =>
      _lastErrorMessage; // Getter public cho thông báo lỗi

  AuthProvider(this._authService, this._firestoreService) {
    // Ngay khi provider được tạo, bắt đầu lắng nghe trạng thái auth
    _listenToAuthChanges();
    print("AuthProvider Initialized and listening to auth changes.");
  }

  // Lắng nghe stream từ AuthService
  void _listenToAuthChanges() {
    // Hủy subscription cũ nếu có để tránh leak
    _authStateSubscription?.cancel();
    _authStateSubscription = _authService.authStateChanges.listen(
      (User? firebaseUser) async {
        if (firebaseUser == null) {
          _user = null;
          // Chỉ cập nhật nếu trạng thái hiện tại không phải là unauthenticated
          if (_status != AuthStatus.unauthenticated) {
            _updateStatus(AuthStatus.unauthenticated);
            print("AuthProvider: User state changed to signed out.");
          }
        } else {
          _user = firebaseUser;
          // Chỉ cập nhật nếu trạng thái hiện tại không phải là authenticated
          if (_status != AuthStatus.authenticated) {
            _updateStatus(AuthStatus.authenticated);
            print(
              "AuthProvider: User state changed to signed in: ${firebaseUser.uid}",
            );
            // Có thể gọi cập nhật profile ở đây nếu cần, nhưng thường gọi sau khi login/signup thành công sẽ tốt hơn
            // await _firestoreService.updateUserProfile(firebaseUser);
          }
        }
      },
      onError: (error) {
        print("AuthProvider: Error in auth state stream: $error");
        // Cập nhật trạng thái lỗi nếu có lỗi từ stream
        _updateStatus(
          AuthStatus.error,
          "Error listening to authentication state.",
        );
      },
    );
  }

  // Hàm helper để cập nhật trạng thái và thông báo listeners
  // message là thông báo lỗi cụ thể nếu có
  void _updateStatus(AuthStatus newStatus, [String? message]) {
    // Chỉ cập nhật và thông báo nếu trạng thái thực sự thay đổi hoặc có lỗi mới
    if (_status != newStatus ||
        (newStatus == AuthStatus.error && message != null)) {
      print(
        "AuthProvider: Updating status from $_status to $newStatus ${message != null ? 'with message: $message' : ''}",
      );
      _status = newStatus;
      _lastErrorMessage =
          message ?? "An unknown error occurred."; // Cập nhật lỗi
      notifyListeners(); // Thông báo cho các widget đang lắng nghe sự thay đổi
    }
  }

  // --- Các hàm gọi đến AuthService ---

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _updateStatus(AuthStatus.authenticating, "Signing in..."); // Báo đang xử lý
    try {
      final userCredential = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      if (userCredential?.user != null) {
        // Cập nhật profile ngay sau khi đăng nhập thành công
        await _firestoreService.updateUserProfile(userCredential!.user!);
        // Stream sẽ tự động cập nhật trạng thái thành authenticated
        // _updateStatus(AuthStatus.authenticated); // Không cần gọi trực tiếp ở đây nữa
        return true; // Đăng nhập thành công
      } else {
        // Trường hợp này ít xảy ra nếu _authService trả về null khi lỗi
        _updateStatus(
          AuthStatus.error,
          "Sign in failed. Invalid credentials or user not found.",
        );
        return false;
      }
    } on FirebaseAuthException catch (e) {
      // Bắt lỗi cụ thể từ Firebase Auth
      print(
        "AuthProvider: Error signing in with email: ${e.code} - ${e.message}",
      );
      // Cập nhật trạng thái lỗi với thông báo từ Firebase
      _updateStatus(
        AuthStatus.error,
        e.message ?? "Sign in failed (code: ${e.code})",
      );
      return false;
    } catch (e) {
      // Bắt các lỗi khác không mong muốn
      print("AuthProvider: Unexpected error signing in with email: $e");
      _updateStatus(
        AuthStatus.error,
        "An unexpected error occurred during sign in.",
      );
      return false;
    }
  }

  Future<bool> createUserWithEmailAndPassword(
    String email,
    String password, {
    String? displayName,
  }) async {
    _updateStatus(
      AuthStatus.authenticating,
      "Creating account...",
    ); // Báo đang xử lý
    try {
      final userCredential = await _authService.createUserWithEmailAndPassword(
        email,
        password,
      );
      if (userCredential?.user != null) {
        // Cập nhật profile Firestore với thông tin ban đầu ngay sau khi đăng ký
        await _firestoreService.updateUserProfile(
          userCredential!.user!,
          displayName: displayName, // Truyền displayName nếu người dùng nhập
          // photoURL: null // Có thể thêm photoURL mặc định
        );
        // (Tùy chọn) Gửi email xác thực nếu cần
        // await _authService.sendEmailVerification();

        // Stream sẽ tự động cập nhật trạng thái thành authenticated
        // _updateStatus(AuthStatus.authenticated); // Không cần gọi trực tiếp
        return true; // Đăng ký thành công
      } else {
        _updateStatus(
          AuthStatus.error,
          "Sign up failed. Could not create user.",
        );
        return false;
      }
    } on FirebaseAuthException catch (e) {
      print("AuthProvider: Error creating user: ${e.code} - ${e.message}");
      // Thông báo lỗi cụ thể (ví dụ: email đã tồn tại, mật khẩu yếu)
      _updateStatus(
        AuthStatus.error,
        e.message ?? "Sign up failed (code: ${e.code})",
      );
      return false;
    } catch (e) {
      print("AuthProvider: Unexpected error creating user: $e");
      _updateStatus(
        AuthStatus.error,
        "An unexpected error occurred during sign up.",
      );
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _updateStatus(
      AuthStatus.authenticating,
      "Signing in with Google...",
    ); // Báo đang xử lý
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential?.user != null) {
        // Cập nhật profile ngay sau khi đăng nhập Google thành công
        await _firestoreService.updateUserProfile(
          userCredential!.user!,
          displayName: userCredential.user!.displayName, // Lấy tên từ Google
          photoURL: userCredential.user!.photoURL, // Lấy ảnh từ Google
        );
        // Stream sẽ tự động cập nhật trạng thái thành authenticated
        // _updateStatus(AuthStatus.authenticated); // Không cần gọi trực tiếp
        return true; // Đăng nhập Google thành công
      } else {
        // Người dùng có thể đã hủy
        _updateStatus(
          AuthStatus.unauthenticated,
          "Google Sign-In cancelled or failed.",
        );
        return false;
      }
    } on FirebaseAuthException catch (e) {
      // Lỗi từ Firebase khi xác thực credential Google
      print(
        "FirebaseAuthException during Google sign in: ${e.code} - ${e.message}",
      );
      _updateStatus(
        AuthStatus.error,
        e.message ?? "Google Sign-In Error (Auth: ${e.code})",
      );
      return false;
    } on PlatformException catch (e) {
      // Lỗi từ plugin google_sign_in (ví dụ: lỗi mạng, APIException 10)
      print(
        "PlatformException during Google sign in: ${e.code} - ${e.message}",
      );
      _updateStatus(
        AuthStatus.error,
        e.message ?? "Google Sign-In Error (Platform: ${e.code})",
      );
      // Có thể cần signOut ở đây không? Xem xét lại logic của _authService.signInWithGoogle
      // await _authService.signOut(); // Đã xử lý trong AuthService?
      return false;
    } catch (e) {
      // Bắt các lỗi khác không mong muốn
      print("An unexpected error occurred during Google sign in: $e");
      await _authService.signOut(); // Đăng xuất để đảm bảo trạng thái nhất quán
      _updateStatus(
        AuthStatus.error,
        "An unexpected Google Sign-In error occurred.",
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
      // Cập nhật trạng thái ngay để UI phản hồi nhanh, dù stream cũng sẽ làm việc này
      _updateStatus(AuthStatus.unauthenticated, "Signed out successfully.");
    } catch (e) {
      print("AuthProvider: Error signing out: $e");
      // Có thể cập nhật trạng thái lỗi nếu muốn, nhưng thường chỉ cần về unauthenticated
      _updateStatus(AuthStatus.error, "Failed to sign out.");
    }
  }

  // Đảm bảo hủy subscription khi provider bị dispose để tránh memory leak
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    print("AuthProvider disposed. Auth stream cancelled.");
    super.dispose();
  }
}
