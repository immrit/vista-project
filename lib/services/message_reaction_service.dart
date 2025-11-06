import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../model/message_reaction.dart';
import '../security/logging_utility.dart';

class MessageReactionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Stream برای real-time updates
  final Map<String, StreamSubscription> _reactionStreams = {};

  /// اضافه کردن یا حذف reaction (Toggle)
  Future<bool> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo('❌ کاربر وارد نشده است');
      return false;
    }

    try {
      logInfo('🔄 شروع toggle reaction: messageId=$messageId, emoji=$emoji, userId=$userId');
      
      // چک کردن آیا قبلاً این reaction را داده است
      final existingReaction = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      logInfo('🔍 بررسی reaction موجود: ${existingReaction != null ? "یافت شد" : "یافت نشد"}');

      if (existingReaction != null) {
        // اگر همان emoji بود، حذف کن (Toggle off)
        logInfo('🗑️ حذف reaction موجود: $emoji');
        final deleteResult = await _supabase
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', userId)
            .eq('emoji', emoji);

        logInfo('✅ Reaction حذف شد: $emoji, result: $deleteResult');
        return false; // reaction حذف شد
      } else {
        // حذف reactions قبلی کاربر برای این پیام (یک کاربر فقط یک reaction)
        logInfo('🗑️ حذف reactions قبلی کاربر برای این پیام');
        final deleteResult = await _supabase
            .from('message_reactions')
            .delete()
            .eq('message_id', messageId)
            .eq('user_id', userId);
        
        logInfo('✅ Reactions قبلی حذف شد: $deleteResult');

        // اضافه کردن reaction جدید
        logInfo('➕ اضافه کردن reaction جدید: $emoji');
        final insertData = {
          'message_id': messageId,
          'conversation_id': conversationId,
          'user_id': userId,
          'emoji': emoji,
        };
        
        logInfo('📝 داده‌های insert: $insertData');
        
        // استفاده از insert ساده (چون قبلاً reactions قبلی را حذف کردیم)
        // اگر constraint unique (message_id, user_id) مشکل ایجاد کند، از upsert استفاده می‌کنیم
        try {
          final insertResult = await _supabase
              .from('message_reactions')
              .insert(insertData)
              .select();

          logInfo('✅ Reaction جدید اضافه شد: $emoji, result: $insertResult');
        } catch (insertError) {
          // اگر خطای unique constraint رخ داد، از upsert استفاده کن
          logInfo('⚠️ خطا در insert، تلاش با upsert: $insertError');
          final upsertResult = await _supabase
              .from('message_reactions')
              .upsert(
                insertData,
                onConflict: 'message_id,user_id',
              )
              .select();
          
          logInfo('✅ Reaction با upsert اضافه شد: $emoji, result: $upsertResult');
        }
        return true; // reaction اضافه شد
      }
    } catch (e, stackTrace) {
      logInfo('❌ خطا در toggle reaction: $e');
      logInfo('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// افزودن reaction به پیام
  Future<bool> addReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo('❌ کاربر وارد نشده است');
      return false;
    }

    try {
      // چک کنیم که آیا قبلاً این reaction را داده یا نه
      final existing = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existing != null) {
        // اگر قبلاً داده، حذفش کن (toggle)
        await removeReaction(
          messageId: messageId,
          conversationId: conversationId,
          emoji: emoji,
        );
        return false;
      }

      // حذف reactions قبلی کاربر برای این پیام (یک کاربر فقط یک reaction)
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);

      // افزودن reaction جدید
      await _supabase.from('message_reactions').insert({
        'message_id': messageId,
        'conversation_id': conversationId,
        'user_id': userId,
        'emoji': emoji,
      });

      logInfo('✅ ری‌اکشن $emoji به پیام $messageId اضافه شد');
      return true;
    } catch (e) {
      logInfo('❌ خطا در افزودن ری‌اکشن: $e');
      return false;
    }
  }

  /// حذف reaction از پیام
  Future<void> removeReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);

      logInfo('✅ ری‌اکشن $emoji از پیام $messageId حذف شد');
    } catch (e) {
      logInfo('❌ خطا در حذف ری‌اکشن: $e');
    }
  }

  /// دریافت reactions یک پیام به صورت Map<String, List<String>>
  Future<Map<String, List<String>>> getMessageReactionsSummary(String messageId) async {
    try {
      final response = await _supabase
          .from('message_reactions')
          .select('emoji, user_id')
          .eq('message_id', messageId);

      final Map<String, List<String>> reactions = {};

      for (var item in response) {
        final emoji = item['emoji'] as String;
        final userId = item['user_id'] as String;

        reactions[emoji] ??= [];
        reactions[emoji]!.add(userId);
      }

      return reactions;
    } catch (e) {
      logInfo('❌ خطا در دریافت reactions: $e');
      return {};
    }
  }

  /// دریافت تمام reactions یک پیام
  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    try {
      final response = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => MessageReaction.fromJson(json))
          .toList();
    } catch (e) {
      logInfo('❌ خطا در دریافت reactions: $e');
      return [];
    }
  }

  /// Stream برای تغییرات Realtime reactions یک مکالمه
  Stream<List<MessageReaction>> watchConversationReactions(String conversationId) {
    return _supabase
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((data) => data
            .map((json) => MessageReaction.fromJson(json))
            .toList());
  }

  /// شروع گوش دادن به تغییرات ری‌اکشن برای یک مکالمه
  void listenToReactions(String conversationId) {
    // اگر قبلاً داریم گوش می‌دیم، دوباره نکن
    if (_reactionStreams.containsKey(conversationId)) return;

    final channel = _supabase.channel('reactions_$conversationId');

    final subscription = channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message_reactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            logInfo('🔔 تغییر ری‌اکشن دریافت شد: ${payload.eventType}');
          },
        )
        .subscribe();

    _reactionStreams[conversationId] = subscription as StreamSubscription;
    logInfo('🎧 شروع گوش دادن به ری‌اکشن‌های مکالمه $conversationId');
  }

  /// توقف گوش دادن به تغییرات
  void stopListening(String conversationId) {
    _reactionStreams[conversationId]?.cancel();
    _reactionStreams.remove(conversationId);
    logInfo('🔇 توقف گوش دادن به ری‌اکشن‌های مکالمه $conversationId');
  }

  /// پاکسازی تمام listener ها
  void dispose() {
    for (var subscription in _reactionStreams.values) {
      subscription.cancel();
    }
    _reactionStreams.clear();
  }
}



