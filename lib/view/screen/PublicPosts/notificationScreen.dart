import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/util/widgets.dart';
import '/view/screen/PublicPosts/profileScreen.dart';
import '../../../provider/provider.dart';
import '../../../util/const.dart';
import 'PostDetailPage.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final getprofile = ref.watch(profileProvider);
    final currentcolor = ref.watch(themeProvider);
    return Scaffold(
      endDrawer: CustomDrawer(getprofile, currentcolor, context, ref),
      appBar: AppBar(
        title: const Text('اعلان ها'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
        },
        child: notifications.isEmpty
            ? const Center(child: Text('اعلان جدیدی وجود نداره'))
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
                                : NetworkImage(notification.avatarUrl),
                          ),
                        ),
                        title: GestureDetector(
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
                          child: Row(
                            children: [
                              Text(notification.username),
                              const SizedBox(width: 5),
                              if (notification.userIsVerified)
                                const Icon(Icons.verified,
                                    color: Colors.blue, size: 16),
                            ],
                          ),
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
                          if (notification.type == 'follow') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: notification.senderId,
                                  username: notification.username,
                                ),
                              ),
                            );
                          } else if (notification.type == 'like' ||
                              notification.type == 'comment' ||
                              notification.type == 'mention') {
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
                      )
                    ],
                  );
                },
              ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'delete_notifications', // برای جلوگیری از تداخل هیرو
            mini: true,
            backgroundColor: Colors.red,
            onPressed: () async {
              // نمایش دیالوگ تایید
              final bool? shouldDelete = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  final theme = Theme.of(context);

                  return AlertDialog(
                    title: const Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text('آیا از حذف اعلان‌ها اطمینان دارید؟')),
                    content: const Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text('تمامی اعلان‌های شما حذف خواهند شد.')),
                    actions: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.textTheme.bodyLarge?.color,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(false); // عدم تایید
                        },
                        child: const Text('لغو'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: theme.colorScheme.secondary,
                          foregroundColor: theme.colorScheme.onSecondary,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(true); // تایید
                        },
                        child: const Text('حذف'),
                      ),
                    ],
                  );
                },
              );

              // اگر کاربر تایید کرد، حذف انجام شود
              if (shouldDelete == true) {
                try {
                  await ref
                      .read(notificationsProvider.notifier)
                      .deleteAllNotifications();

                  // نمایش پیام موفقیت
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('همه اعلان‌ها حذف شدند')),
                  );
                } catch (e) {
                  // نمایش پیام خطا
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف اعلان‌ها: $e')),
                  );
                }
              }
            },
            child: const Icon(Icons.delete),
          ),
          const SizedBox(height: 10), // فاصله بین دکمه‌ها
          FloatingActionButton(
            heroTag: 'refresh_notifications',
            onPressed: () async {
              ref.refresh(notificationsProvider);
            },
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}
