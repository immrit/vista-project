import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../model/message_model.dart';
import '../DB/telegram_style_cache_system.dart';
import '../utils/message_object_pool.dart';
import '../services/ChatService.dart';
import '../main.dart';
import 'chat_provider.dart';

/// ✅ Load Phase Enum
enum LoadPhase {
  placeholder, // فاز 0: نمایش placeholder
  hotCache, // فاز 1: Hot cache
  memoryCache, // فاز 2: Memory cache
  diskCache, // فاز 3: Disk cache
  serverFetch, // فاز 4: Server fetch
  complete, // فاز 5: تکمیل
}

/// ✅ Chat Screen State
class ChatScreenState {
  final List<MessageModel> messages;
  final bool isInitializing;
  final bool isLoadingFromDisk;
  final bool isLoadingFromServer;
  final String? error;
  final LoadPhase currentPhase;

  const ChatScreenState({
    this.messages = const [],
    this.isInitializing = true,
    this.isLoadingFromDisk = false,
    this.isLoadingFromServer = false,
    this.error,
    this.currentPhase = LoadPhase.placeholder,
  });

  ChatScreenState copyWith({
    List<MessageModel>? messages,
    bool? isInitializing,
    bool? isLoadingFromDisk,
    bool? isLoadingFromServer,
    String? error,
    LoadPhase? currentPhase,
  }) {
    return ChatScreenState(
      messages: messages ?? this.messages,
      isInitializing: isInitializing ?? this.isInitializing,
      isLoadingFromDisk: isLoadingFromDisk ?? this.isLoadingFromDisk,
      isLoadingFromServer: isLoadingFromServer ?? this.isLoadingFromServer,
      error: error,
      currentPhase: currentPhase ?? this.currentPhase,
    );
  }
}

/// ✅ Telegram-style Chat Screen Notifier
class TelegramStyleChatScreenNotifier extends StateNotifier<ChatScreenState> {
  final String conversationId;
  final String otherUserId;
  final Ref ref;

  late final TelegramStyleCacheSystem _cacheSystem;
  late final ChatService _chatService;

  StreamSubscription? _messageSubscription;
  Timer? _updateThrottleTimer;
  List<MessageModel> _pendingUpdates = [];

  bool _disposed = false;

  TelegramStyleChatScreenNotifier({
    required this.conversationId,
    required this.otherUserId,
    required this.ref,
  }) : super(const ChatScreenState()) {
    _cacheSystem = TelegramStyleCacheSystem();
    _chatService = ref.read(chatServiceProvider);

    // ✅ شروع بارگذاری فازبندی شده
    _initializeWithPhases();
  }

  /// ✅ بارگذاری چند مرحله‌ای - الهام‌گرفته از تلگرام
  Future<void> _initializeWithPhases() async {
    try {
      print('🚀 Starting Telegram-style initialization...');

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        state = state.copyWith(
          error: 'User not authenticated',
          isInitializing: false,
        );
        return;
      }

      // ═══════════════════════════════════════════════════════
      // PHASE 0: PLACEHOLDER (Instant - 0ms)
      // ═══════════════════════════════════════════════════════
      state = state.copyWith(
        isInitializing: true,
        currentPhase: LoadPhase.placeholder,
      );
      print('📱 PHASE 0: Showing placeholder...');

      // ═══════════════════════════════════════════════════════
      // PHASE 1: HOT CACHE (Synchronous - <1ms)
      // ═══════════════════════════════════════════════════════
      await Future.microtask(() {
        final hotCached = _cacheSystem.getFromHotCache(conversationId);
        if (hotCached != null && hotCached.isNotEmpty) {
          print('⚡ PHASE 1: Hot cache HIT - ${hotCached.length} messages');
          state = state.copyWith(
            messages: hotCached,
            currentPhase: LoadPhase.hotCache,
            isInitializing: false,
          );

          // جلوگیری از ادامه بارگذاری اگر داده fresh باشد
          _scheduleBackgroundRefresh();
          return;
        }
        print('⚠️ PHASE 1: Hot cache MISS');
      });

      // ═══════════════════════════════════════════════════════
      // PHASE 2: MEMORY CACHE (Synchronous - <5ms)
      // ═══════════════════════════════════════════════════════
      if (state.messages.isEmpty) {
        await Future.microtask(() {
          final memoryCached = _cacheSystem.getFromMemoryCache(conversationId);
          if (memoryCached != null && memoryCached.isNotEmpty) {
            print(
                '💾 PHASE 2: Memory cache HIT - ${memoryCached.length} messages');
            state = state.copyWith(
              messages: memoryCached,
              currentPhase: LoadPhase.memoryCache,
              isInitializing: false,
            );

            _scheduleBackgroundRefresh();
            return;
          }
          print('⚠️ PHASE 2: Memory cache MISS');
        });
      }

      // ═══════════════════════════════════════════════════════
      // PHASE 3: DISK CACHE (Async - Background)
      // ═══════════════════════════════════════════════════════
      if (state.messages.isEmpty) {
        state = state.copyWith(
          isLoadingFromDisk: true,
          currentPhase: LoadPhase.diskCache,
        );

        print('📀 PHASE 3: Loading from disk...');

        // بارگذاری از دیسک در background
        _loadFromDiskInBackground(userId);
      }

      // ═══════════════════════════════════════════════════════
      // PHASE 4: SERVER FETCH (Lowest Priority)
      // ═══════════════════════════════════════════════════════
      // این فاز همیشه اجرا می‌شود ولی با تأخیر
      _scheduleServerFetch(userId);

      // ═══════════════════════════════════════════════════════
      // REALTIME SUBSCRIPTION
      // ═══════════════════════════════════════════════════════
      _subscribeToMessages(userId);

    } catch (e, stack) {
      print('❌ Initialization error: $e');
      print('Stack: $stack');
      state = state.copyWith(
        error: e.toString(),
        isInitializing: false,
      );
    }
  }

  /// ✅ بارگذاری از دیسک در background thread
  void _loadFromDiskInBackground(String userId) async {
    try {
      final diskMessages =
          await _cacheSystem.loadFromDisk(conversationId, userId);

      if (diskMessages != null &&
          diskMessages.isNotEmpty &&
          !_disposed) {
        print(
            '✅ PHASE 3: Disk load complete - ${diskMessages.length} messages');

        // فقط اگر هنوز پیامی نداریم
        if (state.messages.isEmpty) {
          state = state.copyWith(
            messages: diskMessages,
            isLoadingFromDisk: false,
            isInitializing: false,
          );
        }

        // Update memory cache
        await _cacheSystem.cacheMessages(conversationId, diskMessages, userId);
      } else {
        print('⚠️ PHASE 3: Disk load - no data');
        state = state.copyWith(isLoadingFromDisk: false);
      }
    } catch (e) {
      print('❌ Disk load error: $e');
      state = state.copyWith(isLoadingFromDisk: false);
    }
  }

  /// ✅ Schedule کردن server fetch با تأخیر
  void _scheduleServerFetch(String userId) {
    // تأخیر 500ms برای اینکه UI فرصت render شدن داشته باشد
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_disposed) {
        _fetchFromServer(userId);
      }
    });
  }

  /// ✅ Schedule کردن background refresh
  void _scheduleBackgroundRefresh() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    Future.delayed(const Duration(seconds: 2), () {
      if (!_disposed) {
        _fetchFromServer(userId, silent: true);
      }
    });
  }

  /// ✅ دریافت از سرور
  Future<void> _fetchFromServer(String userId, {bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(
        isLoadingFromServer: true,
        currentPhase: LoadPhase.serverFetch,
      );
    }

    try {
      print('🌐 PHASE 4: Fetching from server...');

      final serverMessages = await _chatService.getMessages(
        conversationId,
        limit: 50,
      );

      if (!_disposed && serverMessages.isNotEmpty) {
        print('✅ Server fetch complete - ${serverMessages.length} messages');

        // ✅ Merge با پیام‌های موجود
        final mergedMessages = _mergeMessages(
          existing: state.messages,
          incoming: serverMessages,
        );

        state = state.copyWith(
          messages: mergedMessages,
          isLoadingFromServer: false,
          currentPhase: LoadPhase.complete,
        );

        // ✅ Cache کردن با priority بالا
        await _cacheSystem.cacheMessages(
          conversationId,
          mergedMessages,
          userId,
          highPriority: true,
        );
      }
    } catch (e) {
      print('❌ Server fetch error: $e');
      if (!silent) {
        state = state.copyWith(
          isLoadingFromServer: false,
          error: e.toString(),
        );
      }
    }
  }

  /// ✅ Subscribe به real-time updates
  void _subscribeToMessages(String userId) {
    _messageSubscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(100)
        .listen((data) {
      if (_disposed) return;

      final newMessages = data
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      // ✅ استفاده از throttle برای جلوگیری از update های مکرر
      _throttledUpdateMessages(newMessages);
    });
  }

  /// ✅ Throttled update - جلوگیری از "choppy" keyboard
  void _throttledUpdateMessages(List<MessageModel> newMessages) {
    _pendingUpdates = newMessages;

    // اگر timer فعال است، فقط update را ذخیره کن
    if (_updateThrottleTimer?.isActive ?? false) {
      return;
    }

    // اجرای فوری اولین update
    _applyPendingUpdates();

    // تنظیم timer برای update های بعدی
    _updateThrottleTimer = Timer(const Duration(milliseconds: 150), () {
      if (_pendingUpdates.isNotEmpty && !_disposed) {
        _applyPendingUpdates();
      }
    });
  }

  void _applyPendingUpdates() {
    if (_pendingUpdates.isEmpty) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final merged = _mergeMessages(
      existing: state.messages,
      incoming: _pendingUpdates,
    );

    state = state.copyWith(messages: merged);

    // ✅ Update hot cache
    _cacheSystem.cacheMessages(conversationId, merged, userId);

    _pendingUpdates = [];
  }

  /// ✅ Merge کردن هوشمند پیام‌ها
  List<MessageModel> _mergeMessages({
    required List<MessageModel> existing,
    required List<MessageModel> incoming,
  }) {
    final messageMap = <String, MessageModel>{};

    // Add existing
    for (final msg in existing) {
      messageMap[msg.id] = msg;
    }

    // Update/add incoming
    for (final msg in incoming) {
      final existingMsg = messageMap[msg.id];

      // اگر پیام جدیدتر است یا reaction جدیدی دارد
      if (existingMsg == null ||
          msg.createdAt.isAfter(existingMsg.createdAt) ||
          !_areReactionsEqual(msg.reactions, existingMsg.reactions)) {
        messageMap[msg.id] = msg;
      }
    }

    // Sort by date
    final sorted = messageMap.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted;
  }

  bool _areReactionsEqual(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;

    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;

      final listA = List<String>.from(a[key]!)..sort();
      final listB = List<String>.from(b[key]!)..sort();

      if (listA.length != listB.length) return false;
      for (int i = 0; i < listA.length; i++) {
        if (listA[i] != listB[i]) return false;
      }
    }

    return true;
  }

  /// ✅ Load more (pagination)
  Future<void> loadMoreMessages() async {
    if (state.messages.isEmpty) return;

    try {
      final olderMessages = await _chatService.getMessages(
        conversationId,
        limit: 30,
        offset: state.messages.length,
      );

      if (!_disposed && olderMessages.isNotEmpty) {
        final updated = [...state.messages, ...olderMessages];
        state = state.copyWith(messages: updated);

        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          // Update cache
          await _cacheSystem.cacheMessages(conversationId, updated, userId);
        }
      }
    } catch (e) {
      print('❌ Load more error: $e');
    }
  }

  /// ✅ Send message
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ ایجاد temp message با Object Pool
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = MessageObjectPool().obtain(
      id: tempId,
      conversationId: conversationId,
      content: content,
      senderId: userId,
      createdAt: DateTime.now(),
      isMe: true,
    );

    // ✅ فوراً به UI اضافه کن (Optimistic Update)
    final updated = [tempMessage, ...state.messages];
    state = state.copyWith(messages: updated);

    try {
      // ✅ ارسال به سرور
      final serverMessage = await _chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
      );

      // ✅ جایگزینی temp با واقعی
      final finalMessages = state.messages
          .where((m) => m.id != tempId)
          .toList();
      finalMessages.insert(0, serverMessage);

      state = state.copyWith(messages: finalMessages);

      // ✅ بازگرداندن temp به pool
      MessageObjectPool().recycle(tempMessage);

      // Update cache
      await _cacheSystem.cacheMessages(conversationId, finalMessages, userId);
    } catch (e) {
      print('❌ Send message error: $e');

      // Mark temp message as failed
      final failedMessage = tempMessage.copyWith(
        isFailed: true,
        errorMessage: e.toString(),
      );

      final updatedMessages = state.messages
          .map((m) => m.id == tempId ? failedMessage : m)
          .toList();

      state = state.copyWith(messages: updatedMessages);
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing TelegramStyleChatScreenNotifier...');
    _disposed = true;
    _messageSubscription?.cancel();
    _updateThrottleTimer?.cancel();

    // Recycle messages
    MessageObjectPool().recycleAll(state.messages);

    super.dispose();
  }
}

/// ✅ Provider
final telegramStyleChatScreenProvider = StateNotifierProvider.family
    .autoDispose<TelegramStyleChatScreenNotifier, ChatScreenState,
        Map<String, String>>(
  (ref, params) {
    final conversationId = params['conversationId']!;
    final otherUserId = params['otherUserId']!;

    return TelegramStyleChatScreenNotifier(
      conversationId: conversationId,
      otherUserId: otherUserId,
      ref: ref,
    );
  },
);

