// lib/features/chat/services/typing_indicator_service.dart
//
// سرویس مدیریت Typing Indicator
//
// ویژگی‌ها:
// ✅ ارسال وضعیت "در حال تایپ" به سرور
// ✅ دریافت Realtime وضعیت تایپ طرف مقابل
// ✅ Timeout خودکار (بعد 3 ثانیه)
// ✅ مدیریت Channels برای Cleanup

import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class TypingIndicatorService {
  final SupabaseClient _supabase;

  // ✅ نگهداری channel ها برای cleanup
  final Map<String, RealtimeChannel> _activeChannels = {};

  // ✅ Timer برای خاموش کردن خودکار
  Timer? _typingTimer;

  // ✅ Debounce برای جلوگیری از ارسال زیاد
  Timer? _debounceTimer;

  // ✅ وضعیت فعلی
  String? _currentConversationId;
  bool _isCurrentlyTyping = false;

  TypingIndicatorService(this._supabase);

  /// شروع تایپ کردن
  /// 
  /// این متد باید هر بار که کاربر کاراکتر تایپ می‌کنه صدا زده بشه
  /// خودش debounce داره و زیاد به سرور request نمیزنه
  Future<void> startTyping(String conversationId) async {
    // Debounce - فقط هر 500ms یکبار ارسال کن
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _sendTypingStatus(conversationId, true);
    });

    // ✅ Reset کردن timer توقف
    _resetStopTimer(conversationId);
  }

  /// ارسال وضعیت تایپ به سرور
  Future<void> _sendTypingStatus(String conversationId, bool isTyping) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // جلوگیری از ارسال duplicate
      if (_currentConversationId == conversationId && 
          _isCurrentlyTyping == isTyping) {
        return;
      }

      print('⌨️ [Typing] Sending status: $isTyping for: $conversationId');

      // ✅ استفاده از Broadcast Channel (سریع‌تر از database)
      final channel = _getOrCreateChannel(conversationId);
      
      await channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'user_id': userId,
          'is_typing': isTyping,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );

      _currentConversationId = conversationId;
      _isCurrentlyTyping = isTyping;

    } catch (e) {
      print('❌ [Typing] Error sending status: $e');
    }
  }

  /// Reset کردن timer توقف
  void _resetStopTimer(String conversationId) {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      stopTyping(conversationId);
    });
  }

  /// توقف تایپ کردن
  Future<void> stopTyping(String conversationId) async {
    _debounceTimer?.cancel();
    _typingTimer?.cancel();
    
    if (_isCurrentlyTyping) {
      await _sendTypingStatus(conversationId, false);
    }
    
    _isCurrentlyTyping = false;
    _currentConversationId = null;
  }

  /// دریافت یا ساخت Channel
  RealtimeChannel _getOrCreateChannel(String conversationId) {
    if (_activeChannels.containsKey(conversationId)) {
      return _activeChannels[conversationId]!;
    }

    final channel = _supabase.channel('typing:$conversationId');
    _activeChannels[conversationId] = channel;
    
    return channel;
  }

  /// دریافت Realtime وضعیت تایپ طرف مقابل
  /// 
  /// این Stream همیشه وضعیت فعلی رو emit می‌کنه
  /// و به تغییرات Realtime گوش میده
  Stream<bool> watchTypingStatus({
    required String conversationId,
    required String otherUserId,
  }) {
    print('👀 [Typing] Watching status for user: $otherUserId');

    final controller = StreamController<bool>.broadcast();
    Timer? autoStopTimer;

    // ✅ شروع با false
    controller.add(false);

    // ✅ Subscribe به Broadcast channel
    final channel = _supabase
        .channel('typing:$conversationId')
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            try {
              final userId = payload['user_id'] as String?;
              final isTyping = payload['is_typing'] as bool? ?? false;

              // فقط وضعیت طرف مقابل رو نشون بده (نه خودمون!)
              if (userId == otherUserId) {
                print('📬 [Typing] Received: isTyping=$isTyping from $userId');
                controller.add(isTyping);

                // ✅ Auto-stop بعد از 5 ثانیه اگه پیام جدید نیومد
                autoStopTimer?.cancel();
                if (isTyping) {
                  autoStopTimer = Timer(const Duration(seconds: 5), () {
                    if (!controller.isClosed) {
                      controller.add(false);
                    }
                  });
                }
              }
            } catch (e) {
              print('❌ [Typing] Error processing: $e');
            }
          },
        )
        .subscribe();

    // ✅ Cleanup وقتی stream بسته شد
    controller.onCancel = () {
      print('🧹 [Typing] Stream cancelled');
      autoStopTimer?.cancel();
      _supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  /// پاکسازی همه منابع
  void dispose() {
    print('🧹 [Typing] Disposing service...');
    
    _typingTimer?.cancel();
    _debounceTimer?.cancel();

    for (final channel in _activeChannels.values) {
      _supabase.removeChannel(channel);
    }
    _activeChannels.clear();
    
    _isCurrentlyTyping = false;
    _currentConversationId = null;
  }
}

