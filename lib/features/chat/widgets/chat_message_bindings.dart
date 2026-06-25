import 'package:flutter/material.dart';

import '../../../model/message_model.dart';
import '../performance/chat_performance_profile.dart';
import 'chat_selection_controller.dart';
import 'full_screen_image_viewer.dart';

/// Immutable request object passed to the screen-owned bubble builder.
@immutable
class ChatBubbleBuildRequest {
  const ChatBubbleBuildRequest({
    required this.message,
    required this.isMe,
    required this.index,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.adaptiveEffects,
    required this.selection,
    required this.messagesById,
    this.conversationGalleryItems,
    this.conversationGalleryIndexByMessageId,
  });

  final MessageModel message;
  final bool isMe;
  final int index;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final AdaptiveEffectsState adaptiveEffects;
  final ChatSelectionState selection;
  final Map<String, MessageModel> messagesById;
  final List<GalleryItem>? conversationGalleryItems;
  final Map<String, int>? conversationGalleryIndexByMessageId;
}

@immutable
class ChatAlbumBubbleBuildRequest {
  const ChatAlbumBubbleBuildRequest({
    required this.messages,
    required this.primaryIndex,
    required this.isMe,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.adaptiveEffects,
    required this.selection,
    required this.messagesById,
    this.conversationGalleryItems,
    this.conversationGalleryIndexByMessageId,
  });

  final List<MessageModel> messages;
  final int primaryIndex;
  final bool isMe;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final AdaptiveEffectsState adaptiveEffects;
  final ChatSelectionState selection;
  final Map<String, MessageModel> messagesById;
  final List<GalleryItem>? conversationGalleryItems;
  final Map<String, int>? conversationGalleryIndexByMessageId;
}

typedef ChatBubbleBuilder = Widget Function(ChatBubbleBuildRequest request);
typedef ChatAlbumBubbleBuilder = Widget Function(
    ChatAlbumBubbleBuildRequest request);

/// Screen-owned callbacks for message row rendering.
@immutable
class ChatMessageBindings {
  const ChatMessageBindings({
    required this.conversationId,
    required this.currentUserId,
    required this.buildBubble,
    required this.buildAlbumBubble,
    required this.buildLoadingIndicator,
    required this.buildEmptyState,
    required this.onToggleRenderItemSelection,
    required this.onEnterSelectionMode,
    required this.onScrollToBottom,
    required this.isMessageDeleting,
    required this.isMessageTemporarilyHidden,
    required this.onReplyToMessage,
    required this.onDeleteAnimationComplete,
    required this.unreadCount,
    required this.shouldShowUnreadDivider,
    required this.getMessageGroupPosition,
    required this.shouldShowDateDivider,
    required this.conversationGallery,
    required this.overlayRevision,
    required this.galleryStructureVersion,
  });

  final String conversationId;
  final String? currentUserId;
  final int overlayRevision;
  final int galleryStructureVersion;
  final ChatBubbleBuilder buildBubble;
  final ChatAlbumBubbleBuilder buildAlbumBubble;
  final Widget Function() buildLoadingIndicator;
  final Widget Function() buildEmptyState;
  final void Function(List<String> messageIds) onToggleRenderItemSelection;
  final void Function(List<String> messageIds) onEnterSelectionMode;
  final VoidCallback onScrollToBottom;
  final bool Function(String messageId) isMessageDeleting;
  final bool Function(String messageId) isMessageTemporarilyHidden;
  final void Function(MessageModel message) onReplyToMessage;
  final void Function(List<String> messageIds) onDeleteAnimationComplete;
  final int unreadCount;
  final bool Function(List<String> messageIds, int index, int totalRows)
      shouldShowUnreadDivider;
  final (bool, bool) Function(int primaryIndex, int spanLength)
      getMessageGroupPosition;
  final bool Function(DateTime current, DateTime? older) shouldShowDateDivider;
  final ({
    List<GalleryItem> items,
    Map<String, int> indexByMessageId,
  }) conversationGallery;
}

class ChatMessageBindingsScope extends InheritedWidget {
  const ChatMessageBindingsScope({
    super.key,
    required this.bindings,
    required super.child,
  });

  final ChatMessageBindings bindings;

  static ChatMessageBindings of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ChatMessageBindingsScope>();
    assert(scope != null, 'ChatMessageBindingsScope not found in context');
    return scope!.bindings;
  }

  @override
  bool updateShouldNotify(ChatMessageBindingsScope oldWidget) {
    return bindings.overlayRevision != oldWidget.bindings.overlayRevision ||
        bindings.unreadCount != oldWidget.bindings.unreadCount ||
        bindings.galleryStructureVersion !=
            oldWidget.bindings.galleryStructureVersion;
  }
}
