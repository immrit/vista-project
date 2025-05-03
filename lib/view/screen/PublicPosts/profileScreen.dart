import 'package:Vista/view/screen/searchPage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../model/MusicModel.dart';
import '../../../provider/MusicProvider.dart';
import '../../../provider/chat_provider.dart';
import '../../util/const.dart';
import '../../util/widgets.dart';
import '../../widgets/CustomVideoPlayer.dart';
import '../chat/ChatScreen.dart';
import '/main.dart';
import '../../../model/ProfileModel.dart';
import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import 'MusicWaveform.dart';
import 'followers and followings/FollowersScreen.dart';
import 'followers and followings/FollowingScreen.dart';
import '../ouathUser/editeProfile.dart';
import 'publicPosts.dart';
import '../../widgets/ReelsScreen.dart'; // اضافه کن اگر نیست

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
              onRefresh: _refreshProfile,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(profileState, getprofile, currentcolor,
                      isCurrentUserProfile),
                  _buildPostsList(profileState),
                ],
              ),
            ),
    );
  }

  Future<void> _refreshProfile() async {
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .fetchProfile(widget.userId);
      ref.read(postsProvider);
      ref.watch(commentServiceProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطا در به‌روزرسانی: $e'),
            backgroundColor: Colors.red),
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
        if (!isCurrentUserProfile)
          PopupMenuButton(
            onSelected: (value) {
              showDialog(
                context: context,
                builder: (context) =>
                    ReportProfileDialog(userId: widget.userId),
              );
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                    value: 'report', child: Text('گزارش کردن')),
              ];
            },
          )
      ],
      title: _buildAppBarTitle(profile),
      flexibleSpace: FlexibleSpaceBar(background: _buildProfileHeader(profile)),
    );
  }

  Row _buildAppBarTitle(ProfileModel profile) {
    return Row(
      children: [
        Text(profile.username, style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 5),
        if (profile.isVerified) _buildVerificationBadge(profile),
      ],
    );
  }

  Widget _buildVerificationBadge(ProfileModel profile) {
    // نمایش تیک مناسب براساس نوع تأیید
    if (profile.hasBlueBadge) {
      return const Icon(Icons.verified, color: Colors.blue, size: 16);
    } else if (profile.hasGoldBadge) {
      return const Icon(Icons.verified, color: Colors.amber, size: 16);
    } else if (profile.hasBlackBadge) {
      return Container(
        padding: const EdgeInsets.all(.1), // فاصله باریک برای پس‌زمینه
        decoration: BoxDecoration(
          color: Colors.white60, // پس‌زمینه سفید
          shape: BoxShape.circle, // پس‌زمینه دایره‌ای
        ),
        child: const Icon(Icons.verified, color: Colors.black, size: 14),
      );
    } else {
      return const SizedBox.shrink(); // در صورت نداشتن تیک، چیزی نمایش نمی‌دهیم
    }
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
                backgroundImage: AssetImage(defaultAvatarUrl), radius: 40)
            : null,
      ),
    );
  }

  Widget _buildProfileActionButton(
      ProfileModel profile, bool isCurrentUserProfile) {
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;

    // اگر پروفایل خود کاربر است، فقط دکمه ویرایش پروفایل را نمایش می‌دهیم
    if (isCurrentUserProfile) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (context) => const EditProfile())),
        child: const Text('ویرایش پروفایل'),
      );
    }

    // برای پروفایل دیگران، هم دکمه دنبال کردن و هم دکمه ارسال پیام را نمایش می‌دهیم
    return Row(
      children: [
        // دکمه ارسال پیام
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkTheme ? Colors.white24 : Colors.blue,
            foregroundColor: isDarkTheme ? Colors.white : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => _startConversation(profile.id, profile.username),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.message, size: 16),
              SizedBox(width: 4),
              Text('ارسال پیام'),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // دکمه دنبال کردن
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: profile.isFollowed
                ? (isDarkTheme ? Colors.white : Colors.black)
                : Colors.white,
            foregroundColor: profile.isFollowed
                ? (isDarkTheme ? Colors.black : Colors.white)
                : (isDarkTheme ? Colors.black : Colors.black),
            side: BorderSide(
              color: profile.isFollowed
                  ? Colors.transparent
                  : (isDarkTheme ? Colors.black : Colors.black),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => _toggleFollow(profile.id),
          child: Text(profile.isFollowed ? 'لغو دنبال کردن' : 'دنبال کردن'),
        ),
      ],
    );
  }

  // متد برای شروع گفتگو با کاربر دیگر
  void _startConversation(String otherUserId, String otherUsername) async {
    try {
      // نمایش دادن یک نشانگر بارگذاری
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // ایجاد یا بازیابی مکالمه از طریق سرویس چت
      final chatService = ref.read(chatServiceProvider);
      final conversationId =
          await chatService.createOrGetConversation(otherUserId);

      // بستن نشانگر بارگذاری
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // انتقال به صفحه چت
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversationId,
              otherUserId: otherUserId,
              otherUserName: otherUsername,
            ),
          ),
        );
      }
    } catch (e) {
      print("خطای ایجاد گفتگو: $e");

      // بستن نشانگر بارگذاری در صورت بروز خطا
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // نمایش پیام خطا
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در ایجاد گفتگو: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFormattedDate(DateTime date) {
    Jalali jalaliDate = Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  Widget _buildProfileDetails(ProfileModel profile) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(profile.fullName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      if (profile.bio != null) ...[
        const SizedBox(height: 10),
        Directionality(
            textDirection: TextDirection.rtl, child: Text(profile.bio!)),
      ],
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => FollowingScreen(userId: widget.userId)));
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Column(
              children: [
                Text(' ${profile.followingCount}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text('دنبال شونده ها ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => FollowersScreen(userId: widget.userId)));
          },
          child: Column(
            children: [
              Text(' ${profile.followersCount}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Text('دنبال کنندگان',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Column(
              children: [
                Text(' ${profile.posts.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Text(' پست‌ها',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        )
      ])
    ]);
  }

  SliverList _buildPostsList(ProfileModel profile) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (profile.posts.isEmpty) {
            return const Center(child: Text('هنوز پستی وجود ندارد'));
          }
          return _buildPostItem(profile, profile.posts[index]);
        },
        childCount: profile.posts.isEmpty ? 1 : profile.posts.length,
      ),
    );
  }

  Widget _buildPostContent(PublicPostModel post, BuildContext context) {
    final pattern = RegExp(
      r'(#[\w\u0600-\u06FF]+)|((https?:\/\/)?([\w\-])+\.{1}([a-zA-Z]{2,63})([\/\w-]*)*\/?\??([^\s<>#]*))',
      multiLine: true,
      unicode: true,
    );
    List<TextSpan> spans = [];
    int start = 0;

    for (Match match in pattern.allMatches(post.content)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: post.content.substring(start, match.start),
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black),
        ));
      }
      final matchedText = match.group(0)!;
      if (matchedText.startsWith('#')) {
        spans.add(
          TextSpan(
            text: matchedText,
            style: const TextStyle(
                color: Colors.blue, fontWeight: FontWeight.bold),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SearchPage(initialHashtag: matchedText),
                  ),
                );
              },
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: matchedText,
            style: const TextStyle(
                color: Colors.blue, decoration: TextDecoration.underline),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                final url = matchedText.startsWith('http')
                    ? matchedText
                    : 'https://$matchedText';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
          ),
        );
      }
      start = match.end;
    }
    if (start < post.content.length) {
      spans.add(TextSpan(
        text: post.content.substring(start),
        style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.content.isNotEmpty)
          Directionality(
            textDirection: getDirectionality(post.content),
            child: RichText(text: TextSpan(children: spans)),
          ),
        if (post.musicUrl != null && post.musicUrl!.isNotEmpty)
          Consumer(
            builder: (context, ref, child) {
              final isPlaying = ref.watch(isPlayingProvider);
              final currentlyPlaying =
                  ref.watch(currentlyPlayingProvider).value;
              final isThisPlaying = currentlyPlaying?.musicUrl == post.musicUrl;
              final position = ref.watch(musicPositionProvider);
              final duration = ref.watch(musicDurationProvider);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[900]
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: MusicWaveform(
                  musicUrl: post.musicUrl!,
                  isPlaying: isPlaying && isThisPlaying,
                  position: position,
                  duration: duration,
                  onPlayPause: () {
                    if (isPlaying && isThisPlaying) {
                      ref.read(musicPlayerProvider.notifier).togglePlayPause();
                    } else {
                      final music = MusicModel(
                        id: post.id,
                        userId: post.userId,
                        title: post.title ?? 'موزیک',
                        artist: post.username,
                        musicUrl: post.musicUrl!,
                        createdAt: post.createdAt,
                        username: post.username,
                        avatarUrl: post.avatarUrl,
                        isVerified: post.isVerified,
                      );
                      ref.read(musicPlayerProvider.notifier).playMusic(music);
                    }
                  },
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        if (post.hashtags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: post.hashtags
                .map((tag) => GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SearchPage(initialHashtag: '#$tag'),
                        ),
                      ),
                      child: Text('#$tag',
                          style: const TextStyle(
                              color: Colors.blue, fontWeight: FontWeight.w500)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPostItem(ProfileModel profile, PublicPostModel post) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              CircleAvatar(
                  backgroundImage: profile.avatarUrl != null
                      ? NetworkImage(profile.avatarUrl!)
                      : null),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(profile.username,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 3),
                        _buildVerificationBadge(profile)
                      ],
                    ),
                    Text(_getFormattedDate(post.createdAt),
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              _buildPostMenu(context, post),
            ],
          ),
          const SizedBox(height: 12),
          // Content and Music section
          _buildPostContent(post, context),
          // Image section
          if (post.videoUrl != null && post.videoUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: VisibilityDetector(
                key: Key('profile_video_${post.id}'),
                onVisibilityChanged: (visibilityInfo) {
                  // فقط برای لاگ: میزان قابل مشاهده بودن
                  print(
                      'Video ${post.id} visibility: ${visibilityInfo.visibleFraction}');
                },
                child: CustomVideoPlayer(
                  key: ValueKey('video_player_${post.id}'),
                  videoUrl: post.videoUrl!,
                  autoplay: true,
                  muted: true,
                  showProgress: true,
                  looping: true,
                  postId: post.id,
                  username: post.username,
                  likeCount: post.likeCount,
                  commentCount: post.commentCount,
                  isLiked: post.isLiked,
                  title: post.title,
                  content: post.content, // اضافه کردن محتوای پست
                  onLike: () async {
                    _toggleLike(post);
                  },
                  onComment: () =>
                      showCommentsBottomSheet(context, post.id, ref),
                  onVideoPositionTap: (position) {
                    ref
                        .read(videoPositionProvider(post.id ?? '').notifier)
                        .state = position;
                  },
                  onTap: () {
                    final profile =
                        ref.read(userProfileProvider(widget.userId));
                    final videoPosts = profile?.posts
                            .where((p) =>
                                p.videoUrl != null && p.videoUrl!.isNotEmpty)
                            .toList() ??
                        [];
                    final initialIndex =
                        videoPosts.indexWhere((p) => p.id == post.id);

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReelsScreen(
                          posts: videoPosts,
                          initialIndex: initialIndex < 0 ? 0 : initialIndex,
                          initialPositions: {
                            post.id ?? '':
                                ref.read(videoPositionProvider(post.id ?? '')),
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],

          // نمایش تصویر اگر پست دارای imageUrl باشد
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showFullScreenImage(context, post.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => const ShimmerLoading(),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Actions section
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _buildLikeButton(post),
              const SizedBox(width: 16),
              _buildCommentButton(post),
              const SizedBox(width: 16),
              _buildShareButton(post),
            ],
          ),
          Divider(
            endIndent: 1,
            indent: 1,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white10
                : Colors.black26,
          ),
        ],
      ),
    );
  }

  Widget _buildLikeButton(PublicPostModel post) {
    return Row(
      children: [
        IconButton(
          icon: Icon(post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: post.isLiked ? Colors.red : null),
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
            onPressed: () => _showComments(post)),
        Text('${post.commentCount}'),
      ],
    );
  }

  Widget _buildShareButton(PublicPostModel post) {
    return IconButton(
        icon: const Icon(Icons.share), onPressed: () => _sharePost(post));
  }

  void _toggleLike(PublicPostModel post) async {
    final updatedPost = post.copyWith(
        isLiked: !post.isLiked,
        likeCount: post.isLiked ? post.likeCount - 1 : post.likeCount + 1);
    ref
        .read(userProfileProvider(widget.userId).notifier)
        .updatePost(updatedPost);
    try {
      if (updatedPost.isLiked) {
        await supabase.from('likes').insert({
          'post_id': updatedPost.id,
          'user_id': supabase.auth.currentUser!.id
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطا در تغییر وضعیت فالو: $e'),
          backgroundColor: Colors.red));
    }
  }

  void _showComments(PublicPostModel post) {
    showCommentsBottomSheet(context, post.id, ref);
  }

  void _sharePost(PublicPostModel post) {
    String shareText = '${post.username}: \n${post.content}';
    Share.share(shareText);
  }

  PopupMenuButton<String> _buildPostMenu(
      BuildContext context, PublicPostModel post) {
    final currentUserId = supabase.auth.currentUser?.id;
    final isCurrentUserPost = post.userId == currentUserId;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'delete':
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('حذف پست'),
                content: const Text('آیا از حذف این پست اطمینان دارید؟'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('انصراف')),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('حذف'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              try {
                await ref
                    .read(supabaseServiceProvider)
                    .deletePost(ref, post.id);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پست با موفقیت حذف شد')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('خطا در حذف پست')));
              }
            }
            break;
          case 'report':
            showDialog(
                context: context,
                builder: (context) => ReportDialog(post: post));
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: post.content));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('متن کپی شد!')));
            }
            break;
        }
      },
      itemBuilder: (context) => [
        if (isCurrentUserPost)
          const PopupMenuItem(value: 'delete', child: Text('حذف'))
        else
          const PopupMenuItem(value: 'report', child: Text('گزارش')),
        const PopupMenuItem(value: 'copy', child: Text('کپی')),
      ],
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Hero(
                tag: imageUrl,
                child:
                    CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
