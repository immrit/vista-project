import 'package:flutter/material.dart';
import 'dart:math' as math;

/// ویجت تجسم بصری پیشرفته برای وویس
class EnhancedVoiceVisualizer extends StatefulWidget {
  final List<double> waveformData;
  final bool isRecording;
  final bool isPlaying;
  final double progress; // 0.0 to 1.0
  final Color? primaryColor;
  final Color? secondaryColor;
  final double height;
  final bool showProgress;
  final bool animated;

  const EnhancedVoiceVisualizer({
    super.key,
    required this.waveformData,
    this.isRecording = false,
    this.isPlaying = false,
    this.progress = 0.0,
    this.primaryColor,
    this.secondaryColor,
    this.height = 40.0,
    this.showProgress = true,
    this.animated = true,
  });

  @override
  State<EnhancedVoiceVisualizer> createState() =>
      _EnhancedVoiceVisualizerState();
}

class _EnhancedVoiceVisualizerState extends State<EnhancedVoiceVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.animated && (widget.isRecording || widget.isPlaying)) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EnhancedVoiceVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.animated) {
      if (widget.isRecording || widget.isPlaying) {
        if (!_animationController.isAnimating) {
          _animationController.repeat(reverse: true);
        }
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? theme.colorScheme.primary;
    final secondaryColor = widget.secondaryColor ?? theme.colorScheme.secondary;

    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        painter: VoiceVisualizerPainter(
          waveformData: widget.waveformData,
          progress: widget.progress,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          isRecording: widget.isRecording,
          isPlaying: widget.isPlaying,
          showProgress: widget.showProgress,
          animationValue: widget.animated ? _animation.value : 1.0,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class VoiceVisualizerPainter extends CustomPainter {
  final List<double> waveformData;
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isRecording;
  final bool isPlaying;
  final bool showProgress;
  final double animationValue;

  VoiceVisualizerPainter({
    required this.waveformData,
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.isRecording,
    required this.isPlaying,
    required this.showProgress,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final centerY = size.height / 2;
    final barWidth = 3.0;
    final spacing = 2.0;
    final totalBarWidth = barWidth + spacing;

    // تعداد کل میله‌ها
    final totalBars = (size.width / totalBarWidth).floor();

    // محاسبه تعداد میله‌های فعال بر اساس progress
    final activeBars = (totalBars * progress).floor();

    for (int i = 0; i < totalBars; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      final isActive = i < activeBars;

      // دریافت ارتفاع میله از waveform data یا تولید تصادفی
      double barHeight;
      if (waveformData.isNotEmpty && i < waveformData.length) {
        barHeight = (waveformData[i] / 100) * size.height * 0.8;
      } else {
        // تولید ارتفاع تصادفی برای میله‌های خالی
        barHeight = (math.Random().nextDouble() * 0.3 + 0.1) * size.height;
      }

      // حداقل ارتفاع
      barHeight = math.max(barHeight, size.height * 0.05);

      // انیمیشن پیشرفته برای ضبط/پخش
      if ((isRecording || isPlaying) && isActive) {
        // افکت موج پیشرفته‌تر
        final waveEffect = 0.5 + 0.5 * animationValue;
        barHeight *= waveEffect;

        // افکت ارتفاع متفاوت برای هر میله (مثل امواج واقعی صدا)
        final waveOffset = math.sin(
                (i / totalBars) * math.pi * 2 + animationValue * math.pi * 2) *
            0.2;
        barHeight *= (1.0 + waveOffset);
      }

      // انتخاب رنگ
      Color barColor;
      if (isActive) {
        if (isRecording) {
          barColor = primaryColor;
        } else if (isPlaying) {
          barColor = secondaryColor;
        } else {
          barColor = primaryColor.withValues(alpha: 0.7);
        }
      } else {
        barColor = primaryColor.withValues(alpha: 0.2);
      }

      paint.color = barColor;

      // رسم میله
      final topY = centerY - barHeight / 2;
      final bottomY = centerY + barHeight / 2;

      canvas.drawLine(
        Offset(x, topY),
        Offset(x, bottomY),
        paint..strokeWidth = barWidth,
      );
    }

    // رسم خط پیشرفت
    if (showProgress && progress > 0) {
      final progressPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.3)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final progressX = size.width * progress;
      canvas.drawLine(
        Offset(progressX, 0),
        Offset(progressX, size.height),
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceVisualizerPainter oldDelegate) {
    return oldDelegate.waveformData != waveformData ||
        oldDelegate.progress != progress ||
        oldDelegate.isRecording != isRecording ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.animationValue != animationValue;
  }
}

/// ویجت نمایش اطلاعات وویس
class VoiceInfoDisplay extends StatelessWidget {
  final int duration;
  final double fileSize;
  final bool isRecording;
  final bool isPlaying;
  final String? status;

  const VoiceInfoDisplay({
    super.key,
    required this.duration,
    required this.fileSize,
    this.isRecording = false,
    this.isPlaying = false,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // آیکون وضعیت
          Icon(
            isRecording
                ? Icons.mic
                : isPlaying
                    ? Icons.play_arrow
                    : Icons.audiotrack,
            size: 16,
            color: isRecording
                ? Colors.red
                : isPlaying
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
          ),

          const SizedBox(width: 8),

          // مدت زمان
          Text(
            _formatDuration(duration),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 8),

          // حجم فایل
          Text(
            _formatFileSize(fileSize),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),

          // وضعیت اضافی
          if (status != null) ...[
            const SizedBox(width: 8),
            Text(
              status!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(double sizeInKB) {
    if (sizeInKB < 1024) {
      return '${sizeInKB.toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInKB / 1024).toStringAsFixed(1)} MB';
    }
  }
}
