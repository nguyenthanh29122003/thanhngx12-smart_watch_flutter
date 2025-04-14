import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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

  User? _user;
  AuthStatus _status = AuthStatus.uninitialized;
  String _lastErrorMessage = "An unknown error occurred.";
  StreamSubscription<User?>? _authStateSubscription;

  User? get user => _user;
  AuthStatus get status => _status;
  String get lastErrorMessage => _lastErrorMessage;

  AuthProvider(this._authService, this._firestoreService) {
    _checkInitialAuthState();
    _listenToAuthChanges();
    print("AuthProvider Initialized (Fixed Version).");
  }

  Future<void> _checkInitialAuthState() async {
    try {
      // Kiểm tra user hiện tại với timeout
      final firebaseUser = await Future.value(_authService.currentUser)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Initial auth check timeout');
      });
      if (firebaseUser != null) {
        _user = firebaseUser;
        _updateStatus(AuthStatus.authenticated);
      } else {
        _updateStatus(AuthStatus.unauthenticated);
      }
    } catch (e) {
      print("Error checking initial auth state: $e");
      _updateStatus(
          AuthStatus.unauthenticated, "Failed to check initial auth state");
    }
  }

  void _listenToAuthChanges() {
    _authStateSubscription?.cancel();
    _authStateSubscription =
        _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        if (_user != null) {
          _user = null;
          _updateStatus(
              AuthStatus.unauthenticated, "User signed out via stream");
        }
      } else {
        if (_user?.uid != firebaseUser.uid ||
            _status != AuthStatus.authenticated) {
          _user = firebaseUser;
          _updateStatus(AuthStatus.authenticated);
        }
      }
    }, onError: (error) {
      print("!!! AuthProvider: Error in auth state stream: $error");
      _updateStatus(AuthStatus.unauthenticated,
          "Error listening to authentication state");
    });
  }

  void _updateStatus(AuthStatus newStatus, [String? message]) {
    final String currentMessage = message ?? "An unknown error occurred.";
    if (_status == newStatus && _lastErrorMessage == currentMessage) {
      return;
    }

    print(
        "[AuthProvider] Updating status from $_status to $newStatus ${message != null ? 'with message: $message' : ''}");
    _status = newStatus;
    _lastErrorMessage = currentMessage;
    notifyListeners();
  }

  void forceUnauthenticated() {
    print("[AuthProvider] Forcing unauthenticated state");
    _user = null;
    _updateStatus(AuthStatus.unauthenticated, "Authentication timed out");
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _updateStatus(AuthStatus.authenticating, "Signing in...");
    try {
      final userCredential = await _authService
          .signInWithEmailAndPassword(email, password)
          .timeout(const Duration(seconds: 10));
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!);
        return true;
      } else {
        _updateStatus(AuthStatus.unauthenticated,
            "Sign in failed. Invalid credentials or user not found.");
        return false;
      }
    } on TimeoutException {
      _updateStatus(AuthStatus.unauthenticated, "Sign in timed out");
      return false;
    } on FirebaseAuthException catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          e.message ?? "Sign in failed (code: ${e.code})");
      return false;
    } catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          "An unexpected error occurred during sign in.");
      return false;
    }
  }

  Future<bool> createUserWithEmailAndPassword(String email, String password,
      {String? displayName}) async {
    _updateStatus(AuthStatus.authenticating, "Creating account...");
    try {
      final userCredential = await _authService
          .createUserWithEmailAndPassword(email, password)
          .timeout(const Duration(seconds: 10));
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: displayName);
        return true;
      } else {
        _updateStatus(AuthStatus.unauthenticated,
            "Sign up failed. Could not create user.");
        return false;
      }
    } on TimeoutException {
      _updateStatus(AuthStatus.unauthenticated, "Sign up timed out");
      return false;
    } on FirebaseAuthException catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          e.message ?? "Sign up failed (code: ${e.code})");
      return false;
    } catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          "An unexpected error occurred during sign up.");
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _updateStatus(AuthStatus.authenticating, "Signing in with Google...");
    try {
      final userCredential = await _authService
          .signInWithGoogle()
          .timeout(const Duration(seconds: 10));
      if (userCredential?.user != null) {
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: userCredential.user!.displayName,
            photoURL: userCredential.user!.photoURL);
        return true;
      } else {
        _updateStatus(
            AuthStatus.unauthenticated, "Google Sign-In cancelled or failed.");
        return false;
      }
    } on TimeoutException {
      _updateStatus(AuthStatus.unauthenticated, "Google Sign-In timed out");
      return false;
    } on FirebaseAuthException catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          e.message ?? "Google Sign-In Error (Auth: ${e.code})");
      return false;
    } on PlatformException catch (e) {
      _updateStatus(AuthStatus.unauthenticated,
          e.message ?? "Google Sign-In Error (Platform: ${e.code})");
      return false;
    } catch (e) {
      print("!!! AuthProvider: Unexpected error during Google sign in: $e");
      await _authService.signOut().catchError((signOutError) {/* ... */});
      _updateStatus(AuthStatus.unauthenticated,
          "An unexpected Google Sign-In error occurred.");
      return false;
    }
  }

  Future<void> signOut() async {
    print("[AuthProvider] Attempting to sign out...");
    try {
      await _authService.signOut();
      print(
          "[AuthProvider] signOut call successful. Waiting for stream update.");
    } catch (e) {
      print("!!! AuthProvider: Error signing out: $e");
      _updateStatus(AuthStatus.unauthenticated, "Failed to sign out.");
    }
  }

  @override
  void dispose() {
    print("Disposing AuthProvider (Fixed Version)...");
    _authStateSubscription?.cancel();
    print("AuthProvider disposed.");
    super.dispose();
  }
}
