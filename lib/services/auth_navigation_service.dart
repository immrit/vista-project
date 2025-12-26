import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/const.dart';
import '../security/logging_utility.dart';
import 'session_manager_service_v2.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// وضعیت‌های نشست - الهام گرفته از Telegram MTProto Authorization States
/// ═══════════════════════════════════════════════════════════════════════════
enum SessionState {
  /// نشست کاملاً معتبر و فعال
  authenticated,

  /// نشست در حال بررسی (منتظر تأیید)
  verifying,

  /// نشست منقضی شده ولی قابل تمدید
  expiredRefreshable,

  /// نشست منقضی شده و غیرقابل تمدید
  expiredTerminal,

  /// نشست توسط کاربر/سرور باطل شده
  revoked,

  /// هیچ نشستی وجود ندارد
  unauthenticated,

  /// خطا در بررسی (مشکل شبکه)
  networkError,
}

/// نتیجه بررسی نشست با جزئیات کامل
class SessionVerificationResult {
  final SessionState state;
  final String? message;
  final String? userId;
  final DateTime? expiresAt;
  final bool canRetry;
  final int retryCount;

  const SessionVerificationResult({
    required this.state,
    this.message,
    this.userId,
    this.expiresAt,
    this.canRetry = false,
    this.retryCount = 0,
  });

  bool get isValid => state == SessionState.authenticated;
  bool get needsRefresh => state == SessionState.expiredRefreshable;
  bool get needsReauth =>
      state == SessionState.expiredTerminal ||
      state == SessionState.revoked ||
      state == SessionState.unauthenticated;

  @override
  String toString() =>
      'SessionVerificationResult(state: $state, userId: $userId)';
}

/// ═══════════════════════════════════════════════════════════════════════════
/// سرویس مدیریت احراز هویت - سطح Enterprise
///
/// الهام گرفته از:
/// - Telegram MTProto Session Layer
/// - WhatsApp Signal Protocol Auth
/// - Instagram Session Persistence
///
/// ویژگی‌ها:
/// - Multi-layer session verification
/// - Graceful degradation
/// - Smart retry with exponential backoff
/// - Session state machine
/// - Anti-flood protection
/// - Offline-first approach
/// ═══════════════════════════════════════════════════════════════════════════
class AuthNavigationService {
  static final AuthNavigationService _instance =
      AuthNavigationService._internal();
  factory AuthNavigationService() => _instance;
  AuthNavigationService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // STATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// وضعیت فعلی نشست (cached)
  static SessionState _currentState = SessionState.verifying;

  /// آخرین بررسی موفق
  static DateTime? _lastSuccessfulVerification;

  /// جلوگیری از redirect های متوالی
  static bool _isRedirecting = false;
  static DateTime? _lastRedirectAttempt;

  /// شمارنده تلاش‌های ناموفق
  static int _consecutiveFailures = 0;

  /// Cache بررسی نشست
  static SessionVerificationResult? _cachedResult;
  static DateTime? _cacheTime;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION (Telegram-inspired)
  // ═══════════════════════════════════════════════════════════════════════════

  /// حداکثر تلاش برای refresh
  static const int _maxRefreshAttempts = 3;

  /// تأخیر اولیه بین retry ها (exponential backoff)
  static const Duration _baseRetryDelay = Duration(milliseconds: 500);

  /// حداکثر تأخیر بین retry ها
  static const Duration _maxRetryDelay = Duration(seconds: 5);

  /// مدت اعتبار cache نتیجه بررسی
  static const Duration _cacheValidity = Duration(seconds: 30);

  /// cooldown بین redirect ها
  static const Duration _redirectCooldown = Duration(seconds: 5);

  /// حداکثر خطاهای متوالی قبل از redirect
  static const int _maxConsecutiveFailures = 5;

  /// زمان انتظار برای restore نشست
  static const Duration _sessionRestoreWait = Duration(milliseconds: 500);

  /// threshold برای refresh نشست (دقیقه قبل از انقضا)
  static const int _refreshThresholdMinutes = 10;

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی سریع - آیا کاربر لاگین است (cached)
  static bool get isUserLoggedIn {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (e) {
      return false;
    }
  }

  /// شناسه کاربر فعلی
  static String? get currentUserId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (e) {
      return null;
    }
  }

  /// وضعیت فعلی نشست
  static SessionState get currentState => _currentState;

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 1: QUICK CHECK (Offline-First)
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی سریع نشست بدون درخواست شبکه
  ///
  /// این متد از داده‌های محلی استفاده می‌کند و فوراً نتیجه می‌دهد.
  /// مناسب برای UI checks و blocking operations.
  static SessionVerificationResult quickCheck() {
    logInfo('🔍 [AuthNav] Quick check starting...');

    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      final user = supabase.auth.currentUser;

      // بررسی وجود session
      if (session == null || user == null) {
        logInfo('⚠️ [AuthNav] Quick check: No session/user found');
        return const SessionVerificationResult(
          state: SessionState.unauthenticated,
          message: 'نشست فعالی یافت نشد',
        );
      }

      // بررسی expiry
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryTime =
            DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
        final now = DateTime.now();
        final timeUntilExpiry = expiryTime.difference(now);

        if (timeUntilExpiry.isNegative) {
          logInfo('⏰ [AuthNav] Quick check: Session expired');
          return SessionVerificationResult(
            state: SessionState.expiredRefreshable,
            message: 'نشست منقضی شده',
            userId: user.id,
            expiresAt: expiryTime,
            canRetry: true,
          );
        }

        if (timeUntilExpiry.inMinutes < _refreshThresholdMinutes) {
          logInfo(
              '⏳ [AuthNav] Quick check: Session expiring soon (${timeUntilExpiry.inMinutes}m)');
          return SessionVerificationResult(
            state: SessionState.expiredRefreshable,
            message: 'نشست در حال انقضا',
            userId: user.id,
            expiresAt: expiryTime,
            canRetry: true,
          );
        }
      }

      logInfo('✅ [AuthNav] Quick check: Session valid');
      _currentState = SessionState.authenticated;
      return SessionVerificationResult(
        state: SessionState.authenticated,
        userId: user.id,
        expiresAt: expiresAt != null
            ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
            : null,
      );
    } catch (e) {
      logInfo('❌ [AuthNav] Quick check error: $e');
      return const SessionVerificationResult(
        state: SessionState.networkError,
        message: 'خطا در بررسی نشست',
        canRetry: true,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 2: DEEP VERIFICATION (Network-Aware)
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی عمیق نشست با تلاش برای recovery
  ///
  /// این متد:
  /// 1. ابتدا از cache استفاده می‌کند (اگر معتبر باشد)
  /// 2. Quick check انجام می‌دهد
  /// 3. در صورت نیاز، refresh می‌کند
  /// 4. با SessionManagerServiceV2 هماهنگ می‌شود
  /// 5. از exponential backoff برای retry استفاده می‌کند
  static Future<SessionVerificationResult> verifySession({
    bool forceRefresh = false,
    bool useCache = true,
  }) async {
    logInfo(
        '🔐 [AuthNav] Deep verification starting (forceRefresh: $forceRefresh)...');

    // استفاده از cache اگر معتبر است
    if (useCache && !forceRefresh && _isCacheValid()) {
      logInfo('📦 [AuthNav] Using cached result');
      return _cachedResult!;
    }

    _currentState = SessionState.verifying;

    try {
      // مرحله 1: Quick check
      final quickResult = quickCheck();

      if (quickResult.state == SessionState.unauthenticated) {
        // صبر برای احتمال restore شدن session
        logInfo('⏳ [AuthNav] Waiting for potential session restore...');
        await Future.delayed(_sessionRestoreWait);

        // بررسی مجدد
        final retryResult = quickCheck();
        if (retryResult.state == SessionState.unauthenticated) {
          _updateCache(retryResult);
          return retryResult;
        }
      }

      // مرحله 2: اگر نیاز به refresh دارد
      if (quickResult.needsRefresh || forceRefresh) {
        logInfo('🔄 [AuthNav] Attempting session refresh...');
        final refreshResult = await _refreshWithRetry();

        if (refreshResult.isValid) {
          _consecutiveFailures = 0;
          _lastSuccessfulVerification = DateTime.now();
          _updateCache(refreshResult);
          return refreshResult;
        }

        // refresh ناموفق بود
        _consecutiveFailures++;

        if (_consecutiveFailures >= _maxConsecutiveFailures) {
          logInfo('❌ [AuthNav] Too many consecutive failures');
          final terminalResult = SessionVerificationResult(
            state: SessionState.expiredTerminal,
            message: 'امکان تمدید نشست وجود ندارد',
            retryCount: _consecutiveFailures,
          );
          _updateCache(terminalResult);
          return terminalResult;
        }

        _updateCache(refreshResult);
        return refreshResult;
      }

      // مرحله 3: بررسی هماهنگی با SessionManager
      final sessionManagerCheck = await _verifyWithSessionManager();
      if (!sessionManagerCheck) {
        logInfo('⚠️ [AuthNav] SessionManager reports invalid session');
        // اما اگر Supabase auth معتبره، به اون اعتماد کن
        if (quickResult.isValid) {
          logInfo('ℹ️ [AuthNav] Trusting Supabase auth despite SessionManager');
        }
      }

      _consecutiveFailures = 0;
      _lastSuccessfulVerification = DateTime.now();
      _currentState = SessionState.authenticated;
      _updateCache(quickResult);
      return quickResult;
    } catch (e) {
      logInfo('❌ [AuthNav] Verification error: $e');

      // در صورت خطای شبکه، به session محلی اعتماد کن
      if (_isNetworkError(e)) {
        logInfo('🌐 [AuthNav] Network error, trusting local session');
        final localResult = quickCheck();
        if (localResult.isValid) {
          return SessionVerificationResult(
            state: SessionState.authenticated,
            message: 'نشست محلی معتبر (آفلاین)',
            userId: localResult.userId,
          );
        }
      }

      return SessionVerificationResult(
        state: SessionState.networkError,
        message: 'خطا در بررسی نشست: $e',
        canRetry: true,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYER 3: FULL AUTHENTICATION GUARD
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی کامل و هدایت به auth در صورت نیاز
  ///
  /// این متد برای محافظت از صفحات و عملیات‌های حساس استفاده می‌شود.
  /// فقط زمانی redirect می‌کند که واقعاً نشست معتبر نباشد.
  static Future<bool> ensureAuthenticated({
    bool showMessage = true,
    String? message,
    bool forceVerify = false,
  }) async {
    logInfo('🛡️ [AuthNav] ensureAuthenticated called');

    // جلوگیری از redirect متوالی
    if (_shouldSkipRedirect()) {
      logInfo('⏳ [AuthNav] Skipping due to cooldown/redirect in progress');
      return isUserLoggedIn; // فرض بر معتبر بودن
    }

    final result = await verifySession(forceRefresh: forceVerify);

    switch (result.state) {
      case SessionState.authenticated:
        logInfo('✅ [AuthNav] User is authenticated');
        return true;

      case SessionState.verifying:
        // هنوز در حال بررسی - اجازه ادامه بده
        logInfo('⏳ [AuthNav] Still verifying, allowing continuation');
        return true;

      case SessionState.expiredRefreshable:
        // یکبار دیگه تلاش کن
        logInfo('🔄 [AuthNav] Attempting final refresh...');
        final retryResult = await verifySession(forceRefresh: true);
        if (retryResult.isValid) return true;
        return _performNavigation(
          showMessage: showMessage,
          message: message ?? 'نشست منقضی شده، لطفاً مجدداً وارد شوید',
        );

      case SessionState.networkError:
        // در خطای شبکه، به session محلی اعتماد کن
        logInfo('🌐 [AuthNav] Network error, checking local session');
        if (isUserLoggedIn) {
          return true;
        }
        return _performNavigation(
          showMessage: showMessage,
          message: message ?? 'خطا در اتصال به سرور',
        );

      case SessionState.expiredTerminal:
      case SessionState.revoked:
      case SessionState.unauthenticated:
        logInfo('🚫 [AuthNav] Session invalid, redirecting to auth');
        return _performNavigation(
          showMessage: showMessage,
          message: message ?? _getMessageForState(result.state),
        );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی خطا و هدایت هوشمند به auth
  ///
  /// این متد خطا را تحلیل می‌کند و فقط در صورتی redirect می‌کند
  /// که واقعاً مشکل auth باشد.
  static Future<bool> handleAuthErrorAsync(dynamic error) async {
    logInfo('🔍 [AuthNav] Analyzing error: $error');

    if (!_isAuthRelatedError(error)) {
      logInfo('ℹ️ [AuthNav] Not an auth error, ignoring');
      return false;
    }

    logInfo('⚠️ [AuthNav] Auth-related error detected');

    // بررسی عمیق نشست
    final result = await verifySession(forceRefresh: true);

    if (result.isValid) {
      logInfo('✅ [AuthNav] Session still valid despite error');
      return false;
    }

    if (result.needsRefresh) {
      logInfo('🔄 [AuthNav] Attempting recovery...');
      final retryResult = await verifySession(forceRefresh: true);
      if (retryResult.isValid) {
        logInfo('✅ [AuthNav] Recovery successful');
        return false;
      }
    }

    logInfo('❌ [AuthNav] Session invalid, redirecting');
    return _performNavigation(
      showMessage: true,
      message: 'لطفاً مجدداً وارد شوید',
    );
  }

  /// بررسی سریع خطا (sync version برای error handlers)
  static bool handleAuthError(dynamic error) {
    if (!_isAuthRelatedError(error)) {
      return false;
    }

    // بررسی سریع
    final quickResult = quickCheck();
    if (quickResult.isValid) {
      logInfo('⚠️ [AuthNav] Auth error but session valid, ignoring');
      return false;
    }

    return _performNavigation(
      showMessage: true,
      message: 'لطفاً مجدداً وارد شوید',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SIMPLE REDIRECTS (Backward Compatibility)
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی سریع و هدایت
  static bool redirectToAuthIfNeeded({
    bool showMessage = true,
    String? message,
  }) {
    if (isUserLoggedIn) return false;
    return _performNavigation(
      showMessage: showMessage,
      message: message ?? 'لطفاً وارد حساب کاربری خود شوید',
    );
  }

  /// هدایت اجباری
  static bool redirectToAuth({
    bool showMessage = true,
    String? message,
  }) {
    return _performNavigation(
      showMessage: showMessage,
      message: message ?? 'نشست شما منقضی شده است',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Refresh با retry و exponential backoff
  static Future<SessionVerificationResult> _refreshWithRetry() async {
    for (int attempt = 1; attempt <= _maxRefreshAttempts; attempt++) {
      logInfo('🔄 [AuthNav] Refresh attempt $attempt/$_maxRefreshAttempts');

      try {
        final response = await Supabase.instance.client.auth.refreshSession();

        if (response.session != null && response.user != null) {
          logInfo('✅ [AuthNav] Session refreshed successfully');
          _currentState = SessionState.authenticated;

          return SessionVerificationResult(
            state: SessionState.authenticated,
            userId: response.user!.id,
            expiresAt: response.session!.expiresAt != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    response.session!.expiresAt! * 1000)
                : null,
          );
        }
      } on AuthException catch (e) {
        logInfo('⚠️ [AuthNav] Auth exception on refresh: ${e.message}');

        // برخی خطاها غیرقابل retry هستند
        if (e.message.contains('refresh_token_not_found') ||
            e.message.contains('Invalid Refresh Token')) {
          logInfo('❌ [AuthNav] Terminal auth error, stopping retry');
          _currentState = SessionState.expiredTerminal;
          return SessionVerificationResult(
            state: SessionState.expiredTerminal,
            message: 'نشست باطل شده است',
            retryCount: attempt,
          );
        }
      } catch (e) {
        logInfo('⚠️ [AuthNav] Refresh error: $e');
      }

      // Exponential backoff
      if (attempt < _maxRefreshAttempts) {
        final delay = _calculateBackoff(attempt);
        logInfo(
            '⏳ [AuthNav] Waiting ${delay.inMilliseconds}ms before retry...');
        await Future.delayed(delay);
      }
    }

    logInfo('❌ [AuthNav] All refresh attempts failed');
    _currentState = SessionState.expiredRefreshable;
    return SessionVerificationResult(
      state: SessionState.expiredRefreshable,
      message: 'تلاش برای تمدید نشست ناموفق بود',
      canRetry: true,
      retryCount: _maxRefreshAttempts,
    );
  }

  /// بررسی با SessionManagerServiceV2
  static Future<bool> _verifyWithSessionManager() async {
    try {
      final sessionManager = SessionManagerServiceV2();
      return sessionManager.isSessionActive;
    } catch (e) {
      logInfo('⚠️ [AuthNav] SessionManager check failed: $e');
      return true; // در صورت خطا، فرض بر معتبر بودن
    }
  }

  /// محاسبه تأخیر با exponential backoff
  static Duration _calculateBackoff(int attempt) {
    final backoff = _baseRetryDelay * (1 << (attempt - 1)); // 500ms, 1s, 2s
    return backoff > _maxRetryDelay ? _maxRetryDelay : backoff;
  }

  /// بررسی اعتبار cache
  static bool _isCacheValid() {
    if (_cachedResult == null || _cacheTime == null) return false;
    final age = DateTime.now().difference(_cacheTime!);
    return age < _cacheValidity && _cachedResult!.isValid;
  }

  /// به‌روزرسانی cache
  static void _updateCache(SessionVerificationResult result) {
    _cachedResult = result;
    _cacheTime = DateTime.now();
    _currentState = result.state;
  }

  /// بررسی آیا باید redirect را skip کرد
  static bool _shouldSkipRedirect() {
    if (_isRedirecting) return true;

    if (_lastRedirectAttempt != null) {
      final timeSinceLastRedirect =
          DateTime.now().difference(_lastRedirectAttempt!);
      if (timeSinceLastRedirect < _redirectCooldown) return true;
    }

    return false;
  }

  /// بررسی آیا خطا مربوط به auth است
  static bool _isAuthRelatedError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    return errorStr.contains('کاربر وارد نشده') ||
        errorStr.contains('پروفایل کاربر یافت نشد') ||
        errorStr.contains('user not logged in') ||
        errorStr.contains('no user logged in') ||
        errorStr.contains('session expired') ||
        errorStr.contains('jwt expired') ||
        errorStr.contains('invalid jwt') ||
        errorStr.contains('refresh_token_not_found') ||
        errorStr.contains('invalid refresh token') ||
        errorStr.contains('auth session missing') ||
        errorStr.contains('not authenticated') ||
        errorStr.contains('unauthorized');
  }

  /// بررسی آیا خطا مربوط به شبکه است
  static bool _isNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    return errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('connection timed out') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no internet');
  }

  /// پیام مناسب برای هر وضعیت
  static String _getMessageForState(SessionState state) {
    switch (state) {
      case SessionState.authenticated:
        return 'شما وارد شده‌اید';
      case SessionState.verifying:
        return 'در حال بررسی نشست...';
      case SessionState.expiredRefreshable:
        return 'نشست در حال انقضاست';
      case SessionState.expiredTerminal:
        return 'نشست شما منقضی شده است';
      case SessionState.revoked:
        return 'نشست شما باطل شده است';
      case SessionState.unauthenticated:
        return 'لطفاً وارد حساب کاربری خود شوید';
      case SessionState.networkError:
        return 'خطا در اتصال به سرور';
    }
  }

  /// انجام navigation به صفحه auth
  static bool _performNavigation({
    required bool showMessage,
    required String message,
  }) {
    if (_shouldSkipRedirect()) {
      logInfo('⏳ [AuthNav] Navigation skipped (cooldown/redirect active)');
      return false;
    }

    try {
      final context = navigatorKey.currentContext;

      if (context == null || !context.mounted) {
        logInfo('⚠️ [AuthNav] Context not available');
        return false;
      }

      _isRedirecting = true;
      _lastRedirectAttempt = DateTime.now();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = navigatorKey.currentContext;
        if (navContext == null || !navContext.mounted) {
          _isRedirecting = false;
          return;
        }

        try {
          logInfo('🚀 [AuthNav] Navigating to auth screen...');

          Navigator.of(navContext).pushNamedAndRemoveUntil(
            '/auth',
            (route) => false,
          );

          if (showMessage) {
            Future.delayed(const Duration(milliseconds: 300), () {
              final snackContext = navigatorKey.currentContext;
              if (snackContext != null && snackContext.mounted) {
                ScaffoldMessenger.of(snackContext).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.login_rounded, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            message,
                            style: const TextStyle(fontFamily: 'Vazirmatn'),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.blue[700],
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            });
          }
        } catch (e) {
          logInfo('⚠️ [AuthNav] Navigation error: $e');
        } finally {
          Future.delayed(const Duration(seconds: 2), () {
            _isRedirecting = false;
          });
        }
      });

      logInfo('✅ [AuthNav] Navigation request registered');
      return true;
    } catch (e) {
      logInfo('❌ [AuthNav] Error: $e');
      _isRedirecting = false;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  /// اجرای action با اطمینان از auth
  static Future<T?> requireAuth<T>({
    required Future<T> Function() action,
    String? errorMessage,
  }) async {
    final isAuthenticated = await ensureAuthenticated(message: errorMessage);
    if (!isAuthenticated) return null;
    return await action();
  }

  /// Reset کردن state
  static void reset() {
    _isRedirecting = false;
    _lastRedirectAttempt = null;
    _consecutiveFailures = 0;
    _cachedResult = null;
    _cacheTime = null;
    _currentState = SessionState.verifying;
    _lastSuccessfulVerification = null;
    logInfo('🔄 [AuthNav] State reset');
  }

  /// دریافت اطلاعات debug
  static Map<String, dynamic> getDebugInfo() {
    return {
      'currentState': _currentState.name,
      'isUserLoggedIn': isUserLoggedIn,
      'currentUserId': currentUserId,
      'isRedirecting': _isRedirecting,
      'consecutiveFailures': _consecutiveFailures,
      'lastSuccessfulVerification':
          _lastSuccessfulVerification?.toIso8601String(),
      'cacheValid': _isCacheValid(),
    };
  }
}
