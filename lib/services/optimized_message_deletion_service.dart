import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:isar/isar.dart';
import '../security/logging_utility.dart';
import '../model/message_model.dart';
import '../DB/high_performance_cache_system.dart';
import '../DB/isar_database_manager.dart';
import '../DB/entities/deletion_task_entity.dart';
import 'vista_node_service.dart';

enum DeletionMode { me, everyone }

/// سرویس حذف پیام بهینه‌شده - سرور-محور
///
/// این سرویس تنها مسئول:
/// 1. حذف فوری از کش لوکال (برای UI)
/// 2. ارسال درخواست به سرور Node.js
/// 3. مدیریت صف retry برای خطاهای شبکه
///
/// ⚠️ حذف فایل از S3 کاملاً سمت سرور انجام می‌شود
class OptimizedMessageDeletionService {
  static final OptimizedMessageDeletionService _instance =
      OptimizedMessageDeletionService._internal();

  factory OptimizedMessageDeletionService() => _instance;

  OptimizedMessageDeletionService._internal();

  final HighPerformanceCacheSystem _cacheSystem = HighPerformanceCacheSystem();
  final SupabaseClient _supabase = Supabase.instance.client;
  Isar? _isar;

  bool _isProcessing = false;
  Timer? _retryTimer;

  /// مقداردهی اولیه
  Future<void> initialize() async {
    try {
      _isar = await IsarDatabaseManager().instance;
      // بررسی تسک‌های باقی‌مانده
      final count = await _isar!.deletionTaskEntitys.count();
      if (count > 0) {
        logInfo('🔄 Resuming $count pending deletions from Isar...');
        _startProcessingLoop();
      }
    } catch (e) {
      logError('Error initializing OptimizedMessageDeletionService', error: e);
    }
  }

  /// Dispose service
  void dispose() {
    _retryTimer?.cancel();
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
      logInfo('🗑️ Queuing deletion. ID: ${msg.id}, Mode: ${mode.name}');

      // ایجاد تسک (بدون s3Key - سرور خودش key را استخراج می‌کند)
      final task = DeletionTaskEntity()
        ..messageId = msg.id
        ..conversationId = conversationId
        ..deletionMode = mode.index
        ..s3Key = null // ⚠️ دیگر نیازی نیست - سرور استخراج می‌کند
        ..retryCount = 0
        ..nextAttempt = now
        ..timestamp = now;

      tasks.add(task);
    }

    // 2. ذخیره در Isar
    try {
      await _isar!.writeTxn(() async {
        // حذف تسک‌های قبلی برای این پیام‌ها
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
      // دریافت تسک‌های آماده (محدود به 5 تا)
      final tasks = await _isar!.deletionTaskEntitys
          .filter()
          .nextAttemptLessThan(now + 1)
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
    final mode = DeletionMode.values[task.deletionMode];
    final conversationId = task.conversationId;

    try {
      if (mode == DeletionMode.everyone) {
        // ─── حذف برای همه: ارسال به سرور Node.js ───
        // سرور خودش فایل S3 و رکورد DB را حذف می‌کند
        logInfo('🌐 Sending delete request to server: $messageId');
        await VistaNodeService.deleteMessage(messageId);
        logInfo('✅ Server deletion complete for: $messageId');
      } else {
        // ─── حذف فقط برای من: ذخیره در hidden_messages ───
        await _hideMessageForCurrentUser(messageId, conversationId);
        logInfo('✅ Message hidden for current user: $messageId');
      }

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

  /// ذخیره پیام در جدول hidden_messages (حذف یک‌طرفه)
  Future<void> _hideMessageForCurrentUser(
      String messageId, String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase.from('hidden_messages').upsert({
      'user_id': userId,
      'message_id': messageId,
      'conversation_id': conversationId,
      'hidden_at': DateTime.now().toIso8601String(),
    });
  }
}
