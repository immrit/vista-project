import '../security/logging_utility.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import 'http_client_factory.dart';

/// مدیریت مرکزی کشینگ پروفایل‌ها با batching هوشمند و real-time updates
class ProfileCacheManager {
  static final ProfileCacheManager _instance = ProfileCacheManager._internal();
  factory ProfileCacheManager() => _instance;
  ProfileCacheManager._internal();

  // کشینگ دو لایه: Memory + Disk
  final Map<String, Map<String, String?>> _memoryCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Map<String, Completer<Map<String, String?>?>> _pendingRequests = {};

  // تنظیمات کشینگ - مدت زمان کش را افزایش دادیم تا در حالت اسکرول پاک نشود
  static const Duration cacheValidityDuration = Duration(hours: 6);
  static const int maxBatchSize = 15; // اندازه batch را افزایش دادیم
  static const Duration batchDelay =
      Duration(milliseconds: 50); // تاخیر را کاهش دادیم

  // Stream برای real-time updates
  final StreamController<Map<String, Map<String, String?>>> _profileUpdates =
      StreamController.broadcast();

  // P3: shared pinned client (cert pinning + god-mode interceptors).
  late final Dio _dio = createApiV1Dio(baseUrl: EnvConfig.apiBaseUrl);

  Stream<Map<String, Map<String, String?>>> get profileUpdates =>
      _profileUpdates.stream;

  /// دسترسی سریع به پروفایل کش‌شده
  Map<String, String?>? getCachedProfile(String userId) {
    // Check if cache is still valid
    final timestamp = _cacheTimestamps[userId];
    if (timestamp != null &&
        DateTime.now().difference(timestamp) > cacheValidityDuration) {
      // Cache expired, remove it
      _memoryCache.remove(userId);
      _cacheTimestamps.remove(userId);
      return null;
    }

    return _memoryCache[userId];
  }

  /// دریافت پروفایل با batching هوشمند
  Future<Map<String, String?>?> getProfile(String userId) async {
    // 1. Check memory cache first
    final cached = getCachedProfile(userId);
    if (cached != null) {
      return cached;
    }

    // 2. Check if request is already pending
    if (_pendingRequests.containsKey(userId)) {
      return _pendingRequests[userId]!.future;
    }

    // 3. Create completer and fetch
    final completer = Completer<Map<String, String?>?>();
    _pendingRequests[userId] = completer;

    try {
      // Batch with other pending requests
      final batch = await _collectBatch(userId);
      final results = await _fetchBatchProfiles(batch);

      // Process results
      for (final entry in results.entries) {
        final userId = entry.key;
        final profile = entry.value;

        if (profile != null) {
          _memoryCache[userId] = profile;
          _cacheTimestamps[userId] = DateTime.now();
        }

        // Complete the request
        final pendingCompleter = _pendingRequests.remove(userId);
        if (pendingCompleter != null && !pendingCompleter.isCompleted) {
          pendingCompleter.complete(profile);
        }
      }

      // Broadcast updates
      final nonNullResults = <String, Map<String, String?>>{};
      for (final entry in results.entries) {
        if (entry.value != null) {
          nonNullResults[entry.key] = entry.value!;
        }
      }
      if (nonNullResults.isNotEmpty) {
        _profileUpdates.add(nonNullResults);
      }

      return completer.future;
    } catch (e) {
      logInfo('⚠️ Error fetching profile for $userId: $e');
      _pendingRequests.remove(userId);
      completer.complete(null);
      return null;
    }
  }

  /// جمع‌آوری batch از درخواست‌های در حال انتظار
  Future<List<String>> _collectBatch(String initialUserId) async {
    final batch = <String>[initialUserId];

    // Wait a bit to collect more requests
    await Future.delayed(batchDelay);

    // Add other pending requests up to max batch size
    final pendingIds = _pendingRequests.keys.toList();
    for (final userId in pendingIds) {
      if (batch.length >= maxBatchSize) break;
      if (!batch.contains(userId)) {
        batch.add(userId);
      }
    }

    return batch;
  }

  /// دریافت batch پروفایل‌ها از سرور
  Future<Map<String, Map<String, String?>?>> _fetchBatchProfiles(
      List<String> userIds) async {
    if (userIds.isEmpty) return {};

    try {
      final response = await _dio.post(
        '/profiles/batch',
        data: {'user_ids': userIds},
        options: await _authOptions(),
      );
      final profiles = _asList(_asMap(response.data)['profiles']);

      final results = <String, Map<String, String?>?>{};

      for (final userId in userIds) {
        Map<String, dynamic>? profileData;
        for (final item in profiles.whereType<Map>()) {
          if (item['user_id']?.toString() == userId) {
            profileData = item.cast<String, dynamic>();
            break;
          }
        }

        if (profileData != null) {
          results[userId] = {
            'username': profileData['username']?.toString(),
            'avatar_url': profileData['avatar_url']?.toString(),
            'full_name': profileData['full_name']?.toString(),
            'user_id': userId,
          };
        } else {
          results[userId] = null;
        }
      }

      return results;
    } catch (e) {
      logInfo('⚠️ Error in batch profile fetch: $e');
      // Return null for all users on error
      return {for (final userId in userIds) userId: null};
    }
  }

  /// بروزرسانی پروفایل از real-time
  Future<Options?> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return null;
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    return const [];
  }

  void updateProfileFromRealtime(String userId, Map<String, dynamic> data) {
    final profile = {
      'username': data['username'] as String?,
      'avatar_url': data['avatar_url'] as String?,
      'full_name': data['full_name'] as String?,
    };

    _memoryCache[userId] = profile;
    _cacheTimestamps[userId] = DateTime.now();

    // Broadcast update
    _profileUpdates.add({userId: profile});
  }

  /// پاک کردن کش
  void clearCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();

    // Cancel pending requests
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }
    _pendingRequests.clear();
  }

  /// آمار کشینگ
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_profiles': _memoryCache.length,
      'pending_requests': _pendingRequests.length,
      'total_cache_size_mb':
          (_memoryCache.length * 1024) / (1024 * 1024), // Rough estimate
      'cache_size_mb':
          (_memoryCache.length * 1024) / (1024 * 1024), // Rough estimate
    };
  }

  /// پاکسازی منابع
  void dispose() {
    _profileUpdates.close();
    clearCache();
  }
}
