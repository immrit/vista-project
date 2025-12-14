// lib/widgets/universal_delete_animation.dart
//
// انیمیشن حذف عمومی برای تمام انواع محتوا (پیام، پست، وویس، عکس، فایل و...)
// این ویجت در هر دو حالت debug و release به درستی کار می‌کند.

import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Controller برای کنترل انیمیشن حذف از بیرون
class UniversalDeleteAnimationController {
  _UniversalDeleteAnimationState? _state;

  void _attach(_UniversalDeleteAnimationState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// شروع انیمیشن حذف و منتظر ماندن تا تکمیل شود
  Future<void> startDeleteAnimation() async {
    if (_state != null && _state!.mounted) {
      await _state!._startAnimation();
    }
  }

  /// بررسی اینکه آیا انیمیشن در حال اجراست
  bool get isAnimating => _state?._isAnimating ?? false;
}

/// انیمیشن حذف عمومی با افکت پودر شدن
/// قابل استفاده برای: پیام‌ها، پست‌ها، وویس‌ها، عکس‌ها، فایل‌ها و هر نوع محتوای دیگر
class UniversalDeleteAnimation extends StatefulWidget {
  /// ویجت فرزند که انیمیشن روی آن اعمال می‌شود
  final Widget child;

  /// Controller برای کنترل انیمیشن از بیرون
  final UniversalDeleteAnimationController? controller;

  /// callback پس از اتمام انیمیشن
  final VoidCallback? onAnimationComplete;

  /// مدت زمان انیمیشن
  final Duration duration;

  /// تعداد ذرات در افکت پودر شدن
  final int particleCount;

  /// آیا انیمیشن باید فوراً شروع شود؟
  final bool startImmediately;

  /// رنگ ذرات (اگر null باشد، به صورت خودکار بر اساس تم تعیین می‌شود)
  final Color? particleColor;

  const UniversalDeleteAnimation({
    super.key,
    required this.child,
    this.controller,
    this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 500),
    this.particleCount = 50,
    this.startImmediately = false,
    this.particleColor,
  });

  @override
  State<UniversalDeleteAnimation> createState() =>
      _UniversalDeleteAnimationState();
}

class _UniversalDeleteAnimationState extends State<UniversalDeleteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  final List<_Particle> _particles = [];
  bool _showParticles = false;
  bool _isAnimating = false;
  Size? _childSize;

  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _isAnimating = false;
      }
    });

    // اگر باید فوراً شروع شود
    if (widget.startImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAnimation();
      });
    }
  }

  @override
  void didUpdateWidget(UniversalDeleteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // اگر controller عوض شده، به‌روزرسانی کن
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach();
      widget.controller?._attach(this);
    }

    // اگر startImmediately فعال شده و قبلاً نبوده
    if (widget.startImmediately && !oldWidget.startImmediately && !_isAnimating) {
      _startAnimation();
    }
  }

  /// دریافت سایز ویجت فرزند به صورت ایمن
  Future<void> _ensureChildSize() async {
    if (!mounted) return;

    // صبر برای اتمام فریم فعلی
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    // تلاش برای گرفتن سایز
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final size = box.size;
        if (size.width > 0 && size.height > 0) {
          _childSize = size;
          return;
        }
      }
    } catch (_) {}

    // تلاش مجدد بعد از یک فریم
    await Future.delayed(const Duration(milliseconds: 16));
    if (!mounted) return;

    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final size = box.size;
        if (size.width > 0 && size.height > 0) {
          _childSize = size;
          return;
        }
      }
    } catch (_) {}

    // fallback: سایز تخمینی
    final mq = MediaQuery.maybeOf(context);
    _childSize = Size(mq?.size.width ?? 300, 100);
  }

  /// تولید ذرات انیمیشن
  void _generateParticles() {
    if (_childSize == null) return;

    _particles.clear();
    final size = _childSize!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    for (var i = 0; i < widget.particleCount; i++) {
      final startX = _random.nextDouble() * size.width;
      final startY = _random.nextDouble() * size.height;

      final angle = _random.nextDouble() * 2 * pi;
      final speed = 30 + _random.nextDouble() * 100;

      final endX = startX + cos(angle) * speed;
      final endY = startY + sin(angle) * speed - (20 + _random.nextDouble() * 60);

      final particleSize = 2.5 + _random.nextDouble() * 5;
      final delay = _random.nextDouble() * 0.2;

      Color color;
      if (widget.particleColor != null) {
        color = widget.particleColor!;
      } else if (isDark) {
        final gray = 180 + _random.nextInt(75);
        color = Color.fromARGB(255, gray, gray, gray);
      } else {
        final gray = 100 + _random.nextInt(100);
        color = Color.fromARGB(255, gray, gray, gray);
      }

      _particles.add(_Particle(
        start: Offset(startX, startY),
        end: Offset(endX, endY),
        size: particleSize,
        delay: delay,
        color: color,
      ));
    }
  }

  /// شروع انیمیشن حذف
  Future<void> _startAnimation() async {
    if (!mounted || _isAnimating) return;

    _isAnimating = true;

    try {
      await _ensureChildSize();

      if (_childSize != null && _childSize!.width > 0 && _childSize!.height > 0) {
        _generateParticles();
        if (mounted) {
          setState(() => _showParticles = true);
        }
      }

      if (mounted && !_controller.isAnimating) {
        await _controller.forward();
      }

      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      // در صورت خطا، انیمیشن را بدون پارتیکل اجرا کن
      if (mounted && !_controller.isCompleted) {
        try {
          await _controller.forward();
        } catch (_) {}
      }
    }

    _isAnimating = false;

    if (mounted) {
      widget.onAnimationComplete?.call();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final particleSize = _childSize;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ویجت اصلی با انیمیشن محو شدن و کوچک شدن
        FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnim),
          child: SizeTransition(
            sizeFactor: Tween<double>(begin: 1.0, end: 0.0).animate(_scaleAnim),
            axisAlignment: 0.0,
            child: widget.child,
          ),
        ),

        // ذرات پودر شدن
        if (_showParticles && _particles.isNotEmpty && particleSize != null)
          Positioned(
            left: 0,
            top: 0,
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

/// مدل ذره انیمیشن
class _Particle {
  final Offset start;
  final Offset end;
  final double size;
  final double delay;
  final Color color;

  _Particle({
    required this.start,
    required this.end,
    required this.size,
    required this.delay,
    required this.color,
  });
}

/// رسم‌کننده ذرات
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
    return oldDelegate.progress != progress;
  }
}

// ============================================================================
// نسخه ساده‌تر برای استفاده آسان - بدون نیاز به controller
// ============================================================================

/// انیمیشن حذف ساده که با flag کنترل می‌شود
class SimpleDeleteAnimation extends StatefulWidget {
  final Widget child;
  final bool isDeleting;
  final VoidCallback? onAnimationComplete;
  final Duration duration;
  final int particleCount;

  const SimpleDeleteAnimation({
    super.key,
    required this.child,
    this.isDeleting = false,
    this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 500),
    this.particleCount = 50,
  });

  @override
  State<SimpleDeleteAnimation> createState() => _SimpleDeleteAnimationState();
}

class _SimpleDeleteAnimationState extends State<SimpleDeleteAnimation> {
  final _controller = UniversalDeleteAnimationController();
  bool _hasStarted = false;

  @override
  void didUpdateWidget(SimpleDeleteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isDeleting && !oldWidget.isDeleting && !_hasStarted) {
      _hasStarted = true;
      _controller.startDeleteAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return UniversalDeleteAnimation(
      controller: _controller,
      onAnimationComplete: widget.onAnimationComplete,
      duration: widget.duration,
      particleCount: widget.particleCount,
      child: widget.child,
    );
  }
}






