import '../security/logging_utility.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

/// سرویس پیشرفته مدیریت تنظیمات
class AdvancedSettingsService {
  static final AdvancedSettingsService _instance = AdvancedSettingsService._internal();
  factory AdvancedSettingsService() => _instance;
  AdvancedSettingsService._internal();

  // کلیدهای کش
  static const String _userSettingsKey = 'cached_user_settings';
  static const String _appSettingsKey = 'cached_app_settings';
  static const String _privacySettingsKey = 'cached_privacy_settings';
  static const String _notificationSettingsKey = 'cached_notification_settings';
  static const String _performanceSettingsKey = 'cached_performance_settings';
  static const String _storageSettingsKey = 'cached_storage_settings';
  static const String _lastUpdateKey = 'settings_cache_last_update';

  // تنظیمات کش
  static const Duration cacheValidityDuration = Duration(hours: 24);

  // Memory cache
  final Map<String, dynamic> _userSettingsCache = {};
  final Map<String, dynamic> _appSettingsCache = {};
  final Map<String, dynamic> _privacySettingsCache = {};
  final Map<String, dynamic> _notificationSettingsCache = {};
  final Map<String, dynamic> _performanceSettingsCache = {};
  final Map<String, dynamic> _storageSettingsCache = {};
  final Map<String, DateTime> _lastFetch = {};

  // Storage monitoring
  int _currentCacheSize = 0;
  Timer? _storageMonitorTimer;

  /// مقداردهی اولیه
  Future<void> initialize() async {
    try {
      await _loadFromDisk();
      await _initializeDefaultSettings();
      _startStorageMonitoring();
      logInfo('✅ Advanced Settings Service initialized');
    } catch (e) {
      logInfo('❌ Failed to initialize Advanced Settings Service: $e');
    }
  }

  /// تنظیمات پیش‌فرض جامع
  Future<void> _initializeDefaultSettings() async {
    // تنظیمات عملکرد و بهینه‌سازی
    if (_performanceSettingsCache.isEmpty) {
      _performanceSettingsCache.addAll({
        // ⚡️ تنظیمات انیمیشن
        'animations': {
          'enabled': true,
          'speed': 'normal', // slow, normal, fast
          'reduce_motion': false, // برای کاربران حساس به حرکت
          'page_transitions': true,
          'list_animations': true,
          'button_feedback': true,
          'loading_animations': true,
        },
        
        // 🎨 تنظیمات رندرینگ
        'rendering': {
          'enable_gpu_acceleration': true,
          'frame_rate_limit': 60, // 30, 60, 120
          'reduce_transparency': false,
          'reduce_blur': false,
          'high_contrast': false,
        },
        
        // 📊 تنظیمات داده
        'data_optimization': {
          'aggressive_caching': false,
          'preload_images': true,
          'preload_videos': false,
          'lazy_loading': true,
          'batch_requests': true,
          'request_priority': 'balanced', // low, balanced, high
        },
        
        // 🔋 تنظیمات باتری
        'battery': {
          'power_save_mode': false,
          'background_sync': true,
          'reduce_background_activity': false,
          'optimize_for_battery': false,
        },
        
        // 🌐 تنظیمات شبکه
        'network': {
          'auto_retry_failed_requests': true,
          'max_retry_attempts': 3,
          'request_timeout_seconds': 30,
          'use_cellular_data': true,
          'download_on_cellular': false,
          'streaming_quality_cellular': 'medium',
          'streaming_quality_wifi': 'high',
        },
      });
    }

    // تنظیمات ذخیره‌سازی پیشرفته
    if (_storageSettingsCache.isEmpty) {
      _storageSettingsCache.addAll({
        // 💾 مدیریت Cache
        'cache': {
          'max_cache_size_mb': 500,
          'auto_clear_cache': true,
          'cache_clear_interval_days': 7,
          'keep_recent_days': 30,
          'cache_images': true,
          'cache_videos': false,
          'cache_audio': true,
          'cache_documents': true,
        },
        
        // 📱 مدیریت حافظه
        'memory': {
          'max_memory_usage_mb': 200,
          'clear_memory_on_background': false,
          'aggressive_memory_management': false,
        },
        
        // 📥 دانلود خودکار
        'auto_download': {
          'enabled': false,
          'download_photos': true,
          'download_videos': false,
          'download_audio': false,
          'download_documents': false,
          'max_file_size_mb': 10,
          'only_on_wifi': true,
        },
        
        // 🗂 مدیریت فایل‌ها
        'file_management': {
          'auto_delete_old_files': false,
          'keep_files_days': 90,
          'compress_images': true,
          'image_quality': 85, // 0-100
          'video_quality': 'medium', // low, medium, high, original
        },
      });
    }

    // تنظیمات اپلیکیشن پیشرفته
    if (_appSettingsCache.isEmpty) {
      _appSettingsCache.addAll({
        // 🎨 ظاهر
        'appearance': {
          'theme': 'system', // light, dark, system
          'color_scheme': 'default', // default, blue, purple, green
          'language': 'fa',
          'rtl_support': true,
          'font_family': 'default',
          'font_size': 'medium', // small, medium, large, xlarge
          'compact_mode': false,
        },
        
        // 🔊 صدا و لمسی
        'feedback': {
          'enable_sound_effects': true,
          'enable_haptic_feedback': true,
          'haptic_intensity': 'medium', // light, medium, strong
          'notification_sound': 'default',
          'message_sound': 'default',
          'sound_volume': 0.7, // 0.0 - 1.0
        },
        
        // 🌙 حالت شب
        'night_mode': {
          'auto_night_mode': true,
          'night_mode_start': '22:00',
          'night_mode_end': '07:00',
          'follow_system': true,
          'dim_brightness': false,
        },
        
        // 🔐 امنیت
        'security': {
          'require_biometric': false,
          'auto_lock_enabled': true,
          'auto_lock_timeout_minutes': 5,
          'hide_sensitive_info': false,
          'screenshot_security': false,
          'incognito_keyboard': false,
        },
        
        // ♿️ دسترسی‌پذیری
        'accessibility': {
          'large_text': false,
          'bold_text': false,
          'high_contrast': false,
          'color_blind_mode': 'none', // none, protanopia, deuteranopia, tritanopia
          'screen_reader_support': false,
          'simplified_ui': false,
        },
      });
    }

    await _saveToDisk();
  }

  /// بارگذاری از دیسک
  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // بارگذاری تمام تنظیمات
      final settingsMap = {
        _userSettingsKey: _userSettingsCache,
        _appSettingsKey: _appSettingsCache,
        _privacySettingsKey: _privacySettingsCache,
        _notificationSettingsKey: _notificationSettingsCache,
        _performanceSettingsKey: _performanceSettingsCache,
        _storageSettingsKey: _storageSettingsCache,
      };

      for (final entry in settingsMap.entries) {
        final json = prefs.getString(entry.key);
        if (json != null) {
          try {
            final decoded = jsonDecode(json);
            if (decoded is Map<String, dynamic>) {
              entry.value.addAll(decoded);
            } else if (decoded is Map) {
              // Convert Map<dynamic, dynamic> to Map<String, dynamic>
              entry.value.addAll(Map<String, dynamic>.from(decoded));
            }
          } catch (e) {
            logInfo('⚠️ Error decoding ${entry.key}: $e');
          }
        }
      }

      // بارگذاری زمان آخرین به‌روزرسانی
      final lastUpdateJson = prefs.getString(_lastUpdateKey);
      if (lastUpdateJson != null) {
        try {
          final Map<String, dynamic> lastUpdateMap = jsonDecode(lastUpdateJson);
          for (final mapEntry in lastUpdateMap.entries) {
            _lastFetch[mapEntry.key] = DateTime.parse(mapEntry.value);
          }
        } catch (e) {
          logInfo('⚠️ Error decoding last update times: $e');
        }
      }

      logInfo('📥 Loaded all settings from disk');
    } catch (e) {
      logInfo('⚠️ Error loading settings from disk: $e');
    }
  }

  /// ذخیره در دیسک
  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_userSettingsKey, jsonEncode(_userSettingsCache));
      await prefs.setString(_appSettingsKey, jsonEncode(_appSettingsCache));
      await prefs.setString(_privacySettingsKey, jsonEncode(_privacySettingsCache));
      await prefs.setString(_notificationSettingsKey, jsonEncode(_notificationSettingsCache));
      await prefs.setString(_performanceSettingsKey, jsonEncode(_performanceSettingsCache));
      await prefs.setString(_storageSettingsKey, jsonEncode(_storageSettingsCache));

      // ذخیره زمان آخرین به‌روزرسانی
      final lastUpdateMap = <String, String>{};
      for (final entry in _lastFetch.entries) {
        lastUpdateMap[entry.key] = entry.value.toIso8601String();
      }
      await prefs.setString(_lastUpdateKey, jsonEncode(lastUpdateMap));

      logInfo('💾 All settings saved to disk');
    } catch (e) {
      logInfo('⚠️ Error saving settings to disk: $e');
    }
  }

  /// مانیتورینگ فضای ذخیره‌سازی
  void _startStorageMonitoring() {
    _storageMonitorTimer?.cancel();
    _storageMonitorTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await _checkAndCleanStorage();
    });
  }

  /// بررسی و پاکسازی خودکار Storage
  Future<void> _checkAndCleanStorage() async {
    try {
      final cacheConfig = _storageSettingsCache['cache'] as Map<String, dynamic>?;
      if (cacheConfig == null) return;

      final maxCacheSizeMB = cacheConfig['max_cache_size_mb'] as int? ?? 500;
      final autoClearCache = cacheConfig['auto_clear_cache'] as bool? ?? true;
      
      if (!autoClearCache) return;

      // محاسبه حجم فعلی cache
      final currentSize = await _calculateTotalCacheSize();
      _currentCacheSize = currentSize;

      if (currentSize > maxCacheSizeMB) {
        logInfo('⚠️ Cache size ($currentSize MB) exceeds limit ($maxCacheSizeMB MB)');
        await _performSmartCacheCleanup();
      }
    } catch (e) {
      logInfo('❌ Storage monitoring error: $e');
    }
  }

  /// محاسبه حجم کل Cache
  Future<int> _calculateTotalCacheSize() async {
    try {
      final directory = await getApplicationCacheDirectory();
      int totalSize = 0;

      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            totalSize += await entity.length();
          }
        }
      }

      return (totalSize / (1024 * 1024)).round(); // تبدیل به MB
    } catch (e) {
      logInfo('❌ Error calculating cache size: $e');
      return 0;
    }
  }

  /// پاکسازی هوشمند Cache
  Future<void> _performSmartCacheCleanup() async {
    try {
      logInfo('🧹 Starting smart cache cleanup...');
      
      final cacheConfig = _storageSettingsCache['cache'] as Map<String, dynamic>?;
      final keepRecentDays = cacheConfig?['keep_recent_days'] as int? ?? 30;
      final cutoffDate = DateTime.now().subtract(Duration(days: keepRecentDays));

      final directory = await getApplicationCacheDirectory();
      int cleanedSize = 0;
      int cleanedFiles = 0;

      if (await directory.exists()) {
        await for (final entity in directory.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoffDate)) {
              final fileSize = await entity.length();
              await entity.delete();
              cleanedSize += fileSize;
              cleanedFiles++;
            }
          }
        }
      }

      final cleanedSizeMB = (cleanedSize / (1024 * 1024)).toStringAsFixed(2);
      logInfo('✅ Cleaned $cleanedFiles files ($cleanedSizeMB MB)');
    } catch (e) {
      logInfo('❌ Cache cleanup error: $e');
    }
  }

  // ===== متدهای دریافت تنظیمات =====

  /// دریافت تنظیمات عملکرد
  Map<String, dynamic> getPerformanceSettings() {
    return Map<String, dynamic>.from(_performanceSettingsCache);
  }

  /// دریافت تنظیمات ذخیره‌سازی
  Map<String, dynamic> getStorageSettings() {
    return Map<String, dynamic>.from(_storageSettingsCache);
  }

  /// دریافت تنظیمات اپلیکیشن پیشرفته
  Map<String, dynamic> getAdvancedAppSettings() {
    return Map<String, dynamic>.from(_appSettingsCache);
  }

  /// آیا انیمیشن‌ها فعال هستند؟
  bool areAnimationsEnabled() {
    final animations = _performanceSettingsCache['animations'] as Map<String, dynamic>?;
    return animations?['enabled'] as bool? ?? true;
  }

  /// آیا GPU Acceleration فعال است؟
  bool isGPUAccelerationEnabled() {
    final rendering = _performanceSettingsCache['rendering'] as Map<String, dynamic>?;
    return rendering?['enable_gpu_acceleration'] as bool? ?? true;
  }

  /// حداکثر حجم Cache (MB)
  int getMaxCacheSize() {
    final cache = _storageSettingsCache['cache'] as Map<String, dynamic>?;
    return cache?['max_cache_size_mb'] as int? ?? 500;
  }

  /// حجم فعلی Cache (MB)
  int getCurrentCacheSize() {
    return _currentCacheSize;
  }

  // ===== متدهای به‌روزرسانی تنظیمات =====

  /// به‌روزرسانی تنظیمات عملکرد
  Future<void> updatePerformanceSettings(Map<String, dynamic> settings) async {
    _performanceSettingsCache.addAll(settings);
    _lastFetch['performance_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated performance settings');
  }

  /// به‌روزرسانی تنظیمات ذخیره‌سازی
  Future<void> updateStorageSettings(Map<String, dynamic> settings) async {
    _storageSettingsCache.addAll(settings);
    _lastFetch['storage_settings'] = DateTime.now();
    await _saveToDisk();
    
    // اگر max_cache_size تغییر کرد، بررسی فوری کن
    if (settings.containsKey('cache')) {
      await _checkAndCleanStorage();
    }
    
    logInfo('✅ Updated storage settings');
  }

  /// به‌روزرسانی تنظیمات اپلیکیشن پیشرفته
  Future<void> updateAdvancedAppSettings(Map<String, dynamic> settings) async {
    _appSettingsCache.addAll(settings);
    _lastFetch['app_settings'] = DateTime.now();
    await _saveToDisk();
    logInfo('✅ Updated advanced app settings');
  }

  /// پاکسازی دستی Cache
  Future<Map<String, dynamic>> manualCacheCleanup() async {
    final sizeBefore = await _calculateTotalCacheSize();
    await _performSmartCacheCleanup();
    final sizeAfter = await _calculateTotalCacheSize();
    
    return {
      'size_before_mb': sizeBefore,
      'size_after_mb': sizeAfter,
      'cleaned_mb': sizeBefore - sizeAfter,
    };
  }

  /// آمار کامل
  Future<Map<String, dynamic>> getCompleteStats() async {
    final cacheSize = await _calculateTotalCacheSize();
    final maxSize = getMaxCacheSize();
    final usagePercent = maxSize > 0 ? (cacheSize / maxSize * 100).toStringAsFixed(1) : '0';

    return {
      'cache_size_mb': cacheSize,
      'max_cache_size_mb': maxSize,
      'usage_percent': usagePercent,
      'animations_enabled': areAnimationsEnabled(),
      'gpu_acceleration': isGPUAccelerationEnabled(),
      'total_settings_count': {
        'performance': _performanceSettingsCache.length,
        'storage': _storageSettingsCache.length,
        'app': _appSettingsCache.length,
        'privacy': _privacySettingsCache.length,
        'notifications': _notificationSettingsCache.length,
      },
    };
  }

  /// Dispose
  void dispose() {
    _storageMonitorTimer?.cancel();
    logInfo('🧹 Advanced Settings Service disposed');
  }
}

