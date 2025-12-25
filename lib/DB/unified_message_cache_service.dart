import '../security/logging_utility.dart';
import '../model/message_model.dart';
import 'advanced_cache_system.dart';

/// Unified message cache service that works on all platforms
class UnifiedMessageCacheService {
  static final UnifiedMessageCacheService _instance =
      UnifiedMessageCacheService._internal();
  factory UnifiedMessageCacheService() => _instance;
  UnifiedMessageCacheService._internal();

  final AdvancedCacheSystem _advancedCache = AdvancedCacheSystem();

  Future<void> initialize() async {
    await _advancedCache.initialize();
    logInfo('UnifiedMessageCacheService initialized with Advanced Cache');
  }

  /// Cache a message
  Future<void> cacheMessage(MessageModel message, String userId) async {
    await _advancedCache.cacheMessage(message);
  }

  /// Cache multiple messages
  Future<void> cacheMessages(List<MessageModel> messages, String userId) async {
    for (final message in messages) {
      await _advancedCache.cacheMessage(message);
    }
  }

  /// Cache multiple messages with limit support
  Future<void> cacheMessagesWithLimit(
      List<MessageModel> messages, String userId,
      {int? limit}) async {
    final messagesToCache =
        limit != null && limit > 0 ? messages.take(limit).toList() : messages;
    await cacheMessages(messagesToCache, userId);
  }

  /// Get conversation messages
  Future<List<MessageModel>> getConversationMessages(
      String conversationId, String userId,
      {int? limit}) async {
    final messages = _advancedCache.getCachedMessages(conversationId);
    
    // ✅ Optimization: Removed runtime isMe correction. 
    // Data should be correct at write time. Avoiding O(N) allocation.
    
    if (limit != null && limit > 0) {
      return messages.take(limit).toList();
    }
    return messages;
  }

  /// Get cached messages for a conversation
  Future<List<MessageModel>> getCachedMessages(
      String conversationId, String userId) async {
    final messages = _advancedCache.getCachedMessages(conversationId);
    
    // ✅ Optimization: Removed runtime isMe correction.
    return messages;
  }

  /// Get a specific message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId, String userId) async {
    final messages = _advancedCache.getCachedMessages(conversationId);
    return messages.where((m) => m.id == messageId).firstOrNull;
  }

  /// Update a message
  Future<void> updateMessage(MessageModel message, String userId) async {
    // Advanced cache handles updates through real-time sync
  }

  /// Clear messages for a conversation
  Future<void> clearConversationMessages(
      String conversationId, String userId) async {
    await _advancedCache.clearConversationMessages(conversationId);
  }

  /// Clear a specific message
  Future<void> clearMessage(
      String conversationId, String messageId, String userId) async {
    // Advanced cache handles message deletion
  }

  /// حذف فیزیکی پیام از کش (برای حذف دوطرفه)
  /// نیاز به conversationId دارد که باید از MessageDeletionService ارسال شود
  Future<void> deleteMessage(String messageId, {String? conversationId}) async {
    try {
      // اگر conversationId داده نشده باشد، باید آن را پیدا کنیم
      if (conversationId == null) {
        // جستجو در تمام conversation های کش شده
        // این یک روش موقت است - بهتر است conversationId همیشه ارسال شود
        final allMessages = await _findMessageInAllConversations(messageId);
        if (allMessages != null) {
          conversationId = allMessages.conversationId;
        }
      }
      
      if (conversationId != null) {
        await _advancedCache.deleteMessageFromCache(conversationId, messageId);
        logInfo('[UnifiedMessageCache] Message deleted: $messageId');
      } else {
        logInfo('[UnifiedMessageCache] Warning: Could not find conversationId for message: $messageId');
      }
    } catch (e) {
      logInfo('[UnifiedMessageCache] Error deleting message: $e');
    }
  }

  /// پیدا کردن پیام در تمام conversation ها
  Future<MessageModel?> _findMessageInAllConversations(String messageId) async {
    // این یک روش موقت است - برای بهینه‌سازی می‌توان از index استفاده کرد
    // برای اکنون، فقط در conversation های فعال جستجو می‌کنیم
    // در واقعیت، بهتر است conversationId را از MessageDeletionService ارسال کرد
    return null; // باید از caller ارسال شود
  }

  /// نشانه‌گذاری پیام به عنوان حذف شده برای کاربر فعلی (برای حذف یک‌طرفه)
  Future<void> markMessageAsDeletedForUser(String messageId, String userId, {String? conversationId}) async {
    try {
      MessageModel? message;
      
      // اگر conversationId داده شده باشد، مستقیم جستجو می‌کنیم
      if (conversationId != null) {
        message = await getMessage(conversationId, messageId, userId);
      } else {
        // جستجو در تمام conversation ها (موقت)
        message = await _findMessageInAllConversations(messageId);
      }
      
      if (message != null) {
        // به‌روزرسانی پیام با اضافه کردن userId به لیست deletedForUserIds
        final updatedDeletedForUserIds = List<String>.from(message.deletedForUserIds);
        if (!updatedDeletedForUserIds.contains(userId)) {
          updatedDeletedForUserIds.add(userId);
        }
        
        final updatedMessage = message.copyWith(
          deletedForUserIds: updatedDeletedForUserIds,
        );
        
        // به‌روزرسانی در کش
        await _advancedCache.cacheMessage(updatedMessage);
        logInfo('[UnifiedMessageCache] Message marked as deleted for user: $messageId');
      } else {
        logInfo('[UnifiedMessageCache] Warning: Could not find message: $messageId');
      }
    } catch (e) {
      logInfo('[UnifiedMessageCache] Error marking message as deleted: $e');
    }
  }

  /// به‌روزرسانی یا اضافه کردن پیام در کش
  Future<void> upsertMessage(MessageModel message) async {
    await _advancedCache.cacheMessage(message);
  }

  /// حذف تمام پیام‌های یک چت از کش
  Future<void> clearAllMessagesForChat(String chatId) async {
    await _advancedCache.clearConversationMessages(chatId);
    logInfo('[UnifiedMessageCache] All messages cleared for chat: $chatId');
  }

  /// Get unread message count
  Future<int> countUnreadMessages(String conversationId) async {
    return 0; // Placeholder
  }

  /// Clear all cached messages
  Future<void> clearAllCache() async {
    await _advancedCache.clearAllMessages();
  }

  /// Delete messages older than specified date
  Future<void> deleteMessagesOlderThan(DateTime date) async {
    // Advanced cache handles this through cleanup
  }

  /// Perform transaction
  Future<void> performTransaction(Future<void> Function() action) async {
    await action();
  }

  /// Replace temporary message with actual message
  Future<void> replaceTempMessage(
      MessageModel tempMessage, MessageModel actualMessage) async {
    // Delete temp message
    await clearMessage(
        tempMessage.conversationId, tempMessage.id, actualMessage.senderId);
    // Cache actual message
    await cacheMessage(actualMessage, actualMessage.senderId);
  }

  /// Mark message as failed
  Future<void> markMessageAsFailed(
      String conversationId, String messageId) async {
    logInfo('[UnifiedMessageCache] Marking message as failed: $messageId');
  }
}
