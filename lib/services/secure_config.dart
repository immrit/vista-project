import 'dart:io';
import 'package:flutter/foundation.dart';
import '../security/logging_utility.dart';

/// Secure configuration management for sensitive data
/// This class handles environment variables and secure storage
class SecureConfig {
  static const String _awsAccessKeyEnv = 'AWS_ACCESS_KEY_ID';
  static const String _awsSecretKeyEnv = 'AWS_SECRET_ACCESS_KEY';
  static const String _awsRegionEnv = 'AWS_REGION';
  static const String _awsEndpointEnv = 'AWS_ENDPOINT_URL';
  static const String _awsBucketEnv = 'AWS_BUCKET_NAME';

  // Development fallback values (debug only)
  static const String _devAccessKey = '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf';
  static const String _devSecretKey =
      'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5';
  static const String _devRegion = 'ir-thr-at1';
  static const String _devEndpoint =
      'https://coffevista.s3.ir-thr-at1.arvanstorage.ir';
  static const String _devBucket = 'coffevista';

  // Values can be injected at build time via --dart-define
  static const String _awsAccessKeyDefine =
      String.fromEnvironment('AWS_ACCESS_KEY_ID');
  static const String _awsSecretKeyDefine =
      String.fromEnvironment('AWS_SECRET_ACCESS_KEY');
  static const String _awsRegionDefine = String.fromEnvironment('AWS_REGION');
  static const String _awsEndpointDefine =
      String.fromEnvironment('AWS_ENDPOINT_URL');
  static const String _awsBucketDefine =
      String.fromEnvironment('AWS_BUCKET_NAME');

  /// Get AWS Access Key from environment or build-time define
  static String get awsAccessKey {
    final defineKey = _awsAccessKeyDefine;
    if (defineKey.isNotEmpty) return defineKey;

    final envKey = Platform.environment[_awsAccessKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      logInfo(
          '⚠️ Using development AWS access key. Set $_awsAccessKeyEnv for production.');
      return _devAccessKey;
    }

    throw Exception('AWS access key not configured');
  }

  /// Get AWS Secret Key from environment or build-time define
  static String get awsSecretKey {
    final defineKey = _awsSecretKeyDefine;
    if (defineKey.isNotEmpty) return defineKey;

    final envKey = Platform.environment[_awsSecretKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      logInfo(
          '⚠️ Using development AWS secret key. Set $_awsSecretKeyEnv for production.');
      return _devSecretKey;
    }

    throw Exception('AWS secret key not configured');
  }

  /// Get AWS Region from environment or build-time define
  static String get awsRegion {
    final defineVal = _awsRegionDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsRegionEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      return _devRegion;
    }

    throw Exception('AWS region not configured');
  }

  /// Get AWS Endpoint URL from environment or build-time define
  static String get awsEndpointUrl {
    final defineVal = _awsEndpointDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsEndpointEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      return _devEndpoint;
    }

    throw Exception('AWS endpoint URL not configured');
  }

  /// Get AWS Bucket Name from environment or build-time define
  static String get awsBucketName {
    final defineVal = _awsBucketDefine;
    if (defineVal.isNotEmpty) return defineVal;

    final envKey = Platform.environment[_awsBucketEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      return _devBucket;
    }

    throw Exception('AWS bucket name not configured');
  }

  /// Validate that all required credentials are available
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

  /// Get configuration status for debugging
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
              : (kDebugMode ? 'No (using dev)' : 'No'),
      'secret_key_configured':
          Platform.environment[_awsSecretKeyEnv]?.isNotEmpty == true
              ? 'Yes'
              : (kDebugMode ? 'No (using dev)' : 'No'),
      'region': safeValue(() => awsRegion),
      'endpoint': safeValue(() => awsEndpointUrl),
      'bucket': safeValue(() => awsBucketName),
      'is_production': !kDebugMode ? 'Yes' : 'No',
    };
  }
}
