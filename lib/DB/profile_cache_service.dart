import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/ProfileModel.dart';
import '../model/publicPostModel.dart';
import '../utils/const.dart';

/// سرویس کش برای پروفایل کاربران و پست‌های آن‌ها
/// این سرویس آخرین 10 پست هر کاربر را کش می‌کند
class ProfileCacheService {
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  // کلیدهای کش
  static const String _profileCacheKey = 'cached_profiles';
  static const String _postsCacheKey = 'cached_user_posts';
  static const String _lastUpdateKey = 'profile_cache_last_update';

  // تنظیمات کش
  static const int maxCachedPostsPerUser =
      50; // محدودیت کش برای بهینه‌سازی عملکرد
  static const Duration cacheValidityDuration = Duration(hours: 2);

  // Memory cache برای دسترسی سریع
  final Map<String, ProfileModel> _profileMemoryCache = {};
  final Map<String, List<PublicPostModel>> _postsMemoryCache = {};
  final Map<String, DateTime> _lastFetch = {};

  // ✅ Debouncing برای ذخیره‌سازی در دیسک
  Timer? _saveDebounceTimer;
  bool _isDirty = false;
  static const Duration _saveDebounceDelay = Duration(seconds: 5);

  /// مقداردهی اولیه سرویس کش
  Future<void> initialize() async {
    try {
      await _loadFromDisk();
      logInfo('✅ Profile Cache Service initialized');
    } catch (e) {
      logInfo('❌ Failed to initialize Profile Cache Service: $e');
    }
  }

  /// بارگذاری داده‌ها از دیسک
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // بارگذاری پروفایل‌ها
      final profilesJson = prefs.getString(_profileCacheKey);
      if (profilesJson != null) {
        final Map<String, dynamic> profilesMap = jsonDecode(profilesJson);
        for (final entry in profilesMap.entries) {
          final profileData = entry.value as Map<String, dynamic>;
          final profile = ProfileModel.fromMap(profileData);
          _profileMemoryCache[entry.key] = profile;
        }
        logInfo('📥 Loaded ${_profileMemoryCache.length} profiles from disk');
      }

      // بارگذاری پست‌ها
      final postsJson = prefs.getString(_postsCacheKey);
      if (postsJson != null) {
        final Map<String, dynamic> postsMap = jsonDecode(postsJson);
        for (final entry in postsMap.entries) {
          final postsList = (entry.value as List<dynamic>)
              .map((postData) => PublicPostModel.fromMap(postData))
              .toList();
          _postsMemoryCache[entry.key] = postsList;
        }
        print(
            '📥 Loaded posts for ${_postsMemoryCache.length} users from disk');
      }

      // بارگذاری زمان آخرین به‌روزرسانی
      final lastUpdateJson = prefs.getString(_lastUpdateKey);
      if (lastUpdateJson != null) {
        final Map<String, dynamic> lastUpdateMap = jsonDecode(lastUpdateJson);
        for (final entry in lastUpdateMap.entries) {
          _lastFetch[entry.key] = DateTime.parse(entry.value);
        }
      }
    } catch (e) {
      logInfo('⚠️ Error loading profile cache from disk: $e');
    }
  }

  /// ذخیره داده‌ها در دیسک با debouncing برای عملکرد بهتر
  Future<void> _saveToDisk() async {
    // ✅ Debouncing: فقط بعد از 5 ثانیه عدم تغییر، ذخیره کن
    _isDirty = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounceDelay, () async {
      if (!_isDirty) return;
      _isDirty = false;

      try {
        final prefs = await SharedPreferences.getInstance();

        // ذخیره پروفایل‌ها
        final profilesMap = <String, dynamic>{};
        for (final entry in _profileMemoryCache.entries) {
          profilesMap[entry.key] = entry.value.toMap();
        }
        await prefs.setString(_profileCacheKey, jsonEncode(profilesMap));

        // ذخیره پست‌ها
        final postsMap = <String, dynamic>{};
        for (final entry in _postsMemoryCache.entries) {
          postsMap[entry.key] =
              entry.value.map((post) => post.toMap()).toList();
        }
        await prefs.setString(_postsCacheKey, jsonEncode(postsMap));

        // ذخیره زمان آخرین به‌روزرسانی
        final lastUpdateMap = <String, String>{};
        for (final entry in _lastFetch.entries) {
          lastUpdateMap[entry.key] = entry.value.toIso8601String();
        }
        await prefs.setString(_lastUpdateKey, jsonEncode(lastUpdateMap));

        logInfo('💾 Profile cache saved to disk (debounced)');
      } catch (e) {
        logInfo('⚠️ Error saving profile cache to disk: $e');
      }
    });
  }

  /// ذخیره فوری (برای مواقع ضروری مثل dispose)
  Future<void> _saveToDiskImmediate() async {
    _saveDebounceTimer?.cancel();
    _isDirty = false;

    try {
      final prefs = await SharedPreferences.getInstance();

      final profilesMap = <String, dynamic>{};
      for (final entry in _profileMemoryCache.entries) {
        profilesMap[entry.key] = entry.value.toMap();
      }
      await prefs.setString(_profileCacheKey, jsonEncode(profilesMap));

      final postsMap = <String, dynamic>{};
      for (final entry in _postsMemoryCache.entries) {
        postsMap[entry.key] = entry.value.map((post) => post.toMap()).toList();
      }
      await prefs.setString(_postsCacheKey, jsonEncode(postsMap));

      final lastUpdateMap = <String, String>{};
      for (final entry in _lastFetch.entries) {
        lastUpdateMap[entry.key] = entry.value.toIso8601String();
      }
      await prefs.setString(_lastUpdateKey, jsonEncode(lastUpdateMap));

      logInfo('💾 Profile cache saved to disk (immediate)');
    } catch (e) {
      logInfo('⚠️ Error saving profile cache to disk: $e');
    }
  }

  /// بررسی اعتبار کش
  bool _isCacheValid(String userId) {
    final lastFetch = _lastFetch[userId];
    if (lastFetch == null) return false;

    final now = DateTime.now();
    return now.difference(lastFetch) < cacheValidityDuration;
  }

  /// دریافت پروفایل از کش
  ProfileModel? getCachedProfile(String userId) {
    return _profileMemoryCache[userId];
  }

  /// اضافه کردن پروفایل به کش (برای استفاده خارجی)
  void addProfileToCache(String userId, ProfileModel profile) {
    _profileMemoryCache[userId] = profile;
  }

  /// دریافت پست‌های کش شده کاربر
  List<PublicPostModel> getCachedPosts(String userId) {
    return _postsMemoryCache[userId] ?? [];
  }

  /// کش کردن پروفایل و پست‌ها
  Future<void> cacheProfileAndPosts(String userId) async {
    try {
      // بررسی وجود کاربر در Auth
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        logInfo('⚠️ User not authenticated or ID mismatch');
        return;
      }

      // بررسی تأیید ایمیل (اختیاری - برای ثبت نام بدون تأیید ایمیل)
      // if (currentUser.emailConfirmedAt == null) {
      //   print('⚠️ Email not confirmed yet, skipping cache');
      //   return;
      // }

      // دریافت پروفایل از سرور
      final profileResponse = await supabase.from('profiles').select('''
            id,
            username,
            full_name,
            avatar_url,
            email,
            bio,
            created_at,
            is_verified,
            verification_type,
            account_type,
            role
          ''').eq('id', userId).single();

      // محاسبه تعداد دنبال‌کنندگان
      final followersResponse = await supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);

      final followersCount = followersResponse.length;

      // محاسبه تعداد دنبال‌شونده‌ها
      final followingResponse =
          await supabase.from('follows').select('id').eq('follower_id', userId);

      final followingCount = followingResponse.length;

      // دریافت تعداد کل پست‌ها
      final postsCountResponse =
          await supabase.from('posts').select('id').eq('user_id', userId);

      final postsCount = postsCountResponse.length;

      // دریافت همه پست‌ها
      final postsResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles!posts_user_id_fkey (
              username,
              avatar_url,
              is_verified,
              verification_type
            ),
            likes (
              user_id
            ),
            comments (
              id
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(maxCachedPostsPerUser);

      // بررسی وجود فیلدهای مورد نیاز
      if (profileResponse['id'] == null ||
          profileResponse['username'] == null) {
        print(
            '❌ Profile data missing required fields: id=${profileResponse['id']}, username=${profileResponse['username']}');
        throw Exception('Profile data is incomplete');
      }

      // ساخت مدل پروفایل
      final profile = ProfileModel.fromMap({
        ...profileResponse,
        'followers_count': followersCount,
        'following_count': followingCount,
        'posts_count': postsCount,
      });

      // ساخت لیست پست‌ها
      final currentUserId = supabase.auth.currentUser?.id;
      final posts = postsResponse.map((post) {
        final postLikes = post['likes'] as List? ?? [];
        final comments = post['comments'] as List<dynamic>? ?? [];

        final mappedPost = PublicPostModel.fromMap({
          ...post,
          'like_count': postLikes.length,
          'is_liked': postLikes.any((like) => like['user_id'] == currentUserId),
          'username': post['profiles']['username'] ?? 'Unknown',
          'avatar_url': post['profiles']['avatar_url'] ?? '',
          'is_verified': post['profiles']['is_verified'] ?? false,
          'comment_count': comments.length,
          'verification_type': post['profiles']['verification_type'],
        });

        return mappedPost;
      }).toList();

      // ذخیره در memory cache
      _profileMemoryCache[userId] = profile;
      _postsMemoryCache[userId] = posts;
      _lastFetch[userId] = DateTime.now();

      // ذخیره در دیسک
      await _saveToDisk();

      logInfo('✅ Cached profile and ${posts.length} posts for user: $userId');
    } catch (e) {
      logInfo('❌ Failed to cache profile for user $userId: $e');
      rethrow;
    }
  }

  /// دریافت پروفایل (اول از کش، سپس از سرور)
  Future<ProfileModel> getProfile(String userId) async {
    // بررسی کش
    if (_isCacheValid(userId)) {
      final cachedProfile = getCachedProfile(userId);
      if (cachedProfile != null) {
        logInfo('📱 Using cached profile for user: $userId');
        return cachedProfile;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching profile from server for user: $userId');
    await cacheProfileAndPosts(userId);

    final profile = _profileMemoryCache[userId];
    if (profile == null) {
      throw Exception('Failed to fetch profile for user: $userId');
    }

    return profile;
  }

  /// دریافت پست‌های کاربر (اول از کش، سپس از سرور)
  Future<List<PublicPostModel>> getUserPosts(String userId) async {
    // بررسی کش
    if (_isCacheValid(userId)) {
      final cachedPosts = getCachedPosts(userId);
      if (cachedPosts.isNotEmpty) {
        logInfo('📱 Using cached posts for user: $userId');
        return cachedPosts;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching posts from server for user: $userId');
    await cacheProfileAndPosts(userId);

    return _postsMemoryCache[userId] ?? [];
  }

  /// به‌روزرسانی پروفایل در کش
  Future<void> updateCachedProfile(ProfileModel profile) async {
    _profileMemoryCache[profile.id] = profile;
    _lastFetch[profile.id] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated cached profile for user: ${profile.id}');
  }

  /// اضافه کردن پست جدید به کش
  Future<void> addPostToCache(String userId, PublicPostModel post) async {
    final posts = _postsMemoryCache[userId] ?? [];

    // حذف پست قدیمی اگر وجود دارد
    posts.removeWhere((p) => p.id == post.id);

    // اضافه کردن پست جدید در ابتدای لیست
    posts.insert(0, post);

    // محدود کردن به حداکثر تعداد
    if (posts.length > maxCachedPostsPerUser) {
      posts.removeRange(maxCachedPostsPerUser, posts.length);
    }

    _postsMemoryCache[userId] = posts;
    await _saveToDisk();
    logInfo('✅ Added post to cache for user: $userId');
  }

  /// حذف پست از کش
  Future<void> removePostFromCache(String userId, String postId) async {
    final posts = _postsMemoryCache[userId] ?? [];
    posts.removeWhere((p) => p.id == postId);
    _postsMemoryCache[userId] = posts;
    await _saveToDisk();
    logInfo('✅ Removed post from cache for user: $userId');
  }

  /// پاک کردن کش کاربر خاص
  Future<void> clearUserCache(String userId) async {
    _profileMemoryCache.remove(userId);
    _postsMemoryCache.remove(userId);
    _lastFetch.remove(userId);
    await _saveToDisk();
    logInfo('🧹 Cleared cache for user: $userId');
  }

  /// پاک کردن تمام کش
  Future<void> clearAllCache() async {
    _saveDebounceTimer?.cancel();
    _profileMemoryCache.clear();
    _postsMemoryCache.clear();
    _lastFetch.clear();
    _isDirty = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileCacheKey);
    await prefs.remove(_postsCacheKey);
    await prefs.remove(_lastUpdateKey);

    logInfo('🧹 Cleared all profile cache');
  }

  /// Cleanup و ذخیره نهایی
  Future<void> dispose() async {
    _saveDebounceTimer?.cancel();
    if (_isDirty) {
      await _saveToDiskImmediate();
    }
  }

  /// دریافت آمار کش
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_profiles_count': _profileMemoryCache.length,
      'cached_posts_count':
          _postsMemoryCache.values.fold(0, (sum, posts) => sum + posts.length),
      'total_cache_size_mb': _estimateCacheSize(),
      'last_update_times': _lastFetch
          .map((key, value) => MapEntry(key, value.toIso8601String())),
    };
  }

  /// تخمین حجم کش
  double _estimateCacheSize() {
    int totalSize = 0;

    // تخمین حجم پروفایل‌ها
    for (final profile in _profileMemoryCache.values) {
      totalSize += profile.toJson().length;
    }

    // تخمین حجم پست‌ها
    for (final posts in _postsMemoryCache.values) {
      for (final post in posts) {
        totalSize += post.toJson().length;
      }
    }

    // تبدیل به مگابایت
    return totalSize / (1024 * 1024);
  }

  /// بررسی وضعیت اتصال و تصمیم‌گیری برای استفاده از کش
  bool shouldUseCache(String userId) {
    // اگر کش معتبر است، از آن استفاده کن
    if (_isCacheValid(userId)) {
      return true;
    }

    // اگر کش وجود دارد اما منقضی شده، باز هم از آن استفاده کن
    // اما در پس‌زمینه به‌روزرسانی کن
    if (_profileMemoryCache.containsKey(userId)) {
      return true;
    }

    return false;
  }

  /// به‌روزرسانی پس‌زمینه کش
  Future<void> refreshCacheInBackground(String userId) async {
    try {
      await cacheProfileAndPosts(userId);
      logInfo('🔄 Background cache refresh completed for user: $userId');
    } catch (e) {
      logInfo('⚠️ Background cache refresh failed for user $userId: $e');
    }
  }

  /// کش کردن پروفایل بعد از ثبت نام موفق
  Future<void> cacheProfileAfterRegistration(String userId) async {
    try {
      // بررسی وجود کاربر در Auth
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null || currentUser.id != userId) {
        logInfo('⚠️ User not authenticated or ID mismatch');
        return;
      }

      // صبر کردن کمی تا پروفایل در دیتابیس ایجاد شود
      await Future.delayed(const Duration(seconds: 2));

      logInfo('✅ Registration successful, caching profile for user: $userId');
      await cacheProfileAndPosts(userId);
    } catch (e) {
      logInfo('❌ Failed to cache profile after registration: $e');
      // اگر کش ناموفق بود، خطا نده چون ثبت نام موفق بوده
    }
  }
}
