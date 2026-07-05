import 'dart:io';
import 'package:Vista/utils/vista_toast.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:Vista/core/app_config.dart';
import 'package:Vista/services/device_id_service.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'package:Vista/screens/maintenance_screen.dart';
import 'package:Vista/services/refresh_interceptor.dart';

/// SHA-256 fingerprints (hex, no colons, lowercase) of the backend TLS certificate.
///
/// HOW TO UPDATE:
/// ```
///   openssl s_client -connect api.coffevista.ir:443 < /dev/null 2>/dev/null \
///     | openssl x509 -fingerprint -sha256 -noout \
///     | sed 's/://g' | tr 'A-F' 'a-f' | cut -d= -f2
/// ```
///
/// Add the NEW fingerprint first, then remove the old one after rollover.
const List<String> _pinnedFingerprints = [
  // TODO: Replace with your server's actual SHA-256 fingerprint before release.
  // Example (self-signed / placeholder):
  'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
];

const String _placeholderFingerprint =
    'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';

/// Creates a [Dio] instance with certificate pinning configured.
///
/// All API calls should use this factory instead of creating bare [Dio] or
/// [http.Client] instances, so pinning is enforced everywhere.
Dio createPinnedDioClient({
  String? baseUrl,
  Map<String, dynamic>? headers,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? backendUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        ...headers ?? {},
        'X-Device-ID': DeviceIdService.id,
      },
    ),
  );

  // Only pin on mobile; on web/desktop the OS trust store is used.
  if (!kIsWebPlatform) {
    final shouldEnforcePinning = _hasValidPinnedFingerprints();
    if (shouldEnforcePinning) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) {
            return false; // reject bad certs by default
          };
          return client;
        },
        validateCertificate: (cert, host, port) {
          // Plain HTTP connections have no certificate — always allow.
          if (cert == null) return true;

          final digest = _sha256Hex(cert.der);
          if (_pinnedFingerprints.contains(digest)) {
            return true;
          }

          if (_isLocalHost(host)) return true;

          return false;
        },
      );
    } else {
      // No valid pins configured yet: rely on OS trust store, otherwise all
      // HTTPS calls behind this factory would fail with bad certificate.
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient(),
      );
    }
  }

  // Re-resolve the Bearer token per request. createAuthedPinnedDio bakes the
  // access token into base headers at construction; after a refresh rotates
  // it, a long-lived client would keep sending the stale token and every
  // request would 401 on arrival. Only headers that already carry a Bearer
  // token are touched, so unauthenticated/special-token requests are safe.
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final existing = options.headers['Authorization'];
      if (existing is String && existing.startsWith('Bearer ')) {
        final token = await TokenStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }
      handler.next(options);
    },
  ));

  dio.interceptors.add(RefreshTokenInterceptor(dio));

  // Interceptor for God Mode (Maintenance and Ban)
  dio.interceptors.add(InterceptorsWrapper(
    onError: (DioException e, handler) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      // The backend uses two error envelope shapes:
      //   nested (httpapi): {"error": {"code": "error", "message": "banned"}}
      //   flat (feature gate): {"error": "feature_disabled", "feature": "chat"}
      // apiErrorCode() normalizes both to a single comparable code string.
      final code = apiErrorCode(data);

      if (statusCode == 503) {
        // Only the control plane's real maintenance mode carries
        // `maintenance_mode`; other 503s (auth/session service unavailable,
        // proxy hiccups) must propagate as normal errors instead of
        // hijacking the whole navigation stack.
        if (code == 'maintenance_mode' && !MaintenanceScreen.isActive) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/maintenance', (route) => false);
          }
        }
      } else if (statusCode == 403 && data != null) {
        if (code == 'banned' ||
            code == 'account_banned' ||
            code == 'account_suspended') {
          // Banned or Suspended
          TokenStorage.clearAll();
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context)
                .pushNamedAndRemoveUntil('/banned', (route) => false);
            if (code == 'account_suspended') {
              VistaToast.error(
                context: context,
                message: 'شما اجازه دسترسی به ویستا را ندارید (حساب معلق)',
              );
            } else {
              VistaToast.error(
                context: context,
                message: 'حساب شما به دلیل تخلف مسدود شده است.',
              );
            }
          }
        } else if (code == 'account_muted') {
          final context = navigatorKey.currentContext;
          if (context != null) {
            VistaToast.error(
              context: context,
              message:
                  'شما به دلیل تخلف محدود شده‌اید و مجاز به ارسال محتوا نیستید.',
            );
          }
        } else if (code == 'feature_disabled') {
          final context = navigatorKey.currentContext;
          if (context != null) {
            final feature =
                data is Map ? '${data['feature'] ?? ''}'.trim() : '';
            final message = _featureDisabledMessage(feature);
            VistaToast.info(
              context: context,
              message: message,
            );
          }
        }
      } else if (statusCode == 429) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          VistaToast.info(
            context: context,
            message:
                'درخواست‌ها بیش از حد مجاز است. چند لحظه بعد دوباره تلاش کنید.',
          );
        }
      }
      return handler.next(e);
    },
  ));

  // Add a logging interceptor in debug mode.
  assert(() {
    dio.interceptors.add(LogInterceptor(
      requestBody: false, // never log bodies — may contain credentials
      responseBody: false,
      logPrint: (o) => debugPrintSynchronously(o.toString()),
    ));
    return true;
  }());

  return dio;
}

/// Creates an authenticated [Dio] client with optional API path suffix.
/// Creates a Dio client for REST `/v1` API calls with pinning and global interceptors.
Dio createApiV1Dio({String? baseUrl}) {
  final root = (baseUrl ?? backendUrl).replaceAll(RegExp(r'/+$'), '');
  return createPinnedDioClient(
    baseUrl: '$root/v1',
    headers: {'Content-Type': 'application/json'},
  );
}

Future<Dio?> createAuthedPinnedDio({String apiPath = '/v1'}) async {
  final token = await TokenStorage.getAccessToken();
  if (token == null || token.isEmpty) return null;

  final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
  return createPinnedDioClient(
    baseUrl: '$base$apiPath',
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Extracts a comparable error code from a backend error body, handling both
/// envelope shapes the Go backend produces:
///   nested: {"error": {"code": "error", "message": "banned"}}
///   flat:   {"error": "feature_disabled", "feature": "chat", ...}
/// Returns '' when the body has no recognizable error field.
String apiErrorCode(dynamic data) {
  if (data is! Map) return '';
  final err = data['error'];
  if (err is Map) {
    final message = err['message'];
    if (message is String && message.isNotEmpty) return message;
    final code = err['code'];
    if (code is String && code.isNotEmpty) return code;
    return '';
  }
  if (err is String) return err;
  return '';
}

bool get kIsWebPlatform {
  try {
    return identical(0, 0.0); // always false on native
  } catch (_) {
    return true;
  }
}

bool _isLocalHost(String host) =>
    host == 'localhost' ||
    host == '127.0.0.1' ||
    host == '10.0.2.2' || // Android emulator
    host == '10.0.3.2'; // Genymotion

bool _hasValidPinnedFingerprints() {
  if (_pinnedFingerprints.isEmpty) return false;
  for (final fingerprint in _pinnedFingerprints) {
    final normalized = fingerprint.trim().toLowerCase();
    if (normalized.length != 64) continue;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) continue;
    if (normalized == _placeholderFingerprint) continue;
    return true;
  }
  return false;
}

String _featureDisabledMessage(String feature) {
  switch (feature) {
    case 'chat':
      return 'پیام‌رسانی موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'posts':
      return 'ارسال پست موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'comments':
      return 'ثبت کامنت موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'feed':
      return 'فید موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'stories':
      return 'استوری موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'uploads':
      return 'آپلود فایل موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'payments':
      return 'پرداخت موقتاً از اتاق کنترل غیرفعال شده است.';
    case 'auth':
      return 'ورود و ثبت‌نام موقتاً از اتاق کنترل غیرفعال شده است.';
    default:
      return 'این قابلیت موقتاً از اتاق کنترل غیرفعال شده است.';
  }
}

String _sha256Hex(List<int> data) {
  return crypto.sha256.convert(data).toString();
}

// ignore: avoid_annotating_with_dynamic
void debugPrintSynchronously(dynamic message) {
  // ignore: avoid_print
  print(message);
}
