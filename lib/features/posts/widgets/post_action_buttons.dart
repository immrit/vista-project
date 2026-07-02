import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared action buttons for post cards (used in For You / Following / Public).
///
/// Goal: consistent behavior and always-visible counts (including 0),
/// with a lightweight, Social-like visual density.
String _formatCount(int count) {
  if (count < 1000) return '$count';
  if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
  return '${(count / 1000000).toStringAsFixed(1)}M';
}

class PostLikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final VoidCallback onTap;
  final double iconSize;
  final double gap;
  final TextStyle? countStyle;
  final bool showCount;

  const PostLikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
    this.iconSize = 20,
    this.gap = 4,
    this.countStyle,
    this.showCount = true,
  });

  @override
  State<PostLikeButton> createState() => _PostLikeButtonState();
}

class _PostLikeButtonState extends State<PostLikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant PostLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked && widget.isLiked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white70 : Colors.black87;
    final countStyle = widget.countStyle ??
        TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.white70 : Colors.black54,
        );

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
        if (!widget.isLiked) {
          _controller.forward().then((_) => _controller.reverse());
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Icon(
                widget.isLiked ? Icons.favorite_rounded : Icons.favorite_border,
                color: widget.isLiked ? Colors.red : baseColor,
                size: widget.iconSize,
              ),
            ),
            if (widget.showCount) ...[
              SizedBox(width: widget.gap),
              Text(_formatCount(widget.likeCount), style: countStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class PostCommentButton extends StatelessWidget {
  final int commentCount;
  final VoidCallback onTap;
  final double iconSize;
  final double gap;
  final TextStyle? countStyle;
  final bool showCount;

  const PostCommentButton({
    super.key,
    required this.commentCount,
    required this.onTap,
    this.iconSize = 20,
    this.gap = 4,
    this.countStyle,
    this.showCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white70 : Colors.black54;
    final countStyle = this.countStyle ??
        TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.white70 : Colors.black54,
        );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'lib/utils/images/component/comment.png',
              width: iconSize,
              height: iconSize,
              color: baseColor,
              filterQuality: FilterQuality.medium,
            ),
            if (showCount) ...[
              SizedBox(width: gap),
              Text(_formatCount(commentCount), style: countStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class PostSaveButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTap;
  final double iconSize;
  final Color? activeColor;

  const PostSaveButton({
    super.key,
    required this.isSaved,
    required this.onTap,
    this.iconSize = 20,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white70 : Colors.black54;
    final savedColor = activeColor ?? Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        child: Icon(
          isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: iconSize,
          color: isSaved ? savedColor : baseColor,
        ),
      ),
    );
  }
}
