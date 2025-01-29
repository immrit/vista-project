import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '/main.dart';

class StoryImageUploadService {
  static final s3 = S3(
    region: 'ir-thr-at1', // منطقه‌ی ذخیره‌سازی در آروان
    credentials: AwsClientCredentials(
      accessKey: '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf', // کلید دسترسی
      secretKey:
          'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5', // کلید مخفی
    ),
    endpointUrl:
        'https://coffevista.s3.ir-thr-at1.arvanstorage.ir', // آدرس endpoint
  );

  static const String bucketName = 'coffevista'; // نام سطل (Bucket)

  /// آپلود تصویر استوری به آروان کلود
  static Future<String?> uploadStoryImage(File file) async {
    File? compressedFile;
    try {
      // 1. بررسی وجود فایل
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      // 2. فشرده‌سازی تصویر (اختیاری)
      compressedFile = await compressImage(file);
      compressedFile ??= file;

      // 3. ایجاد مسیر ذخیره‌سازی برای استوری‌ها
      final userId = supabase.auth.currentUser!.id; // شناسه‌ی کاربر
      final timestamp = DateTime.now().millisecondsSinceEpoch; // زمان فعلی
      final fileName =
          'stories/$userId/${timestamp}_${path.basename(compressedFile.path)}'; // مسیر فایل

      // 4. خواندن فایل به صورت بایت
      final Uint8List fileBytes = await compressedFile.readAsBytes();
      const contentType = 'image/jpeg'; // نوع محتوا

      // 5. آپلود فایل به آروان کلود
      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead, // دسترسی عمومی به فایل
      );

      // 6. ایجاد لینک عمومی برای فایل آپلود شده
      final uploadedUrl = 'https://storage.coffevista.ir/$bucketName/$fileName';
      print('تصویر استوری با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود تصویر استوری: $e');
      throw Exception('آپلود تصویر استوری به شکست خورد');
    } finally {
      // 7. حذف فایل موقت (اگر وجود دارد)
      if (compressedFile != null && compressedFile.path != file.path) {
        try {
          await compressedFile.delete();
        } catch (e) {
          print('خطا در حذف فایل موقت: $e');
        }
      }
    }
  }

  /// فشرده‌سازی تصویر
  static Future<File?> compressImage(File file) async {
    try {
      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1080, // حداقل عرض تصویر
        minHeight: 1920, // حداقل ارتفاع تصویر
        quality: 85, // کیفیت تصویر (بین 0 تا 100)
        format: CompressFormat.jpeg, // فرمت خروجی
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
      print('خطا در فشرده‌سازی تصویر: $e');
      return null;
    }
  }

  /// حذف تصویر استوری از آروان کلود
  static Future<bool> deleteStoryImage(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key =
          uri.pathSegments.sublist(1).join('/'); // استخراج مسیر فایل از URL

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
}
