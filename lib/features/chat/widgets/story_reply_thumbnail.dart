import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/message_model.dart';
import '../../stories/presentation/providers/story_providers.dart';
import '../utils/story_reply_media_utils.dart';

/// Story-reply thumbnail with API fallback when metadata has no image URL.
class StoryReplyThumbnail extends ConsumerStatefulWidget {
  final StoryReplyData data;
  final double size;
  final Color placeholderColor;
  final Color iconColor;

  const StoryReplyThumbnail({
    super.key,
    required this.data,
    this.size = 56,
    this.placeholderColor = const Color(0x33000000),
    this.iconColor = const Color(0x99FFFFFF),
  });

  @override
  ConsumerState<StoryReplyThumbnail> createState() =>
      _StoryReplyThumbnailState();
}

class _StoryReplyThumbnailState extends ConsumerState<StoryReplyThumbnail> {
  String? _imageUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = StoryReplyMediaUtils.resolveMediaUrl(widget.data.storyThumbnailUrl);
    if (_imageUrl == null || _imageUrl!.isEmpty) {
      _fetchFromStoryApi();
    }
  }

  @override
  void didUpdateWidget(StoryReplyThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.storyId != widget.data.storyId ||
        oldWidget.data.storyThumbnailUrl != widget.data.storyThumbnailUrl) {
      _imageUrl =
          StoryReplyMediaUtils.resolveMediaUrl(widget.data.storyThumbnailUrl);
      if (_imageUrl == null || _imageUrl!.isEmpty) {
        _fetchFromStoryApi();
      }
    }
  }

  Future<void> _fetchFromStoryApi() async {
    final storyId = widget.data.storyId.trim();
    if (storyId.isEmpty || _loading) return;

    setState(() => _loading = true);
    final result =
        await ref.read(storyRepositoryProvider).getStoryById(storyId);

    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      final url = StoryReplyMediaUtils.thumbnailFromStory(result.data!);
      setState(() {
        _imageUrl = url.isNotEmpty ? url : null;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.data.storyMediaType == 'video';
    final isQuestion = widget.data.replyKind == 'question';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_imageUrl != null && _imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: _imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (context, url) => _placeholder(isQuestion, isVideo),
                errorWidget: (context, url, error) =>
                    _placeholder(isQuestion, isVideo),
              )
            else
              _placeholder(isQuestion, isVideo),
            if (_loading)
              Container(
                color: widget.placeholderColor,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (isVideo && !_loading)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isQuestion, bool isVideo) {
    return ColoredBox(
      color: widget.placeholderColor,
      child: Icon(
        isQuestion
            ? Icons.question_answer_rounded
            : (isVideo ? Icons.videocam_rounded : Icons.image_rounded),
        color: widget.iconColor,
        size: widget.size * 0.42,
      ),
    );
  }
}
