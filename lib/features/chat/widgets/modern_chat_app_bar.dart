import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/chat_theme.dart';
import '../screens/modern_chat_screen.dart';
import '../../../model/ProfileModel.dart';
import 'modern_online_status.dart';
import '../../../utils/compat_extensions.dart';
import '../../../utils/directional_navigation.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ModernChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final ChatTheme theme;
  final bool isSelectionMode;
  final int selectedMessagesCount;
  final ChatScreenArgs args;
  final ValueNotifier<bool> isOtherUserTyping;
  final Animation<double> appBarAnimation;
  final int secretAutoDeleteSeconds;
  final String secretAutoDeleteLabel;
  final String secretAutoDeleteStatusText;
  final VoidCallback onExitSelectionMode;
  final VoidCallback? onForwardSelected;
  final VoidCallback? onCopySelected;
  final VoidCallback? onDeleteSelected;
  final void Function(String) onMenuAction;
  final VoidCallback onBack;
  final ProfileModel? otherUserProfile;
  final bool isOtherUserBlocked;
  final bool isCurrentUserBlocked;
  final bool isLoadingGroupMembers;
  final List<dynamic> groupMembers;
  final VoidCallback onTitleTap;
  final int pinnedMessageCount;
  final VoidCallback? onPinnedMessageTap;

  const ModernChatAppBar({
    super.key,
    required this.theme,
    required this.isSelectionMode,
    required this.selectedMessagesCount,
    required this.args,
    required this.isOtherUserTyping,
    required this.appBarAnimation,
    required this.secretAutoDeleteSeconds,
    required this.secretAutoDeleteLabel,
    required this.secretAutoDeleteStatusText,
    required this.onExitSelectionMode,
    this.onForwardSelected,
    this.onCopySelected,
    this.onDeleteSelected,
    required this.onMenuAction,
    required this.onBack,
    this.otherUserProfile,
    required this.isOtherUserBlocked,
    required this.isCurrentUserBlocked,
    required this.isLoadingGroupMembers,
    required this.groupMembers,
    required this.onTitleTap,
    this.pinnedMessageCount = 0,
    this.onPinnedMessageTap,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (pinnedMessageCount > 0 ? 18.0 : 0.0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isSelectionMode) {
      return _buildSelectionAppBar(context);
    }

    final appBarColor =
        args.isSecret ? const Color(0xFF1B3D2F) : theme.appBarColor;

    return AppBar(
      elevation: 0,
      backgroundColor: appBarColor,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: (theme.isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark)
          .copyWith(
        statusBarColor: appBarColor,
        systemStatusBarContrastEnforced: false,
      ),
      leading: IconButton(
        icon: Icon(
          directionalBackIcon(context, ios: true),
          color: theme.textColor,
          size: 20,
        ),
        onPressed: onBack,
      ),
      titleSpacing: 0,
      title: FadeTransition(
        opacity: appBarAnimation,
        child: _buildAppBarTitle(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: theme.iconColor),
          onSelected: onMenuAction,
          itemBuilder: (context) => [
            if (args.isGroup)
              PopupMenuItem(
                value: 'group_manage',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        color: theme.iconColor, size: 20),
                    const SizedBox(width: 12),
                    const Text('مدیریت گروه'),
                  ],
                ),
              ),
            if (args.isGroup)
              PopupMenuItem(
                value: 'group_invite',
                child: Row(
                  children: [
                    Icon(Icons.link_rounded, color: theme.iconColor, size: 20),
                    const SizedBox(width: 12),
                    const Text('کپی لینک دعوت'),
                  ],
                ),
              ),
            if (args.isGroup)
              PopupMenuItem(
                value: 'group_add_members',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: theme.iconColor, size: 20),
                    const SizedBox(width: 12),
                    const Text('افزودن عضو'),
                  ],
                ),
              ),
            if (!args.isSecret && !args.isGroup && args.otherUserId.isNotEmpty)
              const PopupMenuItem(
                value: 'start_secret_chat',
                child: Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.green, size: 20),
                    SizedBox(width: 12),
                    Text('شروع گفتگوی محرمانه',
                        style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            if (args.isSecret)
              PopupMenuItem(
                value: 'secret_timer',
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Text('تایمر حذف خودکار ($secretAutoDeleteLabel)',
                        style: const TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'search',
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.iconColor, size: 20),
                  const SizedBox(width: 12),
                  const Text('جستجو'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: theme.iconColor, size: 20),
                  const SizedBox(width: 12),
                  Text(args.isGroup ? 'اطلاعات گروه' : 'جزئیات چت'),
                ],
              ),
            ),
            if (!args.isGroup && args.otherUserId.isNotEmpty)
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    const Text('مسدود کردن',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(BuildContext context) {
    final appBarColor = theme.sendButtonColor;
    return AppBar(
      elevation: 0,
      backgroundColor: appBarColor,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: appBarColor,
        systemStatusBarContrastEnforced: false,
      ),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: onExitSelectionMode,
      ),
      title: Text(
        '$selectedMessagesCount انتخاب شده'.toPersianDigit(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (!args.isSecret)
          IconButton(
            icon: const Icon(Icons.forward_rounded, color: Colors.white),
            onPressed: onForwardSelected,
            tooltip: 'فوروارد',
          ),
        if (!args.isSecret)
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white),
            onPressed: onCopySelected,
            tooltip: 'کپی',
          ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          onPressed: onDeleteSelected,
          tooltip: 'حذف',
        ),
      ],
    );
  }

  Widget _buildAppBarTitle(BuildContext context) {
    return GestureDetector(
      onTap: onTitleTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarWithOnlineIndicator(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        args.isGroup
                            ? args.otherUserName
                            : (otherUserProfile?.fullName ??
                                args.otherUserName),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (args.isSecret) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_rounded,
                          color: Colors.green, size: 14),
                    ],
                  ],
                ),
                if (isOtherUserBlocked || isCurrentUserBlocked)
                  Text(
                    isCurrentUserBlocked
                        ? 'شما مسدود شده‌اید'
                        : 'کاربر مسدود شده',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  )
                else if (args.isSecret)
                  Row(
                    children: [
                      Icon(
                        secretAutoDeleteSeconds > 0
                            ? Icons.timer_rounded
                            : Icons.timer_off_outlined,
                        size: 13,
                        color: secretAutoDeleteSeconds > 0
                            ? Colors.greenAccent
                            : theme.secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          secretAutoDeleteStatusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secretAutoDeleteSeconds > 0
                                ? Colors.greenAccent
                                : theme.secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                else if (args.isGroup)
                  _buildGroupPresenceSummary()
                else
                  ValueListenableBuilder<bool>(
                    valueListenable: isOtherUserTyping,
                    builder: (context, isTyping, _) {
                      return ModernOnlineStatus(
                        userId: args.otherUserId,
                        isTyping: isTyping,
                        textStyle: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                if (pinnedMessageCount > 0)
                  GestureDetector(
                    onTap: onPinnedMessageTap,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 11,
                            color: theme.sendButtonColor.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '$pinnedMessageCount پیام پین شده',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  theme.sendButtonColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupPresenceSummary() {
    if (isLoadingGroupMembers && groupMembers.isEmpty) {
      return Text(
        'در حال بررسی اعضا...',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 12,
        ),
      );
    }

    if (groupMembers.isEmpty) {
      return Text(
        'گروه',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.secondaryTextColor,
          fontSize: 12,
        ),
      );
    }

    return Text(
      '${groupMembers.length} عضو'.toPersianDigit(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: theme.secondaryTextColor,
        fontSize: 12,
      ),
    );
  }

  Widget _buildAvatarWithOnlineIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2, right: 2),
      child: _buildAvatar(),
    );
  }

  Widget _buildAvatar() {
    if (args.isGroup) {
      if (args.otherUserAvatar != null && args.otherUserAvatar!.isNotEmpty) {
        return ClipOval(
          child: CachedNetworkImage(
            imageUrl: args.otherUserAvatar!,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(color: Colors.white),
            ),
            errorWidget: (context, url, error) => Container(
              color: theme.inputBackgroundColor,
              child: Icon(Icons.group, color: theme.iconColor),
            ),
          ),
        );
      }
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: theme.sendButtonColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.group, color: theme.sendButtonColor),
      );
    }

    if (otherUserProfile?.avatarUrl != null &&
        otherUserProfile!.avatarUrl!.isNotEmpty) {
      final avatarUrl = otherUserProfile!.avatarUrl!;
      return Hero(
        tag: 'avatar_${args.otherUserId}',
        child: ClipOval(
          child: avatarUrl.startsWith('/')
              ? Image.file(
                  File(avatarUrl),
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildAvatarText(),
                )
              : CachedNetworkImage(
                  imageUrl: avatarUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => _buildAvatarText(),
                ),
        ),
      );
    }
    return _buildAvatarText();
  }

  Widget _buildAvatarText() {
    return Hero(
      tag: 'avatar_${args.otherUserId}',
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: theme.sendButtonColor,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          args.otherUserName.isNotEmpty
              ? args.otherUserName.substring(0, 1).toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
