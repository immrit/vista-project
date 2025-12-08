// lib/features/chat/services/message_forward_service.dart
//
// سرویس کامل فوروارد پیام‌ها
//

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class MessageForwardResult {
  final bool isSuccess;
  final String? error;
  final Map<String, String>?
      forwardedMessageIds; // conversationId -> newMessageId

  const MessageForwardResult({
    required this.isSuccess,
    this.error,
    this.forwardedMessageIds,
  });

  factory MessageForwardResult.success(Map<String, String> messageIds) {
    return MessageForwardResult(
      isSuccess: true,
      forwardedMessageIds: messageIds,
    );
  }

  factory MessageForwardResult.failure(String error) {
    return MessageForwardResult(
      isSuccess: false,
      error: error,
    );
  }
}

class MessageForwardService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  /// فوروارد یک پیام به چند مکالمه
  Future<MessageForwardResult> forwardSingle({
    required String messageId,
    required List<String> targetConversationIds,
  }) async {
    return forwardMultiple(
      messageIds: [messageId],
      targetConversationIds: targetConversationIds,
    );
  }

  /// فوروارد چند پیام به چند مکالمه
  Future<MessageForwardResult> forwardMultiple({
    required List<String> messageIds,
    required List<String> targetConversationIds,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return MessageForwardResult.failure('کاربر احراز هویت نشده');
      }

      if (messageIds.isEmpty || targetConversationIds.isEmpty) {
        return MessageForwardResult.failure('پیام یا مکالمه انتخاب نشده');
      }

      // دریافت اطلاعات پیام‌های اصلی
      final messagesResponse = await _supabase.from('messages').select('''
            id,
            conversation_id,
            sender_id,
            content,
            attachment_url,
            attachment_type,
            attachment_file_name,
            reply_to_message_id,
            reply_to_message_id,
            profiles:sender_id(full_name),
            is_forwarded,
            original_sender_id,
            original_message_id,
            forwarded_from_sender_name
          ''').inFilter('id', messageIds);

      if (messagesResponse.isEmpty) {
        return MessageForwardResult.failure('پیام‌ها یافت نشد');
      }

      final Map<String, String> forwardedIds = {};

      // برای هر مکالمه هدف
      for (final targetConvId in targetConversationIds) {
        // چک کنیم آیا کاربر عضو این مکالمه است
        final isParticipant = await _checkParticipant(userId, targetConvId);
        if (!isParticipant) {
          debugPrint('⚠️ User not participant in conversation: $targetConvId');
          continue;
        }

        // فوروارد هر پیام
        for (final messageData in messagesResponse as List) {
          final newMessageId = _uuid.v4();

          // منطق فوروارد زنجیره‌ای:
          // اگر پیام خودش فوروارد شده است، باید اطلاعات اصلی (Original) را حفظ کنیم.
          // اگر پیام فوروارد شده نیست، صاحب فعلی پیام (Sender) به عنوان Original در نظر گرفته می‌شود.

          final isAlreadyForwarded = messageData['is_forwarded'] == true;

          final String? originalSenderId = isAlreadyForwarded
              ? messageData['original_sender_id']
              : messageData['sender_id'];

          final String? originalMessageId = isAlreadyForwarded
              ? messageData['original_message_id']
              : messageData['id'];

          // نام فرستنده اصلی برای نمایش در هدر
          final String? forwardFromName = isAlreadyForwarded
              ? messageData['forwarded_from_sender_name']
              : (messageData['profiles'] != null
                  ? messageData['profiles']['full_name']
                  : null);

          // ساخت پیام جدید که لینک به اطلاعات اصلی دارد
          final newMessage = {
            'id': newMessageId,
            'conversation_id': targetConvId,
            'sender_id': userId,
            'content': messageData['content'],
            'attachment_url': messageData['attachment_url'],
            'attachment_type': messageData['attachment_type'],
            'attachment_file_name': messageData['attachment_file_name'],
            'reply_to_message_id': null, // پیام فوروارد شده reply ندارد

            // اطلاعات فوروارد
            'is_forwarded': true,
            'original_sender_id': originalSenderId,
            'original_message_id': originalMessageId,
            'forwarded_from_sender_name': forwardFromName,

            'created_at': DateTime.now().toIso8601String(),
            'is_sent': true,
            'is_delivered': false,
          };

          // Insert پیام
          await _supabase.from('messages').insert(newMessage);

          forwardedIds[targetConvId] = newMessageId;

          // آپدیت last_message مکالمه
          await _updateConversationLastMessage(targetConvId, newMessageId);
        }
      }

      return MessageForwardResult.success(forwardedIds);
    } catch (e) {
      debugPrint('❌ Error forwarding messages: $e');
      return MessageForwardResult.failure(e.toString());
    }
  }

  /// فوروارد با کپشن (متن اضافه)
  Future<MessageForwardResult> forwardWithCaption({
    required List<String> messageIds,
    required String targetConversationId,
    required String caption,
  }) async {
    try {
      // ابتدا پیام‌ها رو فوروارد کن
      final result = await forwardMultiple(
        messageIds: messageIds,
        targetConversationIds: [targetConversationId],
      );

      if (!result.isSuccess) return result;

      // سپس پیام متنی کپشن رو بفرست
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && caption.trim().isNotEmpty) {
        await _supabase.from('messages').insert({
          'id': _uuid.v4(),
          'conversation_id': targetConversationId,
          'sender_id': userId,
          'content': caption,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return result;
    } catch (e) {
      return MessageForwardResult.failure(e.toString());
    }
  }

  /// چک کردن عضویت در مکالمه
  Future<bool> _checkParticipant(String userId, String conversationId) async {
    try {
      final response = await _supabase
          .from('conversation_participants')
          .select('id')
          .eq('user_id', userId)
          .eq('conversation_id', conversationId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// آپدیت last_message مکالمه
  Future<void> _updateConversationLastMessage(
    String conversationId,
    String messageId,
  ) async {
    try {
      await _supabase.from('conversations').update({
        'last_message_id': messageId,
        'last_message_at': DateTime.now().toIso8601String(),
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint('❌ Error updating conversation: $e');
    }
  }

  /// دریافت تعداد دفعات فوروارد یک پیام
  Future<int> getForwardCount(String originalMessageId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('original_message_id', originalMessageId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  /// دریافت اطلاعات فرستنده اصلی
  Future<Map<String, dynamic>?> getOriginalSenderInfo(String messageId) async {
    try {
      final message = await _supabase
          .from('messages')
          .select('original_sender_id')
          .eq('id', messageId)
          .single();

      if (message['original_sender_id'] == null) return null;

      final profile = await _supabase
          .from('profiles')
          .select('id, full_name, avatar_url, username')
          .eq('id', message['original_sender_id'])
          .single();

      return profile;
    } catch (e) {
      return null;
    }
  }
}
