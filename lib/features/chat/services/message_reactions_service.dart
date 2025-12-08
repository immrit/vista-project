// lib/features/chat/services/message_reactions_service.dart
//
// سرویس مدیریت واکنش‌های پیام
//

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_reaction.dart';

class MessageReactionsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// دریافت ID کاربر فعلی
  String? getCurrentUserId() {
    return _supabase.auth.currentUser?.id;
  }

  /// افزودن یا حذف واکنش به پیام (toggle)
  Future<MessageReaction?> toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    // 🔴 امکان واکنش به پیام‌های موقت وجود ندارد
    if (messageId.startsWith('temp_')) return null;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('کاربر احراز هویت نشده');

      // چک کنیم آیا قبلاً این ایموجی رو زده
      final existing = await _supabase
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existing != null) {
        // حذف واکنش
        await _supabase
            .from('message_reactions')
            .delete()
            .eq('id', existing['id']);
        return null;
      } else {
        // افزودن واکنش جدید
        final userProfile = await _supabase
            .from('profiles')
            .select('full_name, avatar_url')
            .eq('id', userId)
            .single();

        final data = {
          'message_id': messageId,
          'user_id': userId,
          'user_name': userProfile['full_name'] ?? 'کاربر',
          'user_avatar': userProfile['avatar_url'],
          'emoji': emoji,
        };

        final response = await _supabase
            .from('message_reactions')
            .insert(data)
            .select()
            .single();

        return MessageReaction.fromJson(response);
      }
    } catch (e) {
      debugPrint('❌ Error toggling reaction: $e');
      rethrow;
    }
  }

  /// دریافت تمام واکنش‌های یک پیام
  Future<List<MessageReaction>> getMessageReactions(String messageId) async {
    if (messageId.startsWith('temp_')) return [];

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
      debugPrint('❌ Error getting reactions: $e');
      return [];
    }
  }

  /// دریافت واکنش‌های چند پیام یکجا (batch)
  Future<Map<String, List<MessageReaction>>> getMultipleMessageReactions(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};

    // 🔴 فیلتر کردن IDهای موقت (که با temp_ شروع می‌شوند)
    // دیتابیس UUID انتظار دارد و ارسال رشته temp_ باعث کرش می‌شود
    final validIds = messageIds.where((id) => !id.startsWith('temp_')).toList();

    if (validIds.isEmpty) return {};

    try {
      final response = await _supabase
          .from('message_reactions')
          .select()
          .inFilter('message_id', validIds)
          .order('created_at', ascending: true);

      final Map<String, List<MessageReaction>> grouped = {};

      for (final json in response as List) {
        final reaction = MessageReaction.fromJson(json);
        grouped.putIfAbsent(reaction.messageId, () => []).add(reaction);
      }

      return grouped;
    } catch (e) {
      debugPrint('❌ Error getting multiple reactions: $e');
      return {};
    }
  }

  /// Stream برای دریافت real-time واکنش‌های یک پیام
  Stream<List<MessageReaction>> watchMessageReactions(String messageId) {
    if (messageId.startsWith('temp_')) return Stream.value([]);

    return _supabase
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .eq('message_id', messageId)
        .order('created_at')
        .map((data) =>
            data.map((json) => MessageReaction.fromJson(json)).toList());
  }

  /// حذف تمام واکنش‌های کاربر از یک پیام
  Future<void> removeAllUserReactions({
    required String messageId,
  }) async {
    if (messageId.startsWith('temp_')) return;

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('❌ Error removing user reactions: $e');
    }
  }

  /// حذف تمام واکنش‌های یک پیام (وقتی پیام حذف میشه)
  Future<void> deleteAllMessageReactions(String messageId) async {
    if (messageId.startsWith('temp_')) return;

    try {
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId);
    } catch (e) {
      debugPrint('❌ Error deleting all reactions: $e');
    }
  }

  /// دریافت آماری از واکنش‌های یک کاربر
  Future<Map<String, int>> getUserReactionStats(String userId) async {
    try {
      final response = await _supabase
          .from('message_reactions')
          .select('emoji')
          .eq('user_id', userId);

      final Map<String, int> stats = {};
      for (final row in response as List) {
        final emoji = row['emoji'] as String;
        stats[emoji] = (stats[emoji] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting reaction stats: $e');
      return {};
    }
  }
}
