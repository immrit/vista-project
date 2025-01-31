import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CustomCacheManager {
  static const storyKey = 'storyImageCache';
  static const postKey = 'postImageCache';

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
}
