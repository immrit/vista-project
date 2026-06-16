import 'dart:ui';

import 'package:flutter/material.dart';

class LiquidGlassInputShell extends StatefulWidget {
  final Widget child;
  final bool reduceEffects;
  final bool isDark;
  final double blurSigma;
  final Color background;
  final Color borderColor;

  const LiquidGlassInputShell({
    super.key,
    required this.child,
    required this.reduceEffects,
    required this.isDark,
    required this.blurSigma,
    required this.background,
    required this.borderColor,
  });

  @override
  State<LiquidGlassInputShell> createState() => _LiquidGlassInputShellState();
}

class _LiquidGlassInputShellState extends State<LiquidGlassInputShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _driftController;

  @override
  void initState() {
    super.initState();
    _driftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _syncDriftAnimation();
  }

  @override
  void didUpdateWidget(LiquidGlassInputShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceEffects != widget.reduceEffects) {
      _syncDriftAnimation();
    }
  }

  void _syncDriftAnimation() {
    if (widget.reduceEffects) {
      if (_driftController.isAnimating) {
        _driftController.stop();
      }
    } else if (!_driftController.isAnimating) {
      _driftController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _driftController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceEffects) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            color: widget.background.withValues(alpha: 0.95),
            border: Border.all(
              color: widget.borderColor.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: widget.child,
        ),
      );
    }

    final effectiveBlur = widget.blurSigma.clamp(0.0, 14.0);

    return AnimatedBuilder(
      animation: _driftController,
      builder: (context, _) {
        final drift = _driftController.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (effectiveBlur > 0)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: effectiveBlur,
                      sigmaY: effectiveBlur,
                    ),
                    child: const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.background,
                    border: Border.all(
                      color: widget.borderColor,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(-1 + (drift * 1.5), -1),
                        end: Alignment(1 + (drift * 1.2), 1),
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(
                            alpha: widget.isDark ? 0.02 : 0.05,
                          ),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.2, 0.5, 0.8],
                      ),
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}
