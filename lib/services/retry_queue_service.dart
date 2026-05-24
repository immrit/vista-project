import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/retry_queue_entity.dart';
import '../model/retry_queue_item.dart';

class RetryQueueService {
  static final RetryQueueService _instance = RetryQueueService._internal();
  factory RetryQueueService() => _instance;
  RetryQueueService._internal();

  Isar? _isar;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isProcessing = false;
  bool _isOnline = false;

  Future<void> initialize() async {
    _isar = await IsarDatabaseManager().instance;

    // Check initial connectivity
    final connectivity = await Connectivity().checkConnectivity();
    _isOnline = _checkIsOnline(connectivity);

    // Listen for changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isNowOnline = _checkIsOnline(results);
      if (isNowOnline && !_isOnline) {
        debugPrint('🌐 Network restored! Processing offline retry queue...');
        _isOnline = true;
        _processQueue();
      } else if (!isNowOnline) {
        _isOnline = false;
      }
    });

    debugPrint(
        '🤖 Retry Queue Service Initialized. Offline Mode: ${!_isOnline}');
    // Process any leftovers in queue on startup if online
    if (_isOnline) {
      _processQueue();
    }
  }

  bool _checkIsOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> enqueue(RetryQueueItem item) async {
    final isar = _isar;
    if (isar == null) return;

    final entity = RetryQueueEntity.fromModel(item);
    await isar.writeTxn(() async {
      await isar.retryQueueEntitys.putByItemId(entity);
    });

    debugPrint('📥 Enqueued offline task: ${item.typeText} (${item.id})');

    if (_isOnline) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing || !_isOnline) return;
    _isProcessing = true;

    try {
      final isar = _isar;
      if (isar == null) return;

      // Get all pending/failed items ordered by priority and date
      final pendingEntities = await isar.retryQueueEntitys
          .where()
          .filter()
          .statusEqualTo(RetryItemStatus.pending)
          .or()
          .statusEqualTo(RetryItemStatus.failed)
          .sortByPriorityDesc()
          .thenByCreatedAt()
          .findAll();

      if (pendingEntities.isEmpty) {
        _isProcessing = false;
        return;
      }

      debugPrint(
          '⚡ Processing ${pendingEntities.length} offline retry queue items...');

      for (var entity in pendingEntities) {
        final item = entity.toModel();
        if (!item.canRetry) continue;

        // Update status to sending
        await _updateStatus(item.id, RetryItemStatus.sending);

        bool success = await _executeAction(item);

        if (success) {
          await _updateStatus(item.id, RetryItemStatus.completed);
          await _deleteItem(item.id);
          debugPrint('✅ Task completed and removed from queue: ${item.id}');
        } else {
          final nextAttempts = item.attemptCount + 1;
          if (nextAttempts >= item.maxAttempts) {
            await _updateStatus(item.id, RetryItemStatus.failed,
                error: 'Exceeded max retry attempts');
            debugPrint('❌ Task permanently failed: ${item.id}');
          } else {
            await _updateStatus(item.id, RetryItemStatus.failed,
                attempts: nextAttempts, error: 'Network attempt failed');
            debugPrint(
                '⚠️ Task failed, will retry later: ${item.id} (Attempt $nextAttempts)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error in retry queue loop: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _executeAction(RetryQueueItem item) async {
    try {
      // Simulate network sync delay
      await Future.delayed(const Duration(seconds: 1));

      switch (item.type) {
        case RetryOperationType.sendMessage:
          debugPrint('Syncing Message: ${item.payload['content']}');
          return true;
        case RetryOperationType.uploadFile:
          debugPrint('Syncing File Upload: ${item.payload['file_name']}');
          return true;
        case RetryOperationType.deleteMessage:
          debugPrint('Syncing Message Deletion: ${item.payload['message_id']}');
          return true;
        case RetryOperationType.editMessage:
          debugPrint('Syncing Message Edit: ${item.payload['new_content']}');
          return true;
        case RetryOperationType.toggleReaction:
          debugPrint('Syncing Message Reaction: ${item.payload['emoji']}');
          return true;
      }
    } catch (e) {
      debugPrint('Error syncing task ${item.id}: $e');
      return false;
    }
  }

  Future<void> _updateStatus(String itemId, RetryItemStatus status,
      {int? attempts, String? error}) async {
    final isar = _isar;
    if (isar == null) return;

    await isar.writeTxn(() async {
      final entity = await isar.retryQueueEntitys.getByItemId(itemId);
      if (entity != null) {
        entity.status = status;
        if (attempts != null) {
          entity.attemptCount = attempts;
        }
        entity.lastAttemptAt = DateTime.now();
        if (error != null) {
          entity.errorMessage = error;
        }
        await isar.retryQueueEntitys.putByItemId(entity);
      }
    });
  }

  Future<void> _deleteItem(String itemId) async {
    final isar = _isar;
    if (isar == null) return;

    await isar.writeTxn(() async {
      final entity = await isar.retryQueueEntitys.getByItemId(itemId);
      if (entity != null) {
        await isar.retryQueueEntitys.delete(entity.id);
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
