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

// پرووایدر پیام‌های کانال
final channelMessagesProvider =
    StreamProvider.family<List<ChannelMessageModel>, String>((ref, channelId) {
  final channelService = ref.read(channelServiceProvider);
  return channelService.subscribeToChannelMessages(channelId);
});

// نوتیفایر برای مدیریت عملیات‌های کانال
class ChannelNotifier extends StateNotifier<AsyncValue<void>> {
  final ChannelService _channelService;

  ChannelNotifier(this._channelService) : super(const AsyncValue.data(null));

  Future<void> createChannel({
    required String name,
    String? description,
    String? username,
    bool isPrivate = false,
    File? avatarFile,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.createChannel(
        name: name,
        description: description,
        username: username,
        isPrivate: isPrivate,
        avatarFile: avatarFile,
      );
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      throw e;
    }
  }

  Future<void> joinChannel(String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.joinChannel(channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      throw e;
    }
  }

  Future<void> leaveChannel(String channelId) async {
    state = const AsyncValue.loading();
    try {
      await _channelService.leaveChannel(channelId);
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      throw e;
    }
  }

  Future<void> sendMessage({
    required String channelId,
    required String content,
    String? replyToMessageId,
  }) async {
    try {
      await _channelService.sendChannelMessage(
        channelId: channelId,
        content: content,
        replyToMessageId: replyToMessageId,
      );
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }
}

final channelProvider =
    StateNotifierProvider<ChannelNotifier, AsyncValue<void>>((ref) {
  return ChannelNotifier(ref.read(channelServiceProvider));
});
