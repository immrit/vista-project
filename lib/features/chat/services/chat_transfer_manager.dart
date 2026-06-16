import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../security/secure_kv_store.dart';

import '../../../security/logging_utility.dart';

enum TransferTaskStatus {
  queued,
  downloading,
  uploading,
  paused,
  completed,
  failed,
  canceled,
}

class ChatTransferTask {
  final String taskId;
  final String messageId;
  final String url;
  final String fileName;
  final String? localPath;
  final TransferTaskStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String? eTag;
  final DateTime updatedAt;

  const ChatTransferTask({
    required this.taskId,
    required this.messageId,
    required this.url,
    required this.fileName,
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.updatedAt,
    this.localPath,
    this.eTag,
  });

  double get progress {
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0, 1);
  }

  bool get isOfflineAvailable {
    final path = localPath;
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }
}

class _TransferTaskRecord {
  final String taskId;
  final String messageId;
  String url;
  String fileName;
  String? localPath;
  TransferTaskStatus status;
  int receivedBytes;
  int totalBytes;
  String? eTag;
  DateTime updatedAt;

  _TransferTaskRecord({
    required this.taskId,
    required this.messageId,
    required this.url,
    required this.fileName,
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.updatedAt,
    this.localPath,
    this.eTag,
  });

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'messageId': messageId,
        'url': url,
        'fileName': fileName,
        'localPath': localPath,
        'status': status.index,
        'receivedBytes': receivedBytes,
        'totalBytes': totalBytes,
        'eTag': eTag,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static _TransferTaskRecord? fromJson(Map<String, dynamic> json) {
    final taskId = json['taskId'] as String?;
    final messageId = json['messageId'] as String?;
    final url = json['url'] as String?;
    final fileName = json['fileName'] as String?;
    if (taskId == null ||
        messageId == null ||
        url == null ||
        url.isEmpty ||
        fileName == null ||
        fileName.isEmpty) {
      return null;
    }

    final statusIndex = (json['status'] as num?)?.toInt() ?? 0;
    final safeStatusIndex =
        statusIndex.clamp(0, TransferTaskStatus.values.length - 1);

    return _TransferTaskRecord(
      taskId: taskId,
      messageId: messageId,
      url: url,
      fileName: fileName,
      localPath: json['localPath'] as String?,
      status: TransferTaskStatus.values[safeStatusIndex],
      receivedBytes: (json['receivedBytes'] as num?)?.toInt() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      eTag: json['eTag'] as String?,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

class ChatTransferManager {
  static final ChatTransferManager _instance = ChatTransferManager._internal();
  factory ChatTransferManager() => _instance;

  ChatTransferManager._internal() {
    _initFuture = _loadFromPrefs();
    _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) => _onConnectivityChanged(results.first),
        onError: (_) {});
  }

  static const String _prefsKey = 'chat_transfer_tasks_v1';

  final Dio _dio = Dio();
  final Map<String, _TransferTaskRecord> _tasksById = {};
  final Map<String, String> _messageToTaskId = {};
  final Map<String, StreamController<ChatTransferTask?>> _watchers = {};

  final Map<String, CancelToken> _cancelTokens = {};
  final Set<String> _pauseRequested = {};
  final Set<String> _cancelRequested = {};

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Future<void>? _initFuture;
  bool _isInitialized = false;
  Timer? _persistDebounce;

  Future<void> _ensureInitialized() async {
    await _initFuture;
  }

  Future<void> _loadFromPrefs() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final raw = await SecureKeyValueStore.read(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is! Map) continue;
            final row = _TransferTaskRecord.fromJson(
              item.map((key, value) => MapEntry('$key', value)),
            );
            if (row == null) continue;

            if (row.status == TransferTaskStatus.downloading || row.status == TransferTaskStatus.uploading) {
              row.status = TransferTaskStatus.paused;
            }

            _tasksById[row.taskId] = row;
            _messageToTaskId[row.messageId] = row.taskId;
          }
        }
      }
      _schedulePersist();
    } catch (e, s) {
      logError('Failed to load transfer tasks from prefs',
          error: e, stackTrace: s);
    }
  }

  Future<void> _persistNow() async {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    try {
      final data = _tasksById.values.map((e) => e.toJson()).toList();
      await SecureKeyValueStore.write(_prefsKey, jsonEncode(data));
    } catch (e, s) {
      logError('Failed to persist transfer tasks', error: e, stackTrace: s);
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_persistNow());
    });
  }

  ChatTransferTask? _toPublicTask(_TransferTaskRecord? row) {
    if (row == null) return null;
    return ChatTransferTask(
      taskId: row.taskId,
      messageId: row.messageId,
      url: row.url,
      fileName: row.fileName,
      status: row.status,
      receivedBytes: row.receivedBytes,
      totalBytes: row.totalBytes,
      eTag: row.eTag,
      localPath: row.localPath,
      updatedAt: row.updatedAt,
    );
  }

  _TransferTaskRecord? _recordForMessage(String messageId) {
    final taskId = _messageToTaskId[messageId];
    if (taskId == null) return null;
    return _tasksById[taskId];
  }

  void _emitMessageTask(String messageId) {
    final watcher = _watchers[messageId];
    if (watcher == null || watcher.isClosed) return;
    watcher.add(_toPublicTask(_recordForMessage(messageId)));
  }

  void _touch(_TransferTaskRecord row) {
    row.updatedAt = DateTime.now().toUtc();
    _schedulePersist();
    _emitMessageTask(row.messageId);
  }

  /// Start or register an upload task
  Future<String> startUploadTask(
    String messageId,
    String localPath,
    String fileName, {
    int totalBytes = 0,
  }) async {
    await _ensureInitialized();
    final sanitizedName = _sanitizeFileName(fileName);

    final existing = _recordForMessage(messageId);
    if (existing != null) {
      existing.localPath = localPath;
      existing.fileName = sanitizedName;
      existing.totalBytes = totalBytes > 0 ? totalBytes : existing.totalBytes;
      existing.status = TransferTaskStatus.uploading;
      _touch(existing);
      return existing.taskId;
    }

    final taskId = '${messageId}_upload_${DateTime.now().millisecondsSinceEpoch}';
    final row = _TransferTaskRecord(
      taskId: taskId,
      messageId: messageId,
      url: '', // will be set upon completion
      fileName: sanitizedName,
      localPath: localPath,
      status: TransferTaskStatus.uploading,
      receivedBytes: 0,
      totalBytes: totalBytes,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasksById[taskId] = row;
    _messageToTaskId[messageId] = taskId;
    _touch(row);
    return taskId;
  }

  /// Update upload progress
  void updateUploadProgress(String messageId, int sentBytes, int totalBytes) {
    final row = _recordForMessage(messageId);
    if (row == null) return;
    
    row.status = TransferTaskStatus.uploading;
    row.receivedBytes = sentBytes;
    row.totalBytes = totalBytes;
    _touch(row);
  }

  /// Register upload completion and assign the final server URL
  Future<void> registerCompletedUpload({
    required String messageId,
    required String url,
    required String localPath,
    required String fileName,
    int? totalBytes,
  }) async {
    await _ensureInitialized();

    int finalBytes = totalBytes ?? 0;
    if (finalBytes == 0) {
      final localFile = File(localPath);
      if (localFile.existsSync()) {
        finalBytes = localFile.lengthSync();
      }
    }

    final sanitizedName = _sanitizeFileName(fileName);
    final existing = _recordForMessage(messageId);
    if (existing != null) {
      existing.url = url;
      existing.fileName = sanitizedName;
      existing.localPath = localPath;
      existing.receivedBytes = finalBytes;
      existing.totalBytes = finalBytes;
      existing.status = TransferTaskStatus.completed;
      _touch(existing);
      return;
    }

    final taskId = '${messageId}_local_${DateTime.now().millisecondsSinceEpoch}';
    final row = _TransferTaskRecord(
      taskId: taskId,
      messageId: messageId,
      url: url,
      fileName: sanitizedName,
      localPath: localPath,
      status: TransferTaskStatus.completed,
      receivedBytes: finalBytes,
      totalBytes: finalBytes,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasksById[taskId] = row;
    _messageToTaskId[messageId] = taskId;
    _touch(row);
  }

  Future<String> startDownload(
    String messageId,
    String url,
    String fileName,
  ) async {
    await _ensureInitialized();

    final existing = _recordForMessage(messageId);
    if (existing != null) {
      existing.url = url;
      existing.fileName = _sanitizeFileName(fileName);
      if (existing.status != TransferTaskStatus.completed ||
          !(existing.localPath != null &&
              File(existing.localPath!).existsSync())) {
        existing.status = TransferTaskStatus.queued;
      }
      _touch(existing);
      unawaited(_downloadByTaskId(existing.taskId));
      return existing.taskId;
    }

    final taskId = '${messageId}_${DateTime.now().millisecondsSinceEpoch}';
    final row = _TransferTaskRecord(
      taskId: taskId,
      messageId: messageId,
      url: url,
      fileName: _sanitizeFileName(fileName),
      status: TransferTaskStatus.queued,
      receivedBytes: 0,
      totalBytes: 0,
      updatedAt: DateTime.now().toUtc(),
    );

    _tasksById[taskId] = row;
    _messageToTaskId[messageId] = taskId;
    _touch(row);
    unawaited(_downloadByTaskId(taskId));
    return taskId;
  }

  // registerCompletedLocalUpload has been superseded by registerCompletedUpload,
  // but kept for compatibility.
  Future<void> registerCompletedLocalUpload({
    required String messageId,
    required String url,
    required String localPath,
    required String fileName,
  }) async {
    await registerCompletedUpload(
      messageId: messageId,
      url: url,
      localPath: localPath,
      fileName: fileName,
    );
  }

  Future<void> pause(String taskId) async {
    await _ensureInitialized();
    _pauseRequested.add(taskId);
    _cancelTokens[taskId]?.cancel('paused');

    final row = _tasksById[taskId];
    if (row != null && !_cancelTokens.containsKey(taskId)) {
      row.status = TransferTaskStatus.paused;
      _touch(row);
    }
    logInfo('download_paused: $taskId');
  }

  Future<void> resume(String taskId) async {
    await _ensureInitialized();
    _pauseRequested.remove(taskId);
    _cancelRequested.remove(taskId);
    await _downloadByTaskId(taskId, forceResume: true);
    logInfo('download_resumed: $taskId');
  }

  Future<void> cancel(String taskId) async {
    await _ensureInitialized();
    _cancelRequested.add(taskId);
    _cancelTokens[taskId]?.cancel('canceled');

    final row = _tasksById[taskId];
    if (row == null) return;

    if (!_cancelTokens.containsKey(taskId)) {
      await _deleteTaskFiles(row);
      row.status = TransferTaskStatus.canceled;
      row.receivedBytes = 0;
      row.totalBytes = 0;
      row.localPath = null;
      _touch(row);
    }
  }

  Stream<ChatTransferTask?> watchTask(String messageId) async* {
    await _ensureInitialized();
    final controller = _watchers.putIfAbsent(
      messageId,
      () => StreamController<ChatTransferTask?>.broadcast(),
    );
    yield _toPublicTask(_recordForMessage(messageId));
    yield* controller.stream;
  }

  Future<File?> getLocalFileIfExists(String messageId) async {
    await _ensureInitialized();
    final row = _recordForMessage(messageId);
    if (row == null) return null;
    final local = row.localPath;
    if (local == null || local.isEmpty) return null;
    final file = File(local);
    if (!file.existsSync()) return null;
    return file;
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) return;
    await _resumeQueuedTasks();
  }

  Future<void> _resumeQueuedTasks() async {
    await _ensureInitialized();
    for (final row in _tasksById.values) {
      if (row.status == TransferTaskStatus.queued ||
          row.status == TransferTaskStatus.downloading) {
        unawaited(_downloadByTaskId(row.taskId, forceResume: true));
      }
    }
  }

  Future<void> _downloadByTaskId(
    String taskId, {
    bool forceResume = false,
  }) async {
    await _ensureInitialized();
    if (_cancelTokens.containsKey(taskId)) return;

    final row = _tasksById[taskId];
    if (row == null) return;
    if (row.status == TransferTaskStatus.completed && !forceResume) return;

    final hasNet = await _hasConnectivity();
    if (!hasNet) {
      row.status = TransferTaskStatus.queued;
      _touch(row);
      return;
    }

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      final dir = await _getDownloadDirectory();
      final finalPath = p.join(dir.path, row.fileName);
      final partPath = '$finalPath.part';
      final partFile = File(partPath);
      var receivedBytes = partFile.existsSync() ? partFile.lengthSync() : 0;

      final headers = <String, String>{};
      if (receivedBytes > 0) {
        headers['Range'] = 'bytes=$receivedBytes-';
      }

      var response = await _dio.get<ResponseBody>(
        row.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
        ),
        cancelToken: cancelToken,
      );

      var contentLength = int.tryParse(
              response.headers.value(Headers.contentLengthHeader) ?? '') ??
          0;
      final statusCode = response.statusCode ?? 0;
      final rangeAccepted = receivedBytes > 0 && statusCode == 206;

      if (receivedBytes > 0 && !rangeAccepted) {
        if (partFile.existsSync()) {
          await partFile.delete();
        }
        receivedBytes = 0;
        response = await _dio.get<ResponseBody>(
          row.url,
          options: Options(responseType: ResponseType.stream),
          cancelToken: cancelToken,
        );
        contentLength = int.tryParse(
                response.headers.value(Headers.contentLengthHeader) ?? '') ??
            0;
      }

      final totalBytes =
          rangeAccepted ? receivedBytes + contentLength : contentLength;
      row.status = TransferTaskStatus.downloading;
      row.receivedBytes = receivedBytes;
      row.totalBytes = totalBytes;
      row.eTag = response.headers.value('etag');
      _touch(row);

      final raf = partFile.openSync(mode: FileMode.append);
      try {
        await for (final chunk in response.data!.stream) {
          if (cancelToken.isCancelled) {
            break;
          }
          raf.writeFromSync(chunk);
          receivedBytes += chunk.length;
          row.status = TransferTaskStatus.downloading;
          row.receivedBytes = receivedBytes;
          row.totalBytes = totalBytes;
          _touch(row);
        }
      } finally {
        await raf.close();
      }

      if (cancelToken.isCancelled) {
        if (_cancelRequested.remove(taskId)) {
          row.status = TransferTaskStatus.canceled;
        } else {
          _pauseRequested.remove(taskId);
          row.status = TransferTaskStatus.paused;
        }
        _touch(row);
        return;
      }

      if (File(finalPath).existsSync()) {
        await File(finalPath).delete();
      }
      await partFile.rename(finalPath);

      row.status = TransferTaskStatus.completed;
      row.receivedBytes = receivedBytes;
      row.totalBytes = totalBytes > 0 ? totalBytes : receivedBytes;
      row.localPath = finalPath;
      _touch(row);

      logInfo('download_completed: $taskId');
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        if (_cancelRequested.remove(taskId)) {
          row.status = TransferTaskStatus.canceled;
        } else {
          _pauseRequested.remove(taskId);
          row.status = TransferTaskStatus.paused;
        }
      } else {
        row.status = TransferTaskStatus.failed;
        logError('download_failed: $taskId', error: e);
      }
      _touch(row);
    } catch (e, s) {
      row.status = TransferTaskStatus.failed;
      _touch(row);
      logError('download_failed: $taskId', error: e, stackTrace: s);
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  Future<void> _deleteTaskFiles(_TransferTaskRecord task) async {
    final dir = await _getDownloadDirectory();
    final finalPath = p.join(dir.path, task.fileName);
    final partPath = '$finalPath.part';
    try {
      final finalFile = File(finalPath);
      if (await finalFile.exists()) await finalFile.delete();
    } catch (_) {}
    try {
      final partFile = File(partPath);
      if (await partFile.exists()) await partFile.delete();
    } catch (_) {}
    if (task.localPath != null) {
      try {
        final local = File(task.localPath!);
        if (await local.exists()) await local.delete();
      } catch (_) {}
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'chat_downloads'));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Cleans up old cached files (e.g. older than 30 days) to prevent filling up storage.
  /// This is similar to Telegram X's smart cache management.
  Future<void> cleanupCache({int maxDays = 30}) async {
    await _ensureInitialized();
    try {
      final dir = await _getDownloadDirectory();
      final files = dir.listSync(recursive: true);
      final cutoff = DateTime.now().subtract(Duration(days: maxDays));

      int deletedCount = 0;
      for (final entity in files) {
        if (entity is File) {
          final stat = entity.statSync();
          if (stat.accessed.isBefore(cutoff) && stat.modified.isBefore(cutoff)) {
            try {
              entity.deleteSync();
              deletedCount++;
            } catch (_) {}
          }
        }
      }
      
      if (deletedCount > 0) {
        logInfo('cleanupCache: Deleted $deletedCount old cached files.');
      }
    } catch (e, s) {
      logError('cleanupCache: Failed to cleanup cache', error: e, stackTrace: s);
    }
  }

  Future<bool> _hasConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName.trim().replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    if (cleaned.isEmpty) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    return cleaned;
  }

  void dispose() {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
    for (final watcher in _watchers.values) {
      watcher.close();
    }
    _watchers.clear();
    unawaited(_persistNow());
  }
}
