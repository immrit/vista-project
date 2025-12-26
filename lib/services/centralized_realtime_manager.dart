import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/message_model.dart';
import '../utils/const.dart';
import '../DB/unified_message_cache_service.dart';
import '../security/logging_utility.dart';

class CentralizedRealtimeManager {
  static final CentralizedRealtimeManager _instance =
      CentralizedRealtimeManager._internal();
  factory CentralizedRealtimeManager() => _instance;
  CentralizedRealtimeManager._internal();

  // نگهداری subscription ها به ازای هر conversation
  final Map<String, RealtimeChannel> _activeChannels = {};

  // نگهداری callback ها
  final Map<String, List<Function(MessageModel)>> _messageCallbacks = {};

  // نگهداری callback ها برای حذف پیام
  final Map<String, List<Function(String messageId)>> _deletionCallbacks = {};

  // نگهداری callback ها برای به‌روزرسانی پیام
  final Map<String, List<Function(MessageModel)>> _updateCallbacks = {};

  // Throttling برای prevent spam
  final Map<String, Timer?> _throttleTimers = {};
  static const _throttleDuration = Duration(milliseconds: 100);

  // Cache service برای مدیریت حذف
  final UnifiedMessageCacheService _cacheService = UnifiedMessageCacheService();

  /// Subscribe به یک conversation
  void subscribeToConversation({
    required String conversationId,
    required String userId,
    required Function(MessageModel) onNewMessage,
  }) {
    print('📡 Subscribing to conversation: $conversationId');

    // اضافه کردن callback
    if (!_messageCallbacks.containsKey(conversationId)) {
      _messageCallbacks[conversationId] = [];
    }
    _messageCallbacks[conversationId]!.add(onNewMessage);

    // اگر قبلاً subscribe کرده‌ایم، فقط callback را اضافه میکنیم
    if (_activeChannels.containsKey(conversationId)) {
      print('✅ Already subscribed to $conversationId');
      return;
    }

    // ساخت channel جدید با پشتیبانی از INSERT, UPDATE, DELETE
    final channel = supabase
        .channel('messages:$conversationId')
        // رویداد INSERT برای پیام‌های جدید
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            _handleNewMessage(conversationId, payload, userId);
          },
        )
        // رویداد UPDATE برای به‌روزرسانی پیام‌ها (مثل حذف یک‌طرفه)
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            _handleMessageUpdate(conversationId, payload, userId);
          },
        )
        // رویداد DELETE برای حذف دوطرفه
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            _handleMessageDelete(conversationId, payload, userId);
          },
        )
        .subscribe();

    _activeChannels[conversationId] = channel;
    print(
        '✅ Subscribed to conversation (INSERT/UPDATE/DELETE): $conversationId');
  }

  /// ثبت callback برای رویدادهای حذف
  void onMessageDeleted({
    required String conversationId,
    required Function(String messageId) callback,
  }) {
    if (!_deletionCallbacks.containsKey(conversationId)) {
      _deletionCallbacks[conversationId] = [];
    }
    _deletionCallbacks[conversationId]!.add(callback);
  }

  /// ثبت callback برای رویدادهای به‌روزرسانی
  void onMessageUpdated({
    required String conversationId,
    required Function(MessageModel message) callback,
  }) {
    if (!_updateCallbacks.containsKey(conversationId)) {
      _updateCallbacks[conversationId] = [];
    }
    _updateCallbacks[conversationId]!.add(callback);
  }

  /// Handle حذف پیام (DELETE event)
  void _handleMessageDelete(
    String conversationId,
    PostgresChangePayload payload,
    String currentUserId,
  ) {
    try {
      final messageId = payload.oldRecord['id'] as String?;
      if (messageId == null) return;

      logInfo('🗑️ Message deleted via realtime: $messageId');

      // حذف از کش محلی
      _cacheService.deleteMessage(conversationId, messageId);

      // فراخوانی callback ها
      final callbacks = _deletionCallbacks[conversationId] ?? [];
      for (final callback in callbacks) {
        callback(messageId);
      }
    } catch (e) {
      logInfo('❌ Error handling message delete: $e');
    }
  }

  /// Handle به‌روزرسانی پیام (UPDATE event)
  void _handleMessageUpdate(
    String conversationId,
    PostgresChangePayload payload,
    String currentUserId,
  ) {
    try {
      final updatedData = payload.newRecord;
      if (updatedData.isEmpty) return;

      final message = MessageModel.fromJson(
        updatedData,
        currentUserId: currentUserId,
      );

      // بررسی اگر پیام به صورت global حذف شده باشد
      if (message.deletedGlobally) {
        logInfo('🗑️ Message globally deleted via realtime: ${message.id}');
        // حذف از کش محلی
        _cacheService.deleteMessage(conversationId, message.id);

        // فراخوانی callback های حذف
        final deletionCallbacks = _deletionCallbacks[conversationId] ?? [];
        for (final callback in deletionCallbacks) {
          callback(message.id);
        }
      } else if (message.deletedForUserIds.isNotEmpty) {
        // پیام برای برخی کاربران حذف شده است
        logInfo('📝 Message updated (deletion flags): ${message.id}');

        // به‌روزرسانی در کش
        _cacheService.upsertMessage(message);

        // فراخوانی callback های به‌روزرسانی
        final updateCallbacks = _updateCallbacks[conversationId] ?? [];
        for (final callback in updateCallbacks) {
          callback(message);
        }
      }
    } catch (e) {
      logInfo('❌ Error handling message update: $e');
    }
  }

  /// Handle پیام جدید با throttling
  void _handleNewMessage(
    String conversationId,
    PostgresChangePayload payload,
    String currentUserId,
  ) {
    // لغو timer قبلی
    _throttleTimers[conversationId]?.cancel();

    // ساخت timer جدید
    _throttleTimers[conversationId] = Timer(_throttleDuration, () {
      try {
        final messageData = payload.newRecord;
        final message =
            MessageModel.fromJson(messageData, currentUserId: currentUserId);

        // ✅ فقط پیام‌های دیگران را نمایش بده (پیام‌های خودمان با temp system مدیریت میشوند)
        if (message.senderId != currentUserId) {
          print('📩 New message received: ${message.id}');

          // فراخوانی همه callback ها
          final callbacks = _messageCallbacks[conversationId] ?? [];
          for (final callback in callbacks) {
            callback(message);
          }
        }
      } catch (e) {
        print('❌ Error handling new message: $e');
      }
    });
  }

  /// Unsubscribe از یک conversation
  void unsubscribeFromConversation(
    String conversationId,
    Function(MessageModel) callback,
  ) {
    print('📡 Unsubscribing from conversation: $conversationId');

    // حذف callback
    _messageCallbacks[conversationId]?.remove(callback);

    // اگر دیگر callback ای نمانده، channel را ببند
    if (_messageCallbacks[conversationId]?.isEmpty ?? true) {
      _messageCallbacks.remove(conversationId);
      _activeChannels[conversationId]?.unsubscribe();
      _activeChannels.remove(conversationId);
      _throttleTimers[conversationId]?.cancel();
      _throttleTimers.remove(conversationId);
      print('✅ Fully unsubscribed from: $conversationId');
    }
  }

  /// Dispose همه چیز
  void dispose() {
    print('🧹 Disposing all realtime subscriptions...');
    for (final channel in _activeChannels.values) {
      channel.unsubscribe();
    }
    _activeChannels.clear();
    _messageCallbacks.clear();
    _deletionCallbacks.clear();
    _updateCallbacks.clear();
    for (final timer in _throttleTimers.values) {
      timer?.cancel();
    }
    _throttleTimers.clear();
  }
}
