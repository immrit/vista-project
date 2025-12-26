import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:isar/isar.dart';
import '../security/logging_utility.dart';
import '../model/message_model.dart';
import '../DB/high_performance_cache_system.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/deletion_task_entity.dart';
import 'secure_config.dart';

enum DeletionMode { me, everyone }

class OptimizedMessageDeletionService {
  static final OptimizedMessageDeletionService _instance =
      OptimizedMessageDeletionService._internal();

  factory OptimizedMessageDeletionService() => _instance;

  OptimizedMessageDeletionService._internal();

  final HighPerformanceCacheSystem _cacheSystem = HighPerformanceCacheSystem();
  final SupabaseClient _supabase = Supabase.instance.client;
  Isar? _isar;

  // ⚠️ نام باکت دقیقا طبق گفته شما
  static const String _bucketName = 'coffevista';

  bool _isProcessing = false;
  Timer? _retryTimer;

  // تنظیمات کلاینت S3
  static S3 get _s3 {
    if (!SecureConfig.isConfigured) {
      logError('AWS Config Missing!');
      throw Exception('AWS credentials not configured');
    }
    return S3(
      region: SecureConfig.awsRegion,
      credentials: AwsClientCredentials(
        accessKey: SecureConfig.awsAccessKey,
        secretKey: SecureConfig.awsSecretKey,
      ),
      endpointUrl: SecureConfig.awsEndpointUrl,
    );
  }

  /// مقداردهی اولیه
  Future<void> initialize() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      // بررسی تسک‌های باقی‌مانده
      final count = await _isar!.deletionTaskEntitys.count();
      if (count > 0) {
        logInfo('🔄 Resuming $count pending deletions form Isar...');
        _startProcessingLoop();
      }
    } catch (e) {
      logError('Error initializing OptimizedMessageDeletionService', error: e);
    }
  }

  /// Dispose service
  void dispose() {
    _retryTimer?.cancel();
    // _isar?.close(); Isar usually stays open
    logInfo('🧹 OptimizedMessageDeletionService disposed');
  }

  /// متد عمومی حذف (فراخوانی از UI)
  Future<void> deleteMessages({
    required List<MessageModel> messages,
    required String conversationId,
    required DeletionMode mode,
  }) async {
    if (messages.isEmpty) return;

    // 1. حذف فوری از کش لوکال (UI بلافاصله تمیز می‌شود)
    await _purgeFromLocalCache(
        messages.map((e) => e.id).toList(), conversationId);

    if (_isar == null) await initialize();
    if (_isar == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final tasks = <DeletionTaskEntity>[];

    for (var msg in messages) {
      final s3Key = _extractS3KeyCorrectly(msg);

      // لاگ
      if (s3Key != null) {
        logInfo('🗑️ Queuing deletion. ID: ${msg.id}, Key: [$s3Key]');
      }

      // ایجاد تسک
      final task = DeletionTaskEntity()
        ..messageId = msg.id
        ..conversationId = conversationId
        ..deletionMode = mode.index
        ..s3Key = s3Key
        ..retryCount = 0
        ..nextAttempt = now
        ..timestamp = now;

      tasks.add(task);
    }

    // 3. ذخیره در Isar
    try {
      await _isar!.writeTxn(() async {
        // ابتدا تسک‌های قبلی برای این پیام‌ها را پاک کن تا تکراری نشود (اگر لازم است)
        // اما چون ID پیام یکتا است، شاید Isar خودش هندل نکند مگر ID Isar یکی باشد.
        // اینجا messageId داریم.
        // بهتر است چک کنیم if exists update or delete old.
        // ساده: put اضافه می‌کند (autoIncrement id).
        // پس بهتر است کوئری بزنیم و پاک کنیم اگر تکراری است.
        final msgIds = messages.map((e) => e.id).toList();
        await _isar!.deletionTaskEntitys
            .filter()
            .anyOf(msgIds, (q, String id) => q.messageIdEqualTo(id))
            .deleteAll();

        await _isar!.deletionTaskEntitys.putAll(tasks);
      });
      _startProcessingLoop();
    } catch (e) {
      logError('Failed to queue deletion tasks', error: e);
    }
  }

  // --- Compatibility Wrappers ---

  Future<void> deleteMultipleMessages({
    required List<MessageModel> messages,
    required String conversationId,
    required DeletionMode mode,
  }) async {
    await deleteMessages(
        messages: messages, conversationId: conversationId, mode: mode);
  }

  Future<void> deleteMessage({
    required String messageId,
    required String conversationId,
    DeletionMode mode = DeletionMode.me,
    bool optimisticDelete = true,
    MessageModel? message,
  }) async {
    final msg = message ??
        MessageModel(
            id: messageId,
            conversationId: conversationId,
            senderId: '',
            content: '',
            isMe: true,
            createdAt: DateTime.now());
    await deleteMessages(
        messages: [msg], conversationId: conversationId, mode: mode);
  }

  Future<void> clearConversationMessages({
    required String conversationId,
    DeletionMode mode = DeletionMode.me,
  }) async {
    try {
      final cachedMessages = _cacheSystem.getCachedMessages(conversationId);
      if (cachedMessages.isEmpty) return;
      await deleteMessages(
          messages: cachedMessages, conversationId: conversationId, mode: mode);
    } catch (e) {
      logError('Error clearing conversation: $e');
    }
  }

  Future<void> _purgeFromLocalCache(
      List<String> ids, String conversationId) async {
    try {
      for (var id in ids) {
        await _cacheSystem.deleteMessageFromCache(conversationId, id);
      }
    } catch (e) {
      // Ignored
    }
  }

  void _startProcessingLoop() {
    if (_isProcessing) return;
    _retryTimer?.cancel();
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isar == null) await initialize();
    if (_isar == null) return;
    if (_isProcessing) return;

    _isProcessing = true;
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      // دریافت تسک‌های آماده
      // محدودیت 5 تایی
      final tasks = await _isar!.deletionTaskEntitys
          .filter()
          .nextAttemptLessThan(now + 1) // +1 for strict inequality safety
          .sortByNextAttempt()
          .limit(5)
          .findAll();

      if (tasks.isEmpty) {
        _scheduleNextRun();
        _isProcessing = false;
        return;
      }

      await Future.wait(tasks.map((task) async {
        final success = await _executeSingleTask(task);
        await _isar!.writeTxn(() async {
          if (success) {
            await _isar!.deletionTaskEntitys.delete(task.id);
          } else {
            // آپدیت برای تلاش بعدی
            await _isar!.deletionTaskEntitys.put(task);
          }
        });
      }));

      // اگر هنوز تسکی هست، دوباره اجرا کن
      _scheduleNextRun();
    } catch (e) {
      logError('Error in processing queue', error: e);
    } finally {
      _isProcessing = false;
    }
  }

  Future<bool> _executeSingleTask(DeletionTaskEntity task) async {
    final messageId = task.messageId;
    final s3Key = task.s3Key;
    final mode = DeletionMode.values[task.deletionMode];
    final conversationId = task.conversationId;

    try {
      // 1. حذف فایل دیتابیس
      // منطق اصلی: اول فایل AWS، بعد DB.
      if (s3Key != null && s3Key.isNotEmpty) {
        await _deleteS3File(s3Key, mode, messageId);
      }

      // 2. حذف از سوپابیس
      await _deleteFromDatabase(messageId, conversationId, mode);

      logInfo('✅ Full deletion complete for: $messageId');
      return true;
    } catch (e) {
      int retries = task.retryCount + 1;
      // Exponential Backoff
      int delaySec = 5 * (1 << (retries > 10 ? 10 : retries));
      if (delaySec > 3600) delaySec = 3600;

      logError('❌ Deletion failed for $messageId. Retrying in ${delaySec}s',
          error: e);

      task.retryCount = retries;
      task.nextAttempt =
          DateTime.now().millisecondsSinceEpoch + (delaySec * 1000);

      return false;
    }
  }

  Future<void> _scheduleNextRun() async {
    if (_isar == null) return;
    final count = await _isar!.deletionTaskEntitys.count();
    if (count == 0) return;

    // پیدا کردن نزدیک‌ترین زمان اجرا
    final nextTask = await _isar!.deletionTaskEntitys
        .where()
        .sortByNextAttempt()
        .findFirst();

    if (nextTask == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    int delay = nextTask.nextAttempt - now;
    if (delay < 1000) delay = 1000; // Minimal delay

    _retryTimer = Timer(Duration(milliseconds: delay), _processQueue);
  }

  // --- Helpers (Same as before) ---

  String? _extractS3KeyCorrectly(MessageModel message) {
    String? url = message.audioUrl;
    if (url == null || url.isEmpty) {
      url = message.attachmentUrl;
    }
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;

      if (url.contains('storage.389346.ir.cdn.ir')) {
        if (segments.length > 1) {
          final key = segments.sublist(1).join('/');
          return Uri.decodeFull(key);
        }
        return null;
      }

      if (segments.first == _bucketName && segments.length > 1) {
        final key = segments.skip(1).join('/');
        return Uri.decodeFull(key);
      }

      final key = segments.join('/');
      return Uri.decodeFull(key);
    } catch (e) {
      logError('Key extraction error for: $url', error: e);
      return null;
    }
  }

  Future<void> _deleteS3File(
      String key, DeletionMode mode, String messageId) async {
    if (mode == DeletionMode.me) {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final otherDeletion = await _supabase
          .from('deleted_messages')
          .select('message_id')
          .eq('message_id', messageId)
          .neq('user_id', currentUserId)
          .maybeSingle();

      if (otherDeletion == null) {
        logInfo('ℹ️ Keeping file (Other user has msg). Key: $key');
        return;
      }
    }

    try {
      await _s3.deleteObject(bucket: _bucketName, key: key);
      logInfo('✅ S3 Delete successful: $key');
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('NoSuchKey')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _deleteFromDatabase(
      String messageId, String conversationId, DeletionMode mode) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (mode == DeletionMode.everyone) {
      await _supabase.from('messages').delete().eq('id', messageId);
      try {
        await _supabase
            .from('deleted_messages')
            .delete()
            .eq('message_id', messageId);
      } catch (_) {}
    } else {
      await _supabase.from('deleted_messages').upsert({
        'user_id': userId,
        'message_id': messageId,
        'conversation_id': conversationId,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    }
  }
}
