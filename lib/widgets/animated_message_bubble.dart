import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/message_model.dart';
import '../provider/chat_provider.dart';
import 'reactions/reaction_picker.dart';
import 'reactions/reaction_display.dart';

class AnimatedMessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final String currentUserId;
  final String conversationId;

  const AnimatedMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReply,
    this.onDelete,
    required this.currentUserId,
    required this.conversationId,
  });

  @override
  ConsumerState<AnimatedMessageBubble> createState() =>
      _AnimatedMessageBubbleState();
}

class _AnimatedMessageBubbleState extends ConsumerState<AnimatedMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _showActions = false;
  bool _showReactionPicker = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset(widget.isMe ? -0.15 : 0.15, 0),
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _handleSwipe(DragUpdateDetails details) {
    // فقط سوایپ افقی
    if (details.primaryDelta!.abs() > 10) {
      final delta =
          widget.isMe ? -details.primaryDelta! : details.primaryDelta!;

      if (delta > 0) {
        final progress = (delta / 100).clamp(0.0, 1.0);
        _slideController.value = progress;

        if (progress > 0.5 && !_showActions) {
          setState(() => _showActions = true);
          // ارتعاش
          HapticFeedback.lightImpact();
        }
      }
    }
  }

  void _handleSwipeEnd(DragEndDetails details) {
    if (_slideController.value > 0.5) {
      // انجام reply
      widget.onReply?.call();
      // ارتعاش قوی‌تر
      HapticFeedback.mediumImpact();
    }

    _slideController.reverse();
    setState(() => _showActions = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleSwipe,
      onHorizontalDragEnd: _handleSwipeEnd,
      onLongPress: () {
        setState(() => _showReactionPicker = true);
      },
      child: Stack(
        children: [
          // آیکون Reply
          if (_showActions)
            Positioned(
              left: widget.isMe ? null : 20,
              right: widget.isMe ? 20 : null,
              top: 0,
              bottom: 0,
              child: Icon(
                Icons.reply,
                color: Colors.blue.withOpacity(0.7),
                size: 24,
              ),
            ),

          // Message Bubble با انیمیشن
          SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: widget.isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildMessageContent(),

                // ✅ نمایش Reactions
                if (widget.message.reactions.isNotEmpty)
                  ReactionDisplay(
                    reactions: widget.message.reactions,
                    currentUserId: widget.currentUserId,
                    messageId: widget.message.id,
                    conversationId: widget.conversationId,
                    isMyMessage: widget.isMe,
                    onTap: () {
                      // TODO: نمایش BottomSheet با لیست کامل کسانی که reaction داده‌اند
                    },
                  ),
              ],
            ),
          ),

          // ✅ Reaction Picker
          if (_showReactionPicker)
            Positioned(
              top: -60,
              left: 0,
              right: 0,
              child: ReactionPicker(
                onReactionSelected: (emoji) async {
                  // ارسال reaction به سرور
                  await ref
                      .read(messageNotifierProvider.notifier)
                      .toggleReaction(
                        messageId: widget.message.id,
                        conversationId: widget.conversationId,
                        emoji: emoji,
                      );
                },
                onClose: () {
                  setState(() => _showReactionPicker = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    // پیام pending
    if (widget.message.isPending) {
      return _buildPendingMessage();
    }

    // پیام failed
    if (widget.message.isFailed ?? false) {
      return _buildFailedMessage();
    }

    // پیام عادی
    return _buildNormalMessage();
  }

  Widget _buildPendingMessage() {
    return Container(
      margin: EdgeInsets.only(
        left: widget.isMe ? 50 : 10,
        right: widget.isMe ? 10 : 50,
        top: 5,
        bottom: 5,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Colors.blue.shade100.withOpacity(0.5)
            : Colors.grey.shade200.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // محتوای پیام
          Text(
            widget.message.content,
            style: TextStyle(
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          // Loading Shimmer Effect
          Positioned.fill(
            child: _LoadingShimmer(),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedMessage() {
    return Container(
      margin: EdgeInsets.only(
        left: widget.isMe ? 50 : 10,
        right: widget.isMe ? 10 : 50,
        top: 5,
        bottom: 5,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              widget.message.content,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
        ],
      ),
    );
  }

  Widget _buildNormalMessage() {
    return Container(
      margin: EdgeInsets.only(
        left: widget.isMe ? 50 : 10,
        right: widget.isMe ? 10 : 50,
        top: 5,
        bottom: 5,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.blue.shade600 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        widget.message.content,
        style: TextStyle(
          color: widget.isMe ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

// Widget برای Shimmer Effect
class _LoadingShimmer extends StatefulWidget {
  @override
  _LoadingShimmerState createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.3),
                Colors.transparent,
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
        );
      },
    );
  }
}
