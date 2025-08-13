import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  static const storyKey = 'storyImageCache';
  static const postKey = 'postImageCache';
  static const String _chatCacheKey =
      'chat_image_cache'; // کلید جدید برای تصاویر چت

  static CacheManager storyInstance = CacheManager(
    Config(
      storyKey,
      stalePeriod: const Duration(days: 1),
      maxNrOfCacheObjects: 100,
    ),
  );

  static CacheManager postInstance = CacheManager(
    Config(
      postKey,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  static final CacheManager chatInstance = CacheManager(
    Config(
      _chatCacheKey,
      stalePeriod: const Duration(days: 7), // دوره نگهداری متوسط برای تصاویر چت
      maxNrOfCacheObjects: 200, // تعداد بیشتر برای تصاویر چت
    ),
  );

  // Cache manager اختصاصی برای والپیپرهای چت با مدت زمان کش طولانی‌تر
  static const String _wallpaperCacheKey = 'chat_wallpaper_cache';
  static final CacheManager wallpaperInstance = CacheManager(
    Config(
      _wallpaperCacheKey,
      stalePeriod:
          const Duration(days: 30), // نگهداری طولانی‌مدت برای والپیپرها
      maxNrOfCacheObjects: 50, // تعداد کم اما کیفیت بالا
      fileService: HttpFileService(),
    ),
  );
}
