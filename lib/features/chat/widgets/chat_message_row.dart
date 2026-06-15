import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/message_model.dart';
import '../domain/chat_render_descriptor.dart';
import '../performance/adaptive_effects_provider.dart';
import '../providers/chat_message_store_provider.dart';
import '../theme/chat_theme.dart';
import 'chat_message_bindings.dart';
import 'chat_message_list_tile.dart';
import 'chat_selection_controller.dart';
import 'date_divider.dart' as date_divider;
import 'molecular_delete_animation.dart';
import 'swipe_to_reply_wrapper.dart';
import 'unread_messages_divider.dart';
import '../performance/chat_message_render_window.dart';

/// One chat list row. Rebuilds only when its own messages/selection/effects change.
class ChatMessageRow extends ConsumerWidget {
  const ChatMessageRow({
    super.key,
    required this.descriptor,
    required this.layout,
  });

  final ChatRenderDescriptor descriptor;
  final ChatMessageRowLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindings = ChatMessageBindingsScope.of(context);
    final conversationId = bindings.conversationId;

    final rowMessages = <MessageModel>[];
    for (final messageId in descriptor.messageIds) {
      final message = ref.watch(
        chatMessageEntryProvider(conversationId, messageId),
      );
      if (message == null) return const SizedBox.shrink();
      rowMessages.add(message);
    }

    final messagesById =
        ref.read(chatMessageStoreProvider(conversationId)).byId;

    final rowSelection = ref.watch(
      conversationChatSelectionProvider(conversationId).select(
        (state) => ChatRowSelectionSlice.from(descriptor.messageIds, state),
      ),
    );
    final selection = ChatSelectionState(
      isSelectionMode: rowSelection.isSelectionMode,
      selectedMessageIds: rowSelection.selectedIds,
    );
    final isRowSelected = rowSelection.isRowSelected;

    ref.watch(
      adaptiveEffectsProvider.select(
        (state) => (
          state.isFastScrolling,
          state.enableMessageEntryAnimation,
          state.effectsLevel,
          state.chatEntryMode,
          state.motionTokensEnabled,
        ),
      ),
    );
    final effects = ref.read(adaptiveEffectsProvider);

    final primary = rowMessages.first;
    final isMe = primary.senderId == bindings.currentUserId;
    final fastScroll = effects.isFastScrolling;
    final isDeleting =
        rowMessages.any((message) => bindings.isMessageDeleting(message.id));

    final gallery = bindings.conversationGallery;

    Widget bubble;
    if (descriptor.isAlbum) {
      bubble = bindings.buildAlbumBubble(
        ChatAlbumBubbleBuildRequest(
          messages: rowMessages,
          primaryIndex: descriptor.primaryIndex,
          isMe: isMe,
          isFirstInGroup: layout.isFirstInGroup,
          isLastInGroup: layout.isLastInGroup,
          adaptiveEffects: effects,
          selection: selection,
          messagesById: messagesById,
          conversationGalleryItems: gallery.items,
          conversationGalleryIndexByMessageId: gallery.indexByMessageId,
        ),
      );
    } else if (!selection.isSelectionMode && !fastScroll) {
      bubble = SwipeToReplyWrapper(
        isMe: isMe,
        onReply: () => bindings.onReplyToMessage(primary),
        child: bindings.buildBubble(
          ChatBubbleBuildRequest(
            message: primary,
            isMe: isMe,
            index: descriptor.primaryIndex,
            isFirstInGroup: layout.isFirstInGroup,
            isLastInGroup: layout.isLastInGroup,
            adaptiveEffects: effects,
            selection: selection,
            messagesById: messagesById,
            conversationGalleryItems: gallery.items,
            conversationGalleryIndexByMessageId: gallery.indexByMessageId,
          ),
        ),
      );
    } else {
      bubble = bindings.buildBubble(
        ChatBubbleBuildRequest(
          message: primary,
          isMe: isMe,
          index: descriptor.primaryIndex,
          isFirstInGroup: layout.isFirstInGroup,
          isLastInGroup: layout.isLastInGroup,
          adaptiveEffects: effects,
          selection: selection,
          messagesById: messagesById,
          conversationGalleryItems: gallery.items,
          conversationGalleryIndexByMessageId: gallery.indexByMessageId,
        ),
      );
    }

    final isHidden = rowMessages.any(
      (message) => bindings.isMessageTemporarilyHidden(message.id),
    );

    final messageWidget = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (layout.showDateDivider)
          date_divider.DateDivider(date: rowMessages.last.createdAt),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (selection.isSelectionMode) {
              bindings.onToggleRenderItemSelection(descriptor.messageIds);
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            if (selection.isSelectionMode) {
              bindings.onToggleRenderItemSelection(descriptor.messageIds);
            } else {
              bindings.onEnterSelectionMode(descriptor.messageIds);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: RepaintBoundary(
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (selection.isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _SelectionCheckbox(
                        selected: isRowSelected,
                        onTap: () => bindings.onToggleRenderItemSelection(
                          descriptor.messageIds,
                        ),
                      ),
                    ),
                  Flexible(
                    child: Opacity(
                      opacity: isHidden ? 0.0 : 1.0,
                      child: bubble,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (layout.showUnreadDivider)
          UnreadMessagesDivider(
            unreadCount: bindings.unreadCount,
            onTap: bindings.onScrollToBottom,
          ),
      ],
    );

    return ChatMessageListTile(
      keepAlive: !fastScroll &&
          ChatMessageRenderWindow.shouldKeepAliveMessages(rowMessages),
      child: KeyedSubtree(
        key: ValueKey<String>(descriptor.key),
        child: MolecularDeleteAnimation(
          isDeleting: isDeleting,
          onAnimationComplete: () =>
              bindings.onDeleteAnimationComplete(descriptor.messageIds),
          child: messageWidget,
        ),
      ),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 200),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? theme.sendButtonColor : Colors.transparent,
            border: Border.all(
              color:
                  selected ? theme.sendButtonColor : theme.secondaryTextColor,
              width: 2,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : null,
        ),
      ),
    );
  }
}
