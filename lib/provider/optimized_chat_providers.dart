import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../services/optimized_messaging_system.dart';
import '../services/memory_leak_detector.dart';
import '../main.dart';

/// Provider بهینه‌شده برای مدیریت پیام‌ها (جایگزین 6 provider قبلی)
class OptimizedChatNotifier extends StateNotifier<OptimizedChatState> {
  final String conversationId;
  final OptimizedMessagingSystem _messaging = OptimizedMessagingSystem();
  final MemoryLeakDetector _memoryTracker = MemoryLeakDetector();

  StreamSubscription? _subscription;
  bool _isInitialized = false;
  String? _userId;

  OptimizedChatNotifier(this.conversationId)
      : super(const OptimizedChatState()) {
    // Memory tracking
    _memoryTracker.trackObjectCreation('OptimizedChatNotifier', conversationId);
    _initialize();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    MemoryLeakDetector().untrackMemory('OptimizedChatNotifier_$conversationId');
    _messaging.removeRealtimeListener(conversationId);
    _memoryTracker.trackObjectDisposal('OptimizedChatNotifier', conversationId);
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      _userId = supabase.auth.currentUser?.id;
      if (_userId == null) {
        state =
            state.copyWith(isLoading: false, error: 'کاربر احراز هویت نشده');
        return;
      }

      // دریافت پیام‌های کش شده
      final messages = await _messaging.getMessages(conversationId, _userId!);
      state = state.copyWith(messages: messages, isLoading: false);

      // راه‌اندازی real-time listener
      _setupRealtimeListener();

      _isInitialized = true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _setupRealtimeListener() {
    _messaging.setupRealtimeListener(conversationId, (messages) {
      if (!mounted) return;
      state = state.copyWith(messages: messages);
    });
  }

  /// اضافه کردن پیام جدید
  Future<void> addMessage(MessageModel message) async {
    if (_userId == null) return;

    try {
      await _messaging.cacheMessage(message, _userId!);
      // state از طریق real-time listener به‌روزرسانی می‌شود
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// حذف پیام
  Future<void> removeMessage(String messageId) async {
    if (_userId == null) return;

    try {
      await _messaging.removeMessage(conversationId, messageId, _userId!);
      // حذف فوری از state
      final updatedMessages =
          state.messages.where((m) => m.id != messageId).toList();
      state = state.copyWith(messages: updatedMessages);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// بارگذاری پیام‌های بیشتر
  Future<void> loadMoreMessages() async {
    if (state.isLoadingMore || _userId == null) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      // در اینجا می‌توان پیام‌های قدیمی‌تر را از سرور دریافت کرد
      state = state.copyWith(isLoadingMore: false);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// پاک کردن خطا
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// State مدل برای OptimizedChatNotifier
class OptimizedChatState {
  final List<MessageModel> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const OptimizedChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  OptimizedChatState copyWith({
    List<MessageModel>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return OptimizedChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

/// Provider factory برای chat های بهینه‌شده
final optimizedChatProvider = StateNotifierProvider.family
    .autoDispose<OptimizedChatNotifier, OptimizedChatState, String>(
  (ref, conversationId) {
    final notifier = OptimizedChatNotifier(conversationId);

    // Memory tracking
    ref.onDispose(() {
      MemoryLeakDetector()
          .trackObjectDisposal('OptimizedChatProvider', conversationId);
    });

    return notifier;
  },
);

/// Provider برای online status (بهینه‌شده)
final optimizedOnlineStatusProvider =
    StreamProvider.family.autoDispose<bool, String>(
  (ref, userId) {
    final subscription = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) {
          if (data.isEmpty) return false;
          final profile = data.first;
          final lastOnline = DateTime.tryParse(profile['last_online'] ?? '');
          if (lastOnline == null) return false;

          final difference = DateTime.now().difference(lastOnline);
          return difference.inMinutes <
              5; // آنلاین اگر کمتر از 5 دقیقه پیش فعال بوده
        });

    // Memory tracking
    MemoryLeakDetector().trackMemory('OnlineStatus_$userId');
    ref.onDispose(() {
      MemoryLeakDetector().untrackMemory('OnlineStatus_$userId');
    });

    return subscription;
  },
);

/// Provider برای آمار عملکرد
final performanceStatsProvider =
    Provider.autoDispose<Map<String, dynamic>>((ref) {
  final messaging = OptimizedMessagingSystem();
  final memoryDetector = MemoryLeakDetector();

  return {
    ...messaging.getPerformanceStats(),
    ...memoryDetector.getCurrentStats(),
    'timestamp': DateTime.now().toIso8601String(),
  };
});

/// Provider برای تشخیص memory leaks
final memoryLeakProvider = Provider<MemoryLeakDetector>((ref) {
  final detector = MemoryLeakDetector();

  // شروع monitoring در production
  detector.startMonitoring();

  ref.onDispose(() {
    detector.dispose();
  });

  return detector;
});
