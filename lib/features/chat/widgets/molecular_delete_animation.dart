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
  AnimationController? _controller;
  Animation<double>? _fade;
  Animation<double>? _size;
  Animation<Offset>? _slide;

  void _setupAnimations() {
    final ctrl = AnimationController(duration: widget.duration, vsync: this);
    _fade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.0, 0.75, curve: Curves.easeOut)),
    );
    _size = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.12, 1.0, curve: Curves.easeInCubic)),
    );
    _slide = Tween<Offset>(begin: Offset.zero, end: const Offset(0.06, 0.0)).animate(
      CurvedAnimation(parent: ctrl, curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic)),
    );
    ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onAnimationComplete();
    });
    _controller = ctrl;
  }

  @override
  void initState() {
    super.initState();
    // Controller only created when actually deleting — skips 5 allocations per static row.
    if (widget.isDeleting) {
      _setupAnimations();
      _controller!.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant MolecularDeleteAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDeleting && !oldWidget.isDeleting) {
      _setupAnimations();
      _controller!.forward(from: 0);
    } else if (!widget.isDeleting && oldWidget.isDeleting) {
      _controller?.reset();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (!widget.isDeleting || ctrl == null) return widget.child;

    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, child) {
        return FadeTransition(
          opacity: _fade!,
          child: SlideTransition(
            position: _slide!,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: _size!.value,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
