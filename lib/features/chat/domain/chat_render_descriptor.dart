import 'package:flutter/foundation.dart';

/// Stable identity for one row in the chat list (single message or album).
@immutable
class ChatRenderDescriptor {
  const ChatRenderDescriptor({
    required this.key,
    required this.primaryIndex,
    required this.messageIds,
    required this.isAlbum,
  });

  final String key;
  final int primaryIndex;
  final List<String> messageIds;
  final bool isAlbum;

  String get primaryMessageId => messageIds.first;
}

/// Layout metadata for a row that only changes when list structure/neighbors change.
@immutable
class ChatMessageRowLayout {
  const ChatMessageRowLayout({
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.showDateDivider,
    required this.showUnreadDivider,
  });

  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool showDateDivider;
  final bool showUnreadDivider;
}

/// Slice of selection state relevant to one row.
@immutable
class ChatRowSelectionSlice {
  const ChatRowSelectionSlice({
    required this.isSelectionMode,
    required this.selectedIds,
    required this.isRowSelected,
    required this.isPartiallySelected,
  });

  final bool isSelectionMode;
  final Set<String> selectedIds;
  final bool isRowSelected;
  final bool isPartiallySelected;

  factory ChatRowSelectionSlice.from(
    List<String> messageIds,
    ChatSelectionStateLike selection,
  ) {
    final selected = selection.selectedMessageIds;
    final hits = messageIds.where(selected.contains).length;
    return ChatRowSelectionSlice(
      isSelectionMode: selection.isSelectionMode,
      selectedIds: selected,
      isRowSelected: hits > 0 && hits == messageIds.length,
      isPartiallySelected: hits > 0 && hits < messageIds.length,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatRowSelectionSlice &&
        other.isSelectionMode == isSelectionMode &&
        other.isRowSelected == isRowSelected &&
        other.isPartiallySelected == isPartiallySelected;
  }

  @override
  int get hashCode => Object.hash(
        isSelectionMode,
        isRowSelected,
        isPartiallySelected,
      );
}

/// Minimal interface so selection can come from Riverpod or legacy controller.
abstract class ChatSelectionStateLike {
  bool get isSelectionMode;
  Set<String> get selectedMessageIds;
}
