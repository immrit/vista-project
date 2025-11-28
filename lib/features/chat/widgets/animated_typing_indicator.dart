// lib/features/chat/widgets/animated_typing_indicator.dart
//
// نشانگر تایپ با انیمیشن حرفه‌ای
//

import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';

class AnimatedTypingIndicator extends StatefulWidget {
  final String? userName;
  final bool showBubble;
  
  const AnimatedTypingIndicator({
    super.key,
    this.userName,
    this.showBubble = true,
  });

  @override
  State<AnimatedTypingIndicator> createState() => _AnimatedTypingIndicatorState();
}

class _AnimatedTypingIndicatorState extends State<AnimatedTypingIndicator>
    with TickerProviderStateMixin {
  
  late AnimationController _dotController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // انیمیشن نقطه‌ها
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // انیمیشن ورود
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.5, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOut,
      ),
    );
    
    _slideController.forward();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.showBubble)
                _buildBubble(theme)
              else
                _buildDots(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(ChatTheme theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.otherBubbleColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        ),
        boxShadow: [
          if (theme.otherBubbleShadow != null) theme.otherBubbleShadow!,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.userName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.userName!,
                style: TextStyle(
                  color: theme.typingColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          _buildDots(theme),
        ],
      ),
    );
  }

  Widget _buildDots(ChatTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _dotController,
          builder: (context, child) {
            // محاسبه مقدار انیمیشن برای هر نقطه
            final progress = (_dotController.value * 3 - index).clamp(0.0, 1.0);
            final bounce = _calculateBounce(progress);
            
            return Container(
              margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
              child: Transform.translate(
                offset: Offset(0, -bounce * 6),
                child: _buildDot(theme, bounce),
              ),
            );
          },
        );
      }),
    );
  }

  double _calculateBounce(double progress) {
    if (progress < 0.5) {
      // رفتن بالا
      return Curves.easeOut.transform(progress * 2);
    } else {
      // برگشتن پایین
      return Curves.easeIn.transform((1 - progress) * 2);
    }
  }

  Widget _buildDot(ChatTheme theme, double bounce) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: theme.typingColor.withOpacity(0.5 + bounce * 0.5),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// نشانگر تایپ inline (برای استفاده در لیست)
class InlineTypingIndicator extends StatelessWidget {
  final String? userName;
  
  const InlineTypingIndicator({
    super.key,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniTypingDots(color: theme.typingColor),
        const SizedBox(width: 6),
        Text(
          userName != null ? '$userName در حال تایپ...' : 'در حال تایپ...',
          style: TextStyle(
            color: theme.typingColor,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// نقطه‌های کوچک تایپ
class _MiniTypingDots extends StatefulWidget {
  final Color color;
  
  const _MiniTypingDots({required this.color});

  @override
  State<_MiniTypingDots> createState() => _MiniTypingDotsState();
}

class _MiniTypingDotsState extends State<_MiniTypingDots>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final opacity = (((_controller.value + delay) % 1.0) < 0.5)
                ? 0.3 + (_controller.value + delay) % 0.5
                : 0.8 - ((_controller.value + delay) % 0.5);
            
            return Container(
              width: 4,
              height: 4,
              margin: EdgeInsets.only(right: index < 2 ? 2 : 0),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(opacity.clamp(0.3, 1.0)),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

