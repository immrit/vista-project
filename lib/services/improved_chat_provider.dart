import '../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
// import '../services/cache_sync_service.dart'; // Removed
import 'package:Vista/features/chat/repositories/chat_repository.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/features/chat/domain/message_payload.dart';

import '../utils/const.dart';

/// Provider بهبود یافته برای مدیریت چت با سیستم sync ویستا
class ImprovedChatProvider extends StateNotifier<ImprovedChatState> {
  final String conversationId;
  final ChatRepository _chatRepository; // ✅ Injected
  // final CacheSyncService _cacheSync = CacheSyncService(); // Removed

  // NOTE: We don't need independent ChatService anymore.
  // We use repository for all data ops.

  StreamSubscription? _messageSubscription;
  bool _isInitialized = false;
  // مجموعه پیام‌هایی که کاربر به‌صورت خوشبینانه حذف کرده
  final Set<String> _locallyDeletedMessageIds = <String>{};

  ImprovedChatProvider(this.conversationId, this._chatRepository)
      : super(const ImprovedChatState()) {
    _initialize();
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    // _cacheSync.unsubscribeFromConversation(conversationId);
    super.dispose();
  }

  /// مقداردهی اولیه
  Future<void> _initialize() async {
    if (_isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      // مقداردهی سیستم cache sync
      // await _cacheSync.initialize();

      // دریافت پیام‌های کش شده
      await _loadCachedMessages();

      // شروع sync فوری
      await _chatRepository.refreshMessages(conversationId);

      // راه‌اندازی real-time listener
      await _setupRealtimeListener();

      _isInitialized = true;
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// دریافت پیام‌های کش شده
  Future<void> _loadCachedMessages() async {
    try {
      final result = await _chatRepository.getMessages(conversationId);
      final messages = result.data ?? [];

      // فیلتر پیام‌های حذف شده محلی
      final filteredMessages = messages
          .where((m) => !_locallyDeletedMessageIds.contains(m.id))
          .toList();

      state = state.copyWith(
        messages: filteredMessages,
        hasMore: filteredMessages.length >= 20,
      );
    } catch (e) {
      logInfo('خطا در بارگذاری پیام‌های کش شده: $e');
    }
  }

  /// راه‌اندازی real-time listener
  Future<void> _setupRealtimeListener() async {
    // await _cacheSync.subscribeToConversation(conversationId);

    // گوش دادن به تغییرات cache
    // Instead of polling cache via periodic stream, let's use the repository stream!
    _messageSubscription =
        _chatRepository.watchMessages(conversationId).listen((messages) {
      // فیلتر پیام‌های حذف شده محلی
      final filteredMessages = messages
          .where((m) => !_locallyDeletedMessageIds.contains(m.id))
          .toList();

      if (mounted) {
        state = state.copyWith(messages: filteredMessages);
      }
    });
  }

  /// بارگذاری پیام‌های بیشتر
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final oldestMessage =
          state.messages.isNotEmpty ? state.messages.last : null;
      if (oldestMessage == null) return;

      final result = await _chatRepository.getMessages(
        conversationId,
        beforeMessageId: oldestMessage.id,
        limit: 20,
      );

      final newMessages = result.data ?? [];

      if (newMessages.isNotEmpty) {
        // فیلتر پیام‌های حذف شده محلی
        final filteredNewMessages = newMessages
            .where((m) => !_locallyDeletedMessageIds.contains(m.id))
            .toList();
        final allMessages = [...state.messages, ...filteredNewMessages];
        state = state.copyWith(
          messages: allMessages,
          hasMore: filteredNewMessages.length >= 20,
        );
      } else {
        state = state.copyWith(hasMore: false);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// ارسال پیام
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
  }) async {
    try {
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final currentUser = supabase.auth.currentUser!;

      // ایجاد پیام موقت
      final tempMessage = MessageModel.temporary(
        tempId: tempId,
        conversationId: conversationId,
        senderId: currentUser.id,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        replyToMessageId: replyToMessageId,
        senderName: currentUser.userMetadata?['username'],
        senderAvatar: currentUser.userMetadata?['avatar_url'],
      );

      // اضافه کردن به state
      final updatedMessages = [tempMessage, ...state.messages];
      state = state.copyWith(messages: updatedMessages);

      // ارسال به سرور
      // Repository handles optimistic update implicitly if used correctly,
      // but here we are managing state manually.
      // Calling sendMessage on repo returns the final message.

      // Sending to Server using MessagePayload
      final payload = MessagePayload(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        replyToMessageId: replyToMessageId,
        id: tempId,
      );

      final result = await _chatRepository.sendMessage(payload);

      if (!result.isSuccess) throw Exception(result.error);

      final sentMessage = result.data!;

      // جایگزینی پیام موقت با واقعی
      final finalMessages = state.messages.map((m) {
        return (m.id == tempId || m.id == sentMessage.id) ? sentMessage : m;
      }).toList();

      state = state.copyWith(messages: finalMessages);
    } catch (e) {
      // علامت‌گذاری پیام به عنوان ناموفق
      final failedMessages = state.messages.map((m) {
        if (m.id.startsWith('temp_')) {
          return m.copyWith(isSent: false, isPending: false);
        }
        return m;
      }).toList();

      state = state.copyWith(
        messages: failedMessages,
        error: 'خطا در ارسال پیام: $e',
      );
    }
  }

  /// حذف پیام
  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    try {
      // اضافه کردن به لیست پیام‌های حذف شده محلی
      _locallyDeletedMessageIds.add(messageId);

      // حذف خوشبینانه از UI
      final filteredMessages =
          state.messages.where((m) => m.id != messageId).toList();
      state = state.copyWith(messages: filteredMessages);

      // حذف از سرور
      await _chatRepository.deleteMessage(messageId, forEveryone: forEveryone);

      // sync مجدد برای اطمینان
      await _chatRepository.refreshMessages(conversationId);
    } catch (e) {
      // بازگردانی پیام در صورت خطا
      // await _loadCachedMessages(); // Might be jarring
      state = state.copyWith(error: 'خطا در حذف پیام: $e');
    }
  }

  /// تلاش مجدد برای ارسال پیام ناموفق
  Future<void> retryFailedMessage(MessageModel failedMessage) async {
    await sendMessage(
      content: failedMessage.content,
      attachmentUrl: failedMessage.attachmentUrl,
      attachmentType: failedMessage.attachmentType,
      replyToMessageId: failedMessage.replyToMessageId,
    );

    // حذف پیام ناموفق
    final filteredMessages =
        state.messages.where((m) => m.id != failedMessage.id).toList();
    state = state.copyWith(messages: filteredMessages);
  }

  /// sync دستی
  Future<void> syncManually() async {
    state = state.copyWith(isLoading: true);

    try {
      await _chatRepository.refreshMessages(conversationId);
      await _loadCachedMessages();
    } catch (e) {
      state = state.copyWith(error: 'خطا در همگام‌سازی: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  /// پاک کردن خطا
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// State برای مدیریت چت بهبود یافته
class ImprovedChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const ImprovedChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  ImprovedChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return ImprovedChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
    );
  }
}

/// Provider برای استفاده در UI - بدون autoDispose برای جلوگیری از dispose زودهنگام
final improvedChatProvider = StateNotifierProvider.family<ImprovedChatProvider,
    ImprovedChatState, String>(
  (ref, conversationId) {
    final repository = ref.watch(chatRepositoryProvider);
    return ImprovedChatProvider(conversationId, repository);
  },
);

/// Helper providers برای دسترسی آسان‌تر
final chatMessagesProvider =
    Provider.family<List<MessageModel>, String>((ref, conversationId) {
  return ref.watch(improvedChatProvider(conversationId)).messages;
});

final chatLoadingProvider =
    Provider.family<bool, String>((ref, conversationId) {
  return ref.watch(improvedChatProvider(conversationId)).isLoading;
});

final chatErrorProvider =
    Provider.family<String?, String>((ref, conversationId) {
  return ref.watch(improvedChatProvider(conversationId)).error;
});
