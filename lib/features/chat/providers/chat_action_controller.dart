import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:Vista/model/message_model.dart';
import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/security/logging_utility.dart';
import 'package:Vista/features/chat/services/message_actions_service.dart';
import 'package:Vista/features/chat/domain/message_payload.dart';
import 'package:Vista/services/session_manager_service_v2.dart';

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

    state = state.copyWith(isLoading: true);

    try {
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

      final result = await repository.sendMessage(payload);

      return result.fold(
        (success) {
          state = const ChatActionState(); // Reset state on success
          return const ActionResult.success();
        },
        (failure) {
          state = state.copyWith(isLoading: false);
          return ActionResult.failure(failure);
        },
      );
    } catch (e) {
      logInfo('Send Message Failed: $e');
      state = state.copyWith(isLoading: false);
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      return ActionResult.failure(errMsg);
    }
  }

  Future<ActionResult<void>> editMessage({
    required String messageId,
    required String newContent,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final repository = ref.read(chatRepositoryProvider);

      await repository.editMessage(messageId, newContent);

      state = const ChatActionState();
      return const ActionResult.success();
    } catch (e) {
      logInfo('Edit Message Failed: $e');
      state = state.copyWith(isLoading: false);
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      return ActionResult.failure(errMsg);
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId,
      {bool forEveryone = false}) async {
    state = state.copyWith(isLoading: true);
    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.deleteMessage(messageId, forEveryone: forEveryone);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      logInfo('Delete Message Failed: $e');
      state = state.copyWith(isLoading: false);
    }
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
