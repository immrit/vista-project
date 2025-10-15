import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

/// سرویس کش برای تنظیمات کاربر
/// این سرویس تمام تنظیمات کاربر را کش می‌کند تا در حالت آفلاین نیز قابل دسترسی باشد
class SettingsCacheService {
  static final SettingsCacheService _instance =
      SettingsCacheService._internal();
  factory SettingsCacheService() => _instance;
  SettingsCacheService._internal();

  // کلیدهای کش
  static const String _userSettingsKey = 'cached_user_settings';
  static const String _appSettingsKey = 'cached_app_settings';
  static const String _privacySettingsKey = 'cached_privacy_settings';
  static const String _notificationSettingsKey = 'cached_notification_settings';
  static const String _lastUpdateKey = 'settings_cache_last_update';

  // تنظیمات کش
  static const Duration cacheValidityDuration = Duration(hours: 24);

  // Memory cache برای دسترسی سریع
  final Map<String, dynamic> _userSettingsCache = {};
  final Map<String, dynamic> _appSettingsCache = {};
  final Map<String, dynamic> _privacySettingsCache = {};
  final Map<String, dynamic> _notificationSettingsCache = {};
  final Map<String, DateTime> _lastFetch = {};

  /// مقداردهی اولیه سرویس کش
  Future<void> initialize() async {
    try {
      await _loadFromDisk();
      logInfo('✅ Settings Cache Service initialized');
    } catch (e) {
      logInfo('❌ Failed to initialize Settings Cache Service: $e');
    }
  }

  /// بارگذاری داده‌ها از دیسک
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // بارگذاری تنظیمات کاربر
      final userSettingsJson = prefs.getString(_userSettingsKey);
      if (userSettingsJson != null) {
        _userSettingsCache.addAll(jsonDecode(userSettingsJson));
      }

      // بارگذاری تنظیمات اپلیکیشن
      final appSettingsJson = prefs.getString(_appSettingsKey);
      if (appSettingsJson != null) {
        _appSettingsCache.addAll(jsonDecode(appSettingsJson));
      }

      // بارگذاری تنظیمات حریم خصوصی
      final privacySettingsJson = prefs.getString(_privacySettingsKey);
      if (privacySettingsJson != null) {
        _privacySettingsCache.addAll(jsonDecode(privacySettingsJson));
      }

      // بارگذاری تنظیمات اعلان‌ها
      final notificationSettingsJson =
          prefs.getString(_notificationSettingsKey);
      if (notificationSettingsJson != null) {
        _notificationSettingsCache.addAll(jsonDecode(notificationSettingsJson));
      }

      // بارگذاری زمان آخرین به‌روزرسانی
      final lastUpdateJson = prefs.getString(_lastUpdateKey);
      if (lastUpdateJson != null) {
        final Map<String, dynamic> lastUpdateMap = jsonDecode(lastUpdateJson);
        for (final entry in lastUpdateMap.entries) {
          _lastFetch[entry.key] = DateTime.parse(entry.value);
        }
      }

      logInfo('📥 Loaded settings cache from disk');
    } catch (e) {
      logInfo('⚠️ Error loading settings cache from disk: $e');
    }
  }

  /// ذخیره داده‌ها در دیسک
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_userSettingsKey, jsonEncode(_userSettingsCache));
      await prefs.setString(_appSettingsKey, jsonEncode(_appSettingsCache));
      await prefs.setString(
          _privacySettingsKey, jsonEncode(_privacySettingsCache));
      await prefs.setString(
          _notificationSettingsKey, jsonEncode(_notificationSettingsCache));

      // ذخیره زمان آخرین به‌روزرسانی
      final lastUpdateMap = <String, String>{};
      for (final entry in _lastFetch.entries) {
        lastUpdateMap[entry.key] = entry.value.toIso8601String();
      }
      await prefs.setString(_lastUpdateKey, jsonEncode(lastUpdateMap));

      logInfo('💾 Settings cache saved to disk');
    } catch (e) {
      logInfo('⚠️ Error saving settings cache to disk: $e');
    }
  }

  /// بررسی اعتبار کش
  bool _isCacheValid(String settingsType) {
    final lastFetch = _lastFetch[settingsType];
    if (lastFetch == null) return false;

    final now = DateTime.now();
    return now.difference(lastFetch) < cacheValidityDuration;
  }

  /// کش کردن تنظیمات کاربر
  Future<void> cacheUserSettings(String userId) async {
    try {
      final response = await supabase
          .from('user_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _userSettingsCache[userId] = response;
        _lastFetch['user_settings'] = DateTime.now();
        await _saveToDisk();
        logInfo('✅ Cached user settings for user: $userId');
      }
    } catch (e) {
      logInfo('❌ Failed to cache user settings for user $userId: $e');
    }
  }

  /// کش کردن تنظیمات اپلیکیشن
  Future<void> cacheAppSettings() async {
    try {
      // تنظیمات پیش‌فرض اپلیکیشن
      final defaultAppSettings = {
        'theme': 'system',
        'language': 'fa',
        'auto_play_videos': true,
        'auto_download_media': false,
        'max_cache_size_mb': 200,
        'video_quality': 'medium',
        'image_quality': 'high',
        'enable_haptic_feedback': true,
        'enable_sound_effects': true,
        'enable_animations': true,
        'font_size': 'medium',
        'enable_dark_mode': false,
        'auto_sync': true,
        'sync_interval_minutes': 30,
      };

      _appSettingsCache.addAll(defaultAppSettings);
      _lastFetch['app_settings'] = DateTime.now();
      await _saveToDisk();
      logInfo('✅ Cached app settings');
    } catch (e) {
      logInfo('❌ Failed to cache app settings: $e');
    }
  }

  /// کش کردن تنظیمات حریم خصوصی
  Future<void> cachePrivacySettings(String userId) async {
    try {
      final response = await supabase
          .from('privacy_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _privacySettingsCache[userId] = response;
        _lastFetch['privacy_settings'] = DateTime.now();
        await _saveToDisk();
        logInfo('✅ Cached privacy settings for user: $userId');
      } else {
        // تنظیمات پیش‌فرض حریم خصوصی
        final defaultPrivacySettings = {
          'is_private': false,
          'show_online_status': true,
          'allow_message_requests': true,
          'allow_follow_requests': true,
          'show_last_seen': true,
          'allow_profile_views': true,
          'blocked_users': [],
          'restricted_users': [],
        };
        _privacySettingsCache[userId] = defaultPrivacySettings;
        _lastFetch['privacy_settings'] = DateTime.now();
        await _saveToDisk();
      }
    } catch (e) {
      logInfo('❌ Failed to cache privacy settings for user $userId: $e');
    }
  }

  /// کش کردن تنظیمات اعلان‌ها
  Future<void> cacheNotificationSettings(String userId) async {
    try {
      final response = await supabase
          .from('notification_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        _notificationSettingsCache[userId] = response;
        _lastFetch['notification_settings'] = DateTime.now();
        await _saveToDisk();
        logInfo('✅ Cached notification settings for user: $userId');
      } else {
        // تنظیمات پیش‌فرض اعلان‌ها
        final defaultNotificationSettings = {
          'push_notifications': true,
          'message_notifications': true,
          'like_notifications': true,
          'comment_notifications': true,
          'follow_notifications': true,
          'mention_notifications': true,
          'story_notifications': true,
          'sound_enabled': true,
          'vibration_enabled': true,
          'quiet_hours_enabled': false,
          'quiet_hours_start': '22:00',
          'quiet_hours_end': '08:00',
        };
        _notificationSettingsCache[userId] = defaultNotificationSettings;
        _lastFetch['notification_settings'] = DateTime.now();
        await _saveToDisk();
      }
    } catch (e) {
      logInfo('❌ Failed to cache notification settings for user $userId: $e');
    }
  }

  /// دریافت تنظیمات کاربر از کش
  Map<String, dynamic>? getCachedUserSettings(String userId) {
    return _userSettingsCache[userId];
  }

  /// دریافت تنظیمات اپلیکیشن از کش
  Map<String, dynamic> getCachedAppSettings() {
    return _appSettingsCache;
  }

  /// دریافت تنظیمات حریم خصوصی از کش
  Map<String, dynamic>? getCachedPrivacySettings(String userId) {
    return _privacySettingsCache[userId];
  }

  /// دریافت تنظیمات اعلان‌ها از کش
  Map<String, dynamic>? getCachedNotificationSettings(String userId) {
    return _notificationSettingsCache[userId];
  }

  /// دریافت تنظیمات کاربر (اول از کش، سپس از سرور)
  Future<Map<String, dynamic>?> getUserSettings(String userId) async {
    // بررسی کش
    if (_isCacheValid('user_settings')) {
      final cachedSettings = getCachedUserSettings(userId);
      if (cachedSettings != null) {
        logInfo('📱 Using cached user settings for user: $userId');
        return cachedSettings;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching user settings from server for user: $userId');
    await cacheUserSettings(userId);
    return getCachedUserSettings(userId);
  }

  /// دریافت تنظیمات اپلیکیشن (اول از کش، سپس از سرور)
  Future<Map<String, dynamic>> getAppSettings() async {
    // بررسی کش
    if (_isCacheValid('app_settings')) {
      final cachedSettings = getCachedAppSettings();
      if (cachedSettings.isNotEmpty) {
        logInfo('📱 Using cached app settings');
        return cachedSettings;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching app settings from server');
    await cacheAppSettings();
    return getCachedAppSettings();
  }

  /// دریافت تنظیمات حریم خصوصی (اول از کش، سپس از سرور)
  Future<Map<String, dynamic>?> getPrivacySettings(String userId) async {
    // بررسی کش
    if (_isCacheValid('privacy_settings')) {
      final cachedSettings = getCachedPrivacySettings(userId);
      if (cachedSettings != null) {
        logInfo('📱 Using cached privacy settings for user: $userId');
        return cachedSettings;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching privacy settings from server for user: $userId');
    await cachePrivacySettings(userId);
    return getCachedPrivacySettings(userId);
  }

  /// دریافت تنظیمات اعلان‌ها (اول از کش، سپس از سرور)
  Future<Map<String, dynamic>?> getNotificationSettings(String userId) async {
    // بررسی کش
    if (_isCacheValid('notification_settings')) {
      final cachedSettings = getCachedNotificationSettings(userId);
      if (cachedSettings != null) {
        logInfo('📱 Using cached notification settings for user: $userId');
        return cachedSettings;
      }
    }

    // دریافت از سرور و کش کردن
    logInfo('🌐 Fetching notification settings from server for user: $userId');
    await cacheNotificationSettings(userId);
    return getCachedNotificationSettings(userId);
  }

  /// به‌روزرسانی تنظیمات کاربر در کش
  Future<void> updateUserSettings(
      String userId, Map<String, dynamic> settings) async {
    _userSettingsCache[userId] = settings;
    _lastFetch['user_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated cached user settings for user: $userId');
  }

  /// به‌روزرسانی تنظیمات اپلیکیشن در کش
  Future<void> updateAppSettings(Map<String, dynamic> settings) async {
    _appSettingsCache.addAll(settings);
    _lastFetch['app_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated cached app settings');
  }

  /// به‌روزرسانی تنظیمات حریم خصوصی در کش
  Future<void> updatePrivacySettings(
      String userId, Map<String, dynamic> settings) async {
    _privacySettingsCache[userId] = settings;
    _lastFetch['privacy_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated cached privacy settings for user: $userId');
  }

  /// به‌روزرسانی تنظیمات اعلان‌ها در کش
  Future<void> updateNotificationSettings(
      String userId, Map<String, dynamic> settings) async {
    _notificationSettingsCache[userId] = settings;
    _lastFetch['notification_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated cached notification settings for user: $userId');
  }

  /// پاک کردن کش کاربر خاص
  Future<void> clearUserCache(String userId) async {
    _userSettingsCache.remove(userId);
    _privacySettingsCache.remove(userId);
    _notificationSettingsCache.remove(userId);
    await _saveToDisk();
    logInfo('🧹 Cleared settings cache for user: $userId');
  }

  /// پاک کردن تمام کش
  Future<void> clearAllCache() async {
    _userSettingsCache.clear();
    _appSettingsCache.clear();
    _privacySettingsCache.clear();
    _notificationSettingsCache.clear();
    _lastFetch.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userSettingsKey);
    await prefs.remove(_appSettingsKey);
    await prefs.remove(_privacySettingsKey);
    await prefs.remove(_notificationSettingsKey);
    await prefs.remove(_lastUpdateKey);

    logInfo('🧹 Cleared all settings cache');
  }

  /// دریافت آمار کش
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_users_count': _userSettingsCache.length,
      'app_settings_count': _appSettingsCache.length,
      'privacy_settings_count': _privacySettingsCache.length,
      'notification_settings_count': _notificationSettingsCache.length,
      'total_cache_size_mb': _estimateCacheSize(),
      'last_update_times': _lastFetch
          .map((key, value) => MapEntry(key, value.toIso8601String())),
    };
  }

  /// تخمین حجم کش
  double _estimateCacheSize() {
    int totalSize = 0;

    totalSize += jsonEncode(_userSettingsCache).length;
    totalSize += jsonEncode(_appSettingsCache).length;
    totalSize += jsonEncode(_privacySettingsCache).length;
    totalSize += jsonEncode(_notificationSettingsCache).length;

    // تبدیل به مگابایت
    return totalSize / (1024 * 1024);
  }

  /// بررسی وضعیت اتصال و تصمیم‌گیری برای استفاده از کش
  bool shouldUseCache(String settingsType) {
    // اگر کش معتبر است، از آن استفاده کن
    if (_isCacheValid(settingsType)) {
      return true;
    }

    // اگر کش وجود دارد اما منقضی شده، باز هم از آن استفاده کن
    // اما در پس‌زمینه به‌روزرسانی کن
    switch (settingsType) {
      case 'user_settings':
        return _userSettingsCache.isNotEmpty;
      case 'app_settings':
        return _appSettingsCache.isNotEmpty;
      case 'privacy_settings':
        return _privacySettingsCache.isNotEmpty;
      case 'notification_settings':
        return _notificationSettingsCache.isNotEmpty;
      default:
        return false;
    }
  }

  /// به‌روزرسانی پس‌زمینه کش
  Future<void> refreshCacheInBackground(String userId) async {
    try {
      await Future.wait([
        cacheUserSettings(userId),
        cacheAppSettings(),
        cachePrivacySettings(userId),
        cacheNotificationSettings(userId),
      ]);
      logInfo('🔄 Background settings cache refresh completed for user: $userId');
    } catch (e) {
      logInfo('⚠️ Background settings cache refresh failed for user $userId: $e');
    }
  }

  /// مقداردهی اولیه کش برای کاربر جدید
  Future<void> initializeUserCache(String userId) async {
    try {
      await Future.wait([
        cacheUserSettings(userId),
        cacheAppSettings(),
        cachePrivacySettings(userId),
        cacheNotificationSettings(userId),
      ]);
      logInfo('✅ Initialized settings cache for user: $userId');
    } catch (e) {
      logInfo('❌ Failed to initialize settings cache for user $userId: $e');
    }
  }
}




