import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/conversation_model.dart';
import '../model/channel_model.dart';
import 'chat_provider.dart';
import 'channel_provider.dart';

// پرووایدر برای نمایش ترکیبی چت‌ها و کانال‌ها
final combinedMessagesProvider =
    FutureProvider<CombinedMessagesState>((ref) async {
  final conversationsAsync = await ref.watch(conversationsProvider.future);
  final channelsAsync = await ref.watch(channelsProvider.future);

  final conversations = conversationsAsync ?? [];
  final channels = channelsAsync ?? [];

  return CombinedMessagesState(
    conversations: conversations,
    channels: channels,
    hasUnreadConversations: conversations.any((c) => c.hasUnreadMessages),
    hasUnreadChannels: channels.any((c) => !c.isSubscribed),
  );
});

// کلاس برای نگهداری وضعیت ترکیبی
class CombinedMessagesState {
  final List<ConversationModel> conversations;
  final List<ChannelModel> channels;
  final bool hasUnreadConversations;
  final bool hasUnreadChannels;

  CombinedMessagesState({
    required this.conversations,
    required this.channels,
    required this.hasUnreadConversations,
    required this.hasUnreadChannels,
  });
}
