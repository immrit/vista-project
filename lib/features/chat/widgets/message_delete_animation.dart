// lib/features/chat/widgets/message_delete_animation.dart
//
// انیمیشن حذف پیام به سبک تلگرام
//

import 'dart:math';
import 'package:flutter/material.dart';

/// کنترلر انیمیشن حذف
class MessageDeleteAnimationController {
  _MessageDeleteAnimationState? _state;

  void _attach(_MessageDeleteAnimationState state) {
    _state = state;
  }

  void _detach() {
    _state = null;
  }

  /// شروع انیمیشن حذف
  Future<void> startDeleteAnimation() async {
    await _state?.startAnimation();
  }

  /// آیا انیمیشن در حال اجراست؟
  bool get isAnimating => _state?._isAnimating ?? false;
}

/// ویجت انیمیشن حذف پیام با افکت پودر شدن
class MessageDeleteAnimation extends StatefulWidget {
  final Widget child;
  final MessageDeleteAnimationController? controller;
  final VoidCallback? onAnimationComplete;
  final Duration duration;

  const MessageDeleteAnimation({
    super.key,
    required this.child,
    this.controller,
    this.onAnimationComplete,
    this.duration = const Duration(milliseconds: 500),
  });

  @override
  State<MessageDeleteAnimation> createState() => _MessageDeleteAnimationState();
}

class _MessageDeleteAnimationState extends State<MessageDeleteAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _particleController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _particleAnimation;

  bool _isAnimating = false;
  bool _showParticles = false;
  List<_Particle> _particles = [];
  Size? _widgetSize;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeInBack,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.easeIn,
      ),
    );

    _particleAnimation = CurvedAnimation(
      parent: _particleController,
      curve: Curves.easeOut,
    );

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onAnimationComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    widget.controller?._detach();
    _mainController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  /// شروع انیمیشن
  Future<void> startAnimation() async {
    if (_isAnimating) return;

    setState(() {
      _isAnimating = true;
    });

    // تولید ذرات
    _generateParticles();
    setState(() {
      _showParticles = true;
    });

    // شروع انیمیشن ذرات و کوچک شدن همزمان
    _particleController.forward();
    await _mainController.forward();
  }

  void _generateParticles() {
    final random = Random();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    _widgetSize = box.size;

    final width = _widgetSize!.width;
    final height = _widgetSize!.height;

    _particles = List.generate(40, (index) {
      final startX = random.nextDouble() * width;
      final startY = random.nextDouble() * height;

      // جهت پراکندگی - به سمت بیرون و بالا
      final angle = random.nextDouble() * 2 * pi;
      final distance = 30 + random.nextDouble() * 80;

      return _Particle(
        startX: startX,
        startY: startY,
        endX: startX + cos(angle) * distance,
        endY: startY + sin(angle) * distance - 40, // بیشتر به بالا
        size: 3 + random.nextDouble() * 5,
        delay: random.nextDouble() * 0.2,
        color: Colors.grey.shade400,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ویجت اصلی با انیمیشن
        AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return Transform.scale(
              scale: _isAnimating ? _scaleAnimation.value : 1.0,
              child: Opacity(
                opacity: _isAnimating ? _opacityAnimation.value : 1.0,
                child: child,
              ),
            );
          },
          child: widget.child,
        ),

        // ذرات (روی ویجت اصلی)
        if (_showParticles && _widgetSize != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _particleAnimation,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ParticlePainter(
                      particles: _particles,
                      progress: _particleAnimation.value,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// مدل ذره
class _Particle {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final double delay;
  final Color color;

  _Particle({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.delay,
    required this.color,
  });
}

/// نقاش ذرات
class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({
    required this.particles,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      // محاسبه پیشرفت با تأخیر
      final particleProgress =
          ((progress - particle.delay) / (1 - particle.delay)).clamp(0.0, 1.0);

      if (particleProgress <= 0) continue;

      // موقعیت فعلی
      final currentX = particle.startX +
          (particle.endX - particle.startX) * particleProgress;
      final currentY = particle.startY +
          (particle.endY - particle.startY) * particleProgress;

      // شفافیت (محو شدن)
      final opacity = (1 - particleProgress).clamp(0.0, 1.0);

      // اندازه (کوچک شدن)
      final currentSize = particle.size * (1 - particleProgress * 0.5);

      paint.color = particle.color.withOpacity(opacity * 0.8);

      canvas.drawCircle(
        Offset(currentX, currentY),
        currentSize,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
