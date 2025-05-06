import 'dart:async';
import 'package:Vista/view/widgets/VideoPlayerConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/ProfileModel.dart';

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
  final Function(Duration)? onVideoPositionTap;
  final String? title; // این پارامتر را نگه می‌داریم اما استفاده نمی‌کنیم
  final String? content; // این پارامتر را نگه می‌داریم اما استفاده نمی‌کنیم
  final bool isVerified;
  final VerificationType verificationType;

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
    this.onVideoPositionTap,
    this.title,
    this.content,
    this.isVerified = false,
    this.verificationType = VerificationType.none,
  }) : super(key: key);

  @override
  State<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends State<CustomVideoPlayer>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller; // تغییر به nullable
  final VideoPlayerConfig _config = VideoPlayerConfig();
  bool _isFullScreen = false;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _isBuffering = false;

  // برای انیمیشن پخش/مکث
  bool _isAnimating = false;

  // برای نمایش دابل تپ لایک
  bool _showLikeAnim = false;
  Timer? _likeAnimTimer;

  // بهبود عملکرد موقعیت پخش
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // برای تشخیص نمایش
  bool _isVisible = false;

  // برای مدیریت وضعیت کپشن
  bool _isCaptionExpanded = false;

  @override
  bool get wantKeepAlive {
    // Smart keep-alive based on video engagement
    return _isInitialized && _playCount > 3;
  }

  int _playCount = 0;
  bool _isDataSaverMode = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _initializePlayer();
  }

  Future<void> _loadConfig() async {
    _isDataSaverMode = await _config.getDataSaverMode();
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _likeAnimTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final file =
          await _config.videoCacheManager.getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(file);

      await _controller?.initialize();

      if (_controller == null) return;

      if (_isDataSaverMode) {
        // تنظیمات کیفیت پایین برای حالت ذخیره دیتا
      }

      if (mounted) {
        setState(() {
          _isBuffering = true;
        });

        _videoDuration = _controller!.value.duration;
        await _controller?.setLooping(widget.looping);
        await _controller?.setVolume(_isMuted ? 0.0 : 1.0);

        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });

        _controller?.addListener(_videoListener);

        if (widget.autoplay && _isVisible) {
          _playVideo();
        }
      }
    } catch (e) {
      print('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _controller == null) return;

    // بررسی وضعیت پخش
    final isPlaying = _controller!.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // بررسی وضعیت بافرینگ
    final isBuffering = _controller!.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }

    // به‌روزرسانی موقعیت پخش
    final currentPosition = _controller!.value.position;
    if (currentPosition != _currentPosition) {
      setState(() {
        _currentPosition = currentPosition;
      });
    }
  }

  void _playVideo() {
    if (!_isInitialized || _controller == null) return;

    _controller?.play();
    setState(() {
      _isPlaying = true;
      _isAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _pauseVideo() {
    if (!_isInitialized || _controller == null) return;

    _controller?.pause();
    setState(() {
      _isPlaying = false;
      _isAnimating = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isAnimating = false;
        });
      }
    });
  }

  void _togglePlay() {
    if (_isPlaying) {
      _pauseVideo();
    } else {
      _playVideo();
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _showLikeAnimation() {
    if (widget.onLike != null) {
      widget.onLike!();
    }

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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(
        context); // این فراخوانی برای AutomaticKeepAliveClientMixin لازم است

    return Theme(
      data: Theme.of(context).copyWith(
        // Support Material 3 theming
        colorScheme: Theme.of(context).colorScheme,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: _isFullScreen ? _buildFullScreenPlayer() : _buildNormalPlayer(),
      ),
    );
  }

  Widget _buildFullScreenPlayer() {
    return Scaffold(
      body: Stack(
        children: [
          // ...existing video player stack...
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: _toggleFullScreen,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalPlayer() {
    return VisibilityDetector(
      key: ValueKey('video-${widget.videoUrl}-${widget.postId ?? ""}'),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;

        // وضعیت قابل مشاهده بودن را چاپ کنید (برای دیباگ)
        print(
            'Video visibility: $visibleFraction (${widget.postId ?? "no-id"})');

        // اگر بیش از 50% نمایش داده می‌شود، آن را قابل مشاهده در نظر بگیرید
        final newIsVisible = visibleFraction > 0.5;

        if (newIsVisible != _isVisible) {
          setState(() {
            _isVisible = newIsVisible;
          });

          // اگر قابل مشاهده است و autoplay فعال است و آماده است، پخش کنید
          if (newIsVisible && widget.autoplay && _isInitialized) {
            _playVideo();
          } else if (!newIsVisible && _isPlaying) {
            _pauseVideo();
          }
        }
      },
      child: GestureDetector(
        onTap: widget.onTap != null
            ? () {
                // اگر onVideoPositionTap تعریف شده باشد، موقعیت فعلی را پاس می‌دهیم
                if (widget.onVideoPositionTap != null) {
                  widget.onVideoPositionTap!(_currentPosition);
                }
                // اجرای onTap اصلی
                widget.onTap!();
              }
            : _togglePlay,
        onDoubleTap: _showLikeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ویدیو پلیر
            _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : Container(
                    color: Colors.black,
                    height: 250,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),

            // نشانگر بافرینگ
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // دکمه پخش در صورتی که ویدیو در حال پخش نیست و در حال بافرینگ هم نیست
            if (!_isPlaying && !_isBuffering && _isInitialized)
              Center(
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

            // انیمیشن لایک
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

            // آیکون پخش/مکث در وسط صفحه (موقع تپ)
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

            // دکمه خاموش/روشن کردن صدا
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),

            // نوار پیشرفت پایین (در صورت نیاز)
            if (widget.showProgress && _isInitialized)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 3,
                  child: LinearProgressIndicator(
                    value: _videoDuration.inMilliseconds > 0
                        ? _currentPosition.inMilliseconds /
                            _videoDuration.inMilliseconds
                        : 0.0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
