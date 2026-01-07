import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// سرویس تشخیص و رفع Memory Leaks در سیستم پیام‌رسانی
class MemoryLeakDetector {
  static final MemoryLeakDetector _instance = MemoryLeakDetector._internal();
  factory MemoryLeakDetector() => _instance;
  MemoryLeakDetector._internal();

  // ردیابی active objects
  final Map<String, int> _activeObjects = {};
  final Map<String, DateTime> _objectCreationTime = {};
  final Set<StreamSubscription> _activeSubscriptions = {};
  final Set<Timer> _activeTimers = {};

  // آمار memory
  int _totalMemoryAllocations = 0;
  int _totalMemoryDeallocations = 0;

  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// شروع نظارت بر memory leaks
  void startMonitoring() {
    if (_isMonitoring) return;

    _isMonitoring = true;
    logInfo('🔍 Memory Leak Detection started...');

    // بررسی هر 30 ثانیه
    _monitoringTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkForLeaks();
    });
  }

  /// توقف نظارت
  void stopMonitoring() {
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    logInfo('🔍 Memory Leak Detection stopped');
  }

  /// ثبت ایجاد object جدید
  void trackObjectCreation(String objectType, String objectId) {
    final key = '${objectType}_$objectId';
    _activeObjects[key] = (_activeObjects[key] ?? 0) + 1;
    _objectCreationTime[key] = DateTime.now();
    _totalMemoryAllocations++;

    if (kDebugMode) {
      developer.log('📋 Object created: $key', name: 'MemoryTracker');
    }
  }

  /// ثبت حذف object
  void trackObjectDisposal(String objectType, String objectId) {
    final key = '${objectType}_$objectId';
    if (_activeObjects.containsKey(key)) {
      _activeObjects[key] = _activeObjects[key]! - 1;
      if (_activeObjects[key]! <= 0) {
        _activeObjects.remove(key);
        _objectCreationTime.remove(key);
      }
    }
    _totalMemoryDeallocations++;

    if (kDebugMode) {
      developer.log('🗑️ Object disposed: $key', name: 'MemoryTracker');
    }
  }

  /// ثبت StreamSubscription
  void trackSubscription(StreamSubscription subscription) {
    _activeSubscriptions.add(subscription);
    if (kDebugMode) {
      developer.log('📡 Subscription tracked: ${subscription.hashCode}',
          name: 'MemoryTracker');
    }
  }

  /// حذف StreamSubscription
  void untrackSubscription(StreamSubscription subscription) {
    _activeSubscriptions.remove(subscription);
    if (kDebugMode) {
      developer.log('🔌 Subscription untracked: ${subscription.hashCode}',
          name: 'MemoryTracker');
    }
  }

  /// ثبت Timer
  void trackTimer(Timer timer) {
    _activeTimers.add(timer);
    if (kDebugMode) {
      developer.log('⏰ Timer tracked: ${timer.hashCode}',
          name: 'MemoryTracker');
    }
  }

  /// حذف Timer
  void untrackTimer(Timer timer) {
    _activeTimers.remove(timer);
    if (kDebugMode) {
      developer.log('⏰ Timer untracked: ${timer.hashCode}',
          name: 'MemoryTracker');
    }
  }

  /// بررسی وجود memory leaks
  void _checkForLeaks() {
    final now = DateTime.now();
    final leakedObjects = <String>[];
    final longLivedObjects = <String>[];

    // بررسی objects طولانی‌مدت (بیش از 10 دقیقه)
    for (final entry in _objectCreationTime.entries) {
      final lifetime = now.difference(entry.value);
      if (lifetime.inMinutes > 10) {
        longLivedObjects.add(entry.key);
      }
      if (lifetime.inMinutes > 30) {
        leakedObjects.add(entry.key);
      }
    }

    // بررسی subscriptions که cancel نشده‌اند
    final activeSubscriptionsCount = _activeSubscriptions.length;
    final activeTimersCount = _activeTimers.length;

    // گزارش
    if (leakedObjects.isNotEmpty ||
        activeSubscriptionsCount > 10 ||
        activeTimersCount > 5) {
      _reportLeaks(leakedObjects, longLivedObjects, activeSubscriptionsCount,
          activeTimersCount);
    }

    // آمار کلی
    _reportMemoryStats();
  }

  /// گزارش memory leaks
  void _reportLeaks(List<String> leakedObjects, List<String> longLivedObjects,
      int subscriptions, int timers) {
    logInfo('\n🚨 MEMORY LEAK DETECTED! 🚨');

    if (leakedObjects.isNotEmpty) {
      logInfo('💀 Leaked Objects (30+ min):');
      for (final obj in leakedObjects.take(5)) {
        logInfo('   - $obj');
      }
      if (leakedObjects.length > 5) {
        logInfo('   ... and ${leakedObjects.length - 5} more');
      }
    }

    if (longLivedObjects.isNotEmpty) {
      logInfo('⚠️  Long-lived Objects (10+ min):');
      for (final obj in longLivedObjects.take(3)) {
        logInfo('   - $obj');
      }
    }

    if (subscriptions > 10) {
      logInfo('📡 Too many active subscriptions: $subscriptions');
    }

    if (timers > 5) {
      logInfo('⏰ Too many active timers: $timers');
    }

    logInfo('🔧 Recommended actions:');
    logInfo('   1. Check dispose() methods in providers');
    logInfo('   2. Cancel StreamSubscriptions properly');
    logInfo('   3. Cancel Timers when not needed');
    logInfo('   4. Use autoDispose for temporary providers\n');
  }

  /// گزارش آمار memory
  void _reportMemoryStats() {
    final memoryLeakRate = _totalMemoryAllocations > 0
        ? ((_totalMemoryAllocations - _totalMemoryDeallocations) /
            _totalMemoryAllocations *
            100)
        : 0.0;

    if (kDebugMode && _totalMemoryAllocations % 1000 == 0) {
      // گزارش هر 100 allocation
      logInfo('\n📊 Memory Stats:');
      logInfo('   Allocations: $_totalMemoryAllocations');
      logInfo('   Deallocations: $_totalMemoryDeallocations');
      logInfo('   Active Objects: ${_activeObjects.length}');
      logInfo('   Active Subscriptions: ${_activeSubscriptions.length}');
      logInfo('   Active Timers: ${_activeTimers.length}');
      logInfo('   Leak Rate: ${memoryLeakRate.toStringAsFixed(1)}%');

      if (memoryLeakRate > 15) {
        logInfo('   🚨 HIGH LEAK RATE! Check your dispose methods!');
      } else if (memoryLeakRate > 5) {
        logInfo('   ⚠️  Moderate leak rate, consider optimization');
      } else {
        logInfo('   ✅ Good memory management');
      }
      logInfo('');
    }
  }

  /// پاکسازی اجباری برای memory leaks
  void forceCleanup() {
    logInfo('🧹 Force cleanup started...');

    // Cancel همه subscriptions
    for (final subscription in List.from(_activeSubscriptions)) {
      try {
        subscription.cancel();
      } catch (e) {
        logInfo('⚠️ Error canceling subscription: $e');
      }
    }
    _activeSubscriptions.clear();

    // Cancel همه timers
    for (final timer in List.from(_activeTimers)) {
      try {
        timer.cancel();
      } catch (e) {
        logInfo('⚠️ Error canceling timer: $e');
      }
    }
    _activeTimers.clear();

    // پاک کردن tracking data
    _activeObjects.clear();
    _objectCreationTime.clear();

    logInfo('✅ Force cleanup completed');
  }

  /// دریافت آمار فعلی
  Map<String, dynamic> getCurrentStats() {
    return {
      'active_objects': _activeObjects.length,
      'active_subscriptions': _activeSubscriptions.length,
      'active_timers': _activeTimers.length,
      'total_allocations': _totalMemoryAllocations,
      'total_deallocations': _totalMemoryDeallocations,
      'leak_rate': _totalMemoryAllocations > 0
          ? ((_totalMemoryAllocations - _totalMemoryDeallocations) /
              _totalMemoryAllocations *
              100)
          : 0.0,
    };
  }

  /// Dispose کامل
  void dispose() {
    stopMonitoring();
    forceCleanup();
  }
}

/// Extension برای تسهیل tracking
extension MemoryTrackingExtension on Object {
  /// Track کردن object
  void trackMemory(String objectType) {
    MemoryLeakDetector().trackObjectCreation(objectType, hashCode.toString());
  }

  /// Untrack کردن object
  void untrackMemory(String objectType) {
    MemoryLeakDetector().trackObjectDisposal(objectType, hashCode.toString());
  }
}

extension StreamSubscriptionTracking on StreamSubscription {
  /// Track کردن subscription
  void trackMemory() {
    MemoryLeakDetector().trackSubscription(this);
  }

  /// Untrack کردن subscription
  void untrackMemory() {
    MemoryLeakDetector().untrackSubscription(this);
  }
}

extension TimerTracking on Timer {
  /// Track کردن timer
  void trackMemory() {
    MemoryLeakDetector().trackTimer(this);
  }

  /// Untrack کردن timer
  void untrackMemory() {
    MemoryLeakDetector().untrackTimer(this);
  }
}
