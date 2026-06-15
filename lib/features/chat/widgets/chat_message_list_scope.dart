import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/chat_providers.dart';

/// Builds the chat message list while isolating provider watches from the
/// parent screen shell (app bar, input, background).
typedef ChatMessageListBuilder = Widget Function(
  BuildContext context,
  PaginationState paginationState,
);

/// Watches only list structure + pagination — never the full message payload.
class ChatMessageListScope extends ConsumerWidget {
  const ChatMessageListScope({
    super.key,
    required this.conversationId,
    required this.buildList,
  });

  final String conversationId;
  final ChatMessageListBuilder buildList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(
      chatMessageStoreProvider(conversationId).select(
        (store) => store.structureVersion,
      ),
    );
    final paginationState = ref.watch(
      paginationStateProvider(conversationId),
    );
    return buildList(context, paginationState);
  }
}
