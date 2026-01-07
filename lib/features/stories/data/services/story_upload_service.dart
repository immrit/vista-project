import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:uuid/uuid.dart';

import '../../../../services/secure_config.dart';
import '../../../../utils/const.dart';
import '../../../../security/logging_utility.dart';
import '../../core/story_enums.dart';

/// پارامترهای نتیجه آپلود
class StoryMediaUploadResult {
  final String url;
  final String? thumbnailUrl;
  final StoryMediaType type;
  final int? durationSeconds;

  const StoryMediaUploadResult({
    required this.url,
    this.thumbnailUrl,
    required this.type,
    this.durationSeconds,
  });
}

/// سرویس آپلود رسانه استوری (تصویر + ویدیو)
class StoryUploadService {
  static const String _storageBaseUrl = 'https://storage.389346.ir.cdn.ir';
  static const _uuid = Uuid();

  static S3 get _s3 {
    if (!SecureConfig.isConfigured) {
      throw Exception('AWS credentials not configured');
    }
    return S3(
      region: SecureConfig.awsRegion,
      credentials: AwsClientCredentials(
        accessKey: SecureConfig.awsAccessKey,
        secretKey: SecureConfig.awsSecretKey,
      ),
      endpointUrl: SecureConfig.awsEndpointUrl,
    );
  }

  static String get _bucketName => SecureConfig.awsBucketName;

  /// آپلود رسانه استوری (تصویر یا ویدیو)
  static Future<StoryMediaUploadResult?> uploadMedia({
    required dynamic mediaFile,
    required StoryMediaType type,
    Function(double progress)? onProgress,
  }) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر احراز هویت نشده است');
      }

      if (type == StoryMediaType.video) {
        return await _uploadVideo(mediaFile, userId, onProgress);
      } else {
        return await _uploadImage(mediaFile, userId, onProgress);
      }
    } catch (e) {
      logInfo('خطا در آپلود رسانه استوری: $e');
      return null;
    }
  }

  /// آپلود تصویر
  static Future<StoryMediaUploadResult?> _uploadImage(
    dynamic imageData,
    String userId,
    Function(double)? onProgress,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = _uuid.v4();

      late String fileName;
      late Uint8List fileBytes;

      if (kIsWeb) {
        if (imageData is! Uint8List) {
          throw Exception('در محیط وب، داده‌های تصویر باید Uint8List باشد');
        }
        fileBytes = await _optimizeImageBytes(imageData);
        fileName = 'stories/$userId/${timestamp}_${uuid}_web.jpg';
      } else {
        if (imageData is! File) {
          throw Exception('در محیط موبایل، داده‌های تصویر باید File باشد');
        }
        if (!await imageData.exists()) {
          throw Exception('فایل تصویر موجود نیست');
        }

        final compressedFile = await _compressImageFile(imageData);
        fileBytes = await (compressedFile ?? imageData).readAsBytes();

        final originalName = path.basename(imageData.path);
        fileName = 'stories/$userId/${timestamp}_${uuid}_$originalName';

        // حذف فایل موقت
        if (compressedFile != null && compressedFile.path != imageData.path) {
          _deleteFileAsync(compressedFile);
        }
      }

      onProgress?.call(0.5);

      await _uploadToS3(fileName, fileBytes, 'image/jpeg');

      onProgress?.call(1.0);

      final uploadedUrl = '$_storageBaseUrl/$_bucketName/$fileName';
      logInfo('تصویر استوری آپلود شد: $uploadedUrl');

      return StoryMediaUploadResult(
        url: uploadedUrl,
        type: StoryMediaType.image,
      );
    } catch (e) {
      logInfo('خطا در آپلود تصویر: $e');
      return null;
    }
  }

  /// آپلود ویدیو
  static Future<StoryMediaUploadResult?> _uploadVideo(
    dynamic videoData,
    String userId,
    Function(double)? onProgress,
  ) async {
    try {
      if (kIsWeb) {
        throw Exception('آپلود ویدیو در وب پشتیبانی نمی‌شود');
      }

      if (videoData is! File) {
        throw Exception('داده‌های ویدیو باید File باشد');
      }

      if (!await videoData.exists()) {
        throw Exception('فایل ویدیو موجود نیست');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = _uuid.v4();

      onProgress?.call(0.1);

      // فشرده‌سازی ویدیو
      final MediaInfo? compressedInfo = await VideoCompress.compressVideo(
        videoData.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (compressedInfo == null || compressedInfo.file == null) {
        throw Exception('خطا در فشرده‌سازی ویدیو');
      }

      onProgress?.call(0.4);

      // ایجاد thumbnail
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoData.path,
        quality: 75,
        position: -1,
      );

      onProgress?.call(0.5);

      // آپلود ویدیو
      final videoBytes = await compressedInfo.file!.readAsBytes();
      final videoFileName = 'stories/$userId/${timestamp}_${uuid}_video.mp4';
      await _uploadToS3(videoFileName, videoBytes, 'video/mp4');

      onProgress?.call(0.8);

      // آپلود thumbnail
      String? thumbnailUrl;
      if (thumbnailFile.existsSync()) {
        final thumbnailBytes = await thumbnailFile.readAsBytes();
        final thumbnailFileName =
            'stories/$userId/${timestamp}_${uuid}_thumb.jpg';
        await _uploadToS3(thumbnailFileName, thumbnailBytes, 'image/jpeg');
        thumbnailUrl = '$_storageBaseUrl/$_bucketName/$thumbnailFileName';

        _deleteFileAsync(thumbnailFile);
      }

      onProgress?.call(1.0);

      // پاکسازی
      _deleteFileAsync(compressedInfo.file!);
      await VideoCompress.deleteAllCache();

      final videoUrl = '$_storageBaseUrl/$_bucketName/$videoFileName';
      final durationSeconds = (compressedInfo.duration ?? 0) ~/ 1000;

      logInfo('ویدیو استوری آپلود شد: $videoUrl');

      return StoryMediaUploadResult(
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        type: StoryMediaType.video,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      logInfo('خطا در آپلود ویدیو: $e');
      await VideoCompress.deleteAllCache();
      return null;
    }
  }

  /// آپلود به S3
  static Future<void> _uploadToS3(
      String key, Uint8List data, String contentType) async {
    await _s3.putObject(
      bucket: _bucketName,
      key: key,
      body: data,
      contentType: contentType,
      acl: ObjectCannedACL.publicRead,
    );
  }

  /// بهینه‌سازی بایت‌های تصویر
  static Future<Uint8List> _optimizeImageBytes(Uint8List bytes) async {
    try {
      if (bytes.length > 1024 * 1024) {
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1920,
          minWidth: 1080,
          quality: 85,
          format: CompressFormat.jpeg,
        );
        if (result.isNotEmpty) {
          logInfo('تصویر فشرده شد: ${bytes.length} -> ${result.length} bytes');
          return result;
        }
      }
      return bytes;
    } catch (e) {
      logInfo('خطا در بهینه‌سازی تصویر: $e');
      return bytes;
    }
  }

  /// فشرده‌سازی فایل تصویر
  static Future<File?> _compressImageFile(File file) async {
    try {
      final fileSize = await file.length();

      if (fileSize < 1024 * 1024) {
        return null;
      }

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1080,
        minHeight: 1920,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (img == null) return null;

      final dir = path.dirname(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('$dir/compressed_$timestamp.jpg')
        ..writeAsBytesSync(img);

      logInfo(
          'تصویر فشرده شد: $fileSize -> ${await compressedFile.length()} bytes');

      return compressedFile;
    } catch (e) {
      logInfo('خطا در فشرده‌سازی تصویر: $e');
      return null;
    }
  }

  /// حذف فایل موقت
  static void _deleteFileAsync(File file) {
    Future.microtask(() async {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        logInfo('خطا در حذف فایل موقت: $e');
      }
    });
  }

  /// حذف رسانه از S3
  static Future<bool> deleteMedia(String fileUrl) async {
    if (fileUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(fileUrl);
      if (uri.pathSegments.length <= 1) {
        throw Exception('آدرس فایل نامعتبر است');
      }

      final key = uri.pathSegments.sublist(1).join('/');

      await _s3.deleteObject(
        bucket: _bucketName,
        key: key,
      );

      logInfo('رسانه استوری حذف شد: $fileUrl');
      return true;
    } catch (e) {
      logInfo('خطا در حذف رسانه: $e');
      return false;
    }
  }
}
