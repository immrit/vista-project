// lib/services/retry_queue_service.dart
//
// سرویس مدیریت صف ارسال مجدد
//
// این سرویس:
// ✅ پیام‌های ناموفق رو ذخیره میکنه
// ✅ وقتی شبکه برگشت، خودکار ارسال میکنه
// ✅ اولویت‌بندی میکنه
// ✅ Persistent Storage داره (صف از بین نمیره)
//

import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/retry_queue_item.dart';
import '../model/network_state.dart';
import '../security/logging_utility.dart';
import 'network_state_service.dart';

/// Callback برای اجرای عملیات
typedef RetryExecutor = Future<bool> Function(RetryQueueItem item);

class RetryQueueService {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔧 SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final RetryQueueService _instance = RetryQueueService._internal();
  factory RetryQueueService() => _instance;
  RetryQueueService._internal();

  // ═══════════════════════════════════════════════════════════════════════════
  // 📦 STORAGE
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _storageKey = 'retry_queue_items';
  SharedPreferences? _prefs;

  // ═══════════════════════════════════════════════════════════════════════════
  // 📋 QUEUE
  // ═══════════════════════════════════════════════════════════════════════════

  final List<RetryQueueItem> _queue = [];
  List<RetryQueueItem> get queue => List.unmodifiable(_queue);

  // ═══════════════════════════════════════════════════════════════════════════
  // 📡 STREAM CONTROLLERS
  // ═══════════════════════════════════════════════════════════════════════════

  final _queueController = StreamController<List<RetryQueueItem>>.broadcast();
  Stream<List<RetryQueueItem>> get queueStream => _queueController.stream;

  final _itemUpdateController = StreamController<RetryQueueItem>.broadcast();
  Stream<RetryQueueItem> get itemUpdateStream => _itemUpdateController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔌 SUBSCRIPTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  StreamSubscription<NetworkState>? _networkSubscription;

  // ═══════════════════════════════════════════════════════════════════════════
  // ⏱️ TIMERS
  // ═══════════════════════════════════════════════════════════════════════════

  Timer? _processTimer;
  Timer? _cleanupTimer;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎛️ FLAGS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isProcessing = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration _processInterval = Duration(seconds: 5);
  static const Duration _cleanupInterval = Duration(minutes: 30);
  static const int _maxQueueSize = 100;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 EXECUTORS
  // ═══════════════════════════════════════════════════════════════════════════

  final Map<RetryOperationType, RetryExecutor> _executors = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // 🚀 INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize service
  Future<void> initialize() async {
    if (_isInitialized) {
      logInfo('⚠️ RetryQueueService already initialized');
      return;
    }

    logInfo('🚀 Initializing RetryQueueService...');

    try {
      // Load SharedPreferences
      _prefs = await SharedPreferences.getInstance();

      // Load persisted queue
      await _loadQueue();

      // Listen to network changes
      _networkSubscription = NetworkStateService().stateStream.listen(
        _onNetworkStateChanged,
      );

      // Start process timer
      _startProcessTimer();

      // Start cleanup timer
      _startCleanupTimer();

      _isInitialized = true;
      logInfo('✅ RetryQueueService initialized with ${_queue.length} items');
    } catch (e, stack) {
      logInfo('❌ Failed to initialize RetryQueueService: $e');
      logInfo('Stack trace: $stack');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📥 QUEUE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  /// اضافه کردن آیتم به صف
  Future<void> enqueue(RetryQueueItem item) async {
    if (_isDisposed) return;

    // چک کردن سایز صف
    if (_queue.length >= _maxQueueSize) {
      logInfo('⚠️ Queue is full, removing oldest items');
      _removeOldestItems(10);
    }

    // چک duplicate
    if (_queue.any((i) => i.id == item.id)) {
      logInfo('⚠️ Item ${item.id} already in queue');
      return;
    }

    _queue.add(item);
    _sortQueue();
    _notifyQueueChanged();
    await _saveQueue();

    logInfo('📥 Enqueued: ${item.typeText} (${item.id})');

    // اگه آنلاین هستیم، فوری پردازش کن
    if (NetworkStateService().currentState.isConnected) {
      _processQueue();
    }
  }

  /// حذف آیتم از صف
  Future<void> dequeue(String itemId) async {
    if (_isDisposed) return;

    _queue.removeWhere((item) => item.id == itemId);
    _notifyQueueChanged();
    await _saveQueue();

    logInfo('📤 Dequeued: $itemId');
  }

  /// لغو آیتم
  Future<void> cancel(String itemId) async {
    if (_isDisposed) return;

    final index = _queue.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    _queue[index] = _queue[index].copyWith(
      status: RetryItemStatus.cancelled,
    );
    
    _notifyItemUpdated(_queue[index]);
    _notifyQueueChanged();
    await _saveQueue();

    logInfo('🚫 Cancelled: $itemId');
  }

  /// Retry دستی
  Future<void> retryNow(String itemId) async {
    if (_isDisposed) return;

    final index = _queue.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    _queue[index] = _queue[index].copyWith(
      status: RetryItemStatus.pending,
      attemptCount: 0,
      errorMessage: null,
    );

    _notifyItemUpdated(_queue[index]);
    _notifyQueueChanged();
    await _saveQueue();

    logInfo('🔄 Manual retry: $itemId');

    // فوری پردازش کن
    _processQueue();
  }

  /// گرفتن آیتم‌های یک مکالمه
  List<RetryQueueItem> getItemsForConversation(String conversationId) {
    return _queue
        .where((item) => item.conversationId == conversationId)
        .toList();
  }

  /// گرفتن آیتم‌های pending
  List<RetryQueueItem> get pendingItems {
    return _queue
        .where((item) => item.status == RetryItemStatus.pending)
        .toList();
  }

  /// گرفتن آیتم‌های failed
  List<RetryQueueItem> get failedItems {
    return _queue
        .where((item) => item.status == RetryItemStatus.failed)
        .toList();
  }

  /// تعداد آیتم‌های pending
  int get pendingCount => pendingItems.length;

  /// تعداد کل آیتم‌ها
  int get totalCount => _queue.length;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 EXECUTOR REGISTRATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// ثبت executor برای یک نوع عملیات
  void registerExecutor(RetryOperationType type, RetryExecutor executor) {
    _executors[type] = executor;
    logInfo('📝 Registered executor for: ${type.name}');
  }

  /// حذف executor
  void unregisterExecutor(RetryOperationType type) {
    _executors.remove(type);
    logInfo('🗑️ Unregistered executor for: ${type.name}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔄 PROCESSING
  // ═══════════════════════════════════════════════════════════════════════════

  /// شروع timer پردازش
  void _startProcessTimer() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(_processInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _processQueue();
    });
  }

  /// پردازش صف
  Future<void> _processQueue() async {
    if (_isDisposed || _isProcessing) return;
    
    final networkState = NetworkStateService().currentState;
    if (!networkState.isConnected) {
      return;
    }

    _isProcessing = true;

    try {
      // گرفتن آیتم‌های pending که قابل retry هستن
      final itemsToProcess = _queue
          .where((item) => 
            item.status == RetryItemStatus.pending && 
            item.canRetry &&
            !item.isExpired)
          .toList();

      if (itemsToProcess.isEmpty) {
        _isProcessing = false;
        return;
      }

      logInfo('🔄 Processing ${itemsToProcess.length} items...');

      for (final item in itemsToProcess) {
        if (_isDisposed) break;
        
        // چک دوباره شبکه
        if (!NetworkStateService().currentState.isConnected) {
          logInfo('⚠️ Network disconnected, stopping processing');
          break;
        }

        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// پردازش یک آیتم
  Future<void> _processItem(RetryQueueItem item) async {
    final executor = _executors[item.type];
    if (executor == null) {
      logInfo('⚠️ No executor registered for: ${item.type.name}');
      return;
    }

    // Update status to sending
    final index = _queue.indexWhere((i) => i.id == item.id);
    if (index == -1) return;

    _queue[index] = item.copyWith(
      status: RetryItemStatus.sending,
      lastAttemptAt: DateTime.now(),
      attemptCount: item.attemptCount + 1,
    );
    _notifyItemUpdated(_queue[index]);

    try {
      logInfo('📤 Processing: ${item.typeText} (attempt ${item.attemptCount + 1}/${item.maxAttempts})');

      final success = await executor(item);

      if (success) {
        // موفقیت - حذف از صف
        _queue[index] = _queue[index].copyWith(
          status: RetryItemStatus.completed,
        );
        _notifyItemUpdated(_queue[index]);
        
        // حذف بعد از یه تاخیر کوتاه
        Future.delayed(const Duration(seconds: 2), () {
          dequeue(item.id);
        });

        logInfo('✅ Success: ${item.typeText} (${item.id})');
      } else {
        // شکست
        _handleFailure(index, 'عملیات ناموفق بود');
      }
    } catch (e) {
      logInfo('❌ Error processing ${item.id}: $e');
      _handleFailure(index, e.toString());
    }

    await _saveQueue();
    _notifyQueueChanged();
  }

  /// مدیریت شکست
  void _handleFailure(int index, String error) {
    if (index < 0 || index >= _queue.length) return;

    final item = _queue[index];
    
    if (item.attemptCount >= item.maxAttempts) {
      // حداکثر تلاش - failed
      _queue[index] = item.copyWith(
        status: RetryItemStatus.failed,
        errorMessage: error,
      );
      logInfo('💀 Max attempts reached for: ${item.id}');
    } else {
      // برگردون به pending برای تلاش بعدی
      _queue[index] = item.copyWith(
        status: RetryItemStatus.pending,
        errorMessage: error,
      );
    }

    _notifyItemUpdated(_queue[index]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌐 NETWORK HANDLING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Handle network state changes
  void _onNetworkStateChanged(NetworkState state) {
    if (_isDisposed) return;

    if (state.isConnected && pendingCount > 0) {
      logInfo('🌐 Network connected, processing queue...');
      _processQueue();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// شروع timer پاکسازی
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _cleanup();
    });
  }

  /// پاکسازی آیتم‌های منقضی و completed
  Future<void> _cleanup() async {
    if (_isDisposed) return;

    final initialCount = _queue.length;

    // حذف آیتم‌های منقضی
    _queue.removeWhere((item) => item.isExpired);

    // حذف آیتم‌های completed
    _queue.removeWhere((item) => item.status == RetryItemStatus.completed);

    // حذف آیتم‌های cancelled قدیمی (بیش از 1 ساعت)
    _queue.removeWhere((item) => 
      item.status == RetryItemStatus.cancelled &&
      DateTime.now().difference(item.createdAt) > const Duration(hours: 1));

    final removedCount = initialCount - _queue.length;
    if (removedCount > 0) {
      logInfo('🧹 Cleaned up $removedCount items');
      _notifyQueueChanged();
      await _saveQueue();
    }
  }

  /// حذف قدیمی‌ترین آیتم‌ها
  void _removeOldestItems(int count) {
    _queue.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (var i = 0; i < count && _queue.isNotEmpty; i++) {
      _queue.removeAt(0);
    }
  }

  /// پاک کردن همه آیتم‌ها
  Future<void> clearAll() async {
    _queue.clear();
    _notifyQueueChanged();
    await _saveQueue();
    logInfo('🗑️ Queue cleared');
  }

  /// پاک کردن آیتم‌های یک مکالمه
  Future<void> clearConversation(String conversationId) async {
    _queue.removeWhere((item) => item.conversationId == conversationId);
    _notifyQueueChanged();
    await _saveQueue();
    logInfo('🗑️ Cleared items for conversation: $conversationId');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 💾 PERSISTENCE
  // ═══════════════════════════════════════════════════════════════════════════

  /// بارگذاری صف از storage
  Future<void> _loadQueue() async {
    try {
      final jsonString = _prefs?.getString(_storageKey);
      if (jsonString == null || jsonString.isEmpty) return;

      final jsonList = jsonDecode(jsonString) as List;
      _queue.clear();
      
      for (final json in jsonList) {
        try {
          final item = RetryQueueItem.fromJson(json as Map<String, dynamic>);
          // فقط آیتم‌های غیر منقضی رو لود کن
          if (!item.isExpired && item.status != RetryItemStatus.completed) {
            // Reset status to pending if it was sending
            if (item.status == RetryItemStatus.sending) {
              _queue.add(item.copyWith(status: RetryItemStatus.pending));
            } else {
              _queue.add(item);
            }
          }
        } catch (e) {
          logInfo('⚠️ Failed to parse queue item: $e');
        }
      }

      _sortQueue();
      logInfo('💾 Loaded ${_queue.length} items from storage');
    } catch (e) {
      logInfo('❌ Failed to load queue: $e');
    }
  }

  /// ذخیره صف در storage
  Future<void> _saveQueue() async {
    try {
      final jsonList = _queue.map((item) => item.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs?.setString(_storageKey, jsonString);
    } catch (e) {
      logInfo('❌ Failed to save queue: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔔 NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// مرتب‌سازی صف بر اساس اولویت
  void _sortQueue() {
    _queue.sort((a, b) {
      // اول بر اساس اولویت
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      
      // بعد بر اساس زمان
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// اطلاع‌رسانی تغییر صف
  void _notifyQueueChanged() {
    if (!_queueController.isClosed) {
      _queueController.add(List.unmodifiable(_queue));
    }
  }

  /// اطلاع‌رسانی آپدیت آیتم
  void _notifyItemUpdated(RetryQueueItem item) {
    if (!_itemUpdateController.isClosed) {
      _itemUpdateController.add(item);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 STATS
  // ═══════════════════════════════════════════════════════════════════════════

  /// گرفتن آمار
  Map<String, dynamic> getStats() {
    return {
      'totalItems': _queue.length,
      'pendingItems': pendingItems.length,
      'failedItems': failedItems.length,
      'isProcessing': _isProcessing,
      'executorsRegistered': _executors.keys.map((e) => e.name).toList(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧹 DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose service
  void dispose() {
    if (_isDisposed) return;

    logInfo('🧹 Disposing RetryQueueService...');

    _isDisposed = true;
    _networkSubscription?.cancel();
    _processTimer?.cancel();
    _cleanupTimer?.cancel();
    _queueController.close();
    _itemUpdateController.close();
    _executors.clear();

    logInfo('✅ RetryQueueService disposed');
  }
}

