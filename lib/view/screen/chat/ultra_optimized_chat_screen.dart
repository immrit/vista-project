import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../provider/ultra_optimized_chat_provider.dart';
import '../../../widgets/keyboard_aware_text_field.dart';
import '../../../main.dart';
import '../../../provider/chat_provider.dart';
import '../../../model/message_model.dart';

/// ✅ Ultra Optimized Chat Screen
/// با Deferred Initialization Pattern برای باز شدن سریع کیبورد
class UltraOptimizedChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;

  const UltraOptimizedChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  ConsumerState<UltraOptimizedChatScreen> createState() =>
      _UltraOptimizedChatScreenState();
}

class _UltraOptimizedChatScreenState
    extends ConsumerState<UltraOptimizedChatScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(
      ultraOptimizedChatProvider({
        'conversationId': widget.conversationId,
        'otherUserId': widget.otherUserId,
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Message List - بدون هیچ wrapper اضافی
          Expanded(
            child: chatState.messages.isEmpty
                ? const Center(
                    child: Text(
                      'هنوز پیامی وجود ندارد',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: chatState.messages.length,
                    // ✅ Pre-cache زیاد - 4 برابر ارتفاع viewport
                    cacheExtent: MediaQuery.of(context).size.height * 4,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final currentUserId = supabase.auth.currentUser?.id;
                      final isMe = currentUserId != null &&
                          message.senderId == currentUserId;

                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
          ),

          // ✅ Keyboard-Aware Input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: () {
                      // Handle attachment
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KeyboardAwareTextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      hintText: 'پیام خود را بنویسید...',
                      maxLines: null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).primaryColor,
                    onPressed: () {
                      final text = _controller.text.trim();
                      if (text.isNotEmpty) {
                        ref
                            .read(ultraOptimizedChatProvider({
                              'conversationId': widget.conversationId,
                              'otherUserId': widget.otherUserId,
                            }).notifier)
                            .sendMessage(content: text);
                        _controller.clear();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    final userAsync = ref.watch(userProfileDetailsProvider(widget.otherUserId));

    return userAsync.when(
      data: (user) {
        if (user == null) return const Text('...');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user['username'] ?? 'کاربر',
              style: const TextStyle(fontSize: 16),
            ),
            _buildOnlineStatus(),
          ],
        );
      },
      loading: () => const Text('...'),
      error: (_, __) => const Text('خطا'),
    );
  }

  Widget _buildOnlineStatus() {
    final onlineAsync = ref.watch(
      userOnlineStatusStreamProvider(widget.otherUserId),
    );

    return onlineAsync.when(
      data: (isOnline) {
        return Text(
          isOnline ? 'آنلاین' : 'آفلاین',
          style: TextStyle(
            fontSize: 12,
            color: isOnline ? Colors.green : Colors.grey,
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// ✅ Message Bubble - ساده و سریع
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToMessageId != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isMe
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToSenderName != null)
                      Text(
                        message.replyToSenderName!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : Colors.blue,
                        ),
                      ),
                    if (message.replyToContent != null)
                      Text(
                        message.replyToContent!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: isMe ? Colors.white70 : Colors.black54,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isSeen
                        ? Icons.done_all
                        : message.isDelivered
                            ? Icons.done_all
                            : Icons.done,
                    size: 14,
                    color: message.isSeen
                        ? Colors.blue
                        : message.isDelivered
                            ? Colors.white70
                            : Colors.white54,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

