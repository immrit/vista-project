import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Vista/model/message_model.dart';

import 'package:Vista/features/chat/repositories/chat_repository.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';

import 'package:Vista/security/logging_utility.dart';
import 'dart:async';

part 'chat_messages_provider.g.dart';

@riverpod
class ChatMessages extends _$ChatMessages {
  ChatRepository? _chatRepository;
  StreamSubscription? _realtimeSubscription;
  static const int _pageSize = 20;
  bool _hasMore = true;

  @override
  FutureOr<List<MessageModel>> build(String conversationId) async {
    final repository = ref.watch(chatRepositoryProvider);
    _chatRepository = repository;

    _realtimeSubscription?.cancel();

    // Cleanup on dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
    });

    // Return the stream from repository directly.
    // This is the SINGLE SOURCE OF TRUTH.
    _realtimeSubscription = repository.watchMessages(conversationId).listen(
      (messages) {
        state = AsyncValue.data(messages);
      },
      onError: (Object error, StackTrace stackTrace) {
        logError(
          'watchMessages stream failed',
          error: error,
          stackTrace: stackTrace,
        );
        state = AsyncValue.error(error, stackTrace);
      },
    );

    // Initial value while stream connects (Isar usually fires immediately)
    return state.valueOrNull ?? const [];
  }

  Future<void> loadMore() async {
    try {
      final repository = _chatRepository ?? ref.read(chatRepositoryProvider);
      _chatRepository = repository;
      if (!_hasMore || state.isLoading) return;

      final currentMessages = state.value ?? [];
      final oldestMessage = currentMessages.isNotEmpty
          ? currentMessages.last
          : null;

      if (oldestMessage == null) return;

      // Correctly load older messages using the repository
      final result = await repository!.loadMoreMessages(
        conversationId: conversationId,
        oldestMessageDate: oldestMessage.createdAt,
        limit: _pageSize,
      );

      result.fold(
        (newMessages) {
          if (newMessages.isEmpty) {
            _hasMore = false;
          }
          // No need to update state manually, saving to DB triggers the stream!
        },
        (error) {
          logInfo('Load more failed: $error');
        },
      );
    } catch (e) {
      logInfo('Load more failed: $e');
    }
  }

  // Optimistic updates are now handled by the repository saving to Isar immediately.
  // We keep these methods empty or remove them if UI calls them,
  // but looking at ModernChatScreen, it doesn't seem to call these directly for sending.
  // It relies on the provider stream updates.

  // If ModernChatScreen calls these, we should ideally remove usage there too,
  // but to preserve API compatibility we can leave no-ops or delegate to repo if needed.
  // However, since repo.sendMessage writes to DB, the stream updates automatically.
  void addOptimisticMessage(MessageModel message) {
    // No-op: Repository handles DB write -> Stream update
  }

  void updateOptimisticMessage(MessageModel message) {
    // No-op: Repository handles DB write -> Stream update
  }

  void removeOptimisticMessage(String messageId) {
    // No-op: Repository handles DB write -> Stream update
  }
}
