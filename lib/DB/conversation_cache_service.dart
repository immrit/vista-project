// conversation_cache_service.dart
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../model/Hive Model/conversation_hive_model.dart';
import '../model/conversation_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:developer';

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
    try {
      _box = await Hive.openBox<ConversationHiveModel>(_boxName);
      log('[Hive] Conversation box opened successfully');
    } catch (e, st) {
      log('[Hive] Error opening conversation box: $e', stackTrace: st);
      rethrow;
    }
  }

  // بازیابی مکالمات کش شده
  Future<List<ConversationModel>> getCachedConversations() async {
    await initialize();

    try {
      if (_cachedConversations != null) {
        log('[Hive] Returning cached conversations from memory: ${_cachedConversations!.length}');
        return _cachedConversations!;
      }

      final List<ConversationModel> conversations = [];
      for (final hiveModel in _box!.values) {
        try {
          conversations.add(hiveModel.toModel());
        } catch (e, st) {
          log('[Hive] Error converting HiveModel to ConversationModel: $e',
              stackTrace: st);
        }
      }

      conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _cachedConversations = conversations;
      log('[Hive] Loaded ${conversations.length} conversations from Hive');
      return conversations;
    } catch (e, st) {
      log('[Hive] Error in getCachedConversations: $e', stackTrace: st);
      rethrow;
    }
  }

  // ذخیره لیست مکالمات
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    await initialize();
    try {
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
      log('[Hive] Cached ${recentConversations.length} conversations');
    } catch (e, st) {
      log('[Hive] Error in cacheConversations: $e', stackTrace: st);
      rethrow;
    }
  }

  // بروزرسانی یا اضافه کردن یک مکالمه به کش
  Future<void> updateConversation(ConversationModel conversation) async {
    await initialize();
    try {
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
      log('[Hive] Updated conversation: ${conversation.id}');
    } catch (e, st) {
      log('[Hive] Error in updateConversation: $e', stackTrace: st);
      rethrow;
    }
  }

  // دریافت یک مکالمه از کش با آیدی
  Future<ConversationModel?> getConversation(String conversationId) async {
    await initialize();
    try {
      // اول از کش حافظه چک کن
      if (_cachedConversations != null) {
        final cached = _cachedConversations!.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => null as ConversationModel, // رفع خطای نوع
        );
        if (cached != null) return cached;
      }

      // وگرنه از Hive بخوان
      final hiveModel = _box!.get(conversationId);
      if (hiveModel != null) {
        return hiveModel.toModel();
      }
      return null;
    } catch (e, st) {
      log('[Hive] Error in getConversation: $e', stackTrace: st);
      return null;
    }
  }

  /// متد سینک برای گرفتن مکالمه از کش حافظه یا Hive (بدون async)
  ConversationModel? getConversationSync(String conversationId) {
    try {
      // ابتدا از کش حافظه (لیست مکالمات کش شده)
      if (_cachedConversations != null) {
        final cached = _cachedConversations!.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => null as ConversationModel, // رفع خطای نوع
        );
        if (cached != null) return cached;
      }
      // اگر در کش نبود، از Hive بخوان
      if (_box != null && _box!.isOpen) {
        final hiveModel = _box!.get(conversationId);
        if (hiveModel != null) {
          return hiveModel.toModel();
        }
      }
      return null;
    } catch (e, st) {
      log('[Hive] Error in getConversationSync: $e', stackTrace: st);
      return null;
    }
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
