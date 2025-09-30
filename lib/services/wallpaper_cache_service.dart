import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'cache_manager.dart';
import 'dart:io';

/// سرویس مدیریت کش والپیپرهای چت
class WallpaperCacheService {
  static const String _lightWallpaperUrl =
      'https://coffevista.s3.ir-thr-at1.arvanstorage.ir/wallpaper-chat%2F9f649ff4-5ebf-4a68-b740-6f009453500b.png';
  static const String _darkWallpaperUrl =
      'https://coffevista.s3.ir-thr-at1.arvanstorage.ir/wallpaper-chat%2F784e1c0c-2b8a-443d-8231-67c100a081e1.png';

  // Local asset paths as fallback
  static const String _lightWallpaperAsset =
      'lib/view/util/images/wallpapers/light_wallpaper.png';
  static const String _darkWallpaperAsset =
      'lib/view/util/images/wallpapers/dark_wallpaper.png';

  /// دریافت URL والپیپر بر اساس حالت تم
  static String getWallpaperUrl(bool isDarkMode) {
    return isDarkMode ? _darkWallpaperUrl : _lightWallpaperUrl;
  }

  /// دریافت مسیر asset محلی والپیپر بر اساس حالت تم
  static String getLocalWallpaperAsset(bool isDarkMode) {
    return isDarkMode ? _darkWallpaperAsset : _lightWallpaperAsset;
  }

  /// پیش‌بارگذاری هوشمند والپیپرها
  static Future<void> preloadWallpapers() async {
    try {
      // بررسی وجود والپیپرها در کش
      final List<Future> downloadTasks = [];

      // بررسی والپیپر روشن
      final lightCached = await CustomCacheManager.wallpaperInstance
          .getFileFromCache(_lightWallpaperUrl);
      if (lightCached == null || _isExpired(lightCached)) {
        downloadTasks.add(_downloadWallpaper(_lightWallpaperUrl, 'light'));
      }

      // بررسی والپیپر تاریک
      final darkCached = await CustomCacheManager.wallpaperInstance
          .getFileFromCache(_darkWallpaperUrl);
      if (darkCached == null || _isExpired(darkCached)) {
        downloadTasks.add(_downloadWallpaper(_darkWallpaperUrl, 'dark'));
      }

      // دانلود همزمان والپیپرهای مورد نیاز با timeout
      if (downloadTasks.isNotEmpty) {
        await Future.wait(downloadTasks).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print(
                '⚠️ والپیپر preload timeout - continuing with cached/local assets');
            return <void>[];
          },
        );
        print('✅ پیش‌بارگذاری والپیپرها تکمیل شد');
      } else {
        print('ℹ️  والپیپرها از قبل در کش موجود هستند');
      }
    } catch (e) {
      print('❌ خطا در پیش‌بارگذاری والپیپرها: $e');
    }
  }

  /// دانلود والپیپر با نمایش پیشرفت
  static Future<void> _downloadWallpaper(String url, String type) async {
    try {
      print('🔄 در حال دانلود والپیپر $type...');
      try {
        await CustomCacheManager.wallpaperInstance.downloadFile(url).timeout(
              const Duration(seconds: 8),
            );
      } catch (e) {
        print('⚠️ والپیپر $type دانلود timeout - using local asset');
      }
      print('✅ والپیپر $type با موفقیت دانلود و کش شد');
    } catch (e) {
      print('❌ خطا در دانلود والپیپر $type: $e');
    }
  }

  /// بررسی انقضای فایل کش شده
  static bool _isExpired(FileInfo fileInfo) {
    return fileInfo.validTill.isBefore(DateTime.now());
  }

  /// بررسی وجود والپیپر در کش
  static Future<bool> isWallpaperCached(bool isDarkMode) async {
    try {
      final url = getWallpaperUrl(isDarkMode);
      final cached =
          await CustomCacheManager.wallpaperInstance.getFileFromCache(url);
      return cached != null && !_isExpired(cached);
    } catch (e) {
      return false;
    }
  }

  /// دریافت فایل کش‌شده‌ی والپیپر (حتی اگر منقضی شده باشد برای استفاده به‌عنوان thumbnail)
  static Future<File?> getLocalCachedFile(bool isDarkMode) async {
    try {
      final url = getWallpaperUrl(isDarkMode);
      final cached =
          await CustomCacheManager.wallpaperInstance.getFileFromCache(url);
      if (cached != null) {
        // حتی اگر منقضی شده، به‌عنوان fallback/thumbnail استفاده می‌کنیم
        return cached.file;
      }
    } catch (_) {}
    return null;
  }

  /// پاک کردن کش والپیپرها
  static Future<void> clearWallpaperCache() async {
    try {
      await CustomCacheManager.wallpaperInstance.emptyCache();
      print('🗑️  کش والپیپرها پاک شد');
    } catch (e) {
      print('❌ خطا در پاک کردن کش والپیپرها: $e');
    }
  }

  /// بروزرسانی والپیپرها (برای آپدیت‌های آینده)
  static Future<void> refreshWallpapers() async {
    try {
      // حذف والپیپرهای موجود در کش
      await CustomCacheManager.wallpaperInstance.removeFile(_lightWallpaperUrl);
      await CustomCacheManager.wallpaperInstance.removeFile(_darkWallpaperUrl);

      // دانلود مجدد
      await preloadWallpapers();
      print('🔄 والپیپرها بروزرسانی شدند');
    } catch (e) {
      print('❌ خطا در بروزرسانی والپیپرها: $e');
    }
  }

  /// دریافت اطلاعات کش
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final lightCached = await CustomCacheManager.wallpaperInstance
          .getFileFromCache(_lightWallpaperUrl);
      final darkCached = await CustomCacheManager.wallpaperInstance
          .getFileFromCache(_darkWallpaperUrl);

      return {
        'lightWallpaper': {
          'cached': lightCached != null,
          'expired': lightCached != null ? _isExpired(lightCached) : true,
          'cacheTime': lightCached?.validTill.toIso8601String(),
        },
        'darkWallpaper': {
          'cached': darkCached != null,
          'expired': darkCached != null ? _isExpired(darkCached) : true,
          'cacheTime': darkCached?.validTill.toIso8601String(),
        },
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
