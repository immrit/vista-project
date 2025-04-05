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

// پرووایدر برای MessageNotifier
final messageNotifierProvider =
    StateNotifierProvider.autoDispose<MessageNotifier, AsyncValue<void>>((ref) {
  return MessageNotifier(ref);
});

// کنترل‌کننده برای ارسال پیام
class MessageNotifier extends StateNotifier<AsyncValue<void>> {
  MessageNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> deleteConversation(String conversationId) async {
    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.deleteConversation(conversationId);

      // بروزرسانی لیست مکالمات
      ref.invalidate(conversationsProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    if (_disposed) return;

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);

      // اضافه کردن لاگ برای تشخیص مشکل
      print('MessageNotifier: ارسال پیام به $conversationId');

      await chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      if (_disposed) return;

      // بروزرسانی پیام‌ها
      ref.invalidate(messagesProvider(conversationId));
      ref.invalidate(conversationsProvider);

      if (_disposed) return;
      state = const AsyncValue.data(null);
    } catch (e, stack) {
      print('MessageNotifier: خطا در ارسال پیام: $e');
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> markAsRead(String conversationId) async {
    if (_disposed) return;

    try {
      final chatService = ref.read(chatServiceProvider);
      await chatService.markConversationAsRead(conversationId);

      if (_disposed) return;

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);
    } catch (e) {
      print('خطا در علامت‌گذاری به عنوان خوانده شده: $e');
    }
  }

  Future<ConversationModel> createConversation(String otherUserId) async {
    if (_disposed) {
      throw Exception('Notifier has been disposed');
    }

    state = const AsyncValue.loading();
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversation = await chatService.createConversation(otherUserId);

      if (_disposed) {
        throw Exception('Notifier was disposed during operation');
      }

      // بروزرسانی مکالمات
      ref.invalidate(conversationsProvider);
      state = const AsyncValue.data(null);
      return conversation;
    } catch (e, stack) {
      if (!_disposed) {
        state = AsyncValue.error(e, stack);
      }
      rethrow;
    }
  }
}

// این کلاس را به chat_provider.dart.dart اضافه کنید
// در فایل chat_provider.dart اضافه کنید
class SafeMessageHandler {
  final MessageNotifier _notifier;

  SafeMessageHandler(this._notifier);

  Future<void> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    try {
      await _notifier.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );
    } catch (e) {
      print('خطا در ارسال پیام: $e');
      rethrow;
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _notifier.markAsRead(conversationId);
    } catch (e) {
      print('خطا در علامت‌گذاری به عنوان خوانده‌شده: $e');
      rethrow;
    }
  }
}

final safeMessageHandlerProvider = Provider<SafeMessageHandler>((ref) {
  final notifier = ref.watch(messageNotifierProvider.notifier);
  return SafeMessageHandler(notifier);
});
