import 'package:Vista/view/screen/PublicPosts/PostDetailPage.dart';
import 'package:badges/badges.dart' as badges;
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../main.dart';
import '../../../model/MusicModel.dart';
import '../../../provider/MusicProvider.dart';
import '../../util/widgets.dart';
import '../../widgets/CustomVideoPlayer.dart';
import '../../widgets/ReelsScreen.dart';
import '../Music/MiniMusicPlayer.dart';
import '../Stories/story_system.dart';
import '../searchPage.dart';
import '/model/publicPostModel.dart';
import '../../../provider/provider.dart';
import 'MusicWaveform.dart';
import 'notificationScreen.dart';
import 'profileScreen.dart';
import 'dart:async';

class PublicPostsScreen extends ConsumerStatefulWidget {
  const PublicPostsScreen({super.key});

  @override
  ConsumerState<PublicPostsScreen> createState() => _PublicPostsScreenState();
}

class _PublicPostsScreenState extends ConsumerState<PublicPostsScreen>
    with AutomaticKeepAliveClientMixin {
  String _connectionStatus = '';
  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isChecking = false;
  bool _mounted = true; // اضافه کردن متغیر برای کنترل وضعیت mount
  final _pageStorageKey = const PageStorageKey('public_posts');
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _tabControllerKey = GlobalKey();

  @override
  void dispose() {
    _mounted = false; // تنظیم وضعیت mount
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      if (_mounted) {
        // چک کردن وضعیت mount
        _updateConnectionStatus(result);
      }
    });

    // بررسی دوره‌ای وضعیت اتصال
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _initConnectivity();
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _initConnectivity() async {
    setState(() => _isChecking = true);
    try {
      final result = await _connectivity.checkConnectivity();
      if (mounted) {
        await _updateConnectionStatus(result);
      }
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = 'آفلاین';
          _isChecking = false;
        });
      }
      Future.delayed(const Duration(seconds: 3), _initConnectivity);
    }
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    if (!_mounted) return; // چک کردن وضعیت mount

    bool hasInternet = false;
    try {
      final response = await Future.any<dynamic>([
        Supabase.instance.client.from('posts').select().limit(1).single(),
        Future<dynamic>.delayed(
            const Duration(seconds: 3), () => throw 'timeout'),
      ]);
      hasInternet = response != null;
    } catch (_) {
      hasInternet = false;
    }

    if (!_mounted) return; // چک مجدد وضعیت mount

    setState(() {
      _isChecking = false;
      if (!hasInternet) {
        _connectionStatus = 'آفلاین';
        return;
      }

      switch (result) {
        case ConnectivityResult.wifi:
          _connectionStatus = 'متصل به وای‌فای';
          break;
        case ConnectivityResult.mobile:
          _connectionStatus = 'متصل به اینترنت همراه';
          break;
        default:
          _connectionStatus = 'آفلاین';
      }
    });
  }

  Widget _buildConnectionStatus() {
    return ConnectionStatusBar(
      status: _connectionStatus,
      isChecking: _isChecking,
      onRetry: _initConnectivity, // تابع بررسی مجدد اتصال
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentColor = ref.watch(themeProvider);
    final getProfile = ref.watch(profileProvider);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // تعریف رنگ‌ها و سایه‌ها با gradient
    final selectedGradient = LinearGradient(
      colors: isDarkMode
          ? [Colors.grey[800]!, Colors.grey[700]!]
          : [Colors.white, Colors.grey[100]!],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final shadowColor = isDarkMode
        ? Colors.black.withOpacity(0.3)
        : Colors.grey.withOpacity(0.2);

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: DefaultTabController(
                length: 2,
                initialIndex: 0,
                key: _tabControllerKey,
                child: Scaffold(
                  body: NestedScrollView(
                    headerSliverBuilder: (context, innerBoxIsScrolled) => [
                      SliverAppBar(
                        floating: true,
                        snap: true,
                        // آیکون های سمت چپ (leading) - آیکون اعلان‌ها اینجا قرار می‌گیرد
                        actions: [
                          IconButton(
                            icon: _buildNotificationBadge(),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsPage(),
                                ),
                              );
                            },
                          ),
                        ],
                        title: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _connectionStatus == 'متصل به وای‌فای' ||
                                  _connectionStatus == 'متصل به اینترنت همراه'
                              ? Text(
                                  "Vista",
                                  style: TextStyle(
                                      fontFamily: 'Bauhaus',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24),
                                )
                              : _buildConnectionStatus(),
                        ),
                        centerTitle: true,
                        bottom: PreferredSize(
                          preferredSize: const Size.fromHeight(65),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey[850]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: shadowColor,
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(25),
                                child: ButtonsTabBar(
                                  // تنظیمات ظاهری
                                  decoration: BoxDecoration(
                                    gradient: selectedGradient,
                                    boxShadow: [
                                      BoxShadow(
                                        color: shadowColor,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  unselectedDecoration: BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  buttonMargin: const EdgeInsets.all(1),
                                  height: 46,
                                  splashColor: isDarkMode
                                      ? Colors.white12
                                      : Colors.black12,
                                  labelStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  unselectedLabelStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                  // انیمیشن نرم برای تغییر تب
                                  physics: const BouncingScrollPhysics(),
                                  duration: 300,

                                  tabs: [
                                    Tab(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.public, size: 16),
                                          SizedBox(width: 8),
                                          Text('همه پست‌ها'),
                                        ],
                                      ),
                                    ),
                                    Tab(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.people, size: 16),
                                          SizedBox(width: 8),
                                          Text('دنبال‌شده‌ها'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          height: 135,
                          child: const StoryBar(),
                        ),
                      )
                    ],
                    body: const TabBarView(
                      children: [
                        _AllPostsTab(),
                        _FollowingPostsTab(),
                      ],
                    ),
                  ),
                  // endDrawer:
                  //     CustomDrawer(getProfile, currentColor, context, ref),
                ),
              ),
            ),
            // فضای خالی برای مینی پلیر
            Consumer(
              builder: (context, ref, _) {
                final currentlyPlaying =
                    ref.watch(currentlyPlayingProvider).valueOrNull;
                return SizedBox(height: currentlyPlaying != null ? 60 : 0);
              },
            ),
          ],
        ),

        // مینی پلیر
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: MiniMusicPlayer(),
        ),
      ],
    );
  }

  Widget _buildNotificationBadge() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return badges.Badge(
      showBadge: ref.watch(hasNewNotificationProvider).when(
            data: (hasNewNotification) => hasNewNotification,
            loading: () => false,
            error: (_, __) => false,
          ),
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Colors.red,
      ),
      position: badges.BadgePosition.bottomStart(bottom: -8, start: -8),
      child: Icon(
        Icons.favorite_border,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
    );
  }
}

class _AllPostsTab extends ConsumerWidget {
  const _AllPostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استفاده از ویجت جدید بارگذاری تنبل
    return const _AllPostsPaginatedTab();
  }
}

class _AllPostsPaginatedTab extends ConsumerWidget {
  const _AllPostsPaginatedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(publicPostsProvider);
    final notifier = ref.watch(publicPostsProvider.notifier);

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(publicPostsProvider.notifier).refreshPosts(),
      child: postsAsync.when(
        loading: () => _buildPostsSkeletonList(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.refresh(publicPostsProvider);
                  ref.refresh(fetchFollowingPostsProvider);
                  ref.refresh(storyUsersProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.article_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('هیچ پستی یافت نشد', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                notifier.loadMorePosts();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: Theme.of(context).primaryColor,
                      size: 40,
                    ),
                  ),
                );
              }

              final post = posts[index];
              return _buildPostItem(context, ref, post);
            },
          );
        },
      ),
    );
  }

  // ویجت اسکلتون برای نمایش هنگام بارگذاری
  Widget _buildPostsSkeletonList() {
    return ListView.builder(
      itemCount: 5, // تعداد اسکلتون‌های نمایش داده شده
      itemBuilder: (context, index) {
        return buildPostSkeleton(context);
      },
    );
  }
}

class _FollowingPostsTab extends ConsumerWidget {
  const _FollowingPostsTab();
  final bool _hasMore = true; // Define _hasMore as a boolean variable

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(fetchFollowingPostsProvider);

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
      child: postsAsync.when(
        loading: () => _buildPostsSkeletonList(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.refresh(publicPostsProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        data: (posts) {
          return ListView.builder(
            itemCount: posts.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                ref.read(fetchFollowingPostsProvider.notifier).loadMorePosts();
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LoadingAnimationWidget.progressiveDots(
                      color: Theme.of(context).primaryColor,
                      size: 40,
                    ),
                  ),
                );
              }

              final post = posts[index];
              return _buildPostItem(context, ref, post);
            },
          );
        },
      ),
    );
  }

  // ویجت اسکلتون برای نمایش هنگام بارگذاری
  Widget _buildPostsSkeletonList() {
    return ListView.builder(
      itemCount: 5, // تعداد اسکلتون‌های نمایش داده شده
      itemBuilder: (context, index) {
        return buildPostSkeleton(context);
      },
    );
  }
}

Widget buildPostSkeleton(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final shimmerBaseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
  final shimmerHighlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: shimmerBaseColor,
              shape: BoxShape.circle,
            ),
          ),
          title: Container(
            width: 120,
            height: 16,
            color: shimmerBaseColor,
          ),
          subtitle: Container(
            width: 80,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            color: shimmerBaseColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 16,
          color: shimmerBaseColor,
          margin: const EdgeInsets.only(left: 56, right: 24),
        ),
        const SizedBox(height: 4),
        Container(
          height: 16,
          color: shimmerBaseColor,
          margin: const EdgeInsets.only(left: 24, right: 56),
        ),
        const SizedBox(height: 12),
        Container(
          height: 200,
          color: shimmerBaseColor,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shimmerBaseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 16,
              color: shimmerBaseColor,
            ),
            const SizedBox(width: 24),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shimmerBaseColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 16,
              color: shimmerBaseColor,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(),
      ],
    ),
  );
}

Widget _buildPostItem(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  // تبدیل تاریخ به جلالی
  DateTime createdAt = post.createdAt.toLocal();
  Jalali jalaliDate = Jalali.fromDateTime(createdAt);
  String formattedDate =
      '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 18.0),
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailsPage(postId: post.id),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر پست شامل آواتار، نام کاربری، تاریخ و منوهای عملیات
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                        userId: post.userId, username: post.username),
                  ),
                );
              },
              child: CircleAvatar(
                backgroundImage: post.avatarUrl.isEmpty
                    ? const AssetImage(
                            'lib/view/util/images/default-avatar.jpg')
                        as ImageProvider
                    : CachedNetworkImageProvider(
                        post.avatarUrl,
                        // اضافه کردن گزینه‌های جدید برای بهبود کش کردن
                        maxWidth: 100,
                        maxHeight: 100,
                      ),
              ),
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                        userId: post.userId, username: post.username),
                  ),
                );
              },
              child: Row(
                children: [
                  Text(post.username,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  if (post.isVerified) _buildVerificationBadge(post)
                ],
              ),
            ),
            subtitle: Text(formattedDate,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            trailing: _buildPostActions(context, ref, post),
          ),
          const SizedBox(height: 8),

          // بخش محتوای پست (متن، موزیک) - با استایل بهبود یافته
          Directionality(
            textDirection: getDirectionality(post.content),
            child: _buildPostContent(post, context),
          ),

          // نمایش هشتگ‌ها با استایل جدید
          if (post.hashtags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildHashtags(post.hashtags, context),
          ],

          // نمایش ویدیو اگر پست دارای videoUrl باشد
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
                  onLike: () async {
                    try {
                      await ref.read(supabaseServiceProvider).toggleLike(
                            postId: post.id!,
                            ownerId: post.userId!,
                            ref: ref,
                          );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('خطا در لایک پست: $e')),
                        );
                      }
                    }
                  },
                  onComment: () =>
                      showCommentsBottomSheet(context, post.id, ref),
                  onTap: () {
                    // استخراج لیست پست‌های ویدیویی
                    final profile = ref.read(userProfileProvider(post.userId));
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PostImageViewer(imageUrl: post.imageUrl!),
                  ),
                );
              },
              child: Hero(
                tag: post.imageUrl!,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(12.0), // گرد کردن گوشه‌های تصویر
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl!,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: Center(
                        child: LoadingAnimationWidget.staggeredDotsWave(
                          color: Theme.of(context).primaryColor,
                          size: 40,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40),
                      ),
                    ),
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 300),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ردیف دکمه‌های لایک، کامنت و اشتراک - با انیمیشن بهبود یافته
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // دکمه لایک با انیمیشن
              LikeButton(
                isLiked: post.isLiked,
                likeCount: post.likeCount,
                onTap: () async {
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
              const SizedBox(width: 16),
              // دکمه کامنت با استایل جدید
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () {
                      showCommentsBottomSheet(context, post.id, ref);
                    },
                  ),
                  Text(
                    '${post.commentCount}',
                    style: TextStyle(
                      fontWeight: post.commentCount > 0
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // دکمه اشتراک‌گذاری با انیمیشن کلیک
              GestureDetector(
                onTap: () {
                  String sharePost =
                      'کاربر ${post.username} به شما ارسال کرد:\n\n${post.content}';

                  // اگر پست تصویر دارد، آن را هم به اشتراک بگذارید
                  if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
                    sharePost += '\n\nتصویر: ${post.imageUrl}';
                  }

                  Share.share(sharePost);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: const Icon(
                    Icons.share_outlined,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    ),
  );
}

Widget _buildVerificationBadge(PublicPostModel profile) {
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

Widget _buildHashtags(List<String> hashtags, BuildContext context) {
  return Wrap(
    spacing: 8,
    children: hashtags.map((tag) {
      // انتخاب رنگی مناسب برای هر هشتگ بر اساس اولین کاراکتر آن
      final colors = [
        Colors.blue,
        Colors.purple,
        Colors.teal,
        Colors.orange,
        Colors.green,
        Colors.pink,
      ];

      final color = colors[tag.codeUnitAt(0) % colors.length];

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchPage(
                initialHashtag: tag,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Text(
            '#$tag',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class LinkifyText extends StatelessWidget {
  const LinkifyText({
    super.key,
    required this.text,
    required this.onTap,
    this.linkStyle,
  });

  final TextStyle? linkStyle;
  final Function(String) onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    // Updated regex to catch domains without http/https
    final urlRegex = RegExp(
      r'(?:(?:https?:\/\/)?(?:www\.)?)?[a-zA-Z0-9][-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    var start = 0;

    for (final match in urlRegex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: linkStyle ??
              const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              final formattedUrl =
                  url.startsWith('http') ? url : 'https://$url';
              onTap(formattedUrl);
            },
        ),
      );

      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(TextSpan(children: spans));
  }
}

Widget _buildPostContent(PublicPostModel post, BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Directionality(
        textDirection: getDirectionality(post.content),
        child: _buildPostContentText(post.content, context),
      ),
      if (post.musicUrl != null && post.musicUrl!.isNotEmpty)
        Consumer(
          builder: (context, ref, child) {
            final isPlaying = ref.watch(isPlayingProvider);
            final currentlyPlaying = ref.watch(currentlyPlayingProvider).value;
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
                    offset: const Offset(0, 2),
                  ),
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
    ],
  );
}

Widget _buildPostContentText(String content, BuildContext context) {
  final pattern = RegExp(
    r'(#[\w\u0600-\u06FF]+)|((https?:\/\/)?([\w\-])+\.{1}([a-zA-Z]{2,63})([\/\w-]*)*\/?\??([^\s<>#]*))',
    multiLine: true,
    unicode: true,
  );

  List<TextSpan> spans = [];
  int start = 0;

  for (Match match in pattern.allMatches(content)) {
    if (match.start > start) {
      spans.add(TextSpan(text: content.substring(start, match.start)));
    }

    final matchedText = match.group(0)!;

    if (matchedText.startsWith('#')) {
      spans.add(
        TextSpan(
          text: matchedText,
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              // ارسال کل هشتگ با علامت # به صفحه جستجو
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    initialHashtag: matchedText, // ارسال کل هشتگ با علامت #
                  ),
                ),
              );
            },
        ),
      );
    } else {
      // کد مربوط به URL بدون تغییر
      spans.add(
        TextSpan(
          text: matchedText,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
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

  if (start < content.length) {
    spans.add(TextSpan(text: content.substring(start)));
  }

  return RichText(
    text: TextSpan(
      style: DefaultTextStyle.of(context).style,
      children: spans,
    ),
  );
}

Widget _buildPostActions(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  return PopupMenuButton<String>(
    icon: const Icon(Icons.more_vert),
    onSelected: (value) async {
      if (value == 'report') {
        _showReportDialog(context, ref, post.id);
      } else if (value == 'copy') {
        await Clipboard.setData(ClipboardData(text: post.content));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('متن پست کپی شد'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'باشه',
              onPressed: () {},
            ),
          ),
        );
      } else if (value == 'delete') {
        final currentUserId = supabase.auth.currentUser?.id;
        if (currentUserId == post.userId) {
          _showDeleteConfirmation(context, ref, post.id);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('شما نمی‌توانید این پست را حذف کنید'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    },
    itemBuilder: (context) => [
      const PopupMenuItem<String>(
        value: 'report',
        child: Row(
          children: [
            Icon(Icons.flag, color: Colors.orange),
            SizedBox(width: 8),
            Text('گزارش پست'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'copy',
        child: Row(
          children: [
            Icon(Icons.content_copy, color: Colors.blue),
            SizedBox(width: 8),
            Text('کپی متن'),
          ],
        ),
      ),
      if (supabase.auth.currentUser?.id == post.userId)
        const PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Colors.red),
              SizedBox(width: 8),
              Text('حذف پست'),
            ],
          ),
        ),
    ],
  );
}

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.grey[300],
    );
  }
}

void _showDeleteConfirmation(
    BuildContext context, WidgetRef ref, String postId) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('حذف پست'),
        content: const Text('آیا از حذف این پست مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(supabaseServiceProvider).deletePost(ref, postId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پست با موفقیت حذف شد')),
                  );
                  ref.read(publicPostsProvider.notifier).refreshPosts();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف پست: $e')),
                  );
                }
              }
            },
            child: const Text('حذف'),
          ),
        ],
      );
    },
  );
}

void _showReportDialog(BuildContext context, WidgetRef ref, String postId) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('گزارش پست'),
        content: const Text('آیا می‌خواهید این پست را گزارش دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لغو'),
          ),
          TextButton(
            onPressed: () {
              // Add your report logic here
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('پست گزارش شد')),
              );
            },
            child: const Text('گزارش'),
          ),
        ],
      );
    },
  );
}

class LikeButton extends StatefulWidget {
  final bool isLiked;
  final int likeCount;
  final Function onTap;

  const LikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onTap,
  });

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _sizeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 50),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _sizeAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _sizeAnimation.value,
              child: IconButton(
                icon: Icon(
                  widget.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.isLiked ? Colors.red : null,
                ),
                onPressed: () {
                  if (!widget.isLiked) {
                    _controller.forward(from: 0.0);
                  }
                  widget.onTap();
                },
              ),
            );
          },
        ),
        Text(
          widget.likeCount.toString(),
          style: TextStyle(
            fontWeight: widget.isLiked ? FontWeight.bold : FontWeight.normal,
            color: widget.isLiked ? Colors.red : null,
          ),
        ),
      ],
    );
  }
}

class ConnectionStatusBar extends StatefulWidget {
  final String status;
  final bool isChecking;
  final VoidCallback onRetry;

  const ConnectionStatusBar({
    super.key,
    required this.status,
    required this.isChecking,
    required this.onRetry,
  });

  @override
  State<ConnectionStatusBar> createState() => _ConnectionStatusBarState();
}

class _ConnectionStatusBarState extends State<ConnectionStatusBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<double>(begin: -10.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(ConnectionStatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: _buildStatusContent(isDark),
          ),
        );
      },
    );
  }

  Widget _buildStatusContent(bool isDark) {
    // اگر آفلاین است، پیغام خطا با دکمه تلاش مجدد نمایش داده شود
    if (widget.status.contains('آفلاین')) {
      return _buildOfflineMessage(isDark);
    }

    // در غیر این صورت، نوار وضعیت معمولی نمایش داده شود
    return _buildStatusIndicator(isDark);
  }

  Widget _buildOfflineMessage(bool isDark) {
    final color = isDark ? Colors.redAccent : Colors.red[700];
    final backgroundColor =
        isDark ? Colors.red.withOpacity(0.2) : Colors.red[50];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color!.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            'اتصال اینترنت برقرار نیست',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => widget.onRetry(),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    color: color,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  // Text(
                  //   'تلاش مجدد',
                  //   style: TextStyle(
                  //     color: color,
                  //     fontSize: 11,
                  //     fontWeight: FontWeight.bold,
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isDark) {
    Color? mainColor;
    IconData iconData;

    if (widget.isChecking) {
      mainColor = isDark ? Colors.blueAccent : Colors.blue[700];
      iconData = Icons.sync_rounded;
    } else if (widget.status.contains('وای‌فای')) {
      mainColor = isDark ? Colors.greenAccent : Colors.green[700];
      iconData = Icons.wifi_rounded;
    } else {
      mainColor = isDark ? Colors.amberAccent : Colors.amber[700];
      iconData = Icons.signal_cellular_alt_rounded;
    }

    final backgroundColor =
        isDark ? mainColor!.withOpacity(0.2) : mainColor!.withAlpha(20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isChecking)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(mainColor),
              ),
            )
          else
            Icon(
              iconData,
              color: mainColor,
              size: 14,
            ),
          const SizedBox(width: 5),
          Text(
            widget.status,
            style: TextStyle(
              color: mainColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// // کلاس نمایش ویدیو در پست
// class VideoPostWidget extends StatefulWidget {
//   final String videoUrl;

//   const VideoPostWidget({Key? key, required this.videoUrl}) : super(key: key);

//   @override
//   State<VideoPostWidget> createState() => _VideoPostWidgetState();
// }

// class _VideoPostWidgetState extends State<VideoPostWidget> {
//   VideoPlayerController? _videoPlayerController;
//   ChewieController? _chewieController;
//   bool _isInitialized = false;

//   @override
//   void initState() {
//     super.initState();
//     _initializeVideoPlayer();
//   }

//   Future<void> _initializeVideoPlayer() async {
//     try {
//       _videoPlayerController =
//           VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
//       await _videoPlayerController!.initialize();

//       _chewieController = ChewieController(
//         videoPlayerController: _videoPlayerController!,
//         autoPlay: false,
//         looping: false,
//         aspectRatio: _videoPlayerController!.value.aspectRatio,
//         allowFullScreen: true,
//         allowPlaybackSpeedChanging: true,
//         placeholder: Center(
//           child: CircularProgressIndicator(),
//         ),
//         materialProgressColors: ChewieProgressColors(
//           playedColor: Colors.red,
//           handleColor: Colors.red,
//           backgroundColor: Colors.grey,
//           bufferedColor: Colors.grey.shade400,
//         ),
//         allowMuting: true,
//         fullScreenByDefault: false,
//         showOptions: false,
//         showControlsOnInitialize: false,
//       );

//       if (mounted) {
//         setState(() {
//           _isInitialized = true;
//         });
//       }
//     } catch (e) {
//       print('Error initializing video player: $e');
//     }
//   }

//   @override
//   void dispose() {
//     _videoPlayerController?.dispose();
//     _chewieController?.dispose();
//     super.dispose();
//   }

//   void _openFullScreen() {
//     Navigator.of(context).push(
//       MaterialPageRoute(
//         builder: (_) => FullScreenVideoPage(videoUrl: widget.videoUrl),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: _openFullScreen,
//       child: Container(
//         constraints: BoxConstraints(maxHeight: 400),
//         child: _isInitialized
//             ? ClipRRect(
//                 borderRadius: BorderRadius.circular(8),
//                 child: Chewie(controller: _chewieController!),
//               )
//             : AspectRatio(
//                 aspectRatio: 16 / 9,
//                 child: Container(
//                   color: Colors.black87,
//                   child: const Center(
//                     child: CircularProgressIndicator(),
//                   ),
//                 ),
//               ),
//       ),
//     );
//   }
// }

// // --- صفحه نمایش تمام‌صفحه ویدیو ---
// class FullScreenVideoPage extends StatefulWidget {
//   final String videoUrl;
//   const FullScreenVideoPage({Key? key, required this.videoUrl})
//       : super(key: key);

//   @override
//   State<FullScreenVideoPage> createState() => _FullScreenVideoPageState();
// }

// class _FullScreenVideoPageState extends State<FullScreenVideoPage> {
//   late VideoPlayerController _controller;
//   ChewieController? _chewieController;
//   bool _isReady = false;

//   @override
//   void initState() {
//     super.initState();
//     _init();
//   }

//   Future<void> _init() async {
//     // قفل کردن به حالت portraitUp و landscape
//     await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
//     await SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.landscapeLeft,
//       DeviceOrientation.landscapeRight,
//     ]);
//     _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
//     await _controller.initialize();
//     _chewieController = ChewieController(
//       videoPlayerController: _controller,
//       autoPlay: true,
//       looping: false,
//       allowFullScreen: false,
//       allowPlaybackSpeedChanging: true,
//       aspectRatio: _controller.value.aspectRatio,
//       showControlsOnInitialize: true,
//       materialProgressColors: ChewieProgressColors(
//         playedColor: Colors.red,
//         handleColor: Colors.red,
//         backgroundColor: Colors.grey,
//         bufferedColor: Colors.grey.shade400,
//       ),
//     );
//     setState(() {
//       _isReady = true;
//     });
//   }

//   @override
//   void dispose() {
//     _chewieController?.dispose();
//     _controller.dispose();
//     // بازگرداندن orientation به حالت پیش‌فرض
//     SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
//     SystemChrome.setPreferredOrientations([
//       DeviceOrientation.portraitUp,
//       DeviceOrientation.portraitDown,
//     ]);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           Center(
//             child: _isReady && _chewieController != null
//                 ? Chewie(controller: _chewieController!)
//                 : const Center(child: CircularProgressIndicator()),
//           ),
//           Positioned(
//             top: 36,
//             right: 16,
//             child: SafeArea(
//               child: IconButton(
//                 icon: const Icon(Icons.close, color: Colors.white, size: 32),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
