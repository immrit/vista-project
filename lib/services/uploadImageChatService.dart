import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'cache_manager.dart';
import 'secure_config.dart';
import 'user_friendly_error_handler.dart';
import '/main.dart';

class ChatImageUploadService {
  // استفاده از همان تنظیمات S3 موجود در PostImageUploadService
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

  /// تبدیل تصاویر PNG به JPEG
  static Future<File?> convertPngToJpeg(File file) async {
    final img = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      format: CompressFormat.jpeg,
      quality: 85,
    );

    if (img == null) {
      print('تبدیل به JPEG ناموفق بود');
      return null;
    }

    final dir = path.dirname(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final convertedFile = File('$dir/converted_$timestamp.jpg')
      ..writeAsBytesSync(img);

    return convertedFile;
  }

  /// آپلود تصویر چت با پشتیبانی از پیشرفت آپلود (ساده)
  static Future<String?> uploadChatImage(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    File? compressedFile;
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      // بررسی حجم فایل - حداکثر 5MB برای تصاویر چت
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('حجم تصویر باید کمتر از ۵ مگابایت باشد');
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

      final fileName =
          'chats/$conversationId/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();
      const contentType = 'image/jpeg';

      // --- پشتیبانی از پیشرفت آپلود (شبیه‌سازی) ---
      if (onProgress != null) {
        onProgress(0.0);
        await s3.putObject(
          bucket: bucketName,
          key: fileName,
          body: fileBytes,
          contentType: contentType,
          acl: ObjectCannedACL.publicRead,
        );
        onProgress(1.0);
      } else {
        await s3.putObject(
          bucket: bucketName,
          key: fileName,
          body: fileBytes,
          contentType: contentType,
          acl: ObjectCannedACL.publicRead,
        );
      }

      // اطمینان از اینکه لینک خروجی معتبر و قابل استفاده است
      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
      print('تصویر چت با موفقیت آپلود شد: $uploadedUrl');

      // بررسی نهایی: اگر لینک خالی یا null بود، خطا بده
      if (uploadedUrl.isEmpty) {
        throw Exception('لینک آپلود تصویر خالی است!');
      }

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
          print('خطا در حذف فایل موقت: $e');
        }
      }
    }
  }

  // متد مخصوص آپلود تصویر چت در وب (بدون استفاده از File)
  static Future<String> uploadChatImageWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      print('Starting web image upload...');

      // بررسی حجم فایل - حداکثر 5MB برای تصاویر چت
      if (fileBytes.length > 5 * 1024 * 1024) {
        throw Exception('حجم تصویر باید کمتر از ۵ مگابایت باشد');
      }

      // حذف کاراکترهای غیرمجاز از نام فایل
      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');

      const contentType = 'image/jpeg';
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // ساخت نام فایل ساده‌تر و امن‌تر
      final s3FileName =
          'chats/$conversationId/${userId}_${timestamp}_$sanitizedFileName';

      print('Uploading to S3 with key: $s3FileName');

      try {
        await s3.putObject(
          bucket: bucketName,
          key: s3FileName,
          body: fileBytes,
          contentType: contentType,
          acl: ObjectCannedACL.publicRead,
          // تنظیمات CORS برای وب
        );

        final uploadedUrl =
            'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
        print('Web image upload successful: $uploadedUrl');

        return uploadedUrl;
      } catch (e) {
        UserFriendlyErrorHandler.logError(e, context: 'image_upload');
        throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'image_upload'));
      }
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'image_upload'));
    }
  }

  /// حذف تصویر چت
  static Future<bool> deleteChatImage(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      return true;
    } catch (e) {
      print('خطا در حذف تصویر چت: $e');
      return false;
    }
  }

  /// فشرده‌سازی تصویر
  static Future<File?> compressImage(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();

      if (extension == '.png') {
        return file;
      }

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        // تنظیم اندازه مناسب برای تصاویر چت‌ها - کوچکتر از تصاویر پست
        minWidth: 1280,
        minHeight: 720,
        quality: 80, // کیفیت کمی پایین‌تر از تصاویر پست
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
      print('خطا در فشرده‌سازی تصویر چت: $e');
      return null;
    }
  }

  /// ذخیره‌سازی تصاویر چت در کش
  static Future<void> precacheChatImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await CustomCacheManager.chatInstance.downloadFile(url);
    }
  }

  /// پاک کردن کش تصاویر چت
  static Future<void> clearChatCache() async {
    await CustomCacheManager.chatInstance.emptyCache();
  }
}
