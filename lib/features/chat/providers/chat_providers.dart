// lib/features/chat/providers/chat_providers.dart
//
// Go backend chat providers
//

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/chat_repository_impl.dart';
import 'chat_messages_provider.dart';
import '../repositories/chat_repository.dart';
import '../data/datasources/chat_local_datasource_isar.dart';
import '../../../model/conversation_model.dart';

export 'chat_connection_status_provider.dart';
export 'chat_messages_provider.dart';
export 'chat_message_store_provider.dart';
export 'chat_action_controller.dart';
export '../models/send_message_params.dart';

part 'chat_providers.g.dart';

// ═══════════════════════════════════════════════════════════════════
// 📦 REPOSITORY
// ═══════════════════════════════════════════════════════════════════

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  ref.keepAlive();
  return ChatRepositoryImpl(
    localDataSource: ChatLocalDataSourceIsar(),
  );
}

// ═══════════════════════════════════════════════════════════════════
// 📄 PAGINATION STATE
// ═══════════════════════════════════════════════════════════════════

class PaginationState {
  final bool isLoadingMore;
  final bool hasMore;
  const PaginationState({this.isLoadingMore = false, this.hasMore = true});
}

@riverpod
PaginationState paginationState(PaginationStateRef ref, String conversationId) {
  final messagesState = ref.watch(chatMessagesProvider(conversationId));
  return PaginationState(
    isLoadingMore: messagesState.isLoading && messagesState.hasValue,
    hasMore: true,
  );
}

// ═══════════════════════════════════════════════════════════════════
// 📦 PARAMS
// ═══════════════════════════════════════════════════════════════════

class ChatProviderParams {
  final String conversationId;
  final String otherUserId;

  const ChatProviderParams({
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatProviderParams &&
          runtimeType == other.runtimeType &&
          conversationId == other.conversationId &&
          otherUserId == other.otherUserId;

  @override
  int get hashCode => conversationId.hashCode ^ otherUserId.hashCode;
}

// ═══════════════════════════════════════════════════════════════════
// 🔄 CONVERSATIONS STREAM
// ═══════════════════════════════════════════════════════════════════

final conversationsStreamProvider =
    StreamProvider<List<ConversationModel>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});
