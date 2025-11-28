// lib/features/chat/widgets/typing_indicator_widget.dart
//
// ویجت نمایش "در حال نوشتن..." با انیمیشن
//
// ویژگی‌ها:
// ✅ انیمیشن نقاط متحرک
// ✅ طراحی زیبا مثل تلگرام
// ✅ قابل سفارشی‌سازی

import 'package:flutter/material.dart';

/// ویجت نمایش "در حال نوشتن..."
class TypingIndicatorWidget extends StatefulWidget {
  final String? userName;
  final Color? dotColor;
  final double dotSize;
  final Duration animationDuration;

  const TypingIndicatorWidget({
    super.key,
    this.userName,
    this.dotColor,
    this.dotSize = 8,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: widget.animationDuration,
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // شروع انیمیشن با تاخیر
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.dotColor ?? Colors.grey.shade500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar یا آیکون
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 18,
              color: Colors.grey.shade500,
            ),
          ),

          const SizedBox(width: 8),

          // حباب "در حال نوشتن..."
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // نقاط متحرک
                ...List.generate(3, (index) {
                  return AnimatedBuilder(
                    animation: _animations[index],
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _animations[index].value),
                        child: Container(
                          margin: EdgeInsets.only(
                            right: index < 2 ? 4 : 0,
                          ),
                          width: widget.dotSize,
                          height: widget.dotSize,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// نسخه ساده‌تر فقط با نقاط
class TypingDots extends StatefulWidget {
  final Color? color;
  final double size;

  const TypingDots({
    super.key,
    this.color,
    this.size = 6,
  });

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Colors.grey.shade500;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animation = Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  delay,
                  delay + 0.5,
                  curve: Curves.easeInOut,
                ),
              ),
            );

            return Container(
              margin: EdgeInsets.only(right: index < 2 ? 3 : 0),
              child: Opacity(
                opacity: 0.4 + (animation.value * 0.6),
                child: Transform.scale(
                  scale: 0.8 + (animation.value * 0.4),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// نمایش "در حال نوشتن..." در AppBar
class TypingStatusText extends StatelessWidget {
  final String? userName;
  final Color? textColor;

  const TypingStatusText({
    super.key,
    this.userName,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          userName != null ? '$userName در حال نوشتن' : 'در حال نوشتن',
          style: TextStyle(
            fontSize: 12,
            color: textColor ?? Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        TypingDots(
          color: textColor ?? Colors.green,
          size: 4,
        ),
      ],
    );
  }
}

