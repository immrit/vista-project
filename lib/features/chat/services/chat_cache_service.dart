// lib/features/chat/services/chat_cache_service.dart
//
// سرویس Cache یکپارچه برای چت
// 
// این سرویس:
// ✅ یه منبع واحد برای Cache (به جای 4 تا سیستم Cache جداگانه!)
// ✅ الگوی Singleton برای جلوگیری از نمونه‌های متعدد
// ✅ Stream-based برای Real-time UI updates
// ✅ Memory + Disk Cache با LRU eviction

import 'dart:async';
import 'dart:collection';
import '../../../model/message_model.dart';
import '../../../model/conversation_model.dart';
import '../../../DB/unified_message_cache_service.dart';
import '../../../DB/unified_conversation_cache_service.dart';
import '../../../main.dart';

/// سرویس Cache یکپارچه برای چت
/// 
/// از الگوی Singleton استفاده می‌کنه تا مطمئن بشیم فقط یه instance داریم
class ChatCacheService {
  // ═══════════════════════════════════════════════════════════════════
  // 🔒 SINGLETON PATTERN
  // ═══════════════════════════════════════════════════════════════════
  
  static final ChatCacheService _instance = ChatCacheService._internal();
  factory ChatCacheService() => _instance;
  ChatCacheService._internal();

  // ═══════════════════════════════════════════════════════════════════
  // 📦 DEPENDENCIES
  // ═══════════════════════════════════════════════════════════════════
  
  final UnifiedMessageCacheService _messageCache = UnifiedMessageCacheService();
  final UnifiedConversationCacheService _conversationCache = UnifiedConversationCacheService();

  // ═══════════════════════════════════════════════════════════════════
  // 💾 MEMORY CACHE (برای دسترسی فوری)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Cache پیام‌ها در Memory (Key: conversationId)
  /// از LinkedHashMap برای LRU استفاده می‌کنیم
  final LinkedHashMap<String, List<MessageModel>> _messagesMemoryCache = 
      LinkedHashMap();
  
  /// Cache مکالمات در Memory
  List<ConversationModel>? _conversationsMemoryCache;
  
  /// زمان آخرین آپدیت Cache ها
  final Map<String, DateTime> _messageCacheTimestamps = {};
  DateTime? _conversationsCacheTimestamp;
  
  /// حداکثر تعداد مکالمات در Memory Cache
  static const int _maxConversationsInMemory = 5;
  
  /// مدت اعتبار Memory Cache (5 دقیقه)
  static const Duration _memoryCacheExpiry = Duration(minutes: 5);

  // ═══════════════════════════════════════════════════════════════════
  // 📡 STREAM CONTROLLERS (برای Real-time updates)
  // ═══════════════════════════════════════════════════════════════════
  
  /// Controller برای Stream مکالمات
  final _conversationsController = StreamController<List<ConversationModel>>.broadcast();
  
  /// Controllers برای Stream پیام‌های هر مکالمه
  final Map<String, StreamController<List<MessageModel>>> _messageControllers = {};
  
  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS CACHE
  // ═══════════════════════════════════════════════════════════════════

  /// دریافت مکالمات از Cache
  /// 
  /// اول Memory Cache، بعد Disk Cache
  Future<List<ConversationModel>> getCachedConversations() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // ✅ Step 1: Memory Cache (فوری)
    if (_conversationsMemoryCache != null && _isMemoryCacheValid(_conversationsCacheTimestamp)) {
      print('⚡ Memory cache hit for conversations');
      return _conversationsMemoryCache!;
    }

    // ✅ Step 2: Disk Cache
    try {
      final cached = await _conversationCache.getCachedConversations(userId);
      if (cached.isNotEmpty) {
        _conversationsMemoryCache = cached;
        _conversationsCacheTimestamp = DateTime.now();
        print('💾 Disk cache hit for conversations: ${cached.length} items');
        return cached;
      }
    } catch (e) {
      print('⚠️ Error reading conversations from disk cache: $e');
    }

    return [];
  }

  /// ذخیره مکالمات در Cache
  Future<void> cacheConversations(List<ConversationModel> conversations) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ Memory Cache
    _conversationsMemoryCache = List.unmodifiable(conversations);
    _conversationsCacheTimestamp = DateTime.now();

    // ✅ Disk Cache (در Background)
    Future.microtask(() async {
      try {
        for (final conversation in conversations) {
          await _conversationCache.cacheConversation(conversation, userId);
        }
      } catch (e) {
        print('⚠️ Error caching conversations to disk: $e');
      }
    });

    // ✅ Notify Listeners
    _conversationsController.add(conversations);
  }

  /// آپدیت یک مکالمه
  Future<void> updateConversation(ConversationModel conversation) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ Update Memory Cache
    if (_conversationsMemoryCache != null) {
      final index = _conversationsMemoryCache!.indexWhere((c) => c.id == conversation.id);
      if (index != -1) {
        final updated = List<ConversationModel>.from(_conversationsMemoryCache!);
        updated[index] = conversation;
        _conversationsMemoryCache = updated;
        _conversationsController.add(updated);
      }
    }

    // ✅ Update Disk Cache
    await _conversationCache.updateConversation(conversation, userId);
  }

  /// Stream مکالمات
  Stream<List<ConversationModel>> watchConversations() async* {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ اول Cache فعلی رو emit کن
    final cached = await getCachedConversations();
    if (cached.isNotEmpty) {
      yield cached;
    }

    // ✅ بعد به Stream گوش بده
    yield* _conversationCache.watchCachedConversations(userId);
  }

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES CACHE
  // ═══════════════════════════════════════════════════════════════════

  /// دریافت پیام‌های یک مکالمه از Cache
  Future<List<MessageModel>> getCachedMessages(String conversationId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // ✅ Step 1: Memory Cache (فوری)
    if (_messagesMemoryCache.containsKey(conversationId) && 
        _isMemoryCacheValid(_messageCacheTimestamps[conversationId])) {
      print('⚡ Memory cache hit for messages: $conversationId');
      return _messagesMemoryCache[conversationId]!;
    }

    // ✅ Step 2: Disk Cache
    try {
      final cached = await _messageCache.getConversationMessages(conversationId, userId);
      if (cached.isNotEmpty) {
        _updateMessagesMemoryCache(conversationId, cached);
        print('💾 Disk cache hit for messages: ${cached.length} items');
        return cached;
      }
    } catch (e) {
      print('⚠️ Error reading messages from disk cache: $e');
    }

    return [];
  }

  /// ذخیره پیام‌ها در Cache
  Future<void> cacheMessages(String conversationId, List<MessageModel> messages) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ Memory Cache
    _updateMessagesMemoryCache(conversationId, messages);

    // ✅ Disk Cache (در Background)
    Future.microtask(() async {
      try {
        await _messageCache.cacheMessages(messages, userId);
      } catch (e) {
        print('⚠️ Error caching messages to disk: $e');
      }
    });

    // ✅ Notify Listeners
    _getOrCreateMessageController(conversationId).add(messages);
  }

  /// اضافه کردن یک پیام جدید به Cache
  Future<void> addMessage(MessageModel message) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final conversationId = message.conversationId;

    // ✅ Update Memory Cache
    final currentMessages = _messagesMemoryCache[conversationId] ?? [];
    final updated = [...currentMessages, message];
    // مرتب‌سازی - جدیدترین اول
    updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _updateMessagesMemoryCache(conversationId, updated);

    // ✅ Update Disk Cache
    await _messageCache.cacheMessage(message, userId);

    // ✅ Notify Listeners
    _getOrCreateMessageController(conversationId).add(updated);
  }

  /// آپدیت یک پیام
  Future<void> updateMessage(MessageModel message) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final conversationId = message.conversationId;

    // ✅ Update Memory Cache
    if (_messagesMemoryCache.containsKey(conversationId)) {
      final messages = List<MessageModel>.from(_messagesMemoryCache[conversationId]!);
      final index = messages.indexWhere((m) => m.id == message.id);
      if (index != -1) {
        messages[index] = message;
        _updateMessagesMemoryCache(conversationId, messages);
        _getOrCreateMessageController(conversationId).add(messages);
      }
    }

    // ✅ Update Disk Cache
    await _messageCache.cacheMessage(message, userId);
  }

  /// حذف یک پیام از Cache
  Future<void> removeMessage(String messageId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // پیدا کردن conversationId
    String? conversationId;
    for (final entry in _messagesMemoryCache.entries) {
      if (entry.value.any((m) => m.id == messageId)) {
        conversationId = entry.key;
        break;
      }
    }

    if (conversationId != null) {
      // ✅ Update Memory Cache
      final messages = List<MessageModel>.from(_messagesMemoryCache[conversationId]!);
      messages.removeWhere((m) => m.id == messageId);
      _updateMessagesMemoryCache(conversationId, messages);
      _getOrCreateMessageController(conversationId).add(messages);

      // ✅ Update Disk Cache
      await _messageCache.clearMessage(conversationId, messageId, userId);
    }
  }

  /// Stream پیام‌های یک مکالمه
  Stream<List<MessageModel>> watchMessages(String conversationId) async* {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // ✅ اول Cache فعلی رو emit کن
    final cached = await getCachedMessages(conversationId);
    if (cached.isNotEmpty) {
      yield cached;
    }

    // ✅ بعد به Stream Controller گوش بده
    yield* _getOrCreateMessageController(conversationId).stream;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🔧 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  /// بررسی اعتبار Memory Cache
  bool _isMemoryCacheValid(DateTime? timestamp) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _memoryCacheExpiry;
  }

  /// آپدیت Memory Cache پیام‌ها با LRU eviction
  void _updateMessagesMemoryCache(String conversationId, List<MessageModel> messages) {
    // حذف از لیست اگه وجود داره (برای انتقال به آخر - LRU)
    _messagesMemoryCache.remove(conversationId);
    
    // اگه بیش از حد مجاز شد، قدیمی‌ترین رو حذف کن
    while (_messagesMemoryCache.length >= _maxConversationsInMemory) {
      final oldest = _messagesMemoryCache.keys.first;
      _messagesMemoryCache.remove(oldest);
      _messageCacheTimestamps.remove(oldest);
      print('🗑️ LRU eviction: removed $oldest from memory cache');
    }

    _messagesMemoryCache[conversationId] = List.unmodifiable(messages);
    _messageCacheTimestamps[conversationId] = DateTime.now();
  }

  /// گرفتن یا ساختن StreamController برای پیام‌های یک مکالمه
  StreamController<List<MessageModel>> _getOrCreateMessageController(String conversationId) {
    if (!_messageControllers.containsKey(conversationId)) {
      _messageControllers[conversationId] = StreamController<List<MessageModel>>.broadcast();
    }
    return _messageControllers[conversationId]!;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════

  /// پاک کردن Cache یک مکالمه
  Future<void> clearConversationCache(String conversationId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Memory
    _messagesMemoryCache.remove(conversationId);
    _messageCacheTimestamps.remove(conversationId);
    
    // Controller
    _messageControllers[conversationId]?.close();
    _messageControllers.remove(conversationId);

    // Disk
    await _messageCache.clearConversationMessages(conversationId, userId);
  }

  /// پاک کردن کل Cache
  Future<void> clearAll() async {
    // Memory
    _messagesMemoryCache.clear();
    _messageCacheTimestamps.clear();
    _conversationsMemoryCache = null;
    _conversationsCacheTimestamp = null;

    // Controllers
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();

    print('🧹 All chat cache cleared');
  }

  /// Dispose - بستن همه Stream ها
  void dispose() {
    _conversationsController.close();
    for (final controller in _messageControllers.values) {
      controller.close();
    }
    _messageControllers.clear();
    print('🧹 ChatCacheService disposed');
  }

  // ═══════════════════════════════════════════════════════════════════
  // 📊 STATS (برای Debug)
  // ═══════════════════════════════════════════════════════════════════

  /// گرفتن آمار Cache
  Map<String, dynamic> getCacheStats() {
    return {
      'conversations_in_memory': _conversationsMemoryCache?.length ?? 0,
      'conversations_cache_age_seconds': _conversationsCacheTimestamp != null
          ? DateTime.now().difference(_conversationsCacheTimestamp!).inSeconds
          : null,
      'message_conversations_in_memory': _messagesMemoryCache.length,
      'active_stream_controllers': _messageControllers.length,
      'memory_cache_max': _maxConversationsInMemory,
      'cache_expiry_minutes': _memoryCacheExpiry.inMinutes,
    };
  }
}

