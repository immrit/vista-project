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
  // emit. Starts at 300 (render window is hard-capped at 180) and GROWS as the
  // user pages older history in — a fixed cap silently hid every message past
  // the newest 300 even though loadMore had written them to Isar.
  static const int _initialWatchWindow = 300;
  static const int _maxWatchWindow = 2200;
  int _watchWindow = _initialWatchWindow;

  int _subscriptionGeneration = 0;
  int _eventRevision = 0;

  bool _hasMore = true;

  /// True while older history may still exist on the server. paginationState
  /// reads this to stop the load-more spinner at the top of the list.
  bool get hasMore => _hasMore;

  // Delta decryption cache: messageId → decrypted content
  // Avoids re-decrypting messages whose content hasn't changed between stream emits.
  final Map<String, String> _decryptCache = {};

  // Cached ECDH shared secret so we don't re-derive it on every stream emit.
  // Keyed by the peer public key: if the peer rotates keys, the key changes
  // and the cache is invalidated automatically.
  SecretKey? _cachedSharedSecret;
  String? _cachedSharedSecretPeerKey;

  @override
  FutureOr<List<MessageModel>> build(String conversationId) async {
    final repository = ref.watch(chatRepositoryProvider);
    _chatRepository = repository;

    _realtimeSubscription?.cancel();
    _decryptCache.clear();
    _cachedSharedSecret = null;
    _cachedSharedSecretPeerKey = null;
    _watchWindow = _initialWatchWindow;
    _hasMore = true;

    // Cleanup on dispose
    ref.onDispose(() {
      _subscriptionGeneration++;
      _eventRevision++;
      _realtimeSubscription?.cancel();
      _decryptCache.clear();
      _cachedSharedSecret = null;
      _cachedSharedSecretPeerKey = null;
    });

    _subscribe(conversationId);

    // Initial value while stream connects (Isar usually fires immediately)
    return state.valueOrNull ?? const [];
  }

  // Return the stream from repository directly.
  // This is the SINGLE SOURCE OF TRUTH.
  void _subscribe(String conversationId) {
    final generation = ++_subscriptionGeneration;
    _realtimeSubscription?.cancel();
    _realtimeSubscription = _chatRepository!
        .watchMessages(conversationId, limit: _watchWindow)
        .listen(
      (messages) async {
        final revision = ++_eventRevision;
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
          if (generation != _subscriptionGeneration ||
              revision != _eventRevision) {
            return;
          }
          state = AsyncValue.data(decryptedMessages);
        } else {
          if (generation != _subscriptionGeneration ||
              revision != _eventRevision) {
            return;
          }
          state = AsyncValue.data(messages);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _subscriptionGeneration) return;
        logError(
          'watchMessages stream failed',
          error: error,
          stackTrace: stackTrace,
        );
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }

  Future<List<MessageModel>> _decryptMessages(
      List<MessageModel> originalMessages, String convId) async {
    final prefs = await SharedPreferences.getInstance();
    final peerPubB64 = prefs.getString('e2e_peer_pub_$convId');
    if (peerPubB64 == null) return _markEncryptedUnavailable(originalMessages);

    final userId = await TokenStorage.getUserId();
    if (userId == null) return _markEncryptedUnavailable(originalMessages);

    final e2e = E2EEncryptionService();
    final myKeyPair = await e2e.getSavedKeyPair(userId);
    if (myKeyPair == null) return _markEncryptedUnavailable(originalMessages);

    SecretKey? sharedSecret;
    if (_cachedSharedSecret != null &&
        _cachedSharedSecretPeerKey == peerPubB64) {
      // Same peer key as last emit → reuse the derived secret (skip ECDH).
      sharedSecret = _cachedSharedSecret;
    } else {
      try {
        sharedSecret = await e2e.computeSharedSecret(
          myKeyPair: myKeyPair,
          peerPublicKeyBytes: base64Decode(peerPubB64),
        );
        _cachedSharedSecret = sharedSecret;
        _cachedSharedSecretPeerKey = peerPubB64;
      } catch (_) {
        return _markEncryptedUnavailable(originalMessages);
      }
    }
    if (sharedSecret == null) {
      return _markEncryptedUnavailable(originalMessages);
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

      // Reply previews are encrypted with the same secret (they quote the
      // plaintext of an earlier E2EE message) — decrypt them alongside the
      // body so the quoted bubble never shows ciphertext.
      final decryptedReply =
          await _decryptField(e2e, m, m.replyToContent, sharedSecret);

      // Cache hit: same ciphertext → reuse decrypted result
      final cacheKey = '${m.id}:${m.content}';
      final cached = _decryptCache[cacheKey];
      if (cached != null) {
        decryptedList
            .add(m.copyWith(content: cached, replyToContent: decryptedReply));
        continue;
      }

      // Cache miss. decryptMessage handles all three cases via the envelope
      // prefix + MAC oracle (no fragile length/space heuristic):
      //   v1 envelope   → decrypts, or throws E2EDecryptException on tamper
      //   legacy cipher → decrypts (raw shared secret)
      //   plaintext     → returned unchanged (MAC mismatch / not base64)
      try {
        final decryptedContent = await e2e.decryptMessage(
          m.content,
          sharedSecret,
          binding: E2EEncryptionService.messageBinding(
            conversationId: m.conversationId,
            senderId: m.senderId,
            messageId: m.id,
          ),
        );
        if (decryptedContent == m.content) {
          // Plaintext (or undecryptable) — don't cache, leave as-is.
          decryptedList.add(m.copyWith(replyToContent: decryptedReply));
        } else {
          _decryptCache[cacheKey] = decryptedContent;
          decryptedList.add(m.copyWith(
              content: decryptedContent, replyToContent: decryptedReply));
        }
      } on E2EDecryptException {
        // Authenticated v1 envelope failed MAC → tampering or wrong key.
        decryptedList.add(m.copyWith(
            content: '⚠️ پیام دستکاری‌شده', replyToContent: decryptedReply));
      } catch (_) {
        decryptedList.add(m.copyWith(
            content: '⚠️ پیام رمزگشایی نشد', replyToContent: decryptedReply));
      }
    }
    return decryptedList;
  }

  /// Decrypts an optional secondary field (reply preview). Plaintext or
  /// legacy values come back unchanged; failures degrade to the original.
  Future<String?> _decryptField(
    E2EEncryptionService e2e,
    MessageModel message,
    String? value,
    SecretKey sharedSecret,
  ) async {
    if (value == null || value.isEmpty) return value;
    final cacheKey = '${message.id}:reply:$value';
    final cached = _decryptCache[cacheKey];
    if (cached != null) return cached;
    try {
      final decrypted = await e2e.decryptMessage(
        value,
        sharedSecret,
        binding: E2EEncryptionService.messageBinding(
          conversationId: message.conversationId,
          senderId: message.senderId,
          messageId: message.id,
          field: 'reply',
        ),
      );
      if (decrypted != value) _decryptCache[cacheKey] = decrypted;
      return decrypted;
    } catch (_) {
      return '⚠️ پیش‌نمایش رمزگشایی نشد';
    }
  }

  List<MessageModel> _markEncryptedUnavailable(List<MessageModel> messages) {
    return messages.map((message) {
      if (message.messageType == 'exchange_key' ||
          message.messageType == 'exchange_key_reply' ||
          message.content.isEmpty) {
        return message;
      }
      return message.copyWith(
        content: '🔒 کلید رمزگشایی در دسترس نیست',
        replyToContent:
            message.replyToContent == null ? null : '🔒 پیش‌نمایش رمزگشایی نشد',
      );
    }).toList(growable: false);
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
          _hasMore = repository.hasMoreMessages(conversationId);
          if (newMessages.isEmpty) {
            _hasMore = false;
            return;
          }
          // The fetched page is now in Isar, but the watch only surfaces the
          // newest [_watchWindow] rows — grow the window and resubscribe or
          // the older page stays invisible forever.
          final requestedWindow =
              currentMessages.length + newMessages.length + _pageSize;
          _watchWindow = requestedWindow > _maxWatchWindow
              ? _maxWatchWindow
              : requestedWindow;
          _subscribe(conversationId);
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
