import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../model/message_model.dart';
import 'advanced_cache_manager.dart';

/// Advanced attachment and media file cache manager
class AttachmentCacheManager {
  static final AttachmentCacheManager _instance =
      AttachmentCacheManager._internal();
  factory AttachmentCacheManager() => _instance;
  AttachmentCacheManager._internal();

  final AdvancedCacheManager _cacheManager = AdvancedCacheManager();

  // Attachment cache configuration
  static const Duration _attachmentTTL = Duration(days: 30);
  static const int _maxCacheSizeMB = 500; // 500MB cache limit
  static const String _cacheDirectoryName = 'attachments';

  // Cache metadata
  final Map<String, AttachmentMetadata> _attachmentMetadata = {};
  final Map<String, File> _localFileCache = {};

  // Performance tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _bytesDownloaded = 0;
  int _bytesServed = 0;

  Directory? _cacheDirectory;
  bool _isInitialized = false;

  /// Initialize attachment cache
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _cacheManager.initialize();
    await _initializeCacheDirectory();
    await _loadCacheMetadata();
    _startPeriodicCleanup();

    _isInitialized = true;
    print('✅ Attachment Cache Manager initialized');
  }

  /// Cache attachment file
  Future<File?> cacheAttachment(
      String url, String messageId, String conversationId) async {
    try {
      final cacheKey = _generateCacheKey(url);
      final localPath = await _getLocalPath(cacheKey);

      // Check if file already exists
      final file = File(localPath);
      if (await file.exists()) {
        _cacheHits++;
        _localFileCache[cacheKey] = file;
        return file;
      }

      // Download and cache the file
      final downloadedFile =
          await _downloadAndCacheFile(url, cacheKey, messageId, conversationId);
      if (downloadedFile != null) {
        _cacheHits++;
        _localFileCache[cacheKey] = downloadedFile;
      }

      return downloadedFile;
    } catch (e) {
      print('❌ Error caching attachment $url: $e');
      _cacheMisses++;
      return null;
    }
  }

  /// Get cached attachment
  Future<File?> getCachedAttachment(String url) async {
    final cacheKey = _generateCacheKey(url);

    // Check memory cache first
    if (_localFileCache.containsKey(cacheKey)) {
      final file = _localFileCache[cacheKey]!;
      if (await file.exists()) {
        _cacheHits++;
        _bytesServed += await file.length();
        return file;
      } else {
        // File was deleted, remove from cache
        _localFileCache.remove(cacheKey);
        _attachmentMetadata.remove(cacheKey);
      }
    }

    // Check if file exists on disk
    final localPath = await _getLocalPath(cacheKey);
    final file = File(localPath);

    if (await file.exists()) {
      // Update memory cache
      _localFileCache[cacheKey] = file;
      _cacheHits++;
      _bytesServed += await file.length();
      return file;
    }

    _cacheMisses++;
    return null;
  }

  /// Preload attachments for better UX
  Future<void> preloadAttachments(
      List<MessageModel> messages, String conversationId) async {
    final attachmentMessages = messages
        .where(
            (msg) => msg.attachmentUrl != null && msg.attachmentUrl!.isNotEmpty)
        .toList();

    if (attachmentMessages.isEmpty) return;

    // Preload attachments in background
    for (final message in attachmentMessages) {
      if (message.attachmentUrl != null) {
        // Check if already cached
        final cached = await getCachedAttachment(message.attachmentUrl!);
        if (cached == null) {
          // Preload in background
          unawaited(cacheAttachment(
              message.attachmentUrl!, message.id, conversationId));
        }
      }
    }

    print('🔄 Preloading ${attachmentMessages.length} attachments');
  }

  /// Download and cache file
  Future<File?> _downloadAndCacheFile(String url, String cacheKey,
      String messageId, String conversationId) async {
    try {
      // Download file (placeholder - would integrate with HTTP client)
      final file = await _downloadFile(url, cacheKey);

      if (file != null) {
        // Create metadata
        final metadata = AttachmentMetadata(
          url: url,
          cacheKey: cacheKey,
          localPath: file.path,
          messageId: messageId,
          conversationId: conversationId,
          fileSize: await file.length(),
          downloadTime: DateTime.now(),
          lastAccessTime: DateTime.now(),
        );

        // Cache metadata
        _attachmentMetadata[cacheKey] = metadata;
        await _saveCacheMetadata();

        // Update statistics
        _bytesDownloaded += metadata.fileSize;

        print(
            '📥 Downloaded and cached attachment: $cacheKey (${metadata.fileSize} bytes)');
      }

      return file;
    } catch (e) {
      print('❌ Error downloading attachment $url: $e');
      return null;
    }
  }

  /// Download file from URL (placeholder implementation)
  Future<File?> _downloadFile(String url, String cacheKey) async {
    // This would integrate with HTTP client to download the file
    // For now, return null as placeholder
    return null;
  }

  /// Get attachment metadata
  AttachmentMetadata? getAttachmentMetadata(String url) {
    final cacheKey = _generateCacheKey(url);
    return _attachmentMetadata[cacheKey];
  }

  /// Update last access time
  Future<void> updateAccessTime(String url) async {
    final cacheKey = _generateCacheKey(url);
    final metadata = _attachmentMetadata[cacheKey];

    if (metadata != null) {
      final updatedMetadata = metadata.copyWith(lastAccessTime: DateTime.now());
      _attachmentMetadata[cacheKey] = updatedMetadata;
      await _saveCacheMetadata();
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    int totalSize = 0;

    for (final metadata in _attachmentMetadata.values) {
      final file = File(metadata.localPath);
      if (await file.exists()) {
        totalSize += await file.length();
      }
    }

    return totalSize;
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStatistics() async {
    final cacheSize = await getCacheSize();
    final cacheSizeMB = (cacheSize / (1024 * 1024)).toStringAsFixed(2);

    final totalRequests = _cacheHits + _cacheMisses;
    final hitRate = totalRequests > 0 ? _cacheHits / totalRequests : 0.0;

    return {
      'cache_size_mb': cacheSizeMB,
      'cache_size_bytes': cacheSize,
      'cached_files': _attachmentMetadata.length,
      'memory_cache_size': _localFileCache.length,
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hit_rate': hitRate,
      'bytes_downloaded': _bytesDownloaded,
      'bytes_served': _bytesServed,
    };
  }

  /// Clean up old attachments
  Future<void> cleanupOldAttachments() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _attachmentMetadata.entries) {
      final metadata = entry.value;
      final age = now.difference(metadata.lastAccessTime);

      // Remove files older than TTL or if cache size limit exceeded
      if (age > _attachmentTTL) {
        expiredKeys.add(entry.key);
      }
    }

    // Also check cache size limit
    final cacheSize = await getCacheSize();
    if (cacheSize > _maxCacheSizeMB * 1024 * 1024) {
      // Sort by last access time and remove oldest files
      final sortedEntries = _attachmentMetadata.entries.toList()
        ..sort(
            (a, b) => a.value.lastAccessTime.compareTo(b.value.lastAccessTime));

      int sizeToFree =
          cacheSize - (_maxCacheSizeMB * 1024 * 1024 * 0.8).toInt(); // Free 20%
      int currentSize = cacheSize;

      for (final entry in sortedEntries) {
        if (currentSize <= _maxCacheSizeMB * 1024 * 1024 * 0.8) break;

        if (!expiredKeys.contains(entry.key)) {
          expiredKeys.add(entry.key);
          final file = File(entry.value.localPath);
          if (await file.exists()) {
            currentSize -= await file.length();
          }
        }
      }
    }

    // Remove expired files
    for (final key in expiredKeys) {
      final metadata = _attachmentMetadata[key];
      if (metadata != null) {
        final file = File(metadata.localPath);
        if (await file.exists()) {
          await file.delete();
        }
        _attachmentMetadata.remove(key);
        _localFileCache.remove(key);
      }
    }

    if (expiredKeys.isNotEmpty) {
      await _saveCacheMetadata();
      print('🧹 Cleaned up ${expiredKeys.length} old attachments');
    }
  }

  /// Clear all cached attachments
  Future<void> clearAllCache() async {
    for (final metadata in _attachmentMetadata.values) {
      final file = File(metadata.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    _attachmentMetadata.clear();
    _localFileCache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
    _bytesDownloaded = 0;
    _bytesServed = 0;

    await _saveCacheMetadata();
    print('🗑️ Cleared all attachment cache');
  }

  /// Initialize cache directory
  Future<void> _initializeCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = Directory('${appDir.path}/$_cacheDirectoryName');

    if (!await _cacheDirectory!.exists()) {
      await _cacheDirectory!.create(recursive: true);
    }
  }

  /// Get local file path for cache key
  Future<String> _getLocalPath(String cacheKey) async {
    return '${_cacheDirectory!.path}/$cacheKey';
  }

  /// Generate cache key from URL
  String _generateCacheKey(String url) {
    return sha256.convert(utf8.encode(url)).toString().substring(0, 32);
  }

  /// Load cache metadata from disk
  Future<void> _loadCacheMetadata() async {
    try {
      final metadataFile = File('${_cacheDirectory!.path}/metadata.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;

        for (final entry in data.entries) {
          _attachmentMetadata[entry.key] =
              AttachmentMetadata.fromJson(entry.value);
        }

        print(
            '📋 Loaded attachment metadata for ${_attachmentMetadata.length} files');
      }
    } catch (e) {
      print('❌ Error loading attachment metadata: $e');
    }
  }

  /// Save cache metadata to disk
  Future<void> _saveCacheMetadata() async {
    try {
      final metadataFile = File('${_cacheDirectory!.path}/metadata.json');
      final data = _attachmentMetadata
          .map((key, metadata) => MapEntry(key, metadata.toJson()));

      await metadataFile.writeAsString(json.encode(data));
    } catch (e) {
      print('❌ Error saving attachment metadata: $e');
    }
  }

  /// Start periodic cleanup
  void _startPeriodicCleanup() {
    Timer.periodic(const Duration(hours: 6), (timer) {
      cleanupOldAttachments();
    });
  }

  /// Dispose resources
  void dispose() {
    _localFileCache.clear();
    _attachmentMetadata.clear();
  }
}

/// Attachment metadata
class AttachmentMetadata {
  final String url;
  final String cacheKey;
  final String localPath;
  final String messageId;
  final String conversationId;
  final int fileSize;
  final DateTime downloadTime;
  final DateTime lastAccessTime;

  AttachmentMetadata({
    required this.url,
    required this.cacheKey,
    required this.localPath,
    required this.messageId,
    required this.conversationId,
    required this.fileSize,
    required this.downloadTime,
    required this.lastAccessTime,
  });

  AttachmentMetadata copyWith({
    String? url,
    String? cacheKey,
    String? localPath,
    String? messageId,
    String? conversationId,
    int? fileSize,
    DateTime? downloadTime,
    DateTime? lastAccessTime,
  }) {
    return AttachmentMetadata(
      url: url ?? this.url,
      cacheKey: cacheKey ?? this.cacheKey,
      localPath: localPath ?? this.localPath,
      messageId: messageId ?? this.messageId,
      conversationId: conversationId ?? this.conversationId,
      fileSize: fileSize ?? this.fileSize,
      downloadTime: downloadTime ?? this.downloadTime,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'cacheKey': cacheKey,
      'localPath': localPath,
      'messageId': messageId,
      'conversationId': conversationId,
      'fileSize': fileSize,
      'downloadTime': downloadTime.toIso8601String(),
      'lastAccessTime': lastAccessTime.toIso8601String(),
    };
  }

  factory AttachmentMetadata.fromJson(Map<String, dynamic> json) {
    return AttachmentMetadata(
      url: json['url'],
      cacheKey: json['cacheKey'],
      localPath: json['localPath'],
      messageId: json['messageId'],
      conversationId: json['conversationId'],
      fileSize: json['fileSize'],
      downloadTime: DateTime.parse(json['downloadTime']),
      lastAccessTime: DateTime.parse(json['lastAccessTime']),
    );
  }
}

