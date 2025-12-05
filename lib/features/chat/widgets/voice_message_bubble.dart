// lib/features/chat/widgets/voice_message_bubble.dart
//
// ویجت پیام صوتی مدرن با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ Waveform انیمیشن‌دار
// ✅ دکمه پخش/توقف با انیمیشن
// ✅ Progress bar با انیمیشن
// ✅ نمایش زمان پخش
// ✅ دانلود با progress
// ✅ سرعت پخش (1x, 1.5x, 2x)
//

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/chat_theme.dart';

/// ویجت پیام صوتی شبیه تلگرام
class VoiceMessageBubble extends StatefulWidget {
  final String messageId;
  final String audioUrl;
  final int? durationSeconds;
  final List<double>? waveformData;
  final bool isMe;
  final DateTime time;

  const VoiceMessageBubble({
    super.key,
    required this.messageId,
    required this.audioUrl,
    this.durationSeconds,
    this.waveformData,
    required this.isMe,
    required this.time,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLLERS & STATE
  // ═══════════════════════════════════════════════════════════════════════════

  late AudioPlayer _audioPlayer;
  late AnimationController _playButtonController;
  late AnimationController _waveformController;
  late AnimationController _progressController;

  // State
  bool _isInitialized = false;
  bool _isDownloading = false;
  bool _isPlaying = false;
  double _downloadProgress = 0.0;
  Duration _totalDuration = Duration.zero;
  Duration _currentPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  String? _localFilePath;
  String? _error;

  // Waveform
  late List<double> _waveformData;
  static const int _waveformBars = 40;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAnimations();
    _initializeWaveform();
    _setupAudioListeners();

    if (widget.durationSeconds != null) {
      _totalDuration = Duration(seconds: widget.durationSeconds!);
    }
  }

  void _initializeAnimations() {
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
  }

  void _initializeWaveform() {
    if (widget.waveformData != null && widget.waveformData!.isNotEmpty) {
      _waveformData = _normalizeWaveform(widget.waveformData!);
    } else {
      // تولید waveform تصادفی اگر وجود نداشت
      _waveformData = _generateRandomWaveform();
    }
  }

  List<double> _normalizeWaveform(List<double> data) {
    if (data.isEmpty) return _generateRandomWaveform();

    // تبدیل به تعداد bar مورد نظر
    final List<double> normalized = [];
    final step = data.length / _waveformBars;

    for (int i = 0; i < _waveformBars; i++) {
      final startIndex = (i * step).floor();
      final endIndex = math.min(((i + 1) * step).floor(), data.length);

      double sum = 0;
      int count = 0;
      for (int j = startIndex; j < endIndex; j++) {
        sum += data[j].abs();
        count++;
      }

      final avg = count > 0 ? sum / count : 0.0;
      // نرمال‌سازی به بازه 0.2 تا 1.0
      normalized.add(0.2 + (avg.clamp(0.0, 1.0) * 0.8));
    }

    return normalized;
  }

  List<double> _generateRandomWaveform() {
    final random = math.Random(widget.audioUrl.hashCode);
    return List.generate(_waveformBars, (_) => 0.2 + random.nextDouble() * 0.8);
  }

  void _setupAudioListeners() {
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() => _totalDuration = duration);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _currentPosition = position);
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        final isPlaying = state.playing;
        if (isPlaying != _isPlaying) {
          setState(() => _isPlaying = isPlaying);
          if (isPlaying) {
            _playButtonController.forward();
            _waveformController.repeat();
          } else {
            _playButtonController.reverse();
            _waveformController.stop();
          }
        }

        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.pause();
        }
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playButtonController.dispose();
    _waveformController.dispose();
    _progressController.dispose();

    // حذف فایل موقت
    if (_localFilePath != null) {
      try {
        File(_localFilePath!).deleteSync();
      } catch (_) {}
    }

    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔊 AUDIO CONTROL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _downloadAudio() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _error = null;
    });

    try {
      final uri = Uri.parse(widget.audioUrl);
      final request = http.Request('GET', uri);
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('خطا در دانلود');
      }

      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final tempDir = await getTemporaryDirectory();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
      final file = File('${tempDir.path}/$fileName');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (totalBytes > 0 && mounted) {
          setState(() {
            _downloadProgress = downloadedBytes / totalBytes;
          });
        }
      }

      await sink.close();

      if (mounted) {
        _localFilePath = file.path;
        await _audioPlayer.setFilePath(file.path);

        setState(() {
          _isDownloading = false;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    HapticFeedback.lightImpact();

    if (!_isInitialized) {
      await _downloadAudio();
      if (!_isInitialized) return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  void _seekToPosition(double progress) {
    if (!_isInitialized) return;

    final position = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round(),
    );
    _audioPlayer.seek(position);
    HapticFeedback.selectionClick();
  }

  void _changePlaybackSpeed() {
    HapticFeedback.lightImpact();

    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });

    _audioPlayer.setSpeed(_playbackSpeed);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // دکمه پخش/دانلود
          _buildPlayButton(theme),

          const SizedBox(width: 8),

          // Waveform و progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform
                _buildWaveform(theme),

                const SizedBox(height: 4),

                // زمان و سرعت
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(
                          _isPlaying ? _currentPosition : _totalDuration),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isMe
                            ? theme.myBubbleTextColor.withOpacity(0.7)
                            : theme.secondaryTextColor,
                      ),
                    ),

                    // دکمه سرعت
                    if (_isInitialized)
                      GestureDetector(
                        onTap: _changePlaybackSpeed,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.isMe
                                    ? Colors.white
                                    : theme.sendButtonColor)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${_playbackSpeed}x',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isMe
                                  ? theme.myBubbleTextColor
                                  : theme.sendButtonColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(ChatTheme theme) {
    final buttonColor = widget.isMe
        ? Colors.white.withOpacity(0.2)
        : theme.sendButtonColor.withOpacity(0.1);

    final iconColor = widget.isMe ? Colors.white : theme.sendButtonColor;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: buttonColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: iconColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: _buildPlayButtonContent(iconColor, theme),
      ),
    );
  }

  Widget _buildPlayButtonContent(Color iconColor, ChatTheme theme) {
    if (_isDownloading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              strokeWidth: 2.5,
              color: iconColor,
            ),
          ),
          if (_downloadProgress > 0)
            Text(
              '${(_downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
        ],
      );
    }

    if (_error != null) {
      return Icon(
        Icons.refresh_rounded,
        color: theme.errorColor,
        size: 24,
      );
    }

    return AnimatedBuilder(
      animation: _playButtonController,
      builder: (context, child) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(_isPlaying),
            color: iconColor,
            size: 26,
          ),
        );
      },
    );
  }

  Widget _buildWaveform(ChatTheme theme) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    final activeColor = widget.isMe ? Colors.white : theme.sendButtonColor;
    final inactiveColor = widget.isMe
        ? Colors.white.withOpacity(0.4)
        : theme.sendButtonColor.withOpacity(0.3);

    return GestureDetector(
      onTapDown: (details) {
        if (!_isInitialized) return;
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final progressTap = (localPos.dx - 52) / (box.size.width - 52);
        _seekToPosition(progressTap.clamp(0.0, 1.0));
      },
      onHorizontalDragUpdate: (details) {
        if (!_isInitialized) return;
        final box = context.findRenderObject() as RenderBox;
        final localPos = box.globalToLocal(details.globalPosition);
        final progressDrag = (localPos.dx - 52) / (box.size.width - 52);
        _seekToPosition(progressDrag.clamp(0.0, 1.0));
      },
      child: SizedBox(
        height: 28,
        child: AnimatedBuilder(
          animation: _waveformController,
          builder: (context, child) {
            return CustomPaint(
              painter: WaveformPainter(
                waveformData: _waveformData,
                progress: progress,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                isPlaying: _isPlaying,
                animationValue: _waveformController.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 WAVEFORM PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;
  final bool isPlaying;
  final double animationValue;

  WaveformPainter({
    required this.waveformData,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    required this.isPlaying,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty) return;

    final barWidth = size.width / waveformData.length;
    final barSpacing = barWidth * 0.3;
    final actualBarWidth = barWidth - barSpacing;
    final maxBarHeight = size.height * 0.9;
    final minBarHeight = size.height * 0.15;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < waveformData.length; i++) {
      final x = i * barWidth + barSpacing / 2;
      final normalizedHeight = waveformData[i];

      // انیمیشن در حال پخش
      double heightMultiplier = 1.0;
      if (isPlaying) {
        final wave = math.sin((animationValue * 2 * math.pi) + (i * 0.3));
        heightMultiplier = 0.85 + (wave * 0.15);
      }

      final barHeight =
          (minBarHeight + (normalizedHeight * (maxBarHeight - minBarHeight))) *
              heightMultiplier;

      final y = (size.height - barHeight) / 2;
      final barProgress = i / waveformData.length;
      final isActive = barProgress <= progress;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, isActive ? activePaint : inactivePaint);
    }

    // نقطه پیشرفت
    if (progress > 0 && progress < 1) {
      final dotX = progress * size.width;
      final dotPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(dotX, size.height / 2),
        4,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}
