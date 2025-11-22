import '../../security/logging_utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../../services/session_manager_service.dart';

const String defaultAvatarUrl = 'lib/view/util/images/default-avatar.jpg';

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

/// بررسی اتصال به Supabase
Future<bool> checkSupabaseConnectivity() async {
  try {
    await Supabase.instance.client.from('profiles').select().limit(1).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Connection timeout'),
        );
    return true;
  } catch (e) {
    logInfo('❌ Supabase connectivity check failed: $e');
    return false;
  }
}

Future<void> initializeSupabaseWithFailover() async {
  // تلاش اول: استفاده از CDN URL با HTTP client جدید
  try {
    logInfo('🔄 Initializing Supabase with CDN URL: $supabaseCdnUrl');

    // ایجاد Supabase client با HTTP client جدید
    final httpClient = SupabaseHttpClient();
    await Supabase.initialize(
      url: supabaseCdnUrl,
      anonKey: supabaseAnonKey,
      httpClient: httpClient,
      debug: true, // برای دیباگ
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, // امن‌تر
        autoRefreshToken: true, // ✅ خیلی مهم: Auto refresh token
        detectSessionInUri: true,
      ),
    );

    print('✅ Supabase initialized successfully');
    
    // ✅ بررسی session بعد از initialize
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      print('🔐 Active session found: ${session.user.email}');
      print('📅 Session expires at: ${session.expiresAt}');
      
      // بررسی expire شدن
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final expiresAt = session.expiresAt ?? 0;
      
      if (expiresAt < now) {
        print('⚠️ Session expired, refreshing...');
        
        // تلاش برای refresh با retry logic
        bool refreshSuccess = false;
        int retryCount = 0;
        const maxRetries = 3;
        
        while (retryCount < maxRetries && !refreshSuccess) {
          try {
            await Supabase.instance.client.auth.refreshSession();
            print('✅ Session refreshed successfully');
            refreshSuccess = true;
          } catch (e) {
            retryCount++;
            if (retryCount < maxRetries) {
              print('⚠️ Session refresh failed, retrying... ($retryCount/$maxRetries): $e');
              await Future.delayed(Duration(seconds: retryCount));
            } else {
              print('❌ Session refresh failed after $maxRetries attempts: $e');
              
              // بررسی نوع خطا
              final errorString = e.toString().toLowerCase();
              final isNetworkError = errorString.contains('network') ||
                  errorString.contains('timeout') ||
                  errorString.contains('connection') ||
                  errorString.contains('socket') ||
                  errorString.contains('failed host lookup');
              
              // فقط اگر خطای واقعی auth است (نه network error) و session واقعاً منقضی شده، signOut کن
              if (!isNetworkError) {
                final finalSession = Supabase.instance.client.auth.currentSession;
                if (finalSession == null || (finalSession.expiresAt ?? 0) < now) {
                  await Supabase.instance.client.auth.signOut();
                } else {
                  print('⚠️ Refresh failed but session still exists, keeping it active');
                }
              } else {
                print('⚠️ Network error during refresh, keeping session active');
              }
            }
          }
        }
      }
    } else {
      print('ℹ️ No active session found');
    }

    // ✅ اضافه شده: منتظر بمانید تا session restore شود
    print('⏳ Waiting for session restoration...');
    await _waitForSessionRestore();

    await Supabase.instance.client.from('profiles').select().limit(1).timeout(
          const Duration(seconds: 10), // افزایش timeout برای شبکه‌های کند
          onTimeout: () => throw TimeoutException('Ping timeout'),
        );

    // ✅ اضافه شده: پس از initialize موفق، session بازیابی شده را لاگ کنید
    _logSessionStatus();

    return; // اتصال موفق، خروج از تابع
  } catch (e) {
    logInfo('⚠️ CDN URL failed: $e');

    // CDN attempt failed, will try direct URL

    // بررسی اینکه آیا Supabase در تلاش اول مقداردهی اولیه شده بود یا خیر.
    // اگر مقداردهی اولیه شده بود (حتی اگر پینگ ناموفق بود)، باید dispose شود.
    bool needsDisposal = false;
    try {
      // دسترسی به Supabase.instance در صورتی که _initialized false باشد، خطا می‌دهد.
      // از این طریق می‌توانیم بفهمیم که آیا _initialized true شده است یا خیر.
      Supabase.instance; // اگر این خط اجرا شود یعنی _initialized true بوده.
      needsDisposal = true;
    } catch (assertionError) {
      // اگر خطای assertion رخ دهد، یعنی Supabase.instance قابل دسترسی نیست
      // و _initialized false است. پس نیازی به dispose نیست.
      needsDisposal = false;
    }

    if (needsDisposal) {
      try {
        await Supabase.instance.dispose(); // ریست کردن وضعیت Supabase
      } catch (disposeError) {
        logInfo('⚠️ Error disposing Supabase instance: $disposeError');
      }
    }

    // تلاش دوم: استفاده از Direct URL با HTTP client جدید
    try {
      print(
          '🔄 Attempting Supabase initialization with Direct URL: $supabaseDirectUrl');

      // ایجاد Supabase client جدید با HTTP client جدید
      final httpClient2 = SupabaseHttpClient();
      await Supabase.initialize(
        url: supabaseDirectUrl,
        anonKey: supabaseAnonKey,
        httpClient: httpClient2,
        debug: true, // برای دیباگ
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce, // امن‌تر
          autoRefreshToken: true, // ✅ خیلی مهم: Auto refresh token
          detectSessionInUri: true,
        ),
      );

      print('✅ Supabase initialized successfully');
      
      // ✅ بررسی session بعد از initialize
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('🔐 Active session found: ${session.user.email}');
        print('📅 Session expires at: ${session.expiresAt}');
        
        // بررسی expire شدن
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiresAt = session.expiresAt ?? 0;
        
        if (expiresAt < now) {
          print('⚠️ Session expired, refreshing...');
          
          // تلاش برای refresh با retry logic
          bool refreshSuccess = false;
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries && !refreshSuccess) {
            try {
              await Supabase.instance.client.auth.refreshSession();
              print('✅ Session refreshed successfully');
              refreshSuccess = true;
            } catch (e) {
              retryCount++;
              if (retryCount < maxRetries) {
                print('⚠️ Session refresh failed, retrying... ($retryCount/$maxRetries): $e');
                await Future.delayed(Duration(seconds: retryCount));
              } else {
                print('❌ Session refresh failed after $maxRetries attempts: $e');
                
                // بررسی نوع خطا
                final errorString = e.toString().toLowerCase();
                final isNetworkError = errorString.contains('network') ||
                    errorString.contains('timeout') ||
                    errorString.contains('connection') ||
                    errorString.contains('socket') ||
                    errorString.contains('failed host lookup');
                
                // فقط اگر خطای واقعی auth است (نه network error) و session واقعاً منقضی شده، signOut کن
                if (!isNetworkError) {
                  final finalSession = Supabase.instance.client.auth.currentSession;
                  if (finalSession == null || (finalSession.expiresAt ?? 0) < now) {
                    await Supabase.instance.client.auth.signOut();
                  } else {
                    print('⚠️ Refresh failed but session still exists, keeping it active');
                  }
                } else {
                  print('⚠️ Network error during refresh, keeping session active');
                }
              }
            }
          }
        }
      } else {
        print('ℹ️ No active session found');
      }

      // ✅ اضافه شده: منتظر بمانید تا session restore شود
      print('⏳ Waiting for session restoration (Direct URL)...');
      await _waitForSessionRestore();

      // تلاش برای ping با retry و graceful handling
      try {
        await Supabase.instance.client.from('profiles').select().limit(1).timeout(
              const Duration(seconds: 10), // افزایش timeout برای شبکه‌های کند
              onTimeout: () => throw TimeoutException('Ping timeout'),
            );
      } catch (e) {
        // اگر ping ناموفق بود، session را حفظ می‌کنیم (ممکن است مشکل network باشد)
        final errorString = e.toString().toLowerCase();
        final isNetworkError = errorString.contains('network') ||
            errorString.contains('timeout') ||
            errorString.contains('connection') ||
            errorString.contains('socket');
        
        if (isNetworkError) {
          logInfo('⚠️ Network error during ping, but keeping session active: $e');
          // با قطع اینترنت، session را حفظ می‌کنیم
        } else {
          logInfo('⚠️ Ping failed but session may still be valid: $e');
        }
        // حتی با خطا، ادامه می‌دهیم تا session حفظ شود
      }

      // ✅ اضافه شده: پس از initialize موفق، session بازیابی شده را لاگ کنید
      _logSessionStatus();

      logInfo('✅ Supabase initialized successfully with Direct URL');
    } catch (err) {
      print(
          '❌ اتصال به سرور قطع است - لطفاً اتصال اینترنت خود را بررسی کنید: $err');

      // در حالت debug، Supabase را با تنظیمات minimal initialize کنیم
      if (const bool.fromEnvironment('dart.vm.product') == false) {
        print(
            '🔄 تلاش برای initialize Supabase با تنظیمات minimal در حالت توسعه...');

        try {
          // Supabase را با تنظیمات minimal initialize کنیم
          await Supabase.initialize(
            url:
                'https://localhost:54321', // این URL کار نخواهد کرد اما instance ایجاد می‌شود
            anonKey: supabaseAnonKey,
            authOptions: FlutterAuthClientOptions(
              authFlowType: AuthFlowType.pkce,
              autoRefreshToken: true, // ✅ Auto refresh token
              detectSessionInUri: true,
            ),
          );
          logInfo('✅ Supabase با تنظیمات minimal initialize شد (حالت توسعه)');
          logInfo(
              '⚠️ اتصال به دیتابیس ممکن است کار نکند اما برنامه اجرا می‌شود');
          return; // خروج موفق
        } catch (minimalErr) {
          logInfo('❌ حتی minimal Supabase هم شکست خورد: $minimalErr');
          // در این حالت نیز اجازه بده برنامه اجرا شود
          logInfo('🔧 برنامه بدون Supabase اجرا می‌شود');
          return;
        }
      } else {
        rethrow; // در حالت production، اجازه نده برنامه اجرا شود
      }
    }
  }
}

// ✅ تابع جدید: منتظر بمانید تا session restore شود
Future<void> _waitForSessionRestore(
    {int maxAttempts = 15, int delayMs = 200}) async {
  print('🔄 Checking for session restoration...');

  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('✅ Session restored successfully! User: ${session.user.email}');
        
        // بررسی expire شدن و refresh در صورت نیاز
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final expiresAt = session.expiresAt ?? 0;
        
        if (expiresAt < now) {
          print('⚠️ Restored session expired, refreshing...');
          
          // تلاش برای refresh با retry logic
          bool refreshSuccess = false;
          int retryCount = 0;
          const maxRetries = 3;
          
          while (retryCount < maxRetries && !refreshSuccess) {
            try {
              await Supabase.instance.client.auth.refreshSession();
              print('✅ Session refreshed successfully');
              refreshSuccess = true;
            } catch (e) {
              retryCount++;
              if (retryCount < maxRetries) {
                print('⚠️ Session refresh failed, retrying... ($retryCount/$maxRetries): $e');
                await Future.delayed(Duration(seconds: retryCount));
              } else {
                print('❌ Session refresh failed after $maxRetries attempts: $e');
                // در اینجا signOut نمی‌کنیم چون ممکن است مشکل موقتی باشد
              }
            }
          }
        }
        
        return;
      }
    } catch (e) {
      // ignore errors during polling
    }

    if (attempt < maxAttempts - 1) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }

  print('⏳ Session restore check completed (may restore asynchronously)');
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
      print('⏰ Expires in: ${Duration(seconds: timeUntilExpiry).inMinutes} minutes');
      print('🔑 Access Token: ${session.accessToken.substring(0, 20)}...');
      print('🔄 Refresh Token: ${session.refreshToken?.substring(0, 20) ?? 'N/A'}...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } else {
      print('⚠️ No session currently available (may restore later)');
    }
  } catch (e) {
    print('⚠️ Error checking session status: $e');
  }
}
