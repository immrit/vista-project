import 'dart:async';
import 'package:flutter/foundation.dart';
import '../model/message_model.dart';
import '../DB/unified_message_cache_service.dart';

class BackgroundMessageLoader {
  static final BackgroundMessageLoader _instance = BackgroundMessageLoader._internal();
  factory BackgroundMessageLoader() => _instance;
  BackgroundMessageLoader._internal();

  // صف بارگذاری
  final Map<String, Completer<List<MessageModel>>> _loadingQueue = {};

  /// بارگذاری پیام‌ها در background
  Future<List<MessageModel>> loadMessagesInBackground({
    required String conversationId,
    required String userId,
    int limit = 30,
    int offset = 0,
  }) async {
    // اگر در حال بارگذاری است، همان completer را برگردان
    if (_loadingQueue.containsKey(conversationId)) {
      return _loadingQueue[conversationId]!.future;
    }

    final completer = Completer<List<MessageModel>>();
    _loadingQueue[conversationId] = completer;

    try {
      // ✅ اجرا در Isolate جداگانه (فقط برای عملیات سنگین)
      final messages = await compute(
        _loadMessagesInIsolate,
        _LoadMessagesParams(
          conversationId: conversationId,
          userId: userId,
          limit: limit,
          offset: offset,
        ),
      );

      completer.complete(messages);
      return messages;
    } catch (e) {
      print('❌ Background loading error: $e');
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingQueue.remove(conversationId);
    }
  }

  /// اجرای بارگذاری در Isolate
  static Future<List<MessageModel>> _loadMessagesInIsolate(
    _LoadMessagesParams params,
  ) async {
    // این تابع در Isolate جداگانه اجرا می‌شود
    try {
      final cacheService = UnifiedMessageCacheService();

      // بارگذاری از cache
      final messages = await cacheService.getConversationMessages(
        params.conversationId,
        params.userId,
      );

      return messages;
    } catch (e) {
      print('❌ Isolate loading error: $e');
      return [];
    }
  }
}

// کلاس پارامترها برای Isolate
class _LoadMessagesParams {
  final String conversationId;
  final String userId;
  final int limit;
  final int offset;

  _LoadMessagesParams({
    required this.conversationId,
    required this.userId,
    required this.limit,
    required this.offset,
  });
}

