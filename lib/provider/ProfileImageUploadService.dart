import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../services/secure_config.dart';
import '../services/user_friendly_error_handler.dart';
import '/main.dart';

class ProfileImageUploadService {
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

  static String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    return extension == '.png' ? 'image/png' : 'image/jpeg';
  }

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

    print('فایل تبدیل شده در مسیر: ${convertedFile.path}');
    return convertedFile;
  }

  static Future<String?> uploadImage(File file) async {
    File? compressedFile;
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      final extension = path.extension(file.path).toLowerCase();
      print('نوع فایل ورودی: $extension');

      if (extension == '.png') {
        print('تبدیل فایل PNG به JPEG');
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) {
          throw Exception('تبدیل به JPEG شکست خورد');
        }
      } else {
        compressedFile = await compressImage(file);
        if (compressedFile == null) {
          print('فشرده‌سازی ناموفق بود، استفاده از فایل اصلی');
          compressedFile = file;
        }
      }

      final fileName =
          'avatars/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();

      // همیشه با نوع 'image/jpeg' پس از تبدیل کار می‌کنید
      const contentType = 'image/jpeg';
      print('Content-Type: $contentType');
      print('File size: ${fileBytes.length} bytes');

      await s3.putObject(
        bucket: bucketName,
        key: fileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
      print('تصویر با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'profile_image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'profile_image_upload'));
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
  static Future<String?> uploadImageWeb(
      Uint8List fileBytes, String fileName) async {
    try {
      // فقط پسوند فایل را بررسی می‌کنیم
      final extension = path.extension(fileName).toLowerCase();
      print('نوع فایل ورودی (وب): $extension');

      // همیشه با نوع 'image/jpeg' کار می‌کنیم
      const contentType = 'image/jpeg';

      final userId = supabase.auth.currentUser!.id;
      final s3FileName =
          'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      print('Content-Type: $contentType');
      print('File size: ${fileBytes.length} bytes');

      await s3.putObject(
        bucket: bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
      print('تصویر با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'profile_image_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'profile_image_upload'));
    }
  }

  static Future<bool> deleteImage(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      // اگر خطایی رخ نداد، یعنی عملیات موفق بوده
      return true;
    } catch (e) {
      print('خطا در حذف فایل: $e');
      return false;
    }
  }

  static Future<File?> compressImage(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();

      // اگر فایل PNG است، مستقیماً برگردانده شود
      if (extension == '.png') {
        print('فایل PNG شناسایی شد - بدون فشرده‌سازی');
        return file;
      }

      print('شروع فشرده‌سازی با فرمت: $extension');

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1024,
        minHeight: 1024,
        quality: 85,
        format: CompressFormat.jpeg, // همیشه به JPEG تبدیل می‌کنیم
      );

      if (img == null) {
        print('فشرده‌سازی ناموفق بود');
        return null;
      }

      final dir = path.dirname(file.path);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // همیشه با پسوند jpg ذخیره می‌کنیم
      final compressedFile = File('$dir/compressed_$timestamp.jpg')
        ..writeAsBytesSync(img);

      print('فایل فشرده شده در مسیر: ${compressedFile.path}');
      return compressedFile;
    } catch (e) {
      print('خطا در فشرده‌سازی تصویر: $e');
      return null;
    }
  }
}
