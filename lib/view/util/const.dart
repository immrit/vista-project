import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

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

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < _maxRetries) {
      try {
        print(
            '🔄 HTTP Request attempt ${attempt + 1}/$_maxRetries: ${request.method} ${request.url}');

        // ایجاد request جدید برای هر تلاش (برای جلوگیری از خطای finalize)
        final newRequest = _createNewRequest(request);

        // تنظیم timeout برای request
        final response =
            await _inner.send(newRequest).timeout(_timeout, onTimeout: () {
          throw TimeoutException('Request timeout after $_timeout');
        });

        // اگر response موفق بود، آن را برگردان
        if (response.statusCode < 500) {
          print('✅ HTTP Request successful: ${response.statusCode}');
          return response;
        }

        // برای خطاهای سرور، retry کن
        print('⚠️ Server error ${response.statusCode}, retrying...');
        attempt++;

        if (attempt >= _maxRetries) {
          print('💀 Max retries reached for HTTP request');
          return response;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        attempt++;
        print('❌ HTTP Request error (attempt $attempt): $e');

        if (attempt >= _maxRetries) {
          print('💀 Max retries reached, rethrowing error');
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
        print('🔄 Postgrest query attempt ${attempt + 1}/$maxRetries');

        // اجرای query با timeout
        final responseFuture = this;
        final response = await responseFuture.timeout(timeout);

        // اگر response موفق بود، آن را برگردان
        if (response.error == null) {
          print('✅ Postgrest query successful');
          return response;
        }

        // برای خطاهای سرور، retry کن
        print('⚠️ Postgrest error: ${response.error?.message}, retrying...');
        attempt++;

        if (attempt >= maxRetries) {
          print('💀 Max retries reached for Postgrest query');
          return response;
        }

        // exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        attempt++;
        print('❌ Postgrest query error (attempt $attempt): $e');

        if (attempt >= maxRetries) {
          print('💀 Max retries reached, rethrowing error');
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

Future<void> initializeSupabaseWithFailover() async {
  // تلاش اول: استفاده از CDN URL با HTTP client جدید
  try {
    print('Attempting Supabase initialization with CDN URL: $supabaseCdnUrl');

    // ایجاد Supabase client با HTTP client جدید
    final httpClient = SupabaseHttpClient();
    await Supabase.initialize(
      url: supabaseCdnUrl,
      anonKey: supabaseAnonKey,
      httpClient: httpClient,
    );

    print('Supabase initialized with CDN URL. Pinging...');
    await Supabase.instance.client.from('profiles').select().limit(1).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Ping timeout'),
        );
    print('Successfully connected to Supabase via CDN (cloudflare).');
    return; // اتصال موفق، خروج از تابع
  } catch (e) {
    print('Supabase CDN attempt failed: $e');

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
      print(
          'Supabase was not fully initialized by the first attempt, no disposal needed.');
      needsDisposal = false;
    }

    if (needsDisposal) {
      print('Disposing previous Supabase instance before trying fallback...');
      try {
        await Supabase.instance.dispose(); // ریست کردن وضعیت Supabase
        print('Previous Supabase instance disposed.');
      } catch (disposeError) {
        print(
            'Error disposing Supabase instance: $disposeError. Proceeding with fallback anyway.');
        // اگر dispose هم خطا بدهد، احتمالاً مقداردهی اولیه بعدی هم ناموفق خواهد بود
        // مگر اینکه خطای dispose مربوط به بخشی باشد که _initialized را false نکرده.
        // متد dispose در انتها _initialized را false می‌کند.
      }
    }

    // تلاش دوم: استفاده از Direct URL با HTTP client جدید
    print(
        'Attempting Supabase initialization with Direct URL: $supabaseDirectUrl');
    try {
      // ایجاد Supabase client جدید با HTTP client جدید
      final httpClient2 = SupabaseHttpClient();
      await Supabase.initialize(
          url: supabaseDirectUrl,
          anonKey: supabaseAnonKey,
          httpClient: httpClient2);
      print('Supabase initialized with Direct URL. Pinging...');
      await Supabase.instance.client.from('profiles').select().limit(1).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Ping timeout'),
          );
      print('Successfully connected to Supabase via Direct URL (Cloudflare).');
    } catch (err) {
      print('Supabase Direct URL attempt also failed: $err');
      print('Both API endpoints failed. Supabase could not be initialized.');
      // TODO: در اینجا بهتر است به کاربر اطلاع داده شود یا برنامه به صفحه خطا هدایت شود.
    }
  }
}
