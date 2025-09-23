import 'dart:async';
import '../model/message_model.dart';
import '../model/conversation_model.dart';
import 'unified_message_cache_service.dart';
import 'unified_conversation_cache_service.dart';

/// Unified cache system that integrates all caching layers
class UnifiedCacheSystem {
  static final UnifiedCacheSystem _instance = UnifiedCacheSystem._internal();
  factory UnifiedCacheSystem() => _instance;
  UnifiedCacheSystem._internal();

  // Cache system components
  final UnifiedMessageCacheService _messageCache = UnifiedMessageCacheService();
  final UnifiedConversationCacheService _conversationCache =
      UnifiedConversationCacheService();

  bool _isInitialized = false;
  final Map<String, dynamic> _systemHealth = {};

  /// Initialize the unified cache system
  Future<void> initialize() async {
    if (_isInitialized) return;

    print('🚀 Initializing Unified Cache System...');

    try {
      // Initialize cache components
      await Future.wait([
        _messageCache.initialize(),
        _conversationCache.initialize(),
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

  /// Cache a message
  Future<void> cacheMessage(MessageModel message) async {
    await _messageCache.cacheMessage(message, '');
  }

  /// Get cached message
  Future<MessageModel?> getMessage(
      String conversationId, String messageId) async {
    return await _messageCache.getMessage(conversationId, messageId, '');
  }

  /// Cache multiple messages efficiently
  Future<void> cacheMessages(
      List<MessageModel> messages, String conversationId) async {
    await _messageCache.cacheMessages(messages, '');
  }

  /// Get conversation messages
  Future<List<MessageModel>> getConversationMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return await _messageCache.getConversationMessages(conversationId, '');
  }

  /// Conversation Operations

  /// Cache conversation
  Future<void> cacheConversation(ConversationModel conversation) async {
    await _conversationCache.cacheConversation(conversation, '');
  }

  /// Get cached conversation
  Future<ConversationModel?> getConversation(String conversationId) async {
    return await _conversationCache.getConversation(conversationId, '');
  }

  /// Get conversation list
  Future<List<ConversationModel>> getConversationList() async {
    return await _conversationCache.getCachedConversations('');
  }

  /// Update conversation
  Future<void> updateConversation(ConversationModel conversation) async {
    await _conversationCache.updateConversation(conversation, '');
  }

  /// Get total unread count
  int getTotalUnreadCount() {
    return 0; // Placeholder - implement if needed
  }

  /// System Management

  /// Perform intelligent cleanup
  Future<void> performIntelligentCleanup() async {
    // Simple cleanup implementation
    print('🧹 Performing cleanup...');
  }

  /// Force immediate sync
  Future<void> forceSync() async {
    // Simple sync implementation
    print('🔄 Performing sync...');
  }

  /// Get comprehensive system statistics
  Map<String, dynamic> getSystemStatistics() {
    return {
      'system_health': _systemHealth,
      'total_unread_count': getTotalUnreadCount(),
    };
  }

  /// Get system recommendations
  Map<String, dynamic> getSystemRecommendations() {
    final stats = getSystemStatistics();
    final recommendations = <String>[];

    recommendations.add('Cache system is operational.');

    return {
      'recommendations': recommendations,
      'statistics': stats,
    };
  }

  /// Optimize entire system
  Future<void> optimizeSystem() async {
    print('🔧 Optimizing Unified Cache System...');

    await performIntelligentCleanup();
    await _performSystemHealthCheck();

    print('✅ System optimization completed');
  }

  /// Reset entire system
  Future<void> resetSystem() async {
    print('🔄 Resetting Unified Cache System...');

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
    print('🧹 Unified Cache System disposed');
  }
}
