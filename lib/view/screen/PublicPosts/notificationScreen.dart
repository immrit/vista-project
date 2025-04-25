import 'dart:async';

import 'package:Vista/provider/notification_providers.dart';
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../main.dart';
import '../../../model/notificationModel.dart';
import '/view/screen/PublicPosts/profileScreen.dart';
import '../../util/const.dart';
import 'PostDetailPage.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState {
  bool _isDisposed = false;
  bool _isLoading = true;
  StreamSubscription? _notificationListener;

  @override
  void initState() {
    super.initState();
    // تنظیم زبان فارسی برای timeago
    timeago.setLocaleMessages('fa', timeago.FaMessages());

    // بارگذاری اولیه اعلان‌ها
    _initData();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationListener?.cancel();
    super.dispose();
  }

  Future<void> _initData() async {
    if (_isDisposed) return;

    setState(() {
      _isLoading = true;
    });

    await ref.read(notificationsProvider.notifier).fetchNotifications();
    await _markNotificationsAsRead();
    _listenToNotifications();

    if (!_isDisposed) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future _markNotificationsAsRead() async {
    if (_isDisposed) return;
    await ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  void _listenToNotifications() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationListener = supabase
        .from('notifications')
        .stream(primaryKey: ['id']).listen((data) {
      if (!_isDisposed) {
        ref.read(notificationsProvider.notifier).fetchNotifications();
      }
    });
  }

  // تابع برای نمایش نشان تأیید
  Widget _buildVerificationBadge(NotificationModel notification) {
    if (notification.hasBlueBadge) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        child: const Icon(Icons.verified, color: Colors.blue, size: 16),
      );
    } else if (notification.hasGoldBadge) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        child: const Icon(Icons.verified, color: Colors.amber, size: 16),
      );
    } else if (notification.hasBlackBadge) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(.1),
        decoration: const BoxDecoration(
          color: Colors.white60,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.verified, color: Colors.black, size: 16),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // تابع برای نمایش آیکون مناسب برای هر نوع اعلان
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'new_comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'mention':
        return Icons.alternate_email;
      case 'comment_reply':
        return Icons.reply;
      default:
        return Icons.notifications;
    }
  }

  // تابع برای نمایش رنگ آیکون هر نوع اعلان
  Color _getNotificationIconColor(String type) {
    switch (type) {
      case 'like':
        return Colors.red;
      case 'new_comment':
        return Colors.blue;
      case 'follow':
        return Colors.green;
      case 'mention':
        return Colors.purple;
      case 'comment_reply':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // تابع برای نمایش زمان اعلان به صورت نسبی (مثلا "۲ ساعت پیش")
  String _getTimeAgo(DateTime createdAt) {
    return timeago.format(createdAt, locale: 'fa');
  }

  // تابع برای نمایش اعلان‌ها
  Widget _buildNotificationsList(
      BuildContext context, List<NotificationModel> notifications) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'در حال بارگذاری اعلان‌ها...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (notifications.isEmpty) {
      return Center(
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
              'اعلانی وجود ندارد',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _initData(),
              child: const Text('بررسی مجدد'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: notification.isRead
              ? Colors.transparent
              : Colors.blue.withOpacity(0.05),
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (notification.type == 'like' ||
                    notification.type == 'new_comment' ||
                    notification.type == 'mention' ||
                    notification.type == 'comment_reply') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailsPage(
                        postId: notification.PostId,
                      ),
                    ),
                  );
                } else if (notification.type == 'follow') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: notification.senderId,
                        username: notification.username,
                      ),
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: notification.senderId,
                                  username: notification.username,
                                ),
                              ),
                            );
                          },
                          child: Hero(
                            tag: 'avatar-${notification.senderId}',
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: notification.avatarUrl.isEmpty
                                  ? const AssetImage(defaultAvatarUrl)
                                  : CachedNetworkImageProvider(
                                      notification.avatarUrl) as ImageProvider,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color:
                                  _getNotificationIconColor(notification.type),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              size: 12,
                              color: Colors.white,
                            ),
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
                              Text(
                                notification.username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (notification.userIsVerified)
                                _buildVerificationBadge(notification),
                              const Spacer(),
                              Text(
                                _getTimeAgo(notification.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.content,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // لیست تب‌ها برای نمایش
    final tabs = [
      {'type': 'all', 'title': 'همه'},
      {'type': 'like', 'title': 'لایک‌ها'},
      {'type': 'new_comment', 'title': 'نظرات'},
      {'type': 'follow', 'title': 'فالوها'},
      {'type': 'comment_reply', 'title': 'پاسخ‌ها'},
      {'type': 'mention', 'title': 'منشن‌ها'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اعلان‌ها'),
            if (unreadCount > 0)
              Text(
                '$unreadCount اعلان خوانده نشده',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'خواندن همه',
              onPressed: () => _markNotificationsAsRead(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _initData();
        },
        child: DefaultTabController(
          length: tabs.length,
          child: Column(
            children: [
              ButtonsTabBar(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.black,
                borderWidth: 1,
                borderColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                radius: 12,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                unselectedBackgroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF222222)
                        : Colors.white,
                unselectedBorderColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.3)
                        : Colors.black.withOpacity(0.3),
                labelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white // تم تاریک: متن مشکی روی زمینه سفید
                      : Colors.black, // تم روشن: متن سفید روی زمینه مشکی
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withOpacity(
                          0.9) // تم تاریک: متن سفید برای تب‌های غیرفعال
                      : Colors.black.withOpacity(
                          0.9), // تم روشن: متن مشکی برای تب‌های غیرفعال
                  fontWeight: FontWeight.normal,
                ),
                tabs: tabs.map((tab) {
                  final count = ref.watch(
                      notificationCountByTypeProvider(tab['type'] as String?));
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              count.toString(),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        SizedBox(
                          width: 1.5,
                        ),
                        Text(tab['title'] as String),
                      ],
                    ),
                  );
                }).toList(),
              ),
              Expanded(
                child: TabBarView(
                  children: tabs.map((tab) {
                    final filteredNotifications = tab['type'] == 'all'
                        ? notifications
                        : notifications
                            .where((n) => n.type == tab['type'])
                            .toList();
                    return _buildNotificationsList(
                        context, filteredNotifications);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: notifications.isNotEmpty
          ? FloatingActionButton(
              heroTag: 'delete_notifications',
              mini: true,
              backgroundColor: Colors.red,
              tooltip: 'پاک کردن همه اعلان‌ها',
              onPressed: () async {
                if (_isDisposed) return;

                final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('حذف اعلان‌ها'),
                        content: const Text(
                            'آیا از حذف تمامی اعلان‌ها اطمینان دارید؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('انصراف'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (shouldDelete && !_isDisposed) {
                  await ref
                      .read(notificationsProvider.notifier)
                      .deleteAllNotifications();
                  ref.invalidate(hasNewNotificationProvider);
                }
              },
              child: const Icon(Icons.delete_outline),
            )
          : null,
    );
  }
}
