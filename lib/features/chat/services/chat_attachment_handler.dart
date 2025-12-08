// lib/features/chat/services/chat_attachment_handler.dart
//
// هندلر آپلود و حذف فایل‌های ضمیمه چت
//
// مسئولیت:
// - آپلود فایل‌های ضمیمه (عکس، صوت، فیلم)
// - دریافت URL عمومی
// - حذف فایل‌ها از Supabase Storage

import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentHandler {
  final SupabaseClient _supabase;

  ChatAttachmentHandler(this._supabase);

  /// آپلود فایل و دریافت URL
  ///
  /// پارامترها:
  /// - file: فایلی که قرار است آپلود شود
  /// - type: نوع فایل (image, audio, video)
  /// - fileName: نام فایل (اختیاری)
  ///
  /// بازگشت:
  /// - URL فایل آپلود شده یا null در صورت خطا
  Future<String?> uploadAttachment(
    File file,
    String type, {
    String? fileName,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        print('❌ کاربر وارد نشده است');
        return null;
      }

      final userId = user.id;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final finalFileName =
          fileName ?? '${timestamp}_${userId}_${file.path.split('/').last}';

      // ساخت مسیر: type/userId/filename
      final path = '$type/$userId/$finalFileName';

      print('📤 uploading attachment: $path');

      // آپلود فایل
      await _supabase.storage.from('chat_attachments').upload(path, file);

      // دریافت URL عمومی
      final publicUrl =
          _supabase.storage.from('chat_attachments').getPublicUrl(path);

      print('✅ Upload successful: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Upload failed: $e');
      return null;
    }
  }

  /// حذف فایل از Supabase Storage
  ///
  /// این متد از URL استخراج کرده و فایل را حذف می‌کند
  ///
  /// پارامترها:
  /// - url: URL فایل برای حذف
  ///
  /// بازگشت:
  /// - true اگر موفق بود، false اگر خطا رخ داد
  Future<bool> deleteAttachment(String url) async {
    try {
      if (url.isEmpty) return false;

      print('🗑️ Deleting attachment: $url');

      // استخراج مسیر فایل از URL
      // URL به صورت: https://...supabase.co/storage/v1/object/public/chat_attachments/TYPE/USERID/FILENAME
      final parts = url.split('/chat_attachments/');
      if (parts.length < 2) {
        print('❌ Cannot extract path from URL');
        return false;
      }

      final path = parts[1]; // TYPE/USERID/FILENAME

      // حذف فایل
      await _supabase.storage.from('chat_attachments').remove([path]);

      print('✅ Attachment deleted successfully: $path');
      return true;
    } catch (e) {
      print('❌ Delete attachment failed: $e');
      return false;
    }
  }

  /// حذف چندین فایل بصورت بدسته
  ///
  /// پارامترها:
  /// - urls: لیست URL‌های فایل برای حذف
  ///
  /// بازگشت:
  /// - تعداد فایل‌های موفقی حذف شده
  Future<int> deleteMultipleAttachments(List<String> urls) async {
    int deletedCount = 0;

    for (final url in urls) {
      final success = await deleteAttachment(url);
      if (success) {
        deletedCount++;
      }
    }

    return deletedCount;
  }
}
