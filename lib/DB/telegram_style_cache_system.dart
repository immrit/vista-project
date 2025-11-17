import 'dart:async';
import '../model/message_model.dart';
import '../utils/lru_cache.dart';
import 'unified_message_cache_service.dart';

/// ✅ Telegram-style Multi-Layer Cache System
/// الهام‌گرفته از معماری cache تلگرام Android
class TelegramStyleCacheSystem {
  static final TelegramStyleCacheSystem _instance =
      TelegramStyleCacheSystem._internal();
  factory TelegramStyleCacheSystem() => _instance;
  TelegramStyleCacheSystem._internal();

  // ✅ LAYER 1: Hot Memory Cache (LRU) - Fastest (<1ms)
  final LRUCache<String, List<MessageModel>> _hotCache = LRUCache(10);

  // ✅ LAYER 2: Memory Cache (Recent conversations)
  final Map<String, List<MessageModel>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // ✅ LAYER 3: Disk Cache (via UnifiedMessageCacheService)
  final UnifiedMessageCacheService _diskCache = UnifiedMessageCacheService();

  // ✅ Performance metrics
  int _l1Hits = 0; // Hot cache
  int _l2Hits = 0; // Memory cache
  int _l3Hits = 0; // Disk cache
  int _misses = 0;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    print('🚀 Initializing Telegram-style cache system...');

    // ✅ Initialize disk cache
    await _diskCache.initialize();

    _initialized = true;
    print('✅ Cache system initialized');
  }

  /// ✅ LEVEL 1: Hot Cache Check (synchronous - <1ms)
  List<MessageModel>? getFromHotCache(String conversationId) {
    final result = _hotCache.get(conversationId);
    if (result != null) {
      _l1Hits++;
      print('⚡ L1 HIT: Hot cache');
    }
    return result;
  }

  /// ✅ LEVEL 2: Memory Cache Check (synchronous - <5ms)
  List<MessageModel>? getFromMemoryCache(String conversationId) {
    final timestamp = _cacheTimestamps[conversationId];
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);

      if (age.inMinutes < 10) {
        // 10 دقیقه اعتبار
        final messages = _memoryCache[conversationId];
        if (messages != null) {
          _l2Hits++;
          print('💾 L2 HIT: Memory cache (age: ${age.inSeconds}s)');

          // Promote به hot cache
          _hotCache.put(conversationId, messages);
          return messages;
        }
      } else {
        print('⚠️ Memory cache EXPIRED');
        _memoryCache.remove(conversationId);
        _cacheTimestamps.remove(conversationId);
      }
    }

    return null;
  }

  /// ✅ LEVEL 3: Disk Cache Load (asynchronous - background)
  Future<List<MessageModel>?> loadFromDisk(
    String conversationId,
    String userId,
  ) async {
    if (!_initialized) {
      await initialize();
    }

    print('📀 Loading from disk...');

    try {
      final diskMessages =
          await _diskCache.getConversationMessages(conversationId, userId);

      if (diskMessages.isNotEmpty) {
        _l3Hits++;
        print('💿 L3 HIT: Disk cache - ${diskMessages.length} messages');

        // Update memory cache
        final unmodifiableMessages = List<MessageModel>.unmodifiable(diskMessages);
        _memoryCache[conversationId] = unmodifiableMessages;
        _cacheTimestamps[conversationId] = DateTime.now();

        // Promote to hot cache
        _hotCache.put(conversationId, unmodifiableMessages);

        return diskMessages;
      }

      _misses++;
      print('❌ Cache MISS: No data found');
      return null;
    } catch (e) {
      print('❌ Disk load error: $e');
      _misses++;
      return null;
    }
  }

  /// ✅ Multi-layer get - تلاش در تمام لایه‌ها
  Future<List<MessageModel>> getMessages(
    String conversationId,
    String userId,
  ) async {
    // L1: Hot cache
    final hotCached = getFromHotCache(conversationId);
    if (hotCached != null && hotCached.isNotEmpty) {
      return hotCached;
    }

    // L2: Memory cache
    final memoryCached = getFromMemoryCache(conversationId);
    if (memoryCached != null && memoryCached.isNotEmpty) {
      return memoryCached;
    }

    // L3: Disk cache
    final diskCached = await loadFromDisk(conversationId, userId);
    if (diskCached != null && diskCached.isNotEmpty) {
      return diskCached;
    }

    // Cache miss
    _misses++;
    return [];
  }

  /// ✅ Cache Update - با priority
  Future<void> cacheMessages(
    String conversationId,
    List<MessageModel> messages,
    String userId, {
    bool highPriority = false,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    final unmodifiableMessages = List<MessageModel>.unmodifiable(messages);

    // Update hot cache
    _hotCache.put(conversationId, unmodifiableMessages);

    // Update memory cache
    _memoryCache[conversationId] = unmodifiableMessages;
    _cacheTimestamps[conversationId] = DateTime.now();

    // Save to disk در background
    if (highPriority) {
      // فوری save کن
      await _saveToDiskImmediate(conversationId, unmodifiableMessages, userId);
    } else {
      // با تأخیر save کن
      Future.delayed(const Duration(seconds: 2), () {
        _saveToDiskImmediate(conversationId, unmodifiableMessages, userId);
      });
    }
  }

  Future<void> _saveToDiskImmediate(
    String conversationId,
    List<MessageModel> messages,
    String userId,
  ) async {
    try {
      await _diskCache.cacheMessages(messages, userId);
    } catch (e) {
      print('❌ Disk save error: $e');
    }
  }

  /// ✅ Get Performance Stats
  Map<String, dynamic> getPerformanceStats() {
    final total = _l1Hits + _l2Hits + _l3Hits + _misses;
    final hitRate = total > 0
        ? ((_l1Hits + _l2Hits + _l3Hits) / total * 100)
        : 0.0;

    return {
      'l1_hits': _l1Hits,
      'l2_hits': _l2Hits,
      'l3_hits': _l3Hits,
      'misses': _misses,
      'hit_rate': hitRate.toStringAsFixed(1),
      'hot_cache_size': _hotCache.length,
      'memory_cache_size': _memoryCache.length,
    };
  }

  /// ✅ Clear cache for a conversation
  void clearConversationCache(String conversationId) {
    _hotCache.remove(conversationId);
    _memoryCache.remove(conversationId);
    _cacheTimestamps.remove(conversationId);
  }

  /// ✅ Clear all caches
  void clearAll() {
    _hotCache.clear();
    _memoryCache.clear();
    _cacheTimestamps.clear();
    _l1Hits = 0;
    _l2Hits = 0;
    _l3Hits = 0;
    _misses = 0;
  }

  void dispose() {
    clearAll();
  }
}

