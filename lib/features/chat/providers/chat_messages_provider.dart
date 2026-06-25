import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Vista/model/message_model.dart';

import 'package:Vista/features/chat/repositories/chat_repository.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';

import 'package:Vista/security/logging_utility.dart';
import 'dart:async';
import 'package:Vista/features/chat/services/e2e_encryption_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';
import 'package:Vista/core/data/cache/cache_repository.dart';
import 'package:Vista/features/auth/providers/auth_controller.dart';
import 'dart:convert';
import 'package:Vista/services/notification_sound_service.dart';

part 'chat_messages_provider.g.dart';

@riverpod
class ChatMessages extends _$ChatMessages {
  ChatRepository? _chatRepository;
  StreamSubscription? _realtimeSubscription;
  static const int _pageSize = 20;

  // Cap how many newest messages the realtime watch deserializes/processes per
  // emit. The on-screen render window (ChatMessageRenderWindow) is hard-capped
  // at 180, so a fixed window comfortably above that feeds the UI fully while
  // never re-mapping the entire conversation history on each change.
  static const int _watchWindow = 300;

  bool _hasMore = true;

  // Delta decryption cache: messageId → decrypted content
  // Avoids re-decrypting messages whose content hasn't changed between stream emits.
  final Map<String, String> _decryptCache = {};

  @override
  FutureOr<List<MessageModel>> build(String conversationId) async {
    final repository = ref.watch(chatRepositoryProvider);
    _chatRepository = repository;

    _realtimeSubscription?.cancel();
    _decryptCache.clear();

    // Cleanup on dispose
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _decryptCache.clear();
    });

    // Return the stream from repository directly.
    // This is the SINGLE SOURCE OF TRUTH.
    _realtimeSubscription =
        repository.watchMessages(conversationId, limit: _watchWindow).listen(
      (messages) async {
        final currentMessages = state.valueOrNull ?? [];
        if (currentMessages.isNotEmpty && messages.isNotEmpty) {
          final newestMessage = messages.first;
          final oldNewestMessage = currentMessages.first;

          if (newestMessage.id != oldNewestMessage.id ||
              (newestMessage.createdAt.isAfter(oldNewestMessage.createdAt) &&
                  newestMessage.id == oldNewestMessage.id &&
                  currentMessages.length < messages.length)) {
            final currentUserId = await TokenStorage.getUserId();
            if (newestMessage.senderId != currentUserId) {
              NotificationSoundService.instance.playMessageReceivedSound();
            }
          }
        }

        // ✅ تلاش برای رمزگشایی اگر چت از نوع سکرت باشد
        final conversation =
            CacheRepository().getConversationSync(conversationId);
        if (conversation != null && conversation.isSecret) {
          final decryptedMessages =
              await _decryptMessages(messages, conversationId);
          state = AsyncValue.data(decryptedMessages);
        } else {
          state = AsyncValue.data(messages);
        }
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

  Future<List<MessageModel>> _decryptMessages(
      List<MessageModel> originalMessages, String convId) async {
    final prefs = await SharedPreferences.getInstance();
    final peerPubB64 = prefs.getString('e2e_peer_pub_$convId');
    if (peerPubB64 == null) return originalMessages;

    final userId = await TokenStorage.getUserId();
    if (userId == null) return originalMessages;

    final e2e = E2EEncryptionService();
    final myKeyPair = await e2e.getSavedKeyPair(userId);
    if (myKeyPair == null) return originalMessages;

    SecretKey? sharedSecret;
    try {
      sharedSecret = await e2e.computeSharedSecret(
        myKeyPair: myKeyPair,
        peerPublicKeyBytes: base64Decode(peerPubB64),
      );
    } catch (_) {
      return originalMessages;
    }

    // Remove stale cache entries (messages no longer in the list)
    final incomingIds = originalMessages.map((m) => m.id).toSet();
    _decryptCache.removeWhere((id, _) => !incomingIds.contains(id));

    final decryptedList = <MessageModel>[];
    for (var m in originalMessages) {
      if (m.messageType == 'exchange_key' ||
          m.messageType == 'exchange_key_reply' ||
          m.content.isEmpty) {
        decryptedList.add(m);
        continue;
      }

      // Cache hit: same ciphertext → reuse decrypted result
      final cacheKey = '${m.id}:${m.content}';
      final cached = _decryptCache[cacheKey];
      if (cached != null) {
        decryptedList.add(m.copyWith(content: cached));
        continue;
      }

      // Cache miss: decrypt and store
      try {
        if (m.content.length > 20 && !m.content.contains(' ')) {
          final decryptedContent =
              await e2e.decryptMessage(m.content, sharedSecret);
          if (decryptedContent != '[پیام غیرقابل رمزگشایی]') {
            _decryptCache[cacheKey] = decryptedContent;
            decryptedList.add(m.copyWith(content: decryptedContent));
            continue;
          }
        }
      } catch (_) {}

      decryptedList.add(m);
    }
    return decryptedList;
  }

  Future<void> loadMore() async {
    try {
      final ChatRepository repository =
          _chatRepository ?? ref.read(chatRepositoryProvider);
      _chatRepository = repository;
      if (!_hasMore || state.isLoading) return;

      final currentMessages = state.value ?? [];
      final oldestMessage =
          currentMessages.isNotEmpty ? currentMessages.last : null;

      if (oldestMessage == null) return;

      // Correctly load older messages using the repository
      final result = await repository.loadMoreMessages(
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

  // Optimistic updates: immediately mutate in-memory state (0ms latency).
  // Stream fires ~16ms later; ChatMessageDiff reconciles without rebuilding
  // unchanged bubbles (identical() fast path on unchanged instances).

  void addOptimisticMessage(MessageModel message) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncValue.data([message, ...current]);
  }

  void updateOptimisticMessage(MessageModel message) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final m in current) m.id == message.id ? message : m,
    ]);
  }

  void removeOptimisticMessage(String messageId) {
    removeMessageLocally(messageId);
  }

  void removeMessageLocally(String messageId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.where((message) => message.id != messageId).toList(),
    );
  }

  void restoreMessageLocally(MessageModel message) {
    final current = state.valueOrNull ?? const <MessageModel>[];
    if (current.any((item) => item.id == message.id)) return;
    state = AsyncValue.data([message, ...current]);
  }

  void clearMessagesLocally() {
    state = const AsyncValue.data([]);
  }
}
