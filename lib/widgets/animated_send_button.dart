import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedSendButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool enabled;

  const AnimatedSendButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (!widget.enabled) return;

    // انیمیشن فشرده شدن
    await _controller.forward();
    await _controller.reverse();

    // فراخوانی callback
    widget.onPressed();

    // ارتعاش
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: widget.enabled ? Colors.blue.shade600 : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: const Icon(
            Icons.send,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}













