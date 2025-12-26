import 'dart:async';
import 'VideoPlayerConfig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/ProfileModel.dart';
import '../../services/video_autoplay_service.dart';

class CustomVideoPlayer extends ConsumerStatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
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
  final bool showControls; // اضافه شد
  final bool isLocal; // اضافه شد
  final Duration? duration; // اضافه شد

  const CustomVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
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
    this.showControls = true, // اضافه شد
    this.isLocal = false, // اضافه شد
    this.duration, // اضافه شد
  });

  @override
  ConsumerState<CustomVideoPlayer> createState() => _CustomVideoPlayerState();
}

class _CustomVideoPlayerState extends ConsumerState<CustomVideoPlayer>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller; // تغییر به nullable
  final VideoPlayerConfig _config = VideoPlayerConfig();
  bool _isPlayerInitialized = false;
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
  // removed unused caption state (was planned for future expansion)

  @override
  bool get wantKeepAlive {
    // Smart keep-alive based on video engagement
    return _isInitialized && _playCount > 3;
  }

  final int _playCount = 0;
  bool _isDataSaverMode = false;

  @override
  void initState() {
    super.initState();
    _loadConfigAndInitialize();
  }

  Future<void> _loadConfigAndInitialize() async {
    try {
      final videoAutoplayService = VideoAutoplayService();
      await videoAutoplayService.loadSettings();

      if (!mounted) return;
      setState(() {
        _isDataSaverMode = videoAutoplayService.dataSaverEnabled;
      });
      // await _initializePlayer(); // Removed for lazy loading
    } catch (_) {
      // ignore
    }
  }

  @override
  void dispose() {
    // Cancel all timers first
    _likeAnimTimer?.cancel();
    _likeAnimTimer = null;

    // Remove listener and dispose controller
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _controller = null;

    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      final videoAutoplayService = VideoAutoplayService();
      final videoQuality = videoAutoplayService.getVideoQuality();

      // بهینه‌سازی: همیشه از network استفاده کنیم مگر در موارد خاص
      // کش ویدیو باعث مصرف زیاد حافظه می‌شود
      if (_isDataSaverMode ||
          videoQuality == 'low' ||
          widget.maxHeight != null) {
        _controller = VideoPlayerController.network(widget.videoUrl);
      } else {
        // استفاده محدود از کش فقط برای ویدیوهای کوچک
        try {
          final file = await _config.videoCacheManager
              .getSingleFile(widget.videoUrl)
              .timeout(const Duration(
                  seconds: 3)); // timeout برای جلوگیری از انتظار طولانی
          _controller = VideoPlayerController.file(file);
        } catch (e) {
          // fallback به network اگر کش شکست خورد
          _controller = VideoPlayerController.network(widget.videoUrl);
        }
      }

      await _controller?.initialize();

      if (_controller == null) return;

      // اگر auto-quality فعال باشد و استریم HLS باشد، پلیر به‌صورت خودکار تطبیقی رفتار می‌کند
      // (video_player به‌صورت داخلی مدیریت می‌کند اگر URL از نوع HLS باشد)

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

        // بررسی تنظیمات پخش خودکار از VideoAutoplayService
        final videoAutoplayService = VideoAutoplayService();
        final shouldAutoPlay =
            widget.autoplay && videoAutoplayService.shouldAutoPlay();

        if (shouldAutoPlay && _isVisible) {
          _playVideo();
        }
      }
    } catch (e) {
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
    if (isPlaying != _isPlaying && mounted) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // بررسی وضعیت بافرینگ
    final isBuffering = _controller!.value.isBuffering;
    if (isBuffering != _isBuffering && mounted) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }

    // به‌روزرسانی موقعیت پخش
    final currentPosition = _controller!.value.position;
    if (currentPosition != _currentPosition && mounted) {
      setState(() {
        _currentPosition = currentPosition;
      });
    }
  }

  void _playVideo() {
    if (!_isInitialized || _controller == null || !mounted) return;

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
    if (!_isInitialized || _controller == null || !mounted) return;

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
    if (!mounted) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  void _showLikeAnimation() {
    if (widget.onLike != null) {
      widget.onLike!();
    }

    _likeAnimTimer?.cancel();
    if (mounted) {
      setState(() {
        _showLikeAnim = true;
      });
    }

    _likeAnimTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showLikeAnim = false;
        });
      }
    });
  }

  // Removed unused _formatDuration to satisfy linter

  void _toggleFullScreen() {
    if (!mounted) return;
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
        final newIsVisible = visibleFraction > 0.5;

        if (newIsVisible != _isVisible && mounted) {
          setState(() {
            _isVisible = newIsVisible;
          });

          // Do not autoplay if player hasn't been manually initialized
          if (!_isPlayerInitialized) return;

          final videoAutoplayService = VideoAutoplayService();
          final shouldAutoPlay =
              widget.autoplay && videoAutoplayService.shouldAutoPlay();

          if (newIsVisible && shouldAutoPlay && _isInitialized) {
            _playVideo();
          } else if (!newIsVisible && _isPlaying) {
            _pauseVideo();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (!_isPlayerInitialized) {
            // In lazy load mode, tap is disabled until play is pressed.
            return;
          }
          if (widget.onTap != null) {
            if (widget.onVideoPositionTap != null) {
              widget.onVideoPositionTap!(_currentPosition);
            }
            widget.onTap!();
          } else {
            _togglePlay();
          }
        },
        onDoubleTap: _showLikeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_isPlayerInitialized) ...[
              if (widget.thumbnailUrl != null &&
                  widget.thumbnailUrl!.isNotEmpty)
                Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                        child: Icon(Icons.error, color: Colors.white));
                  },
                )
              else
                Container(
                  color: Colors.black,
                  child: const Center(
                    child:
                        Icon(Icons.videocam, color: Colors.white30, size: 50),
                  ),
                ),
              Center(
                child: IconButton(
                  icon: const Icon(Icons.play_circle_fill),
                  color: Colors.white.withOpacity(0.9),
                  iconSize: 60,
                  onPressed: () {
                    if (!mounted) return;
                    setState(() {
                      _isPlayerInitialized = true;
                    });
                    _initializePlayer().then((_) {
                      if (mounted && _isInitialized) {
                        _playVideo();
                      }
                    });
                  },
                ),
              ),
            ] else ...[
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
                AbsorbPointer(
                  absorbing: false, // رویدادها را جذب نمی‌کند
                  child: GestureDetector(
                    onTap: () {
                      // فقط پخش ویدیو بدون رفتن به صفحه ریلز
                      _togglePlay();
                    },
                    child: Center(
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
                  child: SizedBox(
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
            ]
          ],
        ),
      ),
    );
  }
}
