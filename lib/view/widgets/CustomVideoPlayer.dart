import 'dart:async';
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
  bool _isPlaying = false;
  bool _isMuted = true;
  bool _isBuffering = false;
  bool _isVisible = false;
  bool _isAnimating = false;

  // برای موقعیت پخش
  Duration _currentPosition = Duration.zero;
  Duration _videoDuration = Duration.zero;

  // برای دابل‌تپ لایک
  bool _showLikeAnim = false;
  Timer? _likeAnimTimer;

  // برای تشخیص اسکرول
  double _lastVisibleFraction = 0.0;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.muted;
    _initializePlayer();
  }

  @override
  void dispose() {
    _controller.dispose();
    _likeAnimTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      setState(() {
        _isBuffering = true;
      });

      await _controller.initialize();

      _videoDuration = _controller.value.duration;
      _controller.setLooping(widget.looping);
      _controller.setVolume(_isMuted ? 0.0 : 1.0);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isBuffering = false;
        });

        _controller.addListener(_videoListener);
      }
    } catch (e) {
      print('خطا در بارگذاری ویدیو: $e');
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;

    // به‌روزرسانی وضعیت پخش
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // به‌روزرسانی وضعیت بافرینگ
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
  }

  void _playVideo() {
    if (!_isInitialized) return;

    _controller.play();
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
    if (!_isInitialized) return;

    _controller.pause();
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
      _controller.setVolume(_isMuted ? 0.0 : 1.0);
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

  @override
  Widget build(BuildContext context) {
    // استفاده از VisibilityDetector برای تشخیص دقیق نمایش
    return VisibilityDetector(
      key: Key('video-${widget.videoUrl}'),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;

        // اگر درصد نمایش تغییر کرده است، آن را ذخیره می‌کنیم
        if (visibleFraction != _lastVisibleFraction) {
          _lastVisibleFraction = visibleFraction;

          // اگر بیش از 70% ویدیو قابل مشاهده است، آن را به عنوان قابل مشاهده علامت‌گذاری می‌کنیم
          final newIsVisible = visibleFraction > 0.7;

          if (newIsVisible != _isVisible) {
            setState(() {
              _isVisible = newIsVisible;
            });

            // اگر قابل مشاهده شده و autoplay فعال است، پخش را شروع می‌کنیم
            if (_isVisible &&
                widget.autoplay &&
                _isInitialized &&
                !_isPlaying) {
              _playVideo();
            } else if (!_isVisible && _isPlaying) {
              _pauseVideo();
            }
          }
        }
      },
      child: GestureDetector(
        onTap: widget.onTap ?? _togglePlay,
        onDoubleTap: _showLikeAnimation,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ویدیو
            Container(
              width: double.infinity,
              child: _isInitialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : Container(
                      color: Colors.black,
                      height: 250,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
            ),

            // نشانگر بافرینگ
            if (_isBuffering)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),

            // دکمه صدا
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
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
