import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

import '../../../model/message_model.dart';
import 'package:Vista/utils/time_utils.dart'; // Ensure this matches project structure

class MessageBubble extends ConsumerWidget {
  final MessageModel message;
  final bool isMe;
  final MessageModel? previousMessage;
  final MessageModel? nextMessage;
  final Function(MessageModel)? onLongPress;
  final Function(MessageModel)? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe, // Simplified: pass isMe directly or derive from message
    this.previousMessage,
    this.nextMessage,
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Radius constants
    const double kBubbleRadius = 22.0;
    const double kSharpRadius = 4.0;

    // Determine Border Radius based on isMe
    final BorderRadius borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(kBubbleRadius),
      topRight: const Radius.circular(kBubbleRadius),
      bottomLeft: Radius.circular(isMe ? kBubbleRadius : kSharpRadius),
      bottomRight: Radius.circular(isMe ? kSharpRadius : kBubbleRadius),
    );

    // Color Logic
    // My Message: Primary Color
    // Other Message: Card Color or slight grey
    final Color bubbleColor = isMe
        ? theme.primaryColor
        : (isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF));

    final Color textColor =
        isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);

    final Color timestampColor = isMe
        ? Colors.white.withOpacity(0.7)
        : (isDark ? Colors.grey[400]! : Colors.grey[600]!);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 2), // Compact vertical spacing
        child: InkWell(
          onLongPress: onLongPress != null ? () => onLongPress!(message) : null,
          onTap: onTap != null ? () => onTap!(message) : null,
          borderRadius: borderRadius,
          child: Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * 0.75, // Max 75% width
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 10,
                      bottom: 24 // Space for timestamp
                      ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Content
                      _buildContent(context, textColor),
                    ],
                  ),
                ),

                // Timestamp Overlay
                Positioned(
                  bottom: 6,
                  right: isMe ? 8 : null, // Align rigth for Me
                  left: isMe
                      ? null
                      : 8, // Align left for Others (or keep both right if preferred)
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        TimeUtils.formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: timestampColor,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        // Simple checkmark logic (can be expanded)
                        Icon(
                          message.isSeen ? Icons.done_all : Icons.check,
                          size: 12,
                          color: timestampColor,
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    // 1. Image
    if (message.attachmentType == 'image' ||
        (message.localImagePath != null &&
            message.localImagePath!.isNotEmpty)) {
      return _buildImage(context);
    }

    // 2. Text
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 16,
        color: textColor,
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    // Simplified Image Logic (Local > Network)
    bool hasLocal = message.localImagePath != null &&
        File(message.localImagePath!).existsSync();

    Widget imageWidget;
    if (hasLocal) {
      imageWidget =
          Image.file(File(message.localImagePath!), fit: BoxFit.cover);
    } else if (message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: message.attachmentUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: Colors.grey[300]),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
      );
    } else {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: imageWidget,
    );
  }
}
