import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';
import '../services/channel_service.dart';
import 'dart:io';

// پرووایدر سرویس کانال
final channelServiceProvider = Provider<ChannelService>((ref) {
  return ChannelService();
});

// پرووایدر لیست کانال‌ها
final channelsProvider = FutureProvider<List<ChannelModel>>((ref) async {
  final channelService = ref.read(channelServiceProvider);
  return await channelService.getChannels();
});

// پرووایدر برای دریافت یک کانال خاص
final channelProvider =
    FutureProvider.family<ChannelModel?, String>((ref, channelId) async {
  final channelService = ref.read(channelServiceProvider);
  return await channelService.getChannel(channelId);
});

// پرووایدر برای دریافت پیام‌های کانال
final channelMessagesProvider =
    FutureProvider.family<List<ChannelMessageModel>, String>(
        (ref, channelId) async {
  final channelService = ref.read(channelServiceProvider);
  return await channelService.getChannelMessages(channelId);
});

// نوتیفایر برای مدیریت عملیات‌های کانال
class ChannelNotifier extends StateNotifier<AsyncValue<void>> {
  final ChannelService _channelService;

  ChannelNotifier(this._channelService) : super(const AsyncValue.data(null));

  Future<ChannelModel> createChannel({
    required String name,
    String? description,
    required String username,
    bool isPrivate = false,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    try {
      final channel = await _channelService.createChannel(
        name: name,
        description: description,
        username: username,
        isPrivate: isPrivate,
        avatarFile: avatarFile,
      );
      state = const AsyncValue.data(null);
      return channel;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  // ✅ بروزرسانی متد sendMessage
  Future<ChannelMessageModel> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
    File? imageFile,
  }) async {
    try {
      return await _channelService.sendMessage(
        channelId: channelId,
        content: content,
        replyToMessageId: replyToMessageId,
        imageFile: imageFile,
      );
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  Future<void> leaveChannel(String channelId) async {
    try {
      await _channelService.leaveChannel(channelId);

      // بروزرسانی لیست کانال‌ها
      await loadChannels();

      // پاک کردن کش کانال
      await _channelService.clearChannelCache(channelId);
    } catch (e) {
      print('Error in leaveChannel: $e');
      rethrow;
    }
  }

  Future<void> loadChannels() async {
    try {
      await _channelService.getChannels();
      state = const AsyncValue.data(null);
    } catch (e) {
      print('Error loading channels: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  // رفرش کردن لیست کانال‌ها
  Future<List<ChannelModel>> refreshChannels() async {
    try {
      return await _channelService.getChannels(forceRefresh: true);
    } catch (e) {
      print('خطا در رفرش کانال‌ها: $e');
      rethrow;
    }
  }

  // رفرش کردن یک کانال خاص
  Future<ChannelModel?> refreshChannel(String channelId) async {
    try {
      return await _channelService.getChannel(channelId, forceRefresh: true);
    } catch (e) {
      print('خطا در رفرش کانال $channelId: $e');
      rethrow;
    }
  }

  // پاک کردن کش
  Future<void> clearCache() async {
    try {
      await _channelService.clearCache();
    } catch (e) {
      print('خطا در پاک کردن کش: $e');
    }
  }

  // دریافت آمار کش
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      return await _channelService.getCacheStats();
    } catch (e) {
      print('خطا در دریافت آمار کش: $e');
      return {};
    }
  }

  Future<void> joinChannel(String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.joinChannel(channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final channelNotifierProvider =
    StateNotifierProvider<ChannelNotifier, AsyncValue<void>>((ref) {
  return ChannelNotifier(ref.read(channelServiceProvider));
});
