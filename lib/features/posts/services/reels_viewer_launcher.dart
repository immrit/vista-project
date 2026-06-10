import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/publicPostModel.dart';
import '../../../provider/app_settings_provider.dart';
import '../../../widgets/ReelsScreen.dart';

/// Central entry point for opening the reels viewer from feed, profile, etc.
class ReelsViewerLauncher {
  ReelsViewerLauncher._();

  static List<PublicPostModel> videoPlaylist(List<PublicPostModel> posts) {
    return posts.where((post) => post.hasVideo).toList(growable: false);
  }

  static Future<void> open({
    required BuildContext context,
    required WidgetRef ref,
    required PublicPostModel post,
    required List<PublicPostModel> playlist,
    Duration initialPosition = Duration.zero,
  }) async {
    var videos = videoPlaylist(playlist);
    if (videos.isEmpty && post.hasVideo) {
      videos = [post];
    }
    if (videos.isEmpty) return;

    var index = videos.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      videos = [...videos, post];
      index = videos.length - 1;
    }

    final initialPositions = initialPosition > Duration.zero
        ? {post.id: initialPosition}
        : const <String, Duration>{};

    if (initialPosition > Duration.zero) {
      ref.read(videoPositionProvider(post.id).notifier).state =
          initialPosition;
    }

    if (!context.mounted) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReelsScreen(
          posts: List<PublicPostModel>.from(videos),
          initialIndex: index,
          initialPositions: initialPositions,
        ),
      ),
    );
  }
}
