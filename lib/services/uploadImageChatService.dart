import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'cache_manager.dart';
import '/main.dart';

class ChatImageUploadService {
  // استفاده از همان تنظیمات S3 موجود در PostImageUploadService
  static final s3 = S3(
    region: 'ir-thr-at1',
    credentials: AwsClientCredentials(
        accessKey: '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf',
        secretKey:
            'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5'),
    endpointUrl: 'https://coffevista.s3.ir-thr-at1.arvanstorage.ir',
  );

  static const String bucketName = 'coffevista';

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
      final uploadedUrl = 'https://storage.coffevista.ir/$bucketName/$fileName';
      print('تصویر چت با موفقیت آپلود شد: $uploadedUrl');

      // بررسی نهایی: اگر لینک خالی یا null بود، خطا بده
      if (uploadedUrl.isEmpty) {
        throw Exception('لینک آپلود تصویر خالی است!');
      }

      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر چت: $e');
      throw Exception('آپلود تصویر چت شکست خورد: $e');
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
  static Future<String?> uploadChatImageWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      const contentType = 'image/jpeg';

      final userId = supabase.auth.currentUser!.id;
      final s3FileName =
          'chats/$conversationId/${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      await s3.putObject(
        bucket: bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.coffevista.ir/$bucketName/$s3FileName';
      print('تصویر چت با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر چت (وب): $e');
      throw Exception('آپلود تصویر چت شکست خورد: $e');
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
