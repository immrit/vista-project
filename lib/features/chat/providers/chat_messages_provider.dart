import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Vista/model/message_model.dart';
import 'package:Vista/DB/unified_message_cache_service.dart';
import 'package:Vista/features/chat/repositories/chat_repository.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';

import 'package:Vista/utils/const.dart';
import 'package:Vista/security/logging_utility.dart';
import 'dart:async';

part 'chat_messages_provider.g.dart';

@riverpod
class ChatMessages extends _$ChatMessages {
  late final UnifiedMessageCacheService _cacheService;
  late final ChatRepository _chatRepository;
  StreamSubscription? _realtimeSubscription;
  static const int _pageSize = 20;
  bool _hasMore = true;

  @override
  FutureOr<List<MessageModel>> build(String conversationId) async {
    _cacheService = UnifiedMessageCacheService();
    _chatRepository = ref.read(chatRepositoryProvider);

    // Cleanup on dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
    });

    // 1. Load from Cache immediately
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return [];

    final cachedMessages = await _cacheService.getConversationMessages(
        conversationId, currentUser.id);

    // 2. Setup Realtime Listener (via Repository)
    _setupRealtimeListener(conversationId);

    // 3. Fetch fresh data from network in background if we have cache,
    //    or wait for it if cache is empty.
    if (cachedMessages.isEmpty) {
      return await _fetchFromNetwork(conversationId);
    } else {
      // Optimistically return cache, but update in background
      _fetchAndSync(conversationId);
      return cachedMessages;
    }
  }

  Future<List<MessageModel>> _fetchFromNetwork(String conversationId,
      {String? beforeMessageId}) async {
    final result = await _chatRepository.getMessages(
      conversationId,
      limit: _pageSize,
      beforeMessageId: beforeMessageId,
    );

    return result.fold(
      (messages) async {
        _hasMore = messages.length >= _pageSize;
        // Update Cache
        final currentUser = supabase.auth.currentUser;
        if (currentUser != null && messages.isNotEmpty) {
          await _cacheService.cacheMessages(messages, currentUser.id);
        }
        return messages;
      },
      (error) {
        logInfo('Network fetch error: $error');
        return [];
      },
    );
  }

  Future<void> _fetchAndSync(String conversationId) async {
    try {
      final messages = await _fetchFromNetwork(conversationId);
      if (messages.isNotEmpty) {
        state = AsyncValue.data(messages);
      }
    } catch (e) {
      logInfo('Background sync failed: $e');
    }
  }

  Future<void> loadMore() async {
    try {
      if (!_hasMore || state.isLoading) return;

      final currentMessages = state.value ?? [];
      // Don't wipe state, just keep showing current

      final oldestMessage =
          currentMessages.isNotEmpty ? currentMessages.last : null;
      if (oldestMessage == null) return;

      final newMessages = await _fetchFromNetwork(
        conversationId,
        beforeMessageId:
            oldestMessage.id, // Use ID based pagination if repo supports it
        // Or if repo uses offset, we might need a different method.
        // Assuming repo supports standard pagination.
      );

      if (newMessages.isNotEmpty) {
        state = AsyncValue.data([...currentMessages, ...newMessages]);
      }
    } catch (e) {
      // Keep old state on error, maybe show toast
      logInfo('Load more failed: $e');
    }
  }

  void _setupRealtimeListener(String conversationId) {
    // We can use the repository stream if we want full sync
    // Or just simple stream if provided.
    // For now, let's trust the repository's internal sync or use its watchMessages
    // Actually, ChatRepository.watchMessages handles sync + local stream.
    // But this provider seems to want to manage state manually (legacy style).
    // Ideally we should switch to StreamProvider, but to minimize refactor risk:

    _realtimeSubscription =
        _chatRepository.watchMessages(conversationId).listen((messages) {
      // Repository stream yields FULL list usually?
      // Check implementation: yield* _localDataSource.watchMessages
      // Yes, Isar watch yields the full list matching the query.

      // So we can just update state directly!
      state = AsyncValue.data(messages);
    });
  }

  // Optimistic updates methods
  // These might be redundant if we use watchMessages from Isar,
  // because saving to Isar triggers the stream update automatically.
  // But keeping them for now if UI expects instant feedback before DB write.
  void addOptimisticMessage(MessageModel message) {
    final currentMessages = state.value ?? [];
    state = AsyncValue.data([message, ...currentMessages]);
  }

  void updateOptimisticMessage(MessageModel message) {
    final currentMessages = state.value ?? [];
    final updated =
        currentMessages.map((m) => m.id == message.id ? message : m).toList();
    state = AsyncValue.data(updated);
  }

  void removeOptimisticMessage(String messageId) {
    final currentMessages = state.value ?? [];
    final updated = currentMessages.where((m) => m.id != messageId).toList();
    state = AsyncValue.data(updated);
  }
}
