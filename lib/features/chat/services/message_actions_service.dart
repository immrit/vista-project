// lib/features/chat/services/message_actions_service.dart
//
// سرویس اقدامات روی پیام‌ها (ویرایش، فوروارد)
//
// ویژگی‌ها:
// ✅ ویرایش پیام با محدودیت زمانی
// ✅ فوروارد پیام به مکالمات دیگر
// ✅ کپی پیام
// ✅ پین کردن پیام
//

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../../../services/secure_config.dart';
import '../../../security/logging_utility.dart';

/// نتیجه عملیات
class ActionResult<T> {
  final bool isSuccess;
  final T? data;
  final String? error;

  const ActionResult.success([this.data])
      : isSuccess = true,
        error = null;

  const ActionResult.failure(this.error)
      : isSuccess = false,
        data = null;
}

/// سرویس اقدامات پیام
class MessageActionsService {
  final SupabaseClient _supabase;

  // محدودیت زمانی ویرایش (48 ساعت مثل تلگرام)
  static const editTimeLimit = Duration(hours: 48);

  MessageActionsService(this._supabase);

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // ═══════════════════════════════════════════════════════════════════════════
  // ✏️ EDIT MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی امکان ویرایش پیام
  bool canEditMessage(String senderId, DateTime createdAt) {
    if (senderId != _currentUserId) return false;
    final age = DateTime.now().difference(createdAt);
    return age <= editTimeLimit;
  }

  /// ویرایش پیام
  Future<ActionResult<void>> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }

      // دریافت پیام برای بررسی
      final response = await _supabase
          .from('messages')
          .select('sender_id, created_at, content')
          .eq('id', messageId)
          .single();

      final senderId = response['sender_id'] as String;
      final createdAt = DateTime.parse(response['created_at'] as String);
      final oldContent = response['content'] as String;

      // بررسی مالکیت
      if (senderId != userId) {
        return const ActionResult.failure(
            'شما نمی‌توانید این پیام را ویرایش کنید');
      }

      // بررسی محدودیت زمانی
      if (!canEditMessage(senderId, createdAt)) {
        return const ActionResult.failure(
          'زمان ویرایش پیام به پایان رسیده است (حداکثر 48 ساعت)',
        );
      }

      // بررسی تغییر واقعی
      if (newContent.trim() == oldContent.trim()) {
        return const ActionResult.failure('محتوای پیام تغییر نکرده است');
      }

      // ویرایش پیام
      await _supabase.from('messages').update({
        'content': newContent.trim(),
        'is_edited': true,
        'edited_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', messageId);

      print('✅ Message edited: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error editing message: $e');
      return ActionResult.failure('خطا در ویرایش پیام: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ↗️ FORWARD MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// فوروارد پیام به یک یا چند مکالمه
  Future<ActionResult<int>> forwardMessage({
    required String messageId,
    required List<String> targetConversationIds,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }

      if (targetConversationIds.isEmpty) {
        return const ActionResult.failure('هیچ مکالمه‌ای انتخاب نشده');
      }

      // دریافت پیام اصلی
      final originalMessage = await _supabase
          .from('messages')
          .select('*, profiles:sender_id(full_name)')
          .eq('id', messageId)
          .single();

      int successCount = 0;

      for (final conversationId in targetConversationIds) {
        try {
          await _supabase.from('messages').insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': originalMessage['content'],
            'attachment_url': originalMessage['attachment_url'],
            'attachment_type': originalMessage['attachment_type'],
            'attachment_file_name': originalMessage['attachment_file_name'],
            'original_message_id': messageId,
            'original_sender_id': originalMessage['sender_id'],
            'forwarded_from_sender_name': originalMessage['profiles'] != null
                ? originalMessage['profiles']['full_name']
                : null,
            'is_forwarded': true,
            'is_sent': true,
            'is_delivered': false,
          });
          successCount++;
        } catch (e) {
          print('❌ Error forwarding to $conversationId: $e');
        }
      }

      if (successCount == 0) {
        return const ActionResult.failure('خطا در فوروارد پیام');
      }

      print('✅ Message forwarded to $successCount conversations');
      return ActionResult.success(successCount);
    } catch (e) {
      print('❌ Error forwarding message: $e');
      return ActionResult.failure('خطا در فوروارد پیام: $e');
    }
  }

  /// فوروارد چند پیام
  Future<ActionResult<int>> forwardMultipleMessages({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) async {
    try {
      if (messageIds.isEmpty) {
        return const ActionResult.failure('هیچ پیامی انتخاب نشده');
      }

      int totalSuccess = 0;

      for (final messageId in messageIds) {
        final result = await forwardMessage(
          messageId: messageId,
          targetConversationIds: targetConversationIds,
        );
        if (result.isSuccess) {
          totalSuccess += result.data ?? 0;
        }
      }

      if (totalSuccess == 0) {
        return const ActionResult.failure('خطا در فوروارد پیام‌ها');
      }

      return ActionResult.success(totalSuccess);
    } catch (e) {
      return ActionResult.failure('خطا در فوروارد پیام‌ها: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🗑️ DELETE MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// حذف پیام (Delete for Me یا Delete for Everyone)
  ///
  /// - [forEveryone] = true: حذف کامل از دیتابیس (فقط برای پیام‌های خودم)
  /// - [forEveryone] = false: مخفی کردن پیام برای این کاربر
  Future<ActionResult<void>> deleteMessage({
    required String messageId,
    required String conversationId,
    bool forEveryone = false,
  }) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        return const ActionResult.failure('کاربر وارد نشده است');
      }

      if (forEveryone) {
        // Delete for Everyone: فقط صاحب پیام می‌تواند
        return await _deleteForEveryone(messageId: messageId, userId: userId);
      } else {
        // Delete for Me: مخفی کردن پیام
        return await _deleteForMe(
          messageId: messageId,
          conversationId: conversationId,
          userId: userId,
        );
      }
    } catch (e) {
      print('❌ Error deleting message: $e');
      return ActionResult.failure('خطا در حذف پیام: $e');
    }
  }

  /// حذف برای همه (Hard Delete)
  /// این متد پیام را از دیتابیس حذف می‌کند و اگر پیام دارای فایل باشد، آن را از آروان استوریج هم حذف می‌کند
  Future<ActionResult<void>> _deleteForEveryone({
    required String messageId,
    required String userId,
  }) async {
    try {
      // بررسی مالکیت پیام و دریافت اطلاعات فایل
      // ✅ خواندن هم attachment_url و هم audio_url (برای ویس‌ها)
      final message = await _supabase
          .from('messages')
          .select('sender_id, attachment_url, audio_url, conversation_id')
          .eq('id', messageId)
          .maybeSingle();

      if (message == null) {
        return const ActionResult.failure('پیام یافت نشد');
      }

      if (message['sender_id'] != userId) {
        return const ActionResult.failure(
          'شما فقط می‌توانید پیام‌های خودتان را برای همه حذف کنید',
        );
      }

      // ✅ حذف فایل از آروان استوریج (اگر وجود دارد)
      // اولویت با audio_url برای ویس‌ها، سپس attachment_url
      final audioUrl = message['audio_url'] as String?;
      final attachmentUrl = message['attachment_url'] as String?;
      
      // حذف audio_url (اگر وجود دارد - برای ویس‌ها)
      if (audioUrl != null && audioUrl.isNotEmpty) {
        try {
          await _deleteFileFromArvan(audioUrl);
          print('✅ Audio file deleted from Arvan storage: $audioUrl');
        } catch (e) {
          print('⚠️ Error deleting audio file from Arvan (continuing): $e');
        }
      }
      
      // حذف attachment_url (اگر وجود دارد - برای عکس، فیلم، فایل)
      if (attachmentUrl != null && attachmentUrl.isNotEmpty) {
        try {
          await _deleteFileFromArvan(attachmentUrl);
          print('✅ Attachment file deleted from Arvan storage: $attachmentUrl');
        } catch (e) {
          // اگر حذف فایل با خطا مواجه شد، لاگ می‌کنیم اما ادامه می‌دهیم
          // چون پیام باید از دیتابیس حذف شود
          print('⚠️ Error deleting attachment file from Arvan (continuing): $e');
        }
      }

      // حذف پیام از دیتابیس
      await _supabase.from('messages').delete().eq('id', messageId);

      // پاکسازی deleted_messages (اگر وجود دارد)
      try {
        await _supabase
            .from('deleted_messages')
            .delete()
            .eq('message_id', messageId);
      } catch (_) {
        // خطا در پاکسازی deleted_messages مهم نیست
      }

      print('✅ Message deleted for everyone: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error deleting for everyone: $e');
      return ActionResult.failure('خطا در حذف پیام برای همه: $e');
    }
  }

  /// حذف برای من (Soft Delete / Hide)
  Future<ActionResult<void>> _deleteForMe({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      // درج در جدول hidden_messages
      await _supabase.from('hidden_messages').upsert({
        'message_id': messageId,
        'user_id': userId,
        'conversation_id': conversationId,
        'hidden_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Message hidden for user: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error hiding message: $e');
      return ActionResult.failure('خطا در مخفی کردن پیام: $e');
    }
  }

  /// دریافت لیست پیام‌های مخفی شده برای یک مکالمه
  Future<Set<String>> getHiddenMessageIds(String conversationId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return {};

      final response = await _supabase
          .from('hidden_messages')
          .select('message_id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId);

      return (response as List)
          .map((item) => item['message_id'] as String)
          .toSet();
    } catch (e) {
      print('❌ Error getting hidden messages: $e');
      return {};
    }
  }

  /// حذف چند پیام
  Future<ActionResult<int>> deleteMultipleMessages({
    required List<String> messageIds,
    required String conversationId,
    bool forEveryone = false,
  }) async {
    try {
      int successCount = 0;

      for (final messageId in messageIds) {
        final result = await deleteMessage(
          messageId: messageId,
          conversationId: conversationId,
          forEveryone: forEveryone,
        );
        if (result.isSuccess) {
          successCount++;
        }
      }

      if (successCount == 0) {
        return const ActionResult.failure('هیچ پیامی حذف نشد');
      }

      return ActionResult.success(successCount);
    } catch (e) {
      return ActionResult.failure('خطا در حذف پیام‌ها: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📌 PIN MESSAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// پین کردن پیام
  Future<ActionResult<void>> pinMessage({
    required String messageId,
    required String conversationId,
  }) async {
    try {
      await _supabase.from('pinned_messages').upsert({
        'message_id': messageId,
        'conversation_id': conversationId,
        'pinned_by': _currentUserId,
        'pinned_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Message pinned: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error pinning message: $e');
      return ActionResult.failure('خطا در پین کردن پیام');
    }
  }

  /// آنپین کردن پیام
  Future<ActionResult<void>> unpinMessage(String messageId) async {
    try {
      await _supabase
          .from('pinned_messages')
          .delete()
          .eq('message_id', messageId);

      print('✅ Message unpinned: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error unpinning message: $e');
      return ActionResult.failure('خطا در آنپین کردن پیام');
    }
  }

  /// دریافت پیام‌های پین شده یک مکالمه
  Future<List<Map<String, dynamic>>> getPinnedMessages(
    String conversationId,
  ) async {
    try {
      final response = await _supabase
          .from('pinned_messages')
          .select('*, messages(*)')
          .eq('conversation_id', conversationId)
          .order('pinned_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting pinned messages: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🗑️ FILE DELETION FROM ARVAN STORAGE
  // ═══════════════════════════════════════════════════════════════════════════

  /// حذف فایل از آروان استوریج
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
      logError('❌ Error deleting file from Arvan: $fileUrl', error: e);
      rethrow; // پرتاب خطا برای مدیریت در متد فراخوان
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

      // در غیر این صورت، کل مسیر کلید است
      final key = segments.join('/');
      return Uri.decodeFull(key);
    } catch (e) {
      logError('Key extraction error for: $url', error: e);
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final messageActionsServiceProvider = Provider<MessageActionsService>((ref) {
  return MessageActionsService(Supabase.instance.client);
});

/// Actions provider
final messageActionsProvider = Provider<MessageActionsHandler>((ref) {
  final service = ref.watch(messageActionsServiceProvider);
  return MessageActionsHandler(service);
});

class MessageActionsHandler {
  final MessageActionsService _service;

  MessageActionsHandler(this._service);

  bool canEdit(String senderId, DateTime createdAt) =>
      _service.canEditMessage(senderId, createdAt);

  Future<ActionResult<void>> edit({
    required String messageId,
    required String newContent,
  }) =>
      _service.editMessage(messageId: messageId, newContent: newContent);

  Future<ActionResult<int>> forward({
    required String messageId,
    required List<String> targetConversationIds,
  }) =>
      _service.forwardMessage(
        messageId: messageId,
        targetConversationIds: targetConversationIds,
      );

  Future<ActionResult<int>> forwardMultiple({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) =>
      _service.forwardMultipleMessages(
        messageIds: messageIds,
        targetConversationIds: targetConversationIds,
      );

  Future<ActionResult<void>> pin({
    required String messageId,
    required String conversationId,
  }) =>
      _service.pinMessage(messageId: messageId, conversationId: conversationId);

  Future<ActionResult<void>> unpin(String messageId) =>
      _service.unpinMessage(messageId);
}
