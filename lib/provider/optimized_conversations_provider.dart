import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/logging_utility.dart';
import '../model/conversation_model.dart';
import '../services/telegram_read_receipt_service.dart';

import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import '../features/chat/providers/chat_providers.dart';
import '../features/chat/services/sse_manager.dart';
import '../services/user_profile_service.dart';

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
  String? _userId;
  final UserProfileService _profileService = UserProfileService();

  StreamSubscription<List<ConversationModel>>? _repoSubscription;
  StreamSubscription<SseConnectionState>? _sseStatusSubscription;
  Timer? _fallbackPollingTimer;
  bool _disposed = false;
  bool _isRefreshInFlight = false;
  int _lastRefreshStartedAtMs = 0;
  int _latestUpdateToken = 0;
  bool _hasReceivedSseStatusEvent = false;
  String _lastConversationsFingerprint = '';
  final Set<String> _profilePreloadInFlight = <String>{};
  static const Duration _fallbackRefreshInterval = Duration(seconds: 2);
  static const Duration _minRefreshGap = Duration(milliseconds: 1200);

  OptimizedConversationsNotifier(this._ref, this._userId)
      : super(const ConversationsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_disposed) return;

    _userId ??= await TokenStorage.getUserId();

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
      result.fold((conversations) {
        _updateConversations(conversations);
        state = state.copyWith(status: ConversationsStatus.loaded);
      }, (error) => logInfo('⚠️ Initial load warning: $error'));

      // 2. Watch for SSE updates
      _subscribeToUpdates();
      _subscribeToSseStatus();

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

    _repoSubscription = repo.watchConversations().listen(
      (conversations) {
        if (_disposed) return;
        _updateConversations(conversations);
      },
      onError: (e) {
        logInfo('⚠️ Conversation stream error: $e');
      },
    );
  }

  Future<void> _updateConversations(
    List<ConversationModel> conversations,
  ) async {
    if (_disposed) return;
    final updateToken = ++_latestUpdateToken;

    // Fast-path: show latest local conversation changes immediately.
    final sorted = _sortConversations(conversations);
    final sortedFingerprint = _fingerprintConversations(sorted);
    if (sortedFingerprint != _lastConversationsFingerprint ||
        state.status != ConversationsStatus.loaded) {
      _lastConversationsFingerprint = sortedFingerprint;
      state = state.copyWith(
        conversations: sorted,
        status: ConversationsStatus.loaded,
      );
    }

    // Enrich with profiles in background.
    final enriched = await _enrichConversations(
      conversations,
      updateToken: updateToken,
    );
    if (_disposed || updateToken != _latestUpdateToken) return;
    final enrichedSorted = _sortConversations(enriched);
    final enrichedFingerprint = _fingerprintConversations(enrichedSorted);
    if (enrichedFingerprint != _lastConversationsFingerprint ||
        state.status != ConversationsStatus.loaded) {
      _lastConversationsFingerprint = enrichedFingerprint;
      state = state.copyWith(
        conversations: enrichedSorted,
        status: ConversationsStatus.loaded,
      );
    }
  }

  Future<void> _refreshFromServer() async {
    if (_disposed || _isRefreshInFlight) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRefreshStartedAtMs < _minRefreshGap.inMilliseconds) {
      return;
    }
    _lastRefreshStartedAtMs = nowMs;
    _isRefreshInFlight = true;
    try {
      final repo = _ref.read(chatRepositoryProvider);
      await repo.refreshConversations();
    } catch (e) {
      logInfo('⚠️ Refresh error: $e');
    } finally {
      _isRefreshInFlight = false;
    }
  }

  void _subscribeToSseStatus() {
    _sseStatusSubscription?.cancel();
    final repo = _ref.read(chatRepositoryProvider);
    _hasReceivedSseStatusEvent = false;

    _sseStatusSubscription = repo.realtimeStatus.listen(
      (status) {
        if (_disposed) return;
        _hasReceivedSseStatusEvent = true;
        if (status == SseConnectionState.connected) {
          _stopFallbackPolling();
          return;
        }

        _startFallbackPolling();
        unawaited(_refreshFromServer());
      },
      onError: (Object error, StackTrace stackTrace) {
        logInfo('⚠️ SSE status stream error: $error');
        _startFallbackPolling();
      },
    );

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_disposed || _hasReceivedSseStatusEvent) return;
      _startFallbackPolling();
      unawaited(_refreshFromServer());
    });
  }

  void _startFallbackPolling() {
    if (_disposed) return;
    if (_fallbackPollingTimer?.isActive ?? false) return;

    _fallbackPollingTimer = Timer.periodic(_fallbackRefreshInterval, (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      unawaited(_refreshFromServer());
    });
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
  }

  /// Enrich مکالمات با اطلاعات پروفایل
  Future<List<ConversationModel>> _enrichConversations(
    List<ConversationModel> conversations, {
    required int updateToken,
  }) async {
    if (conversations.isEmpty) return [];

    final enriched = <ConversationModel>[];
    final userIdsToLoad = <String>[];

    // اول از memory cache استفاده کن (خیلی سریع)
    for (final conversation in conversations) {
      if (_needsEnrichment(conversation) && conversation.otherUserId != null) {
        final cached = _profileService.getCachedProfile(
          conversation.otherUserId!,
        );
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
      _loadMissingProfiles(
        userIdsToLoad,
        conversations,
        updateToken: updateToken,
      );
    }

    return enriched;
  }

  /// بارگذاری پروفایل‌های missing در background
  Future<void> _loadMissingProfiles(
    List<String> userIds,
    List<ConversationModel> conversations, {
    required int updateToken,
  }) async {
    if (_disposed) return;

    final limitedIds = userIds
        .where((id) => !_profilePreloadInFlight.contains(id))
        .take(10)
        .toList(growable: false);
    if (limitedIds.isEmpty) return;

    try {
      // حداکثر 10 پروفایل همزمان
      _profilePreloadInFlight.addAll(limitedIds);
      await _profileService.preloadProfiles(limitedIds);

      if (_disposed || updateToken != _latestUpdateToken) return;

      // Re-enrich conversations با پروفایل‌های جدید
      final reEnriched = conversations.map((conversation) {
        if (_needsEnrichment(conversation) &&
            conversation.otherUserId != null) {
          final cached = _profileService.getCachedProfile(
            conversation.otherUserId!,
          );
          if (cached != null) {
            return _applyProfile(conversation, cached);
          }
        }
        return conversation;
      }).toList();

      if (!_disposed && updateToken == _latestUpdateToken) {
        final sorted = _sortConversations(reEnriched);
        final fingerprint = _fingerprintConversations(sorted);
        if (fingerprint != _lastConversationsFingerprint) {
          _lastConversationsFingerprint = fingerprint;
          state = state.copyWith(conversations: sorted);
        }
      }
    } catch (e) {
      logInfo('⚠️ Error loading missing profiles: $e');
    } finally {
      _profilePreloadInFlight.removeAll(limitedIds);
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
    ConversationModel conversation,
    Map<String, String?> profile,
  ) {
    return conversation.copyWith(
      otherUserName:
          profile['username'] ?? profile['full_name'] ?? 'VISTA USER',
      otherUserAvatar: profile['avatar_url'],
    );
  }

  /// مرتب‌سازی مکالمات: pinned اول، بعد بر اساس آخرین پیام
  List<ConversationModel> _sortConversations(
    List<ConversationModel> conversations,
  ) {
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

  String _fingerprintConversations(List<ConversationModel> conversations) {
    if (conversations.isEmpty) return 'empty';
    final buffer = StringBuffer();
    for (final c in conversations) {
      buffer
        ..write(c.id)
        ..write('|')
        ..write(c.updatedAt.millisecondsSinceEpoch)
        ..write('|')
        ..write(c.lastMessageTime?.millisecondsSinceEpoch ?? 0)
        ..write('|')
        ..write(c.lastMessage ?? '')
        ..write('|')
        ..write(c.unreadCount)
        ..write('|')
        ..write(c.hasUnreadMessages ? '1' : '0')
        ..write('|')
        ..write(c.lastMessageDeliveryStatus.name)
        ..write(';');
    }
    return buffer.toString();
  }

  // ============================================
  // Public Methods
  // ============================================

  /// Refresh دستی
  Future<void> refresh() async {
    if (_disposed) return;
    state = state.copyWith(isRefreshing: true);
    try {
      await _refreshFromServer();
    } finally {
      if (!_disposed) {
        state = state.copyWith(isRefreshing: false);
      }
    }
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

    final index = state.conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    final targetStatus = _parseDeliveryStatus(status);
    final current = state.conversations[index];
    if (current.lastMessageDeliveryStatus == targetStatus) return;

    final updated = current.copyWith(lastMessageDeliveryStatus: targetStatus);
    final next = List<ConversationModel>.from(state.conversations);
    next[index] = updated;

    final sorted = _sortConversations(next);
    final fingerprint = _fingerprintConversations(sorted);
    if (fingerprint == _lastConversationsFingerprint) return;
    _lastConversationsFingerprint = fingerprint;
    state = state.copyWith(conversations: sorted);
  }

  MessageDeliveryStatus _parseDeliveryStatus(String status) {
    switch (status) {
      case 'read':
      case 'seen':
        return MessageDeliveryStatus.read;
      case 'delivered':
        return MessageDeliveryStatus.delivered;
      case 'sent':
        return MessageDeliveryStatus.sent;
      case 'pending':
        return MessageDeliveryStatus.pending;
      case 'failed':
        return MessageDeliveryStatus.failed;
      default:
        return MessageDeliveryStatus.sent;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _repoSubscription?.cancel();
    _sseStatusSubscription?.cancel();
    _stopFallbackPolling();
    super.dispose();
  }
}

// ============================================
// 3️⃣ Provider اصلی
// ============================================

final optimizedConversationsProvider =
    StateNotifierProvider<OptimizedConversationsNotifier, ConversationsState>((
  ref,
) {
  return OptimizedConversationsNotifier(ref, null);
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
