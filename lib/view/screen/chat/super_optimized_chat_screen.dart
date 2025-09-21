import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../../model/message_model.dart';
import '../../../services/optimized_messaging_system.dart';
import '../../../services/ChatService.dart';
import '../../../provider/provider.dart';
import '../../../provider/optimized_chat_providers.dart';
import '../../../provider/advanced_chat_providers.dart';
import '../../../view/util/time_utils.dart';

/// ChatScreen بهینه‌شده برای عملکرد بالا
class SuperOptimizedChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const SuperOptimizedChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });

  @override
  ConsumerState<SuperOptimizedChatScreen> createState() =>
      _SuperOptimizedChatScreenState();
}

class _SuperOptimizedChatScreenState
    extends ConsumerState<SuperOptimizedChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ItemScrollController _scrollController = ItemScrollController();
  final FocusNode _focusNode = FocusNode();

  late final OptimizedMessagingSystem _messaging;
  late final ChatService _chatService;

  bool _isLoading = false;
  bool _isInitialized = false;
  Completer<void>? _initCompleter;

  @override
  void initState() {
    super.initState();
    _messaging = OptimizedMessagingSystem();
    _chatService = ChatService();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _messaging.removeRealtimeListener(widget.conversationId);
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<void>();
    setState(() => _isLoading = true);

    try {
      await _messaging.initialize();
      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
      _initCompleter!.complete();
    } catch (e) {
      setState(() => _isLoading = false);
      _initCompleter!.completeError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری چت: $e')),
        );
      }
    }

    return _initCompleter!.future;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    // Ensure messaging system is initialized
    if (!_isInitialized) {
      try {
        await _initializeChat();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در بارگذاری سیستم پیام‌رسانی')),
          );
        }
        return;
      }
    }

    // پاک کردن input
    _messageController.clear();

    // ایجاد پیام موقت
    final tempMessage = MessageModel.temporary(
      tempId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: currentUser['id'],
      content: content,
    );

    try {
      // استفاده از سیستم کش پیشرفته برای ارسال فوری
      final messageSender = ref.read(advancedMessageSenderProvider);
      await messageSender.sendMessage(
        conversationId: widget.conversationId,
        content: content,
        senderId: currentUser['id'],
      );

      // سیستم کش پیشرفته خودکار پیام را به سرور ارسال می‌کند
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال پیام: $e')),
        );
      }
    }
  }

  Widget _buildMessagesList() {
    return Consumer(
      builder: (context, ref, child) {
        final messagesAsync =
            ref.watch(advancedMessagesProvider(widget.conversationId));

        return messagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('خطا: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref
                      .refresh(advancedMessagesProvider(widget.conversationId)),
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
          data: (messages) {
            if (messages.isEmpty) {
              return const Center(
                child: Text(
                  'پیامی وجود ندارد. اولین پیام را ارسال کنید!',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            return ScrollablePositionedList.builder(
              itemScrollController: _scrollController,
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final previousMessage =
                    index < messages.length - 1 ? messages[index + 1] : null;

                return _buildMessageItem(message, previousMessage);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageItem(
      MessageModel message, MessageModel? previousMessage) {
    final currentUser = ref.read(currentUserProvider).value;
    final isMe = currentUser != null && message.senderId == currentUser['id'];

    // محاسبه فاصله و date divider
    final showDateDivider = TimeUtils.shouldShowDateDivider(
      message.createdAt,
      previousMessage?.createdAt,
    );

    final spacing = TimeUtils.calculateMessageSpacing(
      message.createdAt,
      previousMessage?.createdAt,
      message.senderId,
      previousMessage?.senderId,
    );

    return Column(
      children: [
        if (showDateDivider) _buildDateDivider(message.createdAt),
        Padding(
          padding: EdgeInsets.only(top: spacing),
          child: RepaintBoundary(
            child: MessageBubble(
              message: message,
              isMe: isMe,
              otherUserName: widget.otherUserName,
              showAvatar: !isMe,
              onDelete: () => _deleteMessage(message.id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text(
                TimeUtils.formatDateDivider(date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(String messageId) async {
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser == null) return;

    // Ensure messaging system is initialized
    if (!_isInitialized) {
      try {
        await _initializeChat();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خطا در بارگذاری سیستم پیام‌رسانی')),
          );
        }
        return;
      }
    }

    try {
      await _messaging.removeMessage(
          widget.conversationId, messageId, currentUser['id']);
      await _chatService.deleteMessage(messageId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف پیام: $e')),
        );
      }
    }
  }

  Widget _buildAppBar() {
    return AppBar(
      elevation: 1,
      backgroundColor: Theme.of(context).cardColor,
      title: Row(
        children: [
          if (widget.otherUserAvatar != null)
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.otherUserAvatar!),
            )
          else
            CircleAvatar(
              radius: 18,
              child: Text(widget.otherUserName.isNotEmpty
                  ? widget.otherUserName[0]
                  : 'U'),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final onlineStatus = ref.watch(
                        optimizedOnlineStatusProvider(widget.otherUserId));
                    return Text(
                      onlineStatus.when(
                        data: (isOnline) => isOnline ? 'آنلاین' : 'آفلاین',
                        loading: () => '...',
                        error: (_, __) => '',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline),
          onPressed: () {
            // نمایش جزئیات چت
          },
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'پیام بنویسید...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              onPressed: _sendMessage,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildInputArea(),
        ],
      ),
    );
  }
}

/// Simple MessageBubble widget for displaying messages
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String otherUserName;
  final bool showAvatar;
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.otherUserName,
    required this.showAvatar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 16,
              child: Text(otherUserName.isNotEmpty ? otherUserName[0] : 'U'),
            ),
          if (!isMe && showAvatar) const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? Theme.of(context).primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    TimeUtils.formatMessageTime(message.createdAt),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('حذف'),
                ),
              ],
              child: Icon(
                Icons.more_vert,
                size: 16,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }
}
