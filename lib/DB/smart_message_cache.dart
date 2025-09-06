import 'dart:async';
import '../model/message_model.dart';
import 'advanced_cache_manager.dart';

/// Smart message cache with intelligent prefetching and optimization
class SmartMessageCache {
  static final SmartMessageCache _instance = SmartMessageCache._internal();
  factory SmartMessageCache() => _instance;
  SmartMessageCache._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();

  // Prefetching configuration
  static const int _prefetchThreshold = 5; // Prefetch when 5 messages remain
  static const int _prefetchBatchSize = 20; // Number of messages to prefetch
  static const Duration _prefetchDelay = Duration(milliseconds: 100);

  // Batch operations
  final Map<String, List<MessageModel>> _pendingBatchOperations = {};
  Timer? _batchTimer;

  // Cache warming
  final Set<String> _warmedConversations = {};
  final Map<String, DateTime> _lastAccessTime = {};

  // Performance monitoring
  final Map<String, CachePerformanceMetrics> _performanceMetrics = {};

  bool _isInitialized = false;

  /// Initialize the smart cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _cacheManager.initialize();
    _startBatchProcessor();
    _startCacheWarmer();

    _isInitialized = true;
    print('✅ Smart Message Cache initialized');
  }

  /// Cache message with smart optimizations
  Future<void> cacheMessage(MessageModel message,
      {bool enablePrefetch = true}) async {
    await _cacheManager.cacheMessage(message);

    // Update performance metrics
    _updatePerformanceMetrics(message.conversationId, CacheOperation.write);

    // Trigger prefetching if needed
    if (enablePrefetch) {
      await _checkAndTriggerPrefetch(message.conversationId);
    }

    // Update access time
    _lastAccessTime[message.conversationId] = DateTime.now();
  }

  /// Batch cache messages for better performance
  Future<void> cacheMessages(
      List<MessageModel> messages, String conversationId) async {
    if (messages.isEmpty) return;

    final startTime = DateTime.now();

    // Use batch operation for better performance
    await _cacheManager.cacheConversationMessages(conversationId, messages);

    // Update performance metrics
    final duration = DateTime.now().difference(startTime);
    _performanceMetrics[conversationId] ??=
        CachePerformanceMetrics(conversationId);
    _performanceMetrics[conversationId]!.batchWriteTime = duration;

    // Warm up cache for this conversation
    _warmedConversations.add(conversationId);
    _lastAccessTime[conversationId] = DateTime.now();

    print(
        '📦 Batched cached ${messages.length} messages in ${duration.inMilliseconds}ms');
  }

  /// Get message with intelligent loading
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    final startTime = DateTime.now();

    final message = await _cacheManager.getMessage(conversationId, messageId);

    // Update performance metrics
    final duration = DateTime.now().difference(startTime);
    _updatePerformanceMetrics(conversationId, CacheOperation.read, duration);

    // Update access time
    _lastAccessTime[conversationId] = DateTime.now();

    return message;
  }

  /// Get conversation messages with smart pagination and prefetching
  Future<List<MessageModel>> getConversationMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
    bool enablePrefetch = true,
  }) async {
    final startTime = DateTime.now();

    // Check if we need to warm up the cache
    if (!_warmedConversations.contains(conversationId)) {
      await _warmUpConversation(conversationId);
    }

    final messages = await _cacheManager.getConversationMessages(
      conversationId,
      limit: limit,
      offset: offset,
    );

    // Update performance metrics
    final duration = DateTime.now().difference(startTime);
    _updatePerformanceMetrics(conversationId, CacheOperation.read, duration);

    // Trigger prefetching if needed
    if (enablePrefetch && messages.length < limit) {
      await _checkAndTriggerPrefetch(conversationId);
    }

    // Update access time
    _lastAccessTime[conversationId] = DateTime.now();

    return messages;
  }

  /// Intelligent prefetching based on usage patterns
  Future<void> _checkAndTriggerPrefetch(String conversationId) async {
    final cachedMessages = await _cacheManager.getConversationMessages(
      conversationId,
      limit: _prefetchThreshold + 1,
    );

    if (cachedMessages.length <= _prefetchThreshold) {
      // Trigger prefetch after a small delay to avoid blocking UI
      Future.delayed(_prefetchDelay, () {
        _prefetchConversationMessages(conversationId);
      });
    }
  }

  /// Prefetch conversation messages
  Future<void> _prefetchConversationMessages(String conversationId) async {
    try {
      // Load more messages from persistent storage
      final existingMessages =
          await _cacheManager.getConversationMessages(conversationId);
      final lastMessage =
          existingMessages.isNotEmpty ? existingMessages.last : null;

      if (lastMessage != null) {
        // Prefetch older messages
        final prefetchMessages = await _loadMessagesFromNetwork(
          conversationId,
          before: lastMessage.createdAt,
          limit: _prefetchBatchSize,
        );

        if (prefetchMessages.isNotEmpty) {
          await cacheMessages(prefetchMessages, conversationId);
          print(
              '🔄 Prefetched ${prefetchMessages.length} messages for $conversationId');
        }
      }
    } catch (e) {
      print('❌ Error prefetching messages for $conversationId: $e');
    }
  }

  /// Warm up conversation cache
  Future<void> _warmUpConversation(String conversationId) async {
    try {
      // Load recent messages to warm up the cache
      final messages = await _loadMessagesFromNetwork(
        conversationId,
        limit: 100, // Load more for warming
      );

      if (messages.isNotEmpty) {
        await cacheMessages(messages, conversationId);
        _warmedConversations.add(conversationId);
        print('🔥 Warmed up cache for conversation $conversationId');
      }
    } catch (e) {
      print('❌ Error warming up conversation $conversationId: $e');
    }
  }

  /// Load messages from network (placeholder - would integrate with ChatService)
  Future<List<MessageModel>> _loadMessagesFromNetwork(
    String conversationId, {
    DateTime? before,
    int limit = 50,
  }) async {
    // This would integrate with the actual ChatService
    // For now, return empty list as placeholder
    return [];
  }

  /// Get cache statistics and recommendations
  Map<String, dynamic> getCacheInsights() {
    final stats = _cacheManager.getCacheStatistics();
    final recommendations = <String>[];

    // Analyze performance and provide recommendations
    final hitRate = stats['hit_rate'] as double;
    if (hitRate < 0.7) {
      recommendations.add(
          'Cache hit rate is low (${(hitRate * 100).toStringAsFixed(1)}%). Consider increasing cache size.');
    }

    final memorySize = stats['memory_cache_size'] as int;
    if (memorySize > 800) {
      recommendations.add(
          'Memory cache is getting full ($memorySize items). Consider cleanup.');
    }

    return {
      'statistics': stats,
      'performance_metrics': _performanceMetrics,
      'recommendations': recommendations,
      'warmed_conversations': _warmedConversations.length,
      'active_conversations': _lastAccessTime.length,
    };
  }

  /// Optimize cache based on usage patterns
  Future<void> optimizeCache() async {
    final now = DateTime.now();

    // Remove old access times
    _lastAccessTime.removeWhere((conversationId, lastAccess) {
      return now.difference(lastAccess).inDays > 7;
    });

    // Remove old warmed conversations
    _warmedConversations.removeWhere((conversationId) {
      return !_lastAccessTime.containsKey(conversationId);
    });

    // Clear expired entries
    await _cacheManager.clearExpiredEntries();

    // Optimize memory usage
    _performanceMetrics.removeWhere((conversationId, metrics) {
      return now.difference(metrics.lastAccess).inHours > 24;
    });

    print('🔧 Cache optimization completed');
  }

  /// Update performance metrics
  void _updatePerformanceMetrics(
      String conversationId, CacheOperation operation,
      [Duration? duration]) {
    _performanceMetrics[conversationId] ??=
        CachePerformanceMetrics(conversationId);

    final metrics = _performanceMetrics[conversationId]!;
    metrics.lastAccess = DateTime.now();

    switch (operation) {
      case CacheOperation.read:
        metrics.readCount++;
        if (duration != null) {
          metrics.averageReadTime = _calculateAverage(
              metrics.averageReadTime, duration, metrics.readCount);
        }
        break;
      case CacheOperation.write:
        metrics.writeCount++;
        break;
    }
  }

  /// Calculate running average
  Duration _calculateAverage(
      Duration currentAverage, Duration newValue, int count) {
    final currentMs = currentAverage.inMilliseconds;
    final newMs = newValue.inMilliseconds;
    final averageMs = ((currentMs * (count - 1)) + newMs) / count;
    return Duration(milliseconds: averageMs.round());
  }

  /// Start batch processor
  void _startBatchProcessor() {
    _batchTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _processPendingBatches();
    });
  }

  /// Process pending batch operations
  Future<void> _processPendingBatches() async {
    for (final entry in _pendingBatchOperations.entries) {
      final conversationId = entry.key;
      final messages = entry.value;

      if (messages.isNotEmpty) {
        await cacheMessages(messages, conversationId);
        _pendingBatchOperations[conversationId] = [];
      }
    }
  }

  /// Start cache warmer
  void _startCacheWarmer() {
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _performCacheWarming();
    });
  }

  /// Perform intelligent cache warming
  Future<void> _performCacheWarming() async {
    // Warm up most recently accessed conversations
    final sortedConversations = _lastAccessTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    for (final entry in sortedConversations.take(3)) {
      if (!_warmedConversations.contains(entry.key)) {
        await _warmUpConversation(entry.key);
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _batchTimer?.cancel();
  }
}

/// Performance metrics for cache operations
class CachePerformanceMetrics {
  final String conversationId;
  int readCount = 0;
  int writeCount = 0;
  Duration averageReadTime = Duration.zero;
  Duration batchWriteTime = Duration.zero;
  DateTime lastAccess;

  CachePerformanceMetrics(this.conversationId) : lastAccess = DateTime.now();
}

/// Cache operations
enum CacheOperation {
  read,
  write,
}
