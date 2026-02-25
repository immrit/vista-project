import '../../security/logging_utility.dart';
import 'dart:async';
import 'package:Vista/utils/widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
import '../../services/cache_manager.dart';
import '../../features/posts/providers/saved_posts_provider.dart';
import 'verification_badge_icon.dart';

class ReelsVideoPlayer extends ConsumerStatefulWidget {
  final PublicPostModel post;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final Duration? initialPosition;
  final Function(Duration)? onPositionChanged;
  final bool autoPlayInFeed; // پارامتر جدید

  const ReelsVideoPlayer({
    super.key,
    required this.post,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.initialPosition,
    this.onPositionChanged,
    this.autoPlayInFeed = false, // مقدار پیش‌فرض false
  });

  @override
  ConsumerState<ReelsVideoPlayer> createState() => _ReelsVideoPlayerState();
}

class _ReelsVideoPlayerState extends ConsumerState<ReelsVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isVisible = false;
  bool _isMuted = true;
  bool _showLikeAnim = false;
  Timer? _likeAnimTimer;
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;
  final bool _showVolumeControl = false;
  Timer? _volumeControlTimer;
  bool _isCaptionExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    // اضافه کردن listener برای آپدیت موقعیت ویدیو
    _controller?.addListener(() {
      if (mounted) {
        setState(() {
          _currentPosition = _controller?.value.position ?? Duration.zero;
          _videoDuration = _controller?.value.duration ?? Duration.zero;
        });

        // اطلاع‌رسانی به parent widget
        if (widget.onPositionChanged != null) {
          widget.onPositionChanged!(_currentPosition);
        }
      }
    });
  }

  @override
  void didUpdateWidget(ReelsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive) {
      _handleActiveStateChange();
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.post.videoUrl == null || widget.post.videoUrl!.isEmpty) return;

    _controller = VideoPlayerController.network(widget.post.videoUrl!);

    try {
      await _controller?.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // اگر initialPosition وجود داشت، به آن موقعیت برو
        if (widget.initialPosition != null) {
          _controller?.seekTo(widget.initialPosition!);
        }

        _controller?.setLooping(true);
        _controller?.setVolume(_isMuted ? 0.0 : 1.0);

        if (_isVisible && widget.isActive) {
          _controller?.play();
          _isPlaying = true;
        }
      }
    } catch (e) {
      logInfo('Error initializing video: $e');
    }
  }

  void _handleActiveStateChange() {
    if (!_isInitialized) return;

    if (widget.isActive && _isVisible) {
      _controller?.play();
      setState(() => _isPlaying = true);
    } else {
      _controller?.pause();
      setState(() => _isPlaying = false);
    }
  }

  void _togglePlay() {
    if (!_isInitialized) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller?.play() : _controller?.pause();
    });
  }

  void _toggleMute() {
    if (!_isInitialized) return;

    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _showLikeAnimation() {
    // حذف فراخوانی widget.onLike() از اینجا

    _likeAnimTimer?.cancel();
    setState(() {
      _showLikeAnim = true;
    });

    _likeAnimTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLikeAnim = false;
        });
      }
    });
  }

  String _getFormattedDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _handleLike() async {
    try {
      final currentLikeState = !widget.post.isLiked;

      // آپدیت وضعیت لایک در provider
      ref
          .read(likeStateProvider.notifier)
          .updateLikeState(widget.post.id, currentLikeState);

      // آپدیت UI محلی
      setState(() {
        widget.post.isLiked = currentLikeState;
        widget.post.likeCount += currentLikeState ? 1 : -1;
      });

      // نمایش انیمیشن لایک
      _showLikeAnimation();

      // ارسال به سرور
      await ref.watch(supabaseServiceProvider).toggleLike(
            postId: widget.post.id,
            ownerId: widget.post.userId,
            ref: ref,
          );
    } catch (e) {
      // در صورت خطا، UI را به حالت قبل برمی‌گردانیم
      final previousLikeState = !widget.post.isLiked;
      ref
          .read(likeStateProvider.notifier)
          .updateLikeState(widget.post.id, previousLikeState);

      setState(() {
        widget.post.isLiked = previousLikeState;
        widget.post.likeCount += previousLikeState ? 1 : -1;
      });
      logDebug('Error in handleLike: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _likeAnimTimer?.cancel();
    _volumeControlTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final savedPostIdsAsync = ref.watch(savedPostIdsProvider);
    final isSaved = savedPostIdsAsync.maybeWhen(
      data: (ids) => ids.contains(widget.post.id),
      orElse: () => false,
    );

    return VisibilityDetector(
      key: Key('video-${widget.post.id}'),
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return; // مهم!
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        setState(() {
          _isVisible = visiblePercentage > 50;
        });

        // فقط در صفحه ریلز، ویدیو را به صورت خودکار پخش کنیم
        // از autoPlayInFeed استفاده می‌کنیم تا در لیست پست‌ها کنترل داشته باشیم
        if (_isVisible && widget.isActive && widget.autoPlayInFeed) {
          _controller?.play();
          setState(() {
            _isPlaying = true;
          });
        } else if (!_isVisible || !widget.isActive) {
          _controller?.pause();
          setState(() {
            _isPlaying = false;
          });
        }
      },
      child: GestureDetector(
        onTap: _togglePlay,
        onDoubleTap: () {
          _handleLike(); // مستقیم از _handleLike استفاده کنید
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            _isInitialized
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            Container(color: Colors.black.withValues(alpha: 0.3)),
            if (_showLikeAnim)
              Center(
                child: AnimatedOpacity(
                  opacity: _showLikeAnim ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.5, end: 1.5),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 100,
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_showVolumeControl)
              Positioned(
                right: 16,
                top: MediaQuery.of(context).size.height / 2 - 40,
                child: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _isMuted ? "بی‌صدا" : "باصدا",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 12,
              bottom: MediaQuery.of(context).size.height * 0.15,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      IconButton(
                        onPressed: _handleLike,
                        icon: Icon(
                          widget.post.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              widget.post.isLiked ? Colors.red : Colors.white,
                          size: 32,
                        ),
                      ),
                      Text(
                        widget.post.likeCount.toString(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () {
                          showCommentsBottomSheet(context, widget.post.id, ref);
                        },
                        icon: Image.asset(
                          'lib/utils/images/component/comment.png',
                          width: 32,
                          height: 32,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.post.commentCount.toString(),
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Column(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final ok = await ref
                              .read(savedPostIdsProvider.notifier)
                              .toggle(widget.post.id, post: widget.post);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('خطا در ذخیره پست')),
                            );
                          }
                        },
                        icon: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color:
                              isSaved ? Colors.lightBlueAccent : Colors.white,
                          size: 32,
                        ),
                      ),
                      Text(
                        isSaved ? 'ذخیره شد' : 'ذخیره',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  IconButton(
                    onPressed: widget.onShare,
                    icon: Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  SizedBox(height: 16),
                  IconButton(
                    onPressed: _toggleMute,
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 50,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CachedNetworkImage(
                          imageUrl: widget.post.avatarUrl,
                          imageBuilder: (context, imageProvider) =>
                              CircleAvatar(
                            radius: 20,
                            backgroundImage: imageProvider,
                            child: null,
                          ),
                          placeholder: (context, url) => CircleAvatar(
                            radius: 20,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                NetworkImage(widget.post.avatarUrl),
                            child: null,
                          ),
                          cacheManager: CustomCacheManager.instanceSync,
                        ),
                        SizedBox(width: 8),
                        Row(
                          children: [
                            Text(
                              widget.post.username.isNotEmpty
                                  ? widget.post.username
                                  : "کاربر",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.post.isVerified) ...[
                              SizedBox(width: 4),
                              _buildVerificationBadge(),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (widget.post.content.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isCaptionExpanded = !_isCaptionExpanded;
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.only(top: 8),
                          child: RichText(
                            maxLines: _isCaptionExpanded ? null : 2,
                            overflow: _isCaptionExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.post.content,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                if (!_isCaptionExpanded &&
                                    widget.post.content.length > 50)
                                  TextSpan(
                                    text: " ... بیشتر",
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getFormattedDuration(_currentPosition),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 2,
                              thumbShape:
                                  RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape:
                                  RoundSliderOverlayShape(overlayRadius: 12),
                            ),
                            child: Slider(
                              value: _currentPosition.inMilliseconds.toDouble(),
                              min: 0.0,
                              max: _videoDuration.inMilliseconds.toDouble(),
                              activeColor: Colors.white,
                              inactiveColor:
                                  Colors.white.withValues(alpha: 0.5),
                              onChanged: (value) {
                                _controller?.seekTo(
                                    Duration(milliseconds: value.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _getFormattedDuration(_videoDuration),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!_isPlaying)
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadge() {
    return VerificationBadgeIcon(
      isVerified: widget.post.isVerified,
      verificationType: widget.post.verificationType,
      role: widget.post.profiles?['role']?.toString(),
      size: 14,
    );
  }
}
