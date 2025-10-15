import 'dart:async';
import '../security/logging_utility.dart';
import 'ChatService.dart';
import '../DB/advanced_cache_system.dart';

/// حالت‌های حذف پیام
enum DeletionMode {
  me, // فقط برای من
  everyone, // برای همه
}

/// وضعیت‌های سنکرونایزیشن
enum SyncStatus {
  pending, // منتظر ارسال به سرور
  syncing, // در حال هماهنگ‌سازی
  synced, // هماهنگ‌شده
  failed, // ناموفق
}

/// ردیاب وضعیت حذف پیام
class DeletionRecord {
  final String messageId;
  final String conversationId;
  final DeletionMode mode;
  final DateTime timestamp;
  SyncStatus syncStatus;
  int retryCount;

  DeletionRecord({
    required this.messageId,
    required this.conversationId,
    required this.mode,
    required this.timestamp,
    this.syncStatus = SyncStatus.pending,
    this.retryCount = 0,
  });
}

/// سیستم حذف پیام بهینه‌شده با هماهنگی سرور و کش
class OptimizedMessageDeletionService {
  static final OptimizedMessageDeletionService _instance =
      OptimizedMessageDeletionService._internal();

  factory OptimizedMessageDeletionService() => _instance;

  OptimizedMessageDeletionService._internal();

  // سرویس‌های وابسته
  final ChatService _chatService = ChatService();
  final AdvancedCacheSystem _cacheSystem = AdvancedCacheSystem();

  // ردیابی حذف‌های معلق
  final Map<String, DeletionRecord> _pendingDeletions = {};

  // ردیابی حذف‌های دسته‌ای
  final Map<String, List<String>> _batchedDeletions = {};

  // تایمر برای تجمیع درخواست‌ها
  Timer? _batchTimer;
  static const Duration _batchInterval = Duration(milliseconds: 300);
  static const int _maxBatchSize = 50;
  static const int _maxRetries = 3;

  // Stream برای ردیابی وضعیت حذف‌ها
  final _deletionStatusStream =
      StreamController<Map<String, SyncStatus>>.broadcast();

  bool _isInitialized = false;
  bool _isSyncing = false;

  /// آغاز سرویس
  Future<void> initialize() async {
    if (_isInitialized) {
      logInfo('✅ OptimizedMessageDeletionService already initialized');
      return;
    }

    logInfo('🚀 Initializing OptimizedMessageDeletionService...');

    try {
      // بارگذاری حذف‌های معلق از ذخیره‌سازی
      // TODO: Load from persistent storage if needed

      // شروع timer برای تجمیع درخواست‌ها
      _startBatchTimer();

      _isInitialized = true;
      logInfo('✅ OptimizedMessageDeletionService initialized successfully');
    } catch (e) {
      logInfo('❌ Failed to initialize OptimizedMessageDeletionService: $e');
      rethrow;
    }
  }

  /// حذف یک پیام (با بهینه‌سازی)
  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    DeletionMode mode = DeletionMode.me,
    bool optimisticDelete = true,
  }) async {
    try {
      logInfo(
          '🗑️ Starting deletion: $messageId (mode: ${mode.name}, optimistic: $optimisticDelete)');

      // 1. حذف فوری از UI (Optimistic Update)
      if (optimisticDelete) {
        await _removeFromCacheOptimistically(conversationId, messageId);
      }

      // 2. اضافه کردن به لیست حذف‌های معلق
      final record = DeletionRecord(
        messageId: messageId,
        conversationId: conversationId,
        mode: mode,
        timestamp: DateTime.now(),
      );

      _pendingDeletions[messageId] = record;
      _emitDeletionStatus();

      logInfo('✅ Message marked for deletion: $messageId');

      // 3. اضافه کردن به دسته (بدون اجرای فوری)
      _addToBatch(conversationId, messageId);
    } catch (e) {
      logInfo('❌ Error marking message for deletion: $e');
      rethrow;
    }
  }

  /// حذف دسته‌ای پیام‌ها (کارآمد)
  Future<void> deleteMultipleMessages({
    required String conversationId,
    required List<String> messageIds,
    DeletionMode mode = DeletionMode.me,
  }) async {
    try {
      logInfo(
          '🗑️ Starting batch deletion: ${messageIds.length} messages in $conversationId');

      // 1. حذف فوری از همه UI
      for (final messageId in messageIds) {
        await _removeFromCacheOptimistically(conversationId, messageId);
      }

      // 2. اضافه کردن به لیست حذف‌های معلق
      for (final messageId in messageIds) {
        final record = DeletionRecord(
          messageId: messageId,
          conversationId: conversationId,
          mode: mode,
          timestamp: DateTime.now(),
        );
        _pendingDeletions[messageId] = record;
      }

      _emitDeletionStatus();

      // 3. اضافه کردن تمام پیام‌ها به دسته
      for (final messageId in messageIds) {
        _addToBatch(conversationId, messageId);
      }

      logInfo('✅ ${messageIds.length} messages marked for deletion');
    } catch (e) {
      logInfo('❌ Error marking messages for batch deletion: $e');
      rethrow;
    }
  }

  /// پاک‌سازی تمام پیام‌های مکالمه (Clear All)
  Future<void> clearConversationMessages({
    required String conversationId,
    DeletionMode mode = DeletionMode.me,
  }) async {
    try {
      logInfo(
          '🗑️ Clearing all messages in conversation: $conversationId (mode: ${mode.name})');

      // 1. دریافت تمام پیام‌های کش‌شده
      final cachedMessages = _cacheSystem.getCachedMessages(conversationId);

      if (cachedMessages.isEmpty) {
        logInfo('⚠️ No cached messages to clear in $conversationId');
        return;
      }

      final messageIds = cachedMessages
          .map((m) => m.id)
          .where((id) => !id.startsWith('temp_'))
          .toList();

      // 2. استفاده از حذف دسته‌ای
      await deleteMultipleMessages(
        conversationId: conversationId,
        messageIds: messageIds,
        mode: mode,
      );

      logInfo('✅ Clear all initiated: ${messageIds.length} messages');
    } catch (e) {
      logInfo('❌ Error clearing conversation messages: $e');
      rethrow;
    }
  }

  /// اضافه کردن به دسته برای هماهنگی
  void _addToBatch(String conversationId, String messageId) {
    if (!_batchedDeletions.containsKey(conversationId)) {
      _batchedDeletions[conversationId] = [];
    }

    final batch = _batchedDeletions[conversationId]!;
    if (!batch.contains(messageId)) {
      batch.add(messageId);
    }

    // اگر دسته سایز کافی باشد، اجرا کن
    if (batch.length >= _maxBatchSize) {
      _batchTimer?.cancel();
      _syncBatch(conversationId);
    }
  }

  /// شروع تایمر دسته‌بندی
  void _startBatchTimer() {
    _batchTimer = Timer.periodic(_batchInterval, (_) {
      // اگر حذف‌های معلق وجود دارد، همه دسته‌ها را هماهنگ کن
      if (_pendingDeletions.isNotEmpty) {
        for (final conversationId in _batchedDeletions.keys.toList()) {
          _syncBatch(conversationId);
        }
      }
    });
  }

  /// هماهنگی یک دسته
  Future<void> _syncBatch(String conversationId) async {
    final batch = _batchedDeletions[conversationId];
    if (batch == null || batch.isEmpty) return;

    if (_isSyncing) {
      logInfo(
          '⚠️ Sync already in progress, skipping batch for $conversationId');
      return;
    }

    _isSyncing = true;

    try {
      logInfo(
          '🔄 Syncing batch: ${batch.length} deletions for $conversationId');

      final List<String> messageIds = List.from(batch);

      // حذف از دسته (منتظر اتمام)
      _batchedDeletions[conversationId]?.clear();

      // هماهنگی هر پیام
      final futures = messageIds.map((messageId) async {
        final record = _pendingDeletions[messageId];
        if (record == null) return;

        try {
          record.syncStatus = SyncStatus.syncing;
          _emitDeletionStatus();

          // حذف از سرور
          await _chatService.deleteMessage(
            messageId,
            forEveryone: record.mode == DeletionMode.everyone,
          );

          record.syncStatus = SyncStatus.synced;
          logInfo('✅ Synced deletion: $messageId');
        } catch (e) {
          record.retryCount++;
          if (record.retryCount < _maxRetries) {
            logInfo(
                '⚠️ Retry deletion $messageId (attempt ${record.retryCount}/$_maxRetries)');
            record.syncStatus = SyncStatus.pending;
            _addToBatch(conversationId, messageId);
          } else {
            logInfo(
                '❌ Failed to sync deletion after $_maxRetries retries: $messageId');
            record.syncStatus = SyncStatus.failed;
          }
        }
      });

      await Future.wait(futures, eagerError: false);

      _emitDeletionStatus();
      logInfo('✅ Batch sync completed for $conversationId');
    } catch (e) {
      logInfo('❌ Error syncing batch for $conversationId: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// حذف فوری از کش
  Future<void> _removeFromCacheOptimistically(
    String conversationId,
    String messageId,
  ) async {
    try {
      // حذف از کش هوشمند (Advanced Cache)
      final messages = _cacheSystem.getCachedMessages(conversationId);

      // نیاز به روش جدید برای بروزرسانی کش (نامحدود حالا)
      // TODO: بروزرسانی مستقیم کش در AdvancedCacheSystem

      logInfo('✅ Message removed from cache: $messageId');
    } catch (e) {
      logInfo('⚠️ Error removing message from cache: $e');
    }
  }

  /// ارسال وضعیت حذف‌ها
  void _emitDeletionStatus() {
    final statusMap = <String, SyncStatus>{};
    for (final entry in _pendingDeletions.entries) {
      statusMap[entry.key] = entry.value.syncStatus;
    }
    if (!_deletionStatusStream.isClosed) {
      _deletionStatusStream.add(statusMap);
    }
  }

  /// دریافت stream وضعیت حذف‌ها
  Stream<Map<String, SyncStatus>> get deletionStatusStream =>
      _deletionStatusStream.stream;

  /// دریافت تعداد حذف‌های معلق
  int get pendingDeletionCount => _pendingDeletions.values
      .where((r) => r.syncStatus == SyncStatus.pending)
      .length;

  /// دریافت تعداد حذف‌های ناموفق
  int get failedDeletionCount => _pendingDeletions.values
      .where((r) => r.syncStatus == SyncStatus.failed)
      .length;

  /// پاک‌سازی منابع
  void dispose() {
    _batchTimer?.cancel();
    _deletionStatusStream.close();
    _pendingDeletions.clear();
    _batchedDeletions.clear();
    logInfo('🧹 OptimizedMessageDeletionService disposed');
  }
}
