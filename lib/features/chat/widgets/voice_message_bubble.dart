// lib/features/chat/widgets/voice_message_bubble.dart
//
// ویجت پیام صوتی مدرن با الهام از ویستا
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
import 'package:path/path.dart' as p;
import '../theme/chat_theme.dart';
import '../../../services/voice_player_service.dart';
import '../../emoji/domain/emoji_render_policy.dart';
import '../../emoji/widgets/telegram_emoji_text.dart';

/// ویجت پیام صوتی شبیه ویستا
class VoiceMessageBubble extends StatefulWidget {
  final String messageId;
  final String audioUrl;
  final String? localFilePath;
  final int? durationSeconds;
  final List<double>? waveformData;
  final bool isMe;
  final DateTime time;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? conversationId;
  final String? conversationTitle;
  final String? attachmentType;
  final String? audioTitle;
  final String? audioArtist;
  final String? audioAlbum;
  final String? caption;

  const VoiceMessageBubble({
    super.key,
    required this.messageId,
    required this.audioUrl,
    this.localFilePath,
    this.durationSeconds,
    this.waveformData,
    required this.isMe,
    required this.time,
    this.senderName,
    this.senderAvatarUrl,
    this.conversationId,
    this.conversationTitle,
    this.attachmentType,
    this.audioTitle,
    this.audioArtist,
    this.audioAlbum,
    this.caption,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLLERS & STATE
  // ═══════════════════════════════════════════════════════════════════════════

  // Use centralized VoicePlayerService instead of per-widget AudioPlayer
  late final VoicePlayerService _playerService;
  late AnimationController _playButtonController;
  late AnimationController _waveformController;
  late AnimationController _progressController;

  // State
  bool _isInitialized = false;
  bool _isDownloading = false;
  bool _isPlaying = false;
  final double _downloadProgress =
      0.0; // retained for UI compatibility when showing progress
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
    _playerService = VoicePlayerService();
    _initializeAnimations();
    _initializeWaveform();
    _subscribeToPlayerService();

    if (widget.durationSeconds != null) {
      _totalDuration = Duration(seconds: widget.durationSeconds!);
      _isInitialized = true;
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

  StreamSubscription<VoicePlayerState>? _playerSub;

  void _subscribeToPlayerService() {
    _playerSub = _playerService.playerStateStream.listen((state) {
      if (!mounted) return;

      final relevant = state.voiceId == widget.messageId;
      final fallbackDuration = widget.durationSeconds != null
          ? Duration(seconds: widget.durationSeconds!)
          : Duration.zero;

      // Update play/position/duration/initialized based on current state
      setState(() {
        _isPlaying = relevant && state.isPlaying;
        _currentPosition = relevant ? state.position : Duration.zero;
        if (relevant && state.duration > Duration.zero) {
          _totalDuration = state.duration;
        } else if (_totalDuration == Duration.zero) {
          _totalDuration = fallbackDuration;
        }
        // if the service is preparing this voice id, consider it initialized/loading
        _isDownloading = relevant && state.isLoading;
        _isInitialized = relevant || _totalDuration > Duration.zero;
        _error = relevant ? state.errorMessage : null;
      });

      if (_isPlaying) {
        _playButtonController.forward();
        _waveformController.repeat();
      } else {
        _playButtonController.reverse();
        _waveformController.stop();
      }
    });
  }

  @override
  void dispose() {
    _playerSub?.cancel();
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

  // Download handled by centralized service; keep method for compatibility if needed

  Future<void> _togglePlayPause() async {
    HapticFeedback.lightImpact();
    if (_error != null && mounted) {
      setState(() => _error = null);
    }
    await _playerService.playOrPause(
      widget.messageId,
      widget.audioUrl,
      localFilePath: widget.localFilePath,
      title: _resolvePlaybackTitle(),
      artist: _resolvePlaybackArtist(),
      artUrl: widget.senderAvatarUrl,
      conversationId: widget.conversationId,
      conversationTitle: widget.conversationTitle,
      attachmentType: widget.attachmentType,
    );
  }

  void _seekToPosition(double progress) {
    if (_totalDuration.inMilliseconds == 0) return;

    final position = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round(),
    );
    _playerService.seek(position);
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
    _playerService.setSpeed(_playbackSpeed);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final playbackTitle = _resolvePlaybackTitle();
    final playbackArtist = _resolvePlaybackArtist();
    final showTrackMeta =
        (widget.attachmentType ?? '').toLowerCase() == 'audio' &&
            (playbackTitle.isNotEmpty || playbackArtist.isNotEmpty);

    return Container(
      constraints: const BoxConstraints(maxWidth: 280, minWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTrackMeta) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                playbackTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.isMe
                      ? theme.myBubbleTextColor
                      : theme.otherBubbleTextColor,
                ),
              ),
            ),
            if (playbackArtist.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Text(
                    playbackArtist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isMe
                          ? theme.myBubbleTextColor.withOpacity(0.75)
                          : theme.secondaryTextColor,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 6),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPlayButton(theme),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildWaveform(theme),
                    const SizedBox(height: 4),
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
                        if (_isInitialized)
                          GestureDetector(
                            onTap: _changePlaybackSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isMe
                                    ? (theme.isDark
                                        ? Colors.white.withOpacity(0.2)
                                        : theme.sendButtonColor
                                            .withOpacity(0.15))
                                    : theme.sendButtonColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: widget.isMe
                                      ? (theme.isDark
                                          ? Colors.white
                                          : theme.sendButtonColor)
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
          if (widget.caption != null && widget.caption!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TelegramEmojiText(
                widget.caption!,
                useTelegramEmoji: EmojiRenderPolicy.useTelegramEmojiRenderer(),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: widget.isMe
                      ? theme.myBubbleTextColor
                      : theme.otherBubbleTextColor,
                  fontSize: 15,
                  fontFamily: 'Vazir',
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 14,
                  color: theme.errorColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.errorColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayButton(ChatTheme theme) {
    // رنگ‌های متفاوت برای تم روشن و تاریک با کنتراست بهتر
    final Color buttonColor;
    final Color iconColor;

    if (widget.isMe) {
      // پیام‌های من
      if (theme.isDark) {
        buttonColor = Colors.white.withOpacity(0.15);
        iconColor = Colors.white;
      } else {
        // تم روشن: از رنگ تیره‌تر استفاده میکنیم
        buttonColor = theme.sendButtonColor.withOpacity(0.15);
        iconColor = theme.sendButtonColor;
      }
    } else {
      // پیام‌های دیگران
      buttonColor = theme.sendButtonColor.withOpacity(0.15);
      iconColor = theme.sendButtonColor;
    }

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

    // رنگ‌های waveform با کنتراست بهتر برای تم روشن و تاریک
    final Color activeColor;
    final Color inactiveColor;

    if (widget.isMe) {
      if (theme.isDark) {
        activeColor = Colors.white;
        inactiveColor = Colors.white.withOpacity(0.4);
      } else {
        // تم روشن: از رنگ اصلی استفاده میکنیم برای خوانایی بهتر
        activeColor = theme.sendButtonColor;
        inactiveColor = theme.sendButtonColor.withOpacity(0.35);
      }
    } else {
      activeColor = theme.sendButtonColor;
      inactiveColor = theme.sendButtonColor.withOpacity(0.35);
    }

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

  String _resolvePlaybackTitle() {
    final normalizedType = (widget.attachmentType ?? '').toLowerCase();
    final taggedTitle = widget.audioTitle?.trim();
    if (taggedTitle != null && taggedTitle.isNotEmpty) {
      return taggedTitle;
    }
    final caption = widget.caption?.trim();
    if (caption != null && caption.isNotEmpty) {
      return caption;
    }
    final derivedFromFile = _deriveTitleFromFilePath(widget.localFilePath);
    if (derivedFromFile != null && derivedFromFile.isNotEmpty) {
      return derivedFromFile;
    }
    return normalizedType == 'audio' ? 'Music' : 'Voice message';
  }

  String _resolvePlaybackArtist() {
    final taggedArtist = widget.audioArtist?.trim();
    if (taggedArtist != null && taggedArtist.isNotEmpty) {
      return taggedArtist;
    }

    final parsedFromTitle = _deriveArtistFromTrackText(widget.audioTitle);
    if (parsedFromTitle != null && parsedFromTitle.isNotEmpty) {
      return parsedFromTitle;
    }

    final fromLocalName = _deriveArtistFromTrackText(
        _deriveTitleFromFilePath(widget.localFilePath));
    if (fromLocalName != null && fromLocalName.isNotEmpty) {
      return fromLocalName;
    }

    final sender = widget.senderName?.trim();
    if (sender != null &&
        sender.isNotEmpty &&
        sender != 'کاربر ناشناس' &&
        sender != 'کاربر') {
      return sender;
    }

    final conversation = widget.conversationTitle?.trim();
    if (conversation != null &&
        conversation.isNotEmpty &&
        conversation != 'کاربر ناشناس' &&
        conversation != 'کاربر') {
      return conversation;
    }

    return 'Unknown artist';
  }

  String? _deriveArtistFromTrackText(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    final separators = <String>[' - ', ' – ', ' — ', ' | ', ' / ', '_'];
    for (final sep in separators) {
      final idx = normalized.indexOf(sep);
      if (idx > 0) {
        final candidate = normalized.substring(0, idx).trim();
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return null;
  }

  String? _deriveTitleFromFilePath(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    final name = p.basename(filePath).trim();
    if (name.isEmpty) return null;
    final ext = p.extension(name);
    final raw =
        ext.isEmpty ? name : name.substring(0, name.length - ext.length);
    final normalized = raw.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
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
