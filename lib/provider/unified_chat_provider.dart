import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../DB/message_cache_service_wrapper.dart';
import '../main.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';

/// یکپارچه‌سازی provider های پیام‌رسانی برای حل مشکل redundancy
/// این provider جایگزین lazyMessagesProvider و conversationMessagesProvider می‌شود

// State برای unified messages management
class UnifiedMessagesState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final bool isInitialized;

  const UnifiedMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.isInitialized = false,
  });

  UnifiedMessagesState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool? isInitialized,
  }) {
    return UnifiedMessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

// Unified Notifier برای مدیریت پیام‌ها
class UnifiedMessagesNotifier extends StateNotifier<UnifiedMessagesState> {
  final String conversationId;
  final ChatService _chatService = ChatService();
  final MessageCacheService _messageCache = MessageCacheService();
  static const int _pageSize = 20;
  int _currentPage = 0;
  StreamSubscription? _realtimeSubscription;
  final Set<String> _locallyDeletedMessageIds = <String>{};

  UnifiedMessagesNotifier(this.conversationId)
      : super(const UnifiedMessagesState()) {
    _initializeMessages();
    _setupRealTimeListener();
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }

  /// بهینه‌سازی فیلتر duplicate messages با الگوریتم O(n)
  List<MessageModel> _filterDuplicateMessages(List<MessageModel> messages) {
    if (messages.isEmpty) return messages;

    final Map<String, MessageModel> uniqueMessages = {};
    final Set<String> realLocalIds = {};

    // شناسایی پیام‌های واقعی
    for (final message in messages) {
      if (!message.id.startsWith('temp_') && message.localId != null) {
        realLocalIds.add(message.localId!);
      }
    }

    // انتخاب پیام‌های منحصر به فرد
    for (final message in messages) {
      if (message.id.startsWith('temp_') && realLocalIds.contains(message.id)) {
        continue; // حذف temp message که real message آن آمده
      }

      final key = message.localId ?? message.id;

      if (!uniqueMessages.containsKey(key) ||
          (!uniqueMessages[key]!.id.startsWith('temp_') &&
              message.id.startsWith('temp_'))) {
        uniqueMessages[key] = message;
      }
    }

    return uniqueMessages.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// مقداردهی اولیه پیام‌ها
  Future<void> _initializeMessages() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final userId = supabase.auth.currentUser!.id;
      final cachedMessages =
          await _messageCache.getConversationMessages(conversationId, userId);

      if (cachedMessages.isNotEmpty) {
        final filteredMessages = _filterDuplicateMessages(cachedMessages);
        state = state.copyWith(
          messages: filteredMessages,
          isLoading: false,
          hasMore: filteredMessages.length >= _pageSize,
          isInitialized: true,
        );
        _currentPage = (filteredMessages.length / _pageSize).ceil();

        // Load more messages if we have less than a full page
        if (filteredMessages.length < _pageSize) {
          await loadMoreMessages();
        }
      } else {
        // Load initial batch of messages
        await loadMoreMessages();
        state = state.copyWith(isInitialized: true);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isInitialized: true,
      );
    }
  }

  /// بارگذاری پیام‌های بیشتر
  Future<void> loadMoreMessages() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final newMessages = await _chatService.getMessages(
        conversationId,
        offset: _currentPage * _pageSize,
        limit: _pageSize,
      );

      if (newMessages.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          hasMore: false,
        );
        return;
      }

      final updatedMessages = [...newMessages, ...state.messages];
      final filteredMessages = _filterDuplicateMessages(updatedMessages);

      state = state.copyWith(
        messages: filteredMessages,
        isLoading: false,
        hasMore: newMessages.length >= _pageSize,
      );

      _currentPage++;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// تنظیم Real-time listener
  void _setupRealTimeListener() {
    _realtimeSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .listen((jsonList) {
          final userId = supabase.auth.currentUser!.id;
          final newMessages = jsonList
              .map((json) => MessageModel.fromJson(json, currentUserId: userId))
              .where((msg) => !msg.id.startsWith('temp_'))
              .toList();

          _handleIncomingMessages(newMessages);
        });
  }

  /// مدیریت پیام‌های ورودی از real-time stream
  void _handleIncomingMessages(List<MessageModel> newMessages) {
    if (newMessages.isEmpty) return;

    // فیلتر پیام‌های جدید
    final existingIds = state.messages.map((m) => m.id).toSet();
    final existingLocalIds = state.messages
        .where((m) => m.localId != null)
        .map((m) => m.localId!)
        .toSet();

    final trulyNewMessages = newMessages.where((msg) {
      return !existingIds.contains(msg.id) &&
          !_locallyDeletedMessageIds.contains(msg.id) &&
          !(msg.localId != null && existingLocalIds.contains(msg.localId!));
    }).toList();

    if (trulyNewMessages.isNotEmpty) {
      final updatedMessages = [...state.messages, ...trulyNewMessages];
      final filteredMessages = _filterDuplicateMessages(updatedMessages);
      state = state.copyWith(messages: filteredMessages);
    }
  }

  /// اضافه کردن پیام موقت
  void addTempMessage(MessageModel tempMessage) {
    final existingMessage = state.messages.any((m) =>
        m.id == tempMessage.id ||
        (m.localId != null && m.localId == tempMessage.localId) ||
        (tempMessage.localId != null && m.id == tempMessage.localId));

    if (existingMessage) return;

    final updatedMessages = [...state.messages, tempMessage];
    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  /// جایگزینی پیام موقت با پیام واقعی
  void replaceTempWithReal(String tempId, MessageModel realMessage) {
    final tempMessageExists = state.messages.any((m) => m.id == tempId);
    if (!tempMessageExists) return;

    final updatedMessages = state.messages.map((m) {
      return m.id == tempId ? realMessage : m;
    }).toList();

    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  /// علامت‌گذاری پیام به عنوان ناموفق
  void markTempFailed(String tempId) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == tempId) {
        return m.copyWith(isSent: false, isPending: false);
      }
      return m;
    }).toList();

    state = state.copyWith(messages: updatedMessages);
  }

  /// به‌روزرسانی پیام
  void updateMessage(MessageModel message) {
    final updatedMessages = state.messages.map((m) {
      return m.id == message.id ? message : m;
    }).toList();

    final filteredMessages = _filterDuplicateMessages(updatedMessages);
    state = state.copyWith(messages: filteredMessages);
  }

  /// حذف پیام
  void removeMessage(String messageId) {
    _locallyDeletedMessageIds.add(messageId);
    final updatedMessages =
        state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);
  }

  /// پاکسازی تمام پیام‌ها
  Future<void> clearAllMessages() async {
    state = state.copyWith(messages: []);

    final userId = supabase.auth.currentUser!.id;
    await _messageCache.clearConversationMessages(conversationId, userId);
  }
}

// Provider یکپارچه برای مدیریت پیام‌ها
final unifiedMessagesProvider = StateNotifierProvider.family
    .autoDispose<UnifiedMessagesNotifier, UnifiedMessagesState, String>(
  (ref, conversationId) {
    final link = ref.keepAlive();
    final notifier = UnifiedMessagesNotifier(conversationId);

    ref.onDispose(() {
      link.close();
    });

    return notifier;
  },
);

// Helper provider برای دسترسی آسان‌تر به پیام‌ها
final messagesListProvider =
    Provider.family<List<MessageModel>, String>((ref, conversationId) {
  final messagesState = ref.watch(unifiedMessagesProvider(conversationId));
  return messagesState.messages;
});

// Helper provider برای وضعیت loading
final messagesLoadingProvider =
    Provider.family<bool, String>((ref, conversationId) {
  final messagesState = ref.watch(unifiedMessagesProvider(conversationId));
  return messagesState.isLoading;
});
