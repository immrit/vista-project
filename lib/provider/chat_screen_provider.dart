import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../services/ChatService.dart';
import '../DB/unified_message_cache_service.dart';
import '../main.dart';

// Class to hold parameters for the chat provider
class ChatProviderParams {
  final String conversationId;
  final String otherUserId;

  const ChatProviderParams(
      {required this.conversationId, required this.otherUserId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatProviderParams &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          otherUserId == other.otherUserId;

  @override
  int get hashCode => conversationId.hashCode ^ otherUserId.hashCode;
}

// A single, unified state for the chat screen
class ChatScreenState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const ChatScreenState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  ChatScreenState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return ChatScreenState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error, // Don't carry over old errors
    );
  }
}

// The single, efficient StateNotifier for the chat screen
class ChatScreenNotifier extends StateNotifier<ChatScreenState> {
  final ChatProviderParams params;
  final ChatService _chatService = ChatService();
  final UnifiedMessageCacheService _cacheService = UnifiedMessageCacheService();
  StreamSubscription? _realtimeSubscription;
  bool _isFetching = false;
  static const _pageSize = 30;

  ChatScreenNotifier(this.params) : super(const ChatScreenState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    print(
        '🚀 Starting ChatProvider initialization for conversation: ${params.conversationId}');

    state = state.copyWith(isLoading: true);

    // بررسی وجود کاربر
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      print('❌ User not authenticated');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'کاربر وارد نشده است',
        );
      }
      return;
    }

    final userId = currentUser.id;

    // بررسی conversationId
    if (params.conversationId.isEmpty) {
      print('❌ ConversationId is empty');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'شناسه مکالمه نامعتبر است',
        );
      }
      return;
    }

    print('✅ User authenticated and conversationId valid');

    try {
      // 1. Load from cache first for instant UI
      print('📦 Loading from cache...');
      final cachedMessages = await _cacheService.getConversationMessages(
          params.conversationId, userId);
      print('✅ Loaded ${cachedMessages.length} messages from cache');
      if (mounted) {
        state = state.copyWith(messages: cachedMessages, isLoading: false);
      }

      // 2. Fetch from server to get latest messages
      print('🌐 Fetching from server...');
      await fetchLatestMessages();

      // 3. Listen for real-time updates
      print('📡 Starting real-time updates...');
      _listenForRealtimeUpdates();
    } catch (e) {
      print('❌ Error during initialization: $e');
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: 'خطا در بارگذاری پیام‌ها: $e',
        );
      }
    }
  }

  Future<void> fetchLatestMessages() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      print(
          '🔄 Fetching latest messages for conversation: ${params.conversationId}');
      final serverMessages = await _chatService
          .getMessages(params.conversationId, limit: _pageSize);
      print('✅ Received ${serverMessages.length} messages from server');
      if (mounted) {
        _updateMessages(serverMessages);
      }
    } catch (e) {
      print('❌ Error fetching latest messages: $e');
      if (mounted) {
        state = state.copyWith(error: e.toString());
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> fetchMoreMessages() async {
    if (state.isLoading || !state.hasMore || _isFetching) return;

    state = state.copyWith(isLoading: true);
    _isFetching = true;

    try {
      final moreMessages = await _chatService.getMessages(
        params.conversationId,
        limit: _pageSize,
        offset: state.messages.length,
      );

      if (mounted) {
        if (moreMessages.isEmpty) {
          state = state.copyWith(hasMore: false, isLoading: false);
        } else {
          final updatedList = [...moreMessages, ...state.messages];
          _updateMessages(updatedList, fromPagination: true);
          state = state.copyWith(isLoading: false);
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(error: e.toString(), isLoading: false);
      }
    } finally {
      _isFetching = false;
    }
  }

  void _listenForRealtimeUpdates() {
    if (_realtimeSubscription != null) {
      print('⚠️ Real-time subscription already exists, skipping');
      return;
    }

    print(
        '📡 Setting up real-time subscription for conversation: ${params.conversationId}');

    try {
      _realtimeSubscription?.cancel();
      _realtimeSubscription =
          _chatService.subscribeToMessages(params.conversationId).listen(
        (messages) {
          print('📨 Received ${messages.length} real-time messages');
          if (mounted) {
            _updateMessages(messages);
          }
        },
        onError: (error) {
          print('❌ Real-time subscription error: $error');
          if (mounted) {
            state = state.copyWith(error: 'خطا در دریافت پیام‌های جدید');
          }
          // تلاش مجدد بعد از 5 ثانیه
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _listenForRealtimeUpdates();
            }
          });
        },
        onDone: () {
          print('⚠️ Real-time subscription closed, reconnecting...');
          _realtimeSubscription = null;
          // تلاش مجدد بعد از 3 ثانیه
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _listenForRealtimeUpdates();
            }
          });
        },
      );
    } catch (e) {
      print('❌ Error setting up real-time subscription: $e');
      if (mounted) {
        state = state.copyWith(error: 'خطا در راه‌اندازی دریافت پیام‌های جدید');
      }
      // تلاش مجدد بعد از 10 ثانیه
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          _listenForRealtimeUpdates();
        }
      });
    }
  }

  void _updateMessages(List<MessageModel> newMessages,
      {bool fromPagination = false}) {
    if (newMessages.isEmpty && !fromPagination) {
      print('⚠️ No new messages to update');
      return;
    }

    print('🔄 Updating messages: ${newMessages.length} new messages');

    final currentMessages =
        Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

    // Only add messages that don't already exist or are newer
    for (var msg in newMessages) {
      final existingMessage = currentMessages[msg.id];
      if (existingMessage == null ||
          msg.createdAt.isAfter(existingMessage.createdAt)) {
        currentMessages[msg.id] = msg;
        print('📝 Added/Updated message: ${msg.id}');
      } else {
        print('⏭️ Skipped duplicate message: ${msg.id}');
      }
    }

    final sortedMessages = currentMessages.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    print('✅ Updated message list: ${sortedMessages.length} total messages');

    if (mounted) {
      state = state.copyWith(messages: sortedMessages);
    }

    // Update cache in the background
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        _cacheService.cacheMessages(newMessages, currentUser.id);
      }
    } catch (e) {
      print('⚠️ Error caching messages: $e');
    }
  }

  Future<void> sendMessage(String content,
      {String? attachmentUrl,
      String? attachmentType,
      int? duration,
      MessageModel? replyToMessage}) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = MessageModel.temporary(
      tempId: tempId,
      conversationId: params.conversationId,
      senderId: currentUser.id,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      duration: duration,
      replyToMessageId: replyToMessage?.id,
      replyToContent: replyToMessage?.content,
      replyToSenderName: replyToMessage?.senderName,
    );

    // Optimistic UI update - add temp message
    _updateMessages([tempMessage]);

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId: params.conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        // duration: duration, // موقتاً غیرفعال تا مشکل دیتابیس حل شود
        localId: tempId,
        replyToMessageId: replyToMessage?.id,
        replyToContent: replyToMessage?.content,
        replyToSenderName: replyToMessage?.senderName,
      );

      // Replace temp message with real one - prevent duplicate
      if (mounted) {
        final currentMessages =
            Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

        // Remove temp message and add real message
        currentMessages.remove(tempId);
        currentMessages[sentMessage.id] = sentMessage;

        final sortedMessages = currentMessages.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = state.copyWith(messages: sortedMessages);
        _cacheService.cacheMessage(sentMessage, currentUser.id);
        _cacheService.clearMessage(
            params.conversationId, tempId, currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        final failedMessage =
            tempMessage.copyWith(isSent: false, isPending: false);
        final currentMessages =
            Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

        // Replace temp message with failed message
        currentMessages[tempId] = failedMessage;

        final sortedMessages = currentMessages.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = state.copyWith(
            messages: sortedMessages, error: "Failed to send message");
      }
    }
  }

  Future<void> deleteMessage(String messageId,
      {bool forEveryone = false}) async {
    try {
      print('🗑️ Deleting message: $messageId (forEveryone: $forEveryone)');

      // حذف خوشبینانه از UI - بلافاصله پیام را از state حذف کن
      final currentMessages =
          Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));
      currentMessages.remove(messageId);

      final sortedMessages = currentMessages.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        state = state.copyWith(messages: sortedMessages);
      }

      // حذف از کش
      final currentUser = supabase.auth.currentUser;
      if (currentUser != null) {
        await _cacheService.clearMessage(
            params.conversationId, messageId, currentUser.id);
      }

      // حذف از سرور
      await _chatService.deleteMessage(messageId, forEveryone: forEveryone);

      print('✅ Message deleted successfully from server');
    } catch (e) {
      print('❌ Error deleting message: $e');
      if (mounted) {
        state = state.copyWith(error: 'خطا در حذف پیام: $e');
      }
      rethrow;
    }
  }

  void clearAllMessages() {
    print('🗑️ Clearing all messages from UI');
    if (mounted) {
      state = state.copyWith(messages: []);
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

// The provider for chat screen state management
final chatScreenProvider = StateNotifierProvider.family
    .autoDispose<ChatScreenNotifier, ChatScreenState, ChatProviderParams>(
        (ref, params) {
  return ChatScreenNotifier(params);
});
