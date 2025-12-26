import 'dart:async';
import '../security/logging_utility.dart';
import '../DB/advanced_cache_system.dart';
import '../utils/const.dart';

/// سرویس پاک‌سازی مموری و مدیریت کش بهینه
class MemoryCleanupService {
  static final MemoryCleanupService _instance =
      MemoryCleanupService._internal();

  factory MemoryCleanupService() => _instance;

  MemoryCleanupService._internal();

  final AdvancedCacheSystem _cacheSystem = AdvancedCacheSystem();

  Timer? _cleanupTimer;
  bool _isInitialized = false;

  // تنظیمات پاک‌سازی
  static const Duration _cleanupInterval = Duration(hours: 1);
  static const Duration _oldMessageThreshold =
      Duration(days: 7); // پیام‌های قدیمی‌تر از 7 روز
  static const int _maxMessagesPerConversation = 100; // حداکثر پیام‌های کش‌شده

  /// آغاز سرویس
  Future<void> initialize() async {
    if (_isInitialized) {
      logInfo('✅ MemoryCleanupService already initialized');
      return;
    }

    logInfo('🚀 Initializing MemoryCleanupService...');

    try {
      // شروع تایمر خودکار
      _startAutomaticCleanup();

      _isInitialized = true;
      logInfo('✅ MemoryCleanupService initialized successfully');
    } catch (e) {
      logInfo('❌ Failed to initialize MemoryCleanupService: $e');
      rethrow;
    }
  }

  /// شروع پاک‌سازی خودکار
  void _startAutomaticCleanup() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      logInfo('⏰ Running automatic memory cleanup...');
      performCleanup();
    });

    logInfo(
        '⏰ Automatic cleanup scheduled every ${_cleanupInterval.inHours} hour(s)');
  }

  /// اجرای پاک‌سازی کامل
  Future<void> performCleanup() async {
    try {
      logInfo('🧹 Starting comprehensive memory cleanup...');

      final startTime = DateTime.now();

      // 1. پاک‌سازی پیام‌های قدیمی
      await _cacheSystem.cleanupOldMessages(
        olderThan: _oldMessageThreshold,
      );

      // 2. پاک‌سازی حافظه در صورت نیاز
      await _cleanupExcessiveCache();

      // 3. پاک‌سازی حافظه ارجاعات
      await _cleanupDeadReferences();

      final duration = DateTime.now().difference(startTime);
      logInfo('✅ Memory cleanup completed in ${duration.inMilliseconds}ms');
    } catch (e) {
      logInfo('❌ Error during memory cleanup: $e');
    }
  }

  /// پاک‌سازی کش اضافی
  Future<void> _cleanupExcessiveCache() async {
    try {
      // دریافت تمام مکالمات کش‌شده
      final conversations = _cacheSystem.getCachedConversations();

      logInfo(
          '🔍 Checking ${conversations.length} conversations for excessive cache...');

      int totalMessagesCleaned = 0;

      // بررسی هر مکالمه
      for (final conversation in conversations) {
        final messages = _cacheSystem.getCachedMessages(conversation.id);

        // اگر تعداد پیام‌ها بیش از حد است، قدیمی‌ها را حذف کن
        if (messages.length > _maxMessagesPerConversation) {
          final excessCount = messages.length - _maxMessagesPerConversation;

          // حذف قدیمی‌ترین پیام‌ها
          final messagesToDelete = messages
              .sublist(_maxMessagesPerConversation)
              .map((m) => m.id)
              .toList();

          await _cacheSystem.deleteMultipleMessagesFromCache(
            conversation.id,
            messagesToDelete,
          );

          totalMessagesCleaned += excessCount;
          logInfo(
              '✅ Cleaned $excessCount excess messages from ${conversation.id}');
        }
      }

      if (totalMessagesCleaned > 0) {
        logInfo('🧹 Total excess messages cleaned: $totalMessagesCleaned');
      }
    } catch (e) {
      logInfo('⚠️ Error cleaning excessive cache: $e');
    }
  }

  /// پاک‌سازی ارجاعات مردهٰ (Dead References)
  Future<void> _cleanupDeadReferences() async {
    try {
      // بررسی اگر کاربر logout شده است
      if (supabase.auth.currentUser == null) {
        logInfo('👤 User logged out, clearing cache...');
        await _cacheSystem.clearAllMessages();
      }
    } catch (e) {
      logInfo('⚠️ Error cleaning dead references: $e');
    }
  }

  /// پاک‌سازی مکالمه خاص
  Future<void> cleanupConversation(String conversationId) async {
    try {
      logInfo('🧹 Cleaning up conversation: $conversationId');

      // حذف پیام‌های قدیمی این مکالمه
      final messages = _cacheSystem.getCachedMessages(conversationId);

      if (messages.isNotEmpty) {
        final oldMessages = messages
            .where((m) =>
                DateTime.now().difference(m.createdAt) > _oldMessageThreshold)
            .map((m) => m.id)
            .toList();

        if (oldMessages.isNotEmpty) {
          await _cacheSystem.deleteMultipleMessagesFromCache(
            conversationId,
            oldMessages,
          );
          logInfo(
              '✅ Removed ${oldMessages.length} old messages from conversation');
        }
      }
    } catch (e) {
      logInfo('⚠️ Error cleaning up conversation: $e');
    }
  }

  /// پاک‌سازی تمام کش
  Future<void> clearAllCache() async {
    try {
      logInfo('🧹 Clearing all cache...');
      await _cacheSystem.clearAllMessages();
      logInfo('✅ All cache cleared');
    } catch (e) {
      logInfo('❌ Error clearing all cache: $e');
    }
  }

  /// دریافت وضعیت مموری
  Future<Map<String, dynamic>> getMemoryStatus() async {
    try {
      final conversations = _cacheSystem.getCachedConversations();
      int totalMessages = 0;

      for (final conversation in conversations) {
        final messages = _cacheSystem.getCachedMessages(conversation.id);
        totalMessages += messages.length;
      }

      return {
        'conversationCount': conversations.length,
        'totalMessages': totalMessages,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      logInfo('⚠️ Error getting memory status: $e');
      return {};
    }
  }

  /// پاک‌سازی منابع
  void dispose() {
    _cleanupTimer?.cancel();
    _isInitialized = false;
    logInfo('🧹 MemoryCleanupService disposed');
  }
}
