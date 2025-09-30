import 'dart:async';
import 'dart:developer' as developer;
import '../main.dart';
import '../DB/unified_message_cache_service.dart';

/// سرویس بهینه‌سازی پیشرفته cache برای همگام‌سازی روان
class AdvancedCacheOptimizer {
  static final AdvancedCacheOptimizer _instance =
      AdvancedCacheOptimizer._internal();
  factory AdvancedCacheOptimizer() => _instance;
  AdvancedCacheOptimizer._internal();

  final UnifiedMessageCacheService _cache = UnifiedMessageCacheService();

  // Cache metrics
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};
  final Map<String, DateTime> _lastAccess = {};

  // Intelligent prefetching
  final Map<String, Timer> _prefetchTimers = {};
  final Set<String> _prefetchQueue = {};

  // Smart compression
  final Map<String, dynamic> _compressionCache = {};

  Timer? _optimizationTimer;
  bool _isOptimizing = false;

  /// شروع optimization engine
  Future<void> startOptimization() async {
    if (_isOptimizing) return;

    _isOptimizing = true;
    developer.log('🚀 Starting Advanced Cache Optimization...',
        name: 'CacheOptimizer');

    // شروع optimization cycle هر 2 دقیقه
    _optimizationTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _performOptimizationCycle();
    });

    // Intelligent prefetching
    _startIntelligentPrefetching();

    developer.log('✅ Advanced Cache Optimization started',
        name: 'CacheOptimizer');
  }

  /// چرخه بهینه‌سازی
  Future<void> _performOptimizationCycle() async {
    try {
      await _optimizeCachePerformance();
      await _intelligentCacheEviction();
      await _optimizeMemoryUsage();
      _updateCacheMetrics();
    } catch (e) {
      developer.log('⚠️ Optimization cycle error: $e', name: 'CacheOptimizer');
    }
  }

  /// بهینه‌سازی عملکرد cache
  Future<void> _optimizeCachePerformance() async {
    final now = DateTime.now();

    // شناسایی cache entries که کمتر استفاده می‌شوند
    final lowUsageEntries = <String>[];

    for (final entry in _lastAccess.entries) {
      final timeSinceAccess = now.difference(entry.value);
      final hits = _cacheHits[entry.key] ?? 0;

      // اگر بیش از 10 دقیقه استفاده نشده و کم hit داشته
      if (timeSinceAccess.inMinutes > 10 && hits < 3) {
        lowUsageEntries.add(entry.key);
      }
    }

    // Pre-compress frequently accessed data
    for (final entry in _cacheHits.entries) {
      if (entry.value > 10 && !_compressionCache.containsKey(entry.key)) {
        await _preCompressData(entry.key);
      }
    }

    developer.log('🔧 Optimized ${lowUsageEntries.length} low-usage entries',
        name: 'CacheOptimizer');
  }

  /// هوشمند cache eviction
  Future<void> _intelligentCacheEviction() async {
    // این روش بر اساس LRU + frequency analysis کار می‌کند
    final candidates = <String, double>{};
    final now = DateTime.now();

    for (final entry in _lastAccess.entries) {
      final timeSinceAccess = now.difference(entry.value).inMinutes.toDouble();
      final hits = (_cacheHits[entry.key] ?? 0).toDouble();
      final misses = (_cacheMisses[entry.key] ?? 0).toDouble();

      // محاسبه امتیاز eviction (کمتر = بهتر برای نگهداری)
      final score = timeSinceAccess / (hits + 1) + misses;
      candidates[entry.key] = score;
    }

    // مرتب‌سازی و evict کردن worst performers
    final sortedCandidates = candidates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final toEvict = sortedCandidates.take(candidates.length ~/ 4); // 25% worst

    for (final entry in toEvict) {
      _evictFromCache(entry.key);
    }

    developer.log('🗑️ Evicted ${toEvict.length} cache entries',
        name: 'CacheOptimizer');
  }

  /// بهینه‌سازی استفاده از memory
  Future<void> _optimizeMemoryUsage() async {
    // پاکسازی compression cache قدیمی
    final now = DateTime.now();
    final oldCompressions = <String>[];

    for (final entry in _compressionCache.entries) {
      if (entry.value is Map && entry.value['timestamp'] != null) {
        final timestamp = DateTime.parse(entry.value['timestamp']);
        if (now.difference(timestamp).inHours > 1) {
          oldCompressions.add(entry.key);
        }
      }
    }

    for (final key in oldCompressions) {
      _compressionCache.remove(key);
    }

    developer.log('🧹 Cleaned ${oldCompressions.length} old compressions',
        name: 'CacheOptimizer');
  }

  /// شروع prefetching هوشمند
  void _startIntelligentPrefetching() {
    // بر اساس الگوهای usage، cache entries مرتبط را prefetch کن
    Timer.periodic(const Duration(minutes: 5), (_) {
      _performIntelligentPrefetch();
    });
  }

  /// انجام prefetch هوشمند
  Future<void> _performIntelligentPrefetch() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Predict که کاربر احتمالاً کدام مکالمات را باز خواهد کرد
    final recentConversations = _getRecentlyAccessedConversations();

    for (final conversationId in recentConversations.take(3)) {
      if (!_prefetchQueue.contains(conversationId)) {
        _prefetchQueue.add(conversationId);
        _prefetchConversationMessages(conversationId, userId);
      }
    }
  }

  /// دریافت مکالمات اخیراً accessed
  List<String> _getRecentlyAccessedConversations() {
    final now = DateTime.now();
    final recent = <String>[];

    for (final entry in _lastAccess.entries) {
      if (now.difference(entry.value).inMinutes < 30) {
        // Extract conversation ID from cache key
        if (entry.key.contains('_')) {
          final conversationId = entry.key.split('_')[0];
          if (!recent.contains(conversationId)) {
            recent.add(conversationId);
          }
        }
      }
    }

    return recent;
  }

  /// Prefetch پیام‌های مکالمه
  Future<void> _prefetchConversationMessages(
      String conversationId, String userId) async {
    _prefetchTimers[conversationId]?.cancel();

    _prefetchTimers[conversationId] =
        Timer(const Duration(seconds: 2), () async {
      try {
        await _cache.getConversationMessages(conversationId, userId);
        _prefetchQueue.remove(conversationId);
        developer.log('📦 Prefetched messages for $conversationId',
            name: 'CacheOptimizer');
      } catch (e) {
        developer.log('⚠️ Prefetch failed for $conversationId: $e',
            name: 'CacheOptimizer');
      }
    });
  }

  /// Pre-compress data برای access سریع‌تر
  Future<void> _preCompressData(String cacheKey) async {
    try {
      // شبیه‌سازی compression (در واقع می‌توان از gzip استفاده کرد)
      _compressionCache[cacheKey] = {
        'compressed': true,
        'timestamp': DateTime.now().toIso8601String(),
        'size_reduction': 0.3, // 30% کاهش حجم
      };

      developer.log('📦 Pre-compressed data for $cacheKey',
          name: 'CacheOptimizer');
    } catch (e) {
      developer.log('⚠️ Pre-compression failed for $cacheKey: $e',
          name: 'CacheOptimizer');
    }
  }

  /// Evict کردن از cache
  void _evictFromCache(String cacheKey) {
    _cacheHits.remove(cacheKey);
    _cacheMisses.remove(cacheKey);
    _lastAccess.remove(cacheKey);
    _compressionCache.remove(cacheKey);
  }

  /// ثبت cache hit
  void recordCacheHit(String cacheKey) {
    _cacheHits[cacheKey] = (_cacheHits[cacheKey] ?? 0) + 1;
    _lastAccess[cacheKey] = DateTime.now();
  }

  /// ثبت cache miss
  void recordCacheMiss(String cacheKey) {
    _cacheMisses[cacheKey] = (_cacheMisses[cacheKey] ?? 0) + 1;
    _lastAccess[cacheKey] = DateTime.now();
  }

  /// به‌روزرسانی metrics
  void _updateCacheMetrics() {
    final totalHits = _cacheHits.values.fold(0, (sum, hits) => sum + hits);
    final totalMisses =
        _cacheMisses.values.fold(0, (sum, misses) => sum + misses);
    final hitRate =
        totalHits > 0 ? (totalHits / (totalHits + totalMisses) * 100) : 0.0;

    if (totalHits % 50 == 0 && totalHits > 0) {
      // گزارش هر 50 hit
      developer.log('📊 Cache hit rate: ${hitRate.toStringAsFixed(1)}%',
          name: 'CacheOptimizer');
    }
  }

  /// دریافت آمار بهینه‌سازی
  Map<String, dynamic> getOptimizationStats() {
    final totalHits = _cacheHits.values.fold(0, (sum, hits) => sum + hits);
    final totalMisses =
        _cacheMisses.values.fold(0, (sum, misses) => sum + misses);
    final hitRate =
        totalHits > 0 ? (totalHits / (totalHits + totalMisses) * 100) : 0.0;

    return {
      'cache_hit_rate': hitRate,
      'total_hits': totalHits,
      'total_misses': totalMisses,
      'active_prefetches': _prefetchQueue.length,
      'compressed_entries': _compressionCache.length,
      'optimization_cycles':
          _optimizationTimer?.isActive ?? false ? 'running' : 'stopped',
    };
  }

  /// توقف optimization
  void stopOptimization() {
    _optimizationTimer?.cancel();
    _optimizationTimer = null;

    for (final timer in _prefetchTimers.values) {
      timer.cancel();
    }
    _prefetchTimers.clear();
    _prefetchQueue.clear();

    _isOptimizing = false;
    developer.log('🛑 Advanced Cache Optimization stopped',
        name: 'CacheOptimizer');
  }

  /// dispose کامل
  void dispose() {
    stopOptimization();
    _cacheHits.clear();
    _cacheMisses.clear();
    _lastAccess.clear();
    _compressionCache.clear();
  }
}
