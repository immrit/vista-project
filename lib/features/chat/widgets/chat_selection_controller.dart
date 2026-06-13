import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class ChatSelectionState {
  const ChatSelectionState({
    this.isSelectionMode = false,
    this.selectedMessageIds = const {},
  });

  final bool isSelectionMode;
  final Set<String> selectedMessageIds;

  const ChatSelectionState.empty() : this();

  ChatSelectionState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedMessageIds,
  }) {
    return ChatSelectionState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedMessageIds: selectedMessageIds ?? this.selectedMessageIds,
    );
  }

  bool contains(String messageId) => selectedMessageIds.contains(messageId);

  bool containsAll(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty);
    final idList = ids.toList(growable: false);
    if (idList.isEmpty) return false;
    return idList.every(selectedMessageIds.contains);
  }
}

class ChatSelectionController extends ValueNotifier<ChatSelectionState> {
  ChatSelectionController() : super(const ChatSelectionState.empty());

  void enterSelectionMode(String messageId) {
    if (messageId.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    value = value.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {...value.selectedMessageIds, messageId},
    );
  }

  void enterSelectionModeForMessages(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    HapticFeedback.mediumImpact();
    value = value.copyWith(
      isSelectionMode: true,
      selectedMessageIds: {...value.selectedMessageIds, ...ids},
    );
  }

  void exitSelectionMode() {
    value = const ChatSelectionState.empty();
  }

  void toggleMessageSelection(String messageId) {
    if (messageId.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    final selected = {...value.selectedMessageIds};
    if (selected.contains(messageId)) {
      selected.remove(messageId);
      value = selected.isEmpty
          ? const ChatSelectionState.empty()
          : value.copyWith(selectedMessageIds: selected);
      return;
    }
    selected.add(messageId);
    value = value.copyWith(
      isSelectionMode: true,
      selectedMessageIds: selected,
    );
  }

  void toggleRenderItemSelection(Iterable<String> messageIds) {
    final ids = messageIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;

    HapticFeedback.selectionClick();
    final selected = {...value.selectedMessageIds};
    final allSelected = ids.every(selected.contains);
    if (allSelected) {
      selected.removeAll(ids);
      value = selected.isEmpty
          ? const ChatSelectionState.empty()
          : value.copyWith(selectedMessageIds: selected);
      return;
    }
    selected.addAll(ids);
    value = value.copyWith(
      isSelectionMode: true,
      selectedMessageIds: selected,
    );
  }
}
