import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/conversation_model.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';

// سرویس چت
final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService();
});

// لیست مکالمات
final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getConversations();
});

// استریم مکالمات برای بروزرسانی خودکار
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.subscribeToConversations();
});

// پیام‌های یک مکالمه
final messagesProvider = FutureProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) async {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.getMessages(conversationId);
});

// استریم پیام‌های یک مکالمه
final messagesStreamProvider = StreamProvider.family
    .autoDispose<List<MessageModel>, String>((ref, conversationId) {
  final chatService = ref.watch(chatServiceProvider);
  return chatService.subscribeToMessages(conversationId);
});

// پرووایدر برای بررسی پیام‌های جدید
final hasNewMessagesProvider = FutureProvider.autoDispose<bool>((ref) async {
  final conversationsAsync = ref.watch(conversationsProvider);
  return conversationsAsync.when(
    data: (conversations) {
      return conversations
          .any((conversation) => conversation.hasUnreadMessages);
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

// کنترل‌کننده برای ارسال پیام
class MessageNotifier extends StateNotifier<AsyncValue<void>> {
  MessageNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      // بروزرسانی پیام‌ها
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markConversationAsRead(conversationId);

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);
    } catch (e) {
      // خطا را نادیده می‌گیریم
    }
  }

  Future<ConversationModel> createConversation(String otherUserId) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.createConversation(otherUserId);

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
      return conversation;
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final messageNotifierProvider =
    StateNotifierProvider.autoDispose<MessageNotifier, AsyncValue<void>>((ref) {
  return MessageNotifier(ref);
});
