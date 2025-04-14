// lib/providers/auth_provider.dart (Phiên bản SỬA LỖI TREO - Cách 1)
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';

// Import các service phụ thuộc
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

// Enum trạng thái xác thực chi tiết hơn
enum AuthStatus {
  uninitialized,
  authenticated,
  authenticating,
  unauthenticated,
  error
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  // State
  User? _user;
  AuthStatus _status = AuthStatus.uninitialized;
  String _lastErrorMessage = "An unknown error occurred.";

  // Stream Subscription
  StreamSubscription<User?>? _authStateSubscription;

  // Getters công khai
  User? get user => _user;
  AuthStatus get status => _status;
  String get lastErrorMessage => _lastErrorMessage;
  // <<< LƯU Ý: Không còn appKey ở đây >>>

  // Constructor
  AuthProvider(this._authService, this._firestoreService) {
    _listenToAuthChanges();
    print("AuthProvider Initialized (Fixed Version).");
  }

  // Lắng nghe thay đổi trạng thái đăng nhập từ Firebase Auth
  void _listenToAuthChanges() {
    _authStateSubscription?.cancel();
    _authStateSubscription =
        _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        // Logout
        if (_user != null) {
          _user = null;
          _updateStatus(AuthStatus.unauthenticated,
              "User signed out via stream"); // Gọi updateStatus (sẽ tự notify)
        }
      } else {
        // Login / User change
        if (_user?.uid != firebaseUser.uid ||
            _status != AuthStatus.authenticated) {
          _user = firebaseUser;
          _updateStatus(
              AuthStatus.authenticated); // Gọi updateStatus (sẽ tự notify)
        }
      }
    }, onError: (error) {
      // Lỗi stream
      print("!!! AuthProvider: Error in auth state stream: $error");
      _updateStatus(AuthStatus.error,
          "Error listening to authentication state."); // Gọi updateStatus (sẽ tự notify)
    });
  }

  // Hàm helper cập nhật trạng thái và LUÔN thông báo listeners
  void _updateStatus(AuthStatus newStatus, [String? message]) {
    final String currentMessage = message ?? "An unknown error occurred.";
    // <<< LƯU Ý: Kiểm tra để tránh notify thừa nếu không có gì thay đổi >>>
    if (_status == newStatus && _lastErrorMessage == currentMessage) {
      return;
    }

    print(
        "[AuthProvider] Updating status from $_status to $newStatus ${message != null ? 'with message: $message' : ''}");
    _status = newStatus;
    _lastErrorMessage = currentMessage;
    notifyListeners(); // <<< LƯU Ý: LUÔN GỌI NOTIFY LISTENERS Ở ĐÂY KHI CÓ THAY ĐỔI
  }

  // --- Các hàm thực hiện hành động xác thực ---
  // Gọi _updateStatus để thay đổi trạng thái -> tự động notify

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    // <<< LƯU Ý: Gọi _updateStatus để báo authenticating (sẽ tự notify) >>>
    _updateStatus(AuthStatus.authenticating, "Signing in...");
    try {
      final userCredential =
          await _authService.signInWithEmailAndPassword(email, password);
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!);
        // _listenToAuthChanges sẽ xử lý việc chuyển sang authenticated
        return true;
      } else {
        // <<< LƯU Ý: Gọi _updateStatus để báo lỗi (sẽ tự notify) >>>
        _updateStatus(AuthStatus.error,
            "Sign in failed. Invalid credentials or user not found.");
        return false;
      }
    } on FirebaseAuthException catch (e) {
      // <<< LƯU Ý: Gọi _updateStatus để báo lỗi (sẽ tự notify) >>>
      _updateStatus(
          AuthStatus.error, e.message ?? "Sign in failed (code: ${e.code})");
      return false;
    } catch (e) {
      // <<< LƯU Ý: Gọi _updateStatus để báo lỗi (sẽ tự notify) >>>
      _updateStatus(
          AuthStatus.error, "An unexpected error occurred during sign in.");
      return false;
    }
  }

  Future<bool> createUserWithEmailAndPassword(String email, String password,
      {String? displayName}) async {
    _updateStatus(
        AuthStatus.authenticating, "Creating account..."); // <<< Tự notify
    try {
      final userCredential =
          await _authService.createUserWithEmailAndPassword(email, password);
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: displayName);
        return true;
      } else {
        _updateStatus(AuthStatus.error,
            "Sign up failed. Could not create user."); // <<< Tự notify
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _updateStatus(AuthStatus.error,
          e.message ?? "Sign up failed (code: ${e.code})"); // <<< Tự notify
      return false;
    } catch (e) {
      _updateStatus(AuthStatus.error,
          "An unexpected error occurred during sign up."); // <<< Tự notify
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _updateStatus(AuthStatus.authenticating,
        "Signing in with Google..."); // <<< Tự notify
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: userCredential.user!.displayName,
            photoURL: userCredential.user!.photoURL);
        return true;
      } else {
        _updateStatus(AuthStatus.unauthenticated,
            "Google Sign-In cancelled or failed."); // <<< Tự notify
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _updateStatus(
          AuthStatus.error,
          e.message ??
              "Google Sign-In Error (Auth: ${e.code})"); // <<< Tự notify
      return false;
    } on PlatformException catch (e) {
      _updateStatus(
          AuthStatus.error,
          e.message ??
              "Google Sign-In Error (Platform: ${e.code})"); // <<< Tự notify
      return false;
    } catch (e) {
      print("!!! AuthProvider: Unexpected error during Google sign in: $e");
      await _authService.signOut().catchError((signOutError) {/* ... */});
      _updateStatus(AuthStatus.error,
          "An unexpected Google Sign-In error occurred."); // <<< Tự notify
      return false;
    }
  }

  Future<void> signOut() async {
    print("[AuthProvider] Attempting to sign out...");
    try {
      await _authService.signOut();
      // <<< LƯU Ý: KHÔNG cần gọi _updateStatus ở đây khi thành công, vì _listenToAuthChanges sẽ xử lý >>>
      print(
          "[AuthProvider] signOut call successful. Waiting for stream update.");
    } catch (e) {
      print("!!! AuthProvider: Error signing out: $e");
      // <<< LƯU Ý: Gọi _updateStatus để báo lỗi nếu signOut thất bại (sẽ tự notify) >>>
      _updateStatus(AuthStatus.error, "Failed to sign out.");
    }
  }

  // --- Dispose ---
  @override
  void dispose() {
    print("Disposing AuthProvider (Fixed Version)...");
    _authStateSubscription?.cancel();
    print("AuthProvider disposed.");
    super.dispose();
  }
}
