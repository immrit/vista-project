import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'env_config.dart';

class AvatarAssetUtils {
  static const String vistaServiceAvatar = 'lib/utils/images/vistalogo-new.png';
  static const String vistaSupportAvatar = 'lib/utils/images/support_icon.png';

  static String? assetPathFrom(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;

    if (value.startsWith('asset://')) {
      final path = value.substring('asset://'.length).trim();
      return path.isEmpty ? null : path;
    }

    if (value.startsWith('lib/utils/images/') ||
        value.startsWith('assets/images/')) {
      return value;
    }

    return null;
  }

  static bool isAssetSource(String? source) => assetPathFrom(source) != null;

  /// Converts relative storage paths to absolute CDN URLs.
  static String? resolveUrl(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;
    if (isAssetSource(value)) return value;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return 'https:$value';
    }

    final baseUrl = EnvConfig.apiBaseUrl.replaceFirst('api.', 's3.');
    final cleanPath = value.startsWith('/') ? value.substring(1) : value;
    return '$baseUrl/$cleanPath';
  }

  static String? firstResolvedUrl(Object? primary, [Object? secondary]) {
    for (final candidate in [primary, secondary]) {
      final resolved = resolveUrl(candidate?.toString());
      if (resolved != null && resolved.isNotEmpty) return resolved;
    }
    return null;
  }

  static ImageProvider? imageProvider(String? source) {
    final resolved = resolveUrl(source);
    if (resolved == null) return null;

    final assetPath = assetPathFrom(resolved);
    if (assetPath != null) return AssetImage(assetPath);

    return CachedNetworkImageProvider(resolved);
  }

  static Widget image({
    required String? source,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? fallback,
    int? memCacheWidth,
    int? memCacheHeight,
    VoidCallback? onLoaded,
  }) {
    final resolved = resolveUrl(source);
    final fallbackWidget = fallback ?? const SizedBox.shrink();
    if (resolved == null) return fallbackWidget;

    final assetPath = assetPathFrom(resolved);
    if (assetPath != null) {
      _notifyLoaded(onLoaded);
      return Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackWidget,
      );
    }

    return CachedNetworkImage(
      imageUrl: resolved,
      cacheKey: resolved,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      placeholder: (_, __) => placeholder ?? fallbackWidget,
      errorWidget: (_, __, ___) => fallbackWidget,
      imageBuilder: (context, imageProvider) {
        _notifyLoaded(onLoaded);
        return Image(image: imageProvider, fit: fit);
      },
    );
  }

  static void _notifyLoaded(VoidCallback? onLoaded) {
    if (onLoaded == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded());
  }
}
