// lib/features/chat/widgets/molecular_delete_animation.dart
//
// انیمیشن حذف پیام با افکت "پودر شدن" (Molecular/Dissolve Effect)
// استفاده از ShaderMask و ترکیب انیمیشن‌ها برای ایجاد افکت حرفه‌ای

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MolecularDeleteAnimation extends StatefulWidget {
  final Widget child;
  final bool isDeleting;
  final VoidCallback onAnimationComplete;
  final Duration duration;

  const MolecularDeleteAnimation({
    super.key,
    required this.child,
    required this.isDeleting,
    required this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<MolecularDeleteAnimation> createState() => _MolecularDeleteAnimationState();
}

class _MolecularDeleteAnimationState extends State<MolecularDeleteAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MolecularDeleteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _controller.forward();
    } else if (!widget.isDeleting && oldWidget.isDeleting) {
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isDeleting) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        // فاز ۱: لرزش قبل از پودر شدن (۱۰۰ میلی‌ثانیه اول)
        if (_progress.value < 0.1) {
          final offset = (_progress.value * 50).toInt() % 2 == 0 ? 2.0 : -2.0;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: widget.child,
          );
        }

        // فاز ۲: پودر شدن با استفاده از ShaderMask
        // برای پودر شدن واقعی نیاز به Fragment Shader است، اما اینجا
        // برای پرفرمنس از ترکیب Fade و Scale و Noise استفاده می‌کنیم.
        return FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: _controller,
              curve: const Interval(0.2, 1.0),
            ),
          ),
          child: Transform.scale(
            scale: 1.0 + (_progress.value * 0.2), // کمی بزرگ شدن هنگام پودر شدن
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, _progress.value, 1.0],
                  colors: [
                    Colors.transparent, // قسمت حذف شده
                    Colors.white.withOpacity(0.5), // مرز پودر شدن
                    Colors.white, // قسمت باقی مانده
                  ],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstOut, // حذف پیکسل‌ها
              child: widget.child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

