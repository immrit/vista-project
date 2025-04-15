// conversation_cache_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/Hive Model/conversation_hive_model.dart';
import '../model/conversation_model.dart';

class ConversationCacheService {
  static final ConversationCacheService _instance =
      ConversationCacheService._internal();
  factory ConversationCacheService() => _instance;
  ConversationCacheService._internal();

  static const String _boxName = 'conversations';
  static const int CACHE_LIMIT = 10; // محدودیت تعداد مکالمات کش شده

  // کش حافظه برای دسترسی سریع‌تر
  List<ConversationModel>? _cachedConversations;

  Box<ConversationHiveModel>? _box;

  Future<void> initialize() async {
    if (_box != null) return;
    _box = await Hive.openBox<ConversationHiveModel>(_boxName);
  }

  // بازیابی مکالمات کش شده
  Future<List<ConversationModel>> getCachedConversations() async {
    await initialize();

    // اگر کش حافظه موجود است، آن را برگردان
    if (_cachedConversations != null) {
      return _cachedConversations!;
    }

    // وگرنه از Hive بخوان
    final List<ConversationModel> conversations = [];
    for (final hiveModel in _box!.values) {
      conversations.add(hiveModel.toModel());
    }

    // مرتب‌سازی بر اساس تاریخ بروزرسانی (جدیدترین در ابتدا)
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    // ذخیره در کش حافظه
    _cachedConversations = conversations;

    return conversations;
  }

  // ذخیره لیست مکالمات
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    await initialize();

    // حفظ فقط 10 مکالمه اخیر
    final recentConversations = conversations.take(CACHE_LIMIT).toList();

    // پاک کردن کش قبلی
    await _box!.clear();

    // ذخیره مکالمات جدید در Hive
    for (final conversation in recentConversations) {
      final hiveModel = ConversationHiveModel.fromModel(conversation);
      await _box!.put(conversation.id, hiveModel);
    }

    // بروزرسانی کش حافظه
    _cachedConversations = recentConversations;
  }

  // بروزرسانی یا اضافه کردن یک مکالمه به کش
  Future<void> updateConversation(ConversationModel conversation) async {
    await initialize();

    // بروزرسانی در Hive
    final hiveModel = ConversationHiveModel.fromModel(conversation);
    await _box!.put(conversation.id, hiveModel);

    // بروزرسانی کش حافظه
    if (_cachedConversations != null) {
      // حذف مکالمه قبلی با همین آیدی (اگر وجود داشته باشد)
      _cachedConversations!.removeWhere((c) => c.id == conversation.id);

      // اضافه کردن مکالمه جدید به ابتدای لیست
      _cachedConversations!.insert(0, conversation);

      // حفظ محدودیت تعداد
      if (_cachedConversations!.length > CACHE_LIMIT) {
        _cachedConversations!.removeLast();
      }
    }
  }

  // دریافت یک مکالمه از کش با آیدی
  Future<ConversationModel?> getConversation(String conversationId) async {
    await initialize();

    // اول از کش حافظه چک کن
    if (_cachedConversations != null) {
      final cached = _cachedConversations!.firstWhere(
        (c) => c.id == conversationId,
        orElse: () => throw Exception('مکالمه یافت نشد'),
      );
      if (cached != null) return cached;
    }

    // وگرنه از Hive بخوان
    final hiveModel = _box!.get(conversationId);
    if (hiveModel != null) {
      return hiveModel.toModel();
    }

    return null;
  }

  // حذف یک مکالمه از کش
  Future<void> removeConversation(String conversationId) async {
    await initialize();

    // حذف از Hive
    await _box!.delete(conversationId);

    // حذف از کش حافظه
    if (_cachedConversations != null) {
      _cachedConversations!.removeWhere((c) => c.id == conversationId);
    }
  }

  // پاک کردن تمام کش
  Future<void> clearCache() async {
    await initialize();

    await _box!.clear();
    _cachedConversations = null;
  }
}
