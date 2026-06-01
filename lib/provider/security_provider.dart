import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import '../security/logging_utility.dart';
import '../services/session_manager_service_v2.dart';

class SecurityProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final http.Client _httpClient;

  SecurityProvider({
    AuthRepository? authRepository,
    http.Client? httpClient,
  })  : _authRepository = authRepository ?? AuthRepository(),
        _httpClient = httpClient ?? http.Client();

  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  bool _isAuthenticated = false;
  AuthUserResponse? _currentUser;
  bool _isLoading = false;
  String? _lastError;

  bool get isAuthenticated => _isAuthenticated;
  AuthUserResponse? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  Future<bool> signInWithEmailPassword(String email, String password) async {
    try {
      _setLoading(true);

      final response = await _authRepository.login(
        identifier: email,
        password: password,
      );
      await TokenStorage.saveTokens(response.session);
      await TokenStorage.saveUserId(response.user.id);
      await SessionManagerServiceV2.instance.ensureSessionRegistered();

      _currentUser = response.user;
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } catch (e) {
      logError('Login failed', error: e);
      _lastError = _friendlyAuthError(e, 'login');
      logDebug('Login failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signOut() async {
    try {
      _setLoading(true);
      await SessionManagerServiceV2.instance.userLogout();

      _currentUser = null;
      _isAuthenticated = false;
      notifyListeners();
      return true;
    } catch (e) {
      logError('Logout failed', error: e);
      _lastError = _friendlyAuthError(e, 'logout');
      logDebug('Logout failed: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> checkAuthStatus() async {
    try {
      final hasSession = await TokenStorage.hasValidSession();
      if (!hasSession) {
        _currentUser = null;
        _isAuthenticated = false;
        notifyListeners();
        return;
      }

      final accessToken = await TokenStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        try {
          final user = await _authRepository.me(accessToken);
          await TokenStorage.saveUserId(user.id);
          _currentUser = user;
          _isAuthenticated = true;
          notifyListeners();
          return;
        } catch (e) {
          logDebug('Could not refresh current user from backend: $e');
        }
      }

      final userId = await TokenStorage.getUserId();
      _currentUser = userId == null
          ? null
          : AuthUserResponse(
              id: userId,
              fullName: '',
              accountStatus: 'active',
              profileCompleted: false,
              createdAt: DateTime.now(),
            );
      _isAuthenticated = _currentUser != null;
      notifyListeners();
    } catch (e) {
      logDebug('Auth status check failed: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearErrors() {
    _lastError = null;
    notifyListeners();
  }

  String _friendlyAuthError(Object error, String context) {
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection')) {
      return 'مشکل در اتصال به سرور. لطفا اینترنت خود را بررسی کنید.';
    }
    if (text.contains('timeout')) {
      return 'زمان اتصال به سرور به پایان رسید. لطفا دوباره تلاش کنید.';
    }
    if (context == 'logout') {
      return 'خروج ناموفق بود. لطفا دوباره تلاش کنید.';
    }
    if (text.contains('401') ||
        text.contains('invalid') ||
        text.contains('unauthorized')) {
      return 'نام کاربری یا رمز عبور نادرست است.';
    }
    return 'ورود ناموفق بود. لطفا دوباره تلاش کنید.';
  }

  Future<Map<String, String>?> _authHeaders() async {
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return null;
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  Future<int> getBlockedUsersCount() async {
    try {
      final headers = await _authHeaders();
      if (headers == null) return 0;

      final response = await _httpClient
          .get(Uri.parse('$_backendUrl/v1/me/blocked-users'), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logDebug('Blocked users count failed: ${response.statusCode}');
        return 0;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return 0;
      final profiles = decoded['profiles'];
      return profiles is List ? profiles.length : 0;
    } catch (e) {
      logDebug('Blocked users count failed: $e');
      return 0;
    }
  }

  Future<bool> isUserBlocked(String userId) async {
    try {
      final headers = await _authHeaders();
      if (headers == null || userId.trim().isEmpty) return false;

      final response = await _httpClient
          .get(
            Uri.parse(
              '$_backendUrl/v1/me/block-status/${Uri.encodeComponent(userId)}',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        logDebug('Block status failed: ${response.statusCode}');
        return false;
      }

      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> && decoded['is_blocked'] == true;
    } catch (e) {
      logDebug('Block status failed: $e');
      return false;
    }
  }
}

final securityProvider = ChangeNotifierProvider<SecurityProvider>((ref) {
  return SecurityProvider();
});

final authStateProvider = StreamProvider<bool>((ref) async* {
  yield await TokenStorage.hasValidSession();
});

final currentUserProvider = Provider<AuthUserResponse?>((ref) {
  return ref.watch(securityProvider).currentUser;
});

final blockedUsersCountProvider = FutureProvider<int>((ref) async {
  final securityNotifier = ref.read(securityProvider);
  return securityNotifier.getBlockedUsersCount();
});
