import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../security/logging_utility.dart';
import '../model/message_model.dart';
import '../DB/advanced_cache_system.dart';
import 'secure_config.dart';

enum DeletionMode { me, everyone }

class OptimizedMessageDeletionService {
  static final OptimizedMessageDeletionService _instance =
      OptimizedMessageDeletionService._internal();

  factory OptimizedMessageDeletionService() => _instance;

  OptimizedMessageDeletionService._internal();

  final AdvancedCacheSystem _cacheSystem = AdvancedCacheSystem();
  final SupabaseClient _supabase = Supabase.instance.client;

  // ⚠️ کلید ذخیره‌سازی صف (ورژن جدید برای جلوگیری از تداخل با قبلی)
  static const String _storageKey = 'queue_v4_strict_key_extraction';

  // ⚠️ نام باکت دقیقا طبق گفته شما
  static const String _bucketName = 'coffevista';

  List<Map<String, dynamic>> _pendingTasks = [];
  bool _isProcessing = false;
  Timer? _retryTimer;

  // تنظیمات کلاینت S3
  static S3 get _s3 {
    if (!SecureConfig.isConfigured) {
      // در محیط توسعه برای جلوگیری از کرش
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
    await _loadQueueFromDisk();
    if (_pendingTasks.isNotEmpty) {
      logInfo('🔄 Resuming ${_pendingTasks.length} pending deletions...');
      _startProcessingLoop();
    }
  }

  /// Dispose service
  void dispose() {
    _retryTimer?.cancel();
    _pendingTasks.clear(); // پاک کردن حافظه موقت (نه دیسک)
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

    // 2. آماده‌سازی تسک‌ها برای صف
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var msg in messages) {
      // استخراج کلید فایل در همین لحظه (چون دسترسی به آبجکت داریم)
      final s3Key = _extractS3KeyCorrectly(msg);

      // لاگ برای اطمینان از صحت کلید استخراج شده
      if (s3Key != null) {
        final urlUsed = msg.audioUrl ?? msg.attachmentUrl ?? 'N/A';
        final urlType = msg.audioUrl != null ? 'audio_url' : 'attachment_url';
        logInfo('🗑️ Queuing file deletion. MessageId: ${msg.id}, Type: ${msg.attachmentType}, Key: [$s3Key], $urlType: $urlUsed');
      } else {
        if (msg.audioUrl != null && msg.audioUrl!.isNotEmpty) {
          logInfo('⚠️ Could not extract S3 key from audio_url. MessageId: ${msg.id}, URL: ${msg.audioUrl}');
        } else if (msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty) {
          logInfo('⚠️ Could not extract S3 key from attachment_url. MessageId: ${msg.id}, URL: ${msg.attachmentUrl}, Type: ${msg.attachmentType}');
        }
      }

      final task = {
        'id': msg.id,
        'conversationId': conversationId,
        'mode': mode.index,
        's3Key': s3Key, // اگر null باشد یعنی فایل ندارد یا لینک معتبر نیست
        'retryCount': 0,
        'nextAttempt': now, // اولین تلاش: همین الان
        'timestamp': now,
      };

      // حذف تکراری‌ها و افزودن به صف
      _pendingTasks.removeWhere((t) => t['id'] == msg.id);
      _pendingTasks.add(task);
    }

    // 3. ذخیره و شروع
    await _saveQueueToDisk();
    _startProcessingLoop();
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

  // -----------------------------

  /// حذف از کش دیتابیس لوکال
  Future<void> _purgeFromLocalCache(
      List<String> ids, String conversationId) async {
    try {
      for (var id in ids) {
        await _cacheSystem.deleteMessageFromCache(conversationId, id);
      }
    } catch (e) {
      // خطا در اینجا نباید مانع ادامه شود
    }
  }

  void _startProcessingLoop() {
    if (_isProcessing) return;
    _retryTimer?.cancel();
    _processQueue();
  }

  /// موتور پردازش صف
  Future<void> _processQueue() async {
    if (_pendingTasks.isEmpty) {
      _isProcessing = false;
      return;
    }

    _isProcessing = true;
    bool queueModified = false;
    final now = DateTime.now().millisecondsSinceEpoch;

    // انتخاب تسک‌های آماده اجرا
    final tasksToRun = _pendingTasks.where((task) {
      final nextAttempt = task['nextAttempt'] as int;
      return now >= nextAttempt;
    }).toList();

    if (tasksToRun.isEmpty) {
      _scheduleNextRun();
      _isProcessing = false;
      return;
    }

    // پردازش 3 تایی برای جلوگیری از فشار زیاد
    int concurrencyLimit = 3;

    for (var i = 0; i < tasksToRun.length; i += concurrencyLimit) {
      final end = (i + concurrencyLimit < tasksToRun.length)
          ? i + concurrencyLimit
          : tasksToRun.length;
      final batch = tasksToRun.sublist(i, end);

      await Future.wait(batch.map((task) async {
        final success = await _executeSingleTask(task);
        if (success) {
          _pendingTasks.remove(task);
          queueModified = true;
        } else {
          // تسک در صف می‌ماند اما زمان اجرای بعدی‌اش تغییر کرده
          queueModified = true;
        }
      }));
    }

    if (queueModified) {
      await _saveQueueToDisk();
    }

    _scheduleNextRun();
    _isProcessing = false;
  }

  /// اجرای یک تسک تکی (حذف فایل + دیتابیس)
  Future<bool> _executeSingleTask(Map<String, dynamic> task) async {
    final messageId = task['id'] as String;
    final s3Key = task['s3Key'] as String?;
    final mode = DeletionMode.values[task['mode'] as int];
    final conversationId = task['conversationId'] as String;

    try {
      // 1. حذف فایل از آروان (اگر وجود دارد)
      if (s3Key != null && s3Key.isNotEmpty) {
        await _deleteS3File(s3Key, mode, messageId);
      }

      // 2. حذف از دیتابیس (فقط اگر حذف فایل موفق بود یا اصلا فایل نداشت)
      await _deleteFromDatabase(messageId, conversationId, mode);

      logInfo('✅ Full deletion complete for: $messageId');
      return true;
    } catch (e) {
      // مدیریت خطا و زمان‌بندی مجدد (Exponential Backoff)
      int retries = (task['retryCount'] as int) + 1;

      // 5s, 10s, 20s, 40s, 80s... تا ماکسیمم 1 ساعت
      int delaySec = 5 * (1 << (retries > 10 ? 10 : retries));
      if (delaySec > 3600) delaySec = 3600;

      logError('❌ Deletion failed for $messageId. Retrying in ${delaySec}s',
          error: e);

      task['retryCount'] = retries;
      task['nextAttempt'] =
          DateTime.now().millisecondsSinceEpoch + (delaySec * 1000);

      return false;
    }
  }

  /// حذف فایل از S3
  /// برای حذف دوطرفه (forEveryone): همیشه فایل را حذف می‌کند
  /// برای حذف یکطرفه (forMe): فقط اگر طرف مقابل هم حذف کرده باشد، فایل را حذف می‌کند
  Future<void> _deleteS3File(
      String key, DeletionMode mode, String messageId) async {
    // در حالت "برای خودم"، باید چک کنیم آیا نفر مقابل فایل را لازم دارد؟
    if (mode == DeletionMode.me) {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        logInfo('⚠️ User not logged in, skipping file deletion. Key: $key');
        return; // کاربر لاگین نیست، نمی‌توانیم چک کنیم
      }

      final otherDeletion = await _supabase
          .from('deleted_messages')
          .select('message_id')
          .eq('message_id', messageId)
          .neq('user_id', currentUserId)
          .maybeSingle();

      if (otherDeletion == null) {
        logInfo('ℹ️ Keeping file (Other user still has message). Key: $key');
        return; // فایل را پاک نمی‌کنیم چون طرف مقابل هنوز پیام را دارد
      }
      logInfo('✅ Both users deleted message, proceeding with file deletion. Key: $key');
    } else {
      // حذف دوطرفه: همیشه فایل را حذف می‌کنیم
      logInfo('🗑️ Bidirectional deletion (forEveryone), deleting file. Key: $key');
    }

    try {
      logInfo('🚀 Sending S3 Delete Request. Bucket: $_bucketName, Key: $key');

      await _s3.deleteObject(
        bucket: _bucketName,
        key: key,
      );

      logInfo('✅ S3 Delete successful. Bucket: $_bucketName, Key: $key');
    } catch (e) {
      // اگر فایل پیدا نشد (404)، یعنی قبلاً پاک شده و موفقیت محسوب می‌شود
      if (e.toString().contains('404') || e.toString().contains('NoSuchKey')) {
        logInfo('⚠️ File not found (404), assumed deleted. Key: $key');
        return;
      }
      // بقیه خطاها (مثل قطعی نت) باید پرتاب شوند تا Retry شوند
      logError('❌ S3 Delete failed. Bucket: $_bucketName, Key: $key', error: e);
      throw e;
    }
  }

  /// حذف از دیتابیس سوپابیس
  Future<void> _deleteFromDatabase(
      String messageId, String conversationId, DeletionMode mode) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (mode == DeletionMode.everyone) {
      // Hard Delete
      await _supabase.from('messages').delete().eq('id', messageId);
      // Clean cleanup (optional)
      try {
        await _supabase
            .from('deleted_messages')
            .delete()
            .eq('message_id', messageId);
      } catch (_) {}
    } else {
      // Soft Delete
      await _supabase.from('deleted_messages').upsert({
        'user_id': userId,
        'message_id': messageId,
        'conversation_id': conversationId,
        'deleted_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔑 KEY EXTRACTION LOGIC (THE FIX)
  // ═══════════════════════════════════════════════════════════════════════════

  /// استخراج دقیق کلید فایل برای S3
  /// این متد هم audio_url (برای ویس‌ها) و هم attachment_url را بررسی می‌کند
  /// پشتیبانی از فرمت‌های مختلف URL آروان:
  /// - https://storage.389346.ir.cdn.ir/bucketName/path/to/file
  /// - https://coffevista.s3.ir-thr-at1.arvanstorage.ir/path/to/file
  String? _extractS3KeyCorrectly(MessageModel message) {
    // ✅ اولویت با audio_url برای ویس‌ها، سپس attachment_url
    String? url = message.audioUrl;
    if (url == null || url.isEmpty) {
      url = message.attachmentUrl;
    }
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      if (segments.isEmpty) return null;

      // فرمت 1: https://storage.389346.ir.cdn.ir/bucketName/path/to/file
      // در این فرمت، اولین segment نام باکت است و باید حذف شود
      if (url.contains('storage.389346.ir.cdn.ir')) {
        if (segments.length > 1) {
          // حذف اولین segment (نام باکت) و بازگرداندن بقیه
          final key = segments.sublist(1).join('/');
          // دیکد کردن URL برای کاراکترهای خاص و فارسی
          return Uri.decodeFull(key);
        }
        return null;
      }

      // فرمت 2: https://coffevista.s3.ir-thr-at1.arvanstorage.ir/path/to/file
      // یا https://domain/coffevista/chats/img.jpg
      // اگر اولین قسمت مسیر، نام باکت باشد، باید حذف شود
      if (segments.first == _bucketName && segments.length > 1) {
        // بازگرداندن بقیه مسیر به عنوان کلید
        final key = segments.skip(1).join('/');
        return Uri.decodeFull(key);
      }

      // در غیر این صورت، کل مسیر کلید است (اگر باکت در URL نیست)
      final key = segments.join('/');
      return Uri.decodeFull(key);
    } catch (e) {
      logError('Key extraction error for: $url', error: e);
      return null;
    }
  }

  void _scheduleNextRun() {
    if (_pendingTasks.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    int minTime = _pendingTasks
        .map((t) => t['nextAttempt'] as int)
        .reduce((a, b) => a < b ? a : b);

    int delay = minTime - now;
    if (delay < 1000) delay = 1000;

    _retryTimer = Timer(Duration(milliseconds: delay), _processQueue);
  }

  // 💾 توابع ذخیره‌سازی
  Future<void> _loadQueueFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> decoded = json.decode(jsonString);
        _pendingTasks = decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      _pendingTasks = [];
      logError('Failed to load queue from disk', error: e);
    }
  }

  Future<void> _saveQueueToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = json.encode(_pendingTasks);
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // خطا در ذخیره‌سازی نباید مانع کار شود
      logError('Failed to save queue to disk', error: e);
    }
  }
}
