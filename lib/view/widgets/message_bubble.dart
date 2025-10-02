import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../../model/message_model.dart';
import 'audio_player_widget.dart';
import '../../../view/util/time_utils.dart';
import 'shared_post_card_widget.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final Function(MessageModel) onLongPress;
  final Function(MessageModel)? onReply;
  final Function(MessageModel)? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
    this.onReply,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  bool _isReplying = false;
  bool _isRetrying = false;
  late AnimationController _retryAnimationController;

  @override
  void initState() {
    super.initState();
    _retryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _retryAnimationController.dispose();
    super.dispose();
  }

  bool _isSharedPost(String content) {
    // بررسی ساده برای تشخیص پست اشتراکی
    return content.contains('📝 پست از') &&
        content.contains('🔗 مشاهده در Vista:');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = widget.message.isMe;
    final isLightMode = theme.brightness == Brightness.light;

    final outgoingBubbleColor =
        isLightMode ? const Color(0xFFE9F5FF) : const Color(0xFF3A3A3A);
    final incomingBubbleColor =
        isLightMode ? Colors.white : const Color(0xFF2C2C2C);
    final bool isImageOnly = widget.message.attachmentType == 'image' &&
        widget.message.content.isEmpty;

    return GestureDetector(
      onLongPress: () => widget.onLongPress(widget.message),
      onHorizontalDragUpdate: (details) {
        if (widget.onReply == null) return;

        const maxDragDistance = 80.0;
        final dragDistance = details.delta.dx.abs();
        final currentDragDistance = _isReplying
            ? maxDragDistance
            : dragDistance.clamp(0.0, maxDragDistance);
        final dragRatio = currentDragDistance / maxDragDistance;

        setState(() {
          _isReplying = dragRatio > 0.3;
        });

        if (dragRatio > 0.7) {
          HapticFeedback.lightImpact();
          widget.onReply!(widget.message);
        }
      },
      onHorizontalDragEnd: (details) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isReplying = false;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          _isReplying ? (isMe ? -20 : 20) : 0,
          0,
          0,
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            padding: const EdgeInsets.all(3),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: (isImageOnly || _isSharedPost(widget.message.content))
                  ? Colors.transparent
                  : (isMe ? outgoingBubbleColor : incomingBubbleColor),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: (isImageOnly || _isSharedPost(widget.message.content))
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.message.replyToMessageId != null)
                  _buildReplyPreview(context, widget.message),
                if (widget.message.attachmentUrl != null &&
                    !_isSharedPost(widget.message.content))
                  _buildAttachment(context, widget.message.attachmentType,
                      widget.message.attachmentUrl!),
                if (widget.message.content.isNotEmpty)
                  _isSharedPost(widget.message.content)
                      ? _buildSharedPostWidget()
                      : _buildMessageContent(context, widget.message, isMe),
                if (!isImageOnly || _isSharedPost(widget.message.content))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          TimeUtils.formatTime(widget.message.createdAt),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.6),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 5),
                          _buildStatusIcon(widget.message),
                        ],
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

  Widget _buildMessageContent(
      BuildContext context, MessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Text(
        message.content,
        style: TextStyle(
          fontSize: 16,
          height: 1.4,
          color: isMe
              ? Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87
              : Theme.of(context).textTheme.bodyLarge?.color,
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
      return AudioPlayerWidget(
        audioUrl: url,
        isMe: widget.message.isMe,
        waveformData: widget.message.waveformData,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReplyPreview(BuildContext context, MessageModel message) {
    // بررسی اینکه آیا پیام اصلی یک پست اشتراکی بوده یا نه
    final isReplyToSharedPost = message.replyToContent != null &&
        message.replyToContent!.contains('📝 پست از') &&
        message.replyToContent!.contains('🔗 مشاهده در Vista:');

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
          if (isReplyToSharedPost) ...[
            // برای پست‌های اشتراکی، نمایش کارت کوچک
            _buildSharedPostReplyPreview(message.replyToContent!),
          ] else ...[
            // برای پیام‌های عادی
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
        ],
      ),
    );
  }

  Widget _buildSharedPostReplyPreview(String replyContent) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // استخراج اطلاعات پست اشتراکی
    final username = _extractUsernameFromContent(replyContent);
    final postContent = _extractPostContentFromReply(replyContent);
    final avatarUrl = _extractAvatarUrlFromContent(replyContent);
    final verificationType = _extractVerificationTypeFromContent(replyContent);
    final hasImage = replyContent.contains('🖼️ تصویر ضمیمه شده');
    final hasVideo = replyContent.contains('🎥 ویدیو ضمیمه شده');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? theme.cardColor.withValues(alpha: 0.3)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر پست (نام کاربری و نشان تایید)
          Row(
            children: [
              // آواتار کوچک
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          username.isNotEmpty ? username[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              // نام کاربری
              Expanded(
                child: Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // نشان تایید
                    if (verificationType != 'none')
                      _buildVerificationBadge(verificationType, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // محتوای پست
          if (postContent.isNotEmpty)
            Text(
              postContent,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 4),
          // نوع رسانه
          if (hasImage || hasVideo)
            Row(
              children: [
                Icon(
                  hasVideo ? Icons.play_circle_outline : Icons.image,
                  size: 14,
                  color:
                      theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  hasVideo ? 'ویدیو' : 'تصویر',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color
                        ?.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _extractUsernameFromContent(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.contains('📝 پست از')) {
        final match = RegExp(r'📝 پست از (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? 'کاربر';
        }
      }
    }
    return 'کاربر';
  }

  String _extractPostContentFromReply(String content) {
    final lines = content.split('\n');
    final contentLines = <String>[];

    // پیدا کردن خط آواتار
    int avatarLineIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('🖼️ آواتار:')) {
        avatarLineIndex = i;
        break;
      }
    }

    // پیدا کردن محتوای پست بعد از آواتار
    for (int i = avatarLineIndex + 1; i < lines.length; i++) {
      final line = lines[i];

      // فیلتر کردن تمام لینک‌ها و metadata
      if (line.startsWith('🖼️') ||
          line.startsWith('🎥') ||
          line.startsWith('🏷️') ||
          line.startsWith('🔗') ||
          _containsUrl(line) ||
          _containsVistaLink(line)) {
        break;
      }

      // اگر خط خالی نیست و metadata نیست، احتمالاً محتوای پست است
      if (line.trim().isNotEmpty) {
        contentLines.add(line);
      }
    }

    return contentLines.join('\n').trim();
  }

  String? _extractAvatarUrlFromContent(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.contains('🖼️ آواتار:')) {
        final match = RegExp(r'🖼️ آواتار: (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1);
        }
      }
    }
    return null;
  }

  String _extractVerificationTypeFromContent(String content) {
    final lines = content.split('\n');
    for (final line in lines) {
      if (line.contains('✅ تایید:')) {
        final match = RegExp(r'✅ تایید: (.+)').firstMatch(line);
        if (match != null) {
          return match.group(1) ?? 'none';
        }
      }
    }
    return 'none';
  }

  Widget _buildVerificationBadge(String verificationType, double size) {
    IconData icon = Icons.verified;
    Color color = Colors.blue;

    switch (verificationType) {
      case 'blueTick':
        color = Colors.blue;
        break;
      case 'goldTick':
        color = Colors.amber;
        break;
      case 'blackTick':
        return Container(
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: Colors.white60,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.verified, color: Colors.black, size: size),
        );
      default:
        color = Colors.blue;
    }

    return Icon(icon, color: color, size: size);
  }

  bool _containsUrl(String text) {
    final urlRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)?[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
      caseSensitive: false,
    );
    return urlRegex.hasMatch(text);
  }

  bool _containsVistaLink(String text) {
    return text.contains('vista') ||
        text.contains('post/') ||
        text.contains('مشاهده در Vista');
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white)),
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

  Widget _buildStatusIcon(MessageModel message) {
    if (message.isPending) {
      return Icon(Icons.schedule, size: 14, color: Colors.grey.shade500);
    } else if (!message.isSent) {
      // برای پیام‌های ناموفق، دکمه retry نمایش داده می‌شود
      return _buildFailedMessageStatus(message);
    } else if (!message.isDelivered) {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    } else if (!message.isSeen) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    }
  }

  Widget _buildFailedMessageStatus(MessageModel message) {
    return GestureDetector(
      onTap: () => _onRetryMessage(message),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 14,
              color: Colors.red.shade600,
            ),
            const SizedBox(width: 4),
            _isRetrying
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                    ),
                  )
                : AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns:
                        message.retryCount * 0.1, // چرخش بر اساس تعداد تلاش‌ها
                    child: Icon(
                      Icons.refresh,
                      size: 12,
                      color: Colors.red.shade600,
                    ),
                  ),
            // نمایش تعداد تلاش‌های ناموفق (اختیاری)
            if (message.retryCount > 0) ...[
              const SizedBox(width: 2),
              Text(
                '${message.retryCount}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onRetryMessage(MessageModel message) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // شروع انیمیشن loading
    setState(() {
      _isRetrying = true;
    });

    // شروع انیمیشن چرخش
    _retryAnimationController.repeat();

    // فراخوانی retry از provider
    if (widget.onRetry != null) {
      widget.onRetry!(message);
    }

    // توقف انیمیشن بعد از 3 ثانیه
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
        _retryAnimationController.stop();
      }
    });
  }

  Widget _buildSharedPostWidget() {
    return SharedPostCardWidget(
      messageContent: widget.message.content,
      attachmentUrl: widget.message.attachmentUrl,
      attachmentType: widget.message.attachmentType,
    );
  }
}
