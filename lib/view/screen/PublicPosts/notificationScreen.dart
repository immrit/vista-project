import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../model/notificationModel.dart';
import '../../../provider/notification_provider.dart';
import '/view/screen/PublicPosts/profileScreen.dart';
import '../../util/const.dart';
import 'PostDetailPage.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    _markNotificationsAsRead();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final notifier = ref.read(notificationsProvider.notifier);
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      notifier.fetchMore();
    }
  }

  Future<void> _markNotificationsAsRead() async {
    await ref.read(notificationsProvider.notifier).markAllAsRead();
  }

  // شیمر تب
  Widget _buildTabsShimmer() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 6),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
              6,
              (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 70,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  )),
        ),
      ),
    );
  }

  // شیمر کارت اعلان
  Widget _buildSkeleton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
        child: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Row(
            children: [
              // آواتار
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // متن
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // نام و زمان
                    Row(
                      children: [
                        Container(
                            width: 80,
                            height: 14,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 6)),
                        const SizedBox(width: 10),
                        Container(
                            width: 16,
                            height: 16,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 6)),
                        const Spacer(),
                        Container(
                            width: 38,
                            height: 11,
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 6)),
                      ],
                    ),
                    // محتوای پیام
                    Container(
                        width: double.infinity,
                        height: 12,
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 4)),
                    Container(
                        width: MediaQuery.of(context).size.width * 0.55,
                        height: 12,
                        color: Colors.white),
                  ],
                ),
              )
            ],
          ),
        ),
      );

  Widget _buildListShimmer() => ListView.builder(
        itemCount: 8,
        itemBuilder: (ctx, idx) => _buildSkeleton(),
      );

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

  String _getTimeAgo(DateTime createdAt) {
    return timeago.format(createdAt, locale: 'fa');
  }

  Widget _buildNotificationsList(
      BuildContext context, List<NotificationModel> notifications) {
    final notifier = ref.watch(notificationsProvider.notifier);
    final hasMore = notifier.hasMore;
    final isFetching = notifier.isFetching;

    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('اعلانی وجود ندارد',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _markNotificationsAsRead,
              child: const Text('بررسی مجدد'),
            )
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: notifications.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < notifications.length) {
          final notification = notifications[index];
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            color: notification.isRead
                ? Colors.transparent
                : Colors.blue.withOpacity(0.06),
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // نشانه گذاری اعلان به عنوان خوانده شده هنگام کلیک
                  if (!notification.isRead) {
                    ref
                        .read(notificationsProvider.notifier)
                        .markAsRead(notification.id);
                  }

                  if (['like', 'new_comment', 'mention', 'comment_reply']
                      .contains(notification.type)) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PostDetailsPage(postId: notification.PostId),
                        ));
                  } else if (notification.type == 'follow') {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            userId: notification.senderId,
                            username: notification.username,
                          ),
                        ));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // آواتار کاربر
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: (notification.avatarUrl.isEmpty)
                                  ? Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.person,
                                          color: Colors.white, size: 32),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: notification.avatarUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 48,
                                        height: 48,
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.person,
                                            color: Colors.white, size: 32),
                                      ),
                                    ),
                            ),
                          ),
                          // آیکون نوع اعلان
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getNotificationIcon(notification.type),
                                size: 14,
                                color: _getNotificationIconColor(
                                    notification.type),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // محتوای اعلان
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // نام کاربر و نشان تأیید
                            Row(
                              children: [
                                Text(
                                  notification.username,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.color,
                                  ),
                                ),
                                _buildVerificationBadge(notification),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const Spacer(),
                                Text(
                                  _getTimeAgo(notification.createdAt),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // متن اعلان
                            Text(
                              notification.content,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
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
        } else {
          // آیتم لودینگ انتهای لیست
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: isFetching
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationsProvider);
    // اگر نیاز به لودینگ دارید، از یک StateProvider یا متد دیگر استفاده کنید
    // final isLoading = ref.watch(notificationsLoadingProvider);

    // تعریف تب‌ها
    final _tabs = [
      {
        'title': 'همه',
        'type': 'all',
        'icon': Icons.notifications,
      },
      {
        'title': 'لایک‌ها',
        'type': 'like',
        'icon': Icons.favorite,
      },
      {
        'title': 'کامنت‌ها',
        'type': 'new_comment',
        'icon': Icons.comment,
      },
      {
        'title': 'دنبال کننده ها',
        'type': 'follow',
        'icon': Icons.person_add,
      },
      {
        'title': 'منشن‌ها',
        'type': 'mention',
        'icon': Icons.alternate_email,
      },
      {
        'title': 'پاسخ‌ها',
        'type': 'comment_reply',
        'icon': Icons.reply,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعلان‌ها'),
        centerTitle: true,
        actions: [
          // دکمه پاک کردن همه اعلان‌ها
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markNotificationsAsRead,
            tooltip: 'نشانه‌گذاری همه به عنوان خوانده شده',
          ),
        ],
      ),
      body: notifications.isEmpty
          ? Column(
              children: [
                _buildTabsShimmer(),
                Expanded(child: _buildListShimmer()),
              ],
            )
          : DefaultTabController(
              length: _tabs.length,
              child: Column(
                children: [
                  // تب‌های اعلان‌ها با طراحی بهبود یافته
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                    child: ButtonsTabBar(
                      backgroundColor: Theme.of(context).primaryColor,
                      unselectedBackgroundColor: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      unselectedLabelStyle: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.normal,
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
                      tabs: _tabs
                          .map(
                            (tab) => Tab(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tab['icon'] as IconData),
                                  const SizedBox(width: 8),
                                  Text(tab['title'] as String),
                                  // نمایش تعداد اعلان‌های خوانده نشده در کنار عنوان تب
                                  Builder(
                                    builder: (_) {
                                      final unreadCount = ref.watch(
                                          unreadNotificationCountByTypeProvider(
                                              tab['type'] as String));
                                      if (unreadCount > 0) {
                                        return Container(
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text("$unreadCount",
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold)),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  // جداکننده
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDarkMode
                        ? Colors.grey.shade800.withOpacity(0.5)
                        : Colors.grey.shade200,
                  ),
                  // محتوای اعلان‌ها
                  Expanded(
                    child: TabBarView(
                      children: _tabs
                          .map(
                            (tab) => Builder(
                              builder: (context) {
                                final filtered = ref.watch(
                                    filteredNotificationsProvider(
                                        tab['type'] as String));
                                return _buildNotificationsList(
                                    context, filtered);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Provider برای تعداد اعلان‌های خوانده نشده بر اساس نوع
final unreadNotificationCountByTypeProvider =
    Provider.family<int, String>((ref, type) {
  final notifications = ref.watch(notificationsProvider);

  // notifications یک List است و متد when ندارد
  if (type == 'all') {
    return notifications.where((n) => !n.isRead).length;
  } else {
    return notifications.where((n) => n.type == type && !n.isRead).length;
  }
});
