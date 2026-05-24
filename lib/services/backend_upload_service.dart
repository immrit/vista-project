import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../security/logging_utility.dart';
import '../features/auth/providers/auth_controller.dart';

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
      dotenv.env['BACKEND_URL'] ?? 'http://10.0.2.2:8080';

  static String get _bucketName =>
      dotenv.env['ARVAN_BUCKET'] ??
      dotenv.env['ARVAN_BUCKET_NAME'] ??
      'coffevista';

  static final Dio _api = Dio(BaseOptions(
    baseUrl: '$_backendUrl/v1',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
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

    final presign = await _presign(
      objectKey: objectKey,
      contentType: contentType,
    );
    final uploadUrl = presign['url']?.toString() ?? '';
    if (uploadUrl.isEmpty) {
      throw 'لینک آپلود از سرور دریافت نشد';
    }

    final headers = _readHeaders(presign['headers']);
    headers['Content-Type'] = contentType;

    logInfo('UPLOAD URL: $uploadUrl');
    logInfo('UPLOAD HEADERS: $headers');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(minutes: 5),
      receiveTimeout: const Duration(seconds: 30),
    ));

    if (!kIsWeb) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        },
      );
    }

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
  }) async {
    final response = await _api.post(
      '/uploads/presign',
      data: {
        'object_key': objectKey,
        'content_type': contentType,
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
