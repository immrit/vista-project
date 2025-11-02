import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:collection';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Safe CacheManager wrapper that handles SQLite lock errors with retry logic
/// and proper timeout configuration
class SafeCacheManager extends CacheManager with ImageCacheManager {
  SafeCacheManager({
    required Config config,
  }) : super(config);

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 100);
  static const Duration _operationTimeout = Duration(seconds: 30);

  /// Execute cache operation with retry logic for SQLite busy errors
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    int attempts = 0;
    Exception? lastException;

    while (attempts < _maxRetries) {
      try {
        return await operation().timeout(_operationTimeout);
      } on TimeoutException catch (e) {
        lastException = e;
        logInfo(
          '⏱️ Cache operation timeout ($operationName) - attempt ${attempts + 1}/$_maxRetries',
        );
        if (attempts == _maxRetries - 1) {
          break;
        }
        await Future.delayed(_retryDelay * (attempts + 1));
      } catch (e) {
        final errorStr = e.toString();
        if (_isRetryableError(errorStr)) {
          lastException = e is Exception ? e : Exception(e.toString());
          attempts++;
          logInfo(
            '🔄 Retrying cache operation ($operationName) - attempt $attempts/$_maxRetries: $errorStr',
          );
          if (attempts < _maxRetries) {
            // Exponential backoff
            await Future.delayed(_retryDelay * attempts);
            continue;
          }
        } else {
          // Non-retryable error, rethrow immediately
          rethrow;
        }
      }
    }

    logInfo('❌ Cache operation failed after $_maxRetries attempts: $lastException');
    if (lastException != null) {
      throw lastException;
    }
    throw Exception('Cache operation failed after $_maxRetries attempts');
  }

  /// Check if error is retryable (SQLite busy/locked errors)
  bool _isRetryableError(String error) {
    return error.contains('database is locked') ||
        error.contains('SQLITE_BUSY') ||
        error.contains('SQLITE_LOCKED') ||
        error.contains('BEGIN EXCLUSIVE') ||
        error.contains('DatabaseException');
  }

  // Note: getSingleFile is not overridden to avoid signature conflicts between
  // CacheManager and BaseCacheManager. The retry logic will still work for
  // other methods that are properly overridden.

  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) {
    return _executeWithRetry(
      () => super.getFileFromCache(key, ignoreMemCache: ignoreMemCache),
      operationName: 'getFileFromCache',
    );
  }

  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) {
    return _executeWithRetry(
      () => super.downloadFile(
        url,
        key: key,
        authHeaders: authHeaders,
        force: force,
      ),
      operationName: 'downloadFile',
    );
  }

  @override
  Future<void> removeFile(String key) {
    return _executeWithRetry(
      () => super.removeFile(key),
      operationName: 'removeFile',
    );
  }

  @override
  Future<void> emptyCache() {
    return _executeWithRetry(
      () => super.emptyCache(),
      operationName: 'emptyCache',
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await super.dispose();
    } catch (e) {
      logInfo('⚠️ Error disposing SafeCacheManager: $e');
    }
  }
}

/// Factory for creating SafeCacheManager instances with proper configuration
class SafeCacheManagerFactory {
  // Singleton instances per cache type
  static final Map<String, SafeCacheManager> _instances = {};
  static final Map<String, Completer<SafeCacheManager>> _initializers = {};
  static const int _maxConcurrentOperations = 10;
  static int _currentOperations = 0;
  static final Queue<Completer<void>> _operationQueue = Queue<Completer<void>>();

  /// Get or create a SafeCacheManager instance for a specific cache key
  static Future<SafeCacheManager> getInstance({
    required String key,
    int maxNrOfCacheObjects = 200,
    Duration stalePeriod = const Duration(days: 30),
    int maxCacheSize = 100 * 1024 * 1024, // 100 MB default
    String? storePath,
  }) async {
    // Return existing instance if available
    if (_instances.containsKey(key)) {
      return _instances[key]!;
    }

    // If initialization is in progress, wait for it
    if (_initializers.containsKey(key)) {
      return _initializers[key]!.future;
    }

    // Start initialization
    final completer = Completer<SafeCacheManager>();
    _initializers[key] = completer;

    try {
      // Get store path
      String? finalStorePath = storePath;
      if (finalStorePath == null && !kIsWeb) {
        final tempDir = await getTemporaryDirectory();
        finalStorePath = path.join(tempDir.path, 'flutter_cache_manager', key);
      }

      // Create config with proper settings
      final config = Config(
        key,
        stalePeriod: stalePeriod,
        maxNrOfCacheObjects: maxNrOfCacheObjects,
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
        // Use custom file system for better error handling
        fileSystem: IOFileSystem(finalStorePath ?? ''),
      );

      // Create SafeCacheManager instance
      final instance = SafeCacheManager(config: config);

      _instances[key] = instance;
      completer.complete(instance);

      logInfo('✅ SafeCacheManager initialized for key: $key');
      return instance;
    } catch (e) {
      completer.completeError(e);
      _initializers.remove(key);
      logInfo('❌ Failed to initialize SafeCacheManager for $key: $e');
      rethrow;
    } finally {
      _initializers.remove(key);
    }
  }

  /// Wait for available slot before executing operation
  static Future<void> _waitForSlot() async {
    if (_currentOperations < _maxConcurrentOperations) {
      _currentOperations++;
      return;
    }

    final completer = Completer<void>();
    _operationQueue.add(completer);
    await completer.future;
  }

  /// Release operation slot
  static void _releaseSlot() {
    _currentOperations--;
    if (_operationQueue.isNotEmpty) {
      _operationQueue.removeFirst().complete();
    }
  }

  /// Execute operation with concurrency limiting
  static Future<T> executeWithLimiting<T>(
    Future<T> Function() operation,
  ) async {
    await _waitForSlot();
    try {
      return await operation();
    } finally {
      _releaseSlot();
    }
  }

  /// Dispose all cache managers
  static Future<void> disposeAll() async {
    for (final instance in _instances.values) {
      try {
        await instance.dispose();
      } catch (e) {
        logInfo('⚠️ Error disposing cache manager: $e');
      }
    }
    _instances.clear();
    _initializers.clear();
  }
}

/// Pre-configured cache managers for common use cases
class OptimizedCacheManagers {
  // Story image cache
  static Future<SafeCacheManager> get storyCache async {
    return SafeCacheManagerFactory.getInstance(
      key: 'storyImageCache',
      maxNrOfCacheObjects: 100,
      stalePeriod: const Duration(days: 7),
      maxCacheSize: 50 * 1024 * 1024, // 50 MB
    );
  }

  // Post image cache
  static Future<SafeCacheManager> get postCache async {
    return SafeCacheManagerFactory.getInstance(
      key: 'postImageCache',
      maxNrOfCacheObjects: 200,
      stalePeriod: const Duration(days: 30),
      maxCacheSize: 200 * 1024 * 1024, // 200 MB
    );
  }

  // Chat image cache
  static Future<SafeCacheManager> get chatCache async {
    return SafeCacheManagerFactory.getInstance(
      key: 'chat_image_cache',
      maxNrOfCacheObjects: 150,
      stalePeriod: const Duration(days: 30),
      maxCacheSize: 100 * 1024 * 1024, // 100 MB
    );
  }

  // Profile avatar cache
  static Future<SafeCacheManager> get avatarCache async {
    return SafeCacheManagerFactory.getInstance(
      key: 'avatar_cache',
      maxNrOfCacheObjects: 300,
      stalePeriod: const Duration(days: 60),
      maxCacheSize: 50 * 1024 * 1024, // 50 MB
    );
  }

  // Default cache (for general use)
  static SafeCacheManager get defaultCache {
    // Use DefaultCacheManager as fallback, but wrap it
    return SafeCacheManager(
      config: Config(
        'defaultCache',
        stalePeriod: const Duration(days: 7),
        maxNrOfCacheObjects: 200,
        repo: JsonCacheInfoRepository(databaseName: 'defaultCache'),
        fileService: HttpFileService(),
      ),
    );
  }
}
