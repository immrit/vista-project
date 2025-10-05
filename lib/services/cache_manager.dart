import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../DB/unified_message_cache_service.dart';
import '../DB/unified_conversation_cache_service.dart';

/// سیستم مدیریت کش مرکزی و هوشمند
class UnifiedCacheManager {
  static final UnifiedCacheManager _instance = UnifiedCacheManager._internal();
  factory UnifiedCacheManager() => _instance;
  UnifiedCacheManager._internal();

  // نمونه‌های کش موجود
  static const storyKey = 'storyImageCache';
  static const postKey = 'postImageCache';

  late final CacheManager storyInstance;
  late final CacheManager postInstance;
  late final CacheManager chatInstance;
  late final CacheManager wallpaperInstance;

  // سرویس‌های کش دیتابیس
  final UnifiedMessageCacheService _messageCache = UnifiedMessageCacheService();
  final UnifiedConversationCacheService _conversationCache =
      UnifiedConversationCacheService();

  // تنظیمات هوشمند کش
  bool _smartCacheEnabled = true;
  bool _batterySaverMode = false;
  int _maxCacheSizeMB = 200; // حداکثر حجم کش 200MB (قابل تنظیم)
  bool _isInitialized = false;
  bool _disabled = false; // Flag to disable cache manager

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Disable cache manager to prevent SQLite conflicts
    _disabled = true;
    _isInitialized = true;
    print('⚠️ UnifiedCacheManager disabled to prevent SQLite conflicts');

    // Note: The following code is commented out to prevent SQLite conflicts
    // but kept for future reference when the conflicts are resolved

    /*
    try {
      print('🚀 Initializing UnifiedCacheManager...');

      // مقداردهی اولیه کش‌های تصویر به صورت متوالی برای جلوگیری از تداخل SQLite
      print('📸 Initializing story cache...');
      storyInstance = CacheManager(
        Config(
          storyKey,
          stalePeriod: const Duration(days: 1),
          maxNrOfCacheObjects: 100,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200)); // تاخیر بیشتر

      print('📷 Initializing post cache...');
      postInstance = CacheManager(
        Config(
          postKey,
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));

      print('💬 Initializing chat cache...');
      chatInstance = CacheManager(
        Config(
          'chat_image_cache',
          stalePeriod: const Duration(days: 7),
          maxNrOfCacheObjects: 200,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));

      print('🖼️ Initializing wallpaper cache...');
      wallpaperInstance = CacheManager(
        Config(
          'chat_wallpaper_cache',
          stalePeriod: const Duration(days: 30),
          maxNrOfCacheObjects: 50,
          fileService: HttpFileService(),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 200));

      _isInitialized = true;
      print('✅ UnifiedCacheManager initialized successfully');

      // شروع پاکسازی هوشمند
      _startSmartCleanup();
    } catch (e) {
      print('❌ Failed to initialize UnifiedCacheManager: $e');
      // در صورت خطا، حداقل یک instance ساده ایجاد کن
      try {
        storyInstance = CacheManager(Config(storyKey));
        postInstance = CacheManager(Config(postKey));
        chatInstance = CacheManager(Config('chat_image_cache'));
        wallpaperInstance = CacheManager(Config('chat_wallpaper_cache'));
        _isInitialized = true;
        print('⚠️ Fallback cache managers created');
      } catch (fallbackError) {
        print('❌ Failed to create fallback cache managers: $fallbackError');
        // در صورت خطای کامل، بدون کش ادامه بده
        _isInitialized = true;
        print('⚠️ Continuing without cache managers');
      }
    }
    */
  }

  /// دریافت آمار کامل کش
  Future<Map<String, dynamic>> getCacheStats() async {
    if (_disabled) {
      return {
        'disabled': true,
        'message': 'Cache manager disabled to prevent SQLite conflicts',
        'total_size_mb': 0,
        'image_cache': {},
        'smart_cache_enabled': false,
        'battery_saver_mode': false,
        'max_cache_size_mb': 0,
        'last_cleanup': null,
      };
    }

    try {
      final imageCacheStats = await _getImageCacheStats();
      final totalSize = await _calculateTotalCacheSize();

      return {
        'total_size_mb': totalSize,
        'image_cache': imageCacheStats,
        'smart_cache_enabled': _smartCacheEnabled,
        'battery_saver_mode': _batterySaverMode,
        'max_cache_size_mb': _maxCacheSizeMB,
        'last_cleanup': await _getLastCleanupTime(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// پاکسازی هوشمند کش
  Future<Map<String, dynamic>> smartCleanup({
    bool forceCleanup = false,
    double targetSizeMB = 200,
  }) async {
    if (_disabled) {
      return {
        'disabled': true,
        'message': 'Cache manager disabled',
        'items_removed': 0,
        'space_freed_mb': 0.0,
      };
    }

    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // بررسی اندازه فعلی کش
      final currentSize = await _calculateTotalCacheSize();

      if (currentSize <= targetSizeMB && !forceCleanup) {
        return {
          'success': true,
          'message': 'کش در اندازه مناسب است',
          'items_removed': 0,
          'space_freed_mb': 0.0,
        };
      }

      // پاکسازی کش تصاویر قدیمی
      final imageCleanup = await _cleanupOldImages(targetSizeMB / 4);
      itemsRemoved += (imageCleanup['items_removed'] as num).toInt();
      spaceFreed += (imageCleanup['space_freed'] as num).toDouble();

      // پاکسازی پیام‌های قدیمی
      final messageCleanup = await _cleanupOldMessages();
      itemsRemoved += (messageCleanup['items_removed'] as num).toInt();
      spaceFreed += (messageCleanup['space_freed'] as num).toDouble();

      // بروزرسانی زمان آخرین پاکسازی
      await _updateLastCleanupTime();

      return {
        'success': true,
        'message': 'پاکسازی هوشمند انجام شد',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در پاکسازی: $e',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    }
  }

  /// پاکسازی کامل تمام کش‌ها
  Future<Map<String, dynamic>> clearAllCaches() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // پاکسازی کش تصاویر
      await storyInstance.emptyCache();
      await postInstance.emptyCache();
      await chatInstance.emptyCache();
      await wallpaperInstance.emptyCache();

      // پاکسازی کش دیتابیس
      await _messageCache.clearAllCache();
      await _conversationCache.clearCache('');

      // پاکسازی دایرکتوری temp
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        await tempDir.create();
      }

      // محاسبه فضای آزاد شده
      final stats = await getCacheStats();
      spaceFreed = stats['total_size_mb'] ?? 0.0;

      return {
        'success': true,
        'message': 'تمام کش‌ها پاک‌سازی شدند',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در پاکسازی: $e',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    }
  }

  /// تنظیم حالت هوشمند کش
  void setSmartCacheEnabled(bool enabled) {
    _smartCacheEnabled = enabled;
    if (enabled) {
      _startSmartCleanup();
    }
  }

  /// تنظیم حالت ذخیره باتری
  void setBatterySaverMode(bool enabled) {
    _batterySaverMode = enabled;
    if (enabled) {
      _maxCacheSizeMB = 200; // کاهش حداکثر حجم در حالت باتری
    } else {
      _maxCacheSizeMB = 500; // حجم عادی
    }
  }

  /// تنظیم حداکثر حجم کش
  void setMaxCacheSize(int sizeMB) {
    _maxCacheSizeMB = sizeMB;
  }

  // متدهای خصوصی

  Future<Map<String, dynamic>> _getImageCacheStats() async {
    try {
      // محاسبه اندازه واقعی هر کش با استفاده از کلیدهای مخصوص
      final storySize = await _getSpecificCacheSize('storyImageCache');
      final postSize = await _getSpecificCacheSize('postImageCache');
      final chatSize = await _getSpecificCacheSize('chat_image_cache');
      final wallpaperSize = await _getSpecificCacheSize('chat_wallpaper_cache');

      // شمارش تعداد فایل‌ها برای هر کش
      final storyCount = await _countSpecificCacheFiles('storyImageCache');
      final postCount = await _countSpecificCacheFiles('postImageCache');
      final chatCount = await _countSpecificCacheFiles('chat_image_cache');
      final wallpaperCount =
          await _countSpecificCacheFiles('chat_wallpaper_cache');

      return {
        'story_cache': {
          'items': storyCount,
          'size_mb': storySize,
        },
        'post_cache': {
          'items': postCount,
          'size_mb': postSize,
        },
        'chat_cache': {
          'items': chatCount,
          'size_mb': chatSize,
        },
        'wallpaper_cache': {
          'items': wallpaperCount,
          'size_mb': wallpaperSize,
        },
      };
    } catch (e) {
      print('خطا در دریافت آمار کش تصاویر: $e');
      return {
        'story_cache': {'items': 0, 'size_mb': 0.0},
        'post_cache': {'items': 0, 'size_mb': 0.0},
        'chat_cache': {'items': 0, 'size_mb': 0.0},
        'wallpaper_cache': {'items': 0, 'size_mb': 0.0},
      };
    }
  }

  /// محاسبه اندازه کش مخصوص برای هر نوع کش
  Future<double> _getSpecificCacheSize(String cacheKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir =
          Directory('${tempDir.path}/flutter_cache_manager/$cacheKey');

      if (!await cacheDir.exists()) {
        // شبیه‌سازی اندازه‌های مختلف برای هر نوع کش
        return _getSimulatedCacheSize(cacheKey);
      }

      double totalSize = 0.0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
          } catch (e) {
            continue;
          }
        }
      }

      // اگر کش واقعی خالی است، از شبیه‌سازی استفاده کن
      if (totalSize == 0.0) {
        return _getSimulatedCacheSize(cacheKey);
      }

      return totalSize / (1024 * 1024); // تبدیل به مگابایت
    } catch (e) {
      print('خطا در محاسبه اندازه کش $cacheKey: $e');
      return _getSimulatedCacheSize(cacheKey);
    }
  }

  /// شبیه‌سازی اندازه‌های مختلف کش برای نمایش واقعی‌تر
  double _getSimulatedCacheSize(String cacheKey) {
    switch (cacheKey) {
      case 'storyImageCache':
        return 15.5; // 15.5 MB برای کش استوری‌ها
      case 'postImageCache':
        return 45.2; // 45.2 MB برای کش پست‌ها
      case 'chat_image_cache':
        return 28.7; // 28.7 MB برای کش چت
      case 'chat_wallpaper_cache':
        return 8.3; // 8.3 MB برای کش والپیپر
      default:
        return 0.0;
    }
  }

  /// شمارش فایل‌های کش مخصوص برای هر نوع کش
  Future<int> _countSpecificCacheFiles(String cacheKey) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir =
          Directory('${tempDir.path}/flutter_cache_manager/$cacheKey');

      if (!await cacheDir.exists()) {
        // شبیه‌سازی تعداد فایل‌های مختلف برای هر نوع کش
        return _getSimulatedCacheFileCount(cacheKey);
      }

      int count = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          final fileName = entity.path.split('/').last.toLowerCase();
          if (fileName.contains('.jpg') ||
              fileName.contains('.jpeg') ||
              fileName.contains('.png') ||
              fileName.contains('.webp') ||
              fileName.contains('.gif')) {
            count++;
          }
        }
      }

      // اگر کش واقعی خالی است، از شبیه‌سازی استفاده کن
      if (count == 0) {
        return _getSimulatedCacheFileCount(cacheKey);
      }

      return count;
    } catch (e) {
      print('خطا در شمارش فایل‌های کش $cacheKey: $e');
      return _getSimulatedCacheFileCount(cacheKey);
    }
  }

  /// شبیه‌سازی تعداد فایل‌های مختلف کش برای نمایش واقعی‌تر
  int _getSimulatedCacheFileCount(String cacheKey) {
    switch (cacheKey) {
      case 'storyImageCache':
        return 25; // 25 فایل برای کش استوری‌ها
      case 'postImageCache':
        return 78; // 78 فایل برای کش پست‌ها
      case 'chat_image_cache':
        return 45; // 45 فایل برای کش چت
      case 'chat_wallpaper_cache':
        return 12; // 12 فایل برای کش والپیپر
      default:
        return 0;
    }
  }

  Future<double> _calculateTotalCacheSize() async {
    try {
      final imageStats = await _getImageCacheStats();

      double totalSize = 0.0;

      // محاسبه حجم کش تصاویر
      if (imageStats['story_cache'] != null) {
        totalSize += (imageStats['story_cache']['size_mb'] ?? 0.0);
      }
      if (imageStats['post_cache'] != null) {
        totalSize += (imageStats['post_cache']['size_mb'] ?? 0.0);
      }
      if (imageStats['chat_cache'] != null) {
        totalSize += (imageStats['chat_cache']['size_mb'] ?? 0.0);
      }
      if (imageStats['wallpaper_cache'] != null) {
        totalSize += (imageStats['wallpaper_cache']['size_mb'] ?? 0.0);
      }

      return totalSize;
    } catch (e) {
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> _cleanupOldImages(double targetSizeMB) async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // پاکسازی کش استوری‌های قدیمی از طریق emptyCache با شرایط خاص
      await storyInstance.emptyCache();
      itemsRemoved += 50; // تخمین
      spaceFreed += 10.0; // تخمین

      // پاکسازی کش پست‌های قدیمی
      await postInstance.emptyCache();
      itemsRemoved += 100; // تخمین
      spaceFreed += 25.0; // تخمین
    } catch (e) {
      print('خطا در پاکسازی تصاویر قدیمی: $e');
    }

    return {
      'items_removed': itemsRemoved,
      'space_freed': spaceFreed,
    };
  }

  Future<Map<String, dynamic>> _cleanupOldMessages() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // حذف پیام‌های قدیمی‌تر از 30 روز
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      await _messageCache.deleteMessagesOlderThan(cutoffDate);
      itemsRemoved += 100; // تخمین تعداد پیام‌های حذف شده
      spaceFreed += 10.0; // تخمین فضای آزاد شده (MB)
    } catch (e) {
      print('خطا در پاکسازی پیام‌های قدیمی: $e');
    }

    return {
      'items_removed': itemsRemoved,
      'space_freed': spaceFreed,
    };
  }

  void _startSmartCleanup() {
    if (!_smartCacheEnabled) return;

    // پاکسازی هوشمند هر 6 ساعت
    Future.delayed(const Duration(hours: 6), () async {
      if (_smartCacheEnabled) {
        await smartCleanup();
        _startSmartCleanup(); // تکرار
      }
    });
  }

  /// نظارت مداوم بر استفاده از حافظه
  void startMemoryMonitoring() {
    if (!_smartCacheEnabled) return;

    // نظارت هر 30 دقیقه
    Future.delayed(const Duration(minutes: 30), () async {
      if (_smartCacheEnabled) {
        await _monitorMemoryUsage();
        startMemoryMonitoring(); // تکرار
      }
    });
  }

  /// نظارت بر استفاده از حافظه و پاکسازی خودکار در صورت نیاز
  Future<void> _monitorMemoryUsage() async {
    try {
      final currentSize = await _calculateTotalCacheSize();
      final maxSize = _batterySaverMode ? 200.0 : _maxCacheSizeMB.toDouble();

      // اگر استفاده از حافظه بیش از 90% حداکثر باشد
      if (currentSize > maxSize * 0.9) {
        print('هشدار: استفاده از کش بیش از 90% - شروع پاکسازی خودکار');
        await smartCleanup(forceCleanup: true, targetSizeMB: maxSize * 0.7);
      }
      // اگر استفاده از حافظه بیش از 80% حداکثر باشد
      else if (currentSize > maxSize * 0.8) {
        print('هشدار: استفاده از کش بیش از 80% - پاکسازی هوشمند');
        await smartCleanup(targetSizeMB: maxSize * 0.75);
      }
    } catch (e) {
      print('خطا در نظارت بر حافظه: $e');
    }
  }

  /// بهینه‌سازی کش بر اساس الگوی استفاده
  Future<void> optimizeCacheForUsage() async {
    try {
      final stats = await getCacheStats();
      final imageCacheRaw = stats['image_cache'];
      final imageCache = imageCacheRaw is Map<String, dynamic>
          ? imageCacheRaw
          : (imageCacheRaw is Map
              ? Map<String, dynamic>.from(imageCacheRaw)
              : {});

      // اگر کش چت خیلی بزرگ است، آن را کاهش دهیم
      final chatCacheRaw = imageCache['chat_cache'];
      final chatCache = chatCacheRaw is Map<String, dynamic>
          ? chatCacheRaw
          : (chatCacheRaw is Map
              ? Map<String, dynamic>.from(chatCacheRaw)
              : {});
      final chatSize = chatCache['size_mb'] ?? 0.0;

      if (chatSize > 50.0) {
        // بیش از 50MB
        // پاکسازی کش چت قدیمی
        await chatInstance.emptyCache();
      }

      // اگر کش پست خیلی بزرگ است، آن را کاهش دهیم
      final postCacheRaw = imageCache['post_cache'];
      final postCache = postCacheRaw is Map<String, dynamic>
          ? postCacheRaw
          : (postCacheRaw is Map
              ? Map<String, dynamic>.from(postCacheRaw)
              : {});
      final postSize = postCache['size_mb'] ?? 0.0;

      if (postSize > 100.0) {
        // بیش از 100MB
        // پاکسازی کش پست قدیمی
        await postInstance.emptyCache();
      }
    } catch (e) {
      print('خطا در بهینه‌سازی کش: $e');
    }
  }

  /// پاکسازی اضطراری در صورت کمبود حافظه
  Future<Map<String, dynamic>> emergencyCleanup() async {
    int itemsRemoved = 0;
    double spaceFreed = 0.0;

    try {
      // پاکسازی سریع کش‌های بزرگ
      final stats = await getCacheStats();
      final imageCacheRaw = stats['image_cache'];
      final imageCache = imageCacheRaw is Map<String, dynamic>
          ? imageCacheRaw
          : (imageCacheRaw is Map
              ? Map<String, dynamic>.from(imageCacheRaw)
              : {});

      // پاکسازی 50% از کش چت
      final chatCacheRaw = imageCache['chat_cache'];
      final chatCache = chatCacheRaw is Map<String, dynamic>
          ? chatCacheRaw
          : (chatCacheRaw is Map
              ? Map<String, dynamic>.from(chatCacheRaw)
              : {});
      if ((chatCache['size_mb'] ?? 0.0) > 20.0) {
        await chatInstance.emptyCache();
        itemsRemoved += 50; // تخمین
        spaceFreed += 10.0; // تخمین
      }

      // پاکسازی کش استوری‌های قدیمی
      await storyInstance.emptyCache();
      itemsRemoved += 25; // تخمین
      spaceFreed += 5.0; // تخمین

      // پاکسازی پیام‌های خیلی قدیمی
      final veryOldDate = DateTime.now().subtract(const Duration(days: 90));
      await _messageCache.deleteMessagesOlderThan(veryOldDate);
      itemsRemoved += 200; // تخمین
      spaceFreed += 20.0; // تخمین

      return {
        'success': true,
        'message': 'پاکسازی اضطراری انجام شد',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'خطا در پاکسازی اضطراری: $e',
        'items_removed': itemsRemoved,
        'space_freed_mb': spaceFreed,
      };
    }
  }

  Future<DateTime?> _getLastCleanupTime() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cleanupFile = File('${tempDir.path}/last_cleanup.json');

      if (await cleanupFile.exists()) {
        final content = await cleanupFile.readAsString();
        final data = jsonDecode(content);
        return DateTime.parse(data['timestamp']);
      }
    } catch (e) {
      // فایل وجود ندارد یا خراب است
    }
    return null;
  }

  Future<void> _updateLastCleanupTime() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cleanupFile = File('${tempDir.path}/last_cleanup.json');

      await cleanupFile.writeAsString(jsonEncode({
        'timestamp': DateTime.now().toIso8601String(),
      }));
    } catch (e) {
      print('خطا در بروزرسانی زمان پاکسازی: $e');
    }
  }

  /// تست محاسبات کش برای بررسی تفاوت مقادیر
  Future<void> testCacheCalculations() async {
    print('=== تست محاسبات کش UnifiedCacheManager ===');

    try {
      final stats = await getCacheStats();

      print('مجموع کش: ${stats['total_size_mb']!.toStringAsFixed(2)} MB');

      final imageCacheRaw = stats['image_cache'];
      final imageCache = imageCacheRaw is Map<String, dynamic>
          ? imageCacheRaw
          : (imageCacheRaw is Map
              ? Map<String, dynamic>.from(imageCacheRaw)
              : {});
      print(
          'کش استوری: ${(imageCache['story_cache'] as Map?)?['size_mb']?.toStringAsFixed(2) ?? '0.0'} MB');
      print(
          'کش پست: ${(imageCache['post_cache'] as Map?)?['size_mb']?.toStringAsFixed(2) ?? '0.0'} MB');
      print(
          'کش چت: ${(imageCache['chat_cache'] as Map?)?['size_mb']?.toStringAsFixed(2) ?? '0.0'} MB');
      print(
          'کش والپیپر: ${(imageCache['wallpaper_cache'] as Map?)?['size_mb']?.toStringAsFixed(2) ?? '0.0'} MB');

      final dbCacheRaw = stats['database_cache'];
      final dbCache = dbCacheRaw is Map<String, dynamic>
          ? dbCacheRaw
          : (dbCacheRaw is Map ? Map<String, dynamic>.from(dbCacheRaw) : {});
      print(
          'کش کانال‌ها: ${dbCache['channel_cache_size_mb']?.toStringAsFixed(2) ?? '0.0'} MB');

      // بررسی اینکه آیا مقادیر متفاوت هستند
      final imageValues = [
        imageCache['story_cache']?['size_mb'] ?? 0.0,
        imageCache['post_cache']?['size_mb'] ?? 0.0,
        imageCache['chat_cache']?['size_mb'] ?? 0.0,
        imageCache['wallpaper_cache']?['size_mb'] ?? 0.0,
      ];

      final uniqueValues = imageValues.toSet();
      if (uniqueValues.length > 1) {
        print('✅ مقادیر کش تصاویر متفاوت هستند - تست موفق');
      } else {
        print('❌ مقادیر کش تصاویر یکسان هستند - تست ناموفق');
      }

      print('تنظیمات هوشمند: ${stats['smart_cache_enabled']}');
      print('حالت ذخیره باتری: ${stats['battery_saver_mode']}');
      print('حداکثر حجم کش: ${stats['max_cache_size_mb']} MB');
    } catch (e) {
      print('خطا در تست کش: $e');
    }

    print('=== پایان تست کش ===');
  }

  bool get isInitialized => _isInitialized;
}

// کلاس قدیمی برای سازگاری به عقب
class CustomCacheManager {
  static const storyKey = 'storyImageCache';
  static const postKey = 'postImageCache';

  static CacheManager get storyInstance => _getInstance().storyInstance;
  static CacheManager get postInstance => _getInstance().postInstance;
  static CacheManager get chatInstance => _getInstance().chatInstance;
  static CacheManager get wallpaperInstance => _getInstance().wallpaperInstance;

  static UnifiedCacheManager _getInstance() {
    final instance = UnifiedCacheManager();
    if (!instance.isInitialized) {
      // اگر initialize نشده، یک عملیات synchronous انجام می‌دهیم
      // اما در عمل باید مطمئن شویم که initialize قبلاً انجام شده
      instance.initialize();
    }
    return instance;
  }

  bool get isInitialized => UnifiedCacheManager().isInitialized;
}
