import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '/main.dart';

class ChatAudioUploadService {
  // استفاده از همان تنظیمات S3 موجود
  static final s3 = S3(
    region: 'ir-thr-at1',
    credentials: AwsClientCredentials(
        accessKey: '4f4716fb-fa84-4ae7-9c8b-34d2a0896cdf',
        secretKey:
            'a6b4db27b4c54bfa46cbc4fd8a4ba2079e2da0cd2800acdc80dd758f8b2c1ec5'),
    endpointUrl: 'https://coffevista.s3.ir-thr-at1.arvanstorage.ir',
  );

  static const String bucketName = 'coffevista';

  /// آپلود فایل صوتی چت
  static Future<String?> uploadChatAudio(
    File audioFile,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await audioFile.exists()) {
        throw Exception('فایل صوتی مورد نظر وجود ندارد');
      }

      final extension = path.extension(audioFile.path).toLowerCase();

      // بررسی فرمت‌های مجاز صوتی
      if (!_isValidAudioFormat(extension)) {
        throw Exception('فرمت فایل صوتی پشتیبانی نمی‌شود');
      }

      final fileName =
          'chats/$conversationId/audio/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(audioFile.path)}';

      final Uint8List fileBytes = await audioFile.readAsBytes();
      final contentType = _getAudioContentType(extension);

      // پشتیبانی از پیشرفت آپلود
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

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$fileName';
      print('فایل صوتی چت با موفقیت آپلود شد: $uploadedUrl');

      if (uploadedUrl.isEmpty) {
        throw Exception('لینک آپلود فایل صوتی خالی است!');
      }

      return uploadedUrl;
    } catch (e) {
      print('خطا در آپلود فایل صوتی چت: $e');
      throw Exception('آپلود فایل صوتی چت شکست خورد: $e');
    }
  }

  /// آپلود فایل صوتی در وب
  static Future<String> uploadChatAudioWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      print('شروع آپلود فایل صوتی در وب...');

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');

      final extension = path.extension(sanitizedFileName).toLowerCase();
      final contentType = _getAudioContentType(extension);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('کاربر احراز هویت نشده');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final s3FileName =
          'chats/$conversationId/audio/${userId}_${timestamp}_$sanitizedFileName';

      print('آپلود به S3 با کلید: $s3FileName');

      await s3.putObject(
        bucket: bucketName,
        key: s3FileName,
        body: fileBytes,
        contentType: contentType,
        acl: ObjectCannedACL.publicRead,
      );

      final uploadedUrl =
          'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
      print('آپلود فایل صوتی وب موفق: $uploadedUrl');

      return uploadedUrl;
    } catch (e) {
      print('خطا در uploadChatAudioWeb: $e');
      throw Exception('آپلود فایل صوتی شکست خورد: $e');
    }
  }

  /// حذف فایل صوتی چت
  static Future<bool> deleteChatAudio(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      return true;
    } catch (e) {
      print('خطا در حذف فایل صوتی چت: $e');
      return false;
    }
  }

  /// بررسی فرمت صوتی معتبر
  static bool _isValidAudioFormat(String extension) {
    const validFormats = ['.mp3', '.aac', '.m4a', '.wav', '.ogg'];
    return validFormats.contains(extension);
  }

  /// تعیین Content-Type برای فایل‌های صوتی
  static String _getAudioContentType(String extension) {
    switch (extension) {
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/mp4';
      case '.wav':
        return 'audio/wav';
      case '.ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg'; // پیش‌فرض
    }
  }
}
