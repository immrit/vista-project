import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'cache_manager.dart';
import '/main.dart';

class PostImageUploadService {
  static final s3 = S3(
    region: 'ir-thr-at1',
    credentials: AwsClientCredentials(
        accessKey: '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf',
        secretKey:
            'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5'),
    endpointUrl: 'https://coffevista.s3.ir-thr-at1.arvanstorage.ir',
  );

  static const String bucketName = 'coffevista';

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

      final uploadedUrl = 'https://storage.coffevista.ir/$bucketName/$fileName';
      print('تصویر پست با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر پست: $e');
      throw Exception('آپلود تصویر پست به شکست خورد');
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
          'https://storage.coffevista.ir/$bucketName/$s3FileName';
      print('تصویر پست با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر پست (وب): $e');
      throw Exception('آپلود تصویر پست به شکست خورد');
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
      print('خطا در حذف تصویر پست: $e');
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
      print('خطا در فشرده‌سازی تصویر پست: $e');
      return null;
    }
  }

  static Future<void> precacheStoryImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await CustomCacheManager.storyInstance.downloadFile(url);
    }
  }

  static Future<void> clearOldCache() async {
    await CustomCacheManager.storyInstance.emptyCache();
  }

  static Future<void> precachePostImages(List<String> imageUrls) async {
    for (final url in imageUrls) {
      await CustomCacheManager.postInstance.downloadFile(url);
    }
  }

  static Future<void> clearCache() async {
    await CustomCacheManager.postInstance.emptyCache();
    await CustomCacheManager.storyInstance.emptyCache();
  }

  static Future<void> removeOldCache() async {
    await CustomCacheManager.postInstance.emptyCache();
    await CustomCacheManager.storyInstance.emptyCache();
  }

  static Future<String> uploadMusicFile(File file) async {
    try {
      // بررسی سایز فایل
      final fileSize = await file.length();
      final maxSize = 13 * 1024 * 1024; // 10MB
      if (fileSize > maxSize) {
        throw Exception('حجم فایل موزیک باید کمتر از 10 مگابایت باشد');
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

      final url = 'https://storage.coffevista.ir/$bucketName/$fileName';
      print("Uploaded music file URL: $url"); // اضافه کردن این خط

      // تست دسترسی به فایل
      final response = await http.head(Uri.parse(url));
      print(
          "File access test status code: ${response.statusCode}"); // اضافه کردن این خط

      return url;
    } catch (e) {
      print("Music upload error: $e"); // اضافه کردن این خط
      rethrow; // انتشار خطا برای مدیریت در AddPublicPostScreen
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
}
