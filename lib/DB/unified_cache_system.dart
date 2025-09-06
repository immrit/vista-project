import 'dart:async';
import 'dart:io';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import 'advanced_cache_manager.dart';
import 'smart_message_cache.dart';
import 'realtime_cache_manager.dart';
import 'conversation_list_cache.dart';
import 'decryption_cache_manager.dart';
import 'background_cache_sync.dart';
import 'attachment_cache_manager.dart';

/// Unified cache system that integrates all caching layers
class UnifiedCacheSystem {
  static final UnifiedCacheSystem _instance = UnifiedCacheSystem._internal();
  factory UnifiedCacheSystem() => _instance;
  UnifiedCacheSystem._internal();

  // Cache system components
  final AdvancedCacheManager _advancedCache = AdvancedCacheManager();
  final SmartMessageCache _smartCache = SmartMessageCache();
  final RealtimeCacheManager _realtimeCache = RealtimeCacheManager();
  final ConversationListCache _conversationCache = ConversationListCache();
  final DecryptionCacheManager _decryptionCache = DecryptionCacheManager();
  final BackgroundCacheSync _backgroundSync = BackgroundCacheSync();
  final AttachmentCacheManager _attachmentCache = AttachmentCacheManager();

  bool _isInitialized = false;
  final Map<String, dynamic> _systemHealth = {};

  /// Initialize the unified cache system
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing Unified Cache System...');

    try {
      // Initialize all cache components
      await Future.wait([
        _advancedCache.initialize(),
        _smartCache.initialize(),
        _realtimeCache.initialize(),
        _conversationCache.initialize(),
        _decryptionCache.initialize(),
        _backgroundSync.initialize(),
        _attachmentCache.initialize(),
      ]);

      // Start system monitoring
      _startSystemMonitoring();

      _isInitialized = true;
      print('✅ Unified Cache System initialized successfully');

      // Perform initial health check
      await _performSystemHealthCheck();
    } catch (e) {
      print('❌ Failed to initialize Unified Cache System: $e');
      rethrow;
    }
  }

  /// Message Operations

  /// Cache a message with smart optimizations
  Future<void> cacheMessage(MessageModel message,
      {bool enablePrefetch = true}) async {
    await _smartCache.cacheMessage(message, enablePrefetch: enablePrefetch);
  }

  /// Get cached message with intelligent loading
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    return await _smartCache.getMessage(conversationId, messageId);
  }

  /// Cache multiple messages efficiently
  Future<void> cacheMessages(
      List<MessageModel> messages, String conversationId) async {
    await _smartCache.cacheMessages(messages, conversationId);
  }

  /// Get conversation messages with smart pagination
  Future<List<MessageModel>> getConversationMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
    bool enablePrefetch = true,
  }) async {
    return await _smartCache.getConversationMessages(
      conversationId,
      limit: limit,
      offset: offset,
      enablePrefetch: enablePrefetch,
    );
  }

  /// Conversation Operations

  /// Cache conversation
  Future<void> cacheConversation(ConversationModel conversation) async {
    await _conversationCache.cacheConversation(conversation);
  }

  /// Get cached conversation
  Future<ConversationModel?> getConversation(String conversationId) async {
    return await _conversationCache.getConversation(conversationId);
  }

  /// Get conversation list with filtering
  Future<List<ConversationModel>> getConversationList({
    ConversationFilter filter = ConversationFilter.all,
    int? limit,
    int? offset,
    String? searchQuery,
  }) async {
    return await _conversationCache.getConversationList(
      filter: filter,
      limit: limit,
      offset: offset,
      searchQuery: searchQuery,
    );
  }

  /// Update conversation
  Future<void> updateConversation(ConversationModel conversation) async {
    await _conversationCache.updateConversation(conversation);
  }

  /// Update unread count
  Future<void> updateUnreadCount(String conversationId, int count) async {
    await _conversationCache.updateUnreadCount(conversationId, count);
  }

  /// Get total unread count
  int getTotalUnreadCount() {
    return _conversationCache.getTotalUnreadCount();
  }

  /// Real-time Operations

  /// Subscribe to real-time updates
  Future<void> subscribeToConversation(
      String conversationId, String userId) async {
    await _realtimeCache.subscribeToConversation(conversationId, userId);
  }

  /// Unsubscribe from conversation
  Future<void> unsubscribeFromConversation(String conversationId) async {
    await _realtimeCache.unsubscribeFromConversation(conversationId);
  }

  /// Handle incoming message
  Future<void> handleIncomingMessage(MessageModel message) async {
    await _realtimeCache.handleMessageUpdate(message);
  }

  /// Handle incoming conversation update
  Future<void> handleIncomingConversationUpdate(
      ConversationModel conversation) async {
    await _realtimeCache.handleConversationUpdate(conversation);
  }

  /// Decryption Operations

  /// Cache decryption result
  Future<void> cacheDecryptionResult(String encryptedContent,
      String decryptedContent, String conversationId) async {
    await _decryptionCache.cacheDecryptionResult(
        encryptedContent, decryptedContent, conversationId);
  }

  /// Get cached decryption result
  Future<String?> getDecryptionResult(
      String encryptedContent, String conversationId) async {
    return await _decryptionCache.getDecryptionResult(
        encryptedContent, conversationId);
  }

  /// Decrypt with intelligent caching
  Future<String?> decryptWithCache(
    String encryptedContent,
    String conversationId,
    Future<String?> Function() decryptFunction,
  ) async {
    return await _decryptionCache.decryptWithCache(
      encryptedContent,
      conversationId,
      decryptFunction,
    );
  }

  /// Attachment Operations

  /// Cache attachment
  Future<void> cacheAttachment(
      String url, String messageId, String conversationId) async {
    await _attachmentCache.cacheAttachment(url, messageId, conversationId);
  }

  /// Get cached attachment
  Future<File?> getCachedAttachment(String url) async {
    return await _attachmentCache.getCachedAttachment(url);
  }

  /// Preload attachments
  Future<void> preloadAttachments(
      List<MessageModel> messages, String conversationId) async {
    await _attachmentCache.preloadAttachments(messages, conversationId);
  }

  /// System Management

  /// Perform full system synchronization
  Future<void> performFullSync() async {
    await _backgroundSync.performFullSync();
  }

  /// Perform intelligent cleanup
  Future<void> performIntelligentCleanup() async {
    await _backgroundSync.performIntelligentCleanup();
  }

  /// Force immediate sync
  Future<void> forceSync() async {
    await _backgroundSync.forceSync();
  }

  /// Get comprehensive system statistics
  Map<String, dynamic> getSystemStatistics() {
    return {
      'system_health': _systemHealth,
      'advanced_cache': _advancedCache.getCacheStatistics(),
      'smart_cache': _smartCache.getCacheInsights(),
      'realtime_cache': _realtimeCache.getRealtimeStatistics(),
      'conversation_cache': _conversationCache.getCacheStatistics(),
      'decryption_cache': _decryptionCache.getDecryptionStatistics(),
      'background_sync': _backgroundSync.getSyncStatistics(),
      'attachment_cache': _attachmentCache.getCacheStatistics(),
      'total_unread_count': getTotalUnreadCount(),
    };
  }

  /// Get system recommendations
  Map<String, dynamic> getSystemRecommendations() {
    final stats = getSystemStatistics();
    final recommendations = <String>[];

    // Analyze cache performance
    final advancedStats = stats['advanced_cache'] as Map<String, dynamic>;
    final smartStats = stats['smart_cache'] as Map<String, dynamic>;
    final decryptionStats = stats['decryption_cache'] as Map<String, dynamic>;

    if ((advancedStats['hit_rate'] as double) < 0.7) {
      recommendations.add(
          'Advanced cache hit rate is low. Consider increasing memory cache size.');
    }

    if ((smartStats['statistics']['hit_rate'] as double) < 0.75) {
      recommendations
          .add('Smart cache hit rate is low. Consider optimizing prefetching.');
    }

    if ((decryptionStats['hit_rate'] as double) < 0.8) {
      recommendations.add(
          'Decryption cache hit rate is low. Consider increasing decryption cache size.');
    }

    final memorySize = advancedStats['memory_cache_size'] as int;
    if (memorySize > 800) {
      recommendations.add(
          'Memory cache is getting full. Consider cleanup or size increase.');
    }

    return {
      'recommendations': recommendations,
      'statistics': stats,
    };
  }

  /// Optimize entire system
  Future<void> optimizeSystem() async {
    print('🔧 Optimizing Unified Cache System...');

    await Future.wait([
      _smartCache.optimizeCache(),
      _backgroundSync.performIntelligentCleanup(),
      _attachmentCache.cleanupOldAttachments(),
      _decryptionCache.clearExpiredEntries(),
    ]);

    await _performSystemHealthCheck();

    print('✅ System optimization completed');
  }

  /// Reset entire system
  Future<void> resetSystem() async {
    print('🔄 Resetting Unified Cache System...');

    await Future.wait([
      _backgroundSync.reset(),
      _attachmentCache.clearAllCache(),
    ]);

    _systemHealth.clear();

    print('✅ System reset completed');
  }

  /// Start system monitoring
  void _startSystemMonitoring() {
    Timer.periodic(const Duration(minutes: 10), (timer) {
      _performSystemHealthCheck();
    });
  }

  /// Perform system health check
  Future<void> _performSystemHealthCheck() async {
    try {
      final stats = getSystemStatistics();

      // Check overall system health
      final issues = <String>[];

      // Memory usage check
      final memorySize = (stats['advanced_cache']
          as Map<String, dynamic>)['memory_cache_size'] as int;
      if (memorySize > 900) {
        issues.add('High memory usage');
      }

      // Cache hit rate checks
      final advancedHitRate = (stats['advanced_cache']
          as Map<String, dynamic>)['hit_rate'] as double;
      if (advancedHitRate < 0.6) {
        issues.add('Low cache hit rate');
      }

      // Update system health
      _systemHealth['last_check'] = DateTime.now().toIso8601String();
      _systemHealth['status'] = issues.isEmpty ? 'healthy' : 'warning';
      _systemHealth['issues'] = issues;
      _systemHealth['uptime'] = _isInitialized ? 'active' : 'inactive';

      if (issues.isNotEmpty) {
        print('⚠️ System health issues detected: ${issues.join(', ')}');
      } else {
        print('✅ System health check passed');
      }
    } catch (e) {
      print('❌ System health check failed: $e');
      _systemHealth['status'] = 'error';
      _systemHealth['last_error'] = e.toString();
    }
  }

  /// Dispose all resources
  void dispose() {
    _backgroundSync.dispose();
    _realtimeCache.dispose();
    _attachmentCache.dispose();
    _decryptionCache.dispose();

    print('🧹 Unified Cache System disposed');
  }
}
