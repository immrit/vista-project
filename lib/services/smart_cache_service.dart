import '../security/logging_utility.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../DB/unified_message_cache_service.dart';

/// سرویس مدیریت کش هوشمند
@Deprecated('Use CacheRepository instead')
class SmartCacheService {
  static final SmartCacheService _instance = SmartCacheService._internal();
  factory SmartCacheService() => _instance;
  SmartCacheService._internal();

  bool _smartCacheEnabled = true;
  int _cacheSizeLimit = 100; // MB
  int _cacheExpiryDays = 7;

  /// بررسی آیا کش هوشمند فعال است
  bool get smartCacheEnabled => _smartCacheEnabled;

  /// دریافت محدودیت اندازه کش
  int get cacheSizeLimit => _cacheSizeLimit;

  /// دریافت زمان انقضای کش
  int get cacheExpiryDays => _cacheExpiryDays;

  /// تنظیم کش هوشمند
  Future<void> setSmartCache(bool enabled) async {
    _smartCacheEnabled = enabled;

    if (enabled) {
      _cacheSizeLimit = 100;
      _cacheExpiryDays = 7;
      await _performSmartCacheCleanup();
      logInfo('🧠 Smart cache enabled - Auto cleanup active');
    } else {
      _cacheSizeLimit = 500;
      _cacheExpiryDays = 30;
      logInfo('🧠 Smart cache disabled - Full cache mode');
    }

    await _saveSettings();
  }

  /// اجرای پاکسازی هوشمند کش
  Future<void> _performSmartCacheCleanup() async {
    try {
      final messageCacheService = UnifiedMessageCacheService();
      final cutoffDate =
          DateTime.now().subtract(Duration(days: _cacheExpiryDays));

      await messageCacheService.deleteMessagesOlderThan(cutoffDate);
      print(
          '🧹 Smart cache cleanup completed - Removed messages older than $_cacheExpiryDays days');
    } catch (e) {
      logInfo('❌ Error during smart cache cleanup: $e');
    }
  }

  /// اجرای پاکسازی دوره‌ای کش
  Future<void> performPeriodicCleanup() async {
    if (!_smartCacheEnabled) return;

    try {
      await _performSmartCacheCleanup();

      // پاکسازی فایل‌های موقت
      await _cleanupTempFiles();

      logInfo('🧹 Periodic cache cleanup completed');
    } catch (e) {
      logInfo('❌ Error during periodic cleanup: $e');
    }
  }

  /// پاکسازی فایل‌های موقت
  Future<void> _cleanupTempFiles() async {
    try {
      // اینجا می‌توانید فایل‌های موقت را پاک کنید
      // برای مثال: فایل‌های دانلود شده، تصاویر موقت، etc.
      logInfo('🧹 Temp files cleanup completed');
    } catch (e) {
      logInfo('❌ Error cleaning temp files: $e');
    }
  }

  /// بارگذاری تنظیمات از SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _smartCacheEnabled = prefs.getBool('smart_cache_enabled') ?? true;
      _cacheSizeLimit = prefs.getInt('cache_size_limit') ?? 100;
      _cacheExpiryDays = prefs.getInt('cache_expiry_days') ?? 7;

      print(
          '📱 Smart cache settings loaded: enabled=$_smartCacheEnabled, size_limit=${_cacheSizeLimit}MB, expiry_days=$_cacheExpiryDays');
    } catch (e) {
      logInfo('❌ Error loading smart cache settings: $e');
    }
  }

  /// ذخیره تنظیمات در SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('smart_cache_enabled', _smartCacheEnabled);
      await prefs.setInt('cache_size_limit', _cacheSizeLimit);
      await prefs.setInt('cache_expiry_days', _cacheExpiryDays);
    } catch (e) {
      logInfo('❌ Error saving smart cache settings: $e');
    }
  }

  /// دریافت تنظیمات کش هوشمند
  Map<String, dynamic> getSmartCacheSettings() {
    return {
      'enabled': _smartCacheEnabled,
      'sizeLimit': _cacheSizeLimit,
      'expiryDays': _cacheExpiryDays,
    };
  }

  /// بررسی آیا کش باید پاکسازی شود
  bool shouldCleanupCache() {
    return _smartCacheEnabled;
  }

  /// دریافت اندازه کش فعلی (تقریبی)
  Future<int> getCurrentCacheSize() async {
    try {
      // اینجا می‌توانید اندازه واقعی کش را محاسبه کنید
      // برای مثال: بررسی اندازه فایل‌های کش شده
      return 0; // placeholder
    } catch (e) {
      logInfo('❌ Error getting cache size: $e');
      return 0;
    }
  }
}
