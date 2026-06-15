import 'package:flutter/foundation.dart';

import '../../../model/message_model.dart';

@immutable
class ChatMessageStoreState {
  const ChatMessageStoreState({
    required this.orderedIds,
    required this.byId,
    required this.structureVersion,
    required this.contentVersion,
  });

  const ChatMessageStoreState.empty()
      : orderedIds = const [],
        byId = const {},
        structureVersion = 0,
        contentVersion = 0;

  /// Newest message first.
  final List<String> orderedIds;
  final Map<String, MessageModel> byId;
  final int structureVersion;
  final int contentVersion;

  bool get isEmpty => orderedIds.isEmpty;

  ChatMessageStoreState copyWith({
    List<String>? orderedIds,
    Map<String, MessageModel>? byId,
    int? structureVersion,
    int? contentVersion,
  }) {
    return ChatMessageStoreState(
      orderedIds: orderedIds ?? this.orderedIds,
      byId: byId ?? this.byId,
      structureVersion: structureVersion ?? this.structureVersion,
      contentVersion: contentVersion ?? this.contentVersion,
    );
  }
}
