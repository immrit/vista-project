import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../services/telegram_voice_player_service.dart';

/// ویجت پخش وویس پیشرفته مثل تلگرام
class TelegramVoicePlayerWidget extends StatefulWidget {
  final String audioUrl;
  final Uint8List? audioBytes;
  final String? localPath;
  final int duration;
  final List<double> waveformData;
  final bool isMe;
  final bool isPreview;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final PlaybackConfig? playbackConfig;

  const TelegramVoicePlayerWidget({
    super.key,
    required this.audioUrl,
    this.audioBytes,
    this.localPath,
    required this.duration,
    required this.waveformData,
    required this.isMe,
    this.isPreview = false,
    this.onDelete,
    this.onReply,
    this.onForward,
    this.playbackConfig,
  });

  @override
  State<TelegramVoicePlayerWidget> createState() =>
      _TelegramVoicePlayerWidgetState();
}

class _TelegramVoicePlayerWidgetState extends State<TelegramVoicePlayerWidget>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _playButtonController;
  late AnimationController _waveformController;
  late AnimationController _speedController;

  // Animations
  late Animation<double> _playButtonAnimation;
  late Animation<double> _waveformAnimation;
  late Animation<double> _speedAnimation;

  // Voice player service
  final TelegramVoicePlayerService _playerService =
      TelegramVoicePlayerService();

  // Player state
  String? _playerId;
  VoicePlaybackState _playbackState = VoicePlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isLoading = false;
  String? _error;

  // UI state
  bool _showSpeedMenu = false;
  final bool _showVolumeSlider = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePlayerService();
    _setupPlayer();
  }

  void _initializeAnimations() {
    // Play button animation
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _playButtonAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _playButtonController,
      curve: Curves.easeInOut,
    ));

    // Waveform animation
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _waveformAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    ));

    // Speed menu animation
    _speedController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _speedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _speedController,
      curve: Curves.easeInOut,
    ));
  }

  void _initializePlayerService() {
    _playerService.setCallbacks(
      onStateChanged: (state) {
        if (mounted) {
          setState(() {
            _playbackState = state;
            _isLoading = state == VoicePlaybackState.loading;
            _error = state == VoicePlaybackState.error ? 'خطا در پخش' : null;
          });

          // Animation handling
          if (state == VoicePlaybackState.playing) {
            _playButtonController.forward();
            _waveformController.forward();
          } else if (state == VoicePlaybackState.paused) {
            _playButtonController.reverse();
          } else if (state == VoicePlaybackState.stopped) {
            _playButtonController.reverse();
            _waveformController.reverse();
          }
        }
      },
      onPositionChanged: (position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      },
      onDurationChanged: (duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
          });
        }
      },
      onSpeedChanged: (speed) {
        if (mounted) {
          setState(() {
            _playbackSpeed = speed;
          });
        }
      },
      onVolumeChanged: (volume) {
        if (mounted) {
          setState(() {
            _volume = volume;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error;
            _playbackState = VoicePlaybackState.error;
          });
        }
      },
    );
  }

  void _setupPlayer() {
    _playerId =
        '${widget.audioUrl.hashCode}_${DateTime.now().millisecondsSinceEpoch}';

    // تنظیم کانفیگ پخش
    if (widget.playbackConfig != null) {
      _playerService.setPlaybackConfig(_playerId!, widget.playbackConfig!);
    }

    // تنظیم مدت زمان
    _duration = Duration(seconds: widget.duration);
  }

  @override
  void dispose() {
    _playButtonController.dispose();
    _waveformController.dispose();
    _speedController.dispose();

    // توقف پخش
    if (_playerId != null) {
      _playerService.stopPlayback(_playerId!);
    }

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

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(
        minWidth: 200,
        maxWidth: 280,
        minHeight: 60,
      ),
      decoration: widget.isPreview
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ردیف اصلی: دکمه پلی، نوار پیشرفت/موج، دکمه سرعت
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // دکمه پلی/پاز
              _buildPlayButton(textColor),

              const SizedBox(width: 12),

              // ویجت ترکیب موج و نوار پیشرفت
              Expanded(
                child: _buildSeekbarWithWaveform(textColor),
              ),

              const SizedBox(width: 8),

              // دکمه سرعت پخش
              _buildPlaybackSpeedButton(textColor),
            ],
          ),

          const SizedBox(height: 8),

          // ردیف دوم: مدت زمان و دکمه‌های عملیات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // مدت زمان
              _buildDurationText(textColor),

              // دکمه‌های عملیات
              if (widget.isMe && !widget.isPreview)
                _buildActionButtons(textColor),
            ],
          ),

          // منوی سرعت پخش
          if (_showSpeedMenu) _buildSpeedMenu(textColor),

          // اسلایدر حجم صدا
          if (_showVolumeSlider) _buildVolumeSlider(textColor),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color textColor) {
    return GestureDetector(
      onTap: _error != null ? null : _playPause,
      child: AnimatedBuilder(
        animation: _playButtonAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _playButtonAnimation.value,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _error != null
                    ? Colors.red.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    )
                  : Icon(
                      _error != null
                          ? Icons.error_outline
                          : (_playbackState == VoicePlaybackState.playing
                              ? Icons.pause
                              : Icons.play_arrow),
                      color: textColor,
                      size: 24,
                    ),
            ),
          );
        },
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
              trackHeight: 30,
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: textColor.withValues(alpha: 0.4),
              inactiveTrackColor: Colors.transparent,
              thumbColor: textColor,
              overlayColor: textColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _duration.inSeconds > 0
                  ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
                  : 0.0,
              onChanged: _error != null ? null : _seek,
            ),
          ),
      ],
    );
  }

  Widget _buildWaveform(Color textColor) {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _waveformAnimation.value,
          child: SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.isPreview ? 12 : 20, (index) {
                // استفاده از waveform داده یا سینوس
                final height = widget.waveformData.isNotEmpty
                    ? (widget.waveformData.length > index
                        ? widget.waveformData[index] / 100 * 20
                        : 4.0)
                    : 4.0 + (math.sin(index * 0.5) * 8).abs();

                // انیمیشن شفافیت بر اساس موقعیت پخش
                final double opacity =
                    _playbackState == VoicePlaybackState.playing
                        ? (0.5 +
                                (math.sin(index * 0.9 +
                                            _position.inMilliseconds / 200) *
                                        0.5)
                                    .abs())
                            .clamp(0.3, 1.0)
                        : 0.4;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 2.5,
                  height: height.clamp(4.0, 22.0),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaybackSpeedButton(Color textColor) {
    return GestureDetector(
      onTap: _toggleSpeedMenu,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed.toStringAsFixed(1)}x',
          style: TextStyle(
            color: textColor.withValues(alpha: 0.9),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDurationText(Color textColor) {
    return Text(
      _duration.inSeconds > 0
          ? '${_formatDuration(_position)} / ${_formatDuration(_duration)}'
          : '--:--',
      style: TextStyle(
        color: textColor.withValues(alpha: 0.8),
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _buildActionButtons(Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onReply != null)
          IconButton(
            onPressed: widget.onReply,
            icon: Icon(
              Icons.reply_rounded,
              color: textColor.withValues(alpha: 0.8),
              size: 16,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        if (widget.onForward != null)
          IconButton(
            onPressed: widget.onForward,
            icon: Icon(
              Icons.forward_rounded,
              color: textColor.withValues(alpha: 0.8),
              size: 16,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        if (widget.onDelete != null)
          IconButton(
            onPressed: widget.onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: textColor.withValues(alpha: 0.8),
              size: 16,
            ),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  Widget _buildSpeedMenu(Color textColor) {
    final availableSpeeds = _playerService.getAvailableSpeeds(_playerId!);

    return AnimatedBuilder(
      animation: _speedAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _speedAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: availableSpeeds.map((speed) {
                final isSelected = speed == _playbackSpeed;
                return GestureDetector(
                  onTap: () => _changePlaybackSpeed(speed),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${speed.toStringAsFixed(1)}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVolumeSlider(Color textColor) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.volume_down,
            color: textColor.withValues(alpha: 0.7),
            size: 16,
          ),
          Expanded(
            child: Slider(
              value: _volume,
              onChanged: (value) => _changeVolume(value),
              activeColor: textColor,
              inactiveColor: textColor.withValues(alpha: 0.3),
            ),
          ),
          Icon(
            Icons.volume_up,
            color: textColor.withValues(alpha: 0.7),
            size: 16,
          ),
        ],
      ),
    );
  }

  // Player methods
  Future<void> _playPause() async {
    if (_playerId == null) return;

    if (_playbackState == VoicePlaybackState.playing) {
      await _playerService.pauseResumePlayback(_playerId!);
    } else if (_playbackState == VoicePlaybackState.paused) {
      await _playerService.pauseResumePlayback(_playerId!);
    } else {
      // شروع پخش جدید
      final fileInfo = VoiceFileInfo(
        url: widget.audioUrl,
        bytes: widget.audioBytes,
        localPath: widget.localPath,
        duration: widget.duration,
        waveformData: widget.waveformData,
        fileSize: 0, // اینجا می‌توان سایز فایل را محاسبه کرد
        timestamp: DateTime.now(),
      );

      await _playerService.playVoice(_playerId!, fileInfo);
    }
  }

  Future<void> _seek(double value) async {
    if (_playerId == null) return;

    final position = Duration(seconds: (value * _duration.inSeconds).round());
    await _playerService.seekTo(_playerId!, position);
  }

  void _changePlaybackSpeed(double speed) {
    if (_playerId == null) return;

    _playerService.setPlaybackSpeed(_playerId!, speed);
    _toggleSpeedMenu();
  }

  void _changeVolume(double volume) {
    if (_playerId == null) return;

    _playerService.setVolume(_playerId!, volume);
  }

  void _toggleSpeedMenu() {
    setState(() {
      _showSpeedMenu = !_showSpeedMenu;
      if (_showSpeedMenu) {
        _speedController.forward();
      } else {
        _speedController.reverse();
      }
    });
  }

  // Utility methods
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
