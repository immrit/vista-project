import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'enhanced_voice_visualizer.dart';
import '../../services/voice_player_service.dart';

/// ویجت نمایش پیام وویس پیشرفته
class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final Uint8List? audioBytes;
  final List<double>? waveformData;
  final bool isMe;
  final bool isPreview;
  final int? duration;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onForward;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    this.audioBytes,
    this.waveformData,
    required this.isMe,
    this.isPreview = false,
    this.duration,
    this.onDelete,
    this.onReply,
    this.onForward,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with TickerProviderStateMixin {
  late final AnimationController _playPauseAnimationController;
  late final AnimationController _waveformAnimationController;

  late Animation<double> _playPauseAnimation;

  final VoicePlayerService _voicePlayerService = VoicePlayerService();
  String? _voiceId;

  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  List<double> _extractedWaveform = [];

  @override
  void initState() {
    super.initState();
    _voiceId = 'voice_${DateTime.now().millisecondsSinceEpoch}';
    _initializeAnimations();
    _preparePlayer();
    _setupVoicePlayerService();
  }

  void _initializeAnimations() {
    _playPauseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _waveformAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _playPauseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playPauseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _preparePlayer() async {
    try {
      setState(() => _isLoading = true);

      print("🎵 آماده‌سازی پخش فایل صوتی: ${widget.audioUrl}");

      // آماده‌سازی پلیر با سرویس جدید
      final success =
          await _voicePlayerService.prepareVoice(_voiceId!, widget.audioUrl);

      if (success) {
        // دریافت مدت زمان از پلیر
        final playerController =
            _voicePlayerService.getPlayerController(_voiceId!);
        if (playerController != null) {
          _totalDuration = Duration(milliseconds: playerController.maxDuration);
          print("🎵 مدت زمان فایل: ${_totalDuration.inSeconds} ثانیه");

          // استخراج waveform اگر موجود نباشد
          if (widget.waveformData == null) {
            try {
              _extractedWaveform = await playerController.extractWaveformData(
                path: widget.audioUrl,
              );
              print(
                  "🎵 Waveform استخراج شد: ${_extractedWaveform.length} نقطه");
            } catch (e) {
              print("⚠️ خطا در استخراج waveform: $e");
              _extractedWaveform = [];
            }
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print("❌ خطا در آماده‌سازی پخش: $e");
      setState(() => _isLoading = false);

      // نمایش پیام خطا به کاربر
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در بارگذاری فایل صوتی: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _setupVoicePlayerService() {
    // تنظیم callbacks برای سرویس پخش وویس
    _voicePlayerService.setCallbacks(
      onPlayStateChanged: (voiceId, isPlaying) {
        if (voiceId == _voiceId && mounted) {
          setState(() {
            _isPlaying = isPlaying;
          });

          if (isPlaying) {
            _playPauseAnimationController.forward();
            _waveformAnimationController.repeat();
          } else {
            _playPauseAnimationController.reverse();
            _waveformAnimationController.stop();
          }
        }
      },
      onPositionChanged: (voiceId, position) {
        if (voiceId == _voiceId && mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
      onDurationChanged: (voiceId, duration) {
        if (voiceId == _voiceId && mounted) {
          setState(() {
            _totalDuration = duration;
          });
        }
      },
    );
  }

  Future<void> _playPause() async {
    try {
      if (_isPlaying) {
        print("⏸️ مکث پخش");
        await _voicePlayerService.pauseVoice(_voiceId!);
      } else {
        print("▶️ شروع پخش");
        await _voicePlayerService.playVoice(_voiceId!);
      }
    } catch (e) {
      print("❌ خطا در پخش/مکث: $e");

      // نمایش پیام خطا به کاربر
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در پخش فایل صوتی: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _seekTo(Duration position) async {
    try {
      print("🔍 جستجو به موقعیت: ${position.inSeconds} ثانیه");
      await _voicePlayerService.seekVoice(_voiceId!, position);
    } catch (e) {
      print("❌ خطا در جستجو: $e");
    }
  }

  @override
  void dispose() {
    _playPauseAnimationController.dispose();
    _waveformAnimationController.dispose();

    // توقف وویس اگر در حال پخش است
    if (_voiceId != null) {
      _voicePlayerService.stopVoice(_voiceId!);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
        minWidth: 200,
      ),
      decoration: BoxDecoration(
        color: widget.isMe
            ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50))
            : (isDark ? const Color(0xFF424242) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر وویس
          _buildVoiceHeader(theme, isDark),

          const SizedBox(height: 8),

          // ویجت پخش
          _buildPlayerWidget(theme, isDark),

          const SizedBox(height: 8),

          // اطلاعات وویس
          _buildVoiceInfo(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.mic,
          size: 16,
          color: widget.isMe ? Colors.white : theme.colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          'پیام صوتی',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: widget.isMe ? Colors.white70 : theme.colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (widget.isPreview) ...[
          IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline, size: 16),
            color: Colors.red,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            padding: EdgeInsets.zero,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayerWidget(ThemeData theme, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Row(
      children: [
        // دکمه پخش/مکث
        AnimatedBuilder(
          animation: _playPauseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_playPauseAnimation.value * 0.1),
              child: IconButton(
                onPressed: _playPause,
                icon: Icon(
                  _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: widget.isMe
                      ? Colors.white
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[300]
                          : Colors.grey[700]),
                ),
                style: IconButton.styleFrom(
                  backgroundColor: widget.isMe
                      ? Colors.white.withValues(alpha: 0.2)
                      : (Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[700]
                          : Colors.grey[200]),
                  shape: const CircleBorder(),
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 8),

        // ویجت waveform
        Expanded(
          child: GestureDetector(
            onTapDown: (details) {
              final RenderBox box = context.findRenderObject() as RenderBox;
              final localPosition = box.globalToLocal(details.globalPosition);
              final progress = localPosition.dx / box.size.width;
              final seekPosition = Duration(
                milliseconds:
                    (_totalDuration.inMilliseconds * progress).round(),
              );
              _seekTo(seekPosition);
            },
            child: SizedBox(
              height: 40,
              child: widget.waveformData != null ||
                      _extractedWaveform.isNotEmpty
                  ? EnhancedVoiceVisualizer(
                      waveformData: widget.waveformData ?? _extractedWaveform,
                      isRecording: false,
                      isPlaying: _isPlaying,
                      progress: _totalDuration.inMilliseconds > 0
                          ? _currentPosition.inMilliseconds /
                              _totalDuration.inMilliseconds
                          : 0.0,
                      primaryColor: widget.isMe
                          ? Colors.white
                          : theme.colorScheme.primary,
                      secondaryColor: widget.isMe
                          ? Colors.white70
                          : theme.colorScheme.secondary,
                      height: 40,
                      showProgress: true,
                      animated: _isPlaying,
                    )
                  : AudioFileWaveforms(
                      size: const Size(double.infinity, 40),
                      playerController:
                          _voicePlayerService.getPlayerController(_voiceId!) ??
                              PlayerController(),
                      enableSeekGesture: true,
                      waveformType: WaveformType.long,
                      playerWaveStyle: PlayerWaveStyle(
                        fixedWaveColor: (widget.isMe
                                ? Colors.white
                                : theme.colorScheme.primary)
                            .withValues(alpha: 0.3),
                        liveWaveColor: widget.isMe
                            ? Colors.white
                            : theme.colorScheme.primary,
                        spacing: 4.0,
                        showSeekLine: true,
                        seekLineColor: widget.isMe
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                    ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // مدت زمان
        Text(
          _formatDuration(_totalDuration),
          style: TextStyle(
            fontSize: 12,
            color: widget.isMe ? Colors.white70 : theme.colorScheme.onSurface,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceInfo(ThemeData theme, bool isDark) {
    return Row(
      children: [
        // زمان فعلی
        Text(
          _formatDuration(_currentPosition),
          style: TextStyle(
            fontSize: 11,
            color: widget.isMe
                ? Colors.white60
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontFamily: 'monospace',
          ),
        ),

        const Spacer(),

        // وضعیت پخش
        if (_isPlaying)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'در حال پخش',
              style: TextStyle(
                fontSize: 10,
                color: widget.isMe ? Colors.white : theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
