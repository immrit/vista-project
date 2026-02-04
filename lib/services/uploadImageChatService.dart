import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'cache_manager.dart';
import 'secure_upload_service.dart';
import 'user_friendly_error_handler.dart';
import '../utils/const.dart';

class ChatImageUploadService {

  /// تبدیل تصاویر PNG به JPEG
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

  /// آپلود تصویر چت با پشتیبانی از پیشرفت آپلود (ساده)
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

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final fileName =
          'chats/$conversationId/${userId}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();
      const contentType = 'image/jpeg';

      if (onProgress != null) {
        onProgress(0.0);
      }

      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: contentType,
        onProgress: onProgress,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('Chat image upload successful: $uploadedUrl');
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

  /// حذف تصویر چت
  /// حذف تصویر چت
  static Future<bool> deleteChatImage(String fileUrl) async {
    try {
      final deleted = await SecureUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      return true;
    } catch (e) {
      logInfo('خطا در حذف تصویر چت: $e');
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
      logInfo('خطا در فشرده‌سازی تصویر چت: $e');
      return null;
    }
  }

  /// ذخیره‌سازی تصاویر چت در کش
  static Future<void> precacheChatImages(List<String> imageUrls) async {
    final cacheManager = await CustomCacheManager.chatInstance;
    for (final url in imageUrls) {
      await cacheManager.downloadFile(url);
    }
  }

  /// پاک کردن کش تصاویر چت
  static Future<void> clearChatCache() async {
    final cacheManager = await CustomCacheManager.chatInstance;
    await cacheManager.emptyCache();
  }
}


