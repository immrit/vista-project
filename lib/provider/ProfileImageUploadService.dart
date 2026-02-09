import '../security/logging_utility.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import '../services/secure_upload_service.dart';
import '../services/user_friendly_error_handler.dart';
import '../utils/const.dart';

class ProfileImageUploadService {

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
      logInfo('تبدیل به JPEG ناموفق بود');
      return null;
    }

    final dir = path.dirname(file.path);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final convertedFile = File('$dir/converted_$timestamp.jpg')
      ..writeAsBytesSync(img);

    logInfo('فایل تبدیل شده در مسیر: ${convertedFile.path}');
    return convertedFile;
  }

  static Future<File?> compressImage(File file) async {
    try {
      final extension = path.extension(file.path).toLowerCase();
      if (extension == '.png') {
        return file;
      }

      final img = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1080,
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
      logInfo('خطا در فشرده‌سازی تصویر پروفایل: $e');
      return null;
    }
  }

  static Future<String?> uploadImage(File file) async {
    File? compressedFile;
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      final extension = path.extension(file.path).toLowerCase();
      logInfo('نوع فایل ورودی: $extension');

      if (extension == '.png') {
        logInfo('تبدیل فایل PNG به JPEG');
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) {
          throw Exception('تبدیل به JPEG شکست خورد');
        }
      } else {
        compressedFile = await compressImage(file);
        if (compressedFile == null) {
          logInfo('فشرده‌سازی ناموفق بود، استفاده از فایل اصلی');
          compressedFile = file;
        }
      }

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('کاربر وارد نشده است');
      }

      final fileName =
          'avatars/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();

      const contentType = 'image/jpeg';
      logInfo('Content-Type: $contentType');
      logInfo('File size: ${fileBytes.length} bytes');
      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: contentType,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('تصویر با موفقیت آپلود شد: $uploadedUrl');
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
          logInfo('خطا در حذف فایل موقت: $e');
        }
      }
    }
  }

  // متد مخصوص آپلود تصویر در وب (بدون استفاده از File)
  static Future<String?> uploadImageForRegistration(
      File file, String userId) async {
    File? compressedFile;
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      final extension = path.extension(file.path).toLowerCase();
      logInfo('نوع فایل ورودی: $extension');

      if (extension == '.png') {
        logInfo('تبدیل فایل PNG به JPEG');
        compressedFile = await convertPngToJpeg(file);
        if (compressedFile == null) {
          throw Exception('تبدیل به JPEG شکست خورد');
        }
      } else {
        compressedFile = await compressImage(file);
        if (compressedFile == null) {
          logInfo(
              'فشرده‌سازی ناموفق بود، استفاده از فایل اصلی');
          compressedFile = file;
        }
      }

      final fileName =
          'avatars/${userId}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(compressedFile.path)}';

      final Uint8List fileBytes = await compressedFile.readAsBytes();

      const contentType = 'image/jpeg';
      logInfo('Content-Type: $contentType');
      logInfo('File size: ${fileBytes.length} bytes');
      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: fileName,
        contentType: contentType,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('تصویر با موفقیت آپلود شد: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e,
          context: 'profile_image_upload_registration');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'profile_image_upload_registration'));
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

  static Future<String?> uploadImageWeb(
      Uint8List fileBytes, String fileName) async {
    try {
      // فقط پسوند فایل را بررسی می‌کنیم
      final extension = path.extension(fileName).toLowerCase();
      logInfo('نوع فایل ورودی (وب): $extension');

      // همیشه با نوع 'image/jpeg' کار می‌کنیم
      const contentType = 'image/jpeg';

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('کاربر وارد نشده است');
      }

      final s3FileName =
          'avatars/${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      logInfo('Content-Type: $contentType');
      logInfo('File size: ${fileBytes.length} bytes');
      final uploadResult = await SecureUploadService.uploadBytes(
        bytes: fileBytes,
        objectKey: s3FileName,
        contentType: contentType,
      );

      final uploadedUrl = uploadResult.url;
      logInfo('تصویر با موفقیت آپلود شد (ثبت نام): $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e,
          context: 'profile_image_upload_registration');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'profile_image_upload_registration'));
    }
  }
  /// حذف تصویر پروفایل
  static Future<bool> deleteImage(String fileUrl) async {
    try {
      final deleted = await SecureUploadService.deleteByUrl(fileUrl);
      if (!deleted) {
        throw Exception('Delete failed');
      }
      return true;
    } catch (e) {
      logInfo('خطا در حذف تصویر پروفایل: $e');
      return false;
    }
  }
}
