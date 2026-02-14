import 'dart:io';
import 'package:flutter/foundation.dart';
import '../security/logging_utility.dart';

/// Secure configuration management for sensitive data.
class SecureConfig {
  static const String _awsAccessKeyEnv = 'AWS_ACCESS_KEY_ID';
  static const String _awsSecretKeyEnv = 'AWS_SECRET_ACCESS_KEY';
  static const String _awsRegionEnv = 'AWS_REGION';
  static const String _awsEndpointEnv = 'AWS_ENDPOINT_URL';
  static const String _awsBucketEnv = 'AWS_BUCKET_NAME';

  // Embedded fallback values.
  static const String _devAccessKey = '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf';
  static const String _devSecretKey =
      'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5';
  static const String _devRegion = 'ir-thr-at1';
  static const String _devEndpoint =
      'https://coffevista.s3.ir-thr-at1.arvanstorage.ir';
  static const String _devBucket = 'coffevista';

  // Values can be injected at build time via --dart-define.
  static const String _awsAccessKeyDefine =
      String.fromEnvironment('AWS_ACCESS_KEY_ID');
  static const String _awsSecretKeyDefine =
      String.fromEnvironment('AWS_SECRET_ACCESS_KEY');
  static const String _awsRegionDefine = String.fromEnvironment('AWS_REGION');
  static const String _awsEndpointDefine =
      String.fromEnvironment('AWS_ENDPOINT_URL');
  static const String _awsBucketDefine =
      String.fromEnvironment('AWS_BUCKET_NAME');
  static const bool _allowEmbeddedAwsInRelease = bool.fromEnvironment(
    'ALLOW_EMBEDDED_AWS_IN_RELEASE',
    defaultValue: true,
  );

  static bool _embeddedWarningLogged = false;

  static bool get _canUseEmbeddedFallback =>
      kDebugMode || _allowEmbeddedAwsInRelease;

  static void _logEmbeddedFallbackOnce() {
    if (_embeddedWarningLogged) return;
    _embeddedWarningLogged = true;
    logWarning(
      'Using embedded AWS fallback credentials. '
      'Provide production credentials via --dart-define for release builds.',
    );
  }

  /// Get AWS Access Key from environment or build-time define.
  static String get awsAccessKey {
    final defineKey = _awsAccessKeyDefine;
    if (defineKey.isNotEmpty) return defineKey;

    final envKey = Platform.environment[_awsAccessKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (_canUseEmbeddedFallback) {
      _logEmbeddedFallbackOnce();
      return _devAccessKey;
    }

    throw Exception('AWS access key not configured');
  }

  /// Get AWS Secret Key from environment or build-time define.
  static String get awsSecretKey {
    final defineKey = _awsSecretKeyDefine;
    if (defineKey.isNotEmpty) return defineKey;

    final envKey = Platform.environment[_awsSecretKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (_canUseEmbeddedFallback) {
      _logEmbeddedFallbackOnce();
      return _devSecretKey;
    }

    throw Exception('AWS secret key not configured');
  }

  /// Get AWS Region from environment or build-time define.
  static String get awsRegion {
    final defineVal = _awsRegionDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsRegionEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (_canUseEmbeddedFallback) {
      _logEmbeddedFallbackOnce();
      return _devRegion;
    }

    throw Exception('AWS region not configured');
  }

  /// Get AWS Endpoint URL from environment or build-time define.
  static String get awsEndpointUrl {
    final defineVal = _awsEndpointDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsEndpointEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (_canUseEmbeddedFallback) {
      _logEmbeddedFallbackOnce();
      return _devEndpoint;
    }

    throw Exception('AWS endpoint URL not configured');
  }

  /// Get AWS Bucket Name from environment or build-time define.
  static String get awsBucketName {
    final defineVal = _awsBucketDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsBucketEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (_canUseEmbeddedFallback) {
      _logEmbeddedFallbackOnce();
      return _devBucket;
    }

    throw Exception('AWS bucket name not configured');
  }

  /// Validate that all required credentials are available.
  static bool get isConfigured {
    try {
      awsAccessKey;
      awsSecretKey;
      awsRegion;
      awsEndpointUrl;
      awsBucketName;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get configuration status for debugging.
  static Map<String, String> getConfigStatus() {
    String safeValue(String Function() getter) {
      try {
        return getter();
      } catch (_) {
        return 'Not set';
      }
    }

    return {
      'access_key_configured':
          Platform.environment[_awsAccessKeyEnv]?.isNotEmpty == true
              ? 'Yes'
              : (_canUseEmbeddedFallback
                  ? 'No (using embedded fallback)'
                  : 'No'),
      'secret_key_configured':
          Platform.environment[_awsSecretKeyEnv]?.isNotEmpty == true
              ? 'Yes'
              : (_canUseEmbeddedFallback
                  ? 'No (using embedded fallback)'
                  : 'No'),
      'region': safeValue(() => awsRegion),
      'endpoint': safeValue(() => awsEndpointUrl),
      'bucket': safeValue(() => awsBucketName),
      'is_production': !kDebugMode ? 'Yes' : 'No',
    };
  }
}
