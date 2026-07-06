import 'dart:async';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:Vista/utils/env_config.dart';
import 'package:Vista/services/device_id_service.dart';

/// Holds the admin-managed TLS pinning config delivered through
/// /api/v1/system/status. http_client_factory reads this synchronously at the
/// TLS handshake, so it must never block. Deliberately server-driven: a static
/// pin baked into the build would brick every client the day the certificate
/// rotates. Here the admin rotates the fingerprint in the panel and clients
/// pick it up on the next status poll — no app update, no silent outage.
enum TlsPinMode { off, monitor, enforce }

class TlsPinningConfig {
  final TlsPinMode mode;
  final Set<String> fingerprints; // lowercase hex sha256, no colons
  final String? expiresAt;

  const TlsPinningConfig({
    this.mode = TlsPinMode.off,
    this.fingerprints = const {},
    this.expiresAt,
  });

  static TlsPinMode _mode(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'enforce':
        return TlsPinMode.enforce;
      case 'monitor':
        return TlsPinMode.monitor;
      default:
        return TlsPinMode.off;
    }
  }

  factory TlsPinningConfig.fromJson(Map<String, dynamic> json) {
    final rawList = json['fingerprints'];
    final fps = <String>{};
    if (rawList is List) {
      for (final item in rawList) {
        final f =
            item.toString().replaceAll(':', '').trim().toLowerCase();
        if (f.length == 64) fps.add(f);
      }
    }
    return TlsPinningConfig(
      mode: _mode(json['mode']?.toString()),
      fingerprints: fps,
      expiresAt: json['expires_at']?.toString(),
    );
  }
}

class TlsPinningStore {
  TlsPinningStore._();
  static final TlsPinningStore instance = TlsPinningStore._();

  TlsPinningConfig _config = const TlsPinningConfig();
  TlsPinningConfig get config => _config;

  void update(TlsPinningConfig config) {
    _config = config;
  }

  /// Decides whether an OS-trusted certificate is acceptable under the current
  /// pinning policy. Returns true (accept) for off/monitor or a matching pin;
  /// returns false (block) only in enforce mode on a mismatch. Never throws.
  bool allowCertificate(List<int> der, String host) {
    final cfg = _config;
    if (cfg.mode == TlsPinMode.off || cfg.fingerprints.isEmpty) {
      return true;
    }
    final digest = crypto.sha256.convert(der).toString();
    if (cfg.fingerprints.contains(digest)) {
      return true;
    }
    // Mismatch — tell the backend so it shows up in the panel, then decide.
    unawaited(_report(host, digest));
    return cfg.mode != TlsPinMode.enforce; // monitor => allow, enforce => block
  }

  bool _reportingInFlight = false;
  DateTime? _lastReportAt;

  Future<void> _report(String host, String seenFingerprint) async {
    // Throttle: one report at a time, at most once per 60s, so a bad cert on
    // a busy screen doesn't hammer the endpoint.
    final now = DateTime.now();
    if (_reportingInFlight) return;
    if (_lastReportAt != null &&
        now.difference(_lastReportAt!) < const Duration(seconds: 60)) {
      return;
    }
    _reportingInFlight = true;
    _lastReportAt = now;
    try {
      // Bare, unpinned client — this must go through even when the pin is
      // wrong, otherwise the mismatch would never be reported.
      final dio = Dio(BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'X-Device-ID': DeviceIdService.id},
      ));
      await dio.post('/api/v1/system/tls-report', data: {
        'host': host,
        'seen_fingerprint': seenFingerprint,
      });
    } catch (_) {
      // best-effort telemetry
    } finally {
      _reportingInFlight = false;
    }
  }
}
