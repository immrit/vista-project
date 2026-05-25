import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/chat_theme.dart';

class TelegramVoiceRecorderBar extends StatelessWidget {
  final ChatTheme theme;
  final bool isLocked;
  final bool isCanceling;
  final int durationSeconds;
  final double swipeProgress;
  final double lockProgress;
  final List<double> waveform;
  final VoidCallback onCancel;
  final VoidCallback onLock;
  final VoidCallback onSend;
  final VoidCallback onStopUnlocked;

  const TelegramVoiceRecorderBar({
    super.key,
    required this.theme,
    required this.isLocked,
    required this.isCanceling,
    required this.durationSeconds,
    required this.swipeProgress,
    required this.lockProgress,
    required this.waveform,
    required this.onCancel,
    required this.onLock,
    required this.onSend,
    required this.onStopUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final indicator =
        isCanceling ? 'رها کنید برای حذف' : 'به چپ بکشید برای حذف';

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.errorColor.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.errorColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'لغو',
            onPressed: onCancel,
            icon: Icon(Icons.delete_outline_rounded, color: theme.errorColor),
          ),
          _TimerPill(
            durationSeconds: durationSeconds,
            theme: theme,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  indicator,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                _WaveformStrip(
                  waveform: waveform,
                  activeColor: theme.errorColor,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLocked)
            GestureDetector(
              onTap: onSend,
              child: _ActionCircle(
                color: theme.sendButtonColor,
                icon: Icons.send_rounded,
              ),
            )
          else
            GestureDetector(
              onTap: onLock,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _ActionCircle(
                    color: theme.secondaryTextColor.withValues(alpha: 0.35),
                    icon: Icons.lock_outline_rounded,
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      value: lockProgress.clamp(0.0, 1.0),
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(theme.sendButtonColor),
                      backgroundColor:
                          theme.secondaryTextColor.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
          if (!isLocked) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onStopUnlocked,
              child: _ActionCircle(
                color: theme.sendButtonColor.withValues(alpha: 0.8),
                icon: Icons.stop_rounded,
              ),
            ),
          ],
          if (!isLocked && swipeProgress > 0.05) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_double_arrow_left_rounded,
              color: Color.lerp(
                theme.secondaryTextColor,
                theme.errorColor,
                swipeProgress.clamp(0.0, 1.0),
              ),
              size: lerpDouble(16, 24, swipeProgress.clamp(0.0, 1.0)),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimerPill extends StatelessWidget {
  final int durationSeconds;
  final ChatTheme theme;

  const _TimerPill({
    required this.durationSeconds,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    final value =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.errorColor.withValues(alpha: 0.14),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: theme.errorColor,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _WaveformStrip extends StatelessWidget {
  final List<double> waveform;
  final Color activeColor;

  const _WaveformStrip({
    required this.waveform,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(20, (index) {
        final sample = waveform.isEmpty
            ? ((index % 3) + 1) / 6
            : waveform[index % waveform.length];
        final h = 4 + (sample.clamp(0.0, 1.0) * 14);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: activeColor,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _ActionCircle({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}
