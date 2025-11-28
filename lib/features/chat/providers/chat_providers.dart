// lib/features/chat/providers/chat_providers.dart
//
// Provider های جدید و ساده برای سیستم چت
// 
// این فایل:
// ✅ یه منبع واحد برای تمام Provider های چت
// ✅ Clean و قابل فهم
// ✅ بدون پیچیدگی‌های اضافی
// ✅ کاملاً Type-safe

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/conversation_model.dart';
import '../../../model/message_model.dart';
import '../repositories/chat_repository.dart';
import '../repositories/chat_repository_impl.dart';
import '../services/chat_cache_service.dart';
import '../services/typing_indicator_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 CORE PROVIDERS (پایه سیستم)
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای CacheService (Singleton)
final chatCacheServiceProvider = Provider<ChatCacheService>((ref) {
  return ChatCacheService();
});

/// Provider برای Repository (Singleton)
/// 
/// این Provider قلب سیستم چت هست
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final cache = ref.watch(chatCacheServiceProvider);
  final repository = ChatRepositoryImpl(cache: cache);

  // Cleanup وقتی Provider dispose میشه
  ref.onDispose(() {
    repository.dispose();
  });

  return repository;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📂 CONVERSATIONS PROVIDERS (لیست مکالمات)
// ═══════════════════════════════════════════════════════════════════════════

/// Stream لیست مکالمات (Real-time)
/// 
/// استفاده:
/// ```dart
/// final conversationsAsync = ref.watch(conversationsStreamProvider);
/// conversationsAsync.when(
///   data: (conversations) => ListView(...),
///   loading: () => CircularProgressIndicator(),
///   error: (e, s) => Text('خطا'),
/// );
/// ```
final conversationsStreamProvider =
    StreamProvider.autoDispose<List<ConversationModel>>((ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchConversations();
});

/// دریافت لیست مکالمات (یکبار)
final getConversationsProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  final result = await repository.getConversations();

  if (result.isSuccess && result.data != null) {
    return result.data!;
  }

  throw Exception(result.error ?? 'خطا در دریافت مکالمات');
});

// ═══════════════════════════════════════════════════════════════════════════
// 💬 MESSAGES PROVIDERS (پیام‌ها)
// ═══════════════════════════════════════════════════════════════════════════

/// Stream پیام‌های یک مکالمه (Real-time)
/// 
/// استفاده:
/// ```dart
/// final messagesAsync = ref.watch(messagesStreamProvider(conversationId));
/// ```
final messagesStreamProvider = StreamProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchMessages(conversationId);
});

/// دریافت پیام‌ها (یکبار)
final getMessagesProvider = FutureProvider.autoDispose
    .family<List<MessageModel>, String>((ref, conversationId) async {
  final repository = ref.watch(chatRepositoryProvider);
  final result = await repository.getMessages(conversationId);

  if (result.isSuccess && result.data != null) {
    return result.data!;
  }

  throw Exception(result.error ?? 'خطا در دریافت پیام‌ها');
});

// ═══════════════════════════════════════════════════════════════════════════
// 🎬 ACTIONS (عملیات چت)
// ═══════════════════════════════════════════════════════════════════════════

/// پارامترهای ارسال پیام
class SendMessageParams {
  final String conversationId;
  final String content;
  final String? attachmentUrl;
  final String? attachmentType;
  final String? attachmentFileName;
  final int? duration;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;

  const SendMessageParams({
    required this.conversationId,
    required this.content,
    this.attachmentUrl,
    this.attachmentType,
    this.attachmentFileName,
    this.duration,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
  });
}

/// Controller برای عملیات چت
/// 
/// این Notifier امکان اجرای عملیات‌های مختلف رو میده
class ChatActionsNotifier extends AutoDisposeNotifier<void> {
  @override
  void build() {}

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// ارسال پیام جدید
  Future<ChatResult<MessageModel>> sendMessage(SendMessageParams params) async {
    return await _repository.sendMessage(
      conversationId: params.conversationId,
      content: params.content,
      attachmentUrl: params.attachmentUrl,
      attachmentType: params.attachmentType,
      attachmentFileName: params.attachmentFileName,
      duration: params.duration,
      replyToMessageId: params.replyToMessageId,
      replyToContent: params.replyToContent,
      replyToSenderName: params.replyToSenderName,
    );
  }

  /// حذف پیام
  Future<ChatResult<void>> deleteMessage(String messageId) async {
    return await _repository.deleteMessage(messageId);
  }

  /// ویرایش پیام
  Future<ChatResult<void>> editMessage(
      String messageId, String newContent) async {
    return await _repository.editMessage(messageId, newContent);
  }

  /// Toggle واکنش
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  }) async {
    return await _repository.toggleReaction(
      messageId: messageId,
      conversationId: conversationId,
      emoji: emoji,
    );
  }

  /// ساخت مکالمه جدید
  Future<ChatResult<ConversationModel>> createConversation(
      String otherUserId) async {
    return await _repository.createConversation(otherUserId);
  }

  /// حذف مکالمه
  Future<ChatResult<void>> deleteConversation(String conversationId) async {
    return await _repository.deleteConversation(conversationId);
  }

  /// آرشیو مکالمه
  Future<ChatResult<void>> toggleArchive(String conversationId) async {
    return await _repository.toggleArchiveConversation(conversationId);
  }

  /// Pin مکالمه
  Future<ChatResult<void>> togglePin(String conversationId) async {
    return await _repository.togglePinConversation(conversationId);
  }

  /// Mute مکالمه
  Future<ChatResult<void>> toggleMute(String conversationId) async {
    return await _repository.toggleMuteConversation(conversationId);
  }

  /// ارسال Typing Indicator
  Future<void> sendTypingIndicator(String conversationId) async {
    await _repository.sendTypingIndicator(conversationId);
  }

  /// Refresh مکالمات
  Future<void> refreshConversations() async {
    await _repository.refreshConversations();
  }

  /// Refresh پیام‌ها
  Future<void> refreshMessages(String conversationId) async {
    await _repository.refreshMessages(conversationId);
  }
}

/// Provider برای عملیات چت
final chatActionsProvider =
    NotifierProvider.autoDispose<ChatActionsNotifier, void>(
  ChatActionsNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// ⌨️ TYPING INDICATOR
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای Supabase Client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider برای TypingIndicatorService
final typingIndicatorServiceProvider = Provider<TypingIndicatorService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final service = TypingIndicatorService(supabase);

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// پارامترهای Typing
class TypingParams {
  final String conversationId;
  final String userId;

  const TypingParams({
    required this.conversationId,
    required this.userId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypingParams &&
          conversationId == other.conversationId &&
          userId == other.userId;

  @override
  int get hashCode => conversationId.hashCode ^ userId.hashCode;
}

/// Stream وضعیت تایپ کردن طرف مقابل
/// 
/// استفاده:
/// ```dart
/// final isTyping = ref.watch(typingStatusProvider(
///   TypingParams(conversationId: id, userId: otherUserId),
/// ));
/// ```
final typingStatusProvider =
    StreamProvider.autoDispose.family<bool, TypingParams>((ref, params) {
  final service = ref.watch(typingIndicatorServiceProvider);
  return service.watchTypingStatus(
    conversationId: params.conversationId,
    otherUserId: params.userId,
  );
});

/// UseCase برای شروع و توقف تایپ
/// 
/// استفاده:
/// ```dart
/// ref.read(typingActionsProvider).startTyping(conversationId);
/// ref.read(typingActionsProvider).stopTyping(conversationId);
/// ```
final typingActionsProvider = Provider<TypingActions>((ref) {
  return TypingActions(ref.watch(typingIndicatorServiceProvider));
});

class TypingActions {
  final TypingIndicatorService _service;

  TypingActions(this._service);

  Future<void> startTyping(String conversationId) async {
    await _service.startTyping(conversationId);
  }

  Future<void> stopTyping(String conversationId) async {
    await _service.stopTyping(conversationId);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🔍 SEARCH
// ═══════════════════════════════════════════════════════════════════════════

/// پارامترهای جستجو
class SearchParams {
  final String conversationId;
  final String query;

  const SearchParams({
    required this.conversationId,
    required this.query,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchParams &&
          conversationId == other.conversationId &&
          query == other.query;

  @override
  int get hashCode => conversationId.hashCode ^ query.hashCode;
}

/// جستجو در پیام‌ها
final searchMessagesProvider = FutureProvider.autoDispose
    .family<List<MessageModel>, SearchParams>((ref, params) async {
  if (params.query.isEmpty) return [];

  final repository = ref.watch(chatRepositoryProvider);
  final result =
      await repository.searchMessages(params.conversationId, params.query);

  if (result.isSuccess && result.data != null) {
    return result.data!;
  }

  return [];
});

// ═══════════════════════════════════════════════════════════════════════════
// 📄 PAGINATION - صفحه‌بندی پیام‌ها
// ═══════════════════════════════════════════════════════════════════════════

/// State برای Pagination
class PaginationState {
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final String? error;

  const PaginationState({
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.error,
  });

  PaginationState copyWith({
    bool? isLoadingMore,
    bool? hasMoreMessages,
    String? error,
  }) {
    return PaginationState(
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      error: error,
    );
  }
}

/// Notifier برای مدیریت Pagination
/// 
/// استفاده:
/// ```dart
/// // گرفتن state
/// final paginationState = ref.watch(paginationStateProvider(conversationId));
/// 
/// // بارگذاری بیشتر
/// ref.read(paginationStateProvider(conversationId).notifier).loadMore(oldestDate);
/// ```
class PaginationNotifier extends FamilyNotifier<PaginationState, String> {
  @override
  PaginationState build(String conversationId) {
    return const PaginationState();
  }

  ChatRepository get _repository => ref.read(chatRepositoryProvider);

  /// بارگذاری پیام‌های بیشتر
  Future<void> loadMore(DateTime oldestMessageDate) async {
    // جلوگیری از درخواست همزمان
    if (state.isLoadingMore || !state.hasMoreMessages) {
      print('⏸️ [Pagination] Skipping: isLoadingMore=${state.isLoadingMore}, hasMore=${state.hasMoreMessages}');
      return;
    }

    print('📥 [Pagination] Loading more messages...');
    state = state.copyWith(isLoadingMore: true, error: null);

    try {
      final result = await _repository.loadMoreMessages(
        conversationId: arg,
        oldestMessageDate: oldestMessageDate,
        limit: 50,
      );

      if (result.isSuccess && result.data != null) {
        print('✅ [Pagination] Loaded ${result.data!.length} messages');

        // اگر کمتر از 50 پیام برگشت، یعنی دیگه پیام نداریم
        final hasMore = result.data!.length >= 50;

        state = state.copyWith(
          isLoadingMore: false,
          hasMoreMessages: hasMore,
        );
      } else {
        state = state.copyWith(
          isLoadingMore: false,
          error: result.error,
        );
      }
    } catch (e) {
      print('❌ [Pagination] Error: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Reset کردن state
  void reset() {
    state = const PaginationState();
  }
}

/// Provider برای Pagination
final paginationStateProvider =
    NotifierProvider.family<PaginationNotifier, PaginationState, String>(
  PaginationNotifier.new,
);

// ═══════════════════════════════════════════════════════════════════════════
// 📊 UTILITIES
// ═══════════════════════════════════════════════════════════════════════════

/// تعداد پیام‌های خوانده نشده (کل)
final totalUnreadCountProvider = Provider.autoDispose<int>((ref) {
  final conversationsAsync = ref.watch(conversationsStreamProvider);

  return conversationsAsync.when(
    data: (conversations) =>
        conversations.fold(0, (sum, c) => sum + c.unreadCount),
    loading: () => 0,
    error: (_, __) => 0,
  );
});

/// مکالمات فعال (غیر آرشیو شده)
final activeConversationsProvider =
    Provider.autoDispose<AsyncValue<List<ConversationModel>>>((ref) {
  final conversationsAsync = ref.watch(conversationsStreamProvider);

  return conversationsAsync.whenData(
    (conversations) => conversations.where((c) => !c.isArchived).toList(),
  );
});

/// مکالمات آرشیو شده
final archivedConversationsProvider =
    Provider.autoDispose<AsyncValue<List<ConversationModel>>>((ref) {
  final conversationsAsync = ref.watch(conversationsStreamProvider);

  return conversationsAsync.whenData(
    (conversations) => conversations.where((c) => c.isArchived).toList(),
  );
});

/// مکالمات Pin شده
final pinnedConversationsProvider =
    Provider.autoDispose<AsyncValue<List<ConversationModel>>>((ref) {
  final activeConvs = ref.watch(activeConversationsProvider);

  return activeConvs.whenData(
    (conversations) => conversations.where((c) => c.isPinned).toList(),
  );
});

/// مکالمات عادی (Pin نشده)
final unpinnedConversationsProvider =
    Provider.autoDispose<AsyncValue<List<ConversationModel>>>((ref) {
  final activeConvs = ref.watch(activeConversationsProvider);

  return activeConvs.whenData(
    (conversations) => conversations.where((c) => !c.isPinned).toList(),
  );
});

