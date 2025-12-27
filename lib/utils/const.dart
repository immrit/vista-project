import '../../security/logging_utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/session_manager_service.dart';

final supabase = Supabase.instance.client;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const String defaultAvatarUrl = 'lib/utils/images/default-avatar.jpg';

const String supabaseCdnUrl = 'https://api.coffevista.ir:8443';
const String supabaseDirectUrl = 'http://cdn.exiritshop.ir:8000';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

/// HTTP Client با timeout و retry mechanism برای Supabase
class SupabaseHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final Duration _timeout = const Duration(seconds: 30);
  final int _maxRetries = 3;
  static const String _sessionIdHeader = 'x-session-id';
  static const String _sessionTokenHeader = 'x-session-token';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < _maxRetries) {
      try {
        // ایجاد request جدید برای هر تلاش (برای جلوگیری از خطای finalize)
        final newRequest = _createNewRequest(request);
        _attachSessionHeaders(newRequest);

        // تنظیم timeout برای request
        final response =
            await _inner.send(newRequest).timeout(_timeout, onTimeout: () {
          throw TimeoutException('Request timeout after $_timeout');
        });

        // اگر response موفق بود، آن را برگردان
        if (response.statusCode < 500) {
          return response;
        }

        // برای خطاهای سرور، retry کن
        attempt++;

        if (attempt >= _maxRetries) {
          return response;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        attempt++;

        if (attempt >= _maxRetries) {
          rethrow;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw Exception('Unexpected error in HTTP client');
  }

  /// ایجاد request جدید بر اساس request اصلی
  http.BaseRequest _createNewRequest(http.BaseRequest originalRequest) {
    if (originalRequest is http.Request) {
      final newRequest =
          http.Request(originalRequest.method, originalRequest.url);
      newRequest.headers.addAll(originalRequest.headers);
      newRequest.body = originalRequest.body;
      return newRequest;
    } else if (originalRequest is http.MultipartRequest) {
      final newRequest = http.MultipartRequest(
        originalRequest.method,
        originalRequest.url,
      );
      newRequest.headers.addAll(originalRequest.headers);
      newRequest.fields.addAll(originalRequest.fields);
      newRequest.files.addAll(originalRequest.files);
      return newRequest;
    } else if (originalRequest is http.StreamedRequest) {
      final newRequest = http.StreamedRequest(
        originalRequest.method,
        originalRequest.url,
      );
      newRequest.headers.addAll(originalRequest.headers);
      // برای StreamedRequest، stream را نمی‌توان کپی کرد
      // در این صورت باید از request اصلی استفاده کرد
      return originalRequest;
    }

    // برای سایر انواع request، request اصلی را برگردان
    return originalRequest;
  }

  void _attachSessionHeaders(http.BaseRequest request) {
    try {
      final sessionManager = SessionManagerService();
      final sessionId = sessionManager.currentSessionId;
      final sessionToken = sessionManager.currentSessionToken;

      if (sessionId != null && sessionId.isNotEmpty) {
        request.headers[_sessionIdHeader] = sessionId;
      }

      if (sessionToken != null && sessionToken.isNotEmpty) {
        request.headers[_sessionTokenHeader] = sessionToken;
      }
    } catch (e) {
      logInfo('⚠️ Failed to attach session headers: $e');
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Extension برای PostgrestFilterBuilder با timeout و retry mechanism
extension PostgrestFilterBuilderExtensions on PostgrestFilterBuilder {
  /// اجرای query با timeout و retry mechanism
  Future<PostgrestResponse> executeWithRetry({
    Duration timeout = const Duration(seconds: 30),
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxRetries) {
      try {
        logInfo('🔄 Postgrest query attempt ${attempt + 1}/$maxRetries');

        // اجرای query با timeout
        final responseFuture = this;
        final response = await responseFuture.timeout(timeout);

        // اگر response موفق بود، آن را برگردان
        if (response.error == null) {
          return response;
        }

        // برای خطاهای سرور، retry کن
        attempt++;

        if (attempt >= maxRetries) {
          return response;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        attempt++;

        if (attempt >= maxRetries) {
          rethrow;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw Exception('Unexpected error in Postgrest query');
  }
}

Future<bool> checkSupabaseConnectivity() async {
  try {
    await Supabase.instance.client.from('profiles').select().limit(1).timeout(
          const Duration(seconds: 5), // کاهش تایم‌اوت برای چک سریع‌تر
          onTimeout: () => throw TimeoutException('Connection timeout'),
        );
    return true;
  } catch (e) {
    logInfo('❌ Supabase connectivity check failed: $e');
    return false;
  }
}

/// ✅ نسخه بهینه‌شده و سریع برای رفع مشکل صفحه سیاه
Future<void> initializeSupabaseWithFailover() async {
  // تلاش اول: استفاده از CDN URL
  try {
    logInfo('🔄 Initializing Supabase with CDN URL: $supabaseCdnUrl');

    // نکته مهم: Supabase.initialize معمولاً فقط کانفیگ است و بلاک نمی‌کند مگر اینکه Auth Flow خاصی باشد
    await Supabase.initialize(
      url: supabaseCdnUrl,
      anonKey: supabaseAnonKey,
      httpClient: SupabaseHttpClient(),
      debug: true,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        detectSessionInUri: true,
      ),
    ).timeout(const Duration(seconds: 3)); // تایم‌اوت سخت برای خود عملیات init

    logInfo('✅ Supabase initialized successfully (Phase 1)');

    // 🚀 بلافاصله خارج شو و بقیه کارها را به پس‌زمینه بسپار
    _startBackgroundInitialization();
    return;
  } catch (e) {
    logInfo('⚠️ CDN URL init failed or timed out: $e');

    // اگر CDN شکست خورد، dispose کن تا دوباره تلاش کنیم
    try {
      Supabase.instance;
      await Supabase.instance.dispose();
    } catch (_) {}

    // تلاش دوم: Direct URL
    try {
      logInfo(
          '🔄 Attempting Supabase initialization with Direct URL: $supabaseDirectUrl');

      await Supabase.initialize(
        url: supabaseDirectUrl,
        anonKey: supabaseAnonKey,
        httpClient: SupabaseHttpClient(),
        debug: true,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          autoRefreshToken: true,
          detectSessionInUri: true,
        ),
      ).timeout(const Duration(seconds: 3));

      logInfo('✅ Supabase initialized successfully with Direct URL');
      _startBackgroundInitialization();
    } catch (err) {
      logInfo('❌ Critical: Supabase init completely failed: $err');

      // حتی اگر شکست خورد، برای اینکه برنامه کرش نکند در حالت مینیمال بالا بیاریم
      // تا کاربر وارد برنامه شود و از دیتای آفلاین استفاده کند
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        try {
          await Supabase.initialize(
            url: 'https://placeholder.url',
            anonKey: supabaseAnonKey,
          );
        } catch (_) {}
      }
    }
  }
}

/// ✅ عملیات سنگین (پینگ، بازیابی نشست) در پس‌زمینه انجام می‌شود
void _startBackgroundInitialization() {
  Future.microtask(() async {
    try {
      logInfo('⏳ Starting background session restoration...');
      await _waitForSessionRestore(maxAttempts: 5, delayMs: 500);

      // لاگ وضعیت نشست
      _logSessionStatus();

      // پینگ شبکه در پس‌زمینه
      checkSupabaseConnectivity();
    } catch (e) {
      logInfo('⚠️ Background init tasks error: $e');
    }
  });
}

Future<void> _waitForSessionRestore(
    {int maxAttempts = 15, int delayMs = 200}) async {
  // منطق قبلی برای بازیابی نشست
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        logInfo(
            '✅ Session restored in background! User: ${session.user.email}');

        // رفرش توکن اگر نیاز بود
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        if ((session.expiresAt ?? 0) < now) {
          try {
            await Supabase.instance.client.auth.refreshSession();
          } catch (_) {}
        }
        return;
      }
    } catch (_) {}
    await Future.delayed(Duration(milliseconds: delayMs));
  }
}

// ✅ تابع جدید: لاگ کردن وضعیت session
void _logSessionStatus() {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = session.expiresAt ?? 0;
      final timeUntilExpiry = expiresAt - now;

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📊 SESSION STATUS');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('✅ Session Active');
      print('👤 User: ${session.user.email}');
      print('🆔 User ID: ${session.user.id}');
      print('📅 Created: ${session.user.createdAt}');
      print(
          '⏰ Expires in: ${Duration(seconds: timeUntilExpiry).inMinutes} minutes');
      final token = session.accessToken;
      print(
          '🔑 Access Token: ${token.length > 20 ? token.substring(0, 20) : token}...');
      print(
          '🔄 Refresh Token: ${session.refreshToken?.substring(0, 20) ?? 'N/A'}...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } else {
      print('⚠️ No session currently available (may restore later)');
    }
  } catch (e) {
    print('⚠️ Error checking session status: $e');
  }
}
