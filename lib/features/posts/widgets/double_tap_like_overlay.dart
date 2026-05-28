// lib/features/posts/widgets/double_tap_like_overlay.dart
//
// انیمیشن قلب زمان double-tap (مشابه اینستاگرام)
//

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// یک wrapper که وقتی کاربر double-tap می‌کند، قلب انیمیشن‌دار نمایش می‌دهد
class DoubleTapLikeOverlay extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onDoubleTap;
  final VoidCallback? onTap;
  final bool isAlreadyLiked;

  const DoubleTapLikeOverlay({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.onTap,
    this.isAlreadyLiked = false,
  });

  @override
  State<DoubleTapLikeOverlay> createState() => _DoubleTapLikeOverlayState();
}

class _DoubleTapLikeOverlayState extends State<DoubleTapLikeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  Offset _tapPosition = Offset.zero;
  bool _showHeart = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3).chain(
          CurveTween(curve: Curves.easeOutBack),
        ),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.8).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 40,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: Curves.easeOut),
        ),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0).chain(
          CurveTween(curve: Curves.easeIn),
        ),
        weight: 30,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDoubleTap(TapDownDetails details) async {
    if (!widget.isAlreadyLiked) {
      // Haptic feedback
      HapticFeedback.mediumImpact();
    }

    setState(() {
      _tapPosition = details.localPosition;
      _showHeart = true;
    });

    _controller.reset();
    _controller.forward();

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 750), () {
      if (mounted) {
        setState(() => _showHeart = false);
      }
    });

    await widget.onDoubleTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTap,
      onDoubleTap: () {}, // needed to activate onDoubleTapDown
      onTap: widget.onTap,
      child: Stack(
        children: [
          widget.child,
          if (_showHeart)
            Positioned(
              left: _tapPosition.dx - 50,
              top: _tapPosition.dy - 50,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _opacityAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          alignment: Alignment.center,
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.heroGradient.createShader(bounds),
                            blendMode: BlendMode.srcIn,
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 80,
                              color: Colors.white, // masked by shader
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
