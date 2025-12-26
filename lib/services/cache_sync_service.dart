import '../security/logging_utility.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../utils/const.dart';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import '../DB/unified_message_cache_service.dart';
import '../DB/unified_conversation_cache_service.dart';
import 'ChatService_LEGACY.dart';

/// سیستم همگام‌سازی کش - روان و هوشمند
class CacheSyncService {
  static final CacheSyncService _instance = CacheSyncService._internal();
  factory CacheSyncService() => _instance;
  CacheSyncService._internal();

  final UnifiedMessageCacheService _messageCache = UnifiedMessageCacheService();
  final UnifiedConversationCacheService _conversationCache =
      UnifiedConversationCacheService();
  final ChatService _chatService = ChatService();

  // Network monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = false;
  bool _isInitialized = false;

  // Retry management
  int _retryCount = 0;
  static const int _maxRetries = 5; // برای قابلیت اطمینان بهتر

  // Sync state
  final Map<String, DateTime> _lastMessageSync = {};
  final Map<String, Timer> _pendingSyncs = {};
  final Set<String> _syncInProgress = {};

  // Performance optimization
  static const Duration _syncDebounce = Duration(milliseconds: 500);
  static const Duration _backgroundSyncInterval = Duration(minutes: 2);
  Timer? _backgroundSyncTimer;

  // Real-time subscriptions
  final Map<String, StreamSubscription> _realtimeSubscriptions = {};

  /// مقداردهی اولیه سیستم sync
  Future<void> initialize() async {
    if (_isInitialized) return;

    // راه‌اندازی network monitoring
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // بررسی وضعیت اولیه اتصال
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = connectivity != ConnectivityResult.none;

    if (_isOnline) {
      _startBackgroundSync();
    }

    _isInitialized = true;
    logDebug('✅ Cache sync initialized');
  }

  /// مدیریت تغییرات network
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (!wasOnline && _isOnline) {
      // آنلاین شدن - sync فوری
      logDebug('📡 Device came online - starting immediate sync');
      _performFullSync();
      _startBackgroundSync();
    } else if (wasOnline && !_isOnline) {
      // آفلاین شدن - توقف background sync
      logDebug('📡 Device went offline - stopping background sync');
      _stopBackgroundSync();
    }
  }

  /// شروع background sync مثل تلگرام
  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (_) {
      if (_isOnline) {
        _performIncrementalSync();
      }
    });
  }

  /// توقف background sync
  void _stopBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = null;
  }

  /// sync کامل (هنگام آنلاین شدن)
  Future<void> _performFullSync() async {
    try {
      logDebug('🔄 Starting full cache sync...');

      // sync مکالمات
      await _syncConversations();

      // sync پیام‌های فعال
      await _syncActiveConversations();

      logDebug('✅ Full cache sync completed');
    } catch (e) {
      logDebug('❌ Full cache sync failed: $e');
    }
  }

  /// sync تدریجی (در background)
  Future<void> _performIncrementalSync() async {
    if (!_isOnline) return;

    try {
      // فقط مکالمات فعال را sync کن
      final activeConversations = await _getActiveConversations();

      for (final conversation in activeConversations.take(5)) {
        // محدود به 5 مکالمه
        await _syncConversationIfNeeded(conversation.id);
      }
    } catch (e) {
      logDebug('❌ Incremental sync failed: $e');
    }
  }

  /// sync مکالمات از سرور
  Future<void> _syncConversations() async {
    try {
      final serverConversations = await _chatService.getConversations();
      final userId = supabase.auth.currentUser!.id;

      for (final conversation in serverConversations) {
        await _conversationCache.updateConversation(conversation, userId);
      }

      logDebug('📋 Synced ${serverConversations.length} conversations');
    } catch (e) {
      logDebug('❌ Conversation sync failed: $e');
    }
  }

  /// دریافت مکالمات فعال (که اخیراً استفاده شده‌اند)
  Future<List<ConversationModel>> _getActiveConversations() async {
    final userId = supabase.auth.currentUser!.id;
    final allConversations =
        await _conversationCache.getCachedConversations(userId);

    // مرتب‌سازی بر اساس آخرین فعالیت
    allConversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // فقط مکالماتی که در 24 ساعت گذشته فعال بوده‌اند
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return allConversations
        .where((conv) => conv.updatedAt.isAfter(cutoff))
        .toList();
  }

  /// sync مکالمات فعال
  Future<void> _syncActiveConversations() async {
    final activeConversations = await _getActiveConversations();

    for (final conversation in activeConversations.take(10)) {
      // محدود به 10 مکالمه
      await _syncConversationMessages(conversation.id);
    }
  }

  /// sync پیام‌های یک مکالمه در صورت نیاز
  Future<void> _syncConversationIfNeeded(String conversationId) async {
    final lastSync = _lastMessageSync[conversationId];
    final now = DateTime.now();

    // اگر کمتر از 30 ثانیه پیش sync شده، skip کن
    if (lastSync != null && now.difference(lastSync).inSeconds < 30) {
      return;
    }

    await _syncConversationMessages(conversationId);
  }

  /// sync پیام‌های یک مکالمه با debounce
  Future<void> _syncConversationMessages(String conversationId) async {
    // جلوگیری از sync همزمان
    if (_syncInProgress.contains(conversationId)) return;

    // لغو sync قبلی (debounce)
    _pendingSyncs[conversationId]?.cancel();

    _pendingSyncs[conversationId] = Timer(_syncDebounce, () async {
      _syncInProgress.add(conversationId);

      try {
        await _performMessageSync(conversationId);
        _lastMessageSync[conversationId] = DateTime.now();
      } finally {
        _syncInProgress.remove(conversationId);
        _pendingSyncs.remove(conversationId);
      }
    });
  }

  /// sync واقعی پیام‌ها
  Future<void> _performMessageSync(String conversationId) async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // دریافت آخرین پیام از کش
      final cachedMessages =
          await _messageCache.getConversationMessages(conversationId, userId);
      final lastCachedTime = cachedMessages.isNotEmpty
          ? cachedMessages.first.createdAt
          : DateTime.now().subtract(const Duration(days: 1));

      // دریافت پیام‌های جدید از سرور
      final newMessages =
          await _chatService.getMessagesAfter(conversationId, lastCachedTime);

      if (newMessages.isNotEmpty) {
        // کش پیام‌های جدید
        await _messageCache.cacheMessages(newMessages, userId);

        debugPrint(
            '📥 Synced ${newMessages.length} new messages for conversation $conversationId');
      }
    } catch (e) {
      logDebug('❌ Message sync failed for conversation $conversationId: $e');
    }
  }

  /// subscribe به real-time updates یک مکالمه
  Future<void> subscribeToConversation(String conversationId) async {
    // لغو subscription قبلی در صورت وجود
    await unsubscribeFromConversation(conversationId);

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final subscription = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 30))
        .listen(
          (data) async {
            await _handleRealtimeUpdate(conversationId, data, userId);
          },
          onError: (error) {
            // مدیریت خطاهای real-time بدون کرش
            if (error.toString().contains('RealtimeSubscribeException')) {
              logDebug('⚠️ Realtime conversation stream error: $error');
              // تلاش مجدد با محدودیت
              if (_retryCount < _maxRetries) {
                _retryCount++;
                Future.delayed(const Duration(seconds: 10), () {
                  // از 15 به 10 ثانیه برای پاسخ سریع‌تر
                  subscribeToConversation(conversationId);
                });
              } else {
                logDebug('Max retries reached for conversation subscription');
              }
            } else {
              logDebug('⚠️ Real-time subscription error: $error');
            }
          },
          onDone: () {
            debugPrint(
                '⚠️ Real-time conversation stream closed, attempting to reconnect...');
            // تلاش مجدد با محدودیت
            if (_retryCount < _maxRetries) {
              _retryCount++;
              Future.delayed(const Duration(seconds: 10), () {
                // از 15 به 10 ثانیه برای پاسخ سریع‌تر
                subscribeToConversation(conversationId);
              });
            } else {
              logDebug('Max retries reached for conversation subscription');
            }
          },
        );

    _realtimeSubscriptions[conversationId] = subscription;
    debugPrint(
        '📡 Subscribed to real-time updates for conversation $conversationId');
  }

  /// unsubscribe از real-time updates
  Future<void> unsubscribeFromConversation(String conversationId) async {
    final subscription = _realtimeSubscriptions.remove(conversationId);
    await subscription?.cancel();

    if (subscription != null) {
      logDebug('📡 Unsubscribed from conversation $conversationId');
    }
  }

  /// مدیریت real-time updates
  Future<void> _handleRealtimeUpdate(String conversationId,
      List<Map<String, dynamic>> data, String userId) async {
    try {
      final messages = data
          .map((json) => MessageModel.fromJson(json, currentUserId: userId))
          .toList();

      // فیلتر پیام‌های جدید
      final cachedMessages =
          await _messageCache.getConversationMessages(conversationId, userId);
      final cachedIds = cachedMessages.map((m) => m.id).toSet();

      final newMessages =
          messages.where((m) => !cachedIds.contains(m.id)).toList();

      if (newMessages.isNotEmpty) {
        // کش پیام‌های جدید
        await _messageCache.cacheMessages(newMessages, userId);

        // بروزرسانی مکالمه با جدیدترین پیام بر اساس created_at
        if (newMessages.isNotEmpty) {
          final latestMessage = newMessages
              .reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
          await _updateConversationFromMessage(
              conversationId, latestMessage, userId);
        }

        debugPrint(
            '📨 Received ${newMessages.length} real-time messages for conversation $conversationId');
      }
    } catch (e) {
      logDebug('❌ Real-time update handling failed: $e');
    }
  }

  /// بروزرسانی مکالمه بر اساس آخرین پیام
  Future<void> _updateConversationFromMessage(
      String conversationId, MessageModel message, String userId) async {
    try {
      final conversation =
          await _conversationCache.getConversation(conversationId, userId);
      if (conversation != null) {
        final updatedConversation = conversation.copyWith(
          lastMessage: message.content,
          lastMessageTime: message.createdAt,
          updatedAt: message.createdAt,
        );

        await _conversationCache.updateConversation(
            updatedConversation, userId);
      }
    } catch (e) {
      logDebug('❌ Conversation update failed: $e');
    }
  }

  /// sync فوری یک مکالمه (هنگام ورود به چت)
  Future<void> syncConversationNow(String conversationId) async {
    if (!_isOnline) return;

    // لغو timer در انتظار
    _pendingSyncs[conversationId]?.cancel();
    _pendingSyncs.remove(conversationId);

    await _performMessageSync(conversationId);
    await subscribeToConversation(conversationId);
  }

  /// پاکسازی منابع
  Future<void> dispose() async {
    _stopBackgroundSync();
    await _connectivitySubscription?.cancel();

    // لغو همه subscriptions
    for (final subscription in _realtimeSubscriptions.values) {
      await subscription.cancel();
    }
    _realtimeSubscriptions.clear();

    // لغو pending syncs
    for (final timer in _pendingSyncs.values) {
      timer.cancel();
    }
    _pendingSyncs.clear();

    _isInitialized = false;
    logDebug('🔄 Cache sync disposed');
  }

  /// آمار عملکرد
  Map<String, dynamic> getPerformanceStats() {
    return {
      'isOnline': _isOnline,
      'activeSyncs': _syncInProgress.length,
      'pendingSyncs': _pendingSyncs.length,
      'realtimeSubscriptions': _realtimeSubscriptions.length,
      'lastSyncTimes': _lastMessageSync,
    };
  }
}
