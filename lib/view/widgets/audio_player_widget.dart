import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Uint8List? audioBytes;
  final bool isMe;
  final bool isPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    this.audioBytes,
    required this.isMe,
    this.isPreview = false,
    this.onDelete,
    this.onReply,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget>
    with SingleTickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _duration = duration;
          _isLoading = false;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _playerStateSubscription =
        _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          _hasError = false;
        });

        // اگر پخش تمام شد، موقعیت را به ابتدا برگردان
        if (state == PlayerState.completed) {
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });
        }
      }
    });
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        if (widget.audioBytes != null) {
          await _audioPlayer.play(BytesSource(widget.audioBytes!));
        } else {
          await _audioPlayer.play(UrlSource(widget.audioUrl));
        }
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
      }
    } catch (e) {
      print('خطا در پخش صوت: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isPlaying = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در پخش فایل صوتی'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _seek(double value) async {
    final position = Duration(seconds: (value * _duration.inSeconds).round());
    await _audioPlayer.seek(position);
  }

  void _changePlaybackSpeed() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;

    setState(() {
      _playbackSpeed = speeds[nextIndex];
    });

    if (_isPlaying) {
      _audioPlayer.setPlaybackRate(_playbackSpeed);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // رنگ‌های متفاوت برای پیام‌های من و دیگران
    final backgroundColor = widget.isMe
        ? (isDark ? const Color(0xFF4F46E5) : const Color(0xFF6366F1))
        : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6));

    final textColor =
        widget.isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    // Conditional decoration based on whether it's a preview or part of a chat bubble
    final BoxDecoration? decoration = widget.isPreview
        ? BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          )
        : null; // No decoration when inside a chat bubble

    return Container(
      // This container will now only apply padding and constraints, and optional decoration
      margin:
          EdgeInsets.zero, // Remove external margin, message bubble handles it
      padding: const EdgeInsets.all(12),
      constraints:
          const BoxConstraints(minWidth: 200, maxWidth: 280, minHeight: 60),
      decoration: decoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ردیف اصلی: دکمه پلی، نوار پیشرفت/موج، دکمه سرعت
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // دکمه پلی/پاز
              GestureDetector(
                onTap: _hasError ? null : _playPause,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _hasError
                        ? Colors.red.withOpacity(0.2)
                        : Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(textColor),
                          ),
                        )
                      : Icon(
                          _hasError
                              ? Icons.error_outline
                              : (_isPlaying ? Icons.pause : Icons.play_arrow),
                          color: textColor,
                          size: 24,
                        ),
                ),
              ),

              const SizedBox(width: 12),

              // ویجت جدید: ترکیب موج و نوار پیشرفت
              Expanded(
                child: _buildSeekbarWithWaveform(textColor),
              ),

              const SizedBox(width: 4),

              // دکمه سرعت پخش
              _buildPlaybackSpeedButton(textColor),
            ],
          ),

          const SizedBox(height: 4),

          // ردیف دوم: مدت زمان و دکمه‌های عملیات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // مدت زمان
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  _duration.inSeconds > 0
                      ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
                      : '--:--',
                  style: TextStyle(
                    color: textColor.withOpacity(0.8),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ),

              // دکمه‌های عملیات
              if (widget.isMe && !widget.isPreview)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onReply != null)
                      IconButton(
                        onPressed: widget.onReply,
                        icon: Icon(
                          Icons.reply_rounded,
                          color: textColor.withOpacity(0.8),
                          size: 16,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: textColor.withOpacity(0.8),
                          size: 16,
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeekbarWithWaveform(Color textColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // لایه زیرین: موج صوتی
        _buildWaveform(textColor),

        // لایه رویی: نوار پیشرفت قابل کلیک
        if (_duration.inSeconds > 0)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 30, // ارتفاع کلیک‌پذیر
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: textColor.withOpacity(0.4),
              inactiveTrackColor: Colors.transparent,
              thumbColor: textColor,
              overlayColor: textColor.withOpacity(0.2),
            ),
            child: Slider(
              value: _duration.inSeconds > 0
                  ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                  : 0.0,
              onChanged: _hasError ? null : _seek,
            ),
          ),
      ],
    );
  }

  Widget _buildWaveform(Color textColor) {
    return Container(
      height: 30,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(widget.isPreview ? 12 : 20, (index) {
          // استفاده از سینوس برای ایجاد یک الگوی موج مانند
          final sinValue = sin(index * 0.5);
          final height = 10 + (sinValue * 8).abs();
          // انیمیشن شفافیت بر اساس موقعیت پخش
          final double opacity = _isPlaying
              ? (0.5 +
                      (sin(index * 0.9 + _position.inMilliseconds / 200) * 0.5)
                          .abs())
                  .clamp(0.3, 1.0)
              : 0.4;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 2.5,
            height: height.clamp(4.0, 22.0),
            decoration: BoxDecoration(
              color: textColor.withOpacity(opacity),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlaybackSpeedButton(Color textColor) {
    return GestureDetector(
      onTap: _changePlaybackSpeed,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed.toStringAsFixed(1)}x',
          style: TextStyle(
            color: textColor.withOpacity(0.9),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
