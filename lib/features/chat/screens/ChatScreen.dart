import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../model/message_model.dart';
import '../../../provider/chat_screen_provider.dart';
import '../../../features/chat/widgets/direct_chat_input.dart';
import '../../../features/chat/widgets/message_bubble.dart';
import 'ChatDetailsScreen.dart';

// Minimalist ChatScreen
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    this.otherUserAvatar,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  late final ChatScreenArgs _providerParams;

  @override
  void initState() {
    super.initState();
    _providerParams = ChatScreenArgs(
      conversationId: widget.conversationId,
      otherUserId: widget.otherUserId,
    );
    // Scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Logic to scroll can be added here if needed, usually ScrollablePositionedList with reverse:true handles bottom alignment well.
    });
  }

  void _showMessageActionsBottomSheet(
      BuildContext context, MessageModel message) {
    // Minimal options for now
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  ref
                      .read(chatScreenProvider(_providerParams).notifier)
                      .deleteMessage(message.id, forEveryone: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                // Copy logic
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendImageMessage(File file, String? caption) {
    ref
        .read(chatScreenProvider(_providerParams).notifier)
        .sendImageMessage(file, caption: caption);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversationId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Error: Invalid Conversation ID')),
      );
    }

    // Providers
    final chatState = ref.watch(chatScreenProvider(_providerParams));

    // Theme
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Solid background
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: widget.otherUserAvatar != null &&
                      widget.otherUserAvatar!.isNotEmpty
                  ? CachedNetworkImageProvider(widget.otherUserAvatar!)
                  : null,
              child: widget.otherUserAvatar == null ||
                      widget.otherUserAvatar!.isEmpty
                  ? Text(widget.otherUserName.substring(0, 1).toUpperCase())
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // if (_isOtherUserTyping) ... // Removed for simplicity/compilation safety
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailsScreen(
                    conversationId: widget.conversationId,
                    otherUserId: widget.otherUserId,
                    otherUserName: widget.otherUserName,
                    otherUserAvatar: widget.otherUserAvatar,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat List
          Expanded(
            child: chatState.isLoading && chatState.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemPositionsListener: _itemPositionsListener,
                    itemCount: chatState.messages.length,
                    reverse: true, // Important for chat
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      final isMe = message.isMe;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: MessageBubble(
                          message: message,
                          isMe: isMe,
                          onLongPress: (msg) {
                            _showMessageActionsBottomSheet(context, msg);
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Direct Input
          DirectChatInput(
            onSend: (text) {
              ref
                  .read(chatScreenProvider(_providerParams).notifier)
                  .sendMessage(text);
            },
            onAttachmentSelected: (file) {
              // Handle attachment
              if (file != null && file.path != null) {
                // For now treating as image for simplicity or generic file
                _sendImageMessage(File(file.path!), null);
              }
            },
            onRecordStart: () {
              // Start Recording logic
              debugPrint('Mic held');
            },
            onRecordEnd: () {
              // Stop Recording logic
              debugPrint('Mic released');
            },
          ),
        ],
      ),
    );
  }
}
