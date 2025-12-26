import '../security/logging_utility.dart';
import 'dart:async';
import '../utils/const.dart';

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
      if (results.isNotEmpty) {
        _profileUpdates.add(Map.from(results));
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
      final response = await supabase
          .from('profiles')
          .select('id, username, avatar_url, full_name')
          .inFilter('id', userIds);

      final results = <String, Map<String, String?>?>{};

      for (final userId in userIds) {
        final profileData = response.cast<Map<String, dynamic>?>().firstWhere(
              (p) => p?['id'] == userId,
              orElse: () => null,
            );

        if (profileData != null) {
          results[userId] = {
            'username': profileData['username'] as String?,
            'avatar_url': profileData['avatar_url'] as String?,
            'full_name': profileData['full_name'] as String?,
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
