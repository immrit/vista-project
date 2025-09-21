import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'dart:math' as math;
import '../../../model/message_model.dart';
import '../../util/widgets.dart';
import '../../widgets/audio_player_widget.dart';

/// Widget بهینه‌شده برای نمایش پیام‌ها - کاهش rebuilds و بهبود performance
class OptimizedMessageWidget extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  final double fontSize;
  final String? highlightedMessageId;
  final Map<String, bool> messageReplyStates;
  final Set<String> inlineImageGrants;
  final Set<String> inlineImageLoaded;
  final Map<String, double> inlineImageProgress;
  final Function(MessageModel) onSetReply;
  final Function(MessageModel, bool) onShowOptions;
  final Function(String) onShowFullScreenImage;
  final Function(MessageModel) onTapMessage;

  const OptimizedMessageWidget({
    super.key,
    required this.message,
    required this.isMe,
    required this.fontSize,
    this.highlightedMessageId,
    required this.messageReplyStates,
    required this.inlineImageGrants,
    required this.inlineImageLoaded,
    required this.inlineImageProgress,
    required this.onSetReply,
    required this.onShowOptions,
    required this.onShowFullScreenImage,
    required this.onTapMessage,
  });

  @override
  State<OptimizedMessageWidget> createState() => _OptimizedMessageWidgetState();
}

class _OptimizedMessageWidgetState extends State<OptimizedMessageWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  // Cache expensive calculations
  late final bool _isImageAttachment;
  late final bool _isAudioAttachment;
  late final bool _isImageOnly;
  late final bool _isTemp;
  late final Color _bubbleColor;
  late final Color _textColor;
  late final Color _timeColor;
  late final BorderRadius _borderRadius;
  late final String _formattedTime;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      duration: Duration(
          milliseconds: widget.message.id.startsWith('temp_') ? 150 : 300),
      vsync: this,
    );

    // Setup animations
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: Offset(widget.isMe ? 50 : -50, 10),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Cache calculations
    _precalculateValues();

    // Start animation
    _animationController.forward();
  }

  void _precalculateValues() {
    final message = widget.message;
    final context = this.context;
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    _isImageAttachment = message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty &&
        message.attachmentType == 'image';

    _isAudioAttachment = message.attachmentUrl != null &&
        message.attachmentUrl!.isNotEmpty &&
        message.attachmentType == 'audio';

    _isImageOnly = _isImageAttachment && message.content.isEmpty;
    _isTemp = !message.isSent && message.id.startsWith('temp_');

    // Colors
    _bubbleColor = widget.isMe
        ? (isLightMode ? const Color(0xFF323232) : const Color(0xFF2A2A2A))
        : (isLightMode ? Colors.white : Colors.grey.shade800);

    _textColor = widget.isMe
        ? Colors.white
        : (isLightMode ? Colors.black87 : Colors.white);
    _timeColor = widget.isMe
        ? Colors.white70
        : (isLightMode ? Colors.black54 : Colors.white70);

    // Border radius
    final baseRadius = math.max(18.0, widget.fontSize * 1.3);
    final tailSmallRadius = math.max(3.0, widget.fontSize * 0.22);
    final tailLargeRadius = math.max(22.0, widget.fontSize * 1.6);

    _borderRadius = BorderRadius.only(
      topLeft: Radius.circular(baseRadius),
      topRight: Radius.circular(baseRadius),
      bottomLeft:
          Radius.circular(widget.isMe ? tailLargeRadius : tailSmallRadius),
      bottomRight:
          Radius.circular(widget.isMe ? tailSmallRadius : tailLargeRadius),
    );

    // Formatted time
    _formattedTime = _formatMessageHour(message.createdAt);
  }

  String _formatMessageHour(DateTime time) {
    final tehranOffset = const Duration(hours: 3, minutes: 30);
    final tehranTime = time.toUtc().add(tehranOffset);
    return '${tehranTime.hour.toString().padLeft(2, '0')}:${tehranTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isHighlighted = widget.highlightedMessageId == message.id;
    final isReplyState = widget.messageReplyStates[message.id] == true;
    final opacity = _isTemp ? 0.6 : 1.0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _slideAnimation.value.dx * (1 - _animationController.value),
            _slideAnimation.value.dy * (1 - _animationController.value),
          ),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value * opacity,
              child: _buildMessageContent(isHighlighted, isReplyState),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(bool isHighlighted, bool isReplyState) {
    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          isReplyState ? (widget.isMe ? -40 : 40) : 0,
          0,
          0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: GestureDetector(
            onLongPress: () =>
                widget.onShowOptions(widget.message, widget.isMe),
            onTap: () => widget.onTapMessage(widget.message),
            child: _buildMessageBubble(),
          ),
        ),
      ),
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // Handle reply drag gesture
    final dragDirection = widget.isMe ? -details.delta.dx : details.delta.dx;
    if (dragDirection > 0) {
      final dragDistance = details.globalPosition.dx;
      final screenWidth = MediaQuery.of(context).size.width;
      final maxDragDistance = screenWidth * 0.3;
      final currentDragDistance = widget.isMe
          ? (screenWidth - dragDistance).clamp(0.0, maxDragDistance)
          : dragDistance.clamp(0.0, maxDragDistance);

      final dragRatio = currentDragDistance / maxDragDistance;
      if (dragRatio > 0.4) {
        widget.onSetReply(widget.message);
      }
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    // Handle drag end
  }

  Widget _buildMessageBubble() {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: math.max(12, widget.fontSize * 0.6),
            vertical: math.max(2, widget.fontSize * 0.15),
          ),
          decoration: BoxDecoration(
            color: _isImageOnly ? Colors.transparent : _bubbleColor,
            border: !widget.isMe && !_isImageOnly
                ? Border.all(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey[200]!
                        : Colors.transparent,
                    width: 1,
                  )
                : null,
            borderRadius: _borderRadius,
          ),
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.message.replyToMessageId != null) _buildReplyWidget(),
              if (_isImageAttachment || _isAudioAttachment)
                _buildAttachmentWidget(),
              if (widget.message.content.isNotEmpty) _buildTextContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyWidget() {
    return Container(
      padding: EdgeInsets.all(math.max(8, widget.fontSize * 0.5)),
      margin: EdgeInsets.only(
        bottom: math.max(6, widget.fontSize * 0.35),
        left: math.max(8, widget.fontSize * 0.5),
        right: math.max(8, widget.fontSize * 0.5),
      ),
      decoration: BoxDecoration(
        color: widget.isMe ? _bubbleColor.withOpacity(0.8) : Colors.grey[100],
        borderRadius:
            BorderRadius.circular(math.max(12, widget.fontSize * 0.7)),
        border: Border.all(
          color:
              widget.isMe ? Colors.white.withOpacity(0.2) : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.reply,
                  size: 14,
                  color: widget.isMe ? Colors.white70 : Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.message.replyToSenderName ?? 'کاربر',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isMe ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.message.replyToContent ?? '',
            style: TextStyle(
              color: widget.isMe ? Colors.white70 : Colors.black87,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentWidget() {
    if (_isAudioAttachment) {
      return Padding(
        padding: const EdgeInsets.only(top: 0.0),
        child: AudioPlayerWidget(
          audioUrl: widget.message.attachmentUrl!,
          isMe: widget.isMe,
        ),
      );
    } else if (_isImageAttachment) {
      return _buildImageWidget();
    }
    return const SizedBox.shrink();
  }

  Widget _buildImageWidget() {
    final url = widget.message.attachmentUrl!;

    if (url.startsWith('/') && File(url).existsSync()) {
      // Local image
      return GestureDetector(
        onTap: () => widget.onShowFullScreenImage(url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(url),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Container(
              constraints: const BoxConstraints(
                maxWidth: 260,
                maxHeight: 320,
              ),
              color: Colors.grey[300],
              child:
                  const Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          ),
        ),
      );
    } else if (url.startsWith('http')) {
      // Network image with auto-download settings
      return _buildNetworkImage(url);
    }

    return const SizedBox.shrink();
  }

  Widget _buildNetworkImage(String url) {
    final shouldInlineLoad =
        widget.inlineImageGrants.contains(widget.message.id);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 260,
          maxHeight: 320,
        ),
        child: shouldInlineLoad
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                progressIndicatorBuilder: (context, url, progress) {
                  final p = progress.progress ?? 0.0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(color: Colors.grey[300]),
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(value: p),
                      ),
                    ],
                  );
                },
                imageBuilder: (context, provider) {
                  return GestureDetector(
                    onTap: () => widget.onShowFullScreenImage(url),
                    child: Image(
                      image: provider,
                      fit: BoxFit.contain,
                    ),
                  );
                },
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image,
                      size: 40, color: Colors.grey),
                ),
              )
            : _buildImagePlaceholder(url),
      ),
    );
  }

  Widget _buildImagePlaceholder(String url) {
    return GestureDetector(
      onTap: () {
        // Grant inline loading permission
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.grey[300]),
          const Center(
            child: Icon(
              Icons.download_rounded,
              size: 40,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent() {
    return Padding(
      padding: EdgeInsets.only(
        top: (_isImageAttachment || _isAudioAttachment)
            ? math.max(4, widget.fontSize * 0.25)
            : math.max(12, widget.fontSize * 0.75),
        left: math.max(12, widget.fontSize * 0.75),
        right: math.max(12, widget.fontSize * 0.75),
        bottom: math.max(12, widget.fontSize * 0.75),
      ),
      child: Column(
        crossAxisAlignment:
            widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.message.content.isNotEmpty)
            Directionality(
              textDirection: getTextDirection(widget.message.content),
              child: Text(
                widget.message.content,
                style: TextStyle(
                  color: _textColor,
                  fontSize: widget.fontSize,
                  height: 1.3,
                ),
              ),
            ),
          if (!_isImageOnly)
            Padding(
              padding: EdgeInsets.only(top: math.max(6, widget.fontSize * 0.3)),
              child: _buildTimeAndStatus(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeAndStatus() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: math.max(8, widget.fontSize * 0.5),
            vertical: math.max(3, widget.fontSize * 0.2),
          ),
          decoration: BoxDecoration(
            color: widget.isMe
                ? Colors.black.withOpacity(0.15)
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withOpacity(0.7),
            borderRadius:
                BorderRadius.circular(math.max(12, widget.fontSize * 0.8)),
          ),
          child: Text(
            _formattedTime,
            style: TextStyle(
              fontSize: math.max(10, widget.fontSize * 0.75),
              color: _timeColor,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ),
        SizedBox(width: math.max(6, widget.fontSize * 0.3)),
        if (widget.isMe) _buildStatusIcon(),
      ],
    );
  }

  Widget _buildStatusIcon() {
    Widget icon;
    Color color = _timeColor;

    if (widget.message.isPending) {
      icon = Icon(Icons.schedule_rounded,
          size: math.max(12, widget.fontSize * 0.8), color: color);
    } else if (!widget.message.isSent) {
      icon = Icon(Icons.refresh_rounded,
          size: math.max(12, widget.fontSize * 0.8), color: Colors.red);
    } else {
      icon = Icon(Icons.done_rounded,
          size: math.max(12, widget.fontSize * 0.8), color: color);
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: icon,
    );
  }
}
