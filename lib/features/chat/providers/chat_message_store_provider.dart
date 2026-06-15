import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../model/message_model.dart';
import '../domain/chat_message_store_state.dart';
import '../domain/chat_render_descriptor.dart';
import '../services/chat_message_diff.dart';
import '../widgets/chat_selection_controller.dart';
import 'chat_messages_provider.dart';

part 'chat_message_store_provider.g.dart';

@riverpod
class ChatMessageStore extends _$ChatMessageStore {
  @override
  ChatMessageStoreState build(String conversationId) {
    ref.listen(
      chatMessagesProvider(conversationId),
      (previous, next) {
        next.whenData(_syncMessages);
      },
      fireImmediately: true,
    );
    return const ChatMessageStoreState.empty();
  }

  void _syncMessages(List<MessageModel> messages) {
    state = ChatMessageDiff.apply(state, messages);
  }
}

/// Watches a single message entry. Only rebuilds when that message changes.
@riverpod
MessageModel? chatMessageEntry(
  ChatMessageEntryRef ref,
  String conversationId,
  String messageId,
) {
  return ref.watch(
    chatMessageStoreProvider(conversationId).select(
      (store) => store.byId[messageId],
    ),
  );
}

@riverpod
class ConversationChatSelection extends _$ConversationChatSelection
    implements ChatSelectionStateLike {
  @override
  ChatSelectionState build(String conversationId) {
    return const ChatSelectionState.empty();
  }

  void enterSelectionMode(String messageId) {
    if (messageId.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {...state.selectedMessageIds, messageId},
    );
  }

  void enterSelectionModeForMessages(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {...state.selectedMessageIds, ...ids},
    );
  }

  void exitSelectionMode() {
    state = const ChatSelectionState.empty();
  }

  void toggleMessageSelection(String messageId) {
    if (messageId.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    final selected = {...state.selectedMessageIds};
    if (selected.contains(messageId)) {
      selected.remove(messageId);
      state = selected.isEmpty
          ? const ChatSelectionState.empty()
          : state.copyWith(selectedMessageIds: selected);
      return;
    }
    selected.add(messageId);
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: selected,
    );
  }

  void toggleRenderItemSelection(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;

    HapticFeedback.selectionClick();
    final selected = {...state.selectedMessageIds};
    final allSelected = ids.every(selected.contains);
    if (allSelected) {
      selected.removeAll(ids);
      state = selected.isEmpty
          ? const ChatSelectionState.empty()
          : state.copyWith(selectedMessageIds: selected);
      return;
    }
    selected.addAll(ids);
    state = state.copyWith(
      isSelectionMode: true,
      selectedMessageIds: selected,
    );
  }

  @override
  Set<String> get selectedMessageIds => state.selectedMessageIds;

  @override
  bool get isSelectionMode => state.isSelectionMode;
}