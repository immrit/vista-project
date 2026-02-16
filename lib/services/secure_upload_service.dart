import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart' as aws;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../security/logging_utility.dart';
import 'secure_config.dart';
import 'session_manager_service_v2.dart';

class SecureUploadConfig {
  static const bool enableSignedUploads =
      bool.fromEnvironment('ENABLE_SIGNED_UPLOADS', defaultValue: true);

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

enum SecureUploadStage {
  sign,
  uploadSigned,
  uploadLegacy,
  urlResolve,
}

class SecureUploadException implements Exception {
  final String userMessage;
  final SecureUploadStage stage;
  final String code;
  final Object? cause;

  const SecureUploadException({
    required this.userMessage,
    required this.stage,
    required this.code,
    this.cause,
  });

  @override
  String toString() {
    final technical =
        cause == null ? '' : ' cause=${cause.runtimeType}: $cause';
    return '$userMessage | technical: stage=${_stageName(stage)} code=$code$technical';
  }

  static String _stageName(SecureUploadStage stage) {
    switch (stage) {
      case SecureUploadStage.sign:
        return 'sign';
      case SecureUploadStage.uploadSigned:
        return 'upload_signed';
      case SecureUploadStage.uploadLegacy:
        return 'upload_legacy';
      case SecureUploadStage.urlResolve:
        return 'url_resolve';
    }
  }
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
  static const Duration _timeout = Duration(seconds: 10);
  static const int _maxRetries = 0;
  static const Duration _unsupportedBaseTtl = Duration(minutes: 10);
  static final Map<String, DateTime> _unsupportedBaseUntil =
      <String, DateTime>{};

  static bool _isRetryable(DioException e) {
    if (_isTlsHandshakeIssue(e)) {
      return true;
    }
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.badCertificate;
  }

  static bool _isRouteMissingResponse(DioException e) {
    final status = e.response?.statusCode;
    if (status != 404 && status != 405) return false;
    final body = (e.response?.data ?? '').toString().toLowerCase();
    return body.contains('cannot post') || body.contains('not found');
  }

  static bool _isBaseTemporarilyUnsupported(String baseUrl) {
    final until = _unsupportedBaseUntil[baseUrl];
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _unsupportedBaseUntil.remove(baseUrl);
      return false;
    }
    return true;
  }

  static void _markBaseTemporarilyUnsupported(
    String baseUrl,
    DioException error,
  ) {
    if (!_isRouteMissingResponse(error)) return;
    _unsupportedBaseUntil[baseUrl] = DateTime.now().add(_unsupportedBaseTtl);
    logWarning(
      'Signed URL base disabled temporarily due to missing route: $baseUrl',
    );
  }

  static bool _shouldFallback(DioException e) {
    if (_fallbackBaseUrl.isEmpty) return false;
    if (_isRetryable(e)) return true;
    final status = e.response?.statusCode ?? 0;
    return status == 404 || status == 405 || status == 410 || status >= 500;
  }

  static bool _isTlsHandshakeIssue(DioException e) {
    if (e.error is HandshakeException || e.error is TlsException) {
      return true;
    }

    final raw = '${e.message ?? ''} ${e.error ?? ''}'.toLowerCase();
    return raw.contains('handshakeexception') ||
        raw.contains('connection terminated during handshake') ||
        raw.contains('ssl') ||
        raw.contains('tls') ||
        raw.contains('certificate');
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
        _markBaseTemporarilyUnsupported(baseUrl, e);
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
    final baseCandidates = <String>[];
    final seen = <String>{};
    void addCandidate(String baseUrl) {
      if (baseUrl.isEmpty) return;
      if (_isBaseTemporarilyUnsupported(baseUrl)) return;
      if (seen.add(baseUrl)) {
        baseCandidates.add(baseUrl);
      }
    }

    if (kReleaseMode) {
      // .app is typically more stable on some Android release network stacks.
      addCandidate(_fallbackBaseUrl);
    }
    addCandidate(_primaryBaseUrl);
    addCandidate(_fallbackBaseUrl);

    if (baseCandidates.isEmpty) {
      throw const SecureUploadException(
        userMessage: 'Signed upload service is temporarily unavailable.',
        stage: SecureUploadStage.sign,
        code: 'SIGNED_URL_BASES_UNAVAILABLE',
      );
    }

    DioException? lastDioError;
    for (var i = 0; i < baseCandidates.length; i++) {
      final baseUrl = baseCandidates[i];
      try {
        return await _postWithRetryOnBase(baseUrl, path, payload);
      } on DioException catch (e, st) {
        lastDioError = e;
        final hasNext = i < baseCandidates.length - 1;
        final canFallback = hasNext && _shouldFallback(e);
        logWarning(
          'Signed URL request failed on $baseUrl (type=${e.type}, fallback=$canFallback)',
          error: e,
          stackTrace: st,
        );
        if (!canFallback) {
          rethrow;
        }
      }
    }

    if (lastDioError != null) {
      throw lastDioError;
    }

    throw const SecureUploadException(
      userMessage: 'Could not reach signed upload service.',
      stage: SecureUploadStage.sign,
      code: 'SIGNED_URL_SERVICE_UNREACHABLE',
    );
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
  static const Duration _uploadTimeout = Duration(minutes: 10);
  static bool _modeLoggedOnce = false;

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
    _logRuntimeModeOnce(bucketName: bucketName);
    if (onProgress != null) {
      onProgress(0.01);
    }
    Object? signedFailure;
    StackTrace? signedFailureStack;
    final canUseLegacy = _canUseLegacyFallback();

    if (SecureUploadConfig.enableSignedUploads) {
      try {
        return await _uploadBytesSigned(
          bytes: bytes,
          objectKey: objectKey,
          contentType: contentType,
          bucketName: bucketName,
          onProgress: onProgress,
        );
      } catch (e, st) {
        signedFailure = _wrapSignedFailure(
          e,
          stage: e is SecureUploadException
              ? e.stage
              : SecureUploadStage.uploadSigned,
          code: e is SecureUploadException ? e.code : 'SIGNED_UPLOAD_FAILED',
          userMessage: 'Upload via signed URL failed.',
        );
        signedFailureStack = st;
        logError(
          'Signed upload failed [mode=signed key=$objectKey bucket=${bucketName ?? "n/a"}]',
          error: signedFailure,
          stackTrace: st,
        );
        if (!canUseLegacy) {
          Error.throwWithStackTrace(signedFailure, st);
        }
      }
    }

    if (canUseLegacy) {
      try {
        if (bucketName == null || bucketName.isEmpty) {
          throw const SecureUploadException(
            userMessage: 'Legacy upload requires a bucket name.',
            stage: SecureUploadStage.uploadLegacy,
            code: 'LEGACY_BUCKET_MISSING',
          );
        }
        logInfo(
          'Using legacy public upload fallback [key=$objectKey bucket=$bucketName]',
        );
        return _legacyUploadBytes(
          bytes: bytes,
          objectKey: objectKey,
          contentType: contentType,
          bucket: bucketName,
          onProgress: onProgress,
        );
      } catch (legacyError, legacyStack) {
        logError(
          'Legacy upload fallback failed [mode=legacy stage=upload_legacy key=$objectKey]',
          error: legacyError,
          stackTrace: legacyStack,
        );
        if (signedFailure != null && signedFailureStack != null) {
          Error.throwWithStackTrace(signedFailure, signedFailureStack);
        }
        rethrow;
      }
    }

    if (signedFailure != null && signedFailureStack != null) {
      Error.throwWithStackTrace(signedFailure, signedFailureStack);
    }

    throw const SecureUploadException(
      userMessage: 'Upload is not configured for this build.',
      stage: SecureUploadStage.uploadLegacy,
      code: 'UPLOAD_NOT_CONFIGURED',
    );
  }

  static Future<UploadResult> uploadFile({
    required File file,
    required String objectKey,
    required String contentType,
    void Function(double progress)? onProgress,
    String? bucket,
  }) async {
    final bucketName = _tryResolveBucket(bucket);
    _logRuntimeModeOnce(bucketName: bucketName);
    if (onProgress != null) {
      onProgress(0.01);
    }
    Object? signedFailure;
    StackTrace? signedFailureStack;
    final canUseLegacy = _canUseLegacyFallback();

    if (SecureUploadConfig.enableSignedUploads) {
      try {
        return await _uploadFileSigned(
          file: file,
          objectKey: objectKey,
          contentType: contentType,
          bucketName: bucketName,
          onProgress: onProgress,
        );
      } catch (e, st) {
        signedFailure = _wrapSignedFailure(
          e,
          stage: e is SecureUploadException
              ? e.stage
              : SecureUploadStage.uploadSigned,
          code: e is SecureUploadException ? e.code : 'SIGNED_UPLOAD_FAILED',
          userMessage: 'Upload via signed URL failed.',
        );
        signedFailureStack = st;
        logError(
          'Signed file upload failed [mode=signed key=$objectKey bucket=${bucketName ?? "n/a"}]',
          error: signedFailure,
          stackTrace: st,
        );
        if (!canUseLegacy) {
          Error.throwWithStackTrace(signedFailure, st);
        }
      }
    }

    if (canUseLegacy) {
      try {
        if (bucketName == null || bucketName.isEmpty) {
          throw const SecureUploadException(
            userMessage: 'Legacy upload requires a bucket name.',
            stage: SecureUploadStage.uploadLegacy,
            code: 'LEGACY_BUCKET_MISSING',
          );
        }
        logInfo(
          'Using legacy public upload fallback [key=$objectKey bucket=$bucketName]',
        );
        // استفاده از stream به‌جای load کامل فایل به RAM
        final bytes = await file.readAsBytes();
        return _legacyUploadBytes(
          bytes: bytes,
          objectKey: objectKey,
          contentType: contentType,
          bucket: bucketName,
          onProgress: onProgress,
        );
      } catch (legacyError, legacyStack) {
        logError(
          'Legacy file upload fallback failed [mode=legacy stage=upload_legacy key=$objectKey]',
          error: legacyError,
          stackTrace: legacyStack,
        );
        if (signedFailure != null && signedFailureStack != null) {
          Error.throwWithStackTrace(signedFailure, signedFailureStack);
        }
        rethrow;
      }
    }

    if (signedFailure != null && signedFailureStack != null) {
      Error.throwWithStackTrace(signedFailure, signedFailureStack);
    }

    throw const SecureUploadException(
      userMessage: 'Upload is not configured for this build.',
      stage: SecureUploadStage.uploadLegacy,
      code: 'UPLOAD_NOT_CONFIGURED',
    );
  }

  static bool _canUseLegacyFallback() {
    if (!SecureUploadConfig.allowLegacyPublicUploads) {
      return false;
    }
    return SecureConfig.isConfigured;
  }

  static SecureUploadException _wrapSignedFailure(
    Object error, {
    required SecureUploadStage stage,
    required String code,
    required String userMessage,
  }) {
    if (error is SecureUploadException) {
      return error;
    }
    return SecureUploadException(
      userMessage: userMessage,
      stage: stage,
      code: code,
      cause: error,
    );
  }

  static Future<UploadResult> _uploadBytesSigned({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
    required String? bucketName,
    void Function(double progress)? onProgress,
  }) async {
    SignedUrlResponse signed;
    if (onProgress != null) {
      onProgress(0.05);
    }
    try {
      signed = await SignedUrlService.createUploadUrl(
        objectKey: objectKey,
        contentType: contentType,
        contentLength: bytes.length,
        bucket: bucketName,
      );
    } catch (e) {
      throw SecureUploadException(
        userMessage: 'Could not get signed upload URL.',
        stage: SecureUploadStage.sign,
        code: 'SIGNED_URL_REQUEST_FAILED',
        cause: e,
      );
    }

    if (onProgress != null) {
      onProgress(0.12);
    }

    try {
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
            final normalized = (sent / total).clamp(0.0, 1.0).toDouble();
            onProgress(0.12 + (normalized * 0.88));
          }
        },
      );
    } catch (e) {
      throw SecureUploadException(
        userMessage: 'Signed upload failed while uploading bytes.',
        stage: SecureUploadStage.uploadSigned,
        code: 'SIGNED_UPLOAD_FAILED',
        cause: e,
      );
    }

    final url = signed.fileUrl ??
        (bucketName != null ? _buildPublicUrl(bucketName, objectKey) : null);
    if (url == null || url.isEmpty) {
      throw const SecureUploadException(
        userMessage: 'Upload URL could not be resolved.',
        stage: SecureUploadStage.urlResolve,
        code: 'FILE_URL_MISSING',
      );
    }

    return UploadResult(
      url: url,
      objectKey: objectKey,
      isPublic: signed.isPublic,
    );
  }

  static Future<UploadResult> _uploadFileSigned({
    required File file,
    required String objectKey,
    required String contentType,
    required String? bucketName,
    void Function(double progress)? onProgress,
  }) async {
    SignedUrlResponse signed;
    final length = await file.length();
    if (onProgress != null) {
      onProgress(0.05);
    }

    try {
      signed = await SignedUrlService.createUploadUrl(
        objectKey: objectKey,
        contentType: contentType,
        contentLength: length,
        bucket: bucketName,
      );
    } catch (e) {
      throw SecureUploadException(
        userMessage: 'Could not get signed upload URL.',
        stage: SecureUploadStage.sign,
        code: 'SIGNED_URL_REQUEST_FAILED',
        cause: e,
      );
    }

    if (onProgress != null) {
      onProgress(0.12);
    }

    try {
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
            final normalized = (sent / total).clamp(0.0, 1.0).toDouble();
            onProgress(0.12 + (normalized * 0.88));
          }
        },
      );
    } catch (e) {
      throw SecureUploadException(
        userMessage: 'Signed upload failed while uploading file.',
        stage: SecureUploadStage.uploadSigned,
        code: 'SIGNED_UPLOAD_FAILED',
        cause: e,
      );
    }

    final url = signed.fileUrl ??
        (bucketName != null ? _buildPublicUrl(bucketName, objectKey) : null);
    if (url == null || url.isEmpty) {
      throw const SecureUploadException(
        userMessage: 'Upload URL could not be resolved.',
        stage: SecureUploadStage.urlResolve,
        code: 'FILE_URL_MISSING',
      );
    }

    return UploadResult(
      url: url,
      objectKey: objectKey,
      isPublic: signed.isPublic,
    );
  }

  static void _logRuntimeModeOnce({required String? bucketName}) {
    if (_modeLoggedOnce) return;
    _modeLoggedOnce = true;
    final secureConfigConfigured = SecureConfig.isConfigured;
    logInfo(
      'SecureUpload runtime mode: enableSignedUploads=${SecureUploadConfig.enableSignedUploads}, '
      'allowLegacyPublicUploads=${SecureUploadConfig.allowLegacyPublicUploads}, '
      'bucketResolved=${(bucketName ?? "").isNotEmpty}, '
      'secureConfigConfigured=$secureConfigConfigured',
    );
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
      throw const SecureUploadException(
        userMessage: 'Legacy upload credentials are missing.',
        stage: SecureUploadStage.uploadLegacy,
        code: 'LEGACY_CREDENTIALS_MISSING',
      );
    }

    final s3 = _buildS3Client();

    Timer? syntheticTimer;
    var syntheticProgress = 0.12;
    if (onProgress != null) {
      onProgress(syntheticProgress);
      // The legacy client does not expose byte-level callbacks.
      // Keep UI responsive with synthetic progress until request completes.
      syntheticTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
        syntheticProgress =
            (syntheticProgress + 0.02).clamp(0.12, 0.94).toDouble();
        onProgress(syntheticProgress);
      });
    }

    try {
      await s3.putObject(
        bucket: bucket,
        key: objectKey,
        body: bytes,
        contentType: contentType,
        acl: aws.ObjectCannedACL.publicRead, // legacy compatibility
      );
    } finally {
      syntheticTimer?.cancel();
    }

    if (onProgress != null) {
      onProgress(1.0);
    }

    return UploadResult(
      url: _buildPublicUrl(bucket, objectKey),
      objectKey: objectKey,
      isPublic: true,
    );
  }

  static aws.S3 _buildS3Client() {
    return aws.S3(
      region: SecureConfig.awsRegion,
      credentials: aws.AwsClientCredentials(
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
