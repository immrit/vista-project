import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';
import '/main.dart';
import '/util/const.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../util/widgets.dart';
import 'followers and followings/FollowersScreen.dart';
import 'followers and followings/FollowingScreen.dart';
import '../ouathUser/editeProfile.dart';
// در فایل ProfileScreen:

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String username;

  const ProfileScreen(
      {super.key, required this.userId, required this.username});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // واکشی اطلاعات پروفایل در اینجا
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider(widget.userId));
    final currentUser = ref.watch(authProvider);
    final getprofile = ref.watch(profileProvider);
    final currentcolor = ref.watch(themeProvider);
    final isCurrentUserProfile = profileState != null &&
        currentUser != null &&
        profileState.id == currentUser.id;

    return Scaffold(
      endDrawer: isCurrentUserProfile
          ? CustomDrawer(getprofile, currentcolor, context, ref)
          : null,
      body: profileState == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshProfile, // متد برای به‌روزرسانی

              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(profileState, getprofile, currentcolor,
                      isCurrentUserProfile),
                  _buildPostsList(profileState),
                ],
              ),
            ),
      // floatingActionButton: profileState != null &&
      //         currentUser != null &&
      //         profileState.id == currentUser.id
      //     ? FloatingActionButton(
      //         child: const Icon(Icons.edit),
      //         onPressed: () {
      //           Navigator.of(context).push(
      //             MaterialPageRoute(
      //               builder: (context) => const AddPublicPostScreen(),
      //             ),
      //           );
      //         },
      //       )
      // : null, // زمانی که پروفایل مربوط به کاربر جاری نیست، null می‌شود
    );
  }

// متد به‌روزرسانی پروفایل
  Future<void> _refreshProfile() async {
    try {
      // واکشی مجدد پروفایل
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);

      // واکشی مجدد پست‌ها
      ref.read(postsProvider);

      ref.watch(commentsProvider(widget.userId));
    } catch (e) {
      // نمایش خطا در صورت وجود
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در به‌روزرسانی: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  SliverAppBar _buildSliverAppBar(ProfileModel profile, dynamic getprofile,
      ThemeData currentcolor, dynamic isCurrentUserProfile) {
    return SliverAppBar(
      expandedHeight: 320,
      backgroundColor: Brightness.dark == Theme.of(context).brightness
          ? Colors.grey[900]
          : null,
      floating: false,
      pinned: true,
      actions: [
        if (!isCurrentUserProfile) // اگر کاربر جاری در پروفایل خود نباشد
          PopupMenuButton(
            onSelected: (value) {
              showDialog(
                context: context,
                builder: (context) => ReportProfileDialog(
                  userId: widget.userId,
                ),
              );
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'report',
                  child: Text('گزارش کردن'),
                ),
              ];
            },
          )
      ],
      title: _buildAppBarTitle(profile),
      flexibleSpace: FlexibleSpaceBar(
        background: _buildProfileHeader(profile),
      ),
    );
  }

  Row _buildAppBarTitle(ProfileModel profile) {
    return Row(
      children: [
        Text(
          profile.username,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 5),
        if (profile.isVerified)
          const Icon(Icons.verified, color: Colors.blue, size: 16),
      ],
    );
  }

  Widget _buildProfileHeader(ProfileModel profile) {
    final bool isCurrentUserProfile = profile.id == ref.read(authProvider)?.id;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          _buildProfileInfo(profile, isCurrentUserProfile),
        ],
      ),
    );
  }

  Widget _buildProfileInfo(ProfileModel profile, bool isCurrentUserProfile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildProfileAvatar(profile),
            const Spacer(),
            _buildProfileActionButton(profile, isCurrentUserProfile),
          ],
        ),
        const SizedBox(height: 16),
        _buildProfileDetails(profile),
      ],
    );
  }

  Widget _buildProfileAvatar(ProfileModel profile) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: CircleAvatar(
        radius: 40,
        backgroundImage:
            profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
        child: profile.avatarUrl == null
            ? const CircleAvatar(
                backgroundImage: AssetImage(
                  defaultAvatarUrl,
                ),
                radius: 40,
              )
            : null,
      ),
    );
  }

  Widget _buildProfileActionButton(
      ProfileModel profile, bool isCurrentUserProfile) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isCurrentUserProfile
            ? Colors.black // پس‌زمینه مشکی برای دکمه ویرایش پروفایل
            : profile.isFollowed
                ? (isDarkTheme
                    ? Colors.white
                    : Colors.black) // پس‌زمینه برای حالت دنبال کردن
                : Colors.white, // پس‌زمینه برای حالت لغو دنبال کردن
        foregroundColor: isCurrentUserProfile
            ? Colors.white // متن سفید برای دکمه ویرایش پروفایل
            : profile.isFollowed
                ? (isDarkTheme
                    ? Colors.black // متن مشکی برای حالت دنبال کردن در تم تاریک
                    : Colors.white) // متن سفید برای حالت دنبال کردن در تم روشن
                : (isDarkTheme
                    ? Colors
                        .black // متن مشکی برای حالت لغو دنبال کردن در تم تاریک
                    : Colors
                        .black), // متن مشکی برای حالت لغو دنبال کردن در تم روشن
        side: BorderSide(
          color: isCurrentUserProfile
              ? Colors.transparent // بدون کادر برای ویرایش پروفایل
              : profile.isFollowed
                  ? Colors.transparent // بدون کادر برای حالت دنبال کردن
                  : (isDarkTheme
                      ? Colors
                          .black // کادر مشکی برای حالت لغو دنبال کردن در تم تاریک
                      : Colors
                          .black), // کادر مشکی برای حالت لغو دنبال کردن در تم روشن
        ),
      ),
      onPressed: () => isCurrentUserProfile
          ? Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const EditProfile()))
          : _toggleFollow(profile.id),
      child: Text(
        isCurrentUserProfile
            ? 'ویرایش پروفایل'
            : profile.isFollowed
                ? 'لغو دنبال کردن'
                : 'دنبال کردن',
      ),
    );
  }

  @override
  Widget _buildProfileDetails(ProfileModel profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.fullName,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (profile.bio != null) ...[
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(profile.bio!),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        FollowingScreen(userId: widget.userId),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  children: [
                    Text(
                      ' ${profile.followingCount}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'دنبال شونده ها ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        FollowersScreen(userId: widget.userId),
                  ),
                );
              },
              child: Column(
                children: [
                  Text(
                    ' ${profile.followersCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'دنبال کنندگان',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            GestureDetector(
              onTap: () => _buildPostsList,
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Column(
                  children: [
                    Text(
                      ' ${profile.posts.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      ' پست‌ها',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  SliverList _buildPostsList(ProfileModel profile) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (profile.posts.isEmpty) {
            return const Center(
              child: Text('هنوز پستی وجود ندارد'),
            );
          }
          return _buildPostItem(profile, profile.posts[index]);
        },
        childCount: profile.posts.isEmpty ? 1 : profile.posts.length,
      ),
    );
  }

  Widget _buildPostItem(ProfileModel profile, PublicPostModel post) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPostHeader(profile, post),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'report':
                      showDialog(
                        context: context,
                        builder: (context) => ReportDialog(post: post),
                      );
                      break;
                    case 'copy':
                      Clipboard.setData(ClipboardData(text: post.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('متن کپی شد!')));
                      break;
                    case 'delete':
                      bool confirmDelete = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('حذف پست'),
                          content:
                              const Text('آیا از حذف این پست اطمینان دارید؟'),
                          actions: <Widget>[
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    theme.textTheme.bodyLarge?.color,
                              ),
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('خیر'),
                            ),
                            TextButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.secondary,
                                foregroundColor: theme.colorScheme.onSecondary,
                              ),
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('بله'),
                            ),
                          ],
                        ),
                      );
                      if (confirmDelete ?? false) {
                        final supabaseService =
                            ref.read(supabaseServiceProvider);
                        try {
                          await supabaseService.deletePost(ref, post.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('پست حذف شد!')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('خطا در حذف پست!')));
                        }
                      }
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  final currentUserId = supabase.auth.currentUser?.id;
                  return <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'report',
                      child: Text('گزارش کردن'),
                    ),
                    const PopupMenuItem<String>(
                      value: 'copy',
                      child: Text('کپی کردن'),
                    ),
                    if (post.userId == currentUserId)
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Text('حذف'),
                      ),
                  ];
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Directionality(
              textDirection: getDirectionality(post.content),
              child: Text(
                post.content,
                textAlign: getTextAlignment(post.content),
              )),

          // اضافه کردن نمایش تصویر
          // در متد _buildPostItem، بعد از نمایش متن پست:
          // اضافه کردن نمایش تصویر در صورت وجود
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            PostImageViewer(imageUrl: post.imageUrl!),
          ],

          const SizedBox(height: 16),
          _buildPostActions(post),
        ],
      ),
    );
  }

  Widget _buildPostHeader(ProfileModel profile, PublicPostModel post) {
    DateTime createdAt = post.createdAt.toLocal();
    Jalali jalaliDate = Jalali.fromDateTime(createdAt);
    String formattedDate =
        '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: profile.avatarUrl != null
              ? NetworkImage(profile.avatarUrl!)
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  profile.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 5),
                if (profile.isVerified)
                  const Icon(Icons.verified, color: Colors.blue, size: 16),
              ],
            ),
            Text(
              formattedDate,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostActions(PublicPostModel post) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildLikeButton(post),
                _buildCommentButton(post),
                _buildShareButton(post),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Divider(
          endIndent: 1,
          indent: 1,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white10
              : Colors.black26, // رنگ متفاوت برای تم روشن
        )
      ],
    );
  }

  Widget _buildLikeButton(PublicPostModel post) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : null,
          ),
          onPressed: () => _toggleLike(post),
        ),
        Text('${post.likeCount}'),
      ],
    );
  }

  Widget _buildCommentButton(PublicPostModel post) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.comment),
          onPressed: () => _showComments(post),
        ),
        Text('${post.commentCount}'),
      ],
    );
  }

  Widget _buildShareButton(PublicPostModel post) {
    return IconButton(
      icon: const Icon(Icons.share),
      onPressed: () => _sharePost(post),
    );
  }

  void _toggleLike(PublicPostModel post) async {
    // به‌روزرسانی محلی
    final updatedPost = post.copyWith(
      isLiked: !post.isLiked,
      likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1,
    );

    ref
        .read(userProfileProvider(widget.userId).notifier)
        .updatePost(updatedPost);

    // ارسال درخواست به سرور
    try {
      if (updatedPost.isLiked) {
        await supabase.from('likes').insert({
          'post_id': updatedPost.id,
          'user_id': supabase.auth.currentUser!.id,
        });
      } else {
        await supabase
            .from('likes')
            .delete()
            .eq('post_id', updatedPost.id)
            .eq('user_id', supabase.auth.currentUser!.id);
      }
    } catch (e) {
      print('خطا در ثبت لایک: $e');
    }
  }

  void _toggleFollow(String userId) async {
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .toggleFollow(userId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در تغییر وضعیت فالو: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showComments(PublicPostModel post) {
    showCommentsBottomSheet(context, post.id, ref);
  }

  void _sharePost(PublicPostModel post) {
    String shareText = '${post.username}: \n\n${post.content}';
    Share.share(shareText);
  }
}

// اضافه کردن متد نمایش تصویر تمام صفحه
void _showFullScreenImage(BuildContext context, String imageUrl) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Hero(
              tag: imageUrl,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
