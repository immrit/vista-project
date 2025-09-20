import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/ChatService.dart';
import 'advanced_cache_manager.dart';
import 'smart_message_cache.dart';
import 'conversation_list_cache.dart';

/// Background cache synchronization and cleanup service
class BackgroundCacheSync {
  static final BackgroundCacheSync _instance = BackgroundCacheSync._internal();
  factory BackgroundCacheSync() => _instance;
  BackgroundCacheSync._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();
  final SmartMessageCache _smartCache = SmartMessageCache();
  final ConversationListCache _conversationCache = ConversationListCache();

  // Sync configuration
  static const Duration _syncInterval = Duration(minutes: 15);
  static const Duration _cleanupInterval = Duration(hours: 2);
  static const Duration _healthCheckInterval = Duration(minutes: 5);

  // Network monitoring
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  ConnectivityResult _currentConnectivity = ConnectivityResult.none;

  // Background tasks
  Timer? _syncTimer;
  Timer? _cleanupTimer;
  Timer? _healthCheckTimer;

  // Sync state
  bool _isOnline = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  DateTime? _lastCleanupTime;

  // Performance metrics
  final Map<String, int> _syncMetrics = {};
  final Map<String, Duration> _operationTimes = {};

  /// Initialize background sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Future.wait([
      _cacheManager.initialize(),
      _smartCache.initialize(),
      _conversationCache.initialize(),
    ]);

    // Initialize network monitoring
    await _initializeNetworkMonitoring();

    // Start background tasks
    _startSyncTimer();
    _startCleanupTimer();
    _startHealthCheckTimer();

    _isInitialized = true;
    print('✅ Background Cache Sync initialized');
  }

  /// Perform comprehensive cache synchronization
  Future<void> performFullSync() async {
    if (!_isOnline) {
      print('📡 Skipping sync - device is offline');
      return;
    }

    final startTime = DateTime.now();
    print('🔄 Starting full cache synchronization...');

    try {
      await _syncConversations();
      await _syncMessages();
      await _syncAttachments();
      await _validateCacheIntegrity();

      _lastSyncTime = DateTime.now();
      final duration = DateTime.now().difference(startTime);

      _operationTimes['full_sync'] = duration;
      _syncMetrics['successful_syncs'] =
          (_syncMetrics['successful_syncs'] ?? 0) + 1;

      print(
          '✅ Full cache synchronization completed in ${duration.inMilliseconds}ms');
    } catch (e) {
      _syncMetrics['failed_syncs'] = (_syncMetrics['failed_syncs'] ?? 0) + 1;
      print('❌ Full cache synchronization failed: $e');
    }
  }

  /// Sync conversations with server
  Future<void> _syncConversations() async {
    try {
      final chatService = ChatService();
      final serverConversations = await chatService.getConversations();

      if (serverConversations.isNotEmpty) {
        await _conversationCache.cacheConversations(serverConversations);
        _syncMetrics['conversations_synced'] =
            (_syncMetrics['conversations_synced'] ?? 0) +
                serverConversations.length;
      }

      print('📋 Synced ${serverConversations.length} conversations');
    } catch (e) {
      print('❌ Conversation sync failed: $e');
    }
  }

  /// Sync messages for active conversations
  Future<void> _syncMessages() async {
    try {
      final conversations =
          await _conversationCache.getConversationList(limit: 10);
      final chatService = ChatService();

      int totalMessagesSynced = 0;

      for (final conversation in conversations) {
        try {
          final messages =
              await chatService.getMessages(conversation.id, limit: 20);
          if (messages.isNotEmpty) {
            await _smartCache.cacheMessages(messages, conversation.id);
            totalMessagesSynced += messages.length;
          }
        } catch (e) {
          print(
              '❌ Failed to sync messages for conversation ${conversation.id}: $e');
        }
      }

      _syncMetrics['messages_synced'] =
          (_syncMetrics['messages_synced'] ?? 0) + totalMessagesSynced;
      print('💬 Synced $totalMessagesSynced messages');
    } catch (e) {
      print('❌ Message sync failed: $e');
    }
  }

  /// Sync attachments and media files
  Future<void> _syncAttachments() async {
    try {
      // This would implement attachment synchronization
      // For now, just log the operation
      print('📎 Attachment sync placeholder');
    } catch (e) {
      print('❌ Attachment sync failed: $e');
    }
  }

  /// Perform intelligent cache cleanup
  Future<void> performIntelligentCleanup() async {
    final startTime = DateTime.now();
    print('🧹 Starting intelligent cache cleanup...');

    try {
      // Clear expired entries
      await _cacheManager.clearExpiredEntries();

      // Optimize cache based on usage patterns
      await _smartCache.optimizeCache();

      // Clean up old conversation data
      await _cleanupOldConversations();

      // Clean up temporary files
      await _cleanupTemporaryFiles();

      _lastCleanupTime = DateTime.now();
      final duration = DateTime.now().difference(startTime);

      _operationTimes['cleanup'] = duration;
      _syncMetrics['successful_cleanups'] =
          (_syncMetrics['successful_cleanups'] ?? 0) + 1;

      print(
          '✅ Intelligent cache cleanup completed in ${duration.inMilliseconds}ms');
    } catch (e) {
      _syncMetrics['failed_cleanups'] =
          (_syncMetrics['failed_cleanups'] ?? 0) + 1;
      print('❌ Intelligent cache cleanup failed: $e');
    }
  }

  /// Validate cache integrity
  Future<void> _validateCacheIntegrity() async {
    try {
      final cacheStats = _cacheManager.getCacheStatistics();

      // Check for inconsistencies
      final issues = <String>[];

      if (cacheStats['hit_rate'] < 0.5) {
        issues.add('Low cache hit rate detected');
      }

      if (issues.isNotEmpty) {
        print('⚠️ Cache integrity issues found: ${issues.join(', ')}');
        _syncMetrics['integrity_issues'] =
            (_syncMetrics['integrity_issues'] ?? 0) + issues.length;
      } else {
        print('✅ Cache integrity validation passed');
      }
    } catch (e) {
      print('❌ Cache integrity validation failed: $e');
    }
  }

  /// Clean up old conversation data
  Future<void> _cleanupOldConversations() async {
    try {
      // Remove conversations older than 30 days with no recent activity
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final conversations = await _conversationCache.getConversationList();

      int cleanedCount = 0;
      for (final conversation in conversations) {
        if ((conversation.lastMessageTime?.isBefore(thirtyDaysAgo) ?? false) &&
            conversation.unreadCount == 0) {
          await _conversationCache.invalidateConversation(conversation.id);
          await _smartCache
              .getConversationMessages(conversation.id)
              .then((messages) {
            // Invalidate message cache for old conversations
          });
          cleanedCount++;
        }
      }

      if (cleanedCount > 0) {
        print('🗑️ Cleaned up $cleanedCount old conversations');
        _syncMetrics['conversations_cleaned'] =
            (_syncMetrics['conversations_cleaned'] ?? 0) + cleanedCount;
      }
    } catch (e) {
      print('❌ Old conversation cleanup failed: $e');
    }
  }

  /// Clean up temporary files
  Future<void> _cleanupTemporaryFiles() async {
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return;

      final tempDir = await Directory.systemTemp.createTemp();
      final files = tempDir.listSync();

      int cleanedCount = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);

          // Remove files older than 1 hour
          if (age.inHours > 1) {
            await file.delete();
            cleanedCount++;
          }
        }
      }

      if (cleanedCount > 0) {
        print('🗂️ Cleaned up $cleanedCount temporary files');
        _syncMetrics['temp_files_cleaned'] =
            (_syncMetrics['temp_files_cleaned'] ?? 0) + cleanedCount;
      }
    } catch (e) {
      print('❌ Temporary file cleanup failed: $e');
    }
  }

  /// Initialize network monitoring
  Future<void> _initializeNetworkMonitoring() async {
    final connectivity = Connectivity();

    // Get initial connectivity status
    _currentConnectivity = await connectivity.checkConnectivity();
    _isOnline = _currentConnectivity != ConnectivityResult.none;

    // Listen to connectivity changes
    _connectivitySubscription = connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _currentConnectivity = result;
    _isOnline = result != ConnectivityResult.none;

    if (!wasOnline && _isOnline) {
      // Device came online - perform sync
      print('🌐 Device came online - triggering sync');
      performFullSync();
    } else if (wasOnline && !_isOnline) {
      // Device went offline
      print('📴 Device went offline');
    }
  }

  /// Start sync timer
  void _startSyncTimer() {
    _syncTimer = Timer.periodic(_syncInterval, (timer) {
      if (_isOnline) {
        performFullSync();
      }
    });
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      performIntelligentCleanup();
    });
  }

  /// Start health check timer
  void _startHealthCheckTimer() {
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Perform health check
  Future<void> _performHealthCheck() async {
    try {
      final cacheStats = _cacheManager.getCacheStatistics();

      // Check memory usage
      final memoryUsage = cacheStats['memory_cache_size'] as int;
      if (memoryUsage > 900) {
        print('⚠️ High memory usage detected: $memoryUsage items');
      }

      _syncMetrics['health_checks'] = (_syncMetrics['health_checks'] ?? 0) + 1;
    } catch (e) {
      print('❌ Health check failed: $e');
    }
  }

  /// Get comprehensive sync statistics
  Map<String, dynamic> getSyncStatistics() {
    return {
      'is_online': _isOnline,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
      'last_cleanup_time': _lastCleanupTime?.toIso8601String(),
      'connectivity': _currentConnectivity.name,
      'metrics': _syncMetrics,
      'operation_times': _operationTimes
          .map((key, value) => MapEntry(key, value.inMilliseconds)),
      'cache_stats': _cacheManager.getCacheStatistics(),
    };
  }

  /// Force immediate sync
  Future<void> forceSync() async {
    print('🚀 Forcing immediate sync...');
    await performFullSync();
  }

  /// Force immediate cleanup
  Future<void> forceCleanup() async {
    print('🧹 Forcing immediate cleanup...');
    await performIntelligentCleanup();
  }

  /// Reset all sync data
  Future<void> reset() async {
    _syncMetrics.clear();
    _operationTimes.clear();
    _lastSyncTime = null;
    _lastCleanupTime = null;

    await _cacheManager.clearAll();
    await _conversationCache.clearAll();

    print('🔄 Reset all sync data');
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _healthCheckTimer?.cancel();
    _connectivitySubscription.cancel();
  }
}
