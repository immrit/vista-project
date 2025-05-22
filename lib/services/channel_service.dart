import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';
import '../DB/channel_cache_service.dart';
import '/main.dart';
import 'uploadImageChatService.dart';

class ChannelService {
  final SupabaseClient _supabase = supabase;
  final ChannelCacheService _cache = ChannelCacheService();

  // دریافت لیست کانال‌ها
  Future<List<ChannelModel>> getChannels() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // اصلاح کوئری برای دریافت role
      final response = await _supabase
          .from('channel_members')
          .select('channel_id, role, channels!inner(*)')
          .eq('user_id', userId);

      print('Channel members response: $response'); // برای دیباگ

      return response.map<ChannelModel>((data) {
        final channelData = data['channels'] as Map<String, dynamic>;
        // اضافه کردن member_role به channelData
        channelData['member_role'] = data['role'];
        return ChannelModel.fromJson(channelData, currentUserId: userId);
      }).toList();
    } catch (e) {
      print('Error fetching channels: $e');
      rethrow;
    }
  }

  // به‌روزرسانی کش کانال‌ها
  Future<void> _refreshChannelsCache(String userId) async {
    try {
      final response = await _supabase
          .from('channel_members')
          .select('*, channels(*)')
          .eq('user_id', userId);

      final channels = response.map<ChannelModel>((data) {
        final channelData = data['channels'] as Map<String, dynamic>;
        return ChannelModel.fromJson(channelData, currentUserId: userId);
      }).toList();

      for (var channel in channels) {
        await _cache.cacheChannel(channel);
      }
    } catch (e) {
      print('Error refreshing channels cache: $e');
    }
  }

  Future<ChannelModel> createChannel({
    required String name,
    String? description,
    String? username,
    bool isPrivate = false,
    File? avatarFile,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // ایجاد کانال
      final channelResponse = await _supabase
          .from('channels')
          .insert({
            'creator_id': userId,
            'name': name,
            'description': description,
            'username': username,
            'is_private': isPrivate,
            'member_count': 1,
          })
          .select()
          .single();

      // افزودن سازنده به عنوان اولین عضو با نقش owner
      await _supabase.from('channel_members').insert({
        'channel_id': channelResponse['id'],
        'user_id': userId,
        'role': 'owner',
      });

      return ChannelModel.fromJson(channelResponse, currentUserId: userId);
    } catch (e) {
      print('Error creating channel: $e');
      throw e;
    }
  }

  Future<void> joinChannel(String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // افزودن کاربر به کانال
      await _supabase.from('channel_members').insert({
        'channel_id': channelId,
        'user_id': userId,
        'role': 'member',
      });

      // افزایش تعداد اعضا
      await _supabase.rpc('increment_channel_member_count',
          params: {'channel_id_param': channelId});
    } catch (e) {
      print('Error joining channel: $e');
      throw e;
    }
  }

  Future<void> leaveChannel(String channelId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // حذف کاربر از کانال
      await _supabase
          .from('channel_members')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', userId);

      // کاهش تعداد اعضا
      await _supabase.rpc('decrement_channel_member_count',
          params: {'channel_id_param': channelId});
    } catch (e) {
      print('Error leaving channel: $e');
      throw e;
    }
  }

  Future<List<ChannelMessageModel>> getChannelMessages(String channelId,
      {int limit = 20}) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('channel_messages')
          .select('*, profiles!sender_id(username, avatar_url)')
          .eq('channel_id', channelId)
          .order('created_at', ascending: false)
          .limit(limit);

      return response.map<ChannelMessageModel>((message) {
        final profile = message['profiles'] as Map<String, dynamic>;
        return ChannelMessageModel.fromJson(message, currentUserId: userId)
            .copyWith(
          senderName: profile['username'],
          senderAvatar: profile['avatar_url'],
        );
      }).toList();
    } catch (e) {
      print('Error fetching channel messages: $e');
      throw e;
    }
  }

  // استریم پیام‌های کانال
  Stream<List<ChannelMessageModel>> subscribeToChannelMessages(
      String channelId) {
    return _supabase
        .from('channel_messages')
        .stream(primaryKey: ['id'])
        .eq('channel_id', channelId)
        .order('created_at')
        .map((messages) {
          return messages
              .map((message) => ChannelMessageModel.fromJson(message))
              .toList();
        });
  }

  Future<void> sendChannelMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
  }) async {
    try {
      await _supabase.from('channel_messages').insert({
        'channel_id': channelId,
        'sender_id': _supabase.auth.currentUser!.id,
        'content': content,
        'reply_to_message_id': replyToMessageId,
      });
    } catch (e) {
      print('Error sending channel message: $e');
      throw e;
    }
  }
}
