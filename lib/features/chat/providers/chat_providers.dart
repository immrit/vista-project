import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_messages_provider.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_impl.dart';
import '../data/datasources/chat_local_datasource_isar.dart';

export 'chat_connection_status_provider.dart';
export 'chat_messages_provider.dart';
export 'chat_action_controller.dart';
export '../models/send_message_params.dart';

part 'chat_providers.g.dart';

// ═══════════════════════════════════════════════════════════════════
// 📦 REPOSITORIES
// ═══════════════════════════════════════════════════════════════════

@riverpod
ChatRepository chatRepository(ChatRepositoryRef ref) {
  final supabase = Supabase.instance.client;
  final localDataSource = ChatLocalDataSourceIsar();

  return ChatRepositoryImpl(
    localDataSource: localDataSource,
    supabase: supabase,
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
  // Detect if loading more: isLoading is true AND we have data
  final isLoadingMore = messagesState.isLoading && messagesState.hasValue;
  // hasMore logic needs to come from provider.
  // currently ChatMessages doesn't expose hasMore in public state easily unless we cast notifier.
  // or we can infer if list count % pageSize != 0 ?
  // let's default true for now or fix ChatMessages to expose state object
  return PaginationState(isLoadingMore: isLoadingMore, hasMore: true);
}

// ═══════════════════════════════════════════════════════════════════
// 📦 PARAMS
// ═══════════════════════════════════════════════════════════════════

// Class to hold parameters for the chat provider
class ChatProviderParams {
  final String conversationId;
  final String otherUserId;

  const ChatProviderParams(
      {required this.conversationId, required this.otherUserId});

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
