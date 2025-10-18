import '../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// سرویس مدیریت تلاش مجدد برای ارسال پیام‌ها
/// - تلاش خودکار با backoff
/// - حداکثر 3 بار تلاش
/// - حفظ وضعیت retry برای هر پیام
class MessageRetryService {
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 2);

  // Map of message ID to retry info
  final Map<String, RetryInfo> _retryMap = {};

  // Stream for retry events
  final _retryController = StreamController<RetryEvent>.broadcast();
  Stream<RetryEvent> get retryStream => _retryController.stream;

  // Retry timers
  final Map<String, Timer> _timers = {};

  /// Schedule a message for retry
  Future<void> scheduleRetry(
    String messageId, {
    required Future<void> Function() onRetry,
    int retryCount = 0,
  }) async {
    final retryInfo = _retryMap[messageId] ??
        RetryInfo(
          messageId: messageId,
          retryCount: retryCount,
          lastAttemptTime: DateTime.now(),
        );

    if (retryInfo.retryCount >= maxRetries) {
      debugPrint(
          '⚠️ Max retries reached for message $messageId (${retryInfo.retryCount})');
      _retryController.add(RetryEvent.maxRetriesReached(messageId));
      return;
    }

    // Cancel existing timer if any
    _timers[messageId]?.cancel();

    // Calculate delay with exponential backoff
    final delay = baseDelay * (1 << retryInfo.retryCount); // 2s, 4s, 8s
    debugPrint(
        '⏱️ Scheduling retry for message $messageId in ${delay.inSeconds}s (attempt ${retryInfo.retryCount + 1}/$maxRetries)');

    _retryController.add(RetryEvent.scheduled(messageId, retryInfo.retryCount));

    // Schedule the retry
    _timers[messageId] = Timer(delay, () async {
      try {
        debugPrint(
            '🔄 Retrying message $messageId (attempt ${retryInfo.retryCount + 1})');
        await onRetry();

        // Success - remove from retry map
        _retryMap.remove(messageId);
        _timers.remove(messageId);
        _retryController.add(RetryEvent.success(messageId));
      } catch (e) {
        logDebug('❌ Retry failed for message $messageId: $e');

        // Update retry count and schedule next retry
        retryInfo.retryCount++;
        retryInfo.lastAttemptTime = DateTime.now();
        _retryMap[messageId] = retryInfo;

        if (retryInfo.retryCount < maxRetries) {
          // Schedule next retry
          await scheduleRetry(
            messageId,
            onRetry: onRetry,
            retryCount: retryInfo.retryCount,
          );
        } else {
          // Max retries reached
          _retryController.add(RetryEvent.maxRetriesReached(messageId));
        }
      }
    });
  }

  /// Manually retry a message
  Future<void> manualRetry(
    String messageId, {
    required Future<void> Function() onRetry,
  }) async {
    logDebug('👤 Manual retry requested for message $messageId');

    // Reset retry count for manual retry
    _retryMap.remove(messageId);

    try {
      await onRetry();
      _retryController.add(RetryEvent.success(messageId));
    } catch (e) {
      logDebug('❌ Manual retry failed: $e');
      // Schedule automatic retry after manual attempt
      await scheduleRetry(
        messageId,
        onRetry: onRetry,
        retryCount: 0,
      );
    }
  }

  /// Get retry info for a message
  RetryInfo? getRetryInfo(String messageId) => _retryMap[messageId];

  /// Cancel scheduled retry
  void cancelRetry(String messageId) {
    _timers[messageId]?.cancel();
    _timers.remove(messageId);
    _retryMap.remove(messageId);
    logDebug('❌ Cancelled retry for message $messageId');
  }

  /// Get all pending retries
  List<String> getPendingRetries() => _retryMap.keys.toList();

  /// Clear all retries
  void clearAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _retryMap.clear();
    logDebug('🗑️ Cleared all message retries');
  }

  void dispose() {
    clearAll();
    _retryController.close();
  }
}

/// Model for retry information
class RetryInfo {
  final String messageId;
  int retryCount;
  DateTime lastAttemptTime;

  RetryInfo({
    required this.messageId,
    required this.retryCount,
    required this.lastAttemptTime,
  });
}

/// Events for retry operations
class RetryEvent {
  final String messageId;
  final RetryEventType type;
  final int? retryAttempt;

  RetryEvent({
    required this.messageId,
    required this.type,
    this.retryAttempt,
  });

  factory RetryEvent.scheduled(String messageId, int attempt) => RetryEvent(
        messageId: messageId,
        type: RetryEventType.scheduled,
        retryAttempt: attempt,
      );

  factory RetryEvent.success(String messageId) => RetryEvent(
        messageId: messageId,
        type: RetryEventType.success,
      );

  factory RetryEvent.maxRetriesReached(String messageId) => RetryEvent(
        messageId: messageId,
        type: RetryEventType.maxRetriesReached,
      );

  @override
  String toString() => 'RetryEvent($messageId, $type, attempt: $retryAttempt)';
}

enum RetryEventType {
  scheduled,
  success,
  maxRetriesReached,
}
