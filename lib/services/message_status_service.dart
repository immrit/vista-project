import '../main.dart';

/// سرویس مدیریت وضعیت پیام‌ها (delivered, seen)
class MessageStatusService {
  static final MessageStatusService _instance =
      MessageStatusService._internal();
  factory MessageStatusService() => _instance;
  MessageStatusService._internal();

  /// علامت‌گذاری پیام به عنوان delivered
  Future<void> markMessageAsDelivered(
      String messageId, String conversationId) async {
    try {
      await supabase.from('messages').update({
        'is_delivered': true,
        'delivered_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      print('✅ پیام $messageId به عنوان delivered علامت‌گذاری شد');
    } catch (e) {
      print('⚠️ خطا در علامت‌گذاری پیام به عنوان delivered: $e');
    }
  }

  /// علامت‌گذاری پیام به عنوان seen
  Future<void> markMessageAsSeen(
      String messageId, String conversationId) async {
    try {
      await supabase.from('messages').update({
        'is_seen': true,
        'seen_at': DateTime.now().toIso8601String(),
      }).eq('id', messageId);

      print('✅ پیام $messageId به عنوان seen علامت‌گذاری شد');
    } catch (e) {
      print('⚠️ خطا در علامت‌گذاری پیام به عنوان seen: $e');
    }
  }

  /// علامت‌گذاری چندین پیام به عنوان seen
  Future<void> markMessagesAsSeen(
      List<String> messageIds, String conversationId) async {
    try {
      if (messageIds.isEmpty) return;

      await supabase.from('messages').update({
        'is_seen': true,
        'seen_at': DateTime.now().toIso8601String(),
      }).inFilter('id', messageIds);

      print('✅ ${messageIds.length} پیام به عنوان seen علامت‌گذاری شدند');
    } catch (e) {
      print('⚠️ خطا در علامت‌گذاری پیام‌ها به عنوان seen: $e');
    }
  }

  /// دریافت وضعیت پیام‌ها در یک مکالمه
  Future<Map<String, dynamic>> getMessageStatuses(
      String conversationId, String currentUserId) async {
    try {
      final response = await supabase
          .from('messages')
          .select('id, is_delivered, is_seen, sender_id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', currentUserId) // فقط پیام‌های دریافتی
          .order('created_at', ascending: false);

      final messages = response as List<dynamic>;

      final undeliveredCount = messages
          .where((msg) =>
              msg['is_delivered'] == false || msg['is_delivered'] == null)
          .length;

      final unseenCount = messages
          .where((msg) => msg['is_seen'] == false || msg['is_seen'] == null)
          .length;

      return {
        'undelivered_count': undeliveredCount,
        'unseen_count': unseenCount,
        'total_unread': undeliveredCount + unseenCount,
      };
    } catch (e) {
      print('⚠️ خطا در دریافت وضعیت پیام‌ها: $e');
      return {
        'undelivered_count': 0,
        'unseen_count': 0,
        'total_unread': 0,
      };
    }
  }
}
