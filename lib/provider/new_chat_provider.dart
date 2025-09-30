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

  const ChatProviderParams({required this.conversationId, required this.otherUserId});

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
class NewChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const NewChatState({
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  NewChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return NewChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error, // Don't carry over old errors
    );
  }
}

// The single, efficient StateNotifier for the chat screen
class NewChatNotifier extends StateNotifier<NewChatState> {
  final ChatProviderParams params;
  final ChatService _chatService = ChatService();
  final UnifiedMessageCacheService _cacheService = UnifiedMessageCacheService();
  StreamSubscription? _realtimeSubscription;
  bool _isFetching = false;
  static const _pageSize = 30;

  NewChatNotifier(this.params) : super(const NewChatState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    final userId = supabase.auth.currentUser!.id;

    // 1. Load from cache first for instant UI
    final cachedMessages = await _cacheService.getConversationMessages(params.conversationId, userId);
    if (mounted) {
      state = state.copyWith(messages: cachedMessages, isLoading: false);
    }

    // 2. Fetch from server to get latest messages
    await fetchLatestMessages();

    // 3. Listen for real-time updates
    _listenForRealtimeUpdates();
  }

  Future<void> fetchLatestMessages() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      final serverMessages = await _chatService.getMessages(params.conversationId, limit: _pageSize);
      if (mounted) {
        _updateMessages(serverMessages);
      }
    } catch (e) {
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
      final oldestMessageTimestamp = state.messages.isNotEmpty ? state.messages.first.createdAt : DateTime.now();
      final moreMessages = await _chatService.getMessages(
        params.conversationId,
        limit: _pageSize,
        before: oldestMessageTimestamp,
      );

      if (mounted) {
        if (moreMessages.isEmpty) {
          state = state.copyWith(hasMore: false, isLoading: false);
        } else {
          final updatedList = [...moreMessages, ...state.messages];
          _updateMessages(updatedList, newMessages: moreMessages, fromPagination: true);
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
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _chatService.subscribeToMessages(params.conversationId, (newMessage) {
      if (mounted) {
        _updateMessages([newMessage]);
      }
    });
  }

  void _updateMessages(List<MessageModel> newMessages, {bool fromPagination = false}) {
    if (newMessages.isEmpty && !fromPagination) return;

    final currentMessages = Map.fromEntries(state.messages.map((m) => MapEntry(m.id, m)));

    for (var msg in newMessages) {
      currentMessages[msg.id] = msg;
    }

    final sortedMessages = currentMessages.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (mounted) {
        state = state.copyWith(messages: sortedMessages);
    }

    // Update cache in the background
    _cacheService.cacheMessages(newMessages, supabase.auth.currentUser!.id);
  }

  Future<void> sendMessage(String content, {String? attachmentUrl, String? attachmentType, MessageModel? replyToMessage}) async {
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
      replyToMessageId: replyToMessage?.id,
      replyToContent: replyToMessage?.content,
      replyToSenderName: replyToMessage?.senderName,
    );

    // Optimistic UI update
    _updateMessages([tempMessage]);

    try {
      final sentMessage = await _chatService.sendMessage(
        conversationId: params.conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        localId: tempId,
        replyToMessageId: replyToMessage?.id,
        replyToContent: replyToMessage?.content,
        replyToSenderName: replyToMessage?.senderName,
      );

      // Replace temp message with real one
      if (mounted) {
        final newMessages = state.messages.map((m) => m.id == tempId ? sentMessage : m).toList();
        state = state.copyWith(messages: newMessages);
        _cacheService.cacheMessage(sentMessage, currentUser.id);
        _cacheService.clearMessage(params.conversationId, tempId, currentUser.id);
      }
    } catch (e) {
      if (mounted) {
        final failedMessage = tempMessage.copyWith(isSent: false, isPending: false);
        final newMessages = state.messages.map((m) => m.id == tempId ? failedMessage : m).toList();
        state = state.copyWith(messages: newMessages, error: "Failed to send message");
      }
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    super.dispose();
  }
}

// The provider for our new notifier
final newChatProvider = StateNotifierProvider.family
    .autoDispose<NewChatNotifier, NewChatState, ChatProviderParams>(
        (ref, params) {
  return NewChatNotifier(params);
});