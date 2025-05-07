import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:uuid/uuid.dart';
import '/main.dart';

class StoryImageUploadService {
  // تنظیمات S3 برای فضای ذخیره‌سازی آروان
  static final S3 s3 = S3(
    region: 'ir-thr-at1',
    credentials: AwsClientCredentials(
      accessKey: '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf',
      secretKey:
          'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5',
    ),
    endpointUrl: 'https://coffevista.s3.ir-thr-at1.arvanstorage.ir',
  );

  static const String bucketName = 'coffevista';
  static const String storageBaseUrl = 'https://storage.coffevista.ir';

  /// آپلود تصویر استوری (پشتیبانی از وب و موبایل)
  static Future<String?> uploadStoryImage(dynamic imageData) async {
    try {
      // بررسی اعتبار داده‌های ورودی
      if (imageData == null) {
        throw Exception('داده‌های تصویر وجود ندارد');
      }

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر احراز هویت نشده است');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uuid = const Uuid().v4();

      // مسیر ذخیره‌سازی فایل
      late String fileName;
      late Uint8List fileBytes;

      // پردازش بر اساس محیط اجرا (وب یا موبایل)
      if (kIsWeb) {
        if (imageData is! Uint8List) {
          throw Exception(
              'در محیط وب، داده‌های تصویر باید از نوع Uint8List باشد');
        }

        // در محیط وب، داده‌ها مستقیماً از نوع Uint8List هستند
        fileBytes = await _optimizeImageBytes(imageData);
        fileName = 'stories/$userId/${timestamp}_${uuid}_web.jpg';
      } else {
        if (imageData is! File) {
          throw Exception(
              'در محیط موبایل، داده‌های تصویر باید از نوع File باشد');
        }

        // بررسی وجود فایل
        if (!await imageData.exists()) {
          throw Exception('فایل تصویر موجود نیست');
        }

        // فشرده‌سازی تصویر در محیط موبایل
        final compressedFile = await _compressImageFile(imageData);
        fileBytes = await (compressedFile ?? imageData).readAsBytes();

        final originalName = path.basename(imageData.path);
        fileName = 'stories/$userId/${timestamp}_${uuid}_$originalName';

        // حذف فایل موقت در صورت وجود
        if (compressedFile != null && compressedFile.path != imageData.path) {
          _deleteFileAsync(compressedFile);
        }
      }

      // آپلود فایل به S3
      await _uploadToS3(fileName, fileBytes);

      // ایجاد آدرس عمومی فایل
      final uploadedUrl = '$storageBaseUrl/$bucketName/$fileName';
      print('تصویر استوری با موفقیت آپلود شد: $uploadedUrl');

      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر استوری: $e');
      return null;
    }
  }

  /// آپلود فایل به S3
  static Future<void> _uploadToS3(String key, Uint8List data) async {
    try {
      await s3.putObject(
        bucket: bucketName,
        key: key,
        body: data,
        contentType: 'image/jpeg',
        acl: ObjectCannedACL.publicRead,
      );
    } catch (e) {
      print('خطا در آپلود به S3: $e');
      throw Exception('خطا در آپلود به سرور: $e');
    }
  }

  /// بهینه‌سازی داده‌های تصویر (برای وب)
  static Future<Uint8List> _optimizeImageBytes(Uint8List bytes) async {
    try {
      // بررسی سایز فایل - اگر بزرگتر از ۱ مگابایت باشد، فشرده‌سازی می‌کنیم
      if (bytes.length > 1024 * 1024) {
        final result = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 1080,
          minWidth: 1080,
          quality: 85,
          format: CompressFormat.jpeg,
        );

        if (result != null && result.isNotEmpty) {
          print('تصویر فشرده شد: ${bytes.length} -> ${result.length} bytes');
          return result;
        }
      }

      return bytes; // برگرداندن بایت‌های اصلی در صورت عدم فشرده‌سازی
    } catch (e) {
      print('خطا در بهینه‌سازی تصویر: $e');
      return bytes; // در صورت خطا، داده‌های اصلی را برمی‌گردانیم
    }
  }

  /// فشرده‌سازی فایل تصویر (برای موبایل)
  static Future<File?> _compressImageFile(File file) async {
    try {
      final fileSize = await file.length();

      // اگر فایل کوچکتر از ۱ مگابایت باشد، نیازی به فشرده‌سازی نیست
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

      if (img == null) {
        return null;
      }

      final dir = path.dirname(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFile = File('$dir/compressed_$timestamp.jpg')
        ..writeAsBytesSync(img);

      print(
          'تصویر فشرده شد: ${fileSize} -> ${await compressedFile.length()} bytes');

      return compressedFile;
    } catch (e) {
      print('خطا در فشرده‌سازی تصویر: $e');
      return null;
    }
  }

  /// حذف فایل به صورت غیرهمزمان
  static void _deleteFileAsync(File file) {
    Future.microtask(() async {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print('خطا در حذف فایل موقت: $e');
      }
    });
  }

  /// حذف تصویر استوری از فضای ذخیره‌سازی
  static Future<bool> deleteStoryImage(String fileUrl) async {
    if (fileUrl.isEmpty) return false;

    try {
      final uri = Uri.parse(fileUrl);

      // استخراج مسیر فایل از URL
      if (uri.pathSegments.length <= 1) {
        throw Exception('آدرس فایل نامعتبر است');
      }

      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      print('تصویر استوری با موفقیت حذف شد: $fileUrl');
      return true;
    } catch (e) {
      print('خطا در حذف تصویر استوری: $e');
      return false;
    }
  }

  /// افزودن تصویر به مجموعه‌ای از تصاویر موجود
  static Future<List<String>> uploadMultipleStoryImages(
      List<dynamic> images) async {
    final List<String> uploadedUrls = [];

    for (final image in images) {
      try {
        final url = await uploadStoryImage(image);
        if (url != null) {
          uploadedUrls.add(url);
        }
      } catch (e) {
        print('خطا در آپلود یکی از تصاویر: $e');
        // ادامه با تصویر بعدی
      }
    }

    return uploadedUrls;
  }

  /// بررسی دسترسی به سرور
  static Future<bool> checkServerConnection() async {
    try {
      // تلاش برای دریافت لیست باکت‌ها برای بررسی اتصال
      await s3.headBucket(bucket: bucketName);
      return true;
    } catch (e) {
      print('خطا در اتصال به سرور: $e');
      return false;
    }
  }
}
