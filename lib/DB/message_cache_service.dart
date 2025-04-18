// message_cache_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/Hive Model/message_hive_model.dart';
import '../model/message_model.dart';

class MessageCacheService {
  static final MessageCacheService _instance = MessageCacheService._internal();
  factory MessageCacheService() => _instance;
  MessageCacheService._internal();

  static const String _boxName = 'messages';
  static const int CACHE_LIMIT =
      50; // محدودیت تعداد پیام‌های کش شده در هر مکالمه

  // کش حافظه برای دسترسی سریع‌تر به پیام‌ها
  final Map<String, List<MessageModel>> _memoryCache = {};

  Box<MessageHiveModel>? _box;

  Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox<MessageHiveModel>(_boxName);
  }

  // ذخیره یک پیام در کش
  Future<void> cacheMessage(MessageModel message) async {
    await initialize();

    // تبدیل به مدل Hive
    final hiveModel = MessageHiveModel.fromModel(message);

    // ساخت کلید مرکب: conversationId + messageId
    final key = '${message.conversationId}_${message.id}';

    // ذخیره در Hive
    await _box!.put(key, hiveModel);

    // بروزرسانی کش حافظه
    if (!_memoryCache.containsKey(message.conversationId)) {
      _memoryCache[message.conversationId] = [];
    }

    // حذف پیام قبلی با همین آیدی (اگر وجود داشته باشد)
    _memoryCache[message.conversationId]!
        .removeWhere((m) => m.id == message.id);

    // اضافه کردن پیام جدید به لیست (با مرتب‌سازی بر اساس زمان)
    int index = 0;
    while (index < _memoryCache[message.conversationId]!.length &&
        _memoryCache[message.conversationId]![index]
            .createdAt
            .isAfter(message.createdAt)) {
      index++;
    }

    _memoryCache[message.conversationId]!.insert(index, message);

    // حفظ محدودیت تعداد
    if (_memoryCache[message.conversationId]!.length > CACHE_LIMIT) {
      _memoryCache[message.conversationId]!.removeLast();
    }
  }

  // بروزرسانی چند پیام در یک زمان
  Future<void> cacheMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;

    for (final message in messages) {
      await cacheMessage(message);
    }
  }

  // دریافت پیام‌های یک مکالمه
  Future<List<MessageModel>> getConversationMessages(
    String conversationId, {
    int limit = 50,
    DateTime? before,
  }) async {
    await initialize();

    // بررسی کش حافظه
    if (_memoryCache.containsKey(conversationId)) {
      if (before == null) {
        // اگر 'before' مشخص نشده، آخرین پیام‌ها را برگردان (محدود به limit)
        return _memoryCache[conversationId]!.take(limit).toList();
      } else {
        // فقط پیام‌های قبل از تاریخ مشخص شده
        return _memoryCache[conversationId]!
            .where((m) => m.createdAt.isBefore(before))
            .take(limit)
            .toList();
      }
    }

    // اگر در کش حافظه نیست، از Hive بخوان
    // ابتدا تمام پیام‌های مربوط به این مکالمه را بیابیم
    final List<MessageModel> messages = [];

    // فیلتر کردن پیام‌های مربوط به این مکالمه
    for (final key in _box!.keys) {
      if (key.toString().startsWith('${conversationId}_')) {
        final hiveModel = _box!.get(key);
        if (hiveModel != null) {
          final message = hiveModel.toModel();
          if (before == null || message.createdAt.isBefore(before)) {
            messages.add(message);
          }
        }
      }
    }

    // مرتب‌سازی بر اساس زمان (جدیدترین در ابتدا)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // محدود کردن تعداد نتایج
    final result = messages.take(limit).toList();

    // ذخیره در کش حافظه
    _memoryCache[conversationId] = result;

    return result;
  }

  // دریافت یک پیام خاص
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    await initialize();

    // ابتدا از کش حافظه بررسی می‌کنیم
    if (_memoryCache.containsKey(conversationId)) {
      final cached = _memoryCache[conversationId]!.firstWhere(
        (m) => m.id == messageId,
        orElse: () => throw Exception('پیام یافت نشد'),
      );
      if (cached != null) return cached;
    }

    // اگر در کش حافظه نیست، از Hive بخوان
    final key = '${conversationId}_$messageId';
    final hiveModel = _box!.get(key);

    if (hiveModel != null) {
      return hiveModel.toModel();
    }

    return null;
  }

  // بروزرسانی وضعیت یک پیام
  Future<void> updateMessageStatus(
    String conversationId,
    String messageId, {
    bool? isRead,
    bool? isSent,
  }) async {
    await initialize();

    // دریافت پیام
    final key = '${conversationId}_$messageId';
    final hiveModel = _box!.get(key);

    if (hiveModel != null) {
      // بروزرسانی وضعیت
      if (isRead != null) hiveModel.isRead = isRead;
      if (isSent != null) hiveModel.isSent = isSent;

      // ذخیره مجدد
      await _box!.put(key, hiveModel);

      // بروزرسانی کش حافظه
      if (_memoryCache.containsKey(conversationId)) {
        final index =
            _memoryCache[conversationId]!.indexWhere((m) => m.id == messageId);
        if (index >= 0) {
          final message = _memoryCache[conversationId]![index];
          final updatedMessage = MessageModel(
            id: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            content: message.content,
            createdAt: message.createdAt,
            attachmentUrl: message.attachmentUrl,
            attachmentType: message.attachmentType,
            isRead: isRead ?? message.isRead,
            isSent: isSent ?? message.isSent,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            isMe: message.isMe,
            replyToMessageId: message.replyToMessageId,
            replyToContent: message.replyToContent,
            replyToSenderName: message.replyToSenderName,
          );
          _memoryCache[conversationId]![index] = updatedMessage;
        }
      }
    }
  }

  // جایگزینی پیام موقت با پیام واقعی (بر اساس tempId)
  Future<void> replaceTempMessage(
      String conversationId, String tempId, MessageModel realMessage) async {
    await initialize();

    // حذف پیام موقت از کش حافظه و Hive
    if (_memoryCache.containsKey(conversationId)) {
      _memoryCache[conversationId]!.removeWhere((m) => m.id == tempId);
    }
    final tempKey = '${conversationId}_$tempId';
    await _box?.delete(tempKey);

    // افزودن پیام واقعی
    await cacheMessage(realMessage);
  }

  // علامت‌گذاری پیام موقت به عنوان ارسال نشده (در صورت خطا)
  Future<void> markMessageAsFailed(String conversationId, String tempId) async {
    await initialize();
    // در کش حافظه
    if (_memoryCache.containsKey(conversationId)) {
      final idx =
          _memoryCache[conversationId]!.indexWhere((m) => m.id == tempId);
      if (idx != -1) {
        final failed =
            _memoryCache[conversationId]![idx].copyWith(isSent: false);
        _memoryCache[conversationId]![idx] = failed;
      }
    }
    // در Hive
    final tempKey = '${conversationId}_$tempId';
    final hiveModel = _box?.get(tempKey);
    if (hiveModel != null) {
      hiveModel.isSent = false;
      await _box?.put(tempKey, hiveModel);
    }
  }

  // حذف پیام‌های یک مکالمه
  Future<void> clearConversationMessages(String conversationId) async {
    await initialize();

    // حذف از کش حافظه
    _memoryCache.remove(conversationId);

    // حذف از Hive
    for (final key in _box!.keys) {
      if (key.toString().startsWith('${conversationId}_')) {
        await _box!.delete(key);
      }
    }
  }

  // حذف یک پیام خاص از کش
  Future<void> clearMessage(String conversationId, String messageId) async {
    await initialize();

    // Remove from memory cache
    if (_memoryCache.containsKey(conversationId)) {
      _memoryCache[conversationId]!.removeWhere((m) => m.id == messageId);
    }

    // Remove from Hive
    final key = '${conversationId}_$messageId';
    await _box?.delete(key);
  }

  // پاک کردن تمام کش
  Future<void> clearAllCache() async {
    await initialize();

    await _box!.clear();
    _memoryCache.clear();
  }
}
