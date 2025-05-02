import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool autoplay;
  final bool muted;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool looping;
  final double? maxHeight;
  final String? postId;
  final String? username;
  final int? likeCount;
  final int? commentCount;
  final bool? isLiked;
  final Function? onLike;
  final Function? onComment;

  const CustomVideoPlayer({
    Key? key,
    required this.videoUrl,
    this.autoplay = true,
    this.muted = true,
    this.onTap,
    this.showProgress = true,
    this.looping = true,
    this.maxHeight,
    this.postId,
    this.username,
    this.likeCount,
    this.commentCount,
    this.isLiked,
    this.onLike,
    this.onComment,
  }) : super(key: key);

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showPlayButton = false;
  bool _isPlaying = false;
  bool _showControls = false;
  Timer? _hideControlsTimer;
  late AnimationController _animationController;
  bool _isDragging = false;
  double _seekPosition = 0.0;

  // برای نمایش بهتر لودینگ
  bool _isBuffering = false;

  // برای نمایش دابل تپ لایک
  bool _showLikeAnim = false;
  Timer? _likeAnimTimer;

  // کنترل حجم صدا با حرکت عمودی
  double _startDragY = 0;
  double _initialVolume = 0;
  bool _isVolumeControlVisible = false;
  bool _isDraggingVolume = false;
  Timer? _hideVolumeControlTimer;

  // خودکار پخش در محدوده نمایش
  final GlobalKey _videoKey = GlobalKey();
  bool _isVisible = false;
  final _visibilityThreshold = 0.7; // درصد بیشتر برای تجربه بهتر

  // بهبود عملکرد موقعیت پخش
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // برای انیمیشن پخش/مکث
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializePlayer();

    // افزودن ویزیبیلیتی دیتکتور
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;

    final box = _videoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    // روش بهتر برای محاسبه ویوپورت با استفاده از MediaQuery
    final mediaQuery = MediaQuery.of(context);
    final vpHeight = mediaQuery.size.height;
    final vpTop = mediaQuery.padding.top;
    final vpBottom = mediaQuery.padding.bottom;
    final effectiveVpHeight = vpHeight - vpTop - vpBottom;

    final pos = box.localToGlobal(Offset.zero);
    final height = box.size.height;

    final visibleTop = math.max(vpTop, pos.dy);
    final visibleBottom = math.min(vpHeight - vpBottom, pos.dy + height);

    if (visibleBottom <= visibleTop) {
      if (_isVisible) {
        setState(() {
          _isVisible = false;
        });
        if (_isPlaying) {
          _pauseVideo();
        }
      }
      return;
    }

    final visibleHeight = visibleBottom - visibleTop;
    final visibleRatio = visibleHeight / height;

    final newIsVisible = visibleRatio >= _visibilityThreshold;

    if (newIsVisible != _isVisible) {
      setState(() {
        _isVisible = newIsVisible;
      });

      if (_isVisible && widget.autoplay && _isInitialized && !_isPlaying) {
        _playVideo();
      } else if (!_isVisible && _isPlaying) {
        _pauseVideo();
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      // نمایش لودینگ در زمان آماده‌سازی ویدئو
      setState(() {
        _isBuffering = true;
      });

      await _controller.initialize();

      _videoDuration = _controller.value.duration;
      _controller.setLooping(widget.looping);
      _controller.setVolume(widget.muted ? 0.0 : 1.0);
      _initialVolume = widget.muted ? 0.0 : 1.0;

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
          _showPlayButton = !widget.autoplay;
        });

        if (widget.autoplay && _isVisible) {
          _playVideo();
        }

        // تنظیم کردن لیسنر‌ها
        _controller.addListener(_videoListener);
      }
    } catch (e) {
      print('خطا در بارگذاری ویدیو: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
          _showPlayButton = true;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;

    // بررسی وضعیت پخش
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // بررسی وضعیت بافرینگ
    final isBuffering = _controller.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }

    // به‌روزرسانی موقعیت پخش
    final currentPosition = _controller.value.position;
    if (currentPosition != _currentPosition) {
      setState(() {
        _currentPosition = currentPosition;
      });
    }

    // اگر ویدیو به پایان رسید
    if (_controller.value.position >= _controller.value.duration &&
        !widget.looping) {
      setState(() {
        _isPlaying = false;
        _showPlayButton = true;
      });
    }
  }

  void _playVideo() {
    if (!_isInitialized) return;

    _controller.play();
    setState(() {
      _isPlaying = true;
      _showPlayButton = false;
      _isAnimating = true;
    });

    // انیمیشن شروع پخش
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _pauseVideo() {
    if (!_isInitialized) return;

    _controller.pause();
    setState(() {
      _isPlaying = false;
      _showPlayButton = true;
      _isAnimating = true;
    });

    // انیمیشن توقف پخش
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    _resetHideControlsTimer();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (_showControls) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _showLikeAnimation() {
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

  void _handleVolumeChange(double deltaY) {
    _hideVolumeControlTimer?.cancel();

    if (!_isDraggingVolume) {
      setState(() {
        _isDraggingVolume = true;
        _isVolumeControlVisible = true;
      });
    }

    final volumeDelta = deltaY / 200; // چقدر حساس باشد
    final newVolume = (_initialVolume - volumeDelta).clamp(0.0, 1.0);

    _controller.setVolume(newVolume);
    setState(() {});

    _hideVolumeControlTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isVolumeControlVisible = false;
          _isDraggingVolume = false;
        });
      }
    });
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (mounted) {
      _checkVisibility();
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _hideVolumeControlTimer?.cancel();
    _likeAnimTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _videoKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        constraints: widget.maxHeight != null
            ? BoxConstraints(maxHeight: widget.maxHeight!)
            : null,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias, // برای رعایت borderRadius
        child: GestureDetector(
          onTap: () {
            // با کلیک روی ویدیو به حالت تمام صفحه برود
            _openFullScreen(context);
          },
          onDoubleTap: () {
            _showLikeAnimation();
            // می‌توانید اینجا لایک کردن پست را اضافه کنید
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ویدیو پلیر
              if (_isInitialized)
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Colors.white.withOpacity(0.8),
                        strokeWidth: 2.0,
                      ),
                    ),
                  ),
                ),

              // انیمیشن لایک دابل‌تپ
              if (_showLikeAnim)
                Center(
                  child: AnimatedOpacity(
                    opacity: _showLikeAnim ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.5, end: 1.2),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Icon(
                            Icons.favorite,
                            color: Colors.white.withOpacity(0.9),
                            size: 100,
                          ),
                        );
                      },
                      onEnd: () {
                        // انیمیشن کوچک شدن و محو شدن آیکون قلب
                        Future.delayed(const Duration(milliseconds: 200), () {
                          if (_showLikeAnim && mounted) {
                            setState(() {
                              _showLikeAnim = false;
                            });
                          }
                        });
                      },
                    ),
                  ),
                ),

              // نمایش دکمه پخش بزرگ وسط صفحه
              if (_showPlayButton && !_isBuffering)
                AnimatedOpacity(
                  opacity: _showPlayButton ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white.withOpacity(0.9),
                        size: 48,
                        semanticLabel: 'پخش ویدیو',
                      ),
                    ),
                  ),
                ),

              // انیمیشن پخش/مکث
              if (_isAnimating)
                AnimatedOpacity(
                  opacity: _isAnimating ? 0.7 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),

              // نشانگر صدای قطع شده
              if (_controller.value.volume == 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.volume_off,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // نمایش آیکون تمام صفحه در گوشه
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () => _openFullScreen(context),
                    splashRadius: 20,
                  ),
                ),
              ),

              // ایندیکیتور بافرینگ با انیمیشن پالس
              if (_isBuffering)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.2),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.9),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    onEnd: () {
                      // تکرار انیمیشن
                      if (mounted && _isBuffering) {
                        setState(() {});
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenVideoPlayer(
          controller: _controller,
          videoUrl: widget.videoUrl,
          username: widget.username,
          likeCount: widget.likeCount,
          commentCount: widget.commentCount,
          isLiked: widget.isLiked,
          postId: widget.postId,
        ),
      ),
    );
  }
}

class FullScreenVideoPlayer extends ConsumerStatefulWidget {
  final VideoPlayerController controller;
  final String videoUrl;
  final String? username;
  final int? likeCount;
  final int? commentCount;
  final bool? isLiked;
  final String? postId;
  final String? userId;

  const FullScreenVideoPlayer({
    Key? key,
    required this.controller,
    required this.videoUrl,
    this.username,
    this.likeCount,
    this.commentCount,
    this.isLiked,
    this.postId,
    this.userId,
  }) : super(key: key);

  @override
  ConsumerState<FullScreenVideoPlayer> createState() =>
      _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends ConsumerState<FullScreenVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isDragging = false;
  double _seekPosition = 0.0;
  bool _isBuffering = false;
  Duration _currentPosition = Duration.zero;
  bool _showLikeAnim = false;
  Timer? _likeAnimTimer;
  late AnimationController _animationController;
  bool _isAnimating = false;
  double _dragStartX = 0.0;
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializePlayer();
  }

  void _initializePlayer() {
    // از کنترلر موجود استفاده می‌کنیم
    _controller = widget.controller;
    _isPlaying = _controller.value.isPlaying;

    _controller.addListener(_videoListener);

    setState(() {
      _isInitialized = _controller.value.isInitialized;
      _isLiked = widget.isLiked ?? false;
      _likeCount = widget.likeCount ?? 0;
      _commentCount = widget.commentCount ?? 0;
      _isMuted = widget.controller.value.volume == 0;
    });
  }

  void _videoListener() {
    if (mounted) {
      setState(() {
        _isPlaying = _controller.value.isPlaying;
        _isBuffering = _controller.value.isBuffering;
        _currentPosition = _controller.value.position;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }

    setState(() {
      _isAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _showLikeAnimation() {
    _likeAnimTimer?.cancel();
    setState(() {
      _showLikeAnim = true;
      _isLiked = true; // فرض می‌کنیم که با دابل تپ، پست لایک می‌شود
    });

    _likeAnimTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLikeAnim = false;
        });
      }
    });
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount = _isLiked ? _likeCount + 1 : _likeCount - 1;
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _onLikeTap() async {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    // اگر postId و userId دارید، اینجا منطق لایک را فراخوانی کنید
    // مثلا:
    // await ref.read(supabaseServiceProvider).toggleLike(postId: widget.postId, ownerId: widget.userId, ref: ref);
  }

  void _onCommentTap() {
    // اگر منطق باز کردن کامنت دارید، اینجا فراخوانی کنید
    // مثلا:
    // showCommentsBottomSheet(context, widget.postId, ref);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // تابع کمکی برای نمایش آیکون تیک تایید
  Widget _buildVerificationBadge() {
    if (widget.username == null) return const SizedBox.shrink();

    // این فقط یک نمونه است. در حالت واقعی باید اطلاعات تایید کاربر را از پروفایل بازیابی کنید
    // فرض می‌کنیم که اطلاعات تایید کاربر در یک مدل ذخیره شده است
    bool hasBlueBadge = true; // به عنوان مثال

    if (hasBlueBadge) {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void dispose() {
    _likeAnimTimer?.cancel();
    _controller.removeListener(_videoListener);
    _animationController.dispose();
    // کنترلر را dispose نمی‌کنیم چون همچنان در ویجت اصلی مورد استفاده است
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ویدیو پلیر
          Center(
            child: _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          // سطح واکنش به ضربه برای پخش/مکث
          GestureDetector(
            onTap: _togglePlayPause,
            onDoubleTap: _showLikeAnimation,
            onHorizontalDragStart: (details) {
              _dragStartX = details.localPosition.dx;
              setState(() {
                _isDragging = true;
              });
            },
            onHorizontalDragUpdate: (details) {
              if (!_isInitialized) return;

              final box = context.findRenderObject() as RenderBox;
              final width = box.size.width;
              final position = details.localPosition.dx;

              final progress = position / width;
              setState(() {
                _seekPosition = progress.clamp(0.0, 1.0);
              });
            },
            onHorizontalDragEnd: (_) {
              if (!_isInitialized) return;

              final duration = _controller.value.duration;
              final position = duration * _seekPosition;
              _controller.seekTo(position);

              setState(() {
                _isDragging = false;
              });
            },
            child: Container(
              color: Colors.transparent,
            ),
          ),

          // نوار بالایی با نام کاربر و آیکون پروفایل و تیک تأیید
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  if (widget.username != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        // آواتار کاربر
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.grey,
                          child:
                              Icon(Icons.person, size: 16, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '@${widget.username}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _buildVerificationBadge(),
                      ],
                    ),
                  ],
                  const Spacer(),
                  // دکمه قطع/وصل صدا
                  IconButton(
                    icon: Icon(
                      _isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                    ),
                    onPressed: _toggleMute,
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),

          // دکمه‌های کنار (مانند لایک، کامنت، اشتراک‌گذاری)
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                _buildSideButton(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  _likeCount.toString(),
                  color: _isLiked ? Colors.red : Colors.white,
                  onTap: _toggleLike,
                ),
                _buildSideButton(Icons.chat_bubble_outline, '0', onTap: () {
                  // اینجا کد باز کردن کامنت‌ها را اضافه کنید
                }),
                _buildSideButton(Icons.share, 'اشتراک', onTap: () async {
                  await Share.share(widget.videoUrl);
                }),
              ],
            ),
          ),

          // انیمیشن لایک دابل تپ
          if (_showLikeAnim)
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.5, end: 1.2),
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red.withOpacity(0.9),
                      size: 100,
                    ),
                  );
                },
              ),
            ),

          // نوار پیشرفت پایین
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, bottom: 40, top: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // نوار پیشرفت
                  Stack(
                    children: [
                      // نوار خاکستری پایه
                      Container(
                        height: 4,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // نوار قرمز پیشرفت
                      FractionallySizedBox(
                        widthFactor: _isDragging
                            ? _seekPosition
                            : (_controller.value.duration.inMilliseconds > 0
                                ? _controller.value.position.inMilliseconds /
                                    _controller.value.duration.inMilliseconds
                                : 0.0),
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // نقطه (thumb) روی نوار پیشرفت
                      Positioned(
                        left: _isDragging
                            ? MediaQuery.of(context).size.width *
                                    _seekPosition -
                                8
                            : (_controller.value.duration.inMilliseconds > 0
                                ? MediaQuery.of(context).size.width *
                                        (_controller
                                                .value.position.inMilliseconds /
                                            _controller.value.duration
                                                .inMilliseconds) -
                                    8
                                : -8),
                        top: -4,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // زمان‌ها
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_controller.value.position),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Text(
                        _formatDuration(_controller.value.duration),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // آیکون پخش/مکث در وسط صفحه (موقع تپ)
          if (_isAnimating)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

          // نشانگر بافرینگ
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildSideButton(IconData icon, String label,
      {Color color = Colors.white, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 30,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
