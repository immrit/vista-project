import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:isar/isar.dart';

import '../../../DB/entities/deletion_task_entity.dart';
import '../../../DB/isar_database_manager.dart';
import '../../auth/providers/auth_controller.dart';
import '../../../security/logging_utility.dart';
import '../../../services/http_client_factory.dart';
import '../data/datasources/chat_local_datasource_isar.dart';

class MessageTombstoneService {
  static final MessageTombstoneService _instance =
      MessageTombstoneService._internal();

  factory MessageTombstoneService() => _instance;

  MessageTombstoneService._internal();

  final IsarDatabaseManager _dbManager = IsarDatabaseManager();
  final ChatLocalDataSourceIsar _localDataSource = ChatLocalDataSourceIsar();
  final Dio _dio = createApiV1Dio(baseUrl: EnvConfig.apiBaseUrl);
  static const String _syncedMarker = '__tombstone_synced__';

  Timer? _syncTimer;
  bool _isSyncing = false;

  Future<Set<String>> getDeletedMessageIds(String conversationId) async {
    final isar = await _dbManager.instance;
    final rows = await isar.deletionTaskEntitys
        .filter()
        .conversationIdEqualTo(conversationId)
        .findAll();
    return rows.map((e) => e.messageId).toSet();
  }

  Future<void> markDeletedLocally({
    required String messageId,
    required String conversationId,
    required bool deleteForEveryone,
  }) async {
    final isar = await _dbManager.instance;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await isar.writeTxn(() async {
      final existing = await isar.deletionTaskEntitys
          .filter()
          .messageIdEqualTo(messageId)
          .findFirst();
      final row = existing ?? DeletionTaskEntity();
      row.messageId = messageId;
      row.conversationId = conversationId;
      row.deletionMode = deleteForEveryone ? 1 : 0;
      row.retryCount = 0;
      row.nextAttempt = nowMs;
      row.timestamp = nowMs;
      row.s3Key = null;
      await isar.deletionTaskEntitys.put(row);
    });

    await _localDataSource.deleteMessage(messageId);
    _startSyncLoop();
    unawaited(syncPendingDeletes());
  }

  Future<void> markDeletedLocallyBatch({
    required List<String> messageIds,
    required String conversationId,
    required bool deleteForEveryone,
  }) async {
    if (messageIds.isEmpty) return;
    final isar = await _dbManager.instance;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final now = DateTime.now().toUtc();

    await isar.writeTxn(() async {
      for (final messageId in messageIds) {
        final existing = await isar.deletionTaskEntitys
            .filter()
            .messageIdEqualTo(messageId)
            .findFirst();
        final row = existing ?? DeletionTaskEntity();
        row.messageId = messageId;
        row.conversationId = conversationId;
        row.deletionMode = deleteForEveryone ? 1 : 0;
        row.retryCount = 0;
        row.nextAttempt = nowMs;
        row.timestamp = now.millisecondsSinceEpoch;
        row.s3Key = null;
        await isar.deletionTaskEntitys.put(row);
      }
    });

    for (final messageId in messageIds) {
      await _localDataSource.deleteMessage(messageId);
    }

    await _syncBatchImmediately(
      messageIds: messageIds,
      conversationId: conversationId,
      deleteForEveryone: deleteForEveryone,
    );

    _startSyncLoop();
    unawaited(syncPendingDeletes());
  }

  void _startSyncLoop() {
    _syncTimer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(syncPendingDeletes()),
    );
  }

  Future<void> _syncBatchImmediately({
    required List<String> messageIds,
    required String conversationId,
    required bool deleteForEveryone,
  }) async {
    if (messageIds.isEmpty) return;
    try {
      if (deleteForEveryone) {
        await _deleteForEveryoneServer(messageIds);
      } else {
        await _dio.post(
          '/chat/conversations/$conversationId/hide',
          data: {'message_ids': messageIds},
          options: await _authOptions(),
        );
      }

      await _markRowsSynced(messageIds);
      logInfo('message_delete_batch_synced: ${messageIds.join(",")}');
    } catch (e) {
      logWarning('Immediate tombstone sync failed, falling back to queue',
          error: e);
    }
  }

  Future<void> _deleteForEveryoneServer(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    for (final messageId in messageIds) {
      await _dio.delete(
        '/chat/messages/$messageId',
        queryParameters: {'for_everyone': true},
        options: await _authOptions(),
      );
    }
  }

  Future<void> _markRowsSynced(Iterable<String> messageIds) async {
    final isar = await _dbManager.instance;
    await isar.writeTxn(() async {
      for (final messageId in messageIds) {
        final row = await isar.deletionTaskEntitys
            .filter()
            .messageIdEqualTo(messageId)
            .findFirst();
        if (row == null) continue;
        row.s3Key = _syncedMarker;
        row.nextAttempt = 1 << 62;
        await isar.deletionTaskEntitys.put(row);
      }
    });
  }

  Future<void> syncPendingDeletes() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final isar = await _dbManager.instance;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final dueRows = await isar.deletionTaskEntitys
          .filter()
          .nextAttemptLessThan(nowMs + 1)
          .sortByNextAttempt()
          .findAll();

      final pending =
          dueRows.where((row) => row.s3Key != _syncedMarker).take(25).toList();

      for (final row in pending) {
        await _syncSingle(row);
      }
    } catch (e, s) {
      logError('Failed to sync tombstones', error: e, stackTrace: s);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncSingle(DeletionTaskEntity row) async {
    final isar = await _dbManager.instance;
    try {
      if (row.deletionMode == 1) {
        await _deleteForEveryoneServer([row.messageId]);
      } else {
        await _dio.post(
          '/chat/conversations/${row.conversationId}/hide',
          data: {
            'message_ids': [row.messageId]
          },
          options: await _authOptions(),
        );
      }

      await isar.writeTxn(() async {
        row.s3Key = _syncedMarker;
        row.nextAttempt = 1 << 62;
        await isar.deletionTaskEntitys.put(row);
      });

      logInfo('message_delete_synced: ${row.messageId}');
    } catch (e) {
      final retryCount = row.retryCount + 1;
      final backoffMs = _backoffMillis(retryCount);
      final nextRetryAt = DateTime.now().millisecondsSinceEpoch + backoffMs;

      await isar.writeTxn(() async {
        row.retryCount = retryCount;
        row.s3Key = e.toString();
        row.nextAttempt = nextRetryAt;
        await isar.deletionTaskEntitys.put(row);
      });
    }
  }

  int _backoffMillis(int retryCount) {
    final clamped = retryCount > 10 ? 10 : retryCount;
    final seconds = 2 * (1 << clamped);
    final capped = seconds > 120 ? 120 : seconds;
    return capped * 1000;
  }

  void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }
}
