import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'secure_config.dart';
import 'user_friendly_error_handler.dart';
import '/main.dart'; // برای دسترسی به supabase client

class ChatFileUploadService {
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

  /// آپلود فایل PDF چت با پشتیبانی از پیشرفت آپلود
  static Future<String?> uploadChatPdfFile(
    File file,
    String conversationId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await file.exists()) {
        throw Exception('فایل مورد نظر وجود ندارد');
      }

      final extension = path.extension(file.path).toLowerCase();
      if (extension != '.pdf') {
        throw Exception('فقط فایل‌های PDF پشتیبانی می‌شوند');
      }

      // بررسی حجم فایل - حداکثر 5MB برای PDF
      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('حجم فایل PDF باید کمتر از ۵ مگابایت باشد');
      }

      // بررسی حجم فایل - حداقل 1KB برای جلوگیری از فایل‌های خالی
      if (fileSize < 1024) {
        throw Exception('فایل PDF باید حداقل ۱ کیلوبایت حجم داشته باشد');
      }

      final fileName =
          'chats/$conversationId/${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';

      final Uint8List fileBytes = await file.readAsBytes();
      const contentType = 'application/pdf';

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
      print('فایل چت با موفقیت آپلود شد: $uploadedUrl');

      if (uploadedUrl.isEmpty) {
        throw Exception('لینک آپلود فایل خالی است!');
      }

      return uploadedUrl;
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'file_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'file_upload'));
    }
  }

  /// متد مخصوص آپلود فایل PDF چت در وب (بدون استفاده از File)
  static Future<String?> uploadChatPdfFileWeb(
    Uint8List fileBytes,
    String fileName,
    String conversationId,
  ) async {
    try {
      print('Starting web PDF file upload...');

      // بررسی پسوند فایل - فقط PDF پشتیبانی می‌شود
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        throw Exception('فقط فایل‌های PDF پشتیبانی می‌شوند');
      }

      // بررسی حجم فایل - حداکثر 5MB برای PDF
      if (fileBytes.length > 5 * 1024 * 1024) {
        throw Exception('حجم فایل PDF باید کمتر از ۵ مگابایت باشد');
      }

      // بررسی حجم فایل - حداقل 1KB برای جلوگیری از فایل‌های خالی
      if (fileBytes.length < 1024) {
        throw Exception('فایل PDF باید حداقل ۱ کیلوبایت حجم داشته باشد');
      }

      final sanitizedFileName =
          fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');

      const contentType = 'application/pdf';
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
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
        );

        final uploadedUrl =
            'https://storage.389346.ir.cdn.ir/$bucketName/$s3FileName';
        print('Web PDF file upload successful: $uploadedUrl');

        return uploadedUrl;
      } catch (e) {
        UserFriendlyErrorHandler.logError(e, context: 'file_upload');
        throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
            context: 'file_upload'));
      }
    } catch (e) {
      UserFriendlyErrorHandler.logError(e, context: 'file_upload');
      throw Exception(UserFriendlyErrorHandler.getFriendlyMessage(e,
          context: 'file_upload'));
    }
  }

  /// حذف فایل چت
  static Future<bool> deleteChatFile(String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final key = uri.pathSegments.sublist(1).join('/');

      await s3.deleteObject(
        bucket: bucketName,
        key: key,
      );

      return true;
    } catch (e) {
      print('خطا در حذف فایل چت: $e');
      return false;
    }
  }
}

