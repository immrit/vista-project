import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'cache_manager.dart';
import 'secure_config.dart';
import 'user_friendly_error_handler.dart';
import '../utils/const.dart';

class PostImageUploadService {
  static S3 get s3 {
    if (!SecureConfig.isConfigured) {
      throw Exception(
          'AWS credentials not properly configured. Please set environment variables.');
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

  static String get bucketName => SecureConfig.awsBucketName;

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

  static Future<String?> uploadPostImage(File file) async {
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
      final fileName =
          'posts/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();
      const contentType = 'image/jpeg';

      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
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
      Uint8List fileBytes, String fileName) async {
    try {
      // همیشه با نوع 'image/jpeg' کار می‌کنیم
      const contentType = 'image/jpeg';

      final userId = supabase.auth.currentUser!.id;
      final s3FileName =
          'posts/${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await s3.putObject(
        bucket: bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
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
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      return true;
    } catch (e) {
      logInfo('خطا در حذف تصویر پست: $e');
      return false;
    }
  }

  static Future<bool> deleteMusicFile(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      logInfo('فایل موسیقی با موفقیت از آروان حذف شد: $fileUrl');
      return true;
    } catch (e) {
      logInfo('خطا در حذف فایل موسیقی: $e');
      return false;
    }
  }

  static Future<bool> deleteVideoFile(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

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

  static Future<String> uploadMusicFile(File file) async {
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

      // ساخت نام منحصر به فرد برای فایل
      final fileName = 'music/${supabase.auth.currentUser!.id}'
          '_${DateTime.now().millisecondsSinceEpoch}$extension';

      // آپلود به آروان
      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: await file.readAsBytes(),
        contentType: _getAudioContentType(extension),
        acl: ObjectCannedACL.publicRead,
        metadata: {'originalName': path.basename(file.path)},
      );

      final url = 'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
      print("Uploaded music file URL: $url"); // اضافه کردن این خط

      // تست دسترسی به فایل
      final response = await http.head(Uri.parse(url));
      print(
          "File access test status code: ${response.statusCode}"); // اضافه کردن این خط

      return url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'audio_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'audio_upload'));
    }
  }

  static bool _isValidAudioFormat(String extension) {
    return ['.mp3', '.m4a'].contains(extension);
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

  static Future<String?> uploadVideoFile(File file) async {
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
      final fileName = 'videos/${supabase.auth.currentUser!.id}'
          '_${DateTime.now().millisecondsSinceEpoch}$extension';

      // آپلود به آروان
      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: await file.readAsBytes(),
        contentType: _getVideoContentType(extension),
        acl: ObjectCannedACL.publicRead,
        metadata: {'originalName': path.basename(file.path)},
      );

      final url = 'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
      print("Uploaded video file URL: $url");

      // تست دسترسی به فایل
      final response = await http.head(Uri.parse(url));
      print("File access test status code: ${response.statusCode}");

      return url;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'video_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'video_upload'));
    }
  }

  static Future<String?> uploadVideoFileWeb(
      Uint8List fileBytes, String fileName) async {
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
      final s3FileName = 'videos/${supabase.auth.currentUser!.id}'
          '_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // آپلود به آروان
      await s3.putObject(
        bucket: bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: _getVideoContentType(extension),
        acl: ObjectCannedACL.publicRead,
      );

      final url = 'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
      print("Uploaded video file URL: $url");

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
}
