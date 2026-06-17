// lib/features/chat/widgets/swipe_to_reply_wrapper.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/chat_theme.dart';

/// Swipe-to-reply that does not compete with vertical list scrolling.
///
/// Uses [Listener] instead of horizontal drag gestures so the scroll view
/// keeps ownership of vertical movement immediately.
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

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper> {
  double _dragOffset = 0.0;
  static const double _replyThreshold = 60.0;
  bool _thresholdReached = false;
  bool _isDraggingHorizontally = false;

  bool _bubbleOnRight(BuildContext context) {
    return widget.isMe;
  }

  bool _isAllowedHorizontalDelta(bool bubbleOnRight, double delta) {
    if (bubbleOnRight) return delta < 0;
    return delta > 0;
  }

  void _resetDrag() {
    if (_dragOffset == 0.0 && !_thresholdReached && !_isDraggingHorizontally) {
      return;
    }
    setState(() {
      _dragOffset = 0.0;
      _thresholdReached = false;
      _isDraggingHorizontally = false;
    });
  }

  void _applyHorizontalDelta(double delta) {
    final nextOffset = (_dragOffset + delta).clamp(-100.0, 100.0);
    if ((nextOffset - _dragOffset).abs() < 0.5) return;

    final reached = nextOffset.abs() > _replyThreshold;
    if (reached && !_thresholdReached) {
      HapticFeedback.lightImpact();
    }

    setState(() {
      _dragOffset = nextOffset;
      _thresholdReached = reached;
    });
  }

  void _onPointerMove(PointerMoveEvent event, bool bubbleOnRight) {
    final dx = event.delta.dx;
    final dy = event.delta.dy;

    if (!_isDraggingHorizontally) {
      if (dx.abs() <= dy.abs() * 1.15 || dx.abs() < 2.0) return;
      if (!_isAllowedHorizontalDelta(bubbleOnRight, dx)) return;
      _isDraggingHorizontally = true;
    }

    if (!_isAllowedHorizontalDelta(bubbleOnRight, dx)) return;
    _applyHorizontalDelta(dx);
  }

  void _onPointerEnd() {
    if (_isDraggingHorizontally && _thresholdReached) {
      widget.onReply();
      HapticFeedback.selectionClick();
    }
    _resetDrag();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;
    final bubbleOnRight = _bubbleOnRight(context);

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerMove: (event) => _onPointerMove(event, bubbleOnRight),
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      child: Stack(
        children: [
          // SizedBox.expand gives the Column tight screen-width constraints so
          // crossAxisAlignment.end in _buildBubbleBody anchors the bubble to the
          // correct screen edge instead of centering it.
          SizedBox(
            width: double.infinity,
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: widget.child,
            ),
          ),
          if (_dragOffset.abs() > 10)
            Positioned(
              right: bubbleOnRight ? 20 : null,
              left: bubbleOnRight ? null : 20,
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
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
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
        ],
      ),
    );
  }
}
