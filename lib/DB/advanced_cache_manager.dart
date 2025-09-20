import 'dart:async';
import '../model/message_model.dart';
import '../model/conversation_model.dart';

/// Advanced multi-layer caching system for messaging app
class AdvancedCacheManager {
  static final AdvancedCacheManager _instance =
      AdvancedCacheManager._internal();
  factory AdvancedCacheManager() => _instance;
  AdvancedCacheManager._internal();

  // Memory cache layer
  final Map<String, CacheEntry> _memoryCache = {};
  final Map<String, List<String>> _conversationMessageKeys = {};
  final Map<String, ConversationModel> _conversationCache = {};

  // Cache configuration
  static const Duration _defaultTTL = Duration(hours: 24);
  static const Duration _shortTTL = Duration(minutes: 30);
  static const Duration _longTTL = Duration(days: 7);
  static const int _maxMemoryItems = 1000;

  // Cache statistics
  int _memoryHits = 0;
  int _memoryMisses = 0;
  int _persistentHits = 0;
  int _persistentMisses = 0;

  bool _isInitialized = false;

  /// Initialize the cache system
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Start background cleanup
      _startBackgroundCleanup();

      _isInitialized = true;
      print('✅ Advanced Cache Manager initialized');
    } catch (e) {
      print('❌ Error initializing Advanced Cache Manager: $e');
      rethrow;
    }
  }

  /// Cache message with intelligent TTL
  Future<void> cacheMessage(MessageModel message, {Duration? ttl}) async {
    final key = 'message_${message.conversationId}_${message.id}';
    final cacheEntry = CacheEntry(
      data: message,
      timestamp: DateTime.now(),
      ttl: ttl ?? _getMessageTTL(message),
      type: CacheType.message,
    );

    // Add to memory cache
    _memoryCache[key] = cacheEntry;

    // Add to conversation index
    if (!_conversationMessageKeys.containsKey(message.conversationId)) {
      _conversationMessageKeys[message.conversationId] = [];
    }
    if (!_conversationMessageKeys[message.conversationId]!.contains(key)) {
      _conversationMessageKeys[message.conversationId]!.add(key);
    }

    // Maintain memory cache size
    _maintainMemoryCacheSize();

    // Cache in persistent storage
    await _cacheInPersistentStorage(key, cacheEntry);
  }

  /// Get cached message with fallback to persistent storage
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    final key = 'message_${conversationId}_$messageId';

    // Check memory cache first
    final memoryEntry = _memoryCache[key];
    if (memoryEntry != null && !memoryEntry.isExpired) {
      _memoryHits++;
      return memoryEntry.data as MessageModel;
    }

    // Check persistent storage
    final persistentEntry = await _getFromPersistentStorage(key);
    if (persistentEntry != null && !persistentEntry.isExpired) {
      _persistentHits++;
      // Update memory cache
      _memoryCache[key] = persistentEntry;
      return persistentEntry.data as MessageModel;
    }

    _memoryMisses++;
    return null;
  }

  /// Cache conversation messages with optimization
  Future<void> cacheConversationMessages(
      String conversationId, List<MessageModel> messages) async {
    final batch = <String, CacheEntry>{};

    for (final message in messages) {
      final key = 'message_${conversationId}_${message.id}';
      final cacheEntry = CacheEntry(
        data: message,
        timestamp: DateTime.now(),
        ttl: _getMessageTTL(message),
        type: CacheType.message,
      );

      batch[key] = cacheEntry;
      _memoryCache[key] = cacheEntry;
    }

    // Update conversation index
    _conversationMessageKeys[conversationId] = batch.keys.toList();

    // Maintain memory cache size
    _maintainMemoryCacheSize();

    // Batch cache in persistent storage
    await _batchCacheInPersistentStorage(batch);
  }

  /// Get cached conversation messages with smart loading
  Future<List<MessageModel>> getConversationMessages(
    String conversationId, {
    int? limit,
    int? offset,
    DateTime? since,
  }) async {
    final messageKeys = _conversationMessageKeys[conversationId] ?? [];
    final messages = <MessageModel>[];

    // Get from memory cache first
    for (final key in messageKeys) {
      final entry = _memoryCache[key];
      if (entry != null && !entry.isExpired) {
        messages.add(entry.data as MessageModel);
      }
    }

    // If not enough messages in memory, load from persistent storage
    if (messages.length < (limit ?? 50)) {
      final persistentMessages = await _getConversationMessagesFromPersistent(
        conversationId,
        limit: limit,
        offset: offset,
        since: since,
      );

      // Add new messages to memory cache
      for (final message in persistentMessages) {
        final key = 'message_${conversationId}_${message.id}';
        if (!_memoryCache.containsKey(key)) {
          _memoryCache[key] = CacheEntry(
            data: message,
            timestamp: DateTime.now(),
            ttl: _getMessageTTL(message),
            type: CacheType.message,
          );
        }
      }

      messages.addAll(persistentMessages);
    }

    // Sort by creation date (newest first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Apply pagination
    if (limit != null && offset != null) {
      final start = offset;
      final end = start + limit;
      return messages.sublist(start, end.clamp(0, messages.length));
    }

    return limit != null ? messages.take(limit).toList() : messages;
  }

  /// Cache conversation
  Future<void> cacheConversation(ConversationModel conversation) async {
    final key = 'conversation_${conversation.id}';
    final cacheEntry = CacheEntry(
      data: conversation,
      timestamp: DateTime.now(),
      ttl: _longTTL,
      type: CacheType.conversation,
    );

    _memoryCache[key] = cacheEntry;
    _conversationCache[conversation.id] = conversation;

    await _cacheInPersistentStorage(key, cacheEntry);
  }

  /// Get cached conversation
  Future<ConversationModel?> getConversation(String conversationId) async {
    // Check memory cache first
    final conversation = _conversationCache[conversationId];
    if (conversation != null) {
      return conversation;
    }

    final key = 'conversation_$conversationId';
    final entry = _memoryCache[key];
    if (entry != null && !entry.isExpired) {
      _memoryHits++;
      return entry.data as ConversationModel;
    }

    // Check persistent storage
    final persistentEntry = await _getFromPersistentStorage(key);
    if (persistentEntry != null && !persistentEntry.isExpired) {
      _persistentHits++;
      _memoryCache[key] = persistentEntry;
      _conversationCache[conversationId] =
          persistentEntry.data as ConversationModel;
      return persistentEntry.data as ConversationModel;
    }

    _memoryMisses++;
    return null;
  }

  /// Invalidate conversation cache
  Future<void> invalidateConversation(String conversationId) async {
    final messageKeys = _conversationMessageKeys[conversationId] ?? [];
    for (final key in messageKeys) {
      _memoryCache.remove(key);
      await _removeFromPersistentStorage(key);
    }

    _conversationMessageKeys.remove(conversationId);
    _conversationCache.remove(conversationId);

    final conversationKey = 'conversation_$conversationId';
    _memoryCache.remove(conversationKey);
    await _removeFromPersistentStorage(conversationKey);
  }

  /// Clear expired entries
  Future<void> clearExpiredEntries() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _memoryCache.forEach((key, entry) {
      if (entry.isExpired) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      await _removeFromPersistentStorage(key);
    }

    print('🧹 Cleared ${expiredKeys.length} expired cache entries');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'memory_cache_size': _memoryCache.length,
      'conversation_cache_size': _conversationCache.length,
      'memory_hits': _memoryHits,
      'memory_misses': _memoryMisses,
      'persistent_hits': _persistentHits,
      'persistent_misses': _persistentMisses,
      'hit_rate': _calculateHitRate(),
    };
  }

  /// Determine TTL based on message properties
  Duration _getMessageTTL(MessageModel message) {
    // Recent messages get shorter TTL
    final age = DateTime.now().difference(message.createdAt);
    if (age.inHours < 1) return _shortTTL;
    if (age.inDays < 1) return _defaultTTL;
    if (age.inDays < 7) return _longTTL;

    // Very old messages get even longer TTL
    return Duration(days: 30);
  }

  /// Maintain memory cache size
  void _maintainMemoryCacheSize() {
    if (_memoryCache.length > _maxMemoryItems) {
      // Remove oldest entries
      final entries = _memoryCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

      final toRemove = entries.take(_memoryCache.length - _maxMemoryItems);
      for (final entry in toRemove) {
        _memoryCache.remove(entry.key);
      }
    }
  }

  /// Calculate cache hit rate
  double _calculateHitRate() {
    final totalRequests =
        _memoryHits + _memoryMisses + _persistentHits + _persistentMisses;
    if (totalRequests == 0) return 0.0;

    final totalHits = _memoryHits + _persistentHits;
    return totalHits / totalRequests;
  }

  /// Start background cleanup
  void _startBackgroundCleanup() {
    Timer.periodic(const Duration(minutes: 30), (timer) {
      clearExpiredEntries();
    });
  }

  // Placeholder methods for persistent storage operations
  // These would be implemented with the existing Sembast services
  Future<void> _cacheInPersistentStorage(String key, CacheEntry entry) async {
    // Implementation would use existing Sembast services
  }

  Future<void> _batchCacheInPersistentStorage(
      Map<String, CacheEntry> batch) async {
    // Implementation would use existing Sembast services
  }

  Future<CacheEntry?> _getFromPersistentStorage(String key) async {
    // Implementation would use existing Sembast services
    return null;
  }

  Future<List<MessageModel>> _getConversationMessagesFromPersistent(
    String conversationId, {
    int? limit,
    int? offset,
    DateTime? since,
  }) async {
    // Implementation would use existing Sembast services
    return [];
  }

  Future<void> _removeFromPersistentStorage(String key) async {
    // Implementation would use existing Sembast services
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    _memoryCache.clear();
    _conversationMessageKeys.clear();
    _conversationCache.clear();
    _memoryHits = 0;
    _memoryMisses = 0;
    _persistentHits = 0;
    _persistentMisses = 0;

    print('🗑️ Advanced Cache Manager cleared all data');
  }
}

/// Cache entry with TTL support
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;
  final Duration ttl;
  final CacheType type;

  CacheEntry({
    required this.data,
    required this.timestamp,
    required this.ttl,
    required this.type,
  });

  bool get isExpired => DateTime.now().difference(timestamp) > ttl;
}

/// Cache entry types
enum CacheType {
  message,
  conversation,
  attachment,
  metadata,
}
