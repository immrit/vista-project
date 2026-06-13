import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/message_model.dart';
import '../performance/adaptive_effects_provider.dart';
import '../performance/chat_performance_profile.dart';
import '../providers/chat_providers.dart';
import 'chat_selection_controller.dart';

/// Builds the chat message list while isolating provider watches from the
/// parent screen shell (app bar, input, background).
typedef ChatMessageListBuilder = Widget Function(
  BuildContext context,
  AsyncValue<List<MessageModel>> messagesAsync,
  PaginationState paginationState,
  AdaptiveEffectsState adaptiveEffects,
  ChatSelectionState selection,
);

/// Watches message/pagination providers and only the adaptive-effect fields
/// that affect list rendering — not scroll velocity or frame budget noise.
class ChatMessageListScope extends ConsumerWidget {
  const ChatMessageListScope({
    super.key,
    required this.conversationId,
    required this.selectionListenable,
    required this.buildList,
  });

  final String conversationId;
  final ChatSelectionController selectionListenable;
  final ChatMessageListBuilder buildList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final messagesAsync = ref.watch(chatMessagesProvider(conversationId));
    final paginationState = ref.watch(
      paginationStateProvider(conversationId),
    );
    final adaptiveEffects = ref.read(adaptiveEffectsProvider);

    return ValueListenableBuilder<ChatSelectionState>(
      valueListenable: selectionListenable,
      builder: (context, selection, _) {
        return buildList(
          context,
          messagesAsync,
          paginationState,
          adaptiveEffects,
          selection,
        );
      },
    );
  }
}
