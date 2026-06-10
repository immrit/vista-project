import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';

import '../../../model/publicPostModel.dart';
import '../../../services/video_autoplay_service.dart';
import '../../../widgets/CustomVideoPlayer.dart';
import '../services/reels_viewer_launcher.dart';

class PostFeedVideo extends ConsumerStatefulWidget {
  final PublicPostModel post;
  final List<PublicPostModel>? reelsPlaylist;
  final double maxHeight;
  final BorderRadius borderRadius;

  const PostFeedVideo({
    super.key,
    required this.post,
    this.reelsPlaylist,
    this.maxHeight = 420,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  ConsumerState<PostFeedVideo> createState() => _PostFeedVideoState();
}

class _PostFeedVideoState extends ConsumerState<PostFeedVideo> {
  Uint8List? _thumbnailBytes;
  bool _loadingThumbnail = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (widget.post.imageUrl?.isNotEmpty == true) return;

    final videoUrl = widget.post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) return;

    setState(() => _loadingThumbnail = true);
    try {
      final autoplayService = VideoAutoplayService();
      await autoplayService.loadSettings();
      final dataSaver = autoplayService.dataSaverEnabled;

      final bytes = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        quality: dataSaver ? 40 : 75,
        maxWidth: dataSaver ? 360 : 720,
      );

      if (!mounted) return;
      if (bytes.isNotEmpty) {
        setState(() => _thumbnailBytes = bytes);
      }
    } catch (_) {
      // Thumbnail generation can fail on some devices; player still works.
    } finally {
      if (mounted) setState(() => _loadingThumbnail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoUrl = widget.post.videoUrl;
    if (videoUrl == null || videoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final autoplayService = VideoAutoplayService();
    final effectiveMaxHeight = autoplayService.dataSaverEnabled
        ? widget.maxHeight * 0.85
        : widget.maxHeight;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: double.infinity,
        child: CustomVideoPlayer(
          videoUrl: videoUrl,
          thumbnailUrl: widget.post.imageUrl,
          thumbnailBytes: _thumbnailBytes,
          loadingThumbnail: _loadingThumbnail,
          postId: widget.post.id,
          autoplay: true,
          muted: true,
          showProgress: true,
          showControls: true,
          maxHeight: effectiveMaxHeight,
          onVideoPositionTap: _openReels,
        ),
      ),
    );
  }

  void _openReels(Duration position) {
    ReelsViewerLauncher.open(
      context: context,
      ref: ref,
      post: widget.post,
      playlist: widget.reelsPlaylist ?? [widget.post],
      initialPosition: position,
    );
  }
}
