import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/cache_manager.dart';
import '../../../services/image_quality_service.dart';

class PostImage extends ConsumerWidget {
  final String imageUrl;

  const PostImage({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageQualityService = ImageQualityService();
    final cacheSettings = imageQualityService.getImageCacheSettings();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: CustomCacheManager.postInstance,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => const Icon(Icons.error),
      fit: BoxFit.cover,
      memCacheWidth: cacheSettings['maxWidth'],
      memCacheHeight: cacheSettings['maxHeight'],
      imageBuilder: (context, imageProvider) {
        return Image(
          image: imageProvider,
          fit: BoxFit.cover,
          // اعمال تنظیمات کیفیت تصویر
          filterQuality: imageQualityService.shouldUseHighQuality()
              ? FilterQuality.high
              : FilterQuality.low,
        );
      },
    );
  }
}
