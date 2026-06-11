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
      (messages) async {
        final currentMessages = state.valueOrNull ?? [];
        if (currentMessages.isNotEmpty && messages.isNotEmpty) {
           final newestMessage = messages.first;
           final oldNewestMessage = currentMessages.first;
           
           if (newestMessage.id != oldNewestMessage.id || (newestMessage.createdAt.isAfter(oldNewestMessage.createdAt) && newestMessage.id == oldNewestMessage.id && currentMessages.length < messages.length)) {
              final currentUserId = await TokenStorage.getUserId();
              if (newestMessage.senderId != currentUserId) {
                 NotificationSoundService.instance.playMessageReceivedSound();
              }
           }
        }

        // ✅ تلاش برای رمزگشایی اگر چت از نوع سکرت باشد
        final conversation = CacheRepository().getConversationSync(conversationId);
        if (conversation != null && conversation.isSecret) {
           final decryptedMessages = await _decryptMessages(messages, conversationId);
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

  Future<List<MessageModel>> _decryptMessages(List<MessageModel> originalMessages, String convId) async {
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

    final decryptedList = <MessageModel>[];
    for (var m in originalMessages) {
       // Only try decrypting normal text/media content, not system exchange keys
       if (m.messageType != 'exchange_key' && m.messageType != 'exchange_key_reply' && m.content.isNotEmpty) {
           try {
              // Basic check if it looks like base64
              if (m.content.length > 20 && !m.content.contains(' ')) {
                 final decryptedContent = await e2e.decryptMessage(m.content, sharedSecret);
                 if (decryptedContent != '[پیام غیرقابل رمزگشایی]') {
                     decryptedList.add(m.copyWith(content: decryptedContent));
                     continue;
                 }
              }
           } catch (_) {}
       }
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
