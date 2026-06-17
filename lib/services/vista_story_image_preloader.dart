import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:http/http.dart' as http;

import '../model/publicPostModel.dart';
import '../utils/avatar_asset_utils.dart';
import '../utils/env_config.dart';

/// اطلاعات نویسنده پست — همیشه از داده پست، نه کاربر فعلی
class StoryPostAuthor {
  final String userId;
  final String username;
  final String fullName;
  final String avatarUrl;

  const StoryPostAuthor({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
  });

  factory StoryPostAuthor.fromPost(PublicPostModel post) {
    final profiles = post.profiles;
    final nestedAuthor = profiles?['author'];
    final authorMap =
        nestedAuthor is Map ? nestedAuthor.cast<String, dynamic>() : null;

    String pickUsername() {
      final values = [
        profiles?['username']?.toString(),
        authorMap?['username']?.toString(),
        post.username,
      ];
      for (final value in values) {
        final trimmed = value?.trim();
        if (trimmed != null &&
            trimmed.isNotEmpty &&
            trimmed != 'نام کاربری ناشناخته' &&
            trimmed != 'Unknown') {
          return trimmed;
        }
      }
      return '';
    }

    String pickFullName() {
      final values = [
        profiles?['full_name']?.toString(),
        authorMap?['full_name']?.toString(),
        post.fullName,
      ];
      for (final value in values) {
        final trimmed = value?.trim();
        if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      }
      return '';
    }

    return StoryPostAuthor(
      userId: post.userId,
      username: pickUsername(),
      fullName: pickFullName(),
      avatarUrl: VistaStoryImagePreloader.resolveAvatarUrl(post),
    );
  }
}

class VistaStoryPreloadedImages {
  final Uint8List? avatarBytes;
  final Uint8List? postImageBytes;
  final Uint8List? videoThumbnailBytes;

  const VistaStoryPreloadedImages({
    this.avatarBytes,
    this.postImageBytes,
    this.videoThumbnailBytes,
  });
}

/// پیش‌بارگذاری تصاویر برای رندر مطمئن در قالب استوری
class VistaStoryImagePreloader {
  static final _cacheManager = DefaultCacheManager();

  static String resolveAvatarUrl(PublicPostModel post) {
    final nestedAuthor = post.profiles?['author'];
    final authorMap =
        nestedAuthor is Map ? nestedAuthor.cast<String, dynamic>() : null;

    final candidates = <String>[
      post.profiles?['avatar_url']?.toString().trim() ?? '',
      post.profiles?['avatarUrl']?.toString().trim() ?? '',
      authorMap?['avatar_url']?.toString().trim() ?? '',
      post.avatarUrl.trim(),
    ];

    for (final candidate in candidates) {
      if (candidate.isNotEmpty) {
        return _normalizeMediaUrl(candidate);
      }
    }

    return '';
  }

  static String resolvePostImageUrl(PublicPostModel post) {
    final url = post.imageUrl?.trim() ?? '';
    if (url.isEmpty) return '';
    return _normalizeMediaUrl(url);
  }

  static String resolveVideoUrl(PublicPostModel post) {
    final url = post.videoUrl?.trim() ?? '';
    if (url.isEmpty) return '';
    return _normalizeMediaUrl(url);
  }

  static Future<VistaStoryPreloadedImages> preloadForPost(
    PublicPostModel post,
  ) async {
    final author = StoryPostAuthor.fromPost(post);
    final postImageUrl = resolvePostImageUrl(post);

    final avatarBytes = await loadImageBytes(author.avatarUrl, retries: 2);
    Uint8List? postImageBytes;
    Uint8List? videoThumbnailBytes;

    if (postImageUrl.isNotEmpty) {
      postImageBytes = await loadImageBytes(postImageUrl, retries: 1);
    }

    if (post.hasVideo) {
      if (postImageBytes != null && postImageBytes.isNotEmpty) {
        videoThumbnailBytes = postImageBytes;
      } else {
        videoThumbnailBytes = await loadVideoThumbnail(post);
      }
    }

    return VistaStoryPreloadedImages(
      avatarBytes: avatarBytes,
      postImageBytes: postImageBytes,
      videoThumbnailBytes: videoThumbnailBytes,
    );
  }

  static Future<Uint8List?> loadVideoThumbnail(PublicPostModel post) async {
    final videoUrl = resolveVideoUrl(post);
    if (videoUrl.isEmpty) return null;

    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        quality: 75,
        maxWidth: 720,
      );
      if (bytes.isNotEmpty) return bytes;
    } catch (_) {}

    return null;
  }

  static Future<Uint8List?> loadImageBytes(
    String? source, {
    int retries = 0,
  }) async {
    final value = source?.trim();
    if (value == null || value.isEmpty) return null;

    for (var attempt = 0; attempt <= retries; attempt++) {
      final bytes = await _loadImageBytesOnce(value);
      if (bytes != null) return bytes;
      if (attempt < retries) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }

    return null;
  }

  static Future<Uint8List?> _loadImageBytesOnce(String value) async {
    final assetPath = AvatarAssetUtils.assetPathFrom(value);
    if (assetPath != null) {
      try {
        final data = await rootBundle.load(assetPath);
        return data.buffer.asUint8List();
      } catch (_) {
        return null;
      }
    }

    try {
      final file = await _cacheManager.getSingleFile(value);
      return await file.readAsBytes();
    } catch (_) {}

    try {
      final response =
          await http.get(Uri.parse(value)).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}

    return null;
  }

  static String _normalizeMediaUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }

    final baseUrl = EnvConfig.apiBaseUrl.replaceFirst('api.', 's3.');
    final cleanPath = url.startsWith('/') ? url.substring(1) : url;
    return '$baseUrl/$cleanPath';
  }
}
