import 'dart:async';
import 'dart:math' as math;
import 'package:Vista/view/util/widgets.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';

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
    Key? key,
    required this.post,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.initialPosition,
    this.onPositionChanged,
    this.autoPlayInFeed = false, // مقدار پیش‌فرض false
  }) : super(key: key);

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
  bool _showVolumeControl = false;
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
    _fetchVerificationType(); // فراخوانی تابع برای دریافت نوع تأیید
  }

  String? _directVerificationType;

  Future<void> _fetchVerificationType() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('verification_type')
          .eq('username', widget.post.username)
          .single();

      setState(() {
        _directVerificationType = response['verification_type'];
      });

      print('Direct verification type from API: $_directVerificationType');
    } catch (e) {
      print('Error fetching verification type: $e');
    }
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
      print('Error initializing video: $e');
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
          .updateLikeState(widget.post.id!, currentLikeState);

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
          .updateLikeState(widget.post.id!, previousLikeState);

      setState(() {
        widget.post.isLiked = previousLikeState;
        widget.post.likeCount += previousLikeState ? 1 : -1;
      });
      debugPrint('Error in handleLike: $e');
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
    return VisibilityDetector(
      key: Key('video-${widget.post.id}'),
      onVisibilityChanged: (visibilityInfo) {
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
            Container(color: Colors.black.withOpacity(0.3)),
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
                    color: Colors.black.withOpacity(0.6),
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
                          showCommentsBottomSheet(
                              context, widget.post.id!, ref);
                        },
                        icon: const Icon(
                          Icons.comment,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      Text(
                        widget.post.commentCount.toString(),
                        style: TextStyle(color: Colors.white),
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
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: widget.post.avatarUrl != null
                              ? NetworkImage(widget.post.avatarUrl!)
                              : null,
                          child: widget.post.avatarUrl == null
                              ? Icon(Icons.person, color: Colors.white)
                              : null,
                        ),
                        SizedBox(width: 8),
                        Row(
                          children: [
                            Text(
                              widget.post.username ?? "کاربر",
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
                    if (widget.post.content != null &&
                        widget.post.content.isNotEmpty)
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
                                      color: Colors.white.withOpacity(0.7),
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
                              inactiveColor: Colors.white.withOpacity(0.5),
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
                    color: Colors.black.withOpacity(0.3),
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
    if (!widget.post.isVerified) return const SizedBox.shrink();

    final verificationType =
        _directVerificationType ?? widget.post.verificationType;

    switch (verificationType) {
      case 'goldTick':
        return const Icon(Icons.verified, color: Colors.amber, size: 14);
      case 'blueTick':
        return const Icon(Icons.verified, color: Colors.blue, size: 14);
      case 'blackTick':
        return Container(
          padding: const EdgeInsets.all(.1),
          decoration: const BoxDecoration(
            color: Colors.white60,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.verified, color: Colors.black, size: 12),
        );
      default:
        return const Icon(Icons.verified, color: Colors.blue, size: 14);
    }
  }
}
