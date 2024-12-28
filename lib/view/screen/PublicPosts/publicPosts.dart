import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../util/widgets.dart';
import 'AddPost.dart';
import 'profileScreen.dart';

class PublicPostsScreen extends ConsumerWidget {
  const PublicPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentColor = ref.watch(themeProvider);
    final getProfile = ref.watch(profileProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'کافه ویستا',
            style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                fontFamily: 'vazier'),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white // رنگ زیر تب انتخاب شده
                : Colors.black,
            labelColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black, // رنگ متن تب انتخاب شده
            unselectedLabelColor:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black, // رنگ متن تب‌های انتخاب نشده
            tabs: const [
              Tab(text: 'همه پست‌ها'),
              Tab(text: 'پست‌های دنبال‌شده‌ها'),
            ],
          ),
        ),
        endDrawer: CustomDrawer(getProfile, currentColor, context, ref),
        body: const TabBarView(
          children: [
            _AllPostsTab(),
            _FollowingPostsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          child: const Icon(Icons.edit),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AddPublicPostScreen(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AllPostsTab extends ConsumerWidget {
  const _AllPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(fetchPublicPosts);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(fetchPublicPosts);
      },
      child: postsAsyncValue.when(
        data: (posts) => _buildPostList(context, ref, posts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('دسترسی به اینترنت قطع است :('),
            IconButton(
              iconSize: 50,
              splashColor: Colors.transparent,
              color: Colors.white,
              onPressed: () {
                ref.invalidate(fetchPublicPosts);
                ref.invalidate(commentsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        )),
      ),
    );
  }
}

class _FollowingPostsTab extends ConsumerWidget {
  const _FollowingPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingPostsAsyncValue = ref.watch(fetchFollowingPostsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.refresh(fetchFollowingPostsProvider);
      },
      child: followingPostsAsyncValue.when(
        data: (posts) => _buildPostList(context, ref, posts),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('دسترسی به اینترنت قطع است :('),
            IconButton(
              iconSize: 50,
              splashColor: Colors.transparent,
              color: Colors.white,
              onPressed: () {
                ref.invalidate(fetchPublicPosts);
                ref.invalidate(commentsProvider);
              },
              icon: const Icon(Icons.refresh),
            ),
          ],
        )),
      ),
    );
  }
}

Widget _buildPostList(
    BuildContext context, WidgetRef ref, List<PublicPostModel> posts) {
  if (posts.isEmpty) {
    return const Center(child: Text('هیچ پستی وجود ندارد.'));
  }

  return ListView.builder(
    itemCount: posts.length,
    itemBuilder: (context, index) {
      final post = posts[index];

      DateTime createdAt = post.createdAt.toLocal();
      Jalali jalaliDate = Jalali.fromDateTime(createdAt);
      String formattedDate =
          '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: GestureDetector(
                onTap: () {
                  // انتقال به صفحه پروفایل با کلیک روی عکس
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: post.userId,
                        username: post.username,
                      ),
                    ),
                  );
                },
                child: CircleAvatar(
                  backgroundImage: post.avatarUrl.isEmpty
                      ? const AssetImage('lib/util/images/default-avatar.jpg')
                      : NetworkImage(post.avatarUrl),
                ),
              ),
              title: GestureDetector(
                onTap: () {
                  // انتقال به صفحه پروفایل با کلیک روی نام کاربری
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        userId: post.userId,
                        username: post.username,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      post.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    if (post.isVerified)
                      const Icon(Icons.verified,
                          color: Colors.blue, size: 16.0),
                  ],
                ),
              ),
              subtitle: Text(
                formattedDate,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              trailing: _buildPostActions(context, ref, post),
            ),
            const SizedBox(height: 8),
            Directionality(
              textDirection: getDirectionality(post.content),
              child: Text(
                post.content,
                textAlign: getTextAlignment(post.content),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                IconButton(
                  icon: Icon(
                    post.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: post.isLiked ? Colors.red : null,
                  ),
                  onPressed: () async {
                    post.isLiked = !post.isLiked;
                    post.likeCount += post.isLiked ? 1 : -1;
                    (context as Element).markNeedsBuild();
                    await ref.watch(supabaseServiceProvider).toggleLike(
                          postId: post.id,
                          ownerId: post.userId,
                          ref: ref,
                        );
                  },
                ),
                Text('${post.likeCount}'),
                const SizedBox(width: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment),
                      onPressed: () {
                        showCommentsBottomSheet(
                            context, ref, post.id, post.userId);
                      },
                    ),
                    Text('${post.commentCount}')
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    String sharePost =
                        'کاربر ${post.username} به شما ارسال کرد:\n\n${post.content}';
                    Share.share(sharePost);
                  },
                ),
              ],
            ),
            const Divider(),
          ],
        ),
      );
    },
  );
}

PopupMenuButton<String> _buildPostActions(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  final currentUserId = Supabase.instance.client.auth.currentUser?.id;
  return PopupMenuButton<String>(
    onSelected: (value) async {
      switch (value) {
        case 'report':
          if (post.userId != currentUserId) {
            return showDialog(
              context: context,
              builder: (context) => ReportDialog(post: post),
            );
          }

          break;
        case 'copy':
          Clipboard.setData(ClipboardData(text: post.content));
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('متن کپی شد!')));
          break;
        case 'delete':
          if (post.userId == currentUserId) {
            final confirmed = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('حذف پست'),
                content: const Text('آیا از حذف این پست اطمینان دارید؟'),
                actions: [
                  TextButton(
                    style: ButtonStyle(
                      overlayColor: WidgetStateProperty.all(
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.white12 // افکت لمس در تم تاریک
                            : Colors.black12, // افکت لمس در تم روشن
                      ),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'انصراف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300] // رنگ روشن‌تر برای تم تاریک
                            : Colors.grey[800], // رنگ تیره‌تر برای تم روشن
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.red[700] // رنگ دکمه در تم تاریک
                              : Colors.red, // رنگ دکمه در تم روشن
                      shadowColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.grey[400], // سایه
                      elevation: 5,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'حذف',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors
                            .white, // Text color remains white for both themes
                      ),
                    ),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.watch(supabaseServiceProvider).deletePost(ref, post.id);
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('پست حذف شد!')));
            }
          }
          break;
      }
    },
    itemBuilder: (context) => [
      if (post.userId != currentUserId)
        const PopupMenuItem(value: 'report', child: Text('گزارش')),
      const PopupMenuItem(value: 'copy', child: Text('کپی')),
      if (post.userId == currentUserId)
        const PopupMenuItem(value: 'delete', child: Text('حذف')),
    ],
  );
}
