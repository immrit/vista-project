import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/message_model.dart';
import '../main.dart';

class CentralizedRealtimeManager {
  static final CentralizedRealtimeManager _instance = CentralizedRealtimeManager._internal();
  factory CentralizedRealtimeManager() => _instance;
  CentralizedRealtimeManager._internal();

  // نگهداری subscription ها به ازای هر conversation
  final Map<String, RealtimeChannel> _activeChannels = {};

  // نگهداری callback ها
  final Map<String, List<Function(MessageModel)>> _messageCallbacks = {};

  // Throttling برای prevent spam
  final Map<String, Timer?> _throttleTimers = {};
  static const _throttleDuration = Duration(milliseconds: 100);

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

    // ساخت channel جدید
    final channel = supabase
        .channel('messages:$conversationId')
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
        .subscribe();

    _activeChannels[conversationId] = channel;
    print('✅ Subscribed to conversation: $conversationId');
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
        final message = MessageModel.fromJson(messageData, currentUserId: currentUserId);

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
    for (final timer in _throttleTimers.values) {
      timer?.cancel();
    }
    _throttleTimers.clear();
  }
}















