// lib/features/chat/widgets/message_delete_animation.dart
//
// انیمیشن حذف پیام به سبک تلگرام
//

import 'package:flutter/material.dart';

/// کنترلر انیمیشن حذف
class MessageDeleteAnimationController {
  _MessageDeleteAnimationState? _state;

  void attach(_MessageDeleteAnimationState state) {
    _state = state;
  }

  Future<void> startDeleteAnimation() async {
    if (_state != null) await _state!.animateOut();
  }
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

  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
    // Use _mainController as the single controller for a compact fade+shrink animation
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutQuad),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
  }

  Future<void> animateOut() async {
    if (!mounted) return;
    await _mainController.forward();
    widget.onAnimationComplete?.call();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_opacityAnimation),
      child: SizeTransition(
        sizeFactor:
            Tween<double>(begin: 1.0, end: 0.0).animate(_scaleAnimation),
        axisAlignment: 0.0,
        child: widget.child,
      ),
    );
  }
}
