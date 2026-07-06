import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:Vista/utils/env_config.dart';
import '../../../security/logging_utility.dart';
import '../../../services/device_id_service.dart';
import '../../../services/system_status_service.dart';
import '../domain/auth_exceptions.dart';

// ══════════════════════════════════════════════════════════════
// مدل‌های پاسخ بک‌اند Go
// ══════════════════════════════════════════════════════════════

class AuthUserResponse {
  final String id;
  final String? username;
  final String fullName;
  final String? email;
  final String? phoneNumber;
  final String accountStatus;
  final bool profileCompleted;
  final bool hasPassword;
  final bool passwordRequired;
  final DateTime? phoneVerifiedAt;
  final DateTime? emailVerifiedAt;
  final DateTime createdAt;

  const AuthUserResponse({
    required this.id,
    this.username,
    required this.fullName,
    this.email,
    this.phoneNumber,
    required this.accountStatus,
    required this.profileCompleted,
    this.hasPassword = false,
    this.passwordRequired = false,
    this.phoneVerifiedAt,
    this.emailVerifiedAt,
    required this.createdAt,
  });

  factory AuthUserResponse.fromJson(Map<String, dynamic> json) {
    return AuthUserResponse(
      id: json['id'] as String? ?? '',
      username: json['username'] as String?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      accountStatus: json['account_status'] as String? ?? 'active',
      profileCompleted: json['profile_completed'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? false,
      passwordRequired: json['password_required'] as bool? ?? false,
      phoneVerifiedAt: json['phone_verified_at'] != null
          ? DateTime.tryParse(json['phone_verified_at'] as String)
          : null,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.tryParse(json['email_verified_at'] as String)
          : null,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AuthSessionResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;

  const AuthSessionResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
  });

  factory AuthSessionResponse.fromJson(Map<String, dynamic> json) {
    return AuthSessionResponse(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'Bearer',
      expiresAt: _parseExpiresAt(json),
    );
  }

  static DateTime _parseExpiresAt(Map<String, dynamic> json) {
    final expiresAt =
        _parseBackendDate(json['expires_at'] ?? json['expiresAt']);
    if (expiresAt != null) return expiresAt;

    final expiresIn = json['expires_in'] ?? json['expiresIn'];
    if (expiresIn is num) {
      return DateTime.now().toUtc().add(Duration(seconds: expiresIn.toInt()));
    }
    if (expiresIn is String) {
      final seconds = int.tryParse(expiresIn);
      if (seconds != null) {
        return DateTime.now().toUtc().add(Duration(seconds: seconds));
      }
    }

    return DateTime.now().toUtc().add(const Duration(minutes: 15));
  }

  static DateTime? _parseBackendDate(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    final hasTimeZone = RegExp(
      r'(z|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(text);
    final normalized = hasTimeZone ? text : '${text}Z';
    return DateTime.tryParse(normalized)?.toUtc() ??
        DateTime.tryParse(text)?.toUtc();
  }
}

class AuthResponse {
  final AuthUserResponse user;
  final AuthSessionResponse session;
  final bool isNewUser;

  const AuthResponse({
    required this.user,
    required this.session,
    required this.isNewUser,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUserResponse.fromJson(
          json['user'] as Map<String, dynamic>? ?? {}),
      session: AuthSessionResponse.fromJson(
          json['session'] as Map<String, dynamic>? ?? {}),
      isNewUser: json['is_new_user'] as bool? ?? false,
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RefreshCoordinator — process-wide single-flight guard around
// /auth/refresh. The app has more than one trigger that can decide a token
// needs refreshing (the session health-check timer and the 401 response
// interceptor). If both fire close together they would otherwise each send
// the same refresh token to the server; the server can only honor one of
// them and was historically treating the loser as a replayed/stolen token,
// which logged the user out everywhere. Routing every refresh attempt
// through this coordinator means the second caller just awaits the first
// call's result instead of firing its own competing request.
// ══════════════════════════════════════════════════════════════
class RefreshCoordinator {
  /// Shared process-wide instance — what app code should use.
  static final RefreshCoordinator instance = RefreshCoordinator();

  Future<AuthResponse>? _inFlight;
  AuthResponse? _lastSuccess;
  DateTime? _lastSuccessAt;

  /// A refresh that completed this recently is reused instead of hitting the
  /// server again. Sequential (non-concurrent) 401 bursts otherwise each fire
  /// their own refresh with whatever refresh token they read *before* the
  /// previous rotation was persisted — the server sees a replayed token and
  /// kills the whole session family. Well under the access-token lifetime,
  /// so a reused response is always still valid.
  static const Duration _reuseWindow = Duration(seconds: 15);

  Future<AuthResponse> refresh(
    String refreshToken,
    AuthRepository repo, {
    Future<void> Function(AuthResponse response)? persist,
  }) {
    final last = _lastSuccess;
    final lastAt = _lastSuccessAt;
    if (last != null &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _reuseWindow) {
      // Already persisted by the call that produced it.
      return Future.value(last);
    }
    return coalesce(() async {
      final response = await repo.refreshToken(refreshToken);
      // Persist BEFORE resolving: once callers see this future complete they
      // assume the stored refresh token is the rotated one. Persisting after
      // resolution leaves a window where a new caller reads the old token
      // and replays it.
      //
      // A persist failure (e.g. a transient secure-storage hiccup) must NOT
      // make this refresh look like it failed: the server already rotated
      // the token — rejecting `response` here would strand the caller on its
      // now-dead pre-rotation token with no valid one to retry with, for a
      // purely local write error. The in-memory response is still good for
      // this caller's immediate retry; the next refresh call will simply try
      // persisting again.
      if (persist != null) {
        try {
          await persist(response);
        } catch (e) {
          // Swallow — see rationale above.
        }
      }
      _lastSuccess = response;
      _lastSuccessAt = DateTime.now();
      return response;
    });
  }

  /// Forget the cached result — must be called on logout/token wipe so a
  /// stale response can never leak into a later login.
  void reset() {
    _lastSuccess = null;
    _lastSuccessAt = null;
  }

  /// Single-flight: if a call is already running, every other caller gets
  /// the SAME future instead of starting a new one. Exposed separately
  /// (rather than inlined into [refresh]) so the coalescing behavior is
  /// unit-testable without a real network call.
  @visibleForTesting
  Future<AuthResponse> coalesce(Future<AuthResponse> Function() call) {
    final running = _inFlight;
    if (running != null) return running;

    final future = call();
    _inFlight = future;
    void clearIfCurrent() {
      if (identical(_inFlight, future)) _inFlight = null;
    }

    // .then(onValue, onError:) — not .whenComplete() — because the derived
    // future it returns is discarded (only used for the cleanup side
    // effect). whenComplete()'s derived future re-throws the original error,
    // which would surface as a separate "unhandled" error alongside the one
    // `future` itself already reports to its real listeners; handling the
    // error here (without rethrowing) keeps the derived future clean.
    future.then((_) => clearIfCurrent(), onError: (_) => clearIfCurrent());
    return future;
  }
}

class VerifyOtpResponse {
  final bool is2faRequired;
  final String? twoFactorToken;
  final AuthResponse? auth;

  const VerifyOtpResponse({
    required this.is2faRequired,
    this.twoFactorToken,
    this.auth,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      is2faRequired: json['is_2fa_required'] as bool? ?? false,
      twoFactorToken: json['two_factor_token'] as String?,
      auth: json['auth'] != null ? AuthResponse.fromJson(json['auth']) : null,
    );
  }
}

class LookupIdentifierResponse {
  final bool success;
  final bool exists;
  final bool isPhone;
  final String? normalizedIdentifier;
  final String? authFlow;
  final String? accountStatus;

  const LookupIdentifierResponse({
    required this.success,
    required this.exists,
    required this.isPhone,
    this.normalizedIdentifier,
    this.authFlow,
    this.accountStatus,
  });

  factory LookupIdentifierResponse.fromJson(Map<String, dynamic> json) {
    return LookupIdentifierResponse(
      success: json['success'] as bool? ?? false,
      exists: json['exists'] as bool? ?? false,
      isPhone: json['is_phone'] as bool? ?? false,
      normalizedIdentifier: json['normalized_identifier'] as String?,
      authFlow: json['auth_flow'] as String?,
      accountStatus: json['account_status'] as String?,
    );
  }
}

class SendOtpResponse {
  final bool success;
  final String message;
  final int expiresInSeconds;
  final int? retryAfterSeconds;
  final String? debugCode;

  const SendOtpResponse({
    required this.success,
    required this.message,
    required this.expiresInSeconds,
    this.retryAfterSeconds,
    this.debugCode,
  });

  factory SendOtpResponse.fromJson(Map<String, dynamic> json) {
    return SendOtpResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 300,
      retryAfterSeconds: json['retry_after_seconds'] as int?,
      debugCode: json['debug_code'] as String?,
    );
  }
}

class SendEmailVerificationResponse {
  final bool success;
  final String message;
  final String sessionId;
  final int expiresInSeconds;
  final String? debugCode;

  const SendEmailVerificationResponse({
    required this.success,
    required this.message,
    required this.sessionId,
    required this.expiresInSeconds,
    this.debugCode,
  });

  factory SendEmailVerificationResponse.fromJson(Map<String, dynamic> json) {
    return SendEmailVerificationResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      expiresInSeconds: json['expires_in_seconds'] as int? ?? 0,
      debugCode: json['debug_code'] as String?,
    );
  }
}

class RecoveryOption {
  final String id;
  final String method; // 'email' | 'sms'
  final String masked;

  const RecoveryOption({
    required this.id,
    required this.method,
    required this.masked,
  });

  factory RecoveryOption.fromJson(Map<String, dynamic> json) {
    return RecoveryOption(
      id: (json['id'] as String?) ?? '',
      method: (json['method'] as String?)?.toLowerCase() ?? '',
      masked: (json['masked'] as String?) ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AuthRepository — متصل به بک‌اند Go
// ══════════════════════════════════════════════════════════════

class AuthRepository {
  /// آدرس بک‌اند Go — از .env خوانده می‌شود
  static String get _backendUrl => EnvConfig.apiBaseUrl;

  late final Dio _dio;

  AuthRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1/auth',
      connectTimeout: const Duration(seconds: 20),
      // Long enough that a slow (not dead) network still receives a /refresh
      // response the server already produced. A premature client timeout here
      // used to strand the client on its now-rotated token → later forced logout.
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'X-Device-ID': DeviceIdService.id,
      },
    ));
    // SECURITY: the previous LogInterceptor(requestHeader: true) had no
    // kDebugMode guard and its logPrint defaulted to print(), so the
    // Authorization: Bearer <token> header of every auth call leaked into
    // logcat in RELEASE builds. Removed — the redacted, debug-only logger
    // below is the only network logging that should ever run.

    // لاگ شبکه فقط در debug و بدون داده حساس
    if (kDebugMode) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final payload = _redactSensitiveData(options.data);
          logInfo('[API][REQ] ${options.method} ${options.uri} data=$payload');
          handler.next(options);
        },
        onResponse: (response, handler) {
          final payload = _redactSensitiveData(response.data);
          logInfo(
              '[API][RES] ${response.statusCode} ${response.requestOptions.path} data=$payload');
          handler.next(response);
        },
        onError: (error, handler) {
          final payload = _redactSensitiveData(error.response?.data);
          logError(
            '[API][ERR] ${error.requestOptions.path} status=${error.response?.statusCode} data=$payload',
            error: error,
          );
          handler.next(error);
        },
      ));
    }
  }

  // ─── ثبت‌نام با ایمیل/شماره/رمز عبور ───
  Future<AuthResponse> register({
    String? username,
    required String fullName,
    String? email,
    String? phoneNumber,
    required String password,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/register', data: {
        if (username != null && username.isNotEmpty) 'username': username,
        'full_name': fullName,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phone_number': phoneNumber,
        'password': password,
      });

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'ثبت‌نام');
    } catch (e) {
      logError('Register Error', error: e);
      rethrow;
    }
  }

  // ─── ورود با ایمیل / شماره موبایل / نام کاربری ───
  Future<AuthResponse> login({
    required String identifier,
    required String password,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );

      final response = await _dio.post('/login', data: {
        'identifier': identifier,
        'password': password,
      });

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'ورود');
    } catch (e) {
      logError('Login Error', error: e);
      rethrow;
    }
  }

  // ─── تمدید توکن با Refresh Token ───
  //
  // Contract: this method throws ONLY UnauthorizedAuthException (the server
  // gave an explicit, unambiguous "this refresh token is dead" answer — the
  // one case that should ever force a logout) or NetworkAuthException
  // (everything else — timeouts, 5xx, unexpected status codes, malformed
  // response bodies, parse errors). Callers rely on this being exhaustive:
  // fail-open (keep the session alive, retry later) is the default; fail-
  // closed (wipe tokens) only happens for a confirmed-dead token. Before this
  // was tightened, any error type this function didn't explicitly recognize
  // (a 400/404/502 from a proxy during deploy, a non-JSON error page, a JSON
  // decode failure) fell through as a bare String/generic exception, which
  // callers misclassified as "token invalid" and force-logged-out the user
  // for what was actually a transient blip.
  Future<AuthResponse> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post('/refresh', data: {
        'refresh_token': refreshToken,
      });

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      // The ONLY terminal case: the server explicitly rejected this refresh
      // token (missing/invalid/expired/user gone/account banned — see
      // internal/auth/service.go RefreshToken). Everything else below is
      // treated as transient on purpose.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw UnauthorizedAuthException('نشست نامعتبر است.');
      }
      throw NetworkAuthException(
          'تمدید نشست موقتاً ناموفق بود: ${_handleDioError(e, 'تمدید نشست')}');
    } catch (e) {
      // Anything that isn't even a DioException (JSON decode failure from a
      // malformed/non-JSON body, a null/type error, etc.) is by definition
      // not a "the server told us the token is dead" signal — never let it
      // fall through to a force-logout classification upstream.
      logError('Refresh Token Error', error: e);
      throw NetworkAuthException('تمدید نشست به دلیل خطای غیرمنتظره ناموفق بود.');
    }
  }

  Future<AuthUserResponse> me(String accessToken) async {
    try {
      final response = await _dio.get('/me',
          options: Options(headers: {
            'Authorization': 'Bearer $accessToken',
          }));

      return AuthUserResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw 'unauthorized';
      }
      throw _handleDioError(e, 'بررسی نشست');
    } catch (e) {
      logError('Me Error', error: e);
      rethrow;
    }
  }

  Future<LookupIdentifierResponse> lookupIdentifier(String identifier) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/lookup', data: {
        'identifier': identifier,
      });

      return LookupIdentifierResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'بررسی شناسه ورود');
    } catch (e) {
      logError('Lookup Identifier Error', error: e);
      rethrow;
    }
  }

  // ─── ارسال کد تایید OTP ───
  Future<SendOtpResponse> sendOtp(String phoneNumber) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/send-otp', data: {
        'phone_number': phoneNumber,
      });

      return SendOtpResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'ارسال کد تایید');
    } catch (e) {
      logError('Send OTP Error', error: e);
      rethrow;
    }
  }

  // ─── بررسی کد تایید OTP ───
  Future<VerifyOtpResponse> verifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/verify-otp', data: {
        'phone_number': phoneNumber,
        'code': code,
      });

      return VerifyOtpResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'تایید کد');
    } catch (e) {
      logError('Verify OTP Error', error: e);
      rethrow;
    }
  }

  // ─── تایید دو مرحله‌ای ───
  Future<AuthResponse> verify2fa({
    required String token,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/2fa/verify', data: {
        'two_factor_token': token,
        'password': password,
      });

      return AuthResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'تایید دو مرحله‌ای');
    } catch (e) {
      logError('Verify 2FA Error', error: e);
      rethrow;
    }
  }

  // ─── ایجاد رمز عبور (2FA Setup) ───
  Future<void> set2FaPassword({
    required String password,
    required String accessToken,
  }) async {
    try {
      final response = await _dio.post(
        '/2fa/setup',
        data: {'password': password},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      if (response.statusCode != 200) {
        throw 'خطا در تعیین رمز عبور';
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'تعیین رمز عبور');
    } catch (e) {
      logError('Set 2FA Password Error', error: e);
      rethrow;
    }
  }

  /// Changes the signed-in user's password. The backend verifies the current
  /// password, applies its own password policy, and revokes all other
  /// sessions on success.
  Future<void> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post(
        '/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'تغییر رمز عبور');
    } catch (e) {
      logError('Change Password Error', error: e);
      rethrow;
    }
  }

  Future<SendEmailVerificationResponse> sendEmailVerification({
    required String accessToken,
    required String email,
  }) async {
    try {
      final response = await _dio.post(
        '/send-email-verification',
        data: {'email': email},
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return SendEmailVerificationResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleDioError(e, 'ارسال کد تأیید ایمیل');
    } catch (e) {
      logError('Send Email Verification Error', error: e);
      rethrow;
    }
  }

  Future<AuthUserResponse> verifyEmail({
    required String accessToken,
    required String sessionId,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/verify-email',
        data: {
          'session_id': sessionId,
          'code': code,
        },
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      return AuthUserResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleDioError(e, 'تأیید ایمیل');
    } catch (e) {
      logError('Verify Email Error', error: e);
      rethrow;
    }
  }

  // ─── بازنشانی رمز عبور با SMS ───
  Future<void> resetPasswordSms({
    required String phoneNumber,
    required String code,
    required String newPassword,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/reset-password-sms', data: {
        'phone_number': phoneNumber,
        'code': code,
        'new_password': newPassword,
      });

      final ok = response.data is Map && response.data['success'] == true;
      if (ok) return;

      throw response.data is Map
          ? (response.data['message'] as String? ?? 'خطای نامشخص')
          : 'خطای نامشخص';
    } on DioException catch (e) {
      throw _handleDioError(e, 'بازنشانی رمز عبور');
    } catch (e) {
      logError('Reset Password SMS Error', error: e);
      rethrow;
    }
  }

  // ─── دریافت گزینه‌های بازیابی ───
  Future<List<RecoveryOption>> getRecoveryOptions(String identifier) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/recovery-options', data: {
        'identifier': identifier,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در سرویس بازیابی';
      }

      final options = data is Map ? data['options'] : null;
      if (options is List) {
        return options
            .whereType<Map>()
            .map((e) => RecoveryOption.fromJson(e.cast<String, dynamic>()))
            .where((o) => o.id.isNotEmpty && o.method.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    } on DioException catch (e) {
      throw _handleDioError(e, 'دریافت گزینه‌های بازیابی');
    } catch (e) {
      logError('Get Recovery Options Error', error: e);
      rethrow;
    }
  }

  // ─── ارسال کد بازیابی ───
  Future<void> sendRecoveryCode(String optionId) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/recovery-send', data: {
        'option_id': optionId,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در ارسال کد';
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'ارسال کد بازیابی');
    } catch (e) {
      logError('Send Recovery Code Error', error: e);
      rethrow;
    }
  }

  // ─── بررسی کد بازیابی ───
  Future<String> verifyRecoveryCode({
    required String optionId,
    required String code,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/recovery-verify', data: {
        'option_id': optionId,
        'code': code,
      });

      final data = response.data;
      if (data is Map &&
          data['success'] == true &&
          data['password_reset_token'] != null) {
        return data['password_reset_token'] as String;
      }
      throw 'خطا در بررسی کد';
    } on DioException catch (e) {
      throw _handleDioError(e, 'بررسی کد بازیابی');
    } catch (e) {
      logError('Verify Recovery Code Error', error: e);
      rethrow;
    }
  }

  // ─── تکمیل بازیابی ───
  Future<void> completeRecovery({
    required String token,
    required String newPassword,
  }) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.login,
        forceRefresh: true,
      );
      final response = await _dio.post('/recovery-complete', data: {
        'password_reset_token': token,
        'new_password': newPassword,
      });

      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw 'خطا در تغییر رمز عبور';
      }
    } on DioException catch (e) {
      throw _handleDioError(e, 'تکمیل بازیابی');
    } catch (e) {
      logError('Complete Recovery Error', error: e);
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Error Handling — تبدیل خطاهای HTTP به پیام فارسی
  // ══════════════════════════════════════════════════════════════

  String _handleDioError(DioException e, String context) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    // خطاهای بک‌اند Go — سه شکل envelope دارد:
    //   ۱) auth.Error سرویس:   {"code":"...", "message":"پیام فارسی"}
    //   ۲) خطای handler:        {"error":{"code":"error","message":"invalid JSON payload"}}
    //   ۳) گیت فیچر (flat):     {"error":"feature_disabled", ...}
    // پیام‌های فارسی مستقیم نمایش داده می‌شوند؛ کدهای انگلیسی/فنی به پیام
    // فارسیِ مبتنی بر status در ادامه fallback می‌شوند.
    final serverMessage = _extractServerMessage(data);
    if (serverMessage != null &&
        RegExp(r'[؀-ۿ]').hasMatch(serverMessage)) {
      return serverMessage;
    }

    // خطاهای HTTP استاندارد
    switch (status) {
      case 400:
        return 'اطلاعات ارسالی نامعتبر است';
      case 401:
        return 'نام کاربری یا رمز عبور اشتباه است';
      case 403:
        return 'حساب کاربری غیرفعال است';
      case 409:
        return 'کاربر با این مشخصات قبلاً ثبت شده است';
      case 429:
        return 'تلاش‌های زیادی انجام شده است. لطفاً چند دقیقه دیگر دوباره تلاش کنید';
      case 500:
        return 'خطای سرور. لطفاً دوباره تلاش کنید';
      case 503:
        return 'سرور موقتاً در دسترس نیست. لطفاً کمی بعد دوباره تلاش کنید';
      default:
        break;
    }

    // خطاهای شبکه
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'اتصال به سرور برقرار نشد. لطفاً اینترنت خود را بررسی کنید';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'خطا در اتصال به سرور. لطفاً اینترنت خود را بررسی کنید';
    }

    logError(
      '$context API Error [status=${e.response?.statusCode}, type=${e.type}, data=${e.response?.data}]',
      error: e,
    );
    return 'خطا در $context. لطفاً دوباره تلاش کنید';
  }

  /// Safely pulls a human-readable message out of any backend error body
  /// without ever casting a Map to String (the old code TypeError'd on the
  /// nested handler envelope).
  String? _extractServerMessage(dynamic data) {
    if (data is! Map) return null;
    final topMessage = data['message'];
    if (topMessage is String && topMessage.isNotEmpty) return topMessage;
    final err = data['error'];
    if (err is Map) {
      final nestedMessage = err['message'];
      if (nestedMessage is String && nestedMessage.isNotEmpty) {
        return nestedMessage;
      }
      final nestedCode = err['code'];
      if (nestedCode is String && nestedCode.isNotEmpty) return nestedCode;
      return null;
    }
    if (err is String && err.isNotEmpty) return err;
    return null;
  }

  dynamic _redactSensitiveData(dynamic data) {
    if (data is Map) {
      final redacted = <String, dynamic>{};
      for (final entry in data.entries) {
        if (_isSensitiveKey(entry.key.toString())) {
          redacted[entry.key.toString()] = '***REDACTED***';
        } else {
          redacted[entry.key.toString()] = _redactSensitiveData(entry.value);
        }
      }
      return redacted;
    }
    if (data is List) {
      return data.map(_redactSensitiveData).toList(growable: false);
    }
    return data;
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('password') ||
        normalized.contains('token') ||
        normalized.contains('otp') ||
        normalized.contains('secret') ||
        normalized.contains('code');
  }
}
