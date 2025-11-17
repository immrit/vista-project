import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../model/message_model.dart';
import '../DB/telegram_style_cache_system.dart';
import '../utils/deferred_initialization_manager.dart';
import '../utils/performance_logger.dart';
import '../services/ChatService.dart';
import '../main.dart';
import 'chat_provider.dart';

/// ✅ Ultra Optimized Chat State
class UltraOptimizedChatState {
  final List<MessageModel> messages;
  final bool isInitialized;
  final String? error;

  const UltraOptimizedChatState({
    this.messages = const [],
    this.isInitialized = false,
    this.error,
  });

  UltraOptimizedChatState copyWith({
    List<MessageModel>? messages,
    bool? isInitialized,
    String? error,
  }) {
    return UltraOptimizedChatState(
      messages: messages ?? this.messages,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error,
    );
  }
}

/// ✅ Ultra Optimized Chat Notifier
/// با Deferred Initialization Pattern برای باز شدن سریع کیبورد
class UltraOptimizedChatNotifier
    extends StateNotifier<UltraOptimizedChatState> {
  final String conversationId;
  final String otherUserId;
  final Ref ref;

  final _deferredManager = DeferredInitializationManager();
  late final TelegramStyleCacheSystem _cacheSystem;
  late final ChatService _chatService;

  StreamSubscription? _messageSubscription;
  bool _disposed = false;

  UltraOptimizedChatNotifier({
    required this.conversationId,
    required this.otherUserId,
    required this.ref,
  }) : super(const UltraOptimizedChatState()) {
    _cacheSystem = TelegramStyleCacheSystem();
    _chatService = ref.read(chatServiceProvider);
    // ✅ فوری: فقط hot cache
    _initializeInstant();
  }

  /// ✅ PHASE 1: فوری - فقط hot cache (زیر 5ms)
  void _initializeInstant() {
    PerformanceLogger.start('instant_init');
    
    final hotCached = _cacheSystem.getFromHotCache(conversationId);
    if (hotCached != null && hotCached.isNotEmpty) {
      print('⚡ Instant load: ${hotCached.length} messages from hot cache');
      state = UltraOptimizedChatState(
        messages: hotCached,
        isInitialized: true,
      );
      PerformanceLogger.end('instant_init');
      // بقیه کارها در background
      _scheduleBackgroundTasks();
    } else {
      // اگر hot cache خالی بود، سریع memory رو چک کن
      _loadFromMemory();
    }
  }

  /// ✅ PHASE 2: Memory cache (زیر 20ms)
  void _loadFromMemory() {
    PerformanceLogger.start('memory_init');
    
    final memoryCached = _cacheSystem.getFromMemoryCache(conversationId);
    if (memoryCached != null && memoryCached.isNotEmpty) {
      print('💾 Fast load: ${memoryCached.length} messages from memory');
      state = UltraOptimizedChatState(
        messages: memoryCached,
        isInitialized: true,
      );
      PerformanceLogger.end('memory_init');
      _scheduleBackgroundTasks();
    } else {
      // هیچ cache موجود نیست - placeholder
      state = const UltraOptimizedChatState(isInitialized: true);
      PerformanceLogger.end('memory_init');
      _scheduleBackgroundTasks();
    }
  }

  /// ✅ زمان‌بندی تمام کارهای سنگین
  void _scheduleBackgroundTasks() {
    // Task 1: بارگذاری از دیسک
    _deferredManager.defer(() => _loadFromDisk());

    // Task 2: دریافت از سرور
    _deferredManager.defer(() => _fetchFromServer());

    // Task 3: راه‌اندازی realtime
    _deferredManager.defer(() => _setupRealtime());
  }

  /// بارگذاری از دیسک - Deferred
  Future<void> _loadFromDisk() async {
    if (_disposed) return;

    PerformanceLogger.start('disk_load');
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final diskMessages = await _cacheSystem.loadFromDisk(conversationId, userId);

      if (diskMessages != null && diskMessages.isNotEmpty && !_disposed) {
        // فقط اگر بهتر از state فعلی باشد
        if (diskMessages.length > state.messages.length) {
          state = state.copyWith(messages: diskMessages);
          print('📀 Updated from disk: ${diskMessages.length} messages');
        }
      }
      PerformanceLogger.end('disk_load');
    } catch (e) {
      print('⚠️ Disk load error: $e');
      PerformanceLogger.end('disk_load');
    }
  }

  /// دریافت از سرور - Deferred
  Future<void> _fetchFromServer() async {
    if (_disposed) return;

    PerformanceLogger.start('server_fetch');
    try {
      final serverMessages = await _chatService.getMessages(
        conversationId,
        limit: 50,
      );

      if (!_disposed && serverMessages.isNotEmpty) {
        final merged = _mergeMessages(
          existing: state.messages,
          incoming: serverMessages,
        );

        state = state.copyWith(messages: merged);
        print('🌐 Updated from server: ${merged.length} messages');

        // Cache کردن
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await _cacheSystem.cacheMessages(conversationId, merged, userId);
        }
      }
      PerformanceLogger.end('server_fetch');
    } catch (e) {
      print('⚠️ Server fetch error: $e');
      PerformanceLogger.end('server_fetch');
    }
  }

  /// راه‌اندازی realtime - Deferred
  Future<void> _setupRealtime() async {
    if (_disposed || _messageSubscription != null) return;

    PerformanceLogger.start('realtime_setup');
    try {
      _messageSubscription = supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(100)
          .listen((data) {
            if (_disposed) return;

            final userId = supabase.auth.currentUser?.id;
            if (userId == null) return;

            final newMessages = data
                .map((json) => MessageModel.fromJson(json, currentUserId: userId))
                .toList();

            final merged = _mergeMessages(
              existing: state.messages,
              incoming: newMessages,
            );

            state = state.copyWith(messages: merged);

            // Update hot cache
            _cacheSystem.cacheMessages(conversationId, merged, userId);
          });

      print('📡 Realtime setup complete');
      PerformanceLogger.end('realtime_setup');
    } catch (e) {
      print('⚠️ Realtime setup error: $e');
      PerformanceLogger.end('realtime_setup');
    }
  }

  /// Merge منطقی پیام‌ها
  List<MessageModel> _mergeMessages({
    required List<MessageModel> existing,
    required List<MessageModel> incoming,
  }) {
    final messageMap = <String, MessageModel>{};

    for (final msg in existing) {
      messageMap[msg.id] = msg;
    }

    for (final msg in incoming) {
      final existingMsg = messageMap[msg.id];
      if (existingMsg == null ||
          msg.createdAt.isAfter(existingMsg.createdAt) ||
          !_areReactionsEqual(msg.reactions, existingMsg.reactions)) {
        messageMap[msg.id] = msg;
      }
    }

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

  /// ارسال پیام - Optimistic
  Future<void> sendMessage({
    required String content,
    String? attachmentUrl,
    String? attachmentType,
  }) async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    PerformanceLogger.start('send_message');

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // ✅ Optimistic update
    final tempMessage = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: currentUser.id,
      content: content,
      createdAt: DateTime.now(),
      isRead: false,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      reactions: {},
      isMe: true,
      isPending: true,
      localId: tempId,
    );

    state = state.copyWith(
      messages: [tempMessage, ...state.messages],
    );

    try {
      // ارسال به سرور
      final serverMessage = await _chatService.sendMessage(
        conversationId: conversationId,
        content: content,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        localId: tempId,
      );

      // جایگزینی temp با واقعی
      final updatedMessages = state.messages
          .where((m) => m.id != tempId)
          .toList();
      updatedMessages.insert(0, serverMessage);

      state = state.copyWith(messages: updatedMessages);

      // Update cache
      await _cacheSystem.cacheMessages(conversationId, updatedMessages, currentUser.id);
      PerformanceLogger.end('send_message');
    } catch (e) {
      print('❌ Send error: $e');
      PerformanceLogger.end('send_message');

      // علامت‌گذاری به عنوان failed
      final failedMessages = state.messages.map((m) {
        if (m.id == tempId) {
          return m.copyWith(isFailed: true, errorMessage: e.toString());
        }
        return m;
      }).toList();

      state = state.copyWith(messages: failedMessages);
    }
  }

  /// Load more messages (pagination)
  Future<void> loadMoreMessages() async {
    if (state.messages.isEmpty || _disposed) return;

    PerformanceLogger.start('load_more');
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
          await _cacheSystem.cacheMessages(conversationId, updated, userId);
        }
      }
      PerformanceLogger.end('load_more');
    } catch (e) {
      print('❌ Load more error: $e');
      PerformanceLogger.end('load_more');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _messageSubscription?.cancel();
    super.dispose();
  }
}

/// ✅ Provider
final ultraOptimizedChatProvider = StateNotifierProvider.family
    .autoDispose<UltraOptimizedChatNotifier, UltraOptimizedChatState, Map<String, String>>(
  (ref, params) {
    return UltraOptimizedChatNotifier(
      conversationId: params['conversationId']!,
      otherUserId: params['otherUserId']!,
      ref: ref,
    );
  },
);






