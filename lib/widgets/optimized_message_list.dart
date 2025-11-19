import 'package:flutter/material.dart';
import '../model/message_model.dart';
import 'modern_message_bubble.dart';

/// ✅ Optimized Message List - الهام‌گرفته از تلگرام
/// با Pre-caching و RepaintBoundary برای performance بهتر
class OptimizedMessageList extends StatefulWidget {
  final List<MessageModel> messages;
  final String currentUserId;
  final Function(MessageModel)? onMessageTap;
  final ScrollController? scrollController;
  final Function()? onLoadMore;

  const OptimizedMessageList({
    super.key,
    required this.messages,
    required this.currentUserId,
    this.onMessageTap,
    this.scrollController,
    this.onLoadMore,
  });

  @override
  State<OptimizedMessageList> createState() => _OptimizedMessageListState();
}

class _OptimizedMessageListState extends State<OptimizedMessageList>
    with AutomaticKeepAliveClientMixin {
  late final ScrollController _scrollController;
  bool _isScrolling = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();

    // ✅ Listen to scroll events برای load more
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when 80% scrolled
      widget.onLoadMore?.call();
    }

    // Track scrolling state
    final isScrolling = _scrollController.position.isScrollingNotifier.value;
    if (isScrolling != _isScrolling) {
      setState(() {
        _isScrolling = isScrolling;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return ListView.custom(
      controller: _scrollController,
      reverse: true,

      // ✅ Pre-caching - الهام‌گرفته از تلگرام
      // 3 برابر ارتفاع viewport را cache می‌کند
      cacheExtent: MediaQuery.of(context).size.height * 3,

      childrenDelegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= widget.messages.length) return null;

          final message = widget.messages[index];
          final isMe = message.senderId == widget.currentUserId;

          return _MessageItem(
            key: ValueKey(message.id),
            message: message,
            isMe: isMe,
            onTap: widget.onMessageTap != null
                ? () => widget.onMessageTap!(message)
                : null,
          );
        },
        childCount: widget.messages.length,

        // ✅ تخمین سایز برای بهبود performance
        findChildIndexCallback: (Key key) {
          final valueKey = key as ValueKey<String>;
          final index = widget.messages.indexWhere(
            (m) => m.id == valueKey.value,
          );
          return index >= 0 ? index : null;
        },
      ),
    );
  }

  @override
  void dispose() {
    if (widget.scrollController == null) {
      _scrollController.dispose();
    } else {
      _scrollController.removeListener(_onScroll);
    }
    super.dispose();
  }
}

/// ✅ Message Item با RepaintBoundary
class _MessageItem extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final VoidCallback? onTap;

  const _MessageItem({
    super.key,
    required this.message,
    required this.isMe,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: onTap,
            child: ModernMessageBubble(
              message: message,
              isMe: isMe,
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}
