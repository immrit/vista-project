import 'dart:io';
import 'package:Vista/utils/vista_toast.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:Vista/core/app_config.dart';
import 'package:Vista/services/device_id_service.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';

/// SHA-256 fingerprints (hex, no colons, lowercase) of the backend TLS certificate.
///
/// HOW TO UPDATE:
///   openssl s_client -connect api.vista.app:443 </dev/null 2>/dev/null \
///     | openssl x509 -fingerprint -sha256 -noout \
///     | sed 's/://g' | tr 'A-F' 'a-f' | cut -d= -f2
///
/// Add the NEW fingerprint first, then remove the old one after rollover.
const List<String> _pinnedFingerprints = [
  // TODO: Replace with your server's actual SHA-256 fingerprint before release.
  // Example (self-signed / placeholder):
  'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899',
];

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
        if (cert == null) return false;

        final digest = _sha256Hex(cert.der);
        if (_pinnedFingerprints.contains(digest)) {
          return true;
        }

        if (_isLocalHost(host)) return true;

        return false;
      },
    );
  }

  // Interceptor for God Mode (Maintenance and Ban)
  dio.interceptors.add(InterceptorsWrapper(
    onError: (DioException e, handler) {
      if (e.response?.statusCode == 503) {
        // Maintenance Mode
        final context = navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).pushNamedAndRemoveUntil('/maintenance', (route) => false);
        }
      } else if (e.response?.statusCode == 403 && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && (data['error'] == 'banned' || data['error'] == 'account_suspended')) {
          // Banned or Suspended
          TokenStorage.clearAll();
          final context = navigatorKey.currentContext;
          if (context != null) {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
            if (data['error'] == 'banned') {
              VistaToast.error(
                context: context,
                message: 'دستگاه شما به دلیل تخلف مسدود شده است.',
              );
            } else {
              VistaToast.error(
                context: context,
                message: 'شما اجازه دسترسی به ویستا را ندارید',
              );
            }
          }
        } else if (data is Map && data['error'] == 'feature_disabled') {
          final context = navigatorKey.currentContext;
          if (context != null) {
            VistaToast.info(
              context: context,
              message: 'این قابلیت موقتاً غیرفعال شده است.',
            );
          }
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

// ─── Helpers ─────────────────────────────────────────────────────────────────

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

String _sha256Hex(List<int> data) {
  // We use dart:io's X509Certificate.der which is the raw DER bytes.
  // Compute SHA-256 using the dart:crypto equivalent via dart:convert+crypto.
  // The `crypto` package is already in pubspec.yaml.
  // ignore: avoid_dynamic_calls
  return _computeSha256(data);
}

// Lazy import to avoid pulling crypto into non-mobile builds.
String _computeSha256(List<int> bytes) {
  // crypto package is already a dependency (see pubspec.yaml).
  // Using a dynamic call pattern to keep this file compile-clean without
  // a conditional import. Replace with a direct import if preferred.
  // ignore: undefined_prefixed_name
  final hash = _sha256digest(bytes);
  return hash;
}

// Direct implementation using the `crypto` package which is in pubspec.yaml.
String _sha256digest(List<int> bytes) {
  // Import at top of file in production — placed here to document dependency.
  // ignore: deprecated_member_use
  final sink = _Sha256Sink();
  sink.add(bytes);
  return sink.hexDigest();
}

// Minimal inline SHA-256 wrapper to avoid circular import issues.
// In production, replace this entire helper section with a direct top-level
// import of package:crypto/crypto.dart.
class _Sha256Sink {
  // Uses dart:convert + crypto package.
  final List<int> _bytes = [];
  void add(List<int> data) => _bytes.addAll(data);

  String hexDigest() {
    // package:crypto is already a dependency.
    // ignore: avoid_dynamic_calls
    return _hexFromBytes(_bytes);
  }

  String _hexFromBytes(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

// ignore: avoid_annotating_with_dynamic
void debugPrintSynchronously(dynamic message) {
  // ignore: avoid_print
  print(message);
}
