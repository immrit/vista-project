import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../../../../features/auth/providers/auth_controller.dart';
import '../../../../services/backend_upload_service.dart';
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
  static const _uuid = Uuid();

  /// آپلود رسانه استوری (تصویر یا ویدیو)
  static Future<StoryMediaUploadResult?> uploadMedia({
    required dynamic mediaFile,
    required StoryMediaType type,
    Function(double progress)? onProgress,
  }) async {
    try {
      final userId = await TokenStorage.getUserId();
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

        final imageSizeMb = (await imageData.length()) / (1024 * 1024);
        if (imageSizeMb > StoryConstants.maxImageSizeMB) {
          throw Exception(
              'حجم تصویر بیش از حد مجاز است (حداکثر ${StoryConstants.maxImageSizeMB} مگابایت)');
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

      final uploadResult = await _uploadToS3(fileName, fileBytes, 'image/jpeg');
      final uploadedUrl = uploadResult.url;

      onProgress?.call(1.0);

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

      // Enforce the declared story limits BEFORE compressing/uploading, so a
      // huge or too-long clip fails fast with a clear message instead of after
      // the whole compress+upload cost. (StoryConstants were previously
      // unenforced.)
      final videoSizeMb = (await videoData.length()) / (1024 * 1024);
      if (videoSizeMb > StoryConstants.maxVideoSizeMB) {
        throw Exception(
            'حجم ویدیو بیش از حد مجاز است (حداکثر ${StoryConstants.maxVideoSizeMB} مگابایت)');
      }
      final probe = await VideoCompress.getMediaInfo(videoData.path);
      final durationSec = (probe.duration ?? 0) / 1000;
      if (durationSec > StoryConstants.maxVideoLengthSeconds) {
        throw Exception(
            'مدت ویدیو بیش از حد مجاز است (حداکثر ${StoryConstants.maxVideoLengthSeconds} ثانیه)');
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
      final videoFileName = 'stories/$userId/${timestamp}_${uuid}_video.mp4';
      final videoUpload = await BackendUploadService.uploadFile(
        file: compressedInfo.file!,
        objectKey: videoFileName,
        contentType: 'video/mp4',
      );
      final videoUrl = videoUpload.url;

      onProgress?.call(0.8);

      // آپلود thumbnail
      String? thumbnailUrl;
      if (thumbnailFile.existsSync()) {
        final thumbnailBytes = await thumbnailFile.readAsBytes();
        final thumbnailFileName =
            'stories/$userId/${timestamp}_${uuid}_thumb.jpg';
        final thumbnailUpload =
            await _uploadToS3(thumbnailFileName, thumbnailBytes, 'image/jpeg');
        thumbnailUrl = thumbnailUpload.url;

        _deleteFileAsync(thumbnailFile);
      }

      onProgress?.call(1.0);

      // پاکسازی
      _deleteFileAsync(compressedInfo.file!);
      await VideoCompress.deleteAllCache();

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

  /// Upload media using secure uploads
  static Future<BackendUploadResult> _uploadToS3(
      String key, Uint8List data, String contentType) async {
    return BackendUploadService.uploadBytes(
      bytes: data,
      objectKey: key,
      contentType: contentType,
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
        minWidth: 1440,
        minHeight: 2560,
        quality: 90,
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
  /// حذف رسانه از storage
  static Future<bool> deleteMedia(String fileUrl) async {
    if (fileUrl.isEmpty) return false;

    try {
      final deleted = await BackendUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      logInfo('رسانه استوری حذف شد: $fileUrl');
      return true;
    } catch (e) {
      logInfo('خطا در حذف رسانه: $e');
      return false;
    }
  }
}
