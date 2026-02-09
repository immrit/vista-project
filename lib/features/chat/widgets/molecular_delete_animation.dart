import 'package:flutter/material.dart';

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
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  State<MolecularDeleteAnimation> createState() =>
      _MolecularDeleteAnimationState();
}

class _MolecularDeleteAnimationState extends State<MolecularDeleteAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _size;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );
    _size = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 1.0, curve: Curves.easeInCubic),
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.06, 0.0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
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
      _controller.forward(from: 0);
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
    if (!widget.isDeleting) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _size.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
