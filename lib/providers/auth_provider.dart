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

  Map<String, dynamic>? _userProfileData; // Lưu trữ dữ liệu đọc từ Firestore
  final bool _isLoadingProfile = false; // Trạng thái đang tải profile

  // <<< THÊM GETTER CHO PROFILE DATA >>>
  Map<String, dynamic>? get userProfileData => _userProfileData;
  bool get isLoadingProfile =>
      _isLoadingProfile; // Có thể dùng để hiển thị loading nếu cần

  // Getter tiện lợi để lấy tên hiển thị (Ưu tiên Firestore, fallback về Auth)
  String? get preferredDisplayName {
    // Ưu tiên lấy từ Firestore profile nếu có
    if (_userProfileData != null && _userProfileData!['displayName'] != null) {
      return _userProfileData!['displayName'] as String?;
    }
    // Nếu không, fallback về displayName từ Firebase Auth user
    return _user?.displayName;
  }

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

  // <<< HÀM MỚI ĐỂ TẢI PROFILE TỪ FIRESTORE >>>
  Future<void> _loadUserProfile(String userId) async {
    if (_isLoadingProfile) return; // Tránh tải lại khi đang tải
    print("[AuthProvider] Loading user profile from Firestore for $userId...");
    // Đặt trạng thái loading (tùy chọn, chỉ cần nếu bạn muốn hiển thị indicator riêng)
    // _isLoadingProfile = true;
    // notifyListeners(); // Thông báo bắt đầu tải (nếu cần)

    try {
      final profileDoc = await _firestoreService.getUserProfile(userId);
      if (profileDoc != null && profileDoc.exists) {
        _userProfileData = profileDoc.data();
        print(
            "[AuthProvider] User profile loaded: ${_userProfileData?['displayName']}");
      } else {
        _userProfileData = null; // Không tìm thấy profile
        print(
            "[AuthProvider] User profile not found in Firestore for $userId.");
      }
    } catch (e) {
      print("!!! [AuthProvider] Error loading user profile: $e");
      _userProfileData = null; // Đặt là null nếu lỗi
    } finally {
      // Đặt trạng thái hết loading (tùy chọn)
      // _isLoadingProfile = false;
      // Luôn gọi notifyListeners để cập nhật UI với profile mới (hoặc null)
      notifyListeners();
    }
  }

  Future<void> _checkInitialAuthState() async {
    try {
      // Kiểm tra user hiện tại với timeout
      final firebaseUser = await Future.value(_authService.currentUser)
          .timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('Initial auth check timeout');
      });
      _user = firebaseUser;
      _updateStatus(AuthStatus.authenticated);
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
      // Thêm async
      if (firebaseUser == null) {
        // Xử lý đăng xuất
        if (_user != null) {
          _user = null;
          _userProfileData = null; // <<< XÓA PROFILE KHI ĐĂNG XUẤT
          _updateStatus(
              AuthStatus.unauthenticated, "User signed out via stream");
        }
      } else {
        // Xử lý đăng nhập hoặc thay đổi user
        bool needsProfileLoad = _user?.uid != firebaseUser.uid ||
            _userProfileData ==
                null; // Cần load nếu user mới hoặc chưa có profile
        _user = firebaseUser;
        _updateStatus(
            AuthStatus.authenticated); // Cập nhật trạng thái auth trước

        // <<< GỌI TẢI PROFILE NẾU CẦN >>>
        if (needsProfileLoad) {
          await _loadUserProfile(firebaseUser.uid); // Gọi hàm tải profile
        }
        // -----------------------------
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
    // Thêm dấu {} để displayName là named parameter
    _updateStatus(AuthStatus.authenticating, "Creating account...");
    try {
      final userCredential = await _authService
          .createUserWithEmailAndPassword(
              email, password) // AuthService chỉ cần email, password
          .timeout(const Duration(seconds: 10));

      if (userCredential?.user != null) {
        User newUser = userCredential!.user!; // Lấy user mới tạo

        // <<< THÊM BƯỚC CẬP NHẬT DISPLAY NAME CHO FIREBASE AUTH >>>
        if (displayName != null && displayName.trim().isNotEmpty) {
          try {
            print("Attempting to update display name for new user...");
            await newUser.updateDisplayName(displayName.trim());
            // Tải lại để chắc chắn có thông tin mới nhất
            await newUser.reload();
            newUser = _authService.firebaseAuth.currentUser ??
                newUser; // Lấy lại user đã cập nhật
            print("Display name updated in Auth: ${newUser.displayName}");
          } catch (e) {
            print("!!! Warning: Failed to update display name in Auth: $e");
            // Tiếp tục tạo profile Firestore
          }
        }

        // ---------------------------------------------------------

        // <<< GỌI updateUserProfile VỚI USER ĐÃ CÓ THỂ CÓ DISPLAYNAME >>>
        await _firestoreService.updateUserProfile(newUser,
            displayName:
                newUser.displayName); // Truyền displayName từ user đã cập nhật
        print("User profile created/updated in Firestore for ${newUser.uid}");
        // Auth state sẽ tự cập nhật qua stream listener
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
      print("!!! Sign up FirebaseAuthException: ${e.code}"); // Log code lỗi
      _updateStatus(AuthStatus.unauthenticated,
          _mapAuthErrorCode(e.code)); // Sử dụng hàm map lỗi
      return false;
    } catch (e) {
      print("!!! Sign up general error: $e");
      _updateStatus(AuthStatus.unauthenticated,
          "An unexpected error occurred during sign up.");
      return false;
    }
  }

  String _mapAuthErrorCode(String code) {
    // TODO: Dịch các thông báo lỗi này bằng l10n nếu muốn
    switch (code) {
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
      // Thêm các mã lỗi Firebase Auth khác nếu cần
      case 'user-not-found': // <<< Lỗi thường gặp khi reset
        return 'No user found with this email address.';
      default:
        print(
            "[AuthProvider] Unmapped Auth Error Code: $code"); // Log lỗi chưa map
        return 'An unknown authentication error occurred ($code).'; // Trả về cả code lỗi
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

// <<< THÊM HÀM GỬI EMAIL RESET MẬT KHẨU >>>
  Future<bool> sendPasswordResetEmail(String email) async {
    _lastErrorMessage = ''; // Xóa lỗi cũ
    // Không cần đặt trạng thái authenticating vì thao tác này thường nhanh
    // _updateStatus(AuthStatus.authenticating, "Sending reset email...");

    print(
        "[AuthProvider] Attempting to send password reset email to $email...");
    try {
      await _authService.sendPasswordResetEmail(email);
      print("[AuthProvider] Password reset email sent successfully.");
      // Có thể đặt một thông báo thành công tạm thời nếu muốn
      // _lastErrorMessage = "Password reset email sent."; // Hoặc để trống
      // Không cần cập nhật status ở đây
      return true; // Thành công
    } on FirebaseAuthException catch (e) {
      print(
          "!!! [AuthProvider] Failed to send reset email (FirebaseAuthException): ${e.code}");
      _lastErrorMessage = _mapAuthErrorCode(e.code); // Map lỗi
      // Không cần cập nhật status thành error, chỉ cần lưu lỗi
      notifyListeners(); // Thông báo để UI có thể đọc lỗi mới (nếu cần)
      return false; // Thất bại
    } catch (e) {
      print(
          "!!! [AuthProvider] Failed to send reset email (General Error): $e");
      _lastErrorMessage =
          "An unexpected error occurred while sending the reset email."; // TODO: i18n
      notifyListeners();
      return false; // Thất bại
    }
  }

  // ------------------------------------------
  @override
  void dispose() {
    print("Disposing AuthProvider (Fixed Version)...");
    _authStateSubscription?.cancel();
    print("AuthProvider disposed.");
    super.dispose();
  }
}
