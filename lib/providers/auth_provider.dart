// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // Cho kDebugMode và mapEquals
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // Cho PlatformException (nếu bắt lỗi Google Sign-In chi tiết)
// import 'package:google_sign_in/google_sign_in.dart'; // Bỏ comment nếu sử dụng Google Sign-In

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
// import '../app_constants.dart'; // Nếu cần dùng hằng số

enum AuthStatus {
  uninitialized, // Trạng thái ban đầu, đang kiểm tra
  authenticated, // Đã xác thực
  authenticating, // Đang trong quá trình đăng nhập/đăng ký
  unauthenticated, // Chưa xác thực
  error // Có lỗi xác thực không mong muốn
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  User? _user; // Thông tin người dùng từ Firebase Auth
  AuthStatus _status = AuthStatus.uninitialized; // Trạng thái xác thực hiện tại
  String _lastErrorMessage = ""; // Thông báo lỗi cuối cùng để UI hiển thị
  Map<String, dynamic>? _userProfileData; // Dữ liệu hồ sơ từ Firestore
  bool _isLoadingProfile =
      false; // Cờ cho biết đang tải hồ sơ hay không (chủ yếu dùng nội bộ)

  StreamSubscription<User?>?
      _authStateListenerSubscription; // Listener cho thay đổi trạng thái auth từ AuthService

  // --- Getters công khai ---
  User? get user => _user;
  AuthStatus get status => _status;
  String get lastErrorMessage => _lastErrorMessage;
  Map<String, dynamic>? get userProfileData => _userProfileData;
  bool get isLoadingProfile =>
      _isLoadingProfile; // UI có thể dùng nếu muốn hiển thị loading riêng cho profile

  /// Getter tiện lợi để lấy tên hiển thị.
  /// Ưu tiên lấy từ hồ sơ Firestore, nếu không có thì fallback về displayName từ Firebase Auth user.
  String? get preferredDisplayName {
    if (_userProfileData != null &&
        _userProfileData!['displayName'] != null &&
        _userProfileData!['displayName'].isNotEmpty) {
      return _userProfileData!['displayName'] as String?;
    }
    if (_user != null &&
        _user!.displayName != null &&
        _user!.displayName!.isNotEmpty) {
      return _user!.displayName;
    }
    return null; // Trả về null nếu không có tên nào
  }

  /// Stream để các thành phần bên ngoài (như AuthWrapper) có thể lắng nghe thay đổi User từ Firebase Auth.
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  // Constructor
  AuthProvider(this._authService, this._firestoreService) {
    print(
        "[AuthProvider] Constructor called. Initializing authentication state...");
    // Khởi tạo bất đồng bộ để không làm constructor bị block.
    _initializeAuthenticationState();
  }

  /// Khởi tạo trạng thái xác thực ban đầu và bắt đầu lắng nghe các thay đổi từ AuthService.
  Future<void> _initializeAuthenticationState() async {
    print("[AuthProvider _initializeAuthenticationState] Starting...");
    // Bước 1: Kiểm tra trạng thái xác thực hiện tại khi provider được tạo.
    await _checkInitialAuthState();
    // Bước 2: Bắt đầu lắng nghe các thay đổi trạng thái xác thực liên tục từ AuthService.
    _listenToAuthChanges();
    print(
        "[AuthProvider _initializeAuthenticationState] Initialization and listener setup complete. Current status: $_status");
  }

  /// Kiểm tra trạng thái xác thực ban đầu. Được gọi một lần khi provider khởi tạo.
  Future<void> _checkInitialAuthState() async {
    print(
        "[AuthProvider _checkInitialAuthState] Checking current Firebase user from AuthService...");
    try {
      _user = _authService
          .currentUser; // Giả sử _authService.currentUser là getter đồng bộ

      if (_user != null) {
        print(
            "[AuthProvider _checkInitialAuthState] Active user found: ${_user!.uid}. Attempting to load profile.");
        await _loadUserProfile(_user!.uid); // Tải hồ sơ Firestore cho user này
        // Sau khi tải profile (thành công hoặc không), cập nhật status thành authenticated
        _updateStatus(
            AuthStatus.authenticated, "Initial user check: Authenticated");
      } else {
        print(
            "[AuthProvider _checkInitialAuthState] No active user found. Status set to unauthenticated.");
        _userProfileData = null; // Đảm bảo profile cũng null
        _updateStatus(
            AuthStatus.unauthenticated, "Initial user check: Unauthenticated");
      }
    } catch (e) {
      print(
          "!!! [AuthProvider _checkInitialAuthState] Error: $e. Defaulting to unauthenticated.");
      _user = null;
      _userProfileData = null;
      _updateStatus(AuthStatus.unauthenticated,
          "Error checking initial auth state: ${e.toString()}");
    }
  }

  /// Lắng nghe các thay đổi trạng thái xác thực từ stream của AuthService.
  void _listenToAuthChanges() {
    _authStateListenerSubscription?.cancel(); // Hủy listener cũ nếu có
    print(
        "[AuthProvider _listenToAuthChanges] Subscribing to authStateChanges stream from AuthService...");
    _authStateListenerSubscription = _authService.authStateChanges.listen(
        (User? firebaseUserFromStream) async {
      // Đổi tên biến để rõ ràng
      print(
          "[AuthProvider _onAuthStateChanged] Auth stream event. New FirebaseUser: ${firebaseUserFromStream?.uid}. Current _user (before update): ${_user?.uid}");

      if (firebaseUserFromStream == null) {
        // Người dùng đã đăng xuất
        if (_user != null) {
          // Chỉ xử lý nếu trạng thái _user trước đó là có người dùng
          print(
              "[AuthProvider _onAuthStateChanged] User signed out via stream. Clearing user data and profile.");
          _user = null;
          _userProfileData = null;
          _updateStatus(
              AuthStatus.unauthenticated, "User signed out via stream");
        } else {
          // Trường hợp stream trả về null nhưng _user đã là null (ví dụ: khi khởi tạo và chưa đăng nhập)
          // Hoặc stream trả về null nhiều lần.
          // Đảm bảo status là unauthenticated nếu nó đang không phải là uninitialized (trạng thái khởi tạo ban đầu)
          if (_status != AuthStatus.unauthenticated &&
              _status != AuthStatus.uninitialized) {
            print(
                "[AuthProvider _onAuthStateChanged] Stream user is null, _user already null. Current status $_status -> unauthenticated.");
            _updateStatus(AuthStatus.unauthenticated, "Auth state became null");
          }
        }
      } else {
        // Người dùng đăng nhập hoặc user object thay đổi (ví dụ: token refresh, displayName update từ Firebase)
        bool userActuallyChanged = (_user?.uid != firebaseUserFromStream.uid);
        bool profileNeedsLoading = userActuallyChanged ||
            _userProfileData == null ||
            _userProfileData!['uid'] != firebaseUserFromStream.uid;

        _user =
            firebaseUserFromStream; // Cập nhật _user với thông tin mới nhất từ stream

        // Chỉ cập nhật status thành authenticated nếu nó chưa phải, để tránh notify thừa
        if (_status != AuthStatus.authenticated &&
            _status != AuthStatus.authenticating) {
          print(
              "[AuthProvider _onAuthStateChanged] User authenticated/changed. Current status $_status -> authenticated.");
          _updateStatus(AuthStatus.authenticated);
        }

        // Tải hoặc làm mới profile nếu user thay đổi hoặc profile chưa có
        if (profileNeedsLoading) {
          print(
              "[AuthProvider _onAuthStateChanged] User changed or profile missing/mismatched. Loading profile for ${firebaseUserFromStream.uid}.");
          await _loadUserProfile(
              firebaseUserFromStream.uid); // _loadUserProfile sẽ tự notify
        } else {
          // User không đổi, profile đã có. Có thể notify nếu muốn UI cập nhật với _user object mới (vd: emailVerified)
          // Tuy nhiên, nếu preferredDisplayName không đổi, có thể không cần.
          // Để đơn giản và đảm bảo UI luôn có dữ liệu mới nhất từ _user, ta có thể notify.
          if (userActuallyChanged) {
            // Chỉ notify nếu đối tượng User thực sự khác (ví dụ, sau khi displayName Auth được cập nhật)
            print(
                "[AuthProvider _onAuthStateChanged] User object instance might have changed. Notifying.");
            notifyListeners();
          } else {
            print(
                "[AuthProvider _onAuthStateChanged] User is the same and profile loaded. No extra notification needed from here.");
          }
        }
      }
    }, onError: (error) {
      print(
          "!!! [AuthProvider _onAuthStateChanged] Error in auth state stream: $error");
      _user = null;
      _userProfileData = null;
      _updateStatus(
          AuthStatus.error, "Error in auth stream: ${error.toString()}");
    });
    print(
        "[AuthProvider _listenToAuthChanges] Subscription to authStateChanges established.");
  }

  /// Tải hồ sơ người dùng từ Firestore.
  Future<void> _loadUserProfile(String userId) async {
    // Không cần cờ _isLoadingProfile ở đây nếu không có UI riêng cho việc này
    // và _updateStatus đã có cờ riêng cho authenticating.
    print(
        "[AuthProvider _loadUserProfile] Attempting to load profile for $userId...");
    Map<String, dynamic>? oldProfileData =
        _userProfileData != null ? Map.from(_userProfileData!) : null;

    try {
      final profileDoc = await _firestoreService.getUserProfile(userId);
      if (profileDoc != null && profileDoc.exists) {
        _userProfileData = profileDoc.data();
        print(
            "[AuthProvider _loadUserProfile] User profile for $userId loaded: ${_userProfileData?['displayName']}");
      } else {
        _userProfileData = null;
        print(
            "[AuthProvider _loadUserProfile] User profile not found in Firestore for $userId.");
      }
    } catch (e) {
      print(
          "!!! [AuthProvider _loadUserProfile] Error loading user profile for $userId: $e");
      _userProfileData = null;
    } finally {
      // Chỉ notifyListeners nếu dữ liệu profile thực sự thay đổi hoặc được tải lần đầu
      if (!mapEquals(oldProfileData, _userProfileData)) {
        print(
            "[AuthProvider _loadUserProfile] Profile data changed or loaded. Notifying. New preferredDisplayName: $preferredDisplayName");
        notifyListeners();
      } else {
        print(
            "[AuthProvider _loadUserProfile] Profile data for $userId unchanged. No notification.");
      }
    }
  }

  /// Cập nhật trạng thái nội bộ và thông báo cho các listeners.
  void _updateStatus(AuthStatus newStatus, [String? message]) {
    final String resolvedMessage = message ??
        (newStatus == AuthStatus.error
            ? "An authentication error occurred."
            : "");

    // Chỉ notify nếu status hoặc message thực sự thay đổi,
    // HOẶC nếu newStatus là authenticating (luôn cho phép chuyển sang/từ trạng thái này để UI cập nhật)
    if (_status == newStatus &&
        _lastErrorMessage == resolvedMessage &&
        newStatus != AuthStatus.authenticating &&
        _status != AuthStatus.authenticating) {
      return;
    }
    print(
        "[AuthProvider _updateStatus] Status changing from '$_status' to '$newStatus'. Message: '$resolvedMessage'");
    _status = newStatus;
    _lastErrorMessage = resolvedMessage;
    notifyListeners();
  }

  /// Đăng nhập bằng Email và Password.
  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    _updateStatus(AuthStatus.authenticating, "Signing in..."); // TODO: i18n
    _lastErrorMessage = '';
    try {
      final userCredential = await _authService
          .signInWithEmailAndPassword(email.trim(), password)
          .timeout(const Duration(seconds: 15));

      if (userCredential?.user != null) {
        // _listenToAuthChanges sẽ được trigger và gọi _loadUserProfile.
        // Tuy nhiên, để cập nhật lastLogin ngay, ta vẫn gọi updateUserProfile.
        await _firestoreService.updateUserProfile(userCredential!.user!,
            updateLastLogin: true);
        // Không cần set status authenticated ở đây, stream sẽ làm
        return true;
      } else {
        _lastErrorMessage =
            "Sign in failed: Invalid credentials or user not found."; // TODO: i18n
        _updateStatus(AuthStatus.unauthenticated, _lastErrorMessage);
        return false;
      }
    } on TimeoutException {
      _lastErrorMessage =
          "Sign in attempt timed out. Please check your connection."; // TODO: i18n
      _updateStatus(AuthStatus.unauthenticated, _lastErrorMessage);
      return false;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _mapAuthErrorCode(e.code);
      _updateStatus(AuthStatus.unauthenticated, _lastErrorMessage);
      return false;
    } catch (e) {
      _lastErrorMessage =
          "An unexpected error occurred during sign in."; // TODO: i18n
      _updateStatus(AuthStatus.unauthenticated, _lastErrorMessage);
      return false;
    }
  }

  /// Đăng ký người dùng mới bằng Email và Password.
  Future<bool> createUserWithEmailAndPassword(String email, String password,
      {String? displayName}) async {
    _updateStatus(
        AuthStatus.authenticating, "Creating account..."); // TODO: i18n
    _lastErrorMessage = '';
    try {
      final userCredential = await _authService
          .createUserWithEmailAndPassword(email.trim(), password)
          .timeout(const Duration(seconds: 15));

      final User? potentialNewUser = userCredential?.user;
      if (potentialNewUser != null) {
        User newUser = potentialNewUser; // Giờ newUser không null
        String? finalDisplayName = displayName?.trim();

        if (finalDisplayName != null && finalDisplayName.isNotEmpty) {
          try {
            print(
                "[AuthProvider] Attempting to update display name in Auth for ${newUser.uid} to '$finalDisplayName'...");
            await newUser.updateDisplayName(finalDisplayName);
            await newUser.reload();
            User? reloadedUser = _authService.currentUser;
            if (reloadedUser != null && reloadedUser.uid == newUser.uid)
              newUser = reloadedUser;
            finalDisplayName =
                newUser.displayName; // Cập nhật từ user đã reload
            print(
                "[AuthProvider] Display name updated in Auth: ${newUser.displayName}");
          } catch (e) {
            print(
                "!!! [AuthProvider] Warning: Failed to update display name in Auth: $e");
            // Giữ nguyên finalDisplayName ban đầu nếu reload lỗi
          }
        } else {
          finalDisplayName = null;
        }

        // Tạo hồ sơ trên Firestore
        try {
          print(
              "[AuthProvider] Creating user profile in Firestore for ${newUser.uid}...");
          await _firestoreService.updateUserProfile(newUser,
              displayName: finalDisplayName, isNewUser: true);
          print("[AuthProvider] User profile created in Firestore.");

          // Tải profile vừa tạo vào state của AuthProvider ngay
          await _loadUserProfile(newUser.uid);
          // _listenToAuthChanges sẽ được trigger bởi user mới từ stream và có thể gọi lại _loadUserProfile,
          // nhưng việc gọi ở đây đảm bảo _userProfileData có sớm hơn.
          // Trạng thái sẽ chuyển sang authenticated qua stream listener.
          return true;
        } catch (firestoreError) {
          print(
              "!!! CRITICAL: Failed to create Firestore profile after sign up: $firestoreError");
          _lastErrorMessage =
              "Failed to create user profile. Please try again."; // TODO: i18n
          _updateStatus(
              AuthStatus.error, _lastErrorMessage); // Dùng status error
          return false;
        }
      } else {
        _lastErrorMessage =
            "Sign up failed: Could not create user."; // TODO: i18n
        _updateStatus(AuthStatus.unauthenticated, _lastErrorMessage);
        return false;
      }
    } on TimeoutException {
      /* ... */ return false;
    } on FirebaseAuthException catch (e) {
      /* ... */ return false;
    } catch (e) {
      /* ... */ return false;
    }
  }

  /// Ánh xạ mã lỗi Firebase Auth sang thông báo dễ hiểu.
  String _mapAuthErrorCode(String code) {
    // TODO: Dịch các thông báo này
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'The email address is badly formatted.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'email-already-in-use':
        return 'This email address is already in use by another account.';
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        print("[AuthProvider] Unmapped Auth Error Code: $code");
        return 'An unknown authentication error occurred ($code).';
    }
  }

  /// Đăng nhập bằng Google.
  Future<bool> signInWithGoogle() async {
    _updateStatus(
        AuthStatus.authenticating, "Signing in with Google..."); // TODO: i18n
    _lastErrorMessage = '';
    try {
      final userCredential = await _authService
          .signInWithGoogle()
          .timeout(const Duration(seconds: 20));
      if (userCredential?.user != null) {
        // _listenToAuthChanges sẽ xử lý việc tải profile.
        // Chỉ cần gọi updateUserProfile để đảm bảo thông tin từ Google (nếu là user mới) và lastLogin được cập nhật.
        await _firestoreService.updateUserProfile(userCredential!.user!,
            displayName: userCredential.user!.displayName,
            photoURL: userCredential.user!.photoURL,
            isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
            updateLastLogin: true);
        // Nếu là user mới và profile được tạo, _loadUserProfile sẽ được gọi trong _listenToAuthChanges
        return true;
      } else {
        /* ... */ return false;
      }
    } on TimeoutException {
      /* ... */ return false;
    } on PlatformException catch (e) {
      /* ... */ return false;
    } catch (e) {
      /* ... */ return false;
    }
  }

  /// Đăng xuất người dùng.
  Future<void> signOut() async {
    print("[AuthProvider] Attempting to sign out...");
    try {
      await _authService.signOut();
      // _listenToAuthChanges sẽ tự động cập nhật _user=null, _userProfileData=null, _status=unauthenticated
      print(
          "[AuthProvider] signOut call successful. Auth stream will update status.");
    } catch (e) {
      print("!!! [AuthProvider] Error signing out: $e");
      _updateStatus(AuthStatus.unauthenticated,
          "Failed to sign out: ${e.toString()}"); // TODO: i18n
    }
  }

  /// Gửi email đặt lại mật khẩu.
  Future<bool> sendPasswordResetEmail(String email) async {
    _lastErrorMessage = '';
    print(
        "[AuthProvider] Attempting to send password reset email to $email...");
    try {
      await _authService.sendPasswordResetEmail(email.trim());
      print("[AuthProvider] Password reset email sent successfully.");
      return true;
    } on FirebaseAuthException catch (e) {
      _lastErrorMessage = _mapAuthErrorCode(e.code);
      notifyListeners(); // Chỉ notify để UI cập nhật lỗi
      return false;
    } catch (e) {
      _lastErrorMessage =
          "An unexpected error occurred while sending the reset email."; // TODO: i18n
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    print("[AuthProvider dispose] Disposing AuthProvider...");
    _authStateListenerSubscription?.cancel();
    print("[AuthProvider dispose] AuthState listener cancelled.");
    super.dispose();
  }
}
