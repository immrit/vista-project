import '../../../model/message_model.dart';
import '../domain/chat_message_store_state.dart';
import '../domain/chat_message_visual_equality.dart';

abstract final class ChatMessageDiff {
  static ChatMessageStoreState apply(
    ChatMessageStoreState current,
    List<MessageModel> incoming,
  ) {
    if (incoming.isEmpty) {
      if (current.isEmpty) return current;
      return const ChatMessageStoreState.empty();
    }

    final incomingIds = List<String>.generate(
      incoming.length,
      (index) => incoming[index].id,
      growable: false,
    );

    final structureChanged = !_orderedIdsEqual(current.orderedIds, incomingIds);

    final nextById = <String, MessageModel>{};
    var contentChanged = false;

    for (final message in incoming) {
      final existing = current.byId[message.id];

      // identical() fast path: entity cache reuses the same instance when content
      // is unchanged — skip all 30+ field comparisons.
      if (identical(existing, message)) {
        nextById[message.id] = existing!;
        continue;
      }

      if (existing != null &&
          ChatMessageVisualEquality.equals(existing, message)) {
        nextById[message.id] = existing;
        continue;
      }

      if (existing != null &&
          ChatMessageVisualEquality.isDeliveryOnlyChange(existing, message)) {
        ChatMessageVisualEquality.patchDeliveryStatus(existing, message);
        nextById[message.id] = existing;
        continue;
      }

      nextById[message.id] = message;
      contentChanged = true;
    }

    for (final removedId in current.byId.keys) {
      if (!nextById.containsKey(removedId)) {
        contentChanged = true;
      }
    }

    if (!structureChanged && !contentChanged) {
      return current;
    }

    return ChatMessageStoreState(
      orderedIds: incomingIds,
      byId: nextById,
      structureVersion: structureChanged
          ? current.structureVersion + 1
          : current.structureVersion,
      contentVersion:
          contentChanged ? current.contentVersion + 1 : current.contentVersion,
    );
  }

  static bool _orderedIdsEqual(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
