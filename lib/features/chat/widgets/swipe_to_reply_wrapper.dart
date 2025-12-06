// lib/features/chat/widgets/swipe_to_reply_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';

class SwipeToReplyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const SwipeToReplyWrapper({
    super.key,
    required this.child,
    required this.onReply,
    required this.isMe,
  });

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragOffset = 0.0;
  static const double _replyThreshold = 60.0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    double delta = details.primaryDelta ?? 0;
    if (_dragOffset + delta > 100 || _dragOffset + delta < -100) return;

    setState(() {
      _dragOffset += delta;
      final reached = _dragOffset.abs() > _replyThreshold;
      if (reached && !_thresholdReached) {
        HapticFeedback.lightImpact();
        _thresholdReached = true;
      } else if (!reached && _thresholdReached) {
        _thresholdReached = false;
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_thresholdReached) {
      widget.onReply();
      HapticFeedback.selectionClick();
    }

    setState(() {
      _dragOffset = 0.0;
      _thresholdReached = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (widget.isMe && details.primaryDelta! > 0) return;
        if (!widget.isMe && details.primaryDelta! < 0) return;
        _onHorizontalDragUpdate(details);
      },
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_dragOffset.abs() > 10)
            Positioned(
              right: widget.isMe ? 20 : null,
              left: !widget.isMe ? 20 : null,
              child: AnimatedScale(
                scale: _thresholdReached ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_thresholdReached)
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        )
                    ],
                  ),
                  child: Icon(
                    Icons.reply_rounded,
                    color:
                        _thresholdReached ? theme.sendButtonColor : Colors.grey,
                    size: 24,
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
