import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool isMe;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.isMe = false,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0;
  final double _triggerThreshold = 60.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.isMe) {
      // My messages swipe left to reply
      if (details.primaryDelta! > 0 && _dragExtent == 0)
        return; // Prevent right swipe
      _dragExtent += details.primaryDelta!;
      if (_dragExtent > 0) _dragExtent = 0; // Cap at 0

      if (_dragExtent < -_triggerThreshold && !_triggered) {
        _triggered = true;
        HapticFeedback.lightImpact();
        widget.onReply();
      }
    } else {
      // Other messages swipe right to reply
      if (details.primaryDelta! < 0 && _dragExtent == 0)
        return; // Prevent left swipe
      _dragExtent += details.primaryDelta!;
      if (_dragExtent < 0) _dragExtent = 0; // Cap at 0

      if (_dragExtent > _triggerThreshold && !_triggered) {
        _triggered = true;
        HapticFeedback.lightImpact();
        widget.onReply();
      }
    }

    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _triggered = false;
    _controller.forward(from: 0.0).then((_) {
      setState(() {
        _dragExtent = 0;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final offset = _dragExtent * (1 - _controller.value);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (offset.abs() > 10)
                  Positioned(
                    right: widget.isMe ? -40 - (offset.abs() * 0.1) : null,
                    left: !widget.isMe ? -40 - (offset.abs() * 0.1) : null,
                    child: Opacity(
                      opacity:
                          (offset.abs() / _triggerThreshold).clamp(0.0, 1.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply_rounded,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                widget.child,
              ],
            ),
          );
        },
      ),
    );
  }
}
