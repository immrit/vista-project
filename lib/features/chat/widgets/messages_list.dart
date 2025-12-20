// lib/features/chat/widgets/messages_list.dart
//
// لیست پیام‌ها با امکانات کامل
//
// ویژگی‌ها:
// ✅ نمایش تاریخ بین پیام‌ها
// ✅ Scroll to bottom button
// ✅ Loading indicator برای پیام‌های بیشتر
// ✅ Empty state

import 'package:flutter/material.dart';
import '../../../model/message_model.dart';
import 'message_bubble.dart';

class MessagesList extends StatefulWidget {
  final List<MessageModel> messages;
  final ScrollController scrollController;
  final Function(MessageModel) onMessageLongPress;
  final Function(MessageModel) onReply;
  final Function(MessageModel, String) onReaction;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final bool hasMore;

  const MessagesList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.onMessageLongPress,
    required this.onReply,
    required this.onReaction,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {
    // نمایش دکمه scroll to bottom
    final showButton = widget.scrollController.offset > 200;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }

    // Load more وقتی به بالا رسیدیم
    if (widget.hasMore &&
        !widget.isLoadingMore &&
        widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent - 100) {
      widget.onLoadMore?.call();
    }
  }

  void _scrollToBottom() {
    widget.scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // ═══════════════════════════════════════════════════════════════
        // لیست پیام‌ها
        // ═══════════════════════════════════════════════════════════════
        ListView.builder(
          controller: widget.scrollController,
          reverse: true, // جدیدترین پیام پایین
          padding: const EdgeInsets.all(16),
          itemCount: widget.messages.length + (widget.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            // Loading indicator در بالا
            if (widget.isLoadingMore && index == widget.messages.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final message = widget.messages[index];
            final previousMessage = index < widget.messages.length - 1
                ? widget.messages[index + 1]
                : null;
            final nextMessage = index > 0 ? widget.messages[index - 1] : null;

            // نمایش تاریخ اگه روز عوض شده
            final showDate = _shouldShowDate(message, previousMessage);

            return Column(
              children: [
                if (showDate) ...[
                  _buildDateDivider(message.createdAt),
                  const SizedBox(height: 16),
                ],
                MessageBubble(
                  message: message,
                  onLongPress: widget.onMessageLongPress,
                  onReply: widget.onReply,
                  previousMessage: previousMessage,
                  nextMessage: nextMessage,
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),

        // ═══════════════════════════════════════════════════════════════
        // دکمه Scroll to Bottom
        // ═══════════════════════════════════════════════════════════════
        if (_showScrollToBottom)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
            ),
          ),
      ],
    );
  }

  /// Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'هنوز پیامی ارسال نشده',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اولین پیام رو بفرست! 👋',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  /// چک کردن اینکه آیا باید تاریخ نمایش داده بشه
  bool _shouldShowDate(MessageModel message, MessageModel? previousMessage) {
    if (previousMessage == null) return true;

    final messageDate = DateTime(
      message.createdAt.year,
      message.createdAt.month,
      message.createdAt.day,
    );

    final previousDate = DateTime(
      previousMessage.createdAt.year,
      previousMessage.createdAt.month,
      previousMessage.createdAt.day,
    );

    return messageDate != previousDate;
  }

  /// ساخت Divider تاریخ
  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String label;
    if (messageDate == today) {
      label = 'امروز';
    } else if (messageDate == yesterday) {
      label = 'دیروز';
    } else {
      // تبدیل به تاریخ شمسی می‌تونه اضافه بشه
      label = '${date.year}/${date.month}/${date.day}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey.shade300),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}
