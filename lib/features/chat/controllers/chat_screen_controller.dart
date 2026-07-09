import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../model/message_model.dart';

class ChatScreenState {
  final MessageModel? replyToMessage;
  final MessageModel? editToMessage;
  final bool isSearchMode;
  final String? highlightedMessageId;
  final bool isOtherUserBlocked;
  final bool isCurrentUserBlocked;
  final String? reactionPickerMessageId;

  final Set<String> deletingMessageIds;

  const ChatScreenState({
    this.replyToMessage,
    this.editToMessage,
    this.isSearchMode = false,
    this.highlightedMessageId,
    this.isOtherUserBlocked = false,
    this.isCurrentUserBlocked = false,
    this.reactionPickerMessageId,
    this.deletingMessageIds = const {},
  });

  ChatScreenState copyWith({
    MessageModel? replyToMessage,
    bool clearReply = false,
    MessageModel? editToMessage,
    bool clearEdit = false,
    bool? isSearchMode,
    String? highlightedMessageId,
    bool clearHighlight = false,
    bool? isOtherUserBlocked,
    bool? isCurrentUserBlocked,
    String? reactionPickerMessageId,
    bool clearReactionPicker = false,
    Set<String>? deletingMessageIds,
  }) {
    return ChatScreenState(
      replyToMessage: clearReply ? null : (replyToMessage ?? this.replyToMessage),
      editToMessage: clearEdit ? null : (editToMessage ?? this.editToMessage),
      isSearchMode: isSearchMode ?? this.isSearchMode,
      highlightedMessageId: clearHighlight ? null : (highlightedMessageId ?? this.highlightedMessageId),
      isOtherUserBlocked: isOtherUserBlocked ?? this.isOtherUserBlocked,
      isCurrentUserBlocked: isCurrentUserBlocked ?? this.isCurrentUserBlocked,
      reactionPickerMessageId: clearReactionPicker ? null : (reactionPickerMessageId ?? this.reactionPickerMessageId),
      deletingMessageIds: deletingMessageIds ?? this.deletingMessageIds,
    );
  }
}

class ChatScreenController extends StateNotifier<ChatScreenState> {
  ChatScreenController() : super(const ChatScreenState());

  void setReplyTo(MessageModel? message) {
    state = state.copyWith(replyToMessage: message, clearReply: message == null);
  }

  void setEditTo(MessageModel? message) {
    state = state.copyWith(editToMessage: message, clearEdit: message == null);
  }

  void setSearchMode(bool active) {
    state = state.copyWith(isSearchMode: active, clearHighlight: !active);
  }

  void setHighlightedMessage(String? id) {
    state = state.copyWith(highlightedMessageId: id, clearHighlight: id == null);
  }

  void setBlockedStatus({bool? otherUser, bool? currentUser}) {
    state = state.copyWith(
      isOtherUserBlocked: otherUser,
      isCurrentUserBlocked: currentUser,
    );
  }

  void showReactionPicker(String? messageId) {
    state = state.copyWith(
      reactionPickerMessageId: messageId,
      clearReactionPicker: messageId == null,
    );
  }
}

final chatScreenControllerProvider = StateNotifierProvider.autoDispose.family<ChatScreenController, ChatScreenState, String>((ref, conversationId) {
  return ChatScreenController();
});
