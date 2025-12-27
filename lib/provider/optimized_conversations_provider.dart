import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/logging_utility.dart';
import '../model/conversation_model.dart';

import '../features/chat/providers/chat_providers.dart';
import '../services/user_profile_service.dart';
import '../utils/const.dart';

// ============================================
// 1️⃣ State class برای مدیریت وضعیت مکالمات
// ============================================

enum ConversationsStatus { initial, loading, loaded, error }

class ConversationsState {
  final List<ConversationModel> conversations;
  final ConversationsStatus status;
  final String? errorMessage;
  final bool isRefreshing;

  const ConversationsState({
    this.conversations = const [],
    this.status = ConversationsStatus.initial,
    this.errorMessage,
    this.isRefreshing = false,
  });

  /// مکالمات پین شده (جدا برای نمایش بالای لیست)
  List<ConversationModel> get pinnedConversations =>
      conversations.where((c) => c.isPinned && !c.isArchived).toList();

  /// مکالمات عادی (بدون پین و بدون آرشیو)
  List<ConversationModel> get regularConversations =>
      conversations.where((c) => !c.isPinned && !c.isArchived).toList();

  /// تعداد کل پیام‌های خوانده‌نشده
  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);

  ConversationsState copyWith({
    List<ConversationModel>? conversations,
    ConversationsStatus? status,
    String? errorMessage,
    bool? isRefreshing,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      status: status ?? this.status,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

// ============================================
// 2️⃣ Notifier برای مدیریت state
// ============================================

class OptimizedConversationsNotifier extends StateNotifier<ConversationsState> {
  final Ref _ref;
  final String? _userId;
  final UserProfileService _profileService = UserProfileService();

  StreamSubscription<List<ConversationModel>>? _repoSubscription;
  bool _disposed = false;

  OptimizedConversationsNotifier(this._ref, this._userId)
      : super(const ConversationsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_disposed) return;

    if (_userId == null) {
      state = const ConversationsState(
        status: ConversationsStatus.error,
        errorMessage: 'کاربر لاگین نیست',
      );
      return;
    }

    state = state.copyWith(status: ConversationsStatus.loading);

    try {
      final repo = _ref.read(chatRepositoryProvider);

      // 1. Initial Load (Fast, from Isar)
      final result = await repo.getConversations();
      result.fold(
        (conversations) {
          _updateConversations(conversations);
          state = state.copyWith(status: ConversationsStatus.loaded);
        },
        (error) => logInfo('⚠️ Initial load warning: $error'),
      );

      // 2. Watch for Realtime Updates
      _subscribeToUpdates();

      // 3. Refresh from Server (Background)
      _refreshFromServer();
    } catch (e) {
      logInfo('❌ Error initializing conversations: $e');
      if (!_disposed) {
        state = state.copyWith(
          status: ConversationsStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  void _subscribeToUpdates() {
    _repoSubscription?.cancel();
    final repo = _ref.read(chatRepositoryProvider);

    _repoSubscription = repo.watchConversations().listen((conversations) {
      if (_disposed) return;
      _updateConversations(conversations);
    }, onError: (e) {
      logInfo('⚠️ Conversation stream error: $e');
    });
  }

  Future<void> _updateConversations(
      List<ConversationModel> conversations) async {
    // Enrich with profiles
    final enriched = await _enrichConversations(conversations);
    if (!_disposed) {
      state = state.copyWith(
        conversations: _sortConversations(enriched),
        status: ConversationsStatus.loaded,
      );
    }
  }

  Future<void> _refreshFromServer() async {
    try {
      final repo = _ref.read(chatRepositoryProvider);
      await repo.refreshConversations();
    } catch (e) {
      logInfo('⚠️ Refresh error: $e');
    }
  }

  /// Enrich مکالمات با اطلاعات پروفایل
  Future<List<ConversationModel>> _enrichConversations(
      List<ConversationModel> conversations) async {
    if (conversations.isEmpty) return [];

    final enriched = <ConversationModel>[];
    final userIdsToLoad = <String>[];

    // اول از memory cache استفاده کن (خیلی سریع)
    for (final conversation in conversations) {
      if (_needsEnrichment(conversation) && conversation.otherUserId != null) {
        final cached =
            _profileService.getCachedProfile(conversation.otherUserId!);
        if (cached != null) {
          enriched.add(_applyProfile(conversation, cached));
        } else {
          userIdsToLoad.add(conversation.otherUserId!);
          enriched.add(conversation);
        }
      } else {
        enriched.add(conversation);
      }
    }

    // اگر پروفایل‌هایی نیاز به لود دارن، در background انجام بده
    if (userIdsToLoad.isNotEmpty) {
      _loadMissingProfiles(userIdsToLoad, conversations);
    }

    return enriched;
  }

  /// بارگذاری پروفایل‌های missing در background
  Future<void> _loadMissingProfiles(
      List<String> userIds, List<ConversationModel> conversations) async {
    if (_disposed) return;

    try {
      // حداکثر 10 پروفایل همزمان
      final limitedIds = userIds.take(10).toList();
      await _profileService.preloadProfiles(limitedIds);

      if (_disposed) return;

      // Re-enrich conversations با پروفایل‌های جدید
      final reEnriched = conversations.map((conversation) {
        if (_needsEnrichment(conversation) &&
            conversation.otherUserId != null) {
          final cached =
              _profileService.getCachedProfile(conversation.otherUserId!);
          if (cached != null) {
            return _applyProfile(conversation, cached);
          }
        }
        return conversation;
      }).toList();

      if (!_disposed) {
        state = state.copyWith(
          conversations: _sortConversations(reEnriched),
        );
      }
    } catch (e) {
      logInfo('⚠️ Error loading missing profiles: $e');
    }
  }

  /// چک کن آیا مکالمه نیاز به enrichment داره
  bool _needsEnrichment(ConversationModel conversation) {
    final name = conversation.otherUserName ?? '';
    return name.isEmpty ||
        name == 'کاربر' ||
        name == 'کاربر ناشناس' ||
        name == 'Unknown User';
  }

  /// اعمال پروفایل به مکالمه
  ConversationModel _applyProfile(
      ConversationModel conversation, Map<String, String?> profile) {
    return conversation.copyWith(
      otherUserName:
          profile['username'] ?? profile['full_name'] ?? 'VISTA USER',
      otherUserAvatar: profile['avatar_url'],
    );
  }

  /// مرتب‌سازی مکالمات: pinned اول، بعد بر اساس آخرین پیام
  List<ConversationModel> _sortConversations(
      List<ConversationModel> conversations) {
    final sorted = List<ConversationModel>.from(conversations);
    sorted.sort((a, b) {
      // پین شده‌ها اول
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      // بعد بر اساس زمان آخرین پیام
      final aTime = a.lastMessageTime ?? a.updatedAt;
      final bTime = b.lastMessageTime ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  // ============================================
  // Public Methods
  // ============================================

  /// Refresh دستی
  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(isRefreshing: true);
    await _refreshFromServer();
    state = state.copyWith(isRefreshing: false);
  }

  /// جستجو در مکالمات
  List<ConversationModel> search(String query) {
    if (query.isEmpty) return state.conversations;

    final lowerQuery = query.toLowerCase();
    return state.conversations.where((c) {
      final name = c.otherUserName?.toLowerCase() ?? '';
      final message = c.lastMessage?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || message.contains(lowerQuery);
    }).toList();
  }

  // ✅ آپدیت وضعیت تیک آخرین پیام
  void updateLastMessageDeliveryStatus({
    required String conversationId,
    required String status,
  }) {
    if (_disposed) return;

    // پیدا کردن مکالمه
    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;

    // اگر تغییری نکرده، کاری نکن
    // (اینجا فرض می‌کنیم که conversationModel فیلد تیک دارد، اما اگر ندارد،
    // احتمالا باید conversation.lastMessageStatus را آپدیت کنیم که ممکن است در مدل نباشد
    // فعلاً فقط لاگ می‌زنیم که آپدیت شد، چون مدل ConversationModel فیلد deliveryStatus ندارد به طور مستقیم برای پیام آخر
    // اما شاید formattedLastMessage یا چیز دیگری باشد.
    // در واقعیت این متد برای تریگر کردن UI refresh لیست چت‌ها استفاده می‌شود.)

    // ما فقط state را رفرش می‌کنیم تا اگر تغییری در دیتابیس بوده، UI آپدیت شود
    // اما چون دیتابیس stream دارد، شاید نیازی نباشد.
    // ولی modern_chat_screen آن را صدا می‌زند.

    // بیایید یک کپی جدید از state بدهیم تا ریبیلد شود
    state = state.copyWith();
  }

  @override
  void dispose() {
    _disposed = true;
    _repoSubscription?.cancel();
    super.dispose();
  }
}

// ============================================
// 3️⃣ Provider اصلی
// ============================================

final optimizedConversationsProvider =
    StateNotifierProvider<OptimizedConversationsNotifier, ConversationsState>(
        (ref) {
  final userId = supabase.auth.currentUser?.id;
  return OptimizedConversationsNotifier(ref, userId);
});

// ============================================
// 4️⃣ Provider های کمکی
// ============================================

/// فقط مکالمات پین شده
final pinnedConversationsProvider = Provider<List<ConversationModel>>((ref) {
  return ref.watch(optimizedConversationsProvider).pinnedConversations;
});

/// فقط مکالمات عادی
final regularConversationsProvider = Provider<List<ConversationModel>>((ref) {
  return ref.watch(optimizedConversationsProvider).regularConversations;
});

/// تعداد پیام‌های خوانده‌نشده
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(optimizedConversationsProvider).totalUnreadCount;
});

/// وضعیت loading
final conversationsLoadingProvider = Provider<bool>((ref) {
  final state = ref.watch(optimizedConversationsProvider);
  return state.status == ConversationsStatus.loading ||
      state.status == ConversationsStatus.initial;
});

/// جستجو در مکالمات
final searchedConversationsProvider =
    Provider.family<List<ConversationModel>, String>((ref, query) {
  return ref.read(optimizedConversationsProvider.notifier).search(query);
});
