import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/logging_utility.dart';
import 'secure_config.dart';
import 'session_manager_service_v2.dart';

class SecureUploadConfig {
  static const bool enableSignedUploads =
      bool.fromEnvironment('ENABLE_SIGNED_UPLOADS', defaultValue: false);

  static bool get allowLegacyPublicUploads {
    return const bool.fromEnvironment('ALLOW_LEGACY_PUBLIC_UPLOADS',
        defaultValue: true);
  }
}

class UploadResult {
  final String url;
  final String objectKey;
  final bool isPublic;

  UploadResult({
    required this.url,
    required this.objectKey,
    required this.isPublic,
  });
}

class SignedUrlResponse {
  final String uploadUrl;
  final String? fileUrl;
  final Map<String, String> headers;
  final bool isPublic;

  SignedUrlResponse({
    required this.uploadUrl,
    required this.fileUrl,
    required this.headers,
    required this.isPublic,
  });
}

class SignedDeleteResponse {
  final String? deleteUrl;
  final Map<String, String> headers;
  final bool success;

  SignedDeleteResponse({
    required this.deleteUrl,
    required this.headers,
    required this.success,
  });
}

class SignedUrlService {
  static const String _primaryBaseUrl = String.fromEnvironment(
    'SIGNED_UPLOADS_BASE_URL',
    defaultValue: 'https://function-vista.chbk.dev/api',
  );
  static const String _fallbackBaseUrl = String.fromEnvironment(
    'SIGNED_UPLOADS_BASE_URL_FALLBACK',
    defaultValue: 'https://function-vista.chbk.app/api',
  );
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 2;

  static bool _isRetryable(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }

  static bool _shouldFallback(DioException e) {
    if (_fallbackBaseUrl.isEmpty) return false;
    if (_isRetryable(e)) return true;
    final status = e.response?.statusCode ?? 0;
    return status == 404 || status == 405 || status == 410 || status >= 500;
  }

  static void _logDioError(DioException e, String url) {
    try {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      logInfo('Signed URL error: ${e.type} on $url');
      if (status != null) {
        logInfo('Signed URL status: $status');
      }
      if (data != null) {
        logInfo('Signed URL response: $data');
      }
    } catch (_) {
      // ignore logging failures
    }
  }

  static Future<Response<dynamic>> _postWithRetryOnBase(
    String baseUrl,
    String path,
    Map<String, dynamic> payload,
  ) async {
    int attempt = 0;
    while (true) {
      try {
        final dio = Dio(
          BaseOptions(
            connectTimeout: _timeout,
            receiveTimeout: _timeout,
            sendTimeout: _timeout,
            headers: await _buildAuthHeaders(),
          ),
        );
        return await dio.post('$baseUrl$path', data: payload);
      } on DioException catch (e) {
        _logDioError(e, '$baseUrl$path');
        if (!_isRetryable(e) || attempt >= _maxRetries) rethrow;
        attempt++;
        final backoff = Duration(milliseconds: 500 * (1 << (attempt - 1)));
        logInfo('Signed URL request retry #$attempt after $backoff: ${e.type}');
        await Future.delayed(backoff);
      }
    }
  }

  static Future<Response<dynamic>> _postWithRetry(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _postWithRetryOnBase(_primaryBaseUrl, path, payload);
    } on DioException catch (e) {
      if (_shouldFallback(e)) {
        logInfo(
            'Signed URL request failed on primary, trying fallback base URL.');
        return await _postWithRetryOnBase(_fallbackBaseUrl, path, payload);
      }
      rethrow;
    }
  }

  static Future<SignedUrlResponse> createUploadUrl({
    required String objectKey,
    required String contentType,
    int? contentLength,
    String? bucket,
  }) async {
    final payload = {
      'key': objectKey,
      'content_type': contentType,
      if (contentLength != null) 'content_length': contentLength,
      if (bucket != null) 'bucket': bucket,
    };

    final response = await _postWithRetry('/storage/sign-upload', payload);

    final data = response.data as Map<String, dynamic>;
    return SignedUrlResponse(
      uploadUrl: data['upload_url'] as String,
      fileUrl: data['file_url'] as String?,
      headers: (data['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          <String, String>{},
      isPublic: data['is_public'] == true,
    );
  }

  static Future<String?> createDownloadUrl({
    required String objectKey,
    String? bucket,
  }) async {
    final payload = {
      'key': objectKey,
      if (bucket != null) 'bucket': bucket,
    };

    final response = await _postWithRetry('/storage/sign-download', payload);
    final data = response.data as Map<String, dynamic>;
    return data['url'] as String?;
  }

  static Future<SignedDeleteResponse> createDeleteUrl({
    required String objectKey,
    String? bucket,
  }) async {
    final payload = {
      'key': objectKey,
      if (bucket != null) 'bucket': bucket,
    };

    final response = await _postWithRetry('/storage/sign-delete', payload);
    final data = response.data as Map<String, dynamic>;

    return SignedDeleteResponse(
      deleteUrl: (data['delete_url'] ?? data['url']) as String?,
      headers: (data['headers'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          <String, String>{},
      success: data['success'] == true || data['deleted'] == true,
    );
  }

  static Future<Map<String, String>> _buildAuthHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final sessionManager = SessionManagerServiceV2.instance;
    final sessionId = sessionManager.currentSessionId;
    final sessionToken = sessionManager.currentSessionToken;
    if (sessionId != null && sessionId.isNotEmpty) {
      headers['x-session-id'] = sessionId;
    }
    if (sessionToken != null && sessionToken.isNotEmpty) {
      headers['x-session-token'] = sessionToken;
    }

    return headers;
  }
}

class SecureUploadService {
  static const String _defaultBucketName =
      String.fromEnvironment('ARVAN_BUCKET_NAME', defaultValue: 'coffevista');
  static const String _cdnBaseUrl = 'https://storage.389346.ir.cdn.ir';
  static const Duration _uploadTimeout = Duration(seconds: 120);

  static String? _tryResolveBucket(String? bucket) {
    if (bucket != null && bucket.isNotEmpty) {
      return bucket;
    }
    if (_defaultBucketName.isNotEmpty) {
      return _defaultBucketName;
    }
    try {
      return SecureConfig.awsBucketName;
    } catch (_) {
      return null;
    }
  }

  static Future<UploadResult> uploadBytes({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
    void Function(double progress)? onProgress,
    String? bucket,
  }) async {
    final bucketName = _tryResolveBucket(bucket);

    if (SecureUploadConfig.enableSignedUploads) {
      try {
        final signed = await SignedUrlService.createUploadUrl(
          objectKey: objectKey,
          contentType: contentType,
          contentLength: bytes.length,
          bucket: bucketName,
        );

        final dio = Dio(
          BaseOptions(
            connectTimeout: SignedUrlService._timeout,
            sendTimeout: _uploadTimeout,
            receiveTimeout: SignedUrlService._timeout,
          ),
        );
        await dio.put(
          signed.uploadUrl,
          data: bytes,
          options: Options(
            headers: {
              'Content-Type': contentType,
              ...signed.headers,
            },
          ),
          onSendProgress: (sent, total) {
            if (onProgress != null && total > 0) {
              onProgress(sent / total);
            }
          },
        );

        final url = signed.fileUrl ??
            (bucketName != null
                ? _buildPublicUrl(bucketName, objectKey)
                : null);
        if (url == null || url.isEmpty) {
          throw Exception(
              'Signed upload did not return file URL and bucket is not configured.');
        }
        return UploadResult(
          url: url,
          objectKey: objectKey,
          isPublic: signed.isPublic,
        );
      } catch (e) {
        logInfo('Signed upload failed: $e');
        if (!SecureUploadConfig.allowLegacyPublicUploads) rethrow;
      }
    }

    if (SecureUploadConfig.allowLegacyPublicUploads) {
      if (bucketName == null || bucketName.isEmpty) {
        throw Exception(
            'Legacy upload requires AWS bucket name. Set AWS_BUCKET_NAME or disable legacy uploads.');
      }
      return _legacyUploadBytes(
        bytes: bytes,
        objectKey: objectKey,
        contentType: contentType,
        bucket: bucketName ?? SecureConfig.awsBucketName,
        onProgress: onProgress,
      );
    }

    throw Exception('Secure upload not configured');
  }

  static Future<UploadResult> uploadFile({
    required File file,
    required String objectKey,
    required String contentType,
    void Function(double progress)? onProgress,
    String? bucket,
  }) async {
    final bucketName = _tryResolveBucket(bucket);

    if (SecureUploadConfig.enableSignedUploads) {
      try {
        final length = await file.length();
        final signed = await SignedUrlService.createUploadUrl(
          objectKey: objectKey,
          contentType: contentType,
          contentLength: length,
          bucket: bucketName,
        );

        final dio = Dio(
          BaseOptions(
            connectTimeout: SignedUrlService._timeout,
            sendTimeout: _uploadTimeout,
            receiveTimeout: SignedUrlService._timeout,
          ),
        );
        await dio.put(
          signed.uploadUrl,
          data: file.openRead(),
          options: Options(
            headers: {
              'Content-Type': contentType,
              'Content-Length': length.toString(),
              ...signed.headers,
            },
          ),
          onSendProgress: (sent, total) {
            if (onProgress != null && total > 0) {
              onProgress(sent / total);
            }
          },
        );

        final url = signed.fileUrl ??
            (bucketName != null
                ? _buildPublicUrl(bucketName, objectKey)
                : null);
        if (url == null || url.isEmpty) {
          throw Exception(
              'Signed upload did not return file URL and bucket is not configured.');
        }
        return UploadResult(
          url: url,
          objectKey: objectKey,
          isPublic: signed.isPublic,
        );
      } catch (e) {
        logInfo('Signed file upload failed: $e');
        if (!SecureUploadConfig.allowLegacyPublicUploads) rethrow;
      }
    }

    if (SecureUploadConfig.allowLegacyPublicUploads) {
      if (bucketName == null || bucketName.isEmpty) {
        throw Exception(
            'Legacy upload requires AWS bucket name. Set AWS_BUCKET_NAME or disable legacy uploads.');
      }
      final bytes = await file.readAsBytes();
      return _legacyUploadBytes(
        bytes: bytes,
        objectKey: objectKey,
        contentType: contentType,
        bucket: bucketName ?? SecureConfig.awsBucketName,
        onProgress: onProgress,
      );
    }

    throw Exception('Secure upload not configured');
  }

  static Future<bool> deleteObject({
    required String objectKey,
    String? bucket,
  }) async {
    if (objectKey.isEmpty) {
      return false;
    }

    if (SecureUploadConfig.enableSignedUploads) {
      try {
        final signed = await SignedUrlService.createDeleteUrl(
          objectKey: objectKey,
          bucket: bucket,
        );

        if (signed.success && signed.deleteUrl == null) {
          return true;
        }

        if (signed.deleteUrl != null) {
          final dio = Dio();
          await dio.delete(
            signed.deleteUrl!,
            options: Options(headers: signed.headers),
          );
          return true;
        }
      } catch (e) {
        logInfo('Signed delete failed: $e');
        if (!SecureUploadConfig.allowLegacyPublicUploads) rethrow;
      }
    }

    if (SecureUploadConfig.allowLegacyPublicUploads) {
      final bucketName = bucket ?? _tryGetDefaultBucket();
      if (bucketName == null || bucketName.isEmpty) {
        logInfo('Legacy delete skipped: bucket not resolved');
        return false;
      }
      if (!SecureConfig.isConfigured) {
        throw Exception('AWS credentials not properly configured.');
      }

      final s3 = _buildS3Client();
      await s3.deleteObject(
        bucket: bucketName,
        key: objectKey,
      );
      return true;
    }

    return false;
  }

  static Future<bool> deleteByUrl(String fileUrl, {String? bucket}) async {
    if (fileUrl.isEmpty) {
      return false;
    }

    Uri uri;
    try {
      uri = Uri.parse(fileUrl);
    } catch (e) {
      logInfo('Invalid file URL: $e');
      return false;
    }

    final segments = uri.pathSegments;
    if (segments.isEmpty) {
      return false;
    }

    final resolvedBucket = _resolveBucketName(segments, bucket);
    final objectKey = _extractObjectKey(segments, resolvedBucket);
    if (objectKey.isEmpty) {
      return false;
    }

    return deleteObject(
      objectKey: objectKey,
      bucket: resolvedBucket,
    );
  }

  static Future<UploadResult> _legacyUploadBytes({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
    required String bucket,
    void Function(double progress)? onProgress,
  }) async {
    if (!SecureConfig.isConfigured) {
      throw Exception('AWS credentials not properly configured.');
    }

    final s3 = _buildS3Client();

    if (onProgress != null) {
      onProgress(0.0);
    }

    await s3.putObject(
      bucket: bucket,
      key: objectKey,
      body: bytes,
      contentType: contentType,
      acl: ObjectCannedACL.publicRead, // legacy compatibility
    );

    if (onProgress != null) {
      onProgress(1.0);
    }

    return UploadResult(
      url: _buildPublicUrl(bucket, objectKey),
      objectKey: objectKey,
      isPublic: true,
    );
  }

  static S3 _buildS3Client() {
    return S3(
      region: SecureConfig.awsRegion,
      credentials: AwsClientCredentials(
        accessKey: SecureConfig.awsAccessKey,
        secretKey: SecureConfig.awsSecretKey,
      ),
      endpointUrl: SecureConfig.awsEndpointUrl,
    );
  }

  static String _buildPublicUrl(String bucket, String key) {
    return '$_cdnBaseUrl/$bucket/$key';
  }

  static String? _tryGetDefaultBucket() {
    try {
      return SecureConfig.awsBucketName;
    } catch (_) {
      return null;
    }
  }

  static String? _resolveBucketName(
    List<String> segments,
    String? bucket,
  ) {
    if (bucket != null && bucket.isNotEmpty) {
      return bucket;
    }

    final defaultBucket = _tryGetDefaultBucket();
    if (defaultBucket != null && segments.contains(defaultBucket)) {
      return defaultBucket;
    }

    if (segments.isNotEmpty) {
      return segments.first;
    }

    return null;
  }

  static String _extractObjectKey(
    List<String> segments,
    String? bucketName,
  ) {
    if (segments.isEmpty) {
      return '';
    }

    if (bucketName != null) {
      final bucketIndex = segments.indexOf(bucketName);
      if (bucketIndex >= 0 && bucketIndex < segments.length - 1) {
        return segments.sublist(bucketIndex + 1).join('/');
      }
    }

    if (segments.length > 1) {
      return segments.sublist(1).join('/');
    }

    return segments.first;
  }
}
