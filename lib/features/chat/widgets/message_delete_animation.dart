// lib/features/chat/widgets/message_delete_animation.dart
//
// Particle "powder" delete animation for message bubbles.
// Waits for layout to be available before generating particles to avoid
// zero-size issues. The implementation is self-contained and exposes a
// controller compatible with existing callers.

import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Controller used by parent to trigger the delete animation for a specific
/// message widget.
class MessageDeleteAnimationController {
  _MessageDeleteAnimationState? _state;

  void attach(_MessageDeleteAnimationState state) {
    _state = state;
  }

  /// Trigger the delete animation (will await completion).
  Future<void> startDeleteAnimation() async {
    if (_state != null) await _state!._startAnimation();
  }
}

/// A message-level delete animation that shows a "powder" particle effect
/// and simultaneously fades & shrinks the message out. It waits for layout
/// to be available before generating particles so the effect is reliable.
class MessageDeleteAnimation extends StatefulWidget {
  final Widget child;
  final MessageDeleteAnimationController? controller;
  final VoidCallback? onAnimationComplete;
  final Duration duration;
  final int particleCount;

  const MessageDeleteAnimation({
    super.key,
    required this.child,
    this.controller,
    this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 550),
    this.particleCount = 40,
  });

  @override
  State<MessageDeleteAnimation> createState() => _MessageDeleteAnimationState();
}

class _MessageDeleteAnimationState extends State<MessageDeleteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _sizeAnim;

  final List<_Particle> _particles = [];
  bool _showParticles = false;
  Size? _childSize;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _sizeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeIn),
    );
  }

  /// متد ایمن برای به دست آوردن سایز ویجت
  Future<void> _ensureChildSize() async {
    if (!mounted) return;

    // 1. اگر در فاز رندرینگ هستیم، صبر میکنیم تا فریم تمام شود
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }

    // 2. تلاش اول برای گرفتن سایز
    RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize && !box.debugNeedsLayout) {
      _childSize = box.size;
      return;
    }

    // 3. اگر هنوز سایز نداشتیم، یک فریم دیگر صبر میکنیم (برای اطمینان)
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    // تلاش مجدد بعد از تاخیر
    box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      _childSize = box.size;
    } else {
      // 4. فال‌بک نهایی برای جلوگیری از کرش
      // اگر به هر دلیلی سایز پیدا نشد، یک سایز تخمینی بر اساس عرض صفحه در نظر میگیریم
      // تا انیمیشن بدون خطا اجرا شود (حتی اگر دقیق نباشد)
      final mq = MediaQuery.maybeOf(context);
      _childSize = Size(mq?.size.width ?? 300, 50);
    }
  }

  void _generateParticles() {
    // اگر به هر دلیلی سایز نال بود، انیمیشن ذرات را اجرا نکن
    if (_childSize == null) return;

    _particles.clear();
    final size = _childSize!;

    for (var i = 0; i < widget.particleCount; i++) {
      final startX = _random.nextDouble() * size.width;
      final startY = _random.nextDouble() * size.height;

      final angle = _random.nextDouble() * 2 * pi;
      final speed = 20 + _random.nextDouble() * 80;

      final endX = startX + cos(angle) * speed;
      final endY =
          startY + sin(angle) * speed - (10 + _random.nextDouble() * 40);

      final particleSize = 2 + _random.nextDouble() * 5;
      final delay = _random.nextDouble() * 0.15;

      final gray = 150 + _random.nextInt(80);
      final color = Color.fromARGB(255, gray, gray, gray);

      _particles.add(_Particle(
        start: Offset(startX, startY),
        end: Offset(endX, endY),
        size: particleSize,
        delay: delay,
        color: color,
      ));
    }
  }

  Future<void> _startAnimation() async {
    if (!mounted) return;

    // ابتدا سعی میکنیم سایز را بگیریم
    await _ensureChildSize();

    // اگر سایز معتبر بود، ذرات را تولید میکنیم
    if (_childSize != null) {
      _generateParticles();
      setState(() {
        _showParticles = true;
      });
    }

    // انیمیشن محو شدن همیشه اجرا شود (چه سایز داشته باشیم چه نه)
    await _controller.forward();

    // مکث کوتاه برای هماهنگی با حذف از لیست
    await Future.delayed(const Duration(milliseconds: 60));

    if (mounted) {
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final particleSize = _childSize;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Animated child: fade & shrink
        // SizeTransition کوچک میکنه و فضا رو آزاد میکنه
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnim),
          child: SizeTransition(
            sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_sizeAnim),
            axisAlignment: 0.0,
            child: widget.child,
          ),
        ),

        // Particles overlay - Positioned استفاده میشه تا روی سایز Stack تأثیر نذاره
        // این باعث میشه وقتی پیام کوچک میشه، فضا هم کوچک بشه
        if (_showParticles && _particles.isNotEmpty && particleSize != null)
          Positioned(
            left: 0,
            top: 0,
            // با استفاده از UnconstrainedBox، CustomPaint سایز خودش رو داره
            // بدون تأثیر روی layout
            child: IgnorePointer(
              child: UnconstrainedBox(
                child: SizedBox(
                  width: particleSize.width,
                  height: particleSize.height,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ParticlePainter(
                          particles: _particles,
                          progress: _controller.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Particle {
  final Offset start;
  final Offset end;
  final double size;
  final double delay; // normalized delay [0..1)
  final Color color;

  _Particle({
    required this.start,
    required this.end,
    required this.size,
    required this.delay,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final localProgress =
          ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final x = lerpDouble(p.start.dx, p.end.dx, localProgress) ?? p.start.dx;
      final y = lerpDouble(p.start.dy, p.end.dy, localProgress) ?? p.start.dy;

      final opacity = (1 - localProgress).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(opacity);

      final currentSize = p.size * (1 - 0.5 * localProgress);
      canvas.drawCircle(Offset(x, y), currentSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.particles != particles;
  }
}
