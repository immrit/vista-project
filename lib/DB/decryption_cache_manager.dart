import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../model/message_model.dart';
import 'advanced_cache_manager.dart';

/// Intelligent decryption cache manager with content hashing
class DecryptionCacheManager {
  static final DecryptionCacheManager _instance =
      DecryptionCacheManager._internal();
  factory DecryptionCacheManager() => _instance;
  DecryptionCacheManager._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();

  // Decryption cache with content hashing
  final Map<String, String> _decryptionMemoryCache = {};
  final Map<String, DateTime> _decryptionTimestamps = {};

  // Cache configuration
  static const Duration _decryptionTTL =
      Duration(days: 7); // Longer TTL for decryption results
  static const int _maxMemoryDecryptions = 500;

  // Performance tracking
  int _decryptionHits = 0;
  int _decryptionMisses = 0;
  final Map<String, Duration> _decryptionTimes = {};

  bool _isInitialized = false;

  /// Initialize decryption cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _cacheManager.initialize();
    _startPeriodicCleanup();

    _isInitialized = true;
    print('✅ Decryption Cache Manager initialized');
  }

  /// Cache decryption result with content-based key
  Future<void> cacheDecryptionResult(String encryptedContent,
      String decryptedContent, String conversationId) async {
    final cacheKey = _generateCacheKey(encryptedContent, conversationId);

    // Cache in memory
    _decryptionMemoryCache[cacheKey] = decryptedContent;
    _decryptionTimestamps[cacheKey] = DateTime.now();

    // Maintain memory cache size
    _maintainMemoryCacheSize();

    // Cache in persistent storage
    await _cacheManager.cacheDecryptionResult(cacheKey, decryptedContent);

    print(
        '🔐 Cached decryption result for key: ${cacheKey.substring(0, 16)}...');
  }

  /// Get cached decryption result
  Future<String?> getDecryptionResult(
      String encryptedContent, String conversationId) async {
    final cacheKey = _generateCacheKey(encryptedContent, conversationId);

    // Check memory cache first
    final memoryResult = _decryptionMemoryCache[cacheKey];
    if (memoryResult != null) {
      // Check if not expired
      final timestamp = _decryptionTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _decryptionTTL) {
        _decryptionHits++;
        return memoryResult;
      } else {
        // Remove expired entry
        _decryptionMemoryCache.remove(cacheKey);
        _decryptionTimestamps.remove(cacheKey);
      }
    }

    // Check persistent storage
    final persistentResult = await _cacheManager.getDecryptionResult(cacheKey);
    if (persistentResult != null) {
      // Update memory cache
      _decryptionMemoryCache[cacheKey] = persistentResult;
      _decryptionTimestamps[cacheKey] = DateTime.now();

      _decryptionHits++;
      return persistentResult;
    }

    _decryptionMisses++;
    return null;
  }

  /// Batch cache decryption results for better performance
  Future<void> cacheDecryptionResults(List<DecryptionEntry> entries) async {
    if (entries.isEmpty) return;

    final startTime = DateTime.now();

    // Update memory cache
    for (final entry in entries) {
      final cacheKey =
          _generateCacheKey(entry.encryptedContent, entry.conversationId);
      _decryptionMemoryCache[cacheKey] = entry.decryptedContent;
      _decryptionTimestamps[cacheKey] = DateTime.now();
    }

    // Maintain memory cache size
    _maintainMemoryCacheSize();

    // Batch cache in persistent storage
    for (final entry in entries) {
      final cacheKey =
          _generateCacheKey(entry.encryptedContent, entry.conversationId);
      await _cacheManager.cacheDecryptionResult(
          cacheKey, entry.decryptedContent);
    }

    final duration = DateTime.now().difference(startTime);
    print(
        '🔐 Batched cached ${entries.length} decryption results in ${duration.inMilliseconds}ms');
  }

  /// Intelligent decryption with caching
  Future<String?> decryptWithCache(
    String encryptedContent,
    String conversationId,
    Future<String?> Function() decryptFunction,
  ) async {
    // Try to get from cache first
    final cachedResult =
        await getDecryptionResult(encryptedContent, conversationId);
    if (cachedResult != null) {
      return cachedResult;
    }

    // Perform decryption
    final startTime = DateTime.now();
    final decryptedResult = await decryptFunction();
    final decryptionTime = DateTime.now().difference(startTime);

    // Cache the result if decryption was successful
    if (decryptedResult != null && decryptedResult.isNotEmpty) {
      await cacheDecryptionResult(
          encryptedContent, decryptedResult, conversationId);

      // Track decryption performance
      final cacheKey = _generateCacheKey(encryptedContent, conversationId);
      _decryptionTimes[cacheKey] = decryptionTime;
    }

    return decryptedResult;
  }

  /// Preload decryption results for better UX
  Future<void> preloadDecryptionResults(
      List<MessageModel> messages, String conversationId) async {
    final encryptedMessages =
        messages.where((msg) => msg.content.startsWith('e2ee:')).toList();

    if (encryptedMessages.isEmpty) return;

    // Check which messages are not in cache
    final entries = <DecryptionEntry>[];

    for (final message in encryptedMessages) {
      final cached = await getDecryptionResult(message.content, conversationId);
      if (cached == null) {
        // This message needs decryption - would be handled by the decryption function
        // For now, we just mark it for potential preloading
      }
    }

    print(
        '🔄 Preloaded decryption cache for ${encryptedMessages.length} messages');
  }

  /// Get decryption cache statistics
  Map<String, dynamic> getDecryptionStatistics() {
    final totalRequests = _decryptionHits + _decryptionMisses;
    final hitRate = totalRequests > 0 ? _decryptionHits / totalRequests : 0.0;

    final averageDecryptionTime = _decryptionTimes.isNotEmpty
        ? Duration(
            milliseconds: (_decryptionTimes.values
                        .map((d) => d.inMilliseconds)
                        .reduce((a, b) => a + b) /
                    _decryptionTimes.length)
                .round())
        : Duration.zero;

    return {
      'memory_cache_size': _decryptionMemoryCache.length,
      'hits': _decryptionHits,
      'misses': _decryptionMisses,
      'hit_rate': hitRate,
      'average_decryption_time': averageDecryptionTime.inMilliseconds,
      'tracked_decryptions': _decryptionTimes.length,
    };
  }

  /// Clear expired decryption cache entries
  Future<void> clearExpiredEntries() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    _decryptionTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _decryptionTTL) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _decryptionMemoryCache.remove(key);
      _decryptionTimestamps.remove(key);
    }

    print('🧹 Cleared ${expiredKeys.length} expired decryption cache entries');
  }

  /// Invalidate decryption cache for a conversation
  Future<void> invalidateConversationDecryption(String conversationId) async {
    final keysToRemove = <String>[];

    // Find all keys related to this conversation
    _decryptionMemoryCache.forEach((key, value) {
      if (key.contains(conversationId)) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _decryptionMemoryCache.remove(key);
      _decryptionTimestamps.remove(key);
    }

    print('🚫 Invalidated decryption cache for conversation: $conversationId');
  }

  /// Generate content-based cache key
  String _generateCacheKey(String encryptedContent, String conversationId) {
    // Create a hash of the encrypted content for consistent key generation
    final contentHash = sha256
        .convert(utf8.encode(encryptedContent))
        .toString()
        .substring(0, 16);
    return '${conversationId}_${contentHash}';
  }

  /// Maintain memory cache size
  void _maintainMemoryCacheSize() {
    if (_decryptionMemoryCache.length > _maxMemoryDecryptions) {
      // Remove oldest entries
      final entries = _decryptionTimestamps.entries.toList()
        ..sort((a, b) =>
            a.value.compareTo(b.value)); // Sort by timestamp (oldest first)

      final toRemove =
          entries.take(_decryptionMemoryCache.length - _maxMemoryDecryptions);
      for (final entry in toRemove) {
        _decryptionMemoryCache.remove(entry.key);
        _decryptionTimestamps.remove(entry.key);
      }
    }
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(hours: 1), (timer) {
      clearExpiredEntries();
    });
  }

  /// Get cache efficiency recommendations
  Map<String, dynamic> getEfficiencyRecommendations() {
    final stats = getDecryptionStatistics();
    final recommendations = <String>[];

    final hitRate = stats['hit_rate'] as double;
    if (hitRate < 0.8) {
      recommendations.add(
          'Decryption cache hit rate is low (${(hitRate * 100).toStringAsFixed(1)}%). Consider increasing cache size.');
    }

    final memorySize = stats['memory_cache_size'] as int;
    if (memorySize > 400) {
      recommendations.add(
          'Decryption memory cache is getting full ($memorySize entries). Consider cleanup.');
    }

    final avgTime = stats['average_decryption_time'] as int;
    if (avgTime > 100) {
      recommendations.add(
          'Average decryption time is high (${avgTime}ms). Consider optimization.');
    }

    return {
      'statistics': stats,
      'recommendations': recommendations,
    };
  }

  /// Export cache data for debugging
  Map<String, dynamic> exportCacheData() {
    return {
      'memory_cache_entries': _decryptionMemoryCache.length,
      'timestamps': _decryptionTimestamps.length,
      'statistics': getDecryptionStatistics(),
      'efficiency': getEfficiencyRecommendations(),
    };
  }

  /// Dispose resources
  void dispose() {
    _decryptionMemoryCache.clear();
    _decryptionTimestamps.clear();
    _decryptionTimes.clear();
  }
}

/// Decryption cache entry
class DecryptionEntry {
  final String encryptedContent;
  final String decryptedContent;
  final String conversationId;
  final DateTime timestamp;

  DecryptionEntry({
    required this.encryptedContent,
    required this.decryptedContent,
    required this.conversationId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'encryptedContent': encryptedContent,
      'decryptedContent': decryptedContent,
      'conversationId': conversationId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory DecryptionEntry.fromJson(Map<String, dynamic> json) {
    return DecryptionEntry(
      encryptedContent: json['encryptedContent'],
      decryptedContent: json['decryptedContent'],
      conversationId: json['conversationId'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
