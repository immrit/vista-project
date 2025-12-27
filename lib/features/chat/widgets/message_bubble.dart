// lib/features/chat/widgets/message_bubble.dart
//
// حباب پیام یکپارچه - ادغام شده از دو فایل قدیمی و جدید
//
// ویژگی‌ها:
// ✅ نمایش تصاویر محلی و شبکه (اولویت با محلی)
// ✅ نمایش Reply
// ✅ نمایش Reactions
// ✅ وضعیت ارسال (pending, sent, delivered, seen)
// ✅ پشتیبانی از پیام‌های فایل، صدا، ویدیو
// ✅ سازگار با ChatScreen فعلی

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:open_filex/open_filex.dart';

import '../../../model/message_model.dart';
import '../../../services/advanced_file_manager.dart';
import '../../../services/toast_service.dart';
import 'package:Vista/utils/time_utils.dart';
import 'package:Vista/widgets/voice_message_widget.dart';
import 'package:Vista/widgets/shared_post_card_widget.dart';
import '../../../widgets/reactions/reaction_display.dart';
import '../../../widgets/reactions/reaction_selector.dart';
import '../../../widgets/reactions/reaction_picker_sheet.dart';
import '../../../widgets/reactions/reaction_manager.dart';
import '../../../provider/reaction_provider.dart';

/// ویجت یکپارچه و نهایی MessageBubble
class MessageBubble extends ConsumerStatefulWidget {
  final MessageModel message;
  final Function(MessageModel) onLongPress;
  final Function(MessageModel)? onReply;
  final Function(MessageModel)? onRetry;
  final Function(String)? onTap;
  final Function(MessageModel)? onSingleTap;
  final Function(String)? onSelectTap;
  final bool isHighlighted;
  final bool isSelected;
  final MessageModel? previousMessage;
  final MessageModel? nextMessage;
  final String? currentUserId;
  final String? conversationId;
  final bool isSelectionMode;
  final Function(String messageId, Offset position)? onShowReactionPicker;
  final VoidCallback? onReactionSelected;

  const MessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
    this.onReply,
    this.onRetry,
    this.onTap,
    this.onSingleTap,
    this.onSelectTap,
    this.isHighlighted = false,
    this.isSelected = false,
    this.previousMessage,
    this.nextMessage,
    this.currentUserId,
    this.conversationId,
    this.isSelectionMode = false,
    this.onShowReactionPicker,
    this.onReactionSelected,
  });

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble>
    with TickerProviderStateMixin {
  bool _isReplying = false;
  bool _isRetrying = false;
  final GlobalKey _messageBubbleKey = GlobalKey();
  late AnimationController _retryAnimationController;
  late AnimationController _statusAnimationController;
  late Animation<double> _statusIconRotation;
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  @override
  void initState() {
    super.initState();
    _retryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _statusIconRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _statusAnimationController, curve: Curves.linear),
    );

    if (widget.message.isPending) {
      _statusAnimationController.repeat();
    }

    // گوش دادن به پیشرفت دانلود
    AdvancedFileManager.instance.downloadProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _downloadProgress[progress.url] = progress.progress;
        });
      }
    });
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message.isPending && !widget.message.isPending) {
      _statusAnimationController.stop();
      _statusAnimationController.reset();
      _statusAnimationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (!oldWidget.message.isPending && widget.message.isPending) {
      _statusAnimationController.repeat();
    }
  }

  @override
  void dispose() {
    _retryAnimationController.dispose();
    _statusAnimationController.dispose();
    super.dispose();
  }

  bool _isSharedPost(String content) {
    return content.contains('📝 پست از') &&
        content.contains('🔗 مشاهده در Vista:');
  }

  bool _isFileWithoutCaption(MessageModel message) {
    if (message.attachmentType == 'document' ||
        message.attachmentType == 'file') {
      if (message.content.isEmpty) {
        return true;
      }
      final fileName = _extractFileName(message.attachmentUrl ?? '');
      return message.content.trim() == fileName;
    }
    return false;
  }

  String _extractFileName(String url) {
    try {
      if (widget.message.attachmentFileName != null) {
        return widget.message.attachmentFileName!;
      }
      return Uri.parse(url).path.split('/').last;
    } catch (e) {
      return 'file';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = widget.message.isMe;
    final isLightMode = theme.brightness == Brightness.light;

    final outgoingBubbleColor =
        isLightMode ? const Color(0xFFF5F5F5) : const Color(0xFF3A3A3A);
    final incomingBubbleColor =
        isLightMode ? Colors.white : const Color(0xFF2C2C2C);
    final bool isImageOnly = widget.message.attachmentType == 'image' &&
        widget.message.content.isEmpty;

    return GestureDetector(
      onLongPress: () {
        final wasNotInSelectionMode = !widget.isSelectionMode;
        widget.onLongPress(widget.message);

        if (wasNotInSelectionMode &&
            widget.conversationId != null &&
            widget.currentUserId != null) {
          HapticFeedback.mediumImpact();

          final isFromMe = widget.currentUserId == widget.message.senderId;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ReactionManager().showReactionPanel(
                context: context,
                messageKey: _messageBubbleKey,
                messageId: widget.message.id,
                conversationId: widget.conversationId!,
                isFromMe: isFromMe,
                ref: ref,
                onDismiss: () {
                  ref
                      .read(
                          reactionSelectorProvider(widget.message.id).notifier)
                      .state = false;
                },
                onReactionSelected: widget.onReactionSelected,
              );
            }
          });

          if (widget.onShowReactionPicker != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final RenderBox? renderBox = _messageBubbleKey.currentContext
                  ?.findRenderObject() as RenderBox?;
              if (renderBox != null && mounted) {
                final position = renderBox.localToGlobal(Offset.zero);
                final size = renderBox.size;
                final centerPosition = Offset(
                  position.dx + size.width / 2,
                  position.dy,
                );
                widget.onShowReactionPicker!(widget.message.id, centerPosition);
              }
            });
          }
        }
      },
      onTap: () {
        if (ref.read(reactionSelectorProvider(widget.message.id))) {
          ref.read(reactionSelectorProvider(widget.message.id).notifier).state =
              false;
        }
        if (ReactionManager().isShowing &&
            ReactionManager().activeMessageId == widget.message.id) {
          ReactionManager().hideReactionPanel();
        }

        if (widget.onSelectTap != null) {
          HapticFeedback.lightImpact();
          widget.onSelectTap!(widget.message.id);
        } else if (widget.onSingleTap != null) {
          widget.onSingleTap!(widget.message);
        }
      },
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
        duration: const Duration(milliseconds: 100),
        transform: Matrix4.translationValues(
          _isReplying ? (isMe ? -20 : 20) : 0,
          0,
          0,
        ),
        padding: widget.isSelected
            ? const EdgeInsets.all(8)
            : const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                key: _messageBubbleKey,
                margin:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                padding: const EdgeInsets.all(3),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: (isImageOnly || _isSharedPost(widget.message.content))
                      ? Colors.transparent
                      : (widget.isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : (isMe ? outgoingBubbleColor : incomingBubbleColor)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: widget.isHighlighted || widget.isSelected
                      ? Border.all(
                          color: widget.isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.amber,
                          width: 2,
                        )
                      : null,
                  boxShadow:
                      (isImageOnly || _isSharedPost(widget.message.content))
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                              if (widget.isHighlighted || widget.isSelected)
                                BoxShadow(
                                  color: (widget.isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.amber)
                                      .withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 0),
                                ),
                            ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.message.replyToMessageId != null)
                      _buildReplyPreview(context, widget.message),
                    // ✅ نمایش attachment (تصویر، ویدیو، فایل)
                    if ((widget.message.attachmentType != null ||
                            widget.message.isImage ||
                            widget.message.isVideo ||
                            widget.message.localImagePath != null) &&
                        !_isSharedPost(widget.message.content))
                      Builder(
                        builder: (context) {
                          // لاگ برای دیباگ
                          debugPrint('📸 MessageBubble - Building attachment:');
                          debugPrint(
                              '  - attachmentType: ${widget.message.attachmentType}');
                          debugPrint(
                              '  - attachmentUrl: ${widget.message.attachmentUrl}');
                          debugPrint(
                              '  - localImagePath: ${widget.message.localImagePath}');
                          debugPrint('  - isImage: ${widget.message.isImage}');
                          debugPrint('  - isVideo: ${widget.message.isVideo}');
                          debugPrint(
                              '  - messageType: ${widget.message.messageType}');

                          // تعیین نوع attachment
                          final attachmentType = widget
                                  .message.attachmentType ??
                              (widget.message.isImage
                                  ? 'image'
                                  : (widget.message.isVideo ? 'video' : null));

                          if (attachmentType == null) {
                            debugPrint(
                                '⚠️ attachmentType is null, skipping attachment');
                            return const SizedBox.shrink();
                          }

                          return _buildAttachment(
                            context,
                            attachmentType,
                            widget.message.attachmentUrl ?? '',
                          );
                        },
                      ),
                    if (widget.message.content.isNotEmpty &&
                        !(_isFileWithoutCaption(widget.message)))
                      _isSharedPost(widget.message.content)
                          ? _buildSharedPostWidget()
                          : _buildMessageContent(context, widget.message, isMe),
                    if (!isImageOnly || _isSharedPost(widget.message.content))
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4, right: 8, bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (widget.message.reactions.isNotEmpty &&
                                widget.currentUserId != null &&
                                widget.conversationId != null)
                              _buildInlineReactions(isMe, theme),
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
                    if (widget.message.reactions.isNotEmpty &&
                        widget.currentUserId != null &&
                        widget.conversationId != null &&
                        widget.message.reactions.values
                            .any((list) => list.length > 1))
                      ReactionDisplay(
                        reactions: widget.message.reactions,
                        currentUserId: widget.currentUserId!,
                        messageId: widget.message.id,
                        conversationId: widget.conversationId!,
                        isMyMessage: isMe,
                        onTap: () {
                          ReactionPickerSheet.show(
                            context,
                            onEmojiSelected: (emoji) async {
                              final service = ref.read(reactionServiceProvider);
                              await service.addReaction(
                                messageId: widget.message.id,
                                conversationId: widget.conversationId!,
                                emoji: emoji,
                              );
                              ref.invalidate(
                                  messageReactionsProvider(widget.message.id));
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (ref.watch(reactionSelectorProvider(widget.message.id)) &&
                widget.conversationId != null)
              Positioned(
                top: -50,
                right: isMe ? 8 : null,
                left: isMe ? null : 8,
                child: ReactionSelectorWidget(
                  messageId: widget.message.id,
                  conversationId: widget.conversationId!,
                ),
              ),
          ],
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

  // ✅ اصلاح اصلی: هندلینگ صحیح تصاویر (لوکال و شبکه)
  Widget _buildAttachment(BuildContext context, String? type, String url) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    debugPrint('🔍 _buildAttachment called with type: $type, url: $url');

    if (type == 'image' || type?.startsWith('image') == true) {
      final localPath = widget.message.localImagePath;
      final remoteUrl = widget.message.attachmentUrl ?? url;

      debugPrint('📸 Image attachment details:');
      debugPrint('  - localPath: $localPath');
      debugPrint('  - remoteUrl: $remoteUrl');
      debugPrint('  - isUploading: ${widget.message.isUploading}');
      debugPrint('  - isPending: ${widget.message.isPending}');

      // آیا فایل لوکال معتبر وجود دارد؟
      final hasValidLocalFile = localPath != null &&
          localPath.isNotEmpty &&
          File(localPath).existsSync();

      debugPrint('  - hasValidLocalFile: $hasValidLocalFile');
      if (localPath != null && localPath.isNotEmpty) {
        debugPrint('  - localPath exists: ${File(localPath).existsSync()}');
      }

      // آیا لینک سرور معتبر است؟
      final hasValidRemoteUrl = remoteUrl.isNotEmpty &&
          (remoteUrl.startsWith('http') || remoteUrl.startsWith('https'));

      debugPrint('  - hasValidRemoteUrl: $hasValidRemoteUrl');

      final isUploading =
          widget.message.isUploading || widget.message.isPending;
      final uploadProgress = widget.message.uploadProgress ?? 0.0;

      Widget imageWidget;

      if (hasValidLocalFile) {
        // اولویت با فایل لوکال (برای آپلود سریع و نمایش آنی)
        debugPrint('✅ نمایش تصویر محلی: $localPath');
        imageWidget = Image.file(
          File(localPath),
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ خطا در نمایش تصویر محلی: $error');
            return Container(
              height: 200,
              constraints: const BoxConstraints(
                minHeight: 150,
                minWidth: 200,
              ),
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 40),
                    SizedBox(height: 8),
                    Text('خطا در بارگذاری تصویر محلی'),
                  ],
                ),
              ),
            );
          },
        );
      } else if (hasValidRemoteUrl) {
        // اگر لوکال نبود، از شبکه بگیر
        debugPrint('✅ نمایش تصویر از سرور: $remoteUrl');
        imageWidget = CachedNetworkImage(
          imageUrl: remoteUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Container(
            height: 200,
            constraints: const BoxConstraints(
              minHeight: 150,
              minWidth: 200,
            ),
            color: Colors.grey[300],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) {
            debugPrint('❌ خطا در دریافت تصویر از URL: $url');
            debugPrint('❌ جزئیات خطا: $error');
            return Container(
              height: 200,
              constraints: const BoxConstraints(
                minHeight: 150,
                minWidth: 200,
              ),
              color: Colors.grey[300],
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 40),
                    SizedBox(height: 8),
                    Text('خطا در بارگذاری تصویر'),
                  ],
                ),
              ),
            );
          },
        );
      } else {
        // هیچکدام موجود نیست (حالت Loading یا Error)
        debugPrint('⚠️ هیچ تصویری برای نمایش وجود ندارد');
        imageWidget = Container(
          height: 200,
          constraints: const BoxConstraints(
            minHeight: 150,
            minWidth: 200,
          ),
          color: Colors.grey[300],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[600],
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  isUploading ? 'در حال آپلود...' : 'لینک تصویر موجود نیست',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 150,
            minHeight: 150,
            maxWidth: 300,
            maxHeight: 400,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                onTap: widget.onSelectTap != null
                    ? null
                    : () {
                        final remoteUrlValue = remoteUrl;
                        final localPathValue = localPath;
                        if (!isUploading &&
                            hasValidRemoteUrl &&
                            remoteUrlValue.isNotEmpty) {
                          _showFullScreenImage(context, remoteUrlValue);
                        } else if (hasValidLocalFile &&
                            localPathValue != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(
                                  backgroundColor: Colors.black,
                                  iconTheme:
                                      const IconThemeData(color: Colors.white),
                                ),
                                body: Center(
                                  child: PhotoView(
                                    imageProvider:
                                        FileImage(File(localPathValue)),
                                    minScale: PhotoViewComputedScale.contained,
                                    maxScale:
                                        PhotoViewComputedScale.covered * 2,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: imageWidget,
                ),
              ),
              if (isUploading && uploadProgress < 1.0)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: uploadProgress,
                              strokeWidth: 4,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(uploadProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (!isUploading && hasValidRemoteUrl && hasValidLocalFile)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              if (widget.message.isFailed == true)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'خطا در آپلود',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.message.errorMessage != null) ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                widget.message.errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onRetry != null) {
                                HapticFeedback.mediumImpact();
                                widget.onRetry!(widget.message);
                              }
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('تلاش مجدد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (type == 'audio') {
      return VoiceMessageWidget(
        audioUrl: url,
        isMe: widget.message.isMe,
        duration: widget.message.duration,
        onDelete: null,
        onReply: null,
      );
    }

    if (type == 'document' || type == 'file' || type == 'pdf') {
      final fileName =
          widget.message.attachmentFileName ?? _extractFileName(url);
      final isDownloading = _isDownloading[url] ?? false;
      final progress = _downloadProgress[url] ?? 0.0;

      return GestureDetector(
        onTap: () => _showFileOptions(context, url),
        onLongPress: () => _showFileOptions(context, url),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isLightMode ? Colors.white : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLightMode
                  ? const Color(0xFFE0E0E0)
                  : const Color(0xFF3A3A3A),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insert_drive_file_rounded,
                  color: theme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isLightMode
                            ? const Color(0xFF1A1A1A)
                            : Colors.white,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isDownloading) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: isLightMode
                                    ? const Color(0xFFF0F0F0)
                                    : const Color(0xFF3A3A3A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLightMode
                                  ? const Color(0xFF6B6B6B)
                                  : const Color(0xFF9E9E9E),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Text(
                        'برای باز کردن ضربه بزنید',
                        style: TextStyle(
                          fontSize: 13,
                          color: isLightMode
                              ? const Color(0xFF6B6B6B)
                              : const Color(0xFF9E9E9E),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDownloading)
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(left: 12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _downloadAndOpen(String url) async {
    try {
      setState(() {
        _isDownloading[url] = true;
        _downloadProgress[url] = 0.0;
      });

      File? file;
      try {
        file = await AdvancedFileManager.instance.getFile(url);
      } catch (downloadError) {
        setState(() {
          _isDownloading[url] = false;
        });
        ToastService.showErrorToast(context, 'خطا در دانلود فایل');
        return;
      }

      if (file == null) {
        setState(() {
          _isDownloading[url] = false;
        });
        ToastService.showErrorToast(context, 'دانلود فایل ناموفق بود');
        return;
      }

      setState(() {
        _isDownloading[url] = false;
        _downloadProgress[url] = 1.0;
      });

      try {
        await _openLocal(file);
      } catch (openError) {
        ToastService.showErrorToast(context, 'خطا در باز کردن فایل');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[url] = false;
        });
      }
    }
  }

  void _showFileOptions(BuildContext context, String url) async {
    final fileName = widget.message.attachmentFileName ?? _extractFileName(url);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.insert_drive_file_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        fileName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading:
                    const Icon(Icons.open_in_new_rounded, color: Colors.blue),
                title: const Text('باز کردن'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _downloadAndOpen(url);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.download_rounded, color: Colors.green),
                title: const Text('ذخیره در دستگاه'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    setState(() {
                      _isDownloading[url] = true;
                      _downloadProgress[url] = 0.0;
                    });

                    final file =
                        await AdvancedFileManager.instance.getFile(url);
                    if (file != null) {
                      setState(() {
                        _isDownloading[url] = false;
                        _downloadProgress[url] = 1.0;
                      });
                      ToastService.showSuccessToast(
                        context,
                        'فایل ذخیره شد: ${file.path}',
                      );
                    } else {
                      setState(() {
                        _isDownloading[url] = false;
                      });
                      ToastService.showErrorToast(
                        context,
                        'دانلود فایل ناموفق بود',
                      );
                    }
                  } catch (e) {
                    setState(() {
                      _isDownloading[url] = false;
                    });
                    ToastService.showErrorToast(context, 'خطا در دانلود فایل');
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLocal(File file) async {
    try {
      debugPrint('🔓 Opening file: ${file.path}');

      final result = await OpenFilex.open(file.path);

      if (result.type == ResultType.done) {
        debugPrint('✅ File opened successfully with open_filex');
        final fileType =
            _isPdfFile(widget.message.attachmentUrl ?? '') ? 'PDF' : 'فایل';
        ToastService.showSuccessToast(context, '$fileType باز شد');
      } else {
        debugPrint('❌ Failed to open file with open_filex: ${result.message}');
        ToastService.showErrorToast(context,
            'نمی‌توان فایل را باز کرد. برنامه مناسبی برای باز کردن این فایل نصب نیست.');
      }
    } catch (e) {
      debugPrint('❌ Error opening file: $e');
      ToastService.showErrorToast(
          context, 'خطا در باز کردن فایل: ${e.toString()}');
    }
  }

  bool _isPdfFile(String url) {
    return url.toLowerCase().endsWith('.pdf');
  }

  Widget _buildReplyPreview(BuildContext context, MessageModel message) {
    final isReplyToSharedPost = message.replyToContent != null &&
        message.replyToContent!.contains('📝 پست از') &&
        message.replyToContent!.contains('🔗 مشاهده در Vista:');

    String? actualSenderName = message.replyToSenderName;
    if (actualSenderName == null ||
        actualSenderName.isEmpty ||
        actualSenderName == 'کاربر') {
      if (message.replyToMessageId != null) {
        if (widget.previousMessage != null &&
            widget.previousMessage!.id == message.replyToMessageId) {
          actualSenderName = widget.previousMessage!.senderName;
        } else if (widget.nextMessage != null &&
            widget.nextMessage!.id == message.replyToMessageId) {
          actualSenderName = widget.nextMessage!.senderName;
        }
      }
    }

    final displayName = (actualSenderName != null &&
            actualSenderName.isNotEmpty &&
            actualSenderName != 'کاربر')
        ? actualSenderName
        : 'کاربر';

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isReplyToSharedPost) ...[
                  _buildSharedPostReplyPreview(message.replyToContent!),
                ] else ...[
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
          ),
        ],
      ),
    );
  }

  Widget _buildSharedPostReplyPreview(String replyContent) {
    // ساده‌سازی شده - فقط متن را نمایش می‌دهد
    return Text(
      replyContent,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }

  Widget _buildInlineReactions(bool isMe, ThemeData theme) {
    if (widget.message.reactions.isEmpty ||
        widget.currentUserId == null ||
        widget.conversationId == null) {
      return const SizedBox.shrink();
    }

    final currentUserId = widget.currentUserId!;
    final reactions = widget.message.reactions;

    final firstReaction = reactions.entries.first;
    final emoji = firstReaction.key;
    final userIds = firstReaction.value;
    final hasCurrentUser = userIds.contains(currentUserId);
    final count = userIds.length;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(reactionServiceProvider).toggleReaction(
                messageId: widget.message.id,
                conversationId: widget.conversationId!,
                emoji: emoji,
              );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: hasCurrentUser
                ? (theme.brightness == Brightness.dark
                    ? Colors.blue.withOpacity(0.25)
                    : Colors.blue.withOpacity(0.15))
                : (theme.brightness == Brightness.dark
                    ? Colors.grey.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(10),
            border: hasCurrentUser
                ? Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Colors.blue.withOpacity(0.5)
                        : Colors.blue.withOpacity(0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                emoji,
                style: const TextStyle(fontSize: 14),
              ),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: hasCurrentUser
                        ? (theme.brightness == Brightness.dark
                            ? Colors.blue[300]
                            : Colors.blue[700])
                        : (theme.brightness == Brightness.dark
                            ? Colors.white70
                            : Colors.grey[700]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    Widget icon;
    if (message.isPending) {
      icon = RotationTransition(
        turns: _statusIconRotation,
        child: Icon(
          Icons.schedule,
          size: 14,
          color: isLightMode ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
      );
    } else if (!message.isSent) {
      icon = _buildFailedMessageStatus(message);
    } else if (!message.isDelivered) {
      icon = _buildStatusBadge(Icons.done,
          isLightMode ? Colors.grey.shade700 : Colors.grey.shade300, 16);
    } else if (!message.isSeen) {
      icon = _buildStatusBadge(Icons.done_all,
          isLightMode ? Colors.grey.shade700 : Colors.grey.shade300, 16);
    } else {
      icon = _buildStatusBadge(Icons.done_all,
          isLightMode ? Colors.blue.shade700 : Colors.blue.shade400, 16);
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: Center(child: icon),
    );
  }

  Widget _buildStatusBadge(IconData icon, Color color, double size) {
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }

  Widget _buildFailedMessageStatus(MessageModel message) {
    return GestureDetector(
      onTap: () => _onRetryMessage(message),
      child: _isRetrying
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
              ),
            )
          : AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: message.retryCount * 0.1,
              child: Icon(
                Icons.error_outline,
                size: 16,
                color: Colors.red.shade600,
              ),
            ),
    );
  }

  void _onRetryMessage(MessageModel message) {
    HapticFeedback.lightImpact();

    setState(() {
      _isRetrying = true;
    });

    _retryAnimationController.repeat();

    if (widget.onRetry != null) {
      widget.onRetry!(message);
    }

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
