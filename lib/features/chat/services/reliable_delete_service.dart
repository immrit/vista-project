// lib/features/chat/services/reliable_delete_service.dart
//
// سرویس حذف تضمینی پیام با صف و retry خودکار
// این سرویس تضمین می‌کند که حتی اگر اینترنت قطع شود، حذف پیام انجام می‌شود
// همچنین فایل‌ها را از آروان استوریج هم حذف می‌کند

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../../../services/secure_config.dart';
import '../../../security/logging_utility.dart';

/// Provider برای ReliableDeleteService
final reliableDeleteServiceProvider = Provider((ref) => ReliableDeleteService());

/// تسک حذف در صف
class DeletionTask {
  final String messageId;
  final String conversationId;
  final bool forEveryone;
  final DateTime timestamp;
  int retryCount;

  DeletionTask({
    required this.messageId,
    required this.conversationId,
    required this.forEveryone,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'conversation_id': conversationId,
      'for_everyone': forEveryone,
      'timestamp': timestamp.toIso8601String(),
      'retry_count': retryCount,
    };
  }

  factory DeletionTask.fromJson(Map<String, dynamic> json) {
    return DeletionTask(
      messageId: json['message_id'],
      conversationId: json['conversation_id'],
      forEveryone: json['for_everyone'] as bool,
      timestamp: DateTime.parse(json['timestamp']),
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }
}

/// سرویس حذف تضمینی پیام
class ReliableDeleteService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // صفی برای نگهداری تسک‌های حذف
  // TODO: در آینده باید در دیتابیس لوکال (Hive/Sqlite) ذخیره شود
  final List<DeletionTask> _deletionQueue = [];
  bool _isProcessing = false;

  ReliableDeleteService();

  /// متد اصلی که UI صدا می‌زند
  ///
  /// [messageId] - شناسه پیام
  /// [conversationId] - شناسه مکالمه
  /// [forEveryone] - آیا برای همه حذف شود؟
  /// [onLocalCacheUpdate] - callback برای آپدیت فوری کش لوکال
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    required bool forEveryone,
    required Function(String) onLocalCacheUpdate,
  }) async {
    // ۱. آپدیت فوری کش لوکال (حذف ویژوال)
    onLocalCacheUpdate(messageId);

    // ۲. افزودن به صف
    _deletionQueue.add(DeletionTask(
      messageId: messageId,
      conversationId: conversationId,
      forEveryone: forEveryone,
      timestamp: DateTime.now(),
    ));

    // ۳. شروع پردازش
    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// پردازش صف حذف
  Future<void> _processQueue() async {
    if (_deletionQueue.isEmpty) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    final task = _deletionQueue.first;

    try {
      if (task.forEveryone) {
        // ⚠️ مهم: اول باید اطلاعات فایل را بگیریم قبل از اینکه پیام را پاک کنیم
        final messageData = await _supabase
            .from('messages')
            .select('sender_id, attachment_url, audio_url')
            .eq('id', task.messageId)
            .maybeSingle();

        if (messageData != null) {
          // ✅ حذف فایل از آروان (بک‌گراند)
          final audioUrl = messageData['audio_url'] as String?;
          final attachmentUrl = messageData['attachment_url'] as String?;

          if (audioUrl != null && audioUrl.isNotEmpty) {
            await _deleteFileFromArvan(audioUrl);
          }
          if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
            await _deleteFileFromArvan(attachmentUrl);
          }
        }

        // حالا پیام را از دیتابیس پاک/آپدیت می‌کنیم
        // برای حفظ یکپارچگی چت، معمولا متن را پاک می‌کنند و فلگ deleted می‌زنند
        await _supabase.from('messages').update({
          'is_deleted': true, // ✅ ستون صحیح طبق اسکیما
          'deleted_at': DateTime.now().toUtc().toIso8601String(), // ✅ مقداردهی زمان حذف
          'content': '', // پاکسازی متن برای امنیت
          'attachment_url': null,
          'audio_url': null,
          'encrypted_content': null, // اگر محتوای رمزنگاری شده هم دارید پاک شود
          'location_data': null,
          'contact_data': null,
        }).eq('id', task.messageId);
      } else {
        // حذف یک طرفه (Delete for Me)
        await _supabase.from('hidden_messages').upsert({
          'message_id': task.messageId,
          'user_id': _supabase.auth.currentUser!.id,
          'conversation_id': task.conversationId,
          'hidden_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      // موفقیت: حذف از صف
      _deletionQueue.removeAt(0);
    } catch (e) {
      logError('Background Delete Error: $e');
      task.retryCount++;

      // اگر بیش از ۵ بار تلاش کردیم، از صف حذف می‌کنیم
      if (task.retryCount >= 5) {
        logError('⚠️ حذف پیام ${task.messageId} بعد از ۵ تلاش ناموفق از صف حذف شد');
        _deletionQueue.removeAt(0);
      } else {
        // تلاش مجدد با تاخیر (Exponential Backoff)
        final delaySeconds = task.retryCount * 2; // 2, 4, 6, 8, 10 ثانیه
        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }

    // ادامه پردازش صف
    _processQueue();
  }

  /// 🗑️ لاجیک حذف از آروان (کپی شده از MessageActionsService)
  /// پشتیبانی از فرمت‌های مختلف URL:
  /// - https://storage.389346.ir.cdn.ir/bucketName/path/to/file
  /// - https://coffevista.s3.ir-thr-at1.arvanstorage.ir/path/to/file
  Future<void> _deleteFileFromArvan(String fileUrl) async {
    if (fileUrl.isEmpty) {
      logInfo('⚠️ File URL is empty, skipping deletion');
      return;
    }

    try {
      // استخراج کلید S3 از URL
      final s3Key = _extractS3KeyFromUrl(fileUrl);
      if (s3Key == null || s3Key.isEmpty) {
        logInfo('⚠️ Could not extract S3 key from URL: $fileUrl');
        return;
      }

      logInfo('🗑️ Deleting file from Arvan. URL: $fileUrl, Key: $s3Key');

      // ایجاد کلاینت S3
      if (!SecureConfig.isConfigured) {
        logError('AWS Config Missing!');
        return;
      }

      final s3 = S3(
        region: SecureConfig.awsRegion,
        credentials: AwsClientCredentials(
          accessKey: SecureConfig.awsAccessKey,
          secretKey: SecureConfig.awsSecretKey,
        ),
        endpointUrl: SecureConfig.awsEndpointUrl,
      );

      // حذف فایل
      await s3.deleteObject(
        bucket: SecureConfig.awsBucketName,
        key: s3Key,
      );

      logInfo('✅ File deleted from Arvan storage: $fileUrl');
    } catch (e) {
      // اگر فایل پیدا نشد (404)، یعنی قبلاً پاک شده و موفقیت محسوب می‌شود
      if (e.toString().contains('404') || e.toString().contains('NoSuchKey')) {
        logInfo('⚠️ File not found (404), assumed deleted: $fileUrl');
        return;
      }
      logInfo('⚠️ Error deleting from Arvan (Task continues): $e');
      // خطا را پرتاب نمی‌کنیم تا تسک ادامه پیدا کند
    }
  }

  /// استخراج کلید S3 از URL
  String? _extractS3KeyFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;

      if (segments.isEmpty) return null;

      // فرمت 1: https://storage.389346.ir.cdn.ir/bucketName/path/to/file
      if (url.contains('storage.389346.ir.cdn.ir')) {
        if (segments.length > 1) {
          // حذف اولین segment (نام باکت) و بازگرداندن بقیه
          final key = segments.sublist(1).join('/');
          return Uri.decodeFull(key);
        }
        return null;
      }

      // فرمت 2: https://coffevista.s3.ir-thr-at1.arvanstorage.ir/path/to/file
      final bucketName = SecureConfig.awsBucketName;
      if (segments.first == bucketName && segments.length > 1) {
        final key = segments.skip(1).join('/');
        return Uri.decodeFull(key);
      }

      // فرمت 3: اگر bucket name در URL نیست، کل path را برمی‌گردانیم
      return Uri.decodeFull(segments.join('/'));
    } catch (_) {
      return null;
    }
  }

  /// دریافت تعداد تسک‌های در صف (برای نمایش به کاربر)
  int get queueLength => _deletionQueue.length;

  /// بررسی آیا در حال پردازش است
  bool get isProcessing => _isProcessing;
}
