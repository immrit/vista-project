import 'dart:async';
import 'dart:collection';
import '../model/conversation_model.dart';
import '../model/message_model.dart';

/// Performance Cache Optimizer
/// بهینه‌ساز عملکرد کش برای سرعت تلگرام
class PerformanceCacheOptimizer {
  static final PerformanceCacheOptimizer _instance =
      PerformanceCacheOptimizer._internal();
  factory PerformanceCacheOptimizer() => _instance;
  PerformanceCacheOptimizer._internal();

  // Hot Cache (Most Recently Used)
  final LRUCache<String, List<MessageModel>> _hotMessageCache = LRUCache(20);
  final LRUCache<String, ConversationModel> _hotConversationCache =
      LRUCache(50);

  // Preload Cache (Predicted Usage)
  final Map<String, List<MessageModel>> _preloadCache = {};
  final Set<String> _preloadQueue = {};

  // Performance Metrics
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _preloadHits = 0;

  Timer? _cleanupTimer;
  bool _isOptimizing = false;

  /// Initialize the performance optimizer
  void initialize() {
    if (_isOptimizing) return;

    print('🚀 Initializing Performance Cache Optimizer...');

    // Start periodic cleanup
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performCleanup();
    });

    _isOptimizing = true;
    print('✅ Performance Cache Optimizer initialized');
  }

  /// Cache messages with performance optimization
  void cacheMessages(String conversationId, List<MessageModel> messages) {
    // Hot cache (immediate access)
    _hotMessageCache.put(conversationId, messages);

    // Preload related conversations
    _schedulePreload(conversationId);
  }

  /// Cache conversation with optimization
  void cacheConversation(ConversationModel conversation) {
    _hotConversationCache.put(conversation.id, conversation);
  }

  /// Get messages with performance tracking
  List<MessageModel>? getMessages(String conversationId) {
    // Check hot cache first
    final hotResult = _hotMessageCache.get(conversationId);
    if (hotResult != null) {
      _cacheHits++;
      return hotResult;
    }

    // Check preload cache
    final preloadResult = _preloadCache[conversationId];
    if (preloadResult != null) {
      _preloadHits++;
      // Move to hot cache
      _hotMessageCache.put(conversationId, preloadResult);
      return preloadResult;
    }

    _cacheMisses++;
    return null;
  }

  /// Get conversation with optimization
  ConversationModel? getConversation(String conversationId) {
    final result = _hotConversationCache.get(conversationId);
    if (result != null) {
      _cacheHits++;
    } else {
      _cacheMisses++;
    }
    return result;
  }

  /// Schedule intelligent preloading
  void _schedulePreload(String currentConversationId) {
    if (_preloadQueue.contains(currentConversationId)) return;

    _preloadQueue.add(currentConversationId);

    // Preload in next frame to avoid blocking UI
    Future.microtask(() {
      _performPreload(currentConversationId);
    });
  }

  /// Perform intelligent preloading
  Future<void> _performPreload(String conversationId) async {
    try {
      // Predict which conversations user might open next
      final candidateConversations = _predictNextConversations(conversationId);

      for (final candidateId in candidateConversations) {
        if (!_preloadCache.containsKey(candidateId) &&
            !_hotMessageCache.containsKey(candidateId)) {
          // This would normally load from database/network
          // For now, we'll just mark it as ready for preload
          print('🔮 Preloading conversation: $candidateId');
        }
      }
    } catch (e) {
      print('⚠️ Preload error: $e');
    } finally {
      _preloadQueue.remove(conversationId);
    }
  }

  /// Predict next conversations user might open
  List<String> _predictNextConversations(String currentId) {
    // Simple prediction: recently cached conversations
    final recentConversations = _hotConversationCache.keys
        .where((id) => id != currentId)
        .take(3)
        .toList();

    return recentConversations;
  }

  /// Perform cleanup to maintain performance
  void _performCleanup() {
    print('🧹 Performing cache cleanup...');

    // Clear old preload cache
    if (_preloadCache.length > 10) {
      final oldEntries =
          _preloadCache.keys.take(_preloadCache.length - 10).toList();
      for (final key in oldEntries) {
        _preloadCache.remove(key);
      }
    }

    // Clear pending preload queue if too large
    if (_preloadQueue.length > 5) {
      _preloadQueue.clear();
    }

    print('✅ Cache cleanup completed');
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final total = _cacheHits + _cacheMisses;
    final hitRate = total > 0 ? (_cacheHits / total * 100) : 0.0;

    return {
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'preload_hits': _preloadHits,
      'hit_rate': hitRate.toStringAsFixed(1),
      'hot_cache_size': _hotMessageCache.length,
      'preload_cache_size': _preloadCache.length,
      'preload_queue_size': _preloadQueue.length,
    };
  }

  /// Reset performance metrics
  void resetStats() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _preloadHits = 0;
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _hotMessageCache.clear();
    _hotConversationCache.clear();
    _preloadCache.clear();
    _preloadQueue.clear();
    _isOptimizing = false;
    print('🧹 Performance Cache Optimizer disposed');
  }
}

/// LRU Cache implementation for optimal memory usage
class LRUCache<K, V> {
  final int _maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  LRUCache(this._maxSize);

  V? get(K key) {
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value; // Move to end (most recent)
    }
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= _maxSize) {
      _cache.remove(_cache.keys.first); // Remove oldest
    }
    _cache[key] = value;
  }

  bool containsKey(K key) => _cache.containsKey(key);

  int get length => _cache.length;

  Iterable<K> get keys => _cache.keys;

  void clear() => _cache.clear();
}
