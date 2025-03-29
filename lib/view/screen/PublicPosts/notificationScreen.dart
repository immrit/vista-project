import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../main.dart';
import '../../../model/notificationModel.dart';
import '/view/screen/PublicPosts/profileScreen.dart';
import '../../../provider/provider.dart';
import '../../util/const.dart';
import 'PostDetailPage.dart';

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super([]);

  Future<void> fetchNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not logged in");
    }

    final response = await supabase
        .from('notifications')
        .select(
            '*, sender:profiles!notifications_sender_id_fkey(username, avatar_url, is_verified)')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false);

    final notifications =
        response.map((item) => NotificationModel.fromMap(item)).toList();

    state = notifications;
  }

  Future<void> deleteAllNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception("User not logged in");
    }

    await supabase.from('notifications').delete().eq('recipient_id', userId);

    state = [];
  }
}

final notificationsProvider = StateNotifierProvider.autoDispose<
    NotificationsNotifier, List<NotificationModel>>((ref) {
  return NotificationsNotifier()..fetchNotifications();
});

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState {
  bool _isDisposed = false;
  StreamSubscription? _notificationListener;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notificationListener?.cancel();
    super.dispose();
  }

  Future _markNotificationsAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || _isDisposed) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);

      if (!_isDisposed) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(hasNewNotificationProvider);
      }
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  void _listenToNotifications() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationListener = supabase
        .from('notifications')
        .stream(primaryKey: ['id']).listen((data) {
      if (!_isDisposed) {
        ref.invalidate(notificationsProvider);
      }
    });
  }

// تابع برای نمایش نشان تأیید
  Widget _buildVerificationBadge(Map<String, dynamic>? userData) {
    // بررسی وضعیت تأیید حساب کاربری
    final bool isVerified = userData?['is_verified'] ?? false;
    if (!isVerified) {
      return const SizedBox.shrink();
    }

    // بررسی نوع نشان تأیید
    final String verificationType = userData?['verification_type'] ?? 'none';
    IconData iconData = Icons.verified;
    Color iconColor = Colors.blue;

    // تعیین نوع و رنگ آیکون بر اساس نوع نشان
    switch (verificationType) {
      case 'blueTick':
        iconData = Icons.verified;
        iconColor = Colors.blue;
        break;
      case 'goldTick':
        iconData = Icons.verified;
        iconColor = Colors.amber;
        break;
      case 'blackTick':
        iconData = Icons.verified;
        iconColor = const Color(0xFF303030); // رنگ مشکی متمایل به خاکستری تیره
        break;
      default:
        // حالت پیش‌فرض برای پروفایل‌های تأیید شده بدون نوع مشخص
        iconData = Icons.verified;
        iconColor = Colors.blue;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Icon(iconData, color: iconColor, size: 16),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('اعلان‌ها')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
        },
        child: notifications.isEmpty
            ? const Center(child: Text('اعلان جدیدی وجود ندارد'))
            : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Column(
                    children: [
                      ListTile(
                        leading: GestureDetector(
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
                          child: CircleAvatar(
                            backgroundImage: notification.avatarUrl.isEmpty
                                ? const AssetImage(defaultAvatarUrl)
                                : CachedNetworkImageProvider(
                                    notification.avatarUrl),
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(notification.username),
                            const SizedBox(width: 5),
                            _buildVerificationBadge({
                              'is_verified': notification.userIsVerified,
                              'verification_type':
                                  notification.verificationType,
                            }),
                          ],
                        ),
                        subtitle: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(notification.content,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        trailing: Icon(
                          notification.isRead
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: notification.isRead
                              ? Colors.green
                              : const Color.fromARGB(255, 137, 127, 127),
                        ),
                        onTap: () {
                          if (notification.type == 'like' ||
                              notification.type == 'new_comment' ||
                              notification.type == 'mention' ||
                              notification.type == 'comment_reply') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailsPage(
                                    postId: notification.PostId),
                              ),
                            );
                            ref.invalidate(
                                commentsProvider(notification.PostId));
                          }
                        },
                      ),
                      Divider(
                        endIndent: 20,
                        indent: 20,
                        color: Colors.grey[200],
                      ),
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'delete_notifications',
            mini: true,
            backgroundColor: Colors.red,
            onPressed: () async {
              if (_isDisposed) return;

              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text('آیا از حذف اعلان‌ها اطمینان دارید؟'),
                  ),
                  content: const Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text('تمامی اعلان‌های شما حذف خواهند شد.'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('لغو'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('حذف'),
                    ),
                  ],
                ),
              );

              if (shouldDelete == true && !_isDisposed) {
                try {
                  await ref
                      .read(notificationsProvider.notifier)
                      .deleteAllNotifications();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('همه اعلان‌ها حذف شدند')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف اعلان‌ها: $e')),
                  );
                }
              }
            },
            child: const Icon(Icons.delete),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'refresh_notifications',
            onPressed: () {
              if (!_isDisposed) {
                ref.invalidate(notificationsProvider);
              }
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
