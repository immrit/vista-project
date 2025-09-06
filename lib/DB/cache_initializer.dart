import 'package:flutter/foundation.dart';
import 'unified_cache_system.dart';

/// Cache system initializer for app startup
class CacheInitializer {
  static final CacheInitializer _instance = CacheInitializer._internal();
  factory CacheInitializer() => _instance;
  CacheInitializer._internal();

  final UnifiedCacheSystem _cacheSystem = UnifiedCacheSystem();
  bool _isInitialized = false;

  /// Initialize all cache systems
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🚀 Initializing Cache Systems...');

      // Initialize unified cache system
      await _cacheSystem.initialize();

      _isInitialized = true;
      print('✅ All cache systems initialized successfully');

      // Log initial statistics
      _logInitialStatistics();
    } catch (e) {
      print('❌ Failed to initialize cache systems: $e');
      rethrow;
    }
  }

  /// Get unified cache system instance
  UnifiedCacheSystem get cacheSystem => _cacheSystem;

  /// Check if cache systems are initialized
  bool get isInitialized => _isInitialized;

  /// Perform initial cache optimization
  Future<void> performInitialOptimization() async {
    try {
      await _cacheSystem.optimizeSystem();
      print('✅ Initial cache optimization completed');
    } catch (e) {
      print('❌ Initial cache optimization failed: $e');
    }
  }

  /// Log initial cache statistics
  void _logInitialStatistics() {
    final stats = _cacheSystem.getSystemStatistics();

    print('📊 Initial Cache Statistics:');
    print(
        '  - Advanced Cache: ${stats['advanced_cache']['memory_cache_size']} items');
    print(
        '  - Conversation Cache: ${stats['conversation_cache']['memory_conversations']} conversations');
    print('  - Total Unread: ${stats['total_unread_count']} messages');
    print('  - System Health: ${stats['system_health']['status']}');
  }

  /// Reset all cache systems
  Future<void> resetAll() async {
    await _cacheSystem.resetSystem();
    _isInitialized = false;
    print('🔄 All cache systems reset');
  }
}

