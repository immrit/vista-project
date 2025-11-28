// lib/provider/retry_queue_provider.dart
//
// Provider های Riverpod برای مدیریت صف ارسال مجدد
//

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/retry_queue_item.dart';
import '../services/retry_queue_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// 🔧 SERVICE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای RetryQueueService (Singleton)
final retryQueueServiceProvider = Provider<RetryQueueService>((ref) {
  return RetryQueueService();
});

// ═══════════════════════════════════════════════════════════════════════════
// 📡 STREAM PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای stream صف (Real-time)
/// 
/// استفاده:
/// ```dart
/// final queueAsync = ref.watch(retryQueueStreamProvider);
/// queueAsync.when(
///   data: (items) => ...,
///   loading: () => ...,
///   error: (e, s) => ...,
/// );
/// ```
final retryQueueStreamProvider = StreamProvider<List<RetryQueueItem>>((ref) {
  final service = ref.watch(retryQueueServiceProvider);
  return service.queueStream;
});

/// Provider برای stream آپدیت آیتم‌ها
final retryItemUpdateStreamProvider = StreamProvider<RetryQueueItem>((ref) {
  final service = ref.watch(retryQueueServiceProvider);
  return service.itemUpdateStream;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📊 CURRENT STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای صف فعلی
final currentRetryQueueProvider = Provider<List<RetryQueueItem>>((ref) {
  // Watch stream to trigger rebuilds
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.queue;
});

/// Provider برای آیتم‌های pending
final pendingItemsProvider = Provider<List<RetryQueueItem>>((ref) {
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.pendingItems;
});

/// Provider برای آیتم‌های failed
final failedItemsProvider = Provider<List<RetryQueueItem>>((ref) {
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.failedItems;
});

/// Provider برای تعداد pending
final pendingCountProvider = Provider<int>((ref) {
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.pendingCount;
});

/// Provider برای تعداد کل
final totalQueueCountProvider = Provider<int>((ref) {
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.totalCount;
});

// ═══════════════════════════════════════════════════════════════════════════
// 📂 CONVERSATION SPECIFIC PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای آیتم‌های یک مکالمه خاص
/// 
/// استفاده:
/// ```dart
/// final items = ref.watch(conversationRetryItemsProvider(conversationId));
/// ```
final conversationRetryItemsProvider = Provider.family<List<RetryQueueItem>, String>(
  (ref, conversationId) {
    ref.watch(retryQueueStreamProvider);
    
    final service = ref.watch(retryQueueServiceProvider);
    return service.getItemsForConversation(conversationId);
  },
);

/// Provider برای تعداد pending یک مکالمه
final conversationPendingCountProvider = Provider.family<int, String>(
  (ref, conversationId) {
    final items = ref.watch(conversationRetryItemsProvider(conversationId));
    return items.where((item) => item.status == RetryItemStatus.pending).length;
  },
);

/// Provider برای بررسی وجود آیتم pending در مکالمه
final hasPendingInConversationProvider = Provider.family<bool, String>(
  (ref, conversationId) {
    final count = ref.watch(conversationPendingCountProvider(conversationId));
    return count > 0;
  },
);

// ═══════════════════════════════════════════════════════════════════════════
// 🎬 ACTIONS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای عملیات صف
/// 
/// استفاده:
/// ```dart
/// await ref.read(retryQueueActionsProvider).enqueue(item);
/// await ref.read(retryQueueActionsProvider).cancel(itemId);
/// await ref.read(retryQueueActionsProvider).retryNow(itemId);
/// ```
final retryQueueActionsProvider = Provider<RetryQueueActions>((ref) {
  final service = ref.watch(retryQueueServiceProvider);
  return RetryQueueActions(service);
});

/// کلاس برای عملیات صف
class RetryQueueActions {
  final RetryQueueService _service;

  RetryQueueActions(this._service);

  /// اضافه کردن آیتم به صف
  Future<void> enqueue(RetryQueueItem item) async {
    await _service.enqueue(item);
  }

  /// حذف آیتم از صف
  Future<void> dequeue(String itemId) async {
    await _service.dequeue(itemId);
  }

  /// لغو آیتم
  Future<void> cancel(String itemId) async {
    await _service.cancel(itemId);
  }

  /// Retry دستی
  Future<void> retryNow(String itemId) async {
    await _service.retryNow(itemId);
  }

  /// پاک کردن همه
  Future<void> clearAll() async {
    await _service.clearAll();
  }

  /// پاک کردن آیتم‌های یک مکالمه
  Future<void> clearConversation(String conversationId) async {
    await _service.clearConversation(conversationId);
  }

  /// ثبت executor
  void registerExecutor(RetryOperationType type, RetryExecutor executor) {
    _service.registerExecutor(type, executor);
  }

  /// حذف executor
  void unregisterExecutor(RetryOperationType type) {
    _service.unregisterExecutor(type);
  }

  /// گرفتن آمار
  Map<String, dynamic> getStats() {
    return _service.getStats();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 📈 STATS PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای آمار صف
final retryQueueStatsProvider = Provider<Map<String, dynamic>>((ref) {
  ref.watch(retryQueueStreamProvider);
  
  final service = ref.watch(retryQueueServiceProvider);
  return service.getStats();
});

// ═══════════════════════════════════════════════════════════════════════════
// 🔔 NOTIFICATION PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider برای بررسی وجود آیتم‌های failed
final hasFailedItemsProvider = Provider<bool>((ref) {
  final failedItems = ref.watch(failedItemsProvider);
  return failedItems.isNotEmpty;
});

/// Provider برای بررسی خالی بودن صف
final isQueueEmptyProvider = Provider<bool>((ref) {
  final totalCount = ref.watch(totalQueueCountProvider);
  return totalCount == 0;
});

