import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import '../../services/toast_service.dart';
import '../../services/advanced_file_manager.dart';
import '../../services/file_manager_service.dart';
import '../../../model/message_model.dart';
import 'voice_message_widget.dart';
import '../../../view/util/time_utils.dart';
import 'shared_post_card_widget.dart';
import '../../widgets/reactions/reaction_display.dart';
import '../../widgets/reactions/reaction_selector.dart';
import '../../widgets/reactions/reaction_picker_sheet.dart';
import '../../widgets/reactions/reaction_manager.dart';
import '../../provider/reaction_provider.dart';
import '../../provider/chat_provider.dart';

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
  final bool isSelectionMode; // آیا در حالت selection mode هستیم؟
  final Function(String messageId, Offset position)?
      onShowReactionPicker; // callback برای نمایش reaction picker
  final VoidCallback?
      onReactionSelected; // callback برای خاموش کردن selection mode بعد از انتخاب reaction

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
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Animation controller برای status icon
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _statusIconRotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _statusAnimationController, curve: Curves.linear),
    );

    // اگر پیام pending است، animation را شروع کن
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

    // وقتی پیام از pending به sent برود، animation را به صورت smooth نمایش بده
    if (oldWidget.message.isPending && !widget.message.isPending) {
      // پایان animation چرخش ساعت
      _statusAnimationController.stop();
      _statusAnimationController.reset();

      // یک animation کوتاه برای تغییر icon
      _statusAnimationController.forward(from: 0).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else if (!oldWidget.message.isPending && widget.message.isPending) {
      // اگر دوباره pending شد، تکرار کن
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
    // بررسی ساده برای تشخیص پست اشتراکی
    return content.contains('📝 پست از') &&
        content.contains('🔗 مشاهده در Vista:');
  }

  bool _isFileWithoutCaption(MessageModel message) {
    // اگر فایل است و کپشن خالی یا فقط شامل اسم فایل است
    if (message.attachmentType == 'document' ||
        message.attachmentType == 'file') {
      if (message.content.isEmpty) {
        return true;
      }
      // اگر کپشن دقیقاً برابر با اسم فایل باشد، آن را به عنوان بدون کپشن در نظر می‌گیریم
      final fileName = _extractFileName(message.attachmentUrl ?? '');
      return message.content.trim() == fileName;
    }
    return false;
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
        // بررسی اینکه آیا در selection mode هستیم یا نه (قبل از select کردن)
        final wasNotInSelectionMode = !widget.isSelectionMode;

        // همیشه پیام را select کن
        widget.onLongPress(widget.message);

        // اگر قبلاً در selection mode نبودیم (یعنی اولین long press) و conversationId و currentUserId موجود باشد
        // Reaction Panel را نمایش بده
        if (wasNotInSelectionMode &&
            widget.conversationId != null &&
            widget.currentUserId != null) {
          HapticFeedback.mediumImpact();

          // ✅ استفاده از ReactionManager برای نمایش overlay
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
                  // بستن selector قدیمی در صورت وجود
                  ref
                      .read(
                          reactionSelectorProvider(widget.message.id).notifier)
                      .state = false;
                },
                onReactionSelected: widget.onReactionSelected,
              );
            }
          });

          // همچنین اگر callback موجود بود، آن را هم فراخوانی کن (برای backward compatibility)
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
        // بستن selector و overlay reaction panel اگر باز است
        if (ref.read(reactionSelectorProvider(widget.message.id))) {
          ref.read(reactionSelectorProvider(widget.message.id).notifier).state =
              false;
        }
        // بستن overlay reaction panel
        if (ReactionManager().isShowing &&
            ReactionManager().activeMessageId == widget.message.id) {
          ReactionManager().hideReactionPanel();
        }

        // اگر در حالت selection mode هستیم، همیشه toggle selection انجام بده
        if (widget.onSelectTap != null) {
          // Haptic feedback برای انتخاب/لغو انتخاب
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
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(
          _isReplying ? (isMe ? -20 : 20) : 0,
          0,
          0,
        ),
        // کل فضای پیام را highlight می‌کنیم وقتی انتخاب شده
        padding: widget.isSelected
            ? const EdgeInsets.all(8)
            : const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? Theme.of(context)
                  .primaryColor
                  .withOpacity(0.08) // highlight ملایم کل فضای پیام
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
                    if (widget.message.attachmentUrl != null &&
                        !_isSharedPost(widget.message.content))
                      _buildAttachment(context, widget.message.attachmentType,
                          widget.message.attachmentUrl!),
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
                            // ✅ نمایش Reactions کنار ساعت (مثل واتساپ)
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

                    // ✅ نمایش Reactions کامل زیر پیام (برای reaction های بیشتر)
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
                          // نمایش BottomSheet با لیست کامل کسانی که reaction داده‌اند
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
                              // بروزرسانی خودکار از طریق real-time listener
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            // ✅ نمایش Reaction Selector (بالای پیام - overlay)
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

  Widget _buildAttachment(BuildContext context, String? type, String url) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    if (type == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: GestureDetector(
          onTap: widget.onSelectTap != null
              ? null // در حالت selection، اجازه نده تصویر باز شود
              : () => _showFullScreenImage(context, url),
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

  String _extractFileName(String url) {
    try {
      debugPrint('🔍 Extracting filename from: $url');
      final uri = Uri.parse(url);
      final path = uri.path;
      debugPrint('📄 Path: $path');

      final name = path.split('/').last;
      debugPrint('📄 Raw name: $name');

      if (name.isNotEmpty) {
        final decodedName = Uri.decodeComponent(name);
        debugPrint('📄 Decoded name: $decodedName');

        // Clean filename for filesystem compatibility
        final cleanName = _cleanFileName(decodedName);
        debugPrint('📄 Clean name: $cleanName');
        return cleanName;
      }

      // Fallback: generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fallbackName = 'vista_file_$timestamp';
      debugPrint('📄 Fallback name: $fallbackName');
      return fallbackName;
    } catch (e) {
      debugPrint('❌ Error extracting filename: $e');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'vista_file_$timestamp';
    }
  }

  String _cleanFileName(String fileName) {
    // Keep Persian characters but clean problematic filesystem chars
    String clean = fileName
        .replaceAll(
            RegExp(r'[<>:"/\\|?*]'), '_') // Replace invalid filesystem chars
        .replaceAll(RegExp(r'\s+'), '_'); // Replace spaces with underscores

    // Ensure it's not too long (max 255 chars for most filesystems)
    if (clean.length > 200) {
      final extension = clean.split('.').last;
      final nameWithoutExt = clean.substring(0, clean.lastIndexOf('.'));
      clean =
          '${nameWithoutExt.substring(0, 200 - extension.length - 1)}.$extension';
    }

    // Ensure it doesn't start with dot or end with space/dot
    clean = clean.replaceAll(RegExp(r'^\.+'), 'file_');
    clean = clean.replaceAll(RegExp(r'[\s\.]+$'), '');

    return clean.isEmpty
        ? 'vista_file_${DateTime.now().millisecondsSinceEpoch}'
        : clean;
  }

  Future<void> _downloadAndOpen(String url) async {
    try {
      setState(() {
        _isDownloading[url] = true;
        _downloadProgress[url] = 0.0;
      });

      // دانلود فایل
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

      // باز کردن فایل
      try {
        await _openLocal(file);
      } catch (openError) {
        ToastService.showErrorToast(context, 'خطا در باز کردن فایل');
      }
    } finally {
      // اطمینان از ریست وضعیت دانلود در هر حالت
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
              // Header
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

              // Options
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

                    // استفاده از AdvancedFileManager برای دانلود
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

      // استفاده از FileManagerService برای بررسی اعتبار فایل
      final isValid = await FileManagerService.isFileValid(file);
      if (!isValid) {
        debugPrint('❌ File is invalid: ${file.path}');
        ToastService.showErrorToast(
            context, 'فایل معتبر نیست یا آسیب دیده است');
        return;
      }

      final fileSize = await file.length();
      debugPrint('📏 File size: $fileSize bytes');

      // استفاده از open_filex برای باز کردن فایل (حل مشکل FileUriExposedException)
      debugPrint('🚀 Opening file with open_filex: ${file.path}');

      try {
        final result = await OpenFilex.open(file.path);

        if (result.type == ResultType.done) {
          debugPrint('✅ File opened successfully with open_filex');
          final fileType =
              _isPdfFile(widget.message.attachmentUrl ?? '') ? 'PDF' : 'فایل';
          ToastService.showSuccessToast(context, '$fileType باز شد');
        } else {
          debugPrint(
              '❌ Failed to open file with open_filex: ${result.message}');
          ToastService.showErrorToast(context,
              'نمی‌توان فایل را باز کرد. برنامه مناسبی برای باز کردن این فایل نصب نیست.');
        }
      } catch (e) {
        debugPrint('❌ Error with open_filex: $e');
        ToastService.showErrorToast(
            context, 'خطا در باز کردن فایل: ${e.toString()}');
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
    // بررسی اینکه آیا پیام اصلی یک پست اشتراکی بوده یا نه
    final isReplyToSharedPost = message.replyToContent != null &&
        message.replyToContent!.contains('📝 پست از') &&
        message.replyToContent!.contains('🔗 مشاهده در Vista:');

    // تلاش برای پیدا کردن نام واقعی فرستنده از پیام‌های قبلی/بعدی
    String? actualSenderName = message.replyToSenderName;
    if (actualSenderName == null ||
        actualSenderName.isEmpty ||
        actualSenderName == 'کاربر') {
      // بررسی پیام‌های قبلی و بعدی برای پیدا کردن نام
      if (message.replyToMessageId != null) {
        // بررسی پیام قبلی
        if (widget.previousMessage != null &&
            widget.previousMessage!.id == message.replyToMessageId) {
          actualSenderName = widget.previousMessage!.senderName;
        }
        // بررسی پیام بعدی
        else if (widget.nextMessage != null &&
            widget.nextMessage!.id == message.replyToMessageId) {
          actualSenderName = widget.nextMessage!.senderName;
        }
      }
    }

    // در نهایت اگر هنوز null است یا 'کاربر' است، از fallback استفاده کن
    // اما از نام فرستنده پیام فعلی استفاده نمی‌کنیم چون این نام فرستنده ریپلای شده نیست
    final displayName = (actualSenderName != null &&
            actualSenderName.isNotEmpty &&
            actualSenderName != 'کاربر')
        ? actualSenderName
        : 'کاربر';

    return Container(
      margin: const EdgeInsets.only(
          top: 8, bottom: 4), // حذف margin چپ و راست برای پر کردن کل عرض
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // padding بهتر
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
          // خط عمودی آبی که قبلا border بود
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
          ),
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
        color: isDark ? theme.cardColor.withOpacity(0.3) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.2),
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
                    color: theme.dividerColor.withOpacity(0.2),
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
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  hasVideo ? 'ویدیو' : 'تصویر',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          // Selection checkbox
          if (widget.isSelected)
            Positioned(
              top: 8,
              left: widget.message.isMe ? 8 : null,
              right: widget.message.isMe ? null : 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
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

  /// ✅ نمایش Reactions کنار ساعت (مثل واتساپ)
  Widget _buildInlineReactions(bool isMe, ThemeData theme) {
    if (widget.message.reactions.isEmpty ||
        widget.currentUserId == null ||
        widget.conversationId == null) {
      return const SizedBox.shrink();
    }

    final currentUserId = widget.currentUserId!;
    final reactions = widget.message.reactions;

    // فقط اولین reaction را نمایش بده (مثل واتساپ)
    final firstReaction = reactions.entries.first;
    final emoji = firstReaction.key;
    final userIds = firstReaction.value;
    final hasCurrentUser = userIds.contains(currentUserId);
    final count = userIds.length;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: GestureDetector(
        onTap: () {
          // Toggle reaction با کلیک - اگر کاربر reaction داده، حذف می‌شود
          HapticFeedback.lightImpact();
          ref.read(messageNotifierProvider.notifier).toggleReaction(
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
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light;

    if (message.isPending) {
      // Rotating schedule icon برای pending
      return RotationTransition(
        turns: _statusIconRotation,
        child: Icon(
          Icons.schedule,
          size: 14,
          color: isLightMode ? Colors.grey.shade600 : Colors.grey.shade400,
        ),
      );
    } else if (!message.isSent) {
      // برای پیام‌های ناموفق، دکمه retry نمایش داده می‌شود
      return _buildFailedMessageStatus(message);
    } else if (!message.isDelivered) {
      // تیک تک - ارسال شده
      return _buildStatusBadge(Icons.done,
          isLightMode ? Colors.grey.shade700 : Colors.grey.shade300, 16);
    } else if (!message.isSeen) {
      // تیک دوتایی - تحویل داده شده
      return _buildStatusBadge(Icons.done_all,
          isLightMode ? Colors.grey.shade700 : Colors.grey.shade300, 16);
    } else {
      // تیک دوتایی آبی - خوانده شده
      return _buildStatusBadge(Icons.done_all,
          isLightMode ? Colors.blue.shade700 : Colors.blue.shade400, 16);
    }
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
