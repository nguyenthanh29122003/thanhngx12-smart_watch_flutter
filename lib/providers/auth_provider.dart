// lib/providers/auth_provider.dart (Phiên bản CÓ THỂ GÂY LỖI TREO)
import 'dart:async';
import 'package:flutter/foundation.dart'; // Import ChangeNotifier
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart'; // Cần cho PlatformException

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
  // <<< KHÔNG CÓ appKey trong phiên bản này >>>

  // Constructor
  AuthProvider(this._authService, this._firestoreService) {
    _listenToAuthChanges();
    print("AuthProvider Initialized (Buggy Version Simulation).");
  }

  // Lắng nghe thay đổi trạng thái đăng nhập từ Firebase Auth
  void _listenToAuthChanges() {
    _authStateSubscription?.cancel();
    _authStateSubscription =
        _authService.authStateChanges.listen((User? firebaseUser) async {
      bool statusChanged = false; // Cờ kiểm tra xem có thay đổi thực sự không
      if (firebaseUser == null) {
        // Người dùng đăng xuất
        if (_user != null) {
          // Chỉ xử lý nếu trước đó có user
          _user = null;
          _updateStatusInternal(AuthStatus.unauthenticated,
              "User signed out via stream"); // Chỉ cập nhật state nội bộ
          statusChanged = true;
        }
      } else {
        // Người dùng đăng nhập hoặc thay đổi
        if (_user?.uid != firebaseUser.uid ||
            _status != AuthStatus.authenticated) {
          _user = firebaseUser;
          _updateStatusInternal(
              AuthStatus.authenticated); // Chỉ cập nhật state nội bộ
          statusChanged = true;
        }
      }

      // <<< CHỈ GỌI notifyListeners() KHI TRẠNG THÁI THAY ĐỔI TỪ STREAM >>>
      if (statusChanged) {
        print("[AuthProvider] Auth state changed from stream. Notifying.");
        notifyListeners();
      }
      // -------------------------------------------------------------
    }, onError: (error) {
      // Xử lý lỗi từ stream auth state
      print("!!! AuthProvider: Error in auth state stream: $error");
      _updateStatusInternal(AuthStatus.error,
          "Error listening to authentication state."); // Chỉ cập nhật state nội bộ
      // <<< KHÔNG GỌI notifyListeners() KHI STREAM BÁO LỖI >>>
    });
  }

  // Hàm helper CHỈ cập nhật state nội bộ, KHÔNG gọi notifyListeners
  void _updateStatusInternal(AuthStatus newStatus, [String? message]) {
    _status = newStatus;
    _lastErrorMessage = message ?? "An unknown error occurred.";
    print("[AuthProvider] Status updated INTERNALLY to: $_status");
    // <<< KHÔNG CÓ notifyListeners() Ở ĐÂY >>>
  }

  // --- Các hàm thực hiện hành động xác thực ---
  // Các hàm này gọi _updateStatusInternal nhưng KHÔNG gọi notifyListeners()
  // Đây chính là điểm có thể gây lỗi treo loading

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _updateStatusInternal(
        AuthStatus.authenticating, "Signing in..."); // Chỉ cập nhật state
    // <<< KHÔNG NOTIFY >>>
    try {
      final userCredential =
          await _authService.signInWithEmailAndPassword(email, password);
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!);
        // Chờ _listenToAuthChanges xử lý và notify sau
        return true;
      } else {
        _updateStatusInternal(AuthStatus.error, "Sign in failed...");
        // <<< KHÔNG NOTIFY >>>
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _updateStatusInternal(AuthStatus.error, e.message ?? "Sign in failed...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    } catch (e) {
      _updateStatusInternal(AuthStatus.error, "Unexpected error...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    }
  }

  Future<bool> createUserWithEmailAndPassword(String email, String password,
      {String? displayName}) async {
    _updateStatusInternal(AuthStatus.authenticating, "Creating account...");
    // <<< KHÔNG NOTIFY >>>
    try {
      final userCredential =
          await _authService.createUserWithEmailAndPassword(email, password);
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: displayName);
        // Chờ _listenToAuthChanges xử lý
        return true;
      } else {
        _updateStatusInternal(AuthStatus.error, "Sign up failed...");
        // <<< KHÔNG NOTIFY >>>
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _updateStatusInternal(AuthStatus.error, e.message ?? "Sign up failed...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    } catch (e) {
      _updateStatusInternal(AuthStatus.error, "Unexpected error...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _updateStatusInternal(
        AuthStatus.authenticating, "Signing in with Google...");
    // <<< KHÔNG NOTIFY >>>
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: userCredential.user!.displayName,
            photoURL: userCredential.user!.photoURL);
        // Chờ _listenToAuthChanges xử lý
        return true;
      } else {
        _updateStatusInternal(
            AuthStatus.unauthenticated, "Google Sign-In cancelled...");
        // <<< KHÔNG NOTIFY >>>
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _updateStatusInternal(
          AuthStatus.error, e.message ?? "Google Sign-In Error...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    } on PlatformException catch (e) {
      _updateStatusInternal(
          AuthStatus.error, e.message ?? "Google Sign-In Error...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    } catch (e) {
      print("!!! AuthProvider: Unexpected error during Google sign in: $e");
      await _authService.signOut().catchError((signOutError) {/* ... */});
      _updateStatusInternal(
          AuthStatus.error, "Unexpected Google Sign-In error...");
      // <<< KHÔNG NOTIFY >>>
      return false;
    }
  }

  Future<void> signOut() async {
    print("[AuthProvider] Attempting to sign out (Buggy Version)...");
    try {
      await _authService.signOut();
      // Chờ _listenToAuthChanges xử lý và notify
    } catch (e) {
      print("!!! AuthProvider: Error signing out: $e");
      _updateStatusInternal(AuthStatus.error, "Failed to sign out.");
      // <<< KHÔNG NOTIFY >>>
    }
  }

  // --- Dispose ---
  @override
  void dispose() {
    print("Disposing AuthProvider (Buggy Version Simulation)...");
    _authStateSubscription?.cancel();
    print("AuthProvider disposed.");
    super.dispose();
  }
}
