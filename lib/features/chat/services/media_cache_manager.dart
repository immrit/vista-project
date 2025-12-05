// lib/features/chat/services/media_cache_manager.dart
//
// مدیریت کش تصاویر و مدیا
//
// ویژگی‌ها:
// ✅ کش هوشمند برای تصاویر چت
// ✅ محدودیت اندازه و تعداد فایل‌ها
// ✅ ریسایز خودکار در مموری
// ✅ Placeholder و Error handling
// ✅ Fade animation برای بارگیری

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';

/// مدیریت کش برای تصاویر و مدیا
class MediaCacheManager {
  // ساخت CacheManager اختصاصی برای چت
  static final chatCacheManager = CacheManager(
    Config(
      'chat_media_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: 'chat_media_cache'),
      fileService: HttpFileService(),
    ),
  );

  /// ویجت هوشمند برای نمایش تصاویر چت
  static Widget buildChatImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    bool showShimmer = true,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: chatCacheManager,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      // ریسایز خودکار برای کاهش مصرف RAM
      memCacheWidth: 400,
      memCacheHeight: (height != null && width != null)
          ? ((height / width) * 400).toInt()
          : 400,
      // Placeholder - Shimmer Effect
      placeholder: (context, url) => showShimmer
          ? _buildShimmerPlaceholder(width, height)
          : _buildSimplePlaceholder(width, height),
      // Error Widget
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error, color: Colors.grey),
      ),
      imageBuilder: (context, imageProvider) {
        Widget child = Image(image: imageProvider, fit: fit);

        if (borderRadius != null) {
          child = ClipRRect(
            borderRadius: borderRadius,
            child: child,
          );
        }

        return child;
      },
    );
  }

  /// Placeholder ساده
  static Widget _buildSimplePlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey),
      ),
    );
  }

  /// Placeholder با Shimmer Effect (مثل تلگرام)
  static Widget _buildShimmerPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          color: Colors.white,
        ),
      ),
    );
  }

  /// پاک کردن کل کش
  static Future<void> clearCache() async {
    await chatCacheManager.emptyCache();
  }

  /// حذف یک فایل کش
  static Future<void> removeCacheFile(String url) async {
    await chatCacheManager.removeFile(url);
  }

  /// دریافت اطلاعات کش
  static Future<FileInfo?> getCacheInfo(String url) async {
    return await chatCacheManager.getFileFromCache(url);
  }
}
