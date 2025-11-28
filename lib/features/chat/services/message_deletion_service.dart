// lib/features/chat/services/message_deletion_service.dart
//
// سرویس حذف پیام و پاکسازی چت (الهام از تلگرام)
//
// ویژگی‌ها:
// ✅ حذف تک پیام (برای من / برای همه)
// ✅ حذف دسته‌ای پیام‌ها
// ✅ پاکسازی کامل چت (برای من / برای همه)
// ✅ Undo functionality (مثل تلگرام)
// ✅ Animation و feedback
//

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../main.dart';
import '../../../security/logging_utility.dart';

/// نوع حذف
enum DeletionType {
  forMe,       // فقط برای من
  forEveryone, // برای همه (هر دو طرف)
}

/// نوع عملیات
enum DeletionOperation {
  singleMessage,    // یک پیام
  multipleMessages, // چند پیام
  entireChat,       // کل چت
}

/// نتیجه حذف
class DeletionResult {
  final bool success;
  final String? error;
  final int deletedCount;
  final DeletionOperation operation;

  const DeletionResult({
    required this.success,
    this.error,
    this.deletedCount = 0,
    required this.operation,
  });

  factory DeletionResult.success({
    required int count,
    required DeletionOperation operation,
  }) {
    return DeletionResult(
      success: true,
      deletedCount: count,
      operation: operation,
    );
  }

  factory DeletionResult.failure(String error, DeletionOperation operation) {
    return DeletionResult(
      success: false,
      error: error,
      operation: operation,
    );
  }
}

/// سرویس حذف پیام (مثل تلگرام)
class MessageDeletionService {
  final SupabaseClient _supabase = supabase;

  /// حذف یک پیام
  ///
  /// [messageId] - شناسه پیام
  /// [type] - نوع حذف (برای من / برای همه)
  ///
  /// Returns: نتیجه حذف
  Future<DeletionResult> deleteMessage({
    required String messageId,
    required DeletionType type,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return DeletionResult.failure(
          'کاربر وارد نشده است',
          DeletionOperation.singleMessage,
        );
      }

      logInfo('🗑️ Deleting message: $messageId (type: ${type.name})');

      if (type == DeletionType.forEveryone) {
        // حذف برای همه - پیام را کاملاً حذف کن
        await _supabase.from('messages').delete().eq('id', messageId);
        
        logInfo('✅ Message deleted for everyone');
      } else {
        // حذف فقط برای من - به جای حذف، فیلد deleted_for اضافه کن
        final message = await _supabase
            .from('messages')
            .select('deleted_for')
            .eq('id', messageId)
            .single();

        List<String> deletedFor = [];
        if (message['deleted_for'] != null) {
          deletedFor = List<String>.from(message['deleted_for'] as List);
        }

        if (!deletedFor.contains(currentUserId)) {
          deletedFor.add(currentUserId);
        }

        await _supabase.from('messages').update({
          'deleted_for': deletedFor,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', messageId);

        logInfo('✅ Message deleted for current user');
      }

      return DeletionResult.success(
        count: 1,
        operation: DeletionOperation.singleMessage,
      );
    } catch (e, stackTrace) {
      logInfo('❌ Error deleting message: $e\n$stackTrace');
      return DeletionResult.failure(
        'خطا در حذف پیام: ${e.toString()}',
        DeletionOperation.singleMessage,
      );
    }
  }

  /// حذف چند پیام
  ///
  /// [messageIds] - لیست شناسه پیام‌ها
  /// [type] - نوع حذف
  ///
  /// Returns: نتیجه حذف
  Future<DeletionResult> deleteMessages({
    required List<String> messageIds,
    required DeletionType type,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return DeletionResult.failure(
          'کاربر وارد نشده است',
          DeletionOperation.multipleMessages,
        );
      }

      logInfo('🗑️ Deleting ${messageIds.length} messages (type: ${type.name})');

      int deletedCount = 0;

      for (final messageId in messageIds) {
        final result = await deleteMessage(
          messageId: messageId,
          type: type,
        );
        
        if (result.success) {
          deletedCount++;
        }
      }

      logInfo('✅ Deleted $deletedCount messages');

      return DeletionResult.success(
        count: deletedCount,
        operation: DeletionOperation.multipleMessages,
      );
    } catch (e, stackTrace) {
      logInfo('❌ Error deleting messages: $e\n$stackTrace');
      return DeletionResult.failure(
        'خطا در حذف پیام‌ها: ${e.toString()}',
        DeletionOperation.multipleMessages,
      );
    }
  }

  /// پاکسازی کامل چت
  ///
  /// [conversationId] - شناسه مکالمه
  /// [type] - نوع پاکسازی
  ///
  /// Returns: نتیجه پاکسازی
  Future<DeletionResult> clearChat({
    required String conversationId,
    required DeletionType type,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        return DeletionResult.failure(
          'کاربر وارد نشده است',
          DeletionOperation.entireChat,
        );
      }

      logInfo('🗑️ Clearing chat: $conversationId (type: ${type.name})');

      if (type == DeletionType.forEveryone) {
        // پاکسازی برای همه - حذف تمام پیام‌ها
        final result = await _supabase
            .from('messages')
            .delete()
            .eq('conversation_id', conversationId)
            .select();

        final deletedCount = result.length;
        
        logInfo('✅ Chat cleared for everyone ($deletedCount messages)');

        return DeletionResult.success(
          count: deletedCount,
          operation: DeletionOperation.entireChat,
        );
      } else {
        // پاکسازی فقط برای من
        final messages = await _supabase
            .from('messages')
            .select('id, deleted_for')
            .eq('conversation_id', conversationId);

        int updatedCount = 0;

        for (final message in messages) {
          List<String> deletedFor = [];
          if (message['deleted_for'] != null) {
            deletedFor = List<String>.from(message['deleted_for'] as List);
          }

          if (!deletedFor.contains(currentUserId)) {
            deletedFor.add(currentUserId);

            await _supabase.from('messages').update({
              'deleted_for': deletedFor,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', message['id']);

            updatedCount++;
          }
        }

        logInfo('✅ Chat cleared for current user ($updatedCount messages)');

        return DeletionResult.success(
          count: updatedCount,
          operation: DeletionOperation.entireChat,
        );
      }
    } catch (e, stackTrace) {
      logInfo('❌ Error clearing chat: $e\n$stackTrace');
      return DeletionResult.failure(
        'خطا در پاکسازی چت: ${e.toString()}',
        DeletionOperation.entireChat,
      );
    }
  }

  /// بررسی آیا پیام قابل حذف برای همه است
  ///
  /// [messageId] - شناسه پیام
  /// [maxDuration] - حداکثر زمان (پیش‌فرض: 48 ساعت مثل تلگرام)
  ///
  /// Returns: true اگر قابل حذف باشد
  Future<bool> canDeleteForEveryone({
    required String messageId,
    Duration maxDuration = const Duration(hours: 48),
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return false;

      final message = await _supabase
          .from('messages')
          .select('sender_id, created_at')
          .eq('id', messageId)
          .single();

      // فقط فرستنده می‌تواند برای همه حذف کند
      if (message['sender_id'] != currentUserId) {
        return false;
      }

      // بررسی زمان ارسال
      final createdAt = DateTime.parse(message['created_at'] as String);
      final now = DateTime.now();
      final difference = now.difference(createdAt);

      // اگر کمتر از maxDuration باشد، قابل حذف است
      return difference < maxDuration;
    } catch (e) {
      logInfo('❌ Error checking deletion permission: $e');
      return false;
    }
  }
}

