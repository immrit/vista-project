import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/auth/domain/auth_exceptions.dart';
import '../model/session_model.dart';
import '../security/logging_utility.dart';
import '../services/current_user_service.dart';
import '../services/device_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SessionVerificationState { verified, pendingVerification, invalid }

enum RefreshResult { success, authError, networkError }

/// 🚀 Session Manager V2 — Go Backend Edition
///
/// Auth tokens are managed via TokenStorage (flutter_secure_storage).
/// Session records are kept in the custom Go backend.
class SessionManagerServiceV2 {
  static final SessionManagerServiceV2 _instance =
      SessionManagerServiceV2._internal();
  factory SessionManagerServiceV2() => _instance;
  static SessionManagerServiceV2 get instance => _instance;
  SessionManagerServiceV2._internal();

  // ─── State ───────────────────────────────────────────────────
  String? _currentSessionId;
  String? _sessionToken;
  Timer? _activityTimer;
  Timer? _healthCheckTimer;
  SessionVerificationState _verificationState =
      SessionVerificationState.pendingVerification;

  bool _isInitialized = false;
  bool _isRegistering = false;
  bool _isInBackground = false;
  DateTime? _lastActivityUpdate;
  bool _isTerminating = false;
  Future<RefreshResult>? _refreshInFlight;

  // ─── Config ──────────────────────────────────────────────────
  static const Duration _activityUpdateInterval = Duration(minutes: 3);
  static const Duration _healthCheckInterval = Duration(minutes: 2);
  static const String _sessionIdStorageKey = 'session_manager_v2.session_id';
  static const String _sessionTokenStorageKey =
      'session_manager_v2.session_token';
  static const Duration _backendTimeout = Duration(seconds: 10);

  // ─── Callbacks ───────────────────────────────────────────────
  Function()? onSessionTerminated;

  // ─── Public Getters ──────────────────────────────────────────
  String? get currentSessionId => _currentSessionId;
  bool get isSessionActive => _currentSessionId != null;
  String? get currentSessionToken => _sessionToken;
  bool get isInBackground => _isInBackground;
  SessionVerificationState get verificationState => _verificationState;

  // ─── Backend helpers ─────────────────────────────────────────
  String get _backendUrl => EnvConfig.apiBaseUrl;

  Uri _backendUri(String path) => Uri.parse('$_backendUrl$path');

  Future<String?> _getAccessToken() async => TokenStorage.getAccessToken();

  Future<String?> _getAuthenticatedUserId() async =>
      CurrentUserService.instance.resolveUserId();

  Future<bool> _hasAnyAuthSession() async =>
      await TokenStorage.hasValidSession() ||
      await TokenStorage.hasRefreshToken();

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Device-ID': DeviceIdService.id,
    };
    final token = await _getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _backendRequest({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final headers = await _buildHeaders();
    final uri = _backendUri(path);
    http.Response response;
    if (method == 'GET') {
      response = await http.get(uri, headers: headers).timeout(_backendTimeout);
    } else {
      response = await http
          .post(uri,
              headers: headers, body: body == null ? null : jsonEncode(body))
          .timeout(_backendTimeout);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = _decodeBody(response.body);
      logInfo(
          '❌ Backend request failed: HTTP ${response.statusCode} ${response.request?.url} - Response: ${response.body}');
      if (payload is Map) {
        throw payload['message']?.toString() ??
            payload['error']?.toString() ??
            'HTTP ${response.statusCode}: ${response.body}';
      }
      throw 'HTTP ${response.statusCode}: ${response.body}';
    }
    logInfo('✅ Backend request success: $method $path');
    return _decodeBody(response.body);
  }

  // ─── Helper: get/set userId from CurrentUserService ──────────
  void _markSessionPendingAndRecover() {
    _verificationState = SessionVerificationState.pendingVerification;
    if (!_isRegistering) _registerSessionInBackground();
  }

  // ═══════════════════════════════════════════════════════════
  // APP LIFECYCLE
  // ═══════════════════════════════════════════════════════════

  Future<void> onAppPaused() async {
    _isInBackground = true;
    logInfo('⏸️ App paused');
    _stopHealthCheck();
    await _saveSession();
  }

  Future<void> onAppResumed() async {
    final wasPaused = _isInBackground;
    _isInBackground = false;
    if (!wasPaused || _currentSessionId == null) return;

    logInfo('▶️ App resumed — checking token...');
    final hasValid = await TokenStorage.hasValidSession();
    if (!hasValid) {
      logInfo('🔄 Token expiring soon, refreshing...');
      await _refreshSessionWithRetry();
    }
    _startActivityTracking();
    _startHealthCheck();
    _setupRealtimeListener();
    _updateActivity();
  }

  // ═══════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      logInfo('🔧 Initializing Session Manager V2...');
      await _loadSavedSession();

      if (_currentSessionId != null) {
        logInfo('🚀 Local session found. Trusting it.');
        _isInitialized = true;
        _startActivityTracking();
        _startHealthCheck();
        _setupRealtimeListener();
        _syncWithServerInBackground();
        return;
      }

      final hasAuth = await _hasAnyAuthSession();
      if (hasAuth) {
        logInfo('✅ Auth token exists, finding session...');
        await _findSessionFromToken();
        _startActivityTracking();
        _startHealthCheck();
        _setupRealtimeListener();
      }
      _isInitialized = true;
    } catch (e) {
      logInfo('❌ Error initializing Session Manager: $e');
    }
  }

  void _syncWithServerInBackground() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final valid = await _quickSessionCheck();
        if (!valid) {
          logInfo('⚠️ Background sync: session invalid, recovering...');
          _markSessionPendingAndRecover();
        }
      } catch (e) {
        logInfo('⚠️ Background sync failed (ignored): $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION REGISTRATION
  // ═══════════════════════════════════════════════════════════

  Future<String?> registerSession({bool force = false}) async {
    if (_isRegistering) return _currentSessionId;
    if (!force &&
        _currentSessionId != null &&
        _verificationState == SessionVerificationState.verified) {
      return _currentSessionId;
    }
    _isRegistering = true;

    try {
      final userId = await _getAuthenticatedUserId();
      if (userId == null) {
        _isRegistering = false;
        return null;
      }

      _sessionToken = const Uuid().v4();
      final sessionId = const Uuid().v4();
      SessionDeviceInfo? deviceInfo;
      try {
        deviceInfo = await _getDeviceInfo();
      } catch (_) {}

      final packageInfo = await PackageInfo.fromPlatform();
      String? ipAddress;
      Map<String, dynamic>? locationData;

      try {
        final ipInfo = await _getIpAndLocation();
        if (ipInfo != null) {
          ipAddress = ipInfo['ip_address'] as String?;
          locationData = {
            'city': ipInfo['location_city'],
            'country': ipInfo['location_country'],
            'latitude': ipInfo['latitude'],
            'longitude': ipInfo['longitude'],
          };
        }
      } catch (_) {}

      try {
        await _backendRequest(
          method: 'POST',
          path: '/v1/sessions/register',
          body: {
            'session_id': sessionId,
            'session_token': _sessionToken,
            'app_version': packageInfo.version,
            if (ipAddress != null) 'ip_address': ipAddress,
            if (locationData != null) 'location': locationData,
            if (deviceInfo != null) 'device_info': deviceInfo.toJson(),
            if (deviceInfo != null) 'platform': deviceInfo.toJson()['platform'],
          },
        );
      } catch (e) {
        logInfo('🚨 CRITICAL: Session registration rejected by backend: $e');
        _isRegistering = false;
        _verificationState = SessionVerificationState.invalid;
        // MUST NOT PROCEED LOCALLY
        return null;
      }

      _currentSessionId = sessionId;
      await _saveSession();
      _verificationState = SessionVerificationState.verified;
      _startActivityTracking();
      _startHealthCheck();
      _setupRealtimeListener();
      _isRegistering = false;
      return _currentSessionId;
    } catch (e) {
      logInfo('❌ Error in registerSession: $e');
      _verificationState = SessionVerificationState.pendingVerification;
      _isRegistering = false;
      return null;
    }
  }

  void _registerSessionInBackground() {
    Future.microtask(() async {
      await registerSession();
    });
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION VERIFICATION
  // ═══════════════════════════════════════════════════════════

  Future<bool> _quickSessionCheck() async {
    if (_currentSessionId == null || _sessionToken == null) {
      _verificationState = SessionVerificationState.invalid;
      return false;
    }
    final hasToken = await TokenStorage.hasValidSession();
    if (!hasToken) {
      final refreshed = await _refreshSessionWithRetry();
      if (refreshed == RefreshResult.authError) {
        _verificationState = SessionVerificationState.invalid;
        return false;
      }
      if (refreshed == RefreshResult.networkError) {
        _verificationState = SessionVerificationState.pendingVerification;
        return true; // We accept them offline!
      }
    }
    return await _checkSessionInDatabase();
  }

  Future<bool> _checkSessionInDatabase() async {
    if (_currentSessionId == null || _sessionToken == null) {
      _verificationState = SessionVerificationState.invalid;
      return false;
    }
    int retries = 0;
    while (retries < 3) {
      try {
        final result = await _backendRequest(
          method: 'POST',
          path: '/v1/sessions/validate',
          body: {
            'session_id': _currentSessionId,
            'session_token': _sessionToken,
          },
        );
        if (result is Map && result['valid'] == true) {
          _verificationState = SessionVerificationState.verified;
          return true;
        }
        _verificationState = SessionVerificationState.invalid;
        return false;
      } catch (e) {
        if (_isRecoverableValidationError(e)) {
          _verificationState = SessionVerificationState.pendingVerification;
          return true;
        }
        retries++;
        if (retries < 3) {
          await Future.delayed(Duration(milliseconds: 500 * retries));
        }
      }
    }
    _verificationState = SessionVerificationState.invalid;
    return false;
  }

  bool _isRecoverableValidationError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('http 429') ||
        text.contains('http 500') ||
        text.contains('http 502') ||
        text.contains('http 503') ||
        text.contains('http 504')) {
      return true;
    }
    return text.contains('network') ||
        text.contains('timeout') ||
        text.contains('connection') ||
        text.contains('socket') ||
        text.contains('failed host');
  }

  // ═══════════════════════════════════════════════════════════
  // ACTIVITY TRACKING
  // ═══════════════════════════════════════════════════════════

  void _startActivityTracking() {
    _activityTimer?.cancel();
    _activityTimer = Timer.periodic(_activityUpdateInterval, (_) {
      if (!_isInBackground) _updateActivity();
    });
  }

  Future<void> _updateActivity() async {
    if (_currentSessionId == null || _sessionToken == null) return;
    if (_isInBackground) return;
    if (_lastActivityUpdate != null &&
        DateTime.now().difference(_lastActivityUpdate!).inMinutes < 2) {
      return;
    }

    try {
      _lastActivityUpdate = DateTime.now();
      final ipInfo = await _getIpAndLocation();
      final ip = ipInfo?['ip_address'] as String?;
      final loc = ipInfo == null
          ? null
          : {
              'city': ipInfo['location_city'],
              'country': ipInfo['location_country'],
              'latitude': ipInfo['latitude'],
              'longitude': ipInfo['longitude'],
            };
      final result = await _backendRequest(
        method: 'POST',
        path: '/v1/sessions/touch',
        body: {
          'session_id': _currentSessionId,
          'session_token': _sessionToken,
          if (ip != null) 'ip_address': ip,
          if (loc != null) 'location': loc,
        },
      );
      if (result is Map && result['valid'] == true) {
        _verificationState = SessionVerificationState.verified;
      }
    } catch (e) {
      logInfo('⚠️ Activity update failed (non-critical): $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // HEALTH CHECK
  // ═══════════════════════════════════════════════════════════

  void _startHealthCheck() {
    if (kDebugMode) {
      logInfo('🔧 Debug mode: Health check disabled');
      return;
    }
    _stopHealthCheck();
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (_) async {
      if (!_isInBackground) await _performHealthCheck();
    });
  }

  void _stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> _performHealthCheck() async {
    final hasValid = await TokenStorage.hasValidSession();
    if (!hasValid && _currentSessionId != null) {
      logInfo('⚠️ Health Check: token invalid, refreshing...');
      await _performSessionRefresh();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION REFRESH WITH RETRY
  // ═══════════════════════════════════════════════════════════

  Future<RefreshResult> _refreshSessionWithRetry() async {
    final running = _refreshInFlight;
    if (running != null) return running;
    final future = _performSessionRefresh();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) _refreshInFlight = null;
    }
  }

  Future<RefreshResult> _performSessionRefresh() async {
    try {
      final refreshToken = await TokenStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        logInfo('🔴 No refresh token — cannot refresh');
        return RefreshResult.authError;
      }

      final repo = AuthRepository();
      final response = await repo.refreshToken(refreshToken);

      await TokenStorage.saveTokens(AuthSessionResponse(
        accessToken: response.session.accessToken,
        refreshToken: response.session.refreshToken,
        expiresAt: response.session.expiresAt,
        tokenType: response.session.tokenType,
      ));
      await TokenStorage.saveUserId(response.user.id);

      CurrentUserService.setCachedUserId(response.user.id);
      logInfo('✅ Token refreshed successfully');
      return RefreshResult.success;
    } on NetworkAuthException catch (e) {
      logInfo('⚠️ Token refresh network error: $e');
      return RefreshResult.networkError;
    } on UnauthorizedAuthException catch (e) {
      logInfo('🔴 Token refresh auth error: $e');
      return RefreshResult.authError;
    } catch (e) {
      logInfo('⚠️ Token refresh failed: $e');
      return RefreshResult.authError;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ═══════════════════════════════════════════════════════════

  void _setupRealtimeListener() {
    // Now uses periodic health check polling instead.
    logInfo('ℹ️ Realtime listener replaced by health check polling.');
  }

  void _teardownRealtimeListener() {
    // Empty
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION PERSISTENCE
  // ═══════════════════════════════════════════════════════════

  Future<void> _saveSession() async {
    if (_currentSessionId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionIdStorageKey, _currentSessionId!);
    if (_sessionToken != null) {
      await prefs.setString(_sessionTokenStorageKey, _sessionToken!);
    }
  }

  Future<void> _loadSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSessionId = prefs.getString(_sessionIdStorageKey);
    _sessionToken = prefs.getString(_sessionTokenStorageKey);
    if (_currentSessionId != null) {
      logInfo('📂 Loaded session from prefs: $_currentSessionId');
    }
  }

  Future<void> _clearSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionIdStorageKey);
    await prefs.remove(_sessionTokenStorageKey);
  }

  // ═══════════════════════════════════════════════════════════
  // SESSION TERMINATION
  // ═══════════════════════════════════════════════════════════

  Future<void> _handleSessionTermination() async {
    if (_isTerminating) return;
    _isTerminating = true;
    logInfo('🔴 Terminating session...');

    _stopHealthCheck();
    _activityTimer?.cancel();
    _teardownRealtimeListener();

    if (_currentSessionId != null) {
      try {
        await _backendRequest(
          method: 'POST',
          path: '/v1/sessions/terminate',
          body: {'target_session_id': _currentSessionId},
        );
      } catch (_) {}
    }

    await TokenStorage.clearAll();
    await _clearSavedSession();
    _currentSessionId = null;
    _sessionToken = null;
    _verificationState = SessionVerificationState.invalid;
    CurrentUserService.clearCache();

    onSessionTerminated?.call();
    _isTerminating = false;
  }

  /// خروج دستی توسط کاربر
  Future<void> userLogout() async {
    await _handleSessionTermination();
  }

  // ═══════════════════════════════════════════════════════════
  // FIND SESSION FROM TOKEN (init helper)
  // ═══════════════════════════════════════════════════════════

  Future<void> _findSessionFromToken() async {
    try {
      final userId = await _getAuthenticatedUserId();
      if (userId == null) return;
      final result = await _backendRequest(
        method: 'GET',
        path: '/v1/sessions/active',
      );
      if (result is Map) {
        final sessions = result['sessions'];
        final firstSession =
            sessions is List && sessions.isNotEmpty ? sessions.first : null;
        if (firstSession is Map) {
          _currentSessionId = firstSession['id']?.toString();
          _sessionToken = firstSession['session_token']?.toString();
        }
        if (_currentSessionId != null) {
          await _saveSession();
          _verificationState = SessionVerificationState.verified;
          logInfo('✅ Found active session from backend: $_currentSessionId');
        }
      }
    } catch (e) {
      logInfo('⚠️ Could not find session from token: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MULTI-DEVICE: TERMINATE OTHER SESSIONS
  // ═══════════════════════════════════════════════════════════

  Future<bool> terminateSession(String targetSessionId) async {
    try {
      final result = await _backendRequest(
        method: 'POST',
        path: '/v1/sessions/terminate',
        body: {
          'target_session_id': targetSessionId,
          'current_session_id': _currentSessionId,
        },
      );
      return result is Map && result['success'] == true;
    } catch (e) {
      logInfo('❌ Terminate session error: $e');
      rethrow;
    }
  }

  Future<bool> terminateAllOtherSessions() async {
    try {
      final userId = await _getAuthenticatedUserId();
      if (userId == null) return false;
      final result = await _backendRequest(
        method: 'POST',
        path: '/v1/sessions/terminate-others',
        body: {
          'current_session_id': _currentSessionId,
        },
      );
      return result is Map &&
          (result['success'] == true || result['count'] != null);
    } catch (e) {
      logInfo('❌ Terminate all sessions error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getActiveSessions() async {
    try {
      final userId = await _getAuthenticatedUserId();
      if (userId == null) return [];
      final result = await _backendRequest(
        method: 'GET',
        path: '/v1/sessions/active',
      );
      if (result is Map && result['sessions'] is List) {
        return (result['sessions'] as List)
            .whereType<Map>()
            .map((session) => Map<String, dynamic>.from(session))
            .toList();
      }
      return [];
    } catch (e) {
      logInfo('❌ Get active sessions error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  // LEGACY COMPATIBILITY WRAPPERS
  // ═══════════════════════════════════════════════════════════

  Future<void> ensureSessionRegistered({bool force = false}) async {
    if (force ||
        !isSessionActive ||
        _verificationState != SessionVerificationState.verified) {
      final sessionId = await registerSession(force: force);
      if (sessionId == null) {
        throw Exception(
            'Session registration failed or was rejected by backend.');
      }
    }
  }

  Future<bool> verifyCurrentSession({bool forceServer = false}) async {
    return await _quickSessionCheck();
  }

  Future<void> updateLocationAndIP() async {
    _updateActivity();
  }

  Future<bool> updateFcmToken(String fcmToken) async {
    final token = fcmToken.trim();
    if (token.isEmpty) return false;

    if (_currentSessionId == null || _sessionToken == null) {
      await ensureSessionRegistered();
    }
    if (_currentSessionId == null || _sessionToken == null) return false;

    try {
      final ipInfo = await _getIpAndLocation();
      final ip = ipInfo?['ip_address'] as String?;
      final loc = ipInfo == null
          ? null
          : {
              'city': ipInfo['location_city'],
              'country': ipInfo['location_country'],
              'latitude': ipInfo['latitude'],
              'longitude': ipInfo['longitude'],
            };
      final result = await _backendRequest(
        method: 'POST',
        path: '/v1/sessions/touch',
        body: {
          'session_id': _currentSessionId,
          'session_token': _sessionToken,
          'fcm_token': token,
          if (ip != null) 'ip_address': ip,
          if (loc != null) 'location': loc,
        },
      );
      if (result is Map && result['valid'] == true) {
        _verificationState = SessionVerificationState.verified;
        return true;
      }
    } catch (e) {
      logInfo('FCM token sync failed: $e');
    }
    return false;
  }

  Future<void> onNetworkRestored() async {
    await _performHealthCheck();
  }

  Future<String?> findCurrentSessionId() async {
    return currentSessionId;
  }

  Future<bool> isSessionStillValid() async {
    return verificationState == SessionVerificationState.verified;
  }

  Stream<List<SessionModel>> watchActiveSessions() async* {
    while (true) {
      try {
        final sessions = await getActiveSessions();
        yield sessions.map((s) => SessionModel.fromJson(s)).toList();
      } catch (e) {
        // Yield empty or current if error occurs, but prevent crash
        yield [];
      }
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DEVICE INFO HELPERS
  // ═══════════════════════════════════════════════════════════

  Future<SessionDeviceInfo?> _getDeviceInfo() async {
    final di = DeviceInfoPlugin();
    final deviceId = DeviceIdService.id;
    if (Platform.isAndroid) {
      final info = await di.androidInfo;
      return SessionDeviceInfo(
        deviceName: '${info.brand} ${info.model}',
        deviceModel: info.model,
        osVersion: info.version.release,
        targetPlatform: TargetPlatform.android,
        deviceId: deviceId,
      );
    } else if (Platform.isIOS) {
      final info = await di.iosInfo;
      return SessionDeviceInfo(
        deviceName: info.name,
        deviceModel: info.model,
        osVersion: info.systemVersion,
        targetPlatform: TargetPlatform.iOS,
        deviceId: deviceId,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> _getIpAndLocation() async {
    try {
      final response = await http
          .get(Uri.parse('https://ipwho.is/'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return {
            'ip_address': data['ip']?.toString(),
            'location_city': data['city']?.toString(),
            'location_country': data['country']?.toString(),
            'location_region': data['region']?.toString(),
            'latitude': data['latitude'],
            'longitude': data['longitude'],
          };
        }
      }
    } catch (_) {}
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  // PUBLIC REFRESH & BACKGROUND INIT (used by session_auth_wrapper)
  // ═══════════════════════════════════════════════════════════

  /// عمومی‌سازی refresh برای استفاده در session_auth_wrapper
  Future<RefreshResult> performSessionRefreshPublic() async {
    return await _performSessionRefresh();
  }

  /// راه‌اندازی session manager در پس‌زمینه بدون block کردن UI
  void initInBackground() {
    Future.microtask(() async {
      try {
        await initialize();
        await ensureSessionRegistered();
        _syncWithServerInBackground();
      } catch (e) {
        logInfo('⚠️ Background session init failed: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════

  void dispose() {
    _activityTimer?.cancel();
    _stopHealthCheck();
    _teardownRealtimeListener();
  }
}
