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
import '../../../services/vista_node_service.dart';

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

  // محدودیت زمانی ویرایش (48 ساعت مثل ویستا)
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
      return const ActionResult.failure('خطا در ویرایش پیام');
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
      return const ActionResult.failure('خطا در فوروارد پیام');
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
      return const ActionResult.failure('خطا در فوروارد پیام‌ها');
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
      return const ActionResult.failure('خطا در حذف پیام');
    }
  }

  /// حذف برای همه (Hard Delete)
  /// ⚠️ این متد درخواست را به سرور Node.js ارسال می‌کند
  /// سرور مسئول حذف فایل از S3 و رکورد از DB است
  Future<ActionResult<void>> _deleteForEveryone({
    required String messageId,
    required String userId,
  }) async {
    try {
      // بررسی مالکیت پیام
      final message = await _supabase
          .from('messages')
          .select('sender_id')
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

      // ارسال درخواست به سرور Node.js
      // سرور خودش فایل S3 و رکورد DB را حذف می‌کند
      await VistaNodeService.deleteMessage(messageId);

      print('✅ Message deleted for everyone: $messageId');
      return const ActionResult.success();
    } catch (e) {
      print('❌ Error deleting for everyone: $e');
      return const ActionResult.failure('خطا در حذف پیام برای همه');
    }
  }

  /// حذف برای من (Soft Delete / Hide)
  Future<ActionResult<void>> _deleteForMe({
    required String messageId,
    required String conversationId,
    required String userId,
  }) async {
    try {
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
      return const ActionResult.failure('خطا در مخفی کردن پیام');
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
      return const ActionResult.failure('خطا در حذف پیام‌ها');
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
