import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../model/conversation_model.dart';
import '../../services/telegram_read_receipt_service.dart';
import '../../features/chat/widgets/telegram_message_status.dart';
import '../provider/typing_provider.dart';
import 'package:Vista/utils/const.dart';

/// 🚀 ویجت Swipeable برای آیتم مکالمه (مثل ویستا)
///
/// قابلیت‌ها:
/// - Swipe راست: Pin/Unpin
/// - Swipe چپ: Archive/Delete
/// - طراحی مدرن و روان

class SwipeableConversationItem extends ConsumerWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;
  final VoidCallback? onMute;
  final VoidCallback? onBlock;

  /// ارتفاع ثابت برای بهینه‌سازی ListView
  static const double itemHeight = 76.0;

  const SwipeableConversationItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
    this.onPin,
    this.onArchive,
    this.onDelete,
    this.onMute,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canBlock =
        (conversation.otherUserId?.isNotEmpty ?? false) && onBlock != null;
    final typingUsersAsync = ref.watch(typingUsersProvider(conversation.id));
    final typingUsers = typingUsersAsync.maybeWhen(
      data: (users) => users,
      orElse: () => conversation.typingUsers.toSet(),
    );
    final otherUserId = conversation.otherUserId;
    final isOtherUserTyping = otherUserId != null &&
        otherUserId.isNotEmpty &&
        typingUsers.contains(otherUserId);

    return Slidable(
      key: ValueKey(conversation.id),
      // ✅ Swipe از راست (RTL) - Pin/Mute
      startActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.25,
        children: [
          // Pin Action
          CustomSlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onPin?.call();
            },
            backgroundColor:
                conversation.isPinned ? Colors.grey.shade600 : Colors.amber,
            foregroundColor: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  conversation.isPinned
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.isPinned ? 'حذف پین' : 'پین',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      // ✅ Swipe از چپ - Archive/Delete
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: canBlock ? 0.75 : 0.5,
        children: [
          // Archive Action
          CustomSlidableAction(
            onPressed: (_) {
              HapticFeedback.lightImpact();
              onArchive?.call();
            },
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.archive_rounded, size: 24),
                SizedBox(height: 4),
                Text(
                  'بایگانی',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (canBlock)
            CustomSlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                onBlock?.call();
              },
              backgroundColor: Colors.deepOrange.shade700,
              foregroundColor: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.block_rounded, size: 24),
                  SizedBox(height: 4),
                  Text(
                    'مسدود',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          // Delete Action
          CustomSlidableAction(
            onPressed: (_) {
              HapticFeedback.mediumImpact();
              onDelete?.call();
            },
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.delete_rounded, size: 24),
                SizedBox(height: 4),
                Text(
                  'حذف',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
      child: _ConversationContent(
        conversation: conversation,
        onTap: onTap,
        onLongPress: onLongPress,
        isOtherUserTyping: isOtherUserTyping,
      ),
    );
  }
}

/// محتوای داخلی آیتم مکالمه
class _ConversationContent extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isOtherUserTyping;

  const _ConversationContent({
    required this.conversation,
    this.onTap,
    this.onLongPress,
    this.isOtherUserTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: SwipeableConversationItem.itemHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _AvatarWidget(
                  avatarUrl: conversation.otherUserAvatar,
                  displayName: _getDisplayName(),
                  isPinned: conversation.isPinned,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContentWidget(
                    displayName: _getDisplayName(),
                    lastMessage: _getLastMessage(),
                    lastMessageTime: conversation.lastMessageTime,
                    unreadCount: conversation.unreadCount,
                    isMuted: conversation.isMuted,
                    isGroup: _isGroupConversation(),
                    // ✅ استفاده از مقدار واقعی از مدل
                    isLastMessageFromMe: conversation.isLastMessageFromMe,
                    // ✅ نوع پیام برای نمایش آیکون مناسب
                    lastMessageType: conversation.lastMessageType,
                    // ✅ وضعیت تحویل پیام - هماهنگ با صفحه چت
                    lastMessageDeliveryStatus:
                        conversation.lastMessageDeliveryStatus,
                    isTyping: isOtherUserTyping,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayName() {
    final name = conversation.otherUserName ?? '';
    if (name.isEmpty || name == 'کاربر' || name == 'کاربر ناشناس') {
      return 'VISTA USER';
    }
    return name;
  }

  bool _isGroupConversation() {
    final otherId = conversation.otherUserId;
    return otherId == null || otherId.isEmpty;
  }

  String _getLastMessage() {
    // استفاده از formattedLastMessage که نوع پیام رو هم هندل میکنه
    final message = conversation.formattedLastMessage;
    if (message == null || message.isEmpty) {
      return 'پیام جدیدی ارسال کنید';
    }
    return message;
  }
}

/// ویجت آواتار با انیمیشن نرم بارگذاری
class _AvatarWidget extends StatefulWidget {
  final String? avatarUrl;
  final String displayName;
  final bool isPinned;

  const _AvatarWidget({
    required this.avatarUrl,
    required this.displayName,
    required this.isPinned,
  });

  @override
  State<_AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<_AvatarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isImageLoaded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onImageLoaded() {
    if (mounted && !_isImageLoaded) {
      setState(() => _isImageLoaded = true);
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        // آواتار اصلی با انیمیشن
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: _buildAvatarWithAnimation(theme),
          ),
        ),
        // Pin indicator
        if (widget.isPinned)
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.push_pin_rounded,
                size: 10,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarWithAnimation(ThemeData theme) {
    // اگر URL نداریم، آواتار پیش‌فرض نمایش بده
    if (widget.avatarUrl?.isNotEmpty != true) {
      return _buildDefaultAvatarImage(theme);
    }

    // استفاده از Stack برای انیمیشن نرم تغییر
    return Stack(
      fit: StackFit.expand,
      children: [
        // لایه زیرین: آواتار پیش‌فرض (همیشه نمایش داده میشه)
        _buildDefaultAvatarImage(theme),

        // لایه رویی: تصویر واقعی با fade-in
        AnimatedBuilder(
          animation: _fadeAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: child,
            );
          },
          child: CachedNetworkImage(
            imageUrl: widget.avatarUrl!,
            fit: BoxFit.cover,
            placeholder: (_, __) =>
                const SizedBox.shrink(), // چیزی نشون نده چون default زیرش هست
            errorWidget: (_, __, ___) =>
                const SizedBox.shrink(), // error هم default رو نشون میده
            imageBuilder: (context, imageProvider) {
              // وقتی تصویر لود شد، انیمیشن رو شروع کن
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onImageLoaded();
              });
              return Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatarImage(ThemeData theme) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _buildFallbackAvatar(theme),
    );
  }

  Widget _buildFallbackAvatar(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.2),
            theme.primaryColor.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          widget.displayName.isNotEmpty
              ? widget.displayName[0].toUpperCase()
              : 'U',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// ویجت محتوای مکالمه با Tick وضعیت و نوع پیام
class _ContentWidget extends StatelessWidget {
  final String displayName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isMuted;
  final bool isGroup;
  final bool isLastMessageFromMe;
  final String? lastMessageType;
  final MessageDeliveryStatus lastMessageDeliveryStatus;
  final bool isTyping;

  const _ContentWidget({
    required this.displayName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isMuted,
    this.isGroup = false,
    this.isLastMessageFromMe = false,
    this.lastMessageType,
    this.lastMessageDeliveryStatus = MessageDeliveryStatus.sent,
    this.isTyping = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = unreadCount > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ردیف اول: نام + زمان
        Row(
          children: [
            if (isMuted) ...[
              Icon(
                Icons.volume_off_rounded,
                size: 14,
                color: theme.hintColor.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Row(
                children: [
                  if (isGroup) ...[
                    Icon(
                      Icons.group_rounded,
                      size: 14,
                      color: theme.hintColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w500,
                        color: theme.textTheme.titleMedium?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (lastMessageTime != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatTime(lastMessageTime!),
                style: TextStyle(
                  fontSize: 12,
                  color: hasUnread ? theme.primaryColor : theme.hintColor,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // ردیف دوم: tick + آیکون نوع پیام + آخرین پیام + badge
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  if (isLastMessageFromMe) ...[
                    TelegramMessageStatus(
                      status: lastMessageDeliveryStatus,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (!isTyping &&
                      lastMessageType != null &&
                      lastMessageType != 'text') ...[
                    _MessageTypeIcon(type: lastMessageType!),
                    const SizedBox(width: 4),
                  ],
                  if (isTyping) ...[
                    Icon(
                      Icons.edit_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      isTyping ? 'در حال نوشتن...' : lastMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: isTyping
                            ? theme.colorScheme.primary
                            : (hasUnread
                                ? theme.textTheme.bodyMedium?.color
                                : theme.hintColor),
                        fontWeight: isTyping
                            ? FontWeight.w600
                            : (hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal),
                        fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              _UnreadBadge(count: unreadCount, isMuted: isMuted),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 6) {
      return '${time.day}/${time.month}';
    }

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'دیروز';
      return '${difference.inDays} روز';
    }

    // نمایش ساعت برای همین روز
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// ✅ آیکون نوع پیام
class _MessageTypeIcon extends StatelessWidget {
  final String type;

  const _MessageTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'voice':
      case 'audio':
        icon = Icons.mic_rounded;
        color = Colors.orange;
        break;
      case 'image':
      case 'photo':
        icon = Icons.photo_rounded;
        color = Colors.blue;
        break;
      case 'video':
        icon = Icons.videocam_rounded;
        color = Colors.purple;
        break;
      case 'post':
      case 'shared_post':
        icon = Icons.article_rounded;
        color = Colors.teal;
        break;
      case 'file':
      case 'document':
        icon = Icons.attach_file_rounded;
        color = Colors.grey;
        break;
      case 'sticker':
        icon = Icons.emoji_emotions_rounded;
        color = Colors.amber;
        break;
      case 'gif':
        icon = Icons.gif_rounded;
        color = Colors.green;
        break;
      case 'location':
        icon = Icons.location_on_rounded;
        color = Colors.red;
        break;
      case 'contact':
        icon = Icons.person_rounded;
        color = Colors.indigo;
        break;
      case 'poll':
        icon = Icons.poll_rounded;
        color = Colors.deepPurple;
        break;
      case 'link':
        icon = Icons.link_rounded;
        color = Colors.cyan;
        break;
      case 'forward':
        icon = Icons.shortcut_rounded;
        color = theme.hintColor;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(
      icon,
      size: 16,
      color: color.withValues(alpha: 0.8),
    );
  }
}

/// ✅ Badge بهبود یافته با طراحی مدرن
class _UnreadBadge extends StatelessWidget {
  final int count;
  final bool isMuted;

  const _UnreadBadge({
    required this.count,
    this.isMuted = false,
  });

  @override
  Widget build(BuildContext context) {
    const Color badgeColor = Color(0xFF1E88E5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [badgeColor, badgeColor.withValues(alpha: 0.86)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
