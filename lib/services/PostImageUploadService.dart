import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'cache_manager.dart';
import 'user_friendly_error_handler.dart';
import 'backend_upload_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/providers/auth_controller.dart';

class PostImageUploadService {
  static Future<File?> convertPngToJpeg(File file) async {
    final img = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      format: CompressFormat.jpeg,
      quality: 85,
    );

    if (img == null) {
      logInfo('تبدیل به JPEG ناموفق بود');
      return null;
    }

    final dir = path.dirname(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final convertedFile = File('$dir/converted_$timestamp.jpg')
      ..writeAsBytesSync(img);

    return convertedFile;
  }

  static Future<String?> uploadPostImage(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    File? compressedFile;
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      final extension = path.extension(file.path).toLowerCase();

      if (extension == '.png') {
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) {
          throw Exception('تبدیل به JPEG شکست خورد');
        }
      } else {
        compressedFile = await compressImage(file);
        compressedFile ??= file;
      }

      // مسیر ذخیره‌سازی برای تصاویر پست‌ها
      final userId = await _currentUserId();
      final fileName =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();
      const contentType = 'image/jpeg';

      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: contentType,
        onProgress: onProgress,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('تصویر پست با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'image_upload'));
    } finally {
      if (compressedFile != null && compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          logInfo('خطا در حذف فایل موقت: $e');
        }
      }
    }
  }

  // متد مخصوص آپلود تصویر در وب (بدون استفاده از File)
  static Future<String?> uploadPostImageWeb(
    Uint8List fileBytes,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // همیشه با نوع 'image/jpeg' کار می‌کنیم
      const contentType = 'image/jpeg';

      final userId = await _currentUserId();
      final s3FileName =
          'posts/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: contentType,
        onProgress: onProgress,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('تصویر پست با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'image_upload'));
    }
  }

  static Future<bool> deletePostImage(String fileUrl) async {
    try {
      final deleted = await BackendUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      return true;
    } catch (e) {
      logInfo('خطا در حذف تصویر پست: $e');
      return false;
    }
  }

  static Future<bool> deleteMusicFile(String fileUrl) async {
    try {
      final deleted = await BackendUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      logInfo('فایل موسیقی با موفقیت از آروان حذف شد: $fileUrl');
      return true;
    } catch (e) {
      logInfo('خطا در حذف فایل موسیقی: $e');
      return false;
    }
  }

  static Future<bool> deleteVideoFile(String fileUrl) async {
    try {
      final deleted = await BackendUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      logInfo('فایل ویدیو با موفقیت از آروان حذف شد: $fileUrl');
      return true;
    } catch (e) {
      logInfo('خطا در حذف فایل ویدیو: $e');
      return false;
    }
  }

  static Future<bool> deleteMediaFile(String fileUrl) async {
    try {
      // بررسی نوع فایل بر اساس URL یا extension
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');
      final extension = path.extension(key).toLowerCase();

      // اگر پسوند فایل مشخص نباشد، از URL برای تشخیص نوع استفاده می‌کنیم
      if (fileUrl.contains('music/') ||
          extension == '.mp3' ||
          extension == '.m4a') {
        return await deleteMusicFile(fileUrl);
      } else if (fileUrl.contains('videos/') ||
          extension == '.mp4' ||
          extension == '.mov' ||
          extension == '.mkv') {
        return await deleteVideoFile(fileUrl);
      } else {
        // برای تصاویر پست یا فایل‌های نامشخص، از متد حذف تصویر استفاده می‌کنیم
        return await deletePostImage(fileUrl);
      }
    } catch (e) {
      logInfo('خطا در حذف فایل رسانه: $e');
      return false;
    }
  }

  static Future<File?> compressImage(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();

      if (extension == '.png') {
        return file;
      }

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        // تنظیم اندازه مناسب برای تصاویر پست‌ها
        minWidth: 1920,
        minHeight: 1080,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (img == null) {
        return null;
      }

      final dir = path.dirname(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('$dir/compressed_$timestamp.jpg')
        ..writeAsBytesSync(img);

      return compressedFile;
    } catch (e) {
      logInfo('خطا در فشرده‌سازی تصویر پست: $e');
      return null;
    }
  }

  static Future<void> precacheStoryImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.storyInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  static Future<void> clearOldCache() async {
    final cacheManager = await CustomCacheManager.storyInstance;
    await cacheManager.emptyCache();
  }

  static Future<void> precachePostImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.postInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  static Future<void> clearCache() async {
    final postCache = await CustomCacheManager.postInstance;
    final storyCache = await CustomCacheManager.storyInstance;
    await postCache.emptyCache();
    await storyCache.emptyCache();
  }

  static Future<void> removeOldCache() async {
    final postCache = await CustomCacheManager.postInstance;
    final storyCache = await CustomCacheManager.storyInstance;
    await postCache.emptyCache();
    await storyCache.emptyCache();
  }

  static Future<String> uploadMusicFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // بررسی سایز فایل
      final fileSize = await file.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        throw Exception('حجم فایل باید کمتر از 10 مگابایت باشد');
      }

      // بررسی فرمت فایل
      final extension = path.extension(file.path).toLowerCase();
      if (!_isValidAudioFormat(extension)) {
        throw Exception('فقط فایل‌های mp3 و m4a پشتیبانی می‌شوند');
      }

      final originalBaseName = path.basenameWithoutExtension(file.path);
      final safeBaseName = _sanitizeMusicFileName(originalBaseName);
      final userId = await _currentUserId();
      final fileName =
          'music/$userId/${DateTime.now().millisecondsSinceEpoch}_$safeBaseName$extension';
      final uploadResult = await BackendUploadService.uploadFile(
        file: file,
        objectKey: fileName,
        contentType: _getAudioContentType(extension),
        onProgress: onProgress,
      );

      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'audio_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload'));
    }
  }

  static bool _isValidAudioFormat(String extension) {
    return ['.mp3', '.m4a'].contains(extension);
  }

  static String _sanitizeMusicFileName(String input) {
    var output = input.trim();
    if (output.isEmpty) return 'track';

    output = output.replaceAll(RegExp(r'[^\w\-\s]'), '');
    output = output.replaceAll(RegExp(r'\s+'), '_');
    output = output.replaceAll(RegExp(r'_+'), '_');
    output = output.replaceAll(RegExp(r'^_+|_+$'), '');

    if (output.isEmpty) return 'track';
    if (output.length > 64) {
      output = output.substring(0, 64);
      output = output.replaceAll(RegExp(r'_+$'), '');
    }
    return output.toLowerCase();
  }

  static String _getAudioContentType(String extension) {
    switch (extension) {
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      default:
        return 'audio/mpeg';
    }
  }

  static Future<String?> uploadVideoFile(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      // بررسی سایز فایل (حداکثر ۱۰ مگابایت)
      final fileSize = await file.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        throw Exception('حجم فایل باید کمتر از ۱۰ مگابایت باشد');
      }

      // بررسی فرمت فایل
      final extension = path.extension(file.path).toLowerCase();
      if (!_isValidVideoFormat(extension)) {
        throw Exception('فقط فایل‌های mp4، mov و mkv پشتیبانی می‌شوند');
      }

      // ساخت نام منحصر به فرد برای فایل
      final userId = await _currentUserId();
      final fileName =
          'videos/$userId/${DateTime.now().millisecondsSinceEpoch}$extension';
      final uploadResult = await BackendUploadService.uploadFile(
        file: file,
        objectKey: fileName,
        contentType: _getVideoContentType(extension),
        onProgress: onProgress,
      );

      return uploadResult.url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'video_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'video_upload'));
    }
  }

  static Future<String?> uploadVideoFileWeb(
    Uint8List fileBytes,
    String fileName, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final extension = path.extension(fileName).toLowerCase();
      if (!_isValidVideoFormat(extension)) {
        throw Exception('فقط فایل‌های mp4، mov و mkv پشتیبانی می‌شوند');
      }

      // بررسی سایز فایل (حداکثر ۱۰ مگابایت)
      if (fileBytes.length > 10 * 1024 * 1024) {
        throw Exception('حجم فایل باید کمتر از ۱۰ مگابایت باشد');
      }

      // ساخت نام منحصر به فرد برای فایل
      final userId = await _currentUserId();
      final s3FileName =
          'videos/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // آپلود به آروان
      final uploadResult = await BackendUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: _getVideoContentType(extension),
        onProgress: onProgress,
      );

      final url = uploadResult.url;
      return url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'video_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'video_upload'));
    }
  }

  static bool _isValidVideoFormat(String extension) {
    return ['.mp4', '.mov', '.mkv'].contains(extension);
  }

  static String _getVideoContentType(String extension) {
    switch (extension) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4';
    }
  }

  static Future<String> _currentUserId() async {
    final storedUserId = await TokenStorage.getUserId();
    if (storedUserId != null && storedUserId.isNotEmpty) {
      return storedUserId;
    }

    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Ú©Ø§Ø±Ø¨Ø± ÙˆØ§Ø±Ø¯ Ù†Ø´Ø¯Ù‡ Ø§Ø³Øª');
    }

    final user = await AuthRepository().me(accessToken);
    await TokenStorage.saveUserId(user.id);
    return user.id;
  }
}
