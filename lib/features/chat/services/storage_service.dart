// lib/features/chat/services/storage_service.dart
//
// مدیریت متمرکز فایل‌های ابری (Cloud Storage)
// مسئولیت: آپلود و حذف فایل‌های چت از Arvan/Supabase

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase;

  StorageService(this._supabase);

  /// حذف هوشمند فایل از فضای ابری
  ///
  /// این متد:
  /// 1. URL را تجزیه می‌کند
  /// 2. نام باکت را حدس می‌زند
  /// 3. مسیر فایل را استخراج می‌کند
  /// 4. فایل را حذف می‌کند
  ///
  /// پارامترها:
  /// - fileUrl: URL کامل فایل
  /// - fileType: نوع فایل (image, audio, video, document)
  ///
  /// بازگشت: true اگر موفق، false اگر خطا
  Future<bool> deleteFile(String fileUrl, String? fileType) async {
    if (fileUrl.isEmpty) {
      print('⚠️ File URL is empty, skipping deletion');
      return false;
    }

    try {
      print('🗑️ Attempting to delete file: $fileUrl');

      // ۱. تعیین نام باکت بر اساس نوع فایل
      String bucketName = _determineBucketName(fileType);
      print('📦 Using bucket: $bucketName');

      // ۲. استخراج مسیر فایل از URL
      String filePath = _extractFilePath(fileUrl, bucketName);
      if (filePath.isEmpty) {
        print('❌ Could not extract file path from URL');
        return false;
      }

      print('📂 File path: $filePath');

      // ۳. حذف فایل از Supabase Storage
      await _supabase.storage.from(bucketName).remove([filePath]);

      print('✅ File deleted successfully from cloud storage');
      return true;
    } catch (e) {
      print('⚠️ Error deleting file from cloud: $e');
      // اگرچه خطا رخ داده، پیام در دیتابیس حذف می‌شود
      // اما این log برای ردیابی مشکلات مفید است
      return false;
    }
  }

  /// حذف چندین فایل بدسته
  ///
  /// بازگشت: تعداد فایل‌های موفقی حذف‌شده
  Future<int> deleteMultipleFiles(
      List<String> fileUrls, String? fileType) async {
    int deletedCount = 0;

    for (final url in fileUrls) {
      final success = await deleteFile(url, fileType);
      if (success) {
        deletedCount++;
      }
    }

    print('📊 Batch deletion: $deletedCount/${fileUrls.length} files deleted');
    return deletedCount;
  }

  /// تعیین نام باکت بر اساس نوع فایل
  ///
  /// نام‌گذاری:
  /// - image → chat_attachments
  /// - audio/voice → chat_attachments
  /// - video → chat_attachments
  /// - document → chat_attachments
  /// - default → chat_attachments
  String _determineBucketName(String? fileType) {
    if (fileType == null || fileType.isEmpty) {
      return 'chat_attachments'; // پیش‌فرض
    }

    // اگر شما باکت‌های جدا دارید برای صوت، این‌جا می‌توانید تغییر دهید:
    // final type = fileType.toLowerCase();
    // if (type == 'audio' || type == 'voice') {
    //   return 'voice_messages';
    // }
    // if (type == 'video') {
    //   return 'video_messages';
    // }

    // برای اکنون، همه چیز در یک باکت:
    return 'chat_attachments';
  }

  /// استخراج مسیر فایل از URL
  ///
  /// مثال URL:
  /// https://project.supabase.co/storage/v1/object/public/chat_attachments/image/user123/file.jpg
  ///
  /// نتیجه: image/user123/file.jpg
  String _extractFilePath(String fileUrl, String bucketName) {
    try {
      // روش ۱: تقسیم بر اساس نام باکت
      if (fileUrl.contains(bucketName)) {
        final parts = fileUrl.split('$bucketName/');
        if (parts.length > 1) {
          String path = parts[1];
          // دیکد URL (برای کاراکتر‌های خاص و فارسی)
          path = Uri.decodeFull(path);
          return path;
        }
      }

      // روش ۲: فرض کنید کل path فایل در URL وجود دارد
      // اگر روش ۱ کار نکرد، بخش‌های آخر URL را بگیر
      final uri = Uri.parse(fileUrl);
      final pathSegments = uri.pathSegments;

      // معمولاً ساختار: ['storage', 'v1', 'object', 'public', 'bucket', 'type', 'userid', 'filename']
      if (pathSegments.length >= 6) {
        // از شاخص 5 به بعد مسیر فایل است
        return pathSegments.sublist(5).join('/');
      }

      print('⚠️ Could not parse URL: $fileUrl');
      return '';
    } catch (e) {
      print('❌ Error extracting file path: $e');
      return '';
    }
  }

  /// بررسی وجود فایل در Storage
  ///
  /// استفاده برای validation قبل از ارسال
  Future<bool> fileExists(String fileUrl, String bucketName) async {
    try {
      final filePath = _extractFilePath(fileUrl, bucketName);
      if (filePath.isEmpty) return false;

      // این دستور لیستی از فایل‌ها بازمی‌گرداند
      // اگر فایل وجود دارد، در لیست خواهد بود
      final files = await _supabase.storage
          .from(bucketName)
          .list(path: _getDirectoryPath(filePath));

      return files.any((file) => file.name == _getFileName(filePath));
    } catch (e) {
      print('❌ Error checking file existence: $e');
      return false;
    }
  }

  /// استخراج نام فایل از مسیر
  String _getFileName(String filePath) {
    return filePath.split('/').last;
  }

  /// استخراج دایرکتوری از مسیر
  String _getDirectoryPath(String filePath) {
    final parts = filePath.split('/');
    if (parts.length > 1) {
      return parts.sublist(0, parts.length - 1).join('/');
    }
    return '';
  }
}
