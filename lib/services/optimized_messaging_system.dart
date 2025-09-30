import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/message_model.dart';
import '../DB/unified_message_cache_service.dart';
import '../provider/provider.dart';
import '../main.dart';
import 'realtime_connection_optimizer.dart';
import 'advanced_cache_optimizer.dart';

/// سیستم پیام‌رسانی بهینه‌شده - تک کش، تک provider
class OptimizedMessagingSystem {
  static final OptimizedMessagingSystem _instance =
      OptimizedMessagingSystem._internal();
  factory OptimizedMessagingSystem() => _instance;
  OptimizedMessagingSystem._internal();

  // تنها یک cache service
  final UnifiedMessageCacheService _cache = UnifiedMessageCacheService();
  // ChatService مستقیماً استفاده نمی‌شود - از Supabase مستقیم استفاده می‌کنیم
  final RealtimeConnectionOptimizer _connectionOptimizer =
      RealtimeConnectionOptimizer();
  final AdvancedCacheOptimizer _cacheOptimizer = AdvancedCacheOptimizer();

  // تنها یک realtime subscription manager
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, List<MessageModel>> _messagesCache = {};
  final Map<String, DateTime> _lastSyncTime = {};

  // تنها یک memory management
  static const int maxConversationsInMemory = 5;
  static const Duration cacheExpiry = Duration(minutes: 10);

  bool _isInitialized = false;

  /// مقداردهی اولیه سیستم بهینه
  Future<void> initialize() async {
    if (_isInitialized) {
      print('✅ Optimized Messaging System already initialized');
      return;
    }

    print('🚀 Initializing Optimized Messaging System...');

    try {
      // Initialize cache service first
      await _cache.initialize();

      // MessageCacheService از پیش initialize شده در main
      await _connectionOptimizer.initialize();
      await _cacheOptimizer.startOptimization();

      _isInitialized = true;
      print('✅ Optimized Messaging System initialized');
    } catch (e) {
      print('❌ Failed to initialize messaging system: $e');
      rethrow;
    }
  }

  /// دریافت پیام‌ها برای یک مکالمه (با کش هوشمند)
  Future<List<MessageModel>> getMessages(
      String conversationId, String userId) async {
    final cacheKey = '${conversationId}_$userId';

    // بررسی memory cache ابتدا
    if (_messagesCache.containsKey(cacheKey) && !_isCacheExpired(cacheKey)) {
      _cacheOptimizer.recordCacheHit(cacheKey);
      return List.from(_messagesCache[cacheKey]!);
    }

    // Record cache miss
    _cacheOptimizer.recordCacheMiss(cacheKey);

    // دریافت از persistent cache
    final messages =
        await _cache.getConversationMessages(conversationId, userId);

    // ذخیره در memory cache با مدیریت حافظه
    _updateMemoryCache(cacheKey, messages);

    return messages;
  }

  /// راه‌اندازی real-time listener برای یک مکالمه (بهینه‌شده)
  void setupRealtimeListener(
      String conversationId, void Function(List<MessageModel>) onUpdate) {
    // لغو listener قبلی اگر وجود دارد
    _activeSubscriptions[conversationId]?.cancel();

    // ایجاد stream بهینه‌شده از طریق ConnectionOptimizer
    final optimizedStream =
        _connectionOptimizer.createOptimizedStream<List<MessageModel>>(
      'messages_$conversationId',
      () {
        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception('User not authenticated');
        }

        return supabase
            .from('messages')
            .stream(primaryKey: ['id'])
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .map((data) => data
                .map((json) =>
                    MessageModel.fromJson(json, currentUserId: userId))
                .toList());
      },
      timeout: const Duration(seconds: 30),
      maxRetries: 5,
    );

    // ثبت subscription
    _activeSubscriptions[conversationId] = optimizedStream.listen(
      (messages) {
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final cacheKey = '${conversationId}_$userId';
          _updateMemoryCache(cacheKey, messages);
          onUpdate(messages);
        }
      },
      onError: (error) {
        print('❌ Realtime error for $conversationId: $error');
      },
    );
  }

  /// حذف listener برای یک مکالمه
  void removeRealtimeListener(String conversationId) {
    _activeSubscriptions[conversationId]?.cancel();
    _activeSubscriptions.remove(conversationId);

    // پاک کردن از memory cache
    _messagesCache.removeWhere((key, _) => key.startsWith(conversationId));
    _lastSyncTime.remove(conversationId);
  }

  /// کش کردن پیام جدید
  Future<void> cacheMessage(MessageModel message, String userId) async {
    await _cache.cacheMessage(message, userId);

    // به‌روزرسانی memory cache
    final cacheKey = '${message.conversationId}_$userId';
    if (_messagesCache.containsKey(cacheKey)) {
      final messages = _messagesCache[cacheKey]!;

      // حذف پیام duplicate اگر وجود دارد
      messages.removeWhere((m) => m.id == message.id);

      // اضافه کردن پیام جدید
      messages.insert(0, message);

      // مرتب‌سازی
      messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      _lastSyncTime[cacheKey] = DateTime.now();
    }
  }

  /// حذف پیام
  Future<void> removeMessage(
      String conversationId, String messageId, String userId) async {
    await _cache.clearMessage(conversationId, messageId, userId);

    // حذف از memory cache
    final cacheKey = '${conversationId}_$userId';
    if (_messagesCache.containsKey(cacheKey)) {
      _messagesCache[cacheKey]!.removeWhere((m) => m.id == messageId);
    }
  }

  /// بررسی انقضای cache
  bool _isCacheExpired(String cacheKey) {
    final lastSync = _lastSyncTime[cacheKey];
    if (lastSync == null) return true;
    return DateTime.now().difference(lastSync) > cacheExpiry;
  }

  /// به‌روزرسانی memory cache با مدیریت حافظه
  void _updateMemoryCache(String cacheKey, List<MessageModel> messages) {
    _messagesCache[cacheKey] = List.from(messages);
    _lastSyncTime[cacheKey] = DateTime.now();

    // مدیریت حافظه - حذف قدیمی‌ترین cache ها
    if (_messagesCache.length > maxConversationsInMemory) {
      final sortedKeys = _lastSyncTime.keys.toList()
        ..sort((a, b) => _lastSyncTime[a]!.compareTo(_lastSyncTime[b]!));

      final keysToRemove =
          sortedKeys.take(_messagesCache.length - maxConversationsInMemory);
      for (final key in keysToRemove) {
        _messagesCache.remove(key);
        _lastSyncTime.remove(key);
      }
    }
  }

  /// پاکسازی کامل (برای memory management)
  void dispose() {
    _cacheOptimizer.dispose();
    _connectionOptimizer.dispose();

    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _messagesCache.clear();
    _lastSyncTime.clear();
  }

  /// دریافت آمار عملکرد
  Map<String, dynamic> getPerformanceStats() {
    return {
      'active_subscriptions': _activeSubscriptions.length,
      'cached_conversations': _messagesCache.length,
      'memory_usage_kb': _estimateMemoryUsage(),
      'connection_stats': _connectionOptimizer.getConnectionStats(),
      'cache_optimization': _cacheOptimizer.getOptimizationStats(),
    };
  }

  /// تخمین استفاده از حافظه
  int _estimateMemoryUsage() {
    int totalMessages = 0;
    for (final messages in _messagesCache.values) {
      totalMessages += messages.length;
    }
    return totalMessages * 2; // تخمین 2KB per message
  }
}

/// Provider بهینه‌شده برای مدیریت پیام‌ها
class OptimizedMessagesNotifier extends StateNotifier<List<MessageModel>> {
  final String conversationId;
  final String userId;
  final OptimizedMessagingSystem _messaging = OptimizedMessagingSystem();

  OptimizedMessagesNotifier(this.conversationId, this.userId) : super([]) {
    _initialize();
  }

  @override
  void dispose() {
    _messaging.removeRealtimeListener(conversationId);
    super.dispose();
  }

  Future<void> _initialize() async {
    // Initialize messaging system first
    await _messaging.initialize();

    // دریافت پیام‌های کش شده
    final messages = await _messaging.getMessages(conversationId, userId);
    state = messages;

    // راه‌اندازی real-time listener
    _messaging.setupRealtimeListener(conversationId, (newMessages) {
      state = newMessages;
    });
  }

  /// اضافه کردن پیام جدید
  Future<void> addMessage(MessageModel message) async {
    // Ensure messaging system is initialized
    await _messaging.initialize();
    await _messaging.cacheMessage(message, userId);
    // state به‌روزرسانی می‌شه از طریق real-time listener
  }

  /// حذف پیام
  Future<void> removeMessage(String messageId) async {
    // Ensure messaging system is initialized
    await _messaging.initialize();
    await _messaging.removeMessage(conversationId, messageId, userId);
    state = state.where((m) => m.id != messageId).toList();
  }
}

/// Provider factory برای پیام‌ها
final optimizedMessagesProvider = StateNotifierProvider.family<
    OptimizedMessagesNotifier, List<MessageModel>, String>(
  (ref, conversationId) {
    final userId = ref.read(currentUserProvider).value?['id'] ?? '';
    return OptimizedMessagesNotifier(conversationId, userId);
  },
);
