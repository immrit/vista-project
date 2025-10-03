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
        // ایجاد request جدید برای هر تلاش (برای جلوگیری از خطای finalize)
        final newRequest = _createNewRequest(request);

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
    print('❌ Supabase connectivity check failed: $e');
    return false;
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

    await Supabase.instance.client.from('profiles').select().limit(1).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Ping timeout'),
        );
    return; // اتصال موفق، خروج از تابع
  } catch (e) {
    print('⚠️ CDN URL failed: $e');

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
        print('⚠️ Error disposing Supabase instance: $disposeError');
      }
    }

    // تلاش دوم: استفاده از Direct URL با HTTP client جدید
    try {
      print(
          'Attempting Supabase initialization with Direct URL: $supabaseDirectUrl');

      // ایجاد Supabase client جدید با HTTP client جدید
      final httpClient2 = SupabaseHttpClient();
      await Supabase.initialize(
          url: supabaseDirectUrl,
          anonKey: supabaseAnonKey,
          httpClient: httpClient2);

      await Supabase.instance.client.from('profiles').select().limit(1).timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Ping timeout'),
          );

      print('✅ Supabase initialized successfully with Direct URL');
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
          );
          print('✅ Supabase با تنظیمات minimal initialize شد (حالت توسعه)');
          print('⚠️ اتصال به دیتابیس ممکن است کار نکند اما برنامه اجرا می‌شود');
          return; // خروج موفق
        } catch (minimalErr) {
          print('❌ حتی minimal Supabase هم شکست خورد: $minimalErr');
          // در این حالت نیز اجازه بده برنامه اجرا شود
          print('🔧 برنامه بدون Supabase اجرا می‌شود');
          return;
        }
      } else {
        rethrow; // در حالت production، اجازه نده برنامه اجرا شود
      }
    }
  }
}
