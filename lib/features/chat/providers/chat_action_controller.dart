import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:Vista/utils/const.dart';
import 'package:Vista/security/logging_utility.dart';

import 'package:Vista/features/chat/providers/chat_providers.dart';
import 'package:Vista/services/message_reaction_service.dart';

import 'package:Vista/features/chat/services/message_actions_service.dart';

part 'chat_action_controller.g.dart';

@riverpod
class ChatActionController extends _$ChatActionController {
  late final MessageReactionService _reactionService;

  @override
  AsyncValue<void> build() {
    _reactionService = MessageReactionService();
    return const AsyncValue.data(null);
  }

  Future<ActionResult<void>> sendMessage({
    required String conversationId,
    required String content,
    String? attachmentUrl,
    String? attachmentType,
    String? replyToMessageId,
  }) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      return const ActionResult.failure('User not logged in');
    }

    state = const AsyncValue.loading();

    // 1. Optimistic Update Removed (Repo handles it via Isar)

    try {
      // 2. Send to Server via Repository
      final repository = ref.read(chatRepositoryProvider);
      final result = await repository.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        replyToMessageId: replyToMessageId,
      );

      return result.fold(
        (success) {
          state = const AsyncValue.data(null);
          return const ActionResult.success();
        },
        (failure) {
          throw Exception(failure);
        },
      );
    } catch (e, stack) {
      logInfo('Send Message Failed: $e');
      state = AsyncValue.error(e, stack);
      return ActionResult.failure(e.toString());
    }
  }

  Future<void> deleteMessage(String conversationId, String messageId,
      {bool forEveryone = false}) async {
    logInfo(
        '🎮 [Controller] Delete button pressed for $messageId, forEveryone=$forEveryone');
    state = const AsyncValue.loading();

    // 1. Optimistic Update Removed (Repo handles it via Isar)

    try {
      // 2. Call Repository
      final repository = ref.read(chatRepositoryProvider);
      final result =
          await repository.deleteMessage(messageId, forEveryone: forEveryone);

      result.fold(
        (success) => state = const AsyncValue.data(null),
        (failure) {
          throw Exception(failure);
        },
      );
    } catch (e, stack) {
      logInfo('Delete Message Failed: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    try {
      await _reactionService.toggleReaction(
        messageId: messageId,
        conversationId: conversationId,
        emoji: emoji,
      );
    } catch (e) {
      logInfo('Toggle Reaction Failed: $e');
    }
  }
}
