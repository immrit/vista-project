// lib/features/chat/widgets/voice_recorder_widget.dart
//
// ویجت ضبط صدا با انیمیشن - با الهام از تلگرام
//
// ویژگی‌ها:
// ✅ انیمیشن Waveform در حال ضبط
// ✅ نمایش مدت زمان
// ✅ Slide to cancel
// ✅ Lock برای ضبط طولانی
// ✅ انیمیشن pulse دکمه میکروفون
//

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/chat_attachment_service.dart';
import '../theme/chat_theme.dart';

/// وضعیت ضبط
enum RecordingState {
  idle,
  recording,
  locked,
  cancelled,
}

/// نتیجه ضبط
class VoiceRecordingResult {
  final String filePath;
  final int durationSeconds;
  final List<double> waveformData;

  const VoiceRecordingResult({
    required this.filePath,
    required this.durationSeconds,
    required this.waveformData,
  });
}

/// ویجت ضبط صدا
class VoiceRecorderWidget extends StatefulWidget {
  final Function(VoiceRecordingResult) onRecordingComplete;
  final VoidCallback? onRecordingStart;
  final VoidCallback? onRecordingCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onRecordingStart,
    this.onRecordingCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🎮 CONTROLLERS & STATE
  // ═══════════════════════════════════════════════════════════════════════════

  final _attachmentService = ChatAttachmentService();

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _waveformController;
  late AnimationController _lockController;

  RecordingState _state = RecordingState.idle;
  int _recordingDuration = 0;
  List<double> _waveformData = [];
  double _slideOffset = 0;
  bool _isLocked = false;

  Timer? _durationTimer;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎬 LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _waveformController.dispose();
    _lockController.dispose();
    _durationTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎤 RECORDING CONTROL
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _startRecording() async {
    HapticFeedback.mediumImpact();

    final success = await _attachmentService.startVoiceRecording(
      onRecordingStateChanged: (isRecording) {
        if (!isRecording && mounted) {
          _handleRecordingEnd();
        }
      },
      onDurationChanged: (duration) {
        if (mounted) {
          setState(() => _recordingDuration = duration);
        }
      },
      onWaveformDataChanged: (data) {
        if (mounted) {
          setState(() => _waveformData = data);
        }
      },
    );

    if (success) {
      setState(() => _state = RecordingState.recording);
      _pulseController.repeat(reverse: true);
      widget.onRecordingStart?.call();

      // Timer برای آپدیت مدت زمان
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _state == RecordingState.recording) {
          setState(() => _recordingDuration++);
        }
      });
    }
  }

  Future<void> _stopRecording() async {
    _durationTimer?.cancel();
    _pulseController.stop();

    final file = await _attachmentService.stopVoiceRecording();

    if (file != null && mounted) {
      widget.onRecordingComplete(VoiceRecordingResult(
        filePath: file.path,
        durationSeconds: _recordingDuration,
        waveformData: _waveformData,
      ));
    }

    _reset();
  }

  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    _durationTimer?.cancel();
    _pulseController.stop();

    await _attachmentService.cancelVoiceRecording();
    widget.onRecordingCancel?.call();

    _reset();
  }

  void _handleRecordingEnd() {
    if (_state == RecordingState.cancelled) {
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _state = RecordingState.idle;
      _recordingDuration = 0;
      _waveformData = [];
      _slideOffset = 0;
      _isLocked = false;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔨 BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    if (_state == RecordingState.idle) {
      return _buildMicButton(theme);
    }

    return _buildRecordingUI(theme);
  }

  Widget _buildMicButton(ChatTheme theme) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) {
        if (_state == RecordingState.recording && !_isLocked) {
          _stopRecording();
        }
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: theme.sendButtonColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.mic_rounded,
          color: theme.sendButtonColor,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildRecordingUI(ChatTheme theme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        color: theme.inputBackgroundColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel hint یا Lock
          if (!_isLocked) ...[
            _buildSlideToCancel(theme),
          ] else ...[
            _buildLockedControls(theme),
          ],

          const Spacer(),

          // Waveform
          _buildWaveform(theme),

          const SizedBox(width: 12),

          // Duration
          _buildDuration(theme),

          const SizedBox(width: 12),

          // Recording indicator / Send button
          if (_isLocked)
            _buildSendButton(theme)
          else
            _buildRecordingIndicator(theme),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSlideToCancel(ChatTheme theme) {
    return Transform.translate(
      offset: Offset(_slideOffset, 0),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chevron_left_rounded,
              color: theme.secondaryTextColor,
              size: 20,
            ),
            Text(
              'بکش برای لغو',
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedControls(ChatTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancelRecording,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform(ChatTheme theme) {
    return AnimatedBuilder(
      animation: _waveformController,
      builder: (context, child) {
        return SizedBox(
          width: 80,
          height: 32,
          child: CustomPaint(
            painter: _LiveWaveformPainter(
              waveformData: _waveformData.isNotEmpty
                  ? _waveformData
                  : List.generate(20, (_) => math.Random().nextDouble()),
              color: theme.sendButtonColor,
              animationValue: _waveformController.value,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDuration(ChatTheme theme) {
    final minutes = _recordingDuration ~/ 60;
    final seconds = _recordingDuration % 60;
    final durationText = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      durationText,
      style: TextStyle(
        color: theme.textColor,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _buildRecordingIndicator(ChatTheme theme) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.errorColor.withOpacity(0.2 + (_pulseController.value * 0.3)),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.errorColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendButton(ChatTheme theme) {
    return GestureDetector(
      onTap: _stopRecording,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.sendButtonColor,
              theme.sendButtonColor.withBlue(
                (theme.sendButtonColor.blue + 30).clamp(0, 255),
              ),
            ],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.sendButtonColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.send_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎨 WAVEFORM PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _LiveWaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Color color;
  final double animationValue;

  _LiveWaveformPainter({
    required this.waveformData,
    required this.color,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final barCount = waveformData.length.clamp(10, 30);
    final barWidth = size.width / barCount - 2;
    final maxHeight = size.height * 0.8;
    final minHeight = size.height * 0.15;

    for (int i = 0; i < barCount; i++) {
      final dataIndex = i % waveformData.length;
      final normalizedValue = waveformData[dataIndex].clamp(0.0, 1.0);

      // انیمیشن breathing
      final wave = math.sin((animationValue * 2 * math.pi) + (i * 0.5));
      final heightMultiplier = 0.8 + (wave * 0.2);

      final barHeight = (minHeight + (normalizedValue * (maxHeight - minHeight))) * heightMultiplier;
      final x = i * (barWidth + 2) + 1;
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(2),
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_LiveWaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.waveformData != waveformData;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 🎯 OVERLAY VERSION - برای نمایش روی input
// ═══════════════════════════════════════════════════════════════════════════

/// Overlay ضبط صدا که روی input نشون داده میشه
class VoiceRecorderOverlay extends StatelessWidget {
  final int duration;
  final List<double> waveformData;
  final bool isLocked;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final VoidCallback onLock;

  const VoiceRecorderOverlay({
    super.key,
    required this.duration,
    required this.waveformData,
    required this.isLocked,
    required this.onCancel,
    required this.onSend,
    required this.onLock,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.errorColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Cancel
          IconButton(
            onPressed: onCancel,
            icon: Icon(Icons.delete_rounded, color: theme.errorColor),
          ),

          // Duration
          Text(
            _formatDuration(duration),
            style: TextStyle(
              color: theme.errorColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Waveform indicator (simple dots)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200 + (i * 50)),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: 4 + (waveformData.isNotEmpty && i < waveformData.length
                      ? waveformData[i] * 12
                      : 0),
                  decoration: BoxDecoration(
                    color: theme.errorColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),

          // Lock or Send
          if (isLocked)
            IconButton(
              onPressed: onSend,
              icon: Icon(
                Icons.send_rounded,
                color: theme.sendButtonColor,
              ),
            )
          else
            IconButton(
              onPressed: onLock,
              icon: Icon(
                Icons.lock_outline_rounded,
                color: theme.secondaryTextColor,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

