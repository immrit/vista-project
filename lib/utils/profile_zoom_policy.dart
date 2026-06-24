import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';

import 'avatar_asset_utils.dart';
import '../provider/settings_providers.dart';

/// Central policy for whether a viewer may enlarge another user's profile photo.
class ProfileZoomPolicy {
  ProfileZoomPolicy._();

  static const String settingsKey = 'allow_profile_zoom';

  static bool allowsFromSettings(Map<String, dynamic>? settings) {
    return settings?[settingsKey] as bool? ?? true;
  }

  static bool canViewerEnlarge({
    required String? viewerUserId,
    required String targetUserId,
    Map<String, dynamic>? targetSettings,
    bool? cachedAllowProfileZoom,
  }) {
    if (viewerUserId != null && viewerUserId == targetUserId) {
      return true;
    }

    if (targetSettings != null) {
      return allowsFromSettings(targetSettings);
    }

    if (cachedAllowProfileZoom != null) {
      return cachedAllowProfileZoom;
    }

    // Unknown remote preference: deny enlargement for other users.
    return false;
  }

  static Future<bool> resolveCanViewerEnlarge({
    required WidgetRef ref,
    required String? viewerUserId,
    required String targetUserId,
    bool? cachedAllowProfileZoom,
  }) async {
    if (viewerUserId != null && viewerUserId == targetUserId) {
      return true;
    }

    if (cachedAllowProfileZoom == false) {
      return false;
    }

    try {
      final settings = await ref.read(userSettingsByIdProvider(targetUserId).future);
      return allowsFromSettings(settings);
    } catch (_) {
      return cachedAllowProfileZoom ?? false;
    }
  }

  static void showRestrictedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.lock_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          'محدودیت دسترسی',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'این کاربر اجازه بزرگنمایی تصویر پروفایل خود را غیرفعال کرده است.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }

  static Future<void> openEnlargedAvatar({
    required BuildContext context,
    required WidgetRef ref,
    required String targetUserId,
    required String? avatarUrl,
    required String? viewerUserId,
    String? heroTag,
    bool? cachedAllowProfileZoom,
  }) async {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return;
    }

    if (viewerUserId != null && viewerUserId == targetUserId) {
      // User can always view their own avatar
    } else if (cachedAllowProfileZoom == false) {
      showRestrictedDialog(context);
      return;
    } else if (cachedAllowProfileZoom == null) {
      // In the new engineered architecture, allowProfileZoom is always provided by models.
      // If null, we default to showing restricted dialog out of an abundance of caution,
      // or we can allow it if we want to be lenient. Let's be lenient by default for nulls (backward compatibility).
    }

    final avatarProvider = AvatarAssetUtils.imageProvider(avatarUrl);
    if (avatarProvider == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: heroTag == null
              ? PhotoView(
                  imageProvider: avatarProvider,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                )
              : Hero(
                  tag: heroTag,
                  child: PhotoView(
                    imageProvider: avatarProvider,
                    backgroundDecoration:
                        const BoxDecoration(color: Colors.black),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 2,
                  ),
                ),
        ),
      ),
    );
  }
}
