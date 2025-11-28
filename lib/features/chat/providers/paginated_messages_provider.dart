// lib/features/chat/providers/paginated_messages_provider.dart
//
// Provider برای پیام‌ها با قابلیت Pagination
//
// ویژگی‌ها:
// ✅ Load More (بارگذاری پیام‌های بیشتر)
// ✅ Infinite Scroll
// ✅ Cache First Strategy
// ✅ Realtime Updates

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../model/message_model.dart';
import '../repositories/chat_repository.dart';
import 'chat_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 📦 STATE
// ═══════════════════════════════════════════════════════════════════════════

/// وضعیت پیام‌های یک مکالمه
class PaginatedMessagesState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const PaginatedMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  PaginatedMessagesState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return PaginatedMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  /// آیا هیچ داده‌ای نداریم و در حال لود اولیه هستیم؟
  bool get isInitialLoading => isLoading && messages.isEmpty;

  /// آیا خالی هست؟
  bool get isEmpty => !isLoading && messages.isEmpty && error == null;
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎮 NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

/// مدیریت پیام‌ها با Pagination
class PaginatedMessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<PaginatedMessagesState, String> {
  static const int _pageSize = 30;

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  StreamSubscription? _realtimeSubscription;

  @override
  Future<PaginatedMessagesState> build(String conversationId) async {
    // Cleanup وقتی dispose میشه
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
    });

    // شروع بارگذاری
    return _loadInitialMessages(conversationId);
  }

  /// بارگذاری اولیه پیام‌ها
  Future<PaginatedMessagesState> _loadInitialMessages(
      String conversationId) async {
    try {
      final result = await _repository.getMessages(
        conversationId,
        limit: _pageSize,
      );

      if (result.isSuccess && result.data != null) {
        // شروع گوش دادن به Realtime
        _setupRealtimeSubscription(conversationId);

        return PaginatedMessagesState(
          messages: result.data!,
          hasMore: result.data!.length >= _pageSize,
        );
      }

      return PaginatedMessagesState(
        error: result.error ?? 'خطا در دریافت پیام‌ها',
      );
    } catch (e) {
      return PaginatedMessagesState(error: e.toString());
    }
  }

  /// بارگذاری پیام‌های بیشتر (قدیمی‌تر)
  Future<void> loadMore() async {
    final currentState = state.valueOrNull;
    if (currentState == null ||
        currentState.isLoadingMore ||
        !currentState.hasMore) {
      return;
    }

    // آپدیت state به "در حال لود"
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final lastMessage = currentState.messages.last;
      final result = await _repository.getMessages(
        arg, // conversationId
        limit: _pageSize,
        beforeMessageId: lastMessage.id,
      );

      if (result.isSuccess && result.data != null) {
        final newMessages = result.data!;
        state = AsyncData(currentState.copyWith(
          messages: [...currentState.messages, ...newMessages],
          isLoadingMore: false,
          hasMore: newMessages.length >= _pageSize,
        ));
      } else {
        state = AsyncData(currentState.copyWith(
          isLoadingMore: false,
          error: result.error,
        ));
      }
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }

  /// ارسال پیام جدید
  Future<ChatResult<MessageModel>> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    int? duration,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
  }) async {
    final result = await _repository.sendMessage(
      conversationId: arg, // conversationId
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      duration: duration,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );

    // Refresh لیست پیام‌ها
    if (result.isSuccess) {
      await refresh();
    }

    return result;
  }

  /// حذف پیام
  Future<ChatResult<void>> deleteMessage(String messageId) async {
    final result = await _repository.deleteMessage(messageId);

    if (result.isSuccess) {
      // حذف از لیست محلی فوری
      final currentState = state.valueOrNull;
      if (currentState != null) {
        state = AsyncData(currentState.copyWith(
          messages:
              currentState.messages.where((m) => m.id != messageId).toList(),
        ));
      }
    }

    return result;
  }

  /// Refresh کردن پیام‌ها
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadInitialMessages(arg));
  }

  /// اضافه کردن پیام جدید به لیست (برای Realtime)
  void addMessage(MessageModel message) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // چک کن که duplicate نباشه
    if (currentState.messages.any((m) => m.id == message.id)) return;

    state = AsyncData(currentState.copyWith(
      messages: [message, ...currentState.messages],
    ));
  }

  /// آپدیت یک پیام (برای Realtime)
  void updateMessage(MessageModel message) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final index = currentState.messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    final updatedMessages = List<MessageModel>.from(currentState.messages);
    updatedMessages[index] = message;

    state = AsyncData(currentState.copyWith(messages: updatedMessages));
  }

  /// حذف یک پیام از لیست (برای Realtime)
  void removeMessage(String messageId) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    state = AsyncData(currentState.copyWith(
      messages: currentState.messages.where((m) => m.id != messageId).toList(),
    ));
  }

  /// Setup Realtime Subscription
  void _setupRealtimeSubscription(String conversationId) {
    _realtimeSubscription?.cancel();

    // گوش دادن به Stream پیام‌ها از Repository
    _realtimeSubscription =
        _repository.watchMessages(conversationId).listen((messages) {
      final currentState = state.valueOrNull;
      if (currentState == null) return;

      // Merge پیام‌های جدید با قدیمی‌ها
      final existingIds = currentState.messages.map((m) => m.id).toSet();
      final newMessages =
          messages.where((m) => !existingIds.contains(m.id)).toList();

      if (newMessages.isNotEmpty) {
        state = AsyncData(currentState.copyWith(
          messages: [...newMessages, ...currentState.messages],
        ));
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای پیام‌های با Pagination
/// 
/// استفاده:
/// ```dart
/// final messagesState = ref.watch(paginatedMessagesProvider(conversationId));
/// 
/// messagesState.when(
///   data: (state) {
///     if (state.isInitialLoading) return Loading();
///     if (state.isEmpty) return EmptyState();
///     return MessagesList(messages: state.messages);
///   },
///   loading: () => Loading(),
///   error: (e, s) => Error(),
/// );
/// 
/// // Load More
/// ref.read(paginatedMessagesProvider(conversationId).notifier).loadMore();
/// 
/// // Send Message
/// await ref.read(paginatedMessagesProvider(conversationId).notifier).sendMessage(
///   content: 'سلام!',
/// );
/// ```
final paginatedMessagesProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedMessagesNotifier, PaginatedMessagesState, String>(
  PaginatedMessagesNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 HELPER PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// فقط لیست پیام‌ها (بدون state اضافی)
final messagesOnlyProvider =
    Provider.autoDispose.family<List<MessageModel>, String>((ref, conversationId) {
  final state = ref.watch(paginatedMessagesProvider(conversationId));
  return state.valueOrNull?.messages ?? [];
});

/// آیا در حال لود بیشتر هستیم؟
final isLoadingMoreProvider =
    Provider.autoDispose.family<bool, String>((ref, conversationId) {
  final state = ref.watch(paginatedMessagesProvider(conversationId));
  return state.valueOrNull?.isLoadingMore ?? false;
});

/// آیا پیام بیشتری داریم؟
final hasMoreMessagesProvider =
    Provider.autoDispose.family<bool, String>((ref, conversationId) {
  final state = ref.watch(paginatedMessagesProvider(conversationId));
  return state.valueOrNull?.hasMore ?? true;
});

