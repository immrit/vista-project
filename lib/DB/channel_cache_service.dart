import 'package:hive/hive.dart';
import '../model/channel_model.dart';
import '../model/channel_message_model.dart';

class ChannelCacheService {
  static const String _channelsBoxName = 'channels';
  static const String _channelMessagesBoxName = 'channel_messages';
  static const String _channelMembersBoxName = 'channel_members';

  Future<Box> _getChannelsBox() async {
    return await Hive.openBox(_channelsBoxName);
  }

  Future<Box> _getMessagesBox() async {
    return await Hive.openBox(_channelMessagesBoxName);
  }

  Future<Box> _getMembersBox() async {
    return await Hive.openBox(_channelMembersBoxName);
  }

  // کش کردن کانال
  Future<void> cacheChannel(ChannelModel channel) async {
    final box = await _getChannelsBox();
    await box.put(channel.id, channel.toJson());
  }

  // دریافت کانال‌های کش شده
  Future<List<ChannelModel>> getCachedChannels() async {
    final box = await _getChannelsBox();
    return box.values
        .map((data) => ChannelModel.fromJson(Map<String, dynamic>.from(data)))
        .toList();
  }

  // دریافت یک کانال خاص
  Future<ChannelModel?> getChannel(String channelId) async {
    final box = await _getChannelsBox();
    final data = box.get(channelId);
    if (data != null) {
      return ChannelModel.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  // کش کردن پیام کانال
  Future<void> cacheChannelMessage(
      String channelId, ChannelMessageModel message) async {
    final box = await _getMessagesBox();
    final messages = box.get(channelId, defaultValue: []) as List;
    messages.add(message.toJson());
    await box.put(channelId, messages);
  }

  // دریافت پیام‌های کانال
  Future<List<ChannelMessageModel>> getChannelMessages(String channelId) async {
    final box = await _getMessagesBox();
    final messages = box.get(channelId, defaultValue: []) as List;
    return messages
        .map((json) =>
            ChannelMessageModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // پاک کردن کش کانال
  Future<void> clearChannelCache(String channelId) async {
    final channelsBox = await _getChannelsBox();
    final messagesBox = await _getMessagesBox();
    final membersBox = await _getMembersBox();

    await channelsBox.delete(channelId);
    await messagesBox.delete(channelId);
    await membersBox.delete(channelId);
  }

  // پاک کردن همه کش‌ها
  Future<void> clearAllCache() async {
    final channelsBox = await _getChannelsBox();
    final messagesBox = await _getMessagesBox();
    final membersBox = await _getMembersBox();

    await channelsBox.clear();
    await messagesBox.clear();
    await membersBox.clear();
  }
}
