import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../security/logging_utility.dart';
import '../features/auth/providers/auth_controller.dart';
import 'device_id_service.dart';
import 'system_status_service.dart';

class BackendUploadResult {
  final String url;
  final String objectKey;
  final String bucket;

  const BackendUploadResult({
    required this.url,
    required this.objectKey,
    required this.bucket,
  });
}

class BackendUploadService {
  static String get _backendUrl =>
      EnvConfig.apiBaseUrl;

  static String get _bucketName =>
      'vista-bucket';

  static final Dio _api = Dio(BaseOptions(
    baseUrl: '$_backendUrl/v1',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'X-Device-ID': DeviceIdService.id,
    },
  ));

  static Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw 'User is not logged in';
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  static Future<BackendUploadResult> uploadBytes({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw 'فایل انتخاب شده خالی است';
    }
    if (objectKey.trim().isEmpty) {
      throw 'مسیر فایل نامعتبر است';
    }

    await SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.uploads,
      forceRefresh: true,
    );

    final presign = await _presign(
      objectKey: objectKey,
      contentType: contentType,
      fileSize: bytes.length,
    );
    logInfo('📦 PRESIGN RESP url=${presign['url']} object_url=${presign['object_url']} key=${presign['object_key']}');
    final uploadUrl = presign['url']?.toString() ?? '';
    if (uploadUrl.isEmpty) {
      throw 'لینک آپلود از سرور دریافت نشد';
    }

    final headers = _readHeaders(presign['headers']);
    headers['Content-Type'] = contentType;

    logInfo('UPLOAD URL: $uploadUrl');
    logInfo('UPLOAD HEADERS: $headers');

    // Plain Dio with default OS certificate validation. This is the object
    // storage host (not the pinned API host); the previous
    // badCertificateCallback => true accepted ANY TLS cert for user media
    // PUTs, opening the upload path to MITM.
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(minutes: 30),
      receiveTimeout: const Duration(minutes: 2),
    ));

    await dio.put(
      uploadUrl,
      data: bytes,
      options: Options(headers: headers),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress((sent / total).clamp(0.0, 1.0).toDouble());
        }
      },
    );

    return BackendUploadResult(
      url: presign['object_url']?.toString() ?? uploadUrl.split('?').first,
      objectKey: presign['object_key']?.toString() ?? objectKey,
      bucket: presign['bucket']?.toString() ?? _bucketName,
    );
  }

  static Future<BackendUploadResult> uploadFile({
    required File file,
    required String objectKey,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    if (!await file.exists()) {
      throw 'فایل انتخاب شده پیدا نشد';
    }
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      objectKey: objectKey,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  static Future<bool> deleteObject(String objectKey) async {
    if (objectKey.trim().isEmpty) return false;

    await SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.uploads,
      forceRefresh: true,
    );

    final response = await _api.post(
      '/uploads/delete',
      data: {'object_key': objectKey},
      options: await _authOptions(),
    );
    final data = response.data;
    return data is Map && data['success'] == true;
  }

  static Future<bool> deleteByUrl(String url) async {
    final objectKey = objectKeyFromUrl(url);
    if (objectKey == null || objectKey.isEmpty) return false;
    return deleteObject(objectKey);
  }

  static String? objectKeyFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;

    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(_bucketName);
    if (bucketIndex >= 0 && bucketIndex < segments.length - 1) {
      return segments.sublist(bucketIndex + 1).join('/');
    }

    final knownRoots = {
      'avatars',
      'posts',
      'stories',
      'chat',
      'music',
      'videos'
    };
    final rootIndex = segments.indexWhere(knownRoots.contains);
    if (rootIndex >= 0) {
      return segments.sublist(rootIndex).join('/');
    }

    return null;
  }

  static Future<Map<String, dynamic>> _presign({
    required String objectKey,
    required String contentType,
    required int fileSize,
  }) async {
    final response = await _api.post(
      '/uploads/presign',
      data: {
        'object_key': objectKey,
        'content_type': contentType,
        'file_size': fileSize,
      },
      options: await _authOptions(),
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Map<String, String> _readHeaders(Object? raw) {
    if (raw is! Map) return <String, String>{};
    return raw.map((key, value) => MapEntry(key.toString(), value.toString()));
  }
}
