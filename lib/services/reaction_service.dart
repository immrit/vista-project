import '../security/logging_utility.dart';
import '../utils/const.dart';
import '../model/message_reaction.dart';

/// سرویس مدیریت ری‌اکشن‌های پیام‌ها مانند توییتر
class ReactionService {
  static final ReactionService _instance = ReactionService._internal();
  factory ReactionService() => _instance;
  ReactionService._internal();

  /// لیست ایموجی‌های پیشنهادی برای ری‌اکشن
  static const List<String> defaultEmojis = [
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '😡',
    '🎉',
    '🔥',
    '👏',
    '💯'
  ];

  /// اضافه کردن ری‌اکشن به پیام
  Future<MessageReaction?> addReaction({
    required String messageId,
    required String conversationId,
    required String userId,
    required String emoji,
  }) async {
    try {
      // بررسی اینکه کاربر قبلاً این ری‌اکشن را نداده باشد
      final existingReactions = await _getMessageReactions(messageId);
      final existingReaction = existingReactions
          .where((r) => r.userId == userId && r.emoji == emoji)
          .firstOrNull;

      if (existingReaction != null) {
        logInfo('⚠️ کاربر قبلاً این ری‌اکشن را داده است');
        return null;
      }

      // اضافه کردن ری‌اکشن جدید
      final response = await supabase
          .from('message_reactions')
          .insert({
            'message_id': messageId,
            'conversation_id': conversationId,
            'user_id': userId,
            'emoji': emoji,
          })
          .select()
          .single();

      final reaction = MessageReaction.fromJson(response);
      logInfo('✅ ری‌اکشن اضافه شد: ${reaction.emoji} به پیام $messageId');

      return reaction;
    } catch (e) {
      logInfo('⚠️ خطا در اضافه کردن ری‌اکشن: $e');
      return null;
    }
  }

  /// حذف ری‌اکشن از پیام
  Future<bool> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    try {
      final result = await supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji);

      if (result != null) {
        logInfo('✅ ری‌اکشن حذف شد: $emoji از پیام $messageId');
        return true;
      }
      return false;
    } catch (e) {
      logInfo('⚠️ خطا در حذف ری‌اکشن: $e');
      return false;
    }
  }

  /// دریافت تمام ری‌اکشن‌های یک پیام
  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    try {
      final response = await supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .order('created_at', ascending: true);

      return (response as List<dynamic>)
          .map((json) => MessageReaction.fromJson(json))
          .toList();
    } catch (e) {
      logInfo('⚠️ خطا در دریافت ری‌اکشن‌های پیام: $e');
      return [];
    }
  }

  /// دریافت ری‌اکشن‌های کاربر برای یک پیام
  Future<MessageReaction?> getUserReaction(
      String messageId, String userId) async {
    try {
      final response = await supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        return MessageReaction.fromJson(response);
      }
      return null;
    } catch (e) {
      logInfo('⚠️ خطا در دریافت ری‌اکشن کاربر: $e');
      return null;
    }
  }

  /// تغییر ری‌اکشن کاربر (حذف قبلی و اضافه کردن جدید)
  Future<MessageReaction?> toggleReaction({
    required String messageId,
    required String conversationId,
    required String userId,
    required String newEmoji,
  }) async {
    try {
      // بررسی ری‌اکشن فعلی کاربر
      final currentReaction = await getUserReaction(messageId, userId);

      if (currentReaction != null) {
        if (currentReaction.emoji == newEmoji) {
          // اگر همان ایموجی است، حذف کن
          await removeReaction(
            messageId: messageId,
            userId: userId,
            emoji: newEmoji,
          );
          return null;
        } else {
          // اگر ایموجی متفاوتی است، قبلی را حذف و جدید را اضافه کن
          await removeReaction(
            messageId: messageId,
            userId: userId,
            emoji: currentReaction.emoji,
          );
        }
      }

      // اضافه کردن ری‌اکشن جدید
      return await addReaction(
        messageId: messageId,
        conversationId: conversationId,
        userId: userId,
        emoji: newEmoji,
      );
    } catch (e) {
      logInfo('⚠️ خطا در تغییر ری‌اکشن: $e');
      return null;
    }
  }

  /// دریافت ری‌اکشن‌های یک مکالمه
  Future<Map<String, List<MessageReaction>>> getConversationReactions(
      String conversationId) async {
    try {
      final response = await supabase
          .from('message_reactions')
          .select('*, messages!inner(*)')
          .eq('conversation_id', conversationId);

      final reactions = (response as List<dynamic>)
          .map((json) => MessageReaction.fromJson(json))
          .toList();

      // گروه‌بندی بر اساس message_id
      final groupedReactions = <String, List<MessageReaction>>{};
      for (final reaction in reactions) {
        groupedReactions[reaction.messageId] ??= [];
        groupedReactions[reaction.messageId]!.add(reaction);
      }

      return groupedReactions;
    } catch (e) {
      logInfo('⚠️ خطا در دریافت ری‌اکشن‌های مکالمه: $e');
      return {};
    }
  }

  /// دریافت آمار ری‌اکشن‌ها برای یک پیام
  Future<Map<String, int>> getReactionStats(String messageId) async {
    try {
      final reactions = await getMessageReactions(messageId);
      final stats = <String, int>{};

      for (final reaction in reactions) {
        stats[reaction.emoji] = (stats[reaction.emoji] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      logInfo('⚠️ خطا در دریافت آمار ری‌اکشن‌ها: $e');
      return {};
    }
  }

  /// حذف تمام ری‌اکشن‌های یک پیام
  Future<void> deleteMessageReactions(String messageId) async {
    try {
      await supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId);

      logInfo('✅ تمام ری‌اکشن‌های پیام $messageId حذف شدند');
    } catch (e) {
      logInfo('⚠️ خطا در حذف ری‌اکشن‌های پیام: $e');
    }
  }

  // متد کمکی برای دریافت ری‌اکشن‌ها
  Future<List<MessageReaction>> _getMessageReactions(String messageId) async {
    return getMessageReactions(messageId);
  }
}
