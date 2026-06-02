import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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

  static ImageProvider? imageProvider(String? source) {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;

    final assetPath = assetPathFrom(value);
    if (assetPath != null) return AssetImage(assetPath);

    return CachedNetworkImageProvider(value);
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
    final value = source?.trim();
    final fallbackWidget = fallback ?? const SizedBox.shrink();
    if (value == null || value.isEmpty) return fallbackWidget;

    final assetPath = assetPathFrom(value);
    if (assetPath != null) {
      _notifyLoaded(onLoaded);
      return Image.asset(
        assetPath,
        fit: fit,
        errorBuilder: (_, __, ___) => fallbackWidget,
      );
    }

    return CachedNetworkImage(
      imageUrl: value,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
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
