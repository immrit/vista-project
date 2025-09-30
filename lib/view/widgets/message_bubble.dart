import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../../model/message_model.dart';
import 'audio_player_widget.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final Function(MessageModel) onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = message.isMe;
    final isLightMode = theme.brightness == Brightness.light;

    final outgoingBubbleColor = isLightMode ? const Color(0xFFE9F5FF) : const Color(0xFF3A3A3A);
    final incomingBubbleColor = isLightMode ? Colors.white : const Color(0xFF2C2C2C);
    final bool isImageOnly = message.attachmentType == 'image' && message.content.isEmpty;

    return GestureDetector(
      onLongPress: () => onLongPress(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isImageOnly ? Colors.transparent : (isMe ? outgoingBubbleColor : incomingBubbleColor),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
             boxShadow: isImageOnly ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 5,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.replyToMessageId != null)
                _buildReplyPreview(context, message),
              if (message.attachmentUrl != null)
                _buildAttachment(context, message.attachmentType, message.attachmentUrl!),
              if (message.content.isNotEmpty)
                _buildMessageContent(context, message, isMe),
              if (!isImageOnly)
                 Padding(
                   padding: const EdgeInsets.only(top: 4, right: 8, bottom: 4),
                   child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 5),
                        _buildStatusIcon(message),
                      ],
                    ],
                                 ),
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, MessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
          color: isMe ? Colors.black87 : Theme.of(context).textTheme.bodyLarge?.color,
          ),
      ),
    );
  }

  Widget _buildAttachment(BuildContext context, String? type, String url) {
    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: GestureDetector(
          onTap: () => _showFullScreenImage(context, url),
          child: CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => const Icon(Icons.error),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    if (type == 'audio') {
      return AudioPlayerWidget(audioUrl: url, isMe: message.isMe);
    }
    return const SizedBox.shrink();
  }

  Widget _buildReplyPreview(BuildContext context, MessageModel message) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 8, right: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        border: Border(
          left: BorderSide(color: Colors.blue.shade300, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.replyToSenderName ?? 'کاربر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToContent ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(imageUrl),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildStatusIcon(MessageModel message) {
    if (message.isPending) {
      return Icon(Icons.schedule, size: 14, color: Colors.grey.shade500);
    } else if (!message.isSent) {
      return Icon(Icons.error_outline, size: 14, color: Colors.red.shade400);
    } else if (!message.isDelivered) {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    } else if (!message.isSeen) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
  }
}