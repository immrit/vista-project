import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/auth_repository.dart';
import '../../../services/current_user_service.dart';
import '../../../services/session_manager_service_v2.dart';
import '../../../services/PushNotificationService.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Ø°Ø®ÛŒØ±Ù‡â€ŒØ³Ø§Ø²ÛŒ Ø§Ù…Ù† ØªÙˆÚ©Ù† â€” Ø¬Ø§ÛŒÚ¯Ø²ÛŒÙ† legacy auth
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class TokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _accessTokenKey = 'vista_access_token';
  static const _refreshTokenKey = 'vista_refresh_token';
  static const _userIdKey = 'vista_user_id';
  static const _expiresAtKey = 'vista_expires_at';
  static const _hasPasswordKey = 'vista_has_password';
  static const _passwordRequiredKey = 'vista_password_required';

  static Future<void> saveTokens(AuthSessionResponse session) async {
    final expiresAt =
        _accessTokenExpiresAt(session.accessToken) ?? session.expiresAt;
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: session.accessToken),
      _storage.write(key: _refreshTokenKey, value: session.refreshToken),
      _storage.write(
        key: _expiresAtKey,
        value: expiresAt.toUtc().toIso8601String(),
      ),
    ]);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
    CurrentUserService.setCachedUserId(userId);
  }

  static Future<void> saveUserAuthState(AuthUserResponse user) async {
    await Future.wait([
      saveUserId(user.id),
      _storage.write(key: _hasPasswordKey, value: user.hasPassword.toString()),
      _storage.write(
        key: _passwordRequiredKey,
        value: user.passwordRequired.toString(),
      ),
    ]);
  }

  static Future<bool?> getPasswordRequired() async {
    final stored = await _storage.read(key: _passwordRequiredKey);
    if (stored == null) return null;
    return stored == 'true';
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  static Future<String?> getUserId() async {
    final stored = await _storage.read(key: _userIdKey);
    if (stored != null && stored.isNotEmpty) {
      CurrentUserService.setCachedUserId(stored);
      return stored;
    }

    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final sub = decoded['sub']?.toString();
      if (sub == null || sub.isEmpty) return null;

      await saveUserId(sub);
      final hasPassword = decoded['has_password'];
      final passwordRequired = decoded['password_required'];
      if (hasPassword is bool) {
        await _storage.write(
            key: _hasPasswordKey, value: hasPassword.toString());
      }
      if (passwordRequired is bool) {
        await _storage.write(
          key: _passwordRequiredKey,
          value: passwordRequired.toString(),
        );
      }
      return sub;
    } catch (e) {
      debugPrint('Failed to derive user id from access token: $e');
      return null;
    }
  }

  static Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null || token.isEmpty) return false;

    final storedExpiresAt = await _storage.read(key: _expiresAtKey);
    final expiresAt = _accessTokenExpiresAt(token) ??
        (storedExpiresAt == null ? null : DateTime.tryParse(storedExpiresAt));
    if (expiresAt == null) return false;

    // Keep a small clock-skew buffer without forcing short-lived tokens into
    // a refresh loop immediately after login.
    return expiresAt
        .toUtc()
        .isAfter(DateTime.now().toUtc().add(const Duration(seconds: 30)));
  }

  static Future<bool> hasRefreshToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token != null && token.isNotEmpty;
  }

  static Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _expiresAtKey),
      _storage.delete(key: _hasPasswordKey),
      _storage.delete(key: _passwordRequiredKey),
    ]);
    CurrentUserService.clearCache();
  }

  static DateTime? _accessTokenExpiresAt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;

      final exp = decoded['exp'];
      if (exp is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
          isUtc: true,
        );
      }
      if (exp is String) {
        final seconds = int.tryParse(exp);
        if (seconds == null) return null;
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000,
          isUtc: true,
        );
      }
    } catch (_) {}
    return null;
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Auth State
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AuthState {
  final bool isLoading;
  final String? error;
  final bool codeSent;
  final bool isLoggedIn;
  final bool isNewUser;
  final AuthUserResponse? currentUser;
  final String? otpDebugCode;
  final bool is2faRequired;
  final String? twoFactorToken;

  AuthState({
    this.isLoading = false,
    this.error,
    this.codeSent = false,
    this.isLoggedIn = false,
    this.isNewUser = false,
    this.currentUser,
    this.otpDebugCode,
    this.is2faRequired = false,
    this.twoFactorToken,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? codeSent,
    bool? isLoggedIn,
    bool? isNewUser,
    AuthUserResponse? currentUser,
    String? otpDebugCode,
    bool clearOtpDebugCode = false,
    bool? is2faRequired,
    String? twoFactorToken,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      codeSent: codeSent ?? this.codeSent,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      isNewUser: isNewUser ?? this.isNewUser,
      currentUser: currentUser ?? this.currentUser,
      otpDebugCode:
          clearOtpDebugCode ? null : (otpDebugCode ?? this.otpDebugCode),
      is2faRequired: is2faRequired ?? this.is2faRequired,
      twoFactorToken: twoFactorToken ?? this.twoFactorToken,
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Auth Controller â€” Ù…Ø³ØªÙ‚Ù„ Ø§Ø² legacy auth
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(AuthState());

  Future<void> _syncFcmTokenAfterAuth() async {
    await PushNotificationService.syncIfNeeded(afterAuth: true);
  }

  // â”€â”€â”€ Ø¨Ø±Ø±Ø³ÛŒ Ù†Ø´Ø³Øª Ø°Ø®ÛŒØ±Ù‡ Ø´Ø¯Ù‡ Ù‡Ù†Ú¯Ø§Ù… Ø´Ø±ÙˆØ¹ Ø§Ù¾Ù„ÛŒÚ©ÛŒØ´Ù† â”€â”€â”€
  Future<void> checkSavedSession() async {
    try {
      final hasSession = await TokenStorage.hasValidSession();
      if (hasSession) {
        final userId = await TokenStorage.getUserId();
        final passwordRequired = await TokenStorage.getPasswordRequired();
        state = state.copyWith(
          isLoggedIn: true,
          currentUser: userId != null
              ? AuthUserResponse(
                  id: userId,
                  fullName: '',
                  accountStatus: 'active',
                  profileCompleted: false,
                  hasPassword: passwordRequired == false,
                  passwordRequired: passwordRequired ?? false,
                  createdAt: DateTime.now(),
                )
              : null,
        );
      }
    } catch (e) {
      debugPrint('âš ï¸ Error checking saved session: $e');
    }
  }

  // â”€â”€â”€ Ø«Ø¨Øªâ€ŒÙ†Ø§Ù… â”€â”€â”€
  Future<bool> register({
    String? username,
    required String fullName,
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearOtpDebugCode: true,
    );
    try {
      final response = await _repository.register(
        username: username,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
      );

      // Ø°Ø®ÛŒØ±Ù‡ ØªÙˆÚ©Ù†â€ŒÙ‡Ø§
      await TokenStorage.saveTokens(response.session);
      await TokenStorage.saveUserAuthState(response.user);
      await SessionManagerServiceV2.instance
          .ensureSessionRegistered(force: true);
      await _syncFcmTokenAfterAuth();

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        isNewUser: response.isNewUser,
        currentUser: response.user,
      );
      return true;
    } catch (e) {
      await TokenStorage.clearAll();
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // â”€â”€â”€ ÙˆØ±ÙˆØ¯ Ø¨Ø§ Ø§ÛŒÙ…ÛŒÙ„/Ø´Ù…Ø§Ø±Ù‡/Ù†Ø§Ù… Ú©Ø§Ø±Ø¨Ø±ÛŒ â”€â”€â”€
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.login(
        identifier: identifier,
        password: password,
      );

      // Ø°Ø®ÛŒØ±Ù‡ ØªÙˆÚ©Ù†â€ŒÙ‡Ø§
      await TokenStorage.saveTokens(response.session);
      await TokenStorage.saveUserAuthState(response.user);
      await SessionManagerServiceV2.instance
          .ensureSessionRegistered(force: true);
      await _syncFcmTokenAfterAuth();

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        isNewUser: false,
        currentUser: response.user,
      );
      return true;
    } catch (e) {
      await TokenStorage.clearAll();
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // â”€â”€â”€ Ø§Ø±Ø³Ø§Ù„ OTP â”€â”€â”€
  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearOtpDebugCode: true,
    );
    try {
      final response = await _repository.sendOtp(phone);
      if (response.success) {
        state = state.copyWith(
          isLoading: false,
          codeSent: true,
          otpDebugCode: response.debugCode,
        );
        return true;
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Ø§Ø±Ø³Ø§Ù„ Ù†Ø§Ù…ÙˆÙÙ‚ Ø¨ÙˆØ¯');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // â”€â”€â”€ ØªØ§ÛŒÛŒØ¯ OTP â”€â”€â”€
  // ─── تایید OTP ───
  Future<bool> verifyOtp({
    required String phone,
    required String token,
    bool isUpdateMode = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.verifyOtp(
        phoneNumber: phone,
        code: token,
      );

      if (response.is2faRequired && response.twoFactorToken != null) {
        state = state.copyWith(
          isLoading: false,
          is2faRequired: true,
          twoFactorToken: response.twoFactorToken,
        );
        return true;
      }

      final auth = response.auth;
      if (auth == null) throw Exception('Auth response missing');

      await TokenStorage.saveTokens(auth.session);
      await TokenStorage.saveUserAuthState(auth.user);
      if (!isUpdateMode) {
        await SessionManagerServiceV2.instance
            .ensureSessionRegistered(force: true);
        await _syncFcmTokenAfterAuth();
      }

      if (!isUpdateMode) {
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: true,
          isNewUser: auth.isNewUser,
          currentUser: auth.user,
          is2faRequired: false,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e) {
      await TokenStorage.clearAll();
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  // ─── تایید ۲FA ───
  Future<bool> verify2fa({
    required String password,
  }) async {
    final token = state.twoFactorToken;
    if (token == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _repository.verify2fa(
        token: token,
        password: password,
      );

      await TokenStorage.saveTokens(response.session);
      await TokenStorage.saveUserAuthState(response.user);
      await SessionManagerServiceV2.instance
          .ensureSessionRegistered(force: true);
      await _syncFcmTokenAfterAuth();

      state = state.copyWith(
        isLoading: false,
        isLoggedIn: true,
        isNewUser: response.isNewUser,
        currentUser: response.user,
        is2faRequired: false,
      );
      return true;
    } catch (e) {
      await TokenStorage.clearAll();
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // â”€â”€â”€ Ø®Ø±ÙˆØ¬ â”€â”€â”€
  Future<AuthUserResponse?> refreshCurrentUser() async {
    try {
      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken == null || accessToken.isEmpty) return null;

      final user = await _repository.me(accessToken);
      await TokenStorage.saveUserAuthState(user);
      state = state.copyWith(
        isLoggedIn: true,
        isNewUser: false,
        currentUser: user,
      );
      return user;
    } catch (e) {
      debugPrint('Error refreshing current user: $e');
      return null;
    }
  }

  void acceptAuthenticatedUser(AuthUserResponse user) {
    unawaited(TokenStorage.saveUserAuthState(user));
    state = state.copyWith(
      isLoading: false,
      isLoggedIn: true,
      isNewUser: false,
      currentUser: user,
    );
  }

  Future<void> logout() async {
    await SessionManagerServiceV2.instance.userLogout();
    await TokenStorage.clearAll();
    state = AuthState(); // reset to initial state
  }

  // â”€â”€â”€ Ø±ÛŒØ³Øª Ø®Ø·Ø§ â”€â”€â”€
  void clearError() {
    state = state.copyWith(error: null);
  }

  // â”€â”€â”€ Ø±ÛŒØ³Øª codeSent â”€â”€â”€
  void resetCodeSent() {
    state = state.copyWith(codeSent: false);
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Providers
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthRepository());
});

/// Ø¢ÛŒØ§ Ú©Ø§Ø±Ø¨Ø± Ù„Ø§Ú¯ÛŒÙ† Ø§Ø³ØªØŸ
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authControllerProvider).isLoggedIn;
});

/// Ú©Ø§Ø±Ø¨Ø± Ù„Ø§Ú¯ÛŒÙ† Ø´Ø¯Ù‡
final activeUserProvider = Provider<AuthUserResponse?>((ref) {
  return ref.watch(authControllerProvider).currentUser;
});

/// ØªÙˆÚ©Ù† Ø¯Ø³ØªØ±Ø³ÛŒ ÙØ¹Ù„ÛŒ
final accessTokenProvider = FutureProvider<String?>((ref) async {
  return TokenStorage.getAccessToken();
});

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Ù¾Ø±ÙˆØ³Ø§ÛŒØ¯Ø±Ù‡Ø§ÛŒ Ø³Ø§Ø²Ú¯Ø§Ø±ÛŒ Ø¨Ø§ Ú©Ø¯Ù‡Ø§ÛŒ Ù‚Ø¨Ù„ÛŒ (Backward Compatibility)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class DummyUserModel {
  final String id;
  const DummyUserModel(this.id);
}

final authProvider = Provider<DummyUserModel?>((ref) {
  final user = ref.watch(activeUserProvider);
  if (user != null) {
    return DummyUserModel(user.id);
  }
  return null;
});

final userAuthStateProvider = StreamProvider<DummyUserModel?>((ref) async* {
  final user = ref.watch(activeUserProvider);
  if (user != null) {
    yield DummyUserModel(user.id);
  } else {
    yield null;
  }
});

// P4: one-shot action provider — autoDispose so it never lingers after the call.
final changePasswordProvider = FutureProvider.autoDispose
    .family<void, ({String oldPassword, String newPassword})>((ref, args) async {
  // TODO: Implement change password with the Go backend API
  throw UnimplementedError('Change password is not implemented yet.');
});
