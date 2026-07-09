import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Vista/model/message_model.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/security/logging_utility.dart';
import 'package:Vista/features/chat/services/message_actions_service.dart';
import 'package:Vista/features/chat/domain/message_payload.dart';
import 'package:Vista/services/session_manager_service_v2.dart';
import 'package:Vista/services/notification_sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'chat_action_controller.g.dart';

/// وضعیت اکشن‌های چت (ریپلای، ادیت)
class ChatActionState {
  final MessageModel? replyMessage;
  final MessageModel? editMessage;
  final bool isLoading;

  const ChatActionState({
    this.replyMessage,
    this.editMessage,
    this.isLoading = false,
  });

  bool get isReplying => replyMessage != null;
  bool get isEditing => editMessage != null;

  ChatActionState copyWith({
    MessageModel? replyMessage,
    MessageModel? editMessage,
    bool? isLoading,
    bool clearReply = false,
    bool clearEdit = false,
  }) {
    return ChatActionState(
      replyMessage: clearReply ? null : (replyMessage ?? this.replyMessage),
      editMessage: clearEdit ? null : (editMessage ?? this.editMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

@riverpod
class ChatActionController extends _$ChatActionController {
  @override
  ChatActionState build() {
    return const ChatActionState();
  }

  void setReply(MessageModel message) {
    state = state.copyWith(replyMessage: message, clearEdit: true);
  }

  void setEdit(MessageModel message) {
    state = state.copyWith(editMessage: message, clearReply: true);
  }

  void cancelAction() {
    state = const ChatActionState();
  }

  Future<ActionResult<void>> sendMessage({
    required String conversationId,
    required String content,
    String? id,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
    int? duration,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    String? replyToKind,
    String? mediaGroupId,
    String? recipientPublicKey,
  }) async {
    if (!await SessionManagerServiceV2.instance.ensureValidAuthSession()) {
      return const ActionResult.failure('User not logged in');
    }

    final repository = ref.read(chatRepositoryProvider);

    final payload = MessagePayload(
      conversationId: conversationId,
      content: content,
      id: id,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      attachmentMimeType: attachmentMimeType,
      attachmentSizeBytes: attachmentSizeBytes,
      audioTitle: audioTitle,
      audioArtist: audioArtist,
      audioAlbum: audioAlbum,
      duration: duration,
      replyToMessageId: replyToMessageId ?? state.replyMessage?.id,
      replyToContent: replyToContent ?? state.replyMessage?.content,
      replyToSenderName: replyToSenderName ?? state.replyMessage?.senderName,
      replyToKind: replyToKind,
      mediaGroupId: mediaGroupId,
      recipientPublicKey: recipientPublicKey,
    );

    // Reset action state immediately — don't block UI waiting for HTTP response.
    // Repository writes optimistic message to Isar synchronously before the HTTP
    // call, so the message appears in the chat list within 1 frame (16ms debounce).
    // Send failure is reflected via isFailed=true on the message bubble (retry tap).
    state = const ChatActionState();
    NotificationSoundService.instance.playMessageSentSound();

    unawaited(repository.sendMessage(payload).then((result) {
      result.fold(
        (_) => null, // Stream confirms via Isar write — no-op here
        (error) => logInfo('sendMessage background error: $error'),
      );
    }));

    return const ActionResult.success();
  }

  Future<ActionResult<void>> resendMessage(MessageModel message) async {
    // A failed secret-chat message must be re-encrypted on retry. The peer
    // key is stored per conversation; omitting it here would silently resend
    // the plaintext of an E2EE message.
    final prefs = await SharedPreferences.getInstance();
    final recipientPublicKey =
        prefs.getString('e2e_peer_pub_${message.conversationId}');

    return sendMessage(
      conversationId: message.conversationId,
      content: message.content,
      id: message.id,
      recipientPublicKey: recipientPublicKey,
      attachmentUrl: message.attachmentUrl,
      attachmentType: message.attachmentType,
      attachmentFileName: message.attachmentFileName,
      attachmentMimeType: message.attachmentMimeType,
      attachmentSizeBytes: message.attachmentSizeBytes,
      replyToMessageId: message.replyToMessageId,
      replyToContent: message.replyToContent,
      replyToSenderName: message.replyToSenderName,
      mediaGroupId: message.mediaGroupId,
    );
  }

  Future<ActionResult<void>> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    final original = state.editMessage;
    final conversationId = original?.conversationId;

    if (original != null && conversationId != null) {
      ref
          .read(chatMessagesProvider(conversationId).notifier)
          .updateOptimisticMessage(original.copyWith(
            content: newContent,
            editedAt: DateTime.now(),
          ));
    }

    state = const ChatActionState(); // dismiss edit bar immediately

    unawaited(
      ref.read(chatRepositoryProvider).editMessage(messageId, newContent).then(
        (result) {
          result.fold(
            (_) => null, // Isar stream confirms — no-op
            (error) {
              logInfo('editMessage background error: $error');
              // Rollback: restore original content
              if (original != null && conversationId != null) {
                ref
                    .read(chatMessagesProvider(conversationId).notifier)
                    .updateOptimisticMessage(original);
              }
            },
          );
        },
      ),
    );

    return const ActionResult.success();
  }

  Future<void> deleteMessage(
    String conversationId,
    String messageId, {
    bool forEveryone = false,
  }) async {
    final messagesNotifier =
        ref.read(chatMessagesProvider(conversationId).notifier);

    // Snapshot for rollback before removing (null = no rollback on failure)
    final msgs = ref.read(chatMessagesProvider(conversationId)).valueOrNull;
    MessageModel? snapshot;
    if (msgs != null) {
      for (final m in msgs) {
        if (m.id == messageId) {
          snapshot = m;
          break;
        }
      }
    }

    messagesNotifier.removeMessageLocally(messageId);
    state = state.copyWith(isLoading: false);

    unawaited(
      ref
          .read(chatRepositoryProvider)
          .deleteMessage(messageId, forEveryone: forEveryone)
          .then((result) {
        result.fold(
          (_) => null, // Isar confirms — no-op
          (error) {
            logInfo('deleteMessage background error: $error');
            // Rollback: put message back
            if (snapshot != null) {
              messagesNotifier.restoreMessageLocally(snapshot);
            }
          },
        );
      }),
    );
  }

  // Keep toggleReaction for compatibility or move logic
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await ref.read(chatRepositoryProvider).toggleReaction(
            messageId: messageId,
            conversationId: conversationId,
            emoji: emoji,
          );
    } catch (e) {
      logInfo('Toggle Reaction Failed: $e');
    }
  }
}
