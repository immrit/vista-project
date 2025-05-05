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

  const ReelsVideoPlayer({
    Key? key,
    required this.post,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.initialPosition,
    this.onPositionChanged,
  }) : super(key: key);

  @override
  ConsumerState<ReelsVideoPlayer> createState() => _ReelsVideoPlayerState();
}

class _ReelsVideoPlayerState extends ConsumerState<ReelsVideoPlayer>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isMuted = false;

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
    _initializePlayer();
    print('Username: ${widget.post.username}');
    print('Is Verified: ${widget.post.isVerified}');
    print('Has Blue Badge: ${widget.post.hasBlueBadge}');
    print('Has Gold Badge: ${widget.post.hasGoldBadge}');
    print('Has Black Badge: ${widget.post.hasBlackBadge}');
    _fetchVerificationType();
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
      if (widget.isActive) {
        _playVideo();
      } else {
        _pauseVideo();
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.post.videoUrl!),
      );

      await _controller.initialize();
      _videoDuration = _controller.value.duration;

      _controller.setLooping(true);
      if (widget.initialPosition != null) {
        await _controller.seekTo(widget.initialPosition!);
      }
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        if (widget.isActive) {
          _playVideo();
        }

        _controller.addListener(_videoListener);
      }
    } catch (e) {
      print('خطا در بارگذاری ویدیو ریلز: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    final position = _controller.value.position;
    if (position != _currentPosition) {
      setState(() {
        _currentPosition = position;
      });
      widget.onPositionChanged?.call(position);
    }
  }

  void _playVideo() {
    if (!_isInitialized) return;
    _controller.play();
    setState(() {
      _isPlaying = true;
    });
  }

  void _pauseVideo() {
    if (!_isInitialized) return;
    _controller.pause();
    setState(() {
      _isPlaying = false;
    });
  }

  void _togglePlayPause() {
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

      _showVolumeControl = true;
      _volumeControlTimer?.cancel();
      _volumeControlTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showVolumeControl = false;
          });
        }
      });
    });
  }

  void _showLikeAnimation() {
    widget.onLike();

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
      await ref.read(supabaseServiceProvider).toggleLike(
            postId: widget.post.id!,
            ownerId: widget.post.userId!,
            ref: ref,
          );

      // نمایش انیمیشن لایک فقط اگه نیاز هست
      _showLikeAnimation();
    } catch (e) {
      debugPrint('Error toggling like: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ثبت لایک: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _likeAnimTimer?.cancel();
    _volumeControlTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayPause,
      onDoubleTap: _showLikeAnimation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _isInitialized
              ? Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
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
                        color: widget.post.isLiked ? Colors.red : Colors.white,
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
                        showCommentsBottomSheet(context, widget.post.id!, ref);
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
                              _controller.seekTo(
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
