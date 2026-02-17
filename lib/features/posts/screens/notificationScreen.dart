import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../model/notificationModel.dart';
import '../../../provider/notification_provider.dart';
import 'package:Vista/services/notification_navigation_service.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';
import 'package:Vista/utils/verification_badge_utils.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  final Set<String> _requestActionLoading = <String>{};
  static const double _timeColumnWidth = 96;

  @override
  void initState() {
    super.initState();
    Future.microtask(_markNotificationsAsRead);
  }

  Future<void> _markNotificationsAsRead() async {
    await ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  Widget _buildTabsShimmer() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            5,
            (_) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 80,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 85, height: 14, color: Colors.white),
                      const Spacer(),
                      Container(width: 40, height: 11, color: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 180,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListShimmer() => ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => _buildSkeleton(),
      );

  Widget _buildVerificationBadge(NotificationModel notification) {
    final resolvedType = resolveVerificationBadgeType(
      isVerified: notification.userIsVerified,
      verificationType: notification.verificationType,
    );
    if (resolvedType == ResolvedVerificationBadgeType.none) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: VerificationBadgeIcon(
        isVerified: notification.userIsVerified,
        verificationType: notification.verificationType,
        size: 16,
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (NotificationModel.canonicalType(type)) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment_rounded;
      case 'comment_reply':
        return Icons.reply_rounded;
      case 'follow':
        return Icons.person_add_rounded;
      case 'follow_request':
        return Icons.person_add_alt_1_rounded;
      case 'follow_request_accepted':
        return Icons.check_circle_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'suggest_follow':
        return Icons.group_add_rounded;
      case 'suggest_post':
        return Icons.auto_awesome_rounded;
      case 'daily_suggestion_digest':
        return Icons.wb_sunny_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotificationIconColor(String type) {
    switch (NotificationModel.canonicalType(type)) {
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blue;
      case 'comment_reply':
        return Colors.orange;
      case 'follow':
      case 'follow_request_accepted':
        return Colors.green;
      case 'follow_request':
        return Colors.amber.shade700;
      case 'mention':
        return Colors.purple;
      case 'suggest_follow':
        return Colors.teal;
      case 'suggest_post':
        return Colors.deepOrange;
      case 'daily_suggestion_digest':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _formatNotificationTime(DateTime createdAt) {
    final now = DateTime.now();
    final localCreatedAt = createdAt.toLocal();
    final diff = now.difference(localCreatedAt);

    if (diff.isNegative || diff.inMinutes < 1) {
      return 'همین الان';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes} دقیقه پیش';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours} ساعت پیش';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} روز پیش';
    }

    final year = localCreatedAt.year;
    final month = localCreatedAt.month.toString().padLeft(2, '0');
    final day = localCreatedAt.day.toString().padLeft(2, '0');
    return '$year/$month/$day';
  }

  Future<void> _openNotification(NotificationModel notification) async {
    if (!notification.isRead) {
      await ref
          .read(notificationsProvider.notifier)
          .markAsRead(notification.id);
    }

    if (!mounted) return;
    await NotificationNavigationService.handleNotificationNavigation(
      context: context,
      notification: notification,
    );
  }

  Future<void> _handleFollowRequestAction(
    NotificationModel notification, {
    required bool accept,
  }) async {
    final actionKey = notification.id;
    if (_requestActionLoading.contains(actionKey)) return;

    setState(() {
      _requestActionLoading.add(actionKey);
    });

    final result =
        await ref.read(notificationsProvider.notifier).respondToFollowRequest(
              requesterId: notification.senderId,
              accept: accept,
              notificationId: notification.id,
            );

    if (!mounted) return;

    setState(() {
      _requestActionLoading.remove(actionKey);
    });

    final isSuccess = result.state == FollowRequestActionState.success;
    final isHandled = result.state == FollowRequestActionState.alreadyHandled;
    final backgroundColor = isSuccess
        ? Colors.green
        : isHandled
            ? Colors.orange
            : Colors.red;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFollowRequestActions(NotificationModel notification) {
    final isLoading = _requestActionLoading.contains(notification.id);
    return Row(
      children: [
        OutlinedButton(
          onPressed: isLoading
              ? null
              : () => _handleFollowRequestAction(
                    notification,
                    accept: false,
                  ),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: const Text('رد'),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: isLoading
              ? null
              : () => _handleFollowRequestAction(
                    notification,
                    accept: true,
                  ),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('پذیرفتن'),
        ),
      ],
    );
  }

  Widget _buildNotificationsList(
    BuildContext context,
    List<NotificationModel> notifications,
  ) {
    final notifier = ref.watch(notificationsProvider.notifier);
    final hasMore = notifier.hasMore;
    final isFetching = notifier.isFetching;

    if (notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'اعلانی برای این بخش وجود ندارد',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref
                    .read(notificationsProvider.notifier)
                    .checkConnectionAndRetry(),
                child: const Text('بررسی مجدد'),
              ),
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 240) {
          notifier.fetchMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: notifications.length + (hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= notifications.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: isFetching
                    ? const CircularProgressIndicator()
                    : const SizedBox.shrink(),
              ),
            );
          }

          final notification = notifications[index];
          final canonicalType =
              NotificationModel.canonicalType(notification.type);
          final isUnread = !notification.isRead;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final highlightColor =
              Theme.of(context).primaryColor.withValues(alpha: 0.06);

          return Column(
            children: [
              Material(
                color: isUnread ? highlightColor : Colors.transparent,
                child: InkWell(
                  onTap: () => _openNotification(notification),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 3,
                            height: 54,
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: (notification.avatarUrl == null ||
                                        notification.avatarUrl!.isEmpty)
                                    ? Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey.shade300,
                                        child: const Icon(Icons.person,
                                            color: Colors.white, size: 32),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: notification.avatarUrl!,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey.shade300,
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey.shade300,
                                          child: const Icon(Icons.person,
                                              color: Colors.white, size: 32),
                                        ),
                                      ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Icon(
                                  _getNotificationIcon(canonicalType),
                                  size: 14,
                                  color:
                                      _getNotificationIconColor(canonicalType),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.username.isNotEmpty
                                            ? notification.username
                                            : 'کاربر',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14.5,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _buildVerificationBadge(notification),
                                    if (isUnread)
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.content,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.8,
                                    height: 1.35,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                                if (canonicalType == 'follow_request') ...[
                                  const SizedBox(height: 10),
                                  _buildFollowRequestActions(notification),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: _timeColumnWidth,
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Text(
                                _formatNotificationTime(notification.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 86, left: 14),
                child: Divider(
                  height: 1,
                  thickness: 0.6,
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationsProvider);
    final notifier = ref.watch(notificationsProvider.notifier);
    final isInitialLoading =
        notifications.isEmpty && (notifier.isFetching || notifier.hasMore);

    const tabs = <_NotificationTabData>[
      _NotificationTabData(
          title: 'همه', type: 'all', icon: Icons.notifications),
      _NotificationTabData(
        title: 'درخواست‌ها',
        type: 'follow_request',
        icon: Icons.person_add_alt_1_rounded,
      ),
      _NotificationTabData(
        title: 'دنبال‌کننده‌ها',
        type: 'follow',
        icon: Icons.person_add_rounded,
      ),
      _NotificationTabData(
          title: 'لایک‌ها', type: 'like', icon: Icons.favorite),
      _NotificationTabData(
        title: 'کامنت‌ها',
        type: 'comment',
        icon: Icons.comment_rounded,
      ),
      _NotificationTabData(
        title: 'پاسخ‌ها',
        type: 'comment_reply',
        icon: Icons.reply_rounded,
      ),
      _NotificationTabData(
        title: 'منشن‌ها',
        type: 'mention',
        icon: Icons.alternate_email_rounded,
      ),
      _NotificationTabData(
        title: 'پیشنهادها',
        type: 'daily_suggestion_digest',
        icon: Icons.auto_awesome_rounded,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعلان‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: _markNotificationsAsRead,
            tooltip: 'علامت‌گذاری همه به عنوان خوانده شده',
          ),
        ],
      ),
      body: isInitialLoading
          ? Column(
              children: [
                _buildTabsShimmer(),
                Expanded(child: _buildListShimmer()),
              ],
            )
          : DefaultTabController(
              length: tabs.length,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: ButtonsTabBar(
                      backgroundColor: Theme.of(context).primaryColor,
                      unselectedBackgroundColor: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      unselectedLabelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      radius: 18,
                      borderWidth: 1,
                      borderColor: isDarkMode
                          ? Colors.transparent
                          : Colors.grey.shade300,
                      unselectedBorderColor: isDarkMode
                          ? Colors.transparent
                          : Colors.grey.shade300,
                      height: 40,
                      tabs: tabs
                          .map(
                            (tab) => Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tab.icon),
                                  const SizedBox(width: 6),
                                  Text(tab.title),
                                  Builder(
                                    builder: (_) {
                                      final unreadCount = ref.watch(
                                        unreadNotificationCountByFilterProvider(
                                          tab.type,
                                        ),
                                      );
                                      if (unreadCount <= 0) {
                                        return const SizedBox.shrink();
                                      }
                                      return Container(
                                        margin: const EdgeInsets.only(right: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDarkMode
                        ? Colors.grey.shade800.withValues(alpha: 0.5)
                        : Colors.grey.shade200,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: tabs.map((tab) {
                        return Builder(
                          builder: (context) {
                            final filtered = ref
                                .watch(filteredNotificationsProvider(tab.type));
                            return RefreshIndicator(
                              onRefresh: () async {
                                await ref
                                    .read(notificationsProvider.notifier)
                                    .refresh();
                              },
                              color: Theme.of(context).primaryColor,
                              backgroundColor: Theme.of(context).cardColor,
                              child: _buildNotificationsList(context, filtered),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _NotificationTabData {
  const _NotificationTabData({
    required this.title,
    required this.type,
    required this.icon,
  });

  final String title;
  final String type;
  final IconData icon;
}
