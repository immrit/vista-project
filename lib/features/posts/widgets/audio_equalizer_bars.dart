import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Soft animated equalizer bars used on the music preview.
///
/// Lightweight: a single [AnimationController] drives every bar with a phase
/// offset, so N bars cost one ticker (no per-bar controllers). No blur / no
/// saveLayer — cheap to keep running while composing.
class AudioEqualizerBars extends StatefulWidget {
  const AudioEqualizerBars({
    super.key,
    this.color = Colors.white,
    this.barCount = 4,
    this.height = 18,
    this.barWidth = 3,
    this.spacing = 3,
    this.animate = true,
  });

  final Color color;
  final int barCount;
  final double height;
  final double barWidth;
  final double spacing;
  final bool animate;

  @override
  State<AudioEqualizerBars> createState() => _AudioEqualizerBarsState();
}

class _AudioEqualizerBarsState extends State<AudioEqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant AudioEqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              // Phase-shifted sine per bar → organic, non-uniform bounce.
              final phase = (_controller.value * 2 * math.pi) + (i * 1.3);
              final t = (math.sin(phase) + 1) / 2; // 0..1
              final factor = widget.animate ? (0.30 + 0.70 * t) : 0.5;
              return Padding(
                padding: EdgeInsets.only(
                    right: i == widget.barCount - 1 ? 0 : widget.spacing),
                child: Container(
                  width: widget.barWidth,
                  height: widget.height * factor,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(widget.barWidth),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
