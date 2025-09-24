import 'dart:io';
import 'package:flutter/foundation.dart';

/// Secure configuration management for sensitive data
/// This class handles environment variables and secure storage
class SecureConfig {
  static const String _awsAccessKeyEnv = 'AWS_ACCESS_KEY_ID';
  static const String _awsSecretKeyEnv = 'AWS_SECRET_ACCESS_KEY';
  static const String _awsRegionEnv = 'AWS_REGION';
  static const String _awsEndpointEnv = 'AWS_ENDPOINT_URL';
  static const String _awsBucketEnv = 'AWS_BUCKET_NAME';

  // Fallback values for development (should be removed in production)
  static const String _devAccessKey = '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf';
  static const String _devSecretKey =
      'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5';
  static const String _devRegion = 'ir-thr-at1';
  static const String _devEndpoint =
      'https://coffevista.s3.ir-thr-at1.arvanstorage.ir';
  static const String _devBucket = 'coffevista';

  /// Get AWS Access Key from environment or fallback
  static String get awsAccessKey {
    final envKey = Platform.environment[_awsAccessKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      print(
          '⚠️ Using development AWS credentials. Set $_awsAccessKeyEnv environment variable for production.');
      return _devAccessKey;
    }

    throw Exception(
        'AWS Access Key not configured. Set $_awsAccessKeyEnv environment variable.');
  }

  /// Get AWS Secret Key from environment or fallback
  static String get awsSecretKey {
    final envKey = Platform.environment[_awsSecretKeyEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    if (kDebugMode) {
      print(
          '⚠️ Using development AWS credentials. Set $_awsSecretKeyEnv environment variable for production.');
      return _devSecretKey;
    }

    throw Exception(
        'AWS Secret Key not configured. Set $_awsSecretKeyEnv environment variable.');
  }

  /// Get AWS Region from environment or fallback
  static String get awsRegion {
    final envKey = Platform.environment[_awsRegionEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return _devRegion;
  }

  /// Get AWS Endpoint URL from environment or fallback
  static String get awsEndpointUrl {
    final envKey = Platform.environment[_awsEndpointEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return _devEndpoint;
  }

  /// Get AWS Bucket Name from environment or fallback
  static String get awsBucketName {
    final envKey = Platform.environment[_awsBucketEnv];
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }
    return _devBucket;
  }

  /// Validate that all required credentials are available
  static bool get isConfigured {
    try {
      awsAccessKey;
      awsSecretKey;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get configuration status for debugging
  static Map<String, String> getConfigStatus() {
    return {
      'access_key_configured':
          Platform.environment[_awsAccessKeyEnv]?.isNotEmpty == true
              ? 'Yes'
              : 'No (using dev)',
      'secret_key_configured':
          Platform.environment[_awsSecretKeyEnv]?.isNotEmpty == true
              ? 'Yes'
              : 'No (using dev)',
      'region': awsRegion,
      'endpoint': awsEndpointUrl,
      'bucket': awsBucketName,
      'is_production': !kDebugMode ? 'Yes' : 'No',
    };
  }
}
