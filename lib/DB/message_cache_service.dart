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

  // بهبود مدیریت کش برای عملکرد بهتر
  static const int MAX_CACHE_AGE_HOURS = 24;
  static const int MAX_MESSAGES_PER_CONVERSATION = 100;

  // کش حافظه برای دسترسی سریع‌تر به پیام‌ها
  final Map<String, List<MessageModel>> _memoryCache = {};

  // کش تاریخ‌های پیام هر مکالمه (date dividers) در حافظه
  final Map<String, List<DateTime>> _dateDividersCache = {};

  Box<MessageHiveModel>? _box;

  // Box برای ذخیره تاریخ‌ها در Hive
  Box<List>? _dateBox;

  Future<void> initialize() async {
    if (_box != null && _dateBox != null) return;
    _box ??= await Hive.openBox<MessageHiveModel>(_boxName);
    _dateBox ??= await Hive.openBox<List>('message_dates');
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

    // بعد از اضافه کردن پیام، تاریخ‌های جدید را بروزرسانی کن (سریع و فقط اگر لازم بود)
    final dateKey =
        '${message.createdAt.year}-${message.createdAt.month}-${message.createdAt.day}';
    final cachedDates = _dateDividersCache[message.conversationId] ?? [];
    if (!cachedDates.any((d) =>
        d.year == message.createdAt.year &&
        d.month == message.createdAt.month &&
        d.day == message.createdAt.day)) {
      _dateDividersCache[message.conversationId] = [
        ...cachedDates,
        DateTime(message.createdAt.year, message.createdAt.month,
            message.createdAt.day)
      ];
    }
  }

  // بروزرسانی چند پیام در یک زمان
  Future<void> cacheMessages(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    await initialize();

    // پیام‌های جدید را بر اساس conversationId گروه‌بندی کن
    final Map<String, List<MessageModel>> grouped = {};
    for (final message in messages) {
      grouped.putIfAbsent(message.conversationId, () => []).add(message);
    }

    for (final entry in grouped.entries) {
      final conversationId = entry.key;
      final newMessages = entry.value;

      // حذف پیام‌های temp که پیام واقعی‌شان آمده
      if (_memoryCache.containsKey(conversationId)) {
        final tempIds = newMessages
            .map((m) => m.id)
            .where((id) => id.startsWith('temp_'))
            .toSet();
        _memoryCache[conversationId]!
            .removeWhere((m) => tempIds.contains(m.id));
      }

      // حذف پیام temp با همان id پیام واقعی
      for (final msg in newMessages) {
        await replaceTempIfExists(msg.conversationId, msg.id, msg);
      }

      // اضافه یا جایگزین کردن پیام‌ها
      for (final message in newMessages) {
        await cacheMessage(message);
      }

      // بعد از اضافه کردن پیام‌ها، تاریخ‌های جدید را بروزرسانی کن
      if (_memoryCache.containsKey(conversationId)) {
        await _updateDateDividers(
            conversationId, _memoryCache[conversationId]!);
      }
    }
  }

  // اگر پیام temp با همین id وجود داشت، حذف و پیام واقعی را جایگزین کن
  Future<void> replaceTempIfExists(
      String conversationId, String messageId, MessageModel realMessage) async {
    await initialize();
    // حذف از کش حافظه
    if (_memoryCache.containsKey(conversationId)) {
      _memoryCache[conversationId]!
          .removeWhere((m) => m.id == messageId && m.id.startsWith('temp_'));
    }
    // حذف از Hive
    final tempKey = '${conversationId}_$messageId';
    await _box?.delete(tempKey);
    // پیام واقعی را اضافه کن
    await cacheMessage(realMessage);
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

    // هنگام پاکسازی پیام‌های یک مکالمه، کش تاریخ را هم پاک کن
    _dateDividersCache.remove(conversationId);
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

    // هنگام پاکسازی کل کش، کش تاریخ را هم پاک کن
    _dateDividersCache.clear();
  }

  // گرفتن لیست تاریخ‌های پیام (date divider) برای یک مکالمه
  List<DateTime> getDateDividers(String conversationId) {
    // اول از کش حافظه
    if (_dateDividersCache.containsKey(conversationId)) {
      return _dateDividersCache[conversationId]!;
    }
    // اگر در کش حافظه نبود، از Hive پیام‌ها را بخوان و تاریخ‌ها را استخراج کن
    final box = _box;
    if (box == null) return [];
    final datesSet = <String>{};
    for (final key in box.keys) {
      if (key.toString().startsWith('${conversationId}_')) {
        final hiveModel = box.get(key);
        if (hiveModel != null) {
          final date = hiveModel.createdAt;
          final dateKey = '${date.year}-${date.month}-${date.day}';
          datesSet.add(dateKey);
        }
      }
    }
    // تبدیل به لیست DateTime و مرتب‌سازی
    final dates = datesSet.map((s) {
      final parts = s.split('-');
      return DateTime(
          int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toList()
      ..sort((a, b) => b.compareTo(a)); // جدیدترین بالا
    _dateDividersCache[conversationId] = dates;
    return dates;
  }

  // ذخیره تاریخ‌های جدید برای یک مکالمه (در حافظه و Hive)
  Future<void> _updateDateDividers(
      String conversationId, List<MessageModel> messages) async {
    await initialize();
    final dates = <DateTime>[];
    DateTime? lastDate;
    // پیام‌ها باید بر اساس زمان صعودی مرتب شوند تا تاریخ‌ها درست استخراج شوند
    final sorted = List<MessageModel>.from(messages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final msg in sorted) {
      final msgDate =
          DateTime(msg.createdAt.year, msg.createdAt.month, msg.createdAt.day);
      if (lastDate == null || !msgDate.isAtSameMomentAs(lastDate)) {
        dates.add(msgDate);
        lastDate = msgDate;
      }
    }
    _dateDividersCache[conversationId] = dates;
    // ذخیره در Hive (به صورت لیست String)
    await _dateBox?.put(
        conversationId, dates.map((d) => d.toIso8601String()).toList());
  }

  // افزودن متد جدید برای همگام‌سازی هوشمند با سرور
  Future<void> smartSync(
      String conversationId, List<MessageModel> serverMessages) async {
    await initialize();

    // حذف پیام‌های قدیمی از کش
    await _cleanOldCache();

    // دریافت پیام‌های موقت
    final cachedMessages = await getConversationMessages(conversationId);
    final tempMessages =
        cachedMessages.where((m) => m.id.startsWith('temp_')).toList();

    // حذف پیام‌های غیر موقت فعلی
    for (final key in _box!.keys) {
      if (key.toString().startsWith('${conversationId}_') &&
          !key.toString().contains('temp_')) {
        await _box!.delete(key);
      }
    }

    // اضافه کردن پیام‌های جدید سرور
    await cacheMessages(serverMessages);

    // بازگرداندن پیام‌های موقت
    await cacheMessages(tempMessages);

    // بروزرسانی کش حافظه
    _memoryCache[conversationId] = [...serverMessages, ...tempMessages]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // محدود کردن تعداد پیام‌های کش شده
    if (_memoryCache[conversationId]!.length > MAX_MESSAGES_PER_CONVERSATION) {
      _memoryCache[conversationId] = _memoryCache[conversationId]!
          .take(MAX_MESSAGES_PER_CONVERSATION)
          .toList();
    }
  }

  Future<void> _cleanOldCache() async {
    final now = DateTime.now();
    final keys = _box!.keys.toList();

    for (final key in keys) {
      final message = _box!.get(key);
      if (message != null) {
        final messageAge = now.difference(message.createdAt);
        if (messageAge.inHours > MAX_CACHE_AGE_HOURS) {
          await _box!.delete(key);
        }
      }
    }
  }
}
