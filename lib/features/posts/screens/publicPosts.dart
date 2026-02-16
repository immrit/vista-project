import '../../../security/logging_utility.dart';
import 'PostDetailPage.dart';
import 'package:Vista/utils/comments_bottom_sheet.dart';
import 'package:badges/badges.dart' as badges;
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../utils/const.dart';
import '../../../provider/MusicProvider.dart';
// تغییر به فایل جدید
import '../../../provider/personalized_feed_provider.dart';
import '../../../services/secure_upload_service.dart';
import '../../../services/vista_node_service.dart';
import 'package:Vista/utils/widgets.dart';
import 'package:Vista/widgets/profile_avatar_widget.dart'; // Add this import
import 'package:Vista/widgets/CustomVideoPlayer.dart';
import 'package:Vista/widgets/ReelsScreen.dart';
import 'package:Vista/features/music/screens/MiniMusicPlayer.dart';
import 'package:Vista/features/stories/stories.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../services/smart_share_service.dart';
import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:Vista/features/posts/widgets/post_music_bubble.dart';
import '../../../../features/posts/providers/post_upload_provider.dart';
import '../providers/saved_posts_provider.dart';
import 'notificationScreen.dart';
import 'profileScreen.dart';
import 'dart:async';
import '../../../utils/premium_features_helper.dart';
import '../../../utils/user_friendly_error_utils.dart';

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
  final ScrollController _scrollController = ScrollController();
  Timer? _connectivityTimer; // Timer برای بررسی دوره‌ای وضعیت اتصال

  final GlobalKey _tabControllerKey = GlobalKey();

  @override
  void dispose() {
    _mounted = false; // تنظیم وضعیت mount
    _connectivitySubscription.cancel();
    _connectivityTimer?.cancel(); // لغو timer بررسی اتصال
    _scrollController.dispose();
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

    // بررسی دوره‌ای وضعیت اتصال - فقط هر ۲ دقیقه و فقط وقتی آفلاین باشه
    _connectivityTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted && _connectionStatus == 'آفلاین') {
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
      logDebug('Error checking connectivity: $e');
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
    if (!_mounted) return; // چک مجدد وضعیت mount

    // محاسبه وضعیت جدید
    String newStatus = '';

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

    // تعیین متن وضعیت
    if (!hasInternet) {
      newStatus = 'آفلاین';
    } else {
      switch (result) {
        case ConnectivityResult.wifi:
          newStatus = 'متصل به وای‌فای';
          break;
        case ConnectivityResult.mobile:
          newStatus = 'متصل به اینترنت همراه';
          break;
        default:
          newStatus = 'آفلاین';
      }
    }

    // ✅ نکته کلیدی: فقط اگر وضعیت تغییر کرده باشه setState بزن
    if (_connectionStatus != newStatus) {
      setState(() {
        _isChecking = false;
        _connectionStatus = newStatus;
      });
    } else {
      // اگر وضعیت تغییر نکرده، فقط isChecking رو false کن بدون rebuild
      if (_isChecking) {
        _isChecking = false;
      }
    }
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
// StoryBar removed
                      // SliverToBoxAdapter(
                      //   child: Container(
                      //     padding: const EdgeInsets.symmetric(vertical: 12),
                      //     height: 135,
                      //     child: const StoryBar(),
                      //   ),
                      // )
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
    final postsAsync = ref.watch(personalizedFeedProvider);
    final notifier = ref.watch(personalizedFeedProvider.notifier);

    return Column(
      children: [
        const UploadProgressList(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async =>
                ref.read(personalizedFeedProvider.notifier).refreshPosts(),
            child: postsAsync.when(
              loading: () => _buildPostsSkeletonList(),
              error: (error, stack) {
                final friendly = error is FeedDisplayError
                    ? error
                    : const FeedDisplayError(
                        message:
                            'بارگذاری پست‌ها با خطا مواجه شد. لطفا دوباره تلاش کنید.',
                      );
                return Center(
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
                          friendly.message,
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
                          ref.invalidate(personalizedFeedProvider);
                          ref.invalidate(fetchFollowingPostsProvider);
                          ref.invalidate(activeStoriesProvider);
                          ref.invalidate(commentNotifierProvider);
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
                );
              },
              data: (posts) {
                if (posts.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('هیچ پستی یافت نشد',
                            style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
                  physics: const ClampingScrollPhysics(),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                  cacheExtent: 500,
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
                    return RepaintBoundary(
                      child: _buildPostItem(context, ref, post),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
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

    return Column(
      children: [
        const UploadProgressList(),
        Expanded(
          child: RefreshIndicator(
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'بارگذاری پست‌ها ممکن نشد. لطفا دوباره تلاش کنید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                  physics: const ClampingScrollPhysics(),
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                  cacheExtent: 500,
                  itemBuilder: (context, index) {
                    if (index == posts.length) {
                      ref
                          .read(fetchFollowingPostsProvider.notifier)
                          .loadMorePosts();
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
                    return RepaintBoundary(
                      child: _buildPostItem(context, ref, post),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
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
            leading: ProfileAvatar(
              userId: post.userId,
              size: 40,
              imageUrl: post.avatarUrl,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                        userId: post.userId, username: post.username),
                  ),
                );
              },
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
                  thumbnailUrl: post.imageUrl,
                  autoplay: ref.watch(autoPlayProvider),
                  muted: true,
                  showProgress: true,
                  looping: true,
                  postId: post.id,
                  username: post.username,
                  likeCount: post.likeCount,
                  commentCount: post.commentCount,
                  isLiked: post.isLiked,
                  content: post.content, // اضافه کردن محتوای پست
                  isVerified: post.isVerified, // حتما از post
                  verificationType: post.verificationType, // حتما از post
                  onLike: () async {
                    post.isLiked = !post.isLiked;
                    post.likeCount += post.isLiked ? 1 : -1;
                    (context as Element).markNeedsBuild();
                    await ref.watch(supabaseServiceProvider).toggleLike(
                          postId: post.id,
                          ownerId: post.userId,
                          ref: ref,
                        );
                  },
                  onComment: () =>
                      showCommentsBottomSheet(context, post.id, ref),
                  onVideoPositionTap: (position) {
                    ref.read(videoPositionProvider(post.id).notifier).state =
                        position;
                  },
                  onTap: () {
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
                          initialPositions: {
                            post.id: ref.read(videoPositionProvider(post.id)),
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
              onDoubleTap: () async {
                final isLiked =
                    ref.read(likeStateProvider)[post.id] ?? post.isLiked;
                if (!isLiked) {
                  // Trigger like
                  ref
                      .read(likeStateProvider.notifier)
                      .updateLikeState(post.id, true);
                  await ref.read(supabaseServiceProvider).toggleLike(
                        postId: post.id,
                        ownerId: post.userId,
                        ref: ref,
                      );
                }
              },
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
          // ردیف دکمه‌های لایک، کامنت و اشتراک - بازگردانی به ظاهر اصلی
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // دکمه لایک
                    Consumer(
                      builder: (context, ref, child) {
                        final isLiked = ref.watch(likeStateProvider)[post.id] ??
                            post.isLiked;
                        final likeCount = post.likeCount +
                            (isLiked != post.isLiked ? (isLiked ? 1 : -1) : 0);

                        return LikeButton(
                          key: ValueKey('like_${post.id}'),
                          isLiked: isLiked,
                          likeCount: likeCount,
                          onTap: () async {
                            // Optimistic update
                            ref
                                .read(likeStateProvider.notifier)
                                .updateLikeState(post.id, !isLiked);
                            try {
                              await ref
                                  .read(supabaseServiceProvider)
                                  .toggleLike(
                                    postId: post.id,
                                    ownerId: post.userId,
                                    ref: ref,
                                  );
                            } catch (e) {
                              // Revert on failure
                              if (context.mounted) {
                                ref
                                    .read(likeStateProvider.notifier)
                                    .updateLikeState(post.id, isLiked);
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 20),
                    // دکمه کامنت
                    CommentButton(
                      commentCount: post.commentCount,
                      onTap: () {
                        showCommentsBottomSheet2(context,
                            postId: post.id, postTitle: post.title ?? 'پست');
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final savedPostIdsAsync =
                            ref.watch(savedPostIdsProvider);
                        final isSaved = savedPostIdsAsync.maybeWhen(
                          data: (ids) => ids.contains(post.id),
                          orElse: () => false,
                        );

                        return SaveButton(
                          isSaved: isSaved,
                          onTap: () async {
                            final ok = await ref
                                .read(savedPostIdsProvider.notifier)
                                .toggle(post.id, post: post);
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('خطا در ذخیره پست'),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    // دکمه اشتراک‌گذاری
                    GestureDetector(
                      onTap: () {
                        VistaNodeService.trackFeedEvent(
                          postId: post.id,
                          eventType: 'share',
                        );
                        SmartShareService().showShareOptions(post, context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.transparent,
                        child: Image.asset(
                          'lib/utils/images/component/send.png',
                          width: 24,
                          height: 24,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
      // فیلتر کردن لینک‌های Vista و پست‌های اشتراکی
      if (!_isVistaOrSharedPostLink(url)) {
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
      } else {
        // نمایش لینک‌های Vista به صورت متن عادی
        spans.add(TextSpan(text: url));
      }

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
        PostMusicBubble(
          postId: post.id,
          musicUrl: post.musicUrl!,
          createdAt: post.createdAt,
          title: _resolveMusicTitle(post),
          artist: post.username,
          avatarUrl: post.avatarUrl,
        ),
    ],
  );
}

String _resolveMusicTitle(PublicPostModel post) {
  final direct = post.title?.trim() ?? '';
  if (direct.isNotEmpty) return direct;

  final url = post.musicUrl?.trim() ?? '';
  if (url.isEmpty) return 'موزیک';

  final uri = Uri.tryParse(url);
  final lastSegment = (uri?.pathSegments.isNotEmpty ?? false)
      ? uri!.pathSegments.last
      : url.split('/').last;

  final withoutExtension = lastSegment.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final normalized = withoutExtension
      .replaceFirst(RegExp(r'^[^_]+_[0-9]+_'), '')
      .replaceAll('_', ' ')
      .trim();

  return normalized.isEmpty ? 'موزیک' : normalized;
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
      // فیلتر کردن لینک‌های Vista و پست‌های اشتراکی
      if (!_isVistaOrSharedPostLink(matchedText)) {
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
      } else {
        // نمایش لینک‌های Vista به صورت متن عادی
        spans.add(TextSpan(text: matchedText));
      }
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

// بررسی اینکه آیا لینک مربوط به Vista یا پست اشتراکی است
bool _isVistaOrSharedPostLink(String url) {
  return url.contains('vista') ||
      url.contains('post/') ||
      url.contains('m مشاهده در Vista') ||
      url.contains('coffevista') ||
      url.contains('arvan');
}

void showEditPostDialog(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  final TextEditingController contentController =
      TextEditingController(text: post.content);
  String? imageUrl = post.imageUrl;
  String? videoUrl = post.videoUrl;
  bool imageRemoved = false;
  bool videoRemoved = false;
  bool isLoading = false;

  // جملات آماده برای ادمین‌ها
  final List<String> adminTemplates = [
    'این محتوا مناسب نیست و حذف شده است.',
    'تبلیغات در ویستا ممنوع است.',
    'این پست بر اساس قوانین ویستا حذف شده است.',
    'محتوای نامناسب شناسایی و حذف شد.',
    'این پست نقض قوانین محسوب می‌شود.',
    'لطفاً محتوای مناسب ارسال کنید.',
    'این محتوا با قوانین ویستا سازگار نیست.',
  ];

  // تابع تشخیص جهت متن
  TextDirection getTextDirection(String text) {
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    final englishRegex = RegExp(r'[a-zA-Z]');

    int persianCount = persianRegex.allMatches(text).length;
    int englishCount = englishRegex.allMatches(text).length;

    if (persianCount > englishCount) {
      return TextDirection.rtl;
    } else {
      return TextDirection.ltr;
    }
  }

  // تابع حذف فایل از آروان کلود
  // تابع حذف فایل از storage
  Future<void> deleteFileFromArvan(String fileUrl) async {
    try {
      if (fileUrl.contains('storage.389346.ir.cdn.ir')) {
        final deleted = await SecureUploadService.deleteByUrl(fileUrl);
        if (deleted) {
          logInfo('فایل با موفقیت از آروان کلود حذف شد: $fileUrl');
        }
      }
    } catch (e) {
      logInfo('خطا در حذف فایل از آروان کلود: $e');
    }
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                const Text('ویرایش پست توسط ناظر'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // بخش جملات آماده
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lightbulb_outline,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 4),
                            const Text('جملات آماده:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: adminTemplates.map((template) {
                            return InkWell(
                              onTap: () {
                                contentController.text = template;
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.orange.withOpacity(0.5)),
                                ),
                                child: Text(
                                  template.length > 30
                                      ? '${template.substring(0, 30)}...'
                                      : template,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.orange[700]),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // بخش متن پست
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.text_fields,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            const Text('متن پست:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Directionality(
                          textDirection:
                              getTextDirection(contentController.text),
                          child: TextField(
                            controller: contentController,
                            maxLines: 4,
                            maxLength: 300,
                            textDirection:
                                getTextDirection(contentController.text),
                            onChanged: (value) {
                              setState(() {
                                // تغییر جهت متن بر اساس محتوا
                              });
                            },
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'متن پست را ویرایش کنید...',
                              counterText:
                                  '${contentController.text.length}/300',
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[700]
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // بخش محتوای چندرسانه‌ای
                  if (imageUrl != null &&
                      imageUrl.isNotEmpty &&
                      !imageRemoved) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.image, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              const Text('تصویر فعلی:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    height: 150,
                                    color: Colors.grey[300],
                                    child: const Center(
                                        child: CircularProgressIndicator()),
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // حذف از آروان کلود
                                    await deleteFileFromArvan(imageUrl);
                                    setState(() {
                                      imageRemoved = true;
                                    });
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('حذف تصویر'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // بخش ویدیو
                  if (videoUrl != null &&
                      videoUrl.isNotEmpty &&
                      !videoRemoved) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.video_library,
                                  size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              const Text('ویدیو فعلی:',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Icon(
                                    Icons.play_circle_outline,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Icon(
                                      Icons.video_library,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    // حذف از آروان کلود
                                    await deleteFileFromArvan(videoUrl);
                                    setState(() {
                                      videoRemoved = true;
                                    });
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('حذف ویدیو'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // اطلاعات پست
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            const Text('اطلاعات پست:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('نویسنده: ${post.username}'),
                        Text(
                            'تاریخ: ${post.createdAt.toString().substring(0, 16)}'),
                        Text('لایک‌ها: ${post.likeCount}'),
                        Text('کامنت‌ها: ${post.commentCount}'),
                        // نمایش اطلاعات ناظر قبلی (اگر وجود داشته باشد)
                        if (post.moderatorUsername != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings,
                                        size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    const Text('آخرین ویرایش توسط:',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('ناظر: ${post.moderatorUsername}',
                                    style: const TextStyle(fontSize: 12)),
                                if (post.moderatedAt != null)
                                  Text(
                                      'تاریخ: ${post.moderatedAt!.toString().substring(0, 16)}',
                                      style: const TextStyle(fontSize: 12)),
                                if (post.moderationReason != null) ...[
                                  const SizedBox(height: 4),
                                  Text('دلیل: ${post.moderationReason}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.red)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                child: const Text('لغو'),
              ),
              ElevatedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        final content = contentController.text.trim();
                        if (content.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('متن پست نمی‌تواند خالی باشد'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          isLoading = true;
                        });

                        try {
                          // دریافت اطلاعات ناظر فعلی
                          final currentUser = supabase.auth.currentUser;
                          final moderatorProfile = await supabase
                              .from('profiles')
                              .select('username')
                              .eq('id', currentUser!.id)
                              .single();

                          final updateData = {
                            'content': content,
                            if (imageRemoved) 'image_url': null,
                            if (!imageRemoved && imageUrl != null)
                              'image_url': imageUrl,
                            if (videoRemoved) 'video_url': null,
                            if (!videoRemoved && videoUrl != null)
                              'video_url': videoUrl,
                            'updated_at': DateTime.now().toIso8601String(),
                            // ثبت اطلاعات ناظر
                            'moderator_id': currentUser.id,
                            'moderator_username': moderatorProfile['username'],
                            'moderated_at': DateTime.now().toIso8601String(),
                            'moderation_reason':
                                content, // متن ویرایش شده به عنوان دلیل
                          };

                          await supabase
                              .from('posts')
                              .update(updateData)
                              .eq('id', post.id);

                          // رفرش همه provider های مربوطه
                          ref.invalidate(personalizedFeedProvider);
                          ref.invalidate(fetchFollowingPostsProvider);

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text('پست با موفقیت ویرایش شد'),
                                  ],
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            setState(() {
                              isLoading = false;
                            });
                            UserFriendlyErrorUtils.showErrorSnackBar(
                                context, e);
                          }
                        }
                      },
                icon: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isLoading ? 'در حال ذخیره...' : 'ذخیره تغییرات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildPostActions(
    BuildContext context, WidgetRef ref, PublicPostModel post) {
  final profileAsync = ref.watch(profileProvider);

  return profileAsync.when(
    data: (profile) {
      final isBlueTick = profile != null &&
          profile['is_verified'] == true &&
          profile['verification_type'] == 'blueTick';

      final currentUserId = supabase.auth.currentUser?.id;
      final isCurrentUserPost = post.userId == currentUserId;

      return PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) {
          final items = <PopupMenuItem<String>>[
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
          ];

          // صاحب پست یا مدیران (تیک آبی) مجاز به حذف هستند
          if (isCurrentUserPost || isBlueTick) {
            items.add(const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف پست'),
                ],
              ),
            ));
          }

          // منطق نمایش گزینه ویرایش
          final currentUserProfile = ref.read(currentUserProfileProvider);
          final hasPremiumEdit = currentUserProfile.value != null &&
              PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
              isCurrentUserPost;

          // ویرایش: اگر تیک آبی دارد (برای همه) یا صاحب پست است (اگر پرمیوم باشد)
          if (isBlueTick || hasPremiumEdit) {
            items.add(PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    isBlueTick ? Icons.admin_panel_settings : Icons.edit,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Text(isBlueTick ? 'ویرایش ناظر' : 'ویرایش پست'),
                ],
              ),
            ));
          } else if (isCurrentUserPost) {
            // نمایش گزینه قفل برای صاحب پست که پرمیوم نیست
            items.add(PopupMenuItem<String>(
              value: 'edit_locked',
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  const Text('ویرایش پست'),
                  const Spacer(),
                  Icon(
                    Icons.workspace_premium,
                    size: 18,
                    color: Colors.amber.shade600,
                  ),
                ],
              ),
            ));
          }

          return items;
        },
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
            if (isCurrentUserPost || isBlueTick) {
              _showDeleteConfirmation(context, ref, post.id);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('شما نمی‌توانید این پست را حذف کنید'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } else if (value == 'edit') {
            if (isBlueTick && !isCurrentUserPost) {
              // نمایش ویرایش مخصوص ناظرین (فقط برای پست دیگران)
              showEditPostDialog(context, ref, post);
            } else {
              // نمایش ویرایش استاندارد (برای پست خود، چه تیک آبی چه طلایی)
              showStandardEditDialog(
                context: context,
                ref: ref,
                post: post,
                onSuccess: () {
                  ref.invalidate(personalizedFeedProvider);
                  ref.invalidate(fetchFollowingPostsProvider);
                },
              );
            }
          } else if (value == 'edit_locked') {
            PremiumFeaturesHelper.showPremiumPromptDialog(
              context,
              feature: 'ویرایش پست',
            );
          }
        },
      );
    },
    loading: () => PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
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
      ],
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
        }
      },
    ),
    error: (_, __) => PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
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
      ],
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
        }
      },
    ),
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
                  ref.read(personalizedFeedProvider.notifier).refreshPosts();
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  UserFriendlyErrorUtils.showErrorSnackBar(context, e);
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
  final VoidCallback onTap;

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
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    _scaleAnimation = Tween(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked) {
        _controller.forward().then((_) => _controller.reverse());
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onTap();
        if (!widget.isLiked) {
          _controller.forward().then((_) => _controller.reverse());
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked
                  ? Colors.red
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black),
              size: 28,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.likeCount}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentButton extends StatelessWidget {
  final int commentCount;
  final VoidCallback onTap;

  const CommentButton({
    super.key,
    required this.commentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'lib/utils/images/component/comment.png',
            width: 26,
            height: 26,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black54,
          ),
          const SizedBox(width: 6),
          Text(
            '$commentCount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class SaveButton extends StatelessWidget {
  final bool isSaved;
  final VoidCallback onTap;

  const SaveButton({
    super.key,
    required this.isSaved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final savedColor = Theme.of(context).colorScheme.primary;
    final baseColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black54;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Icon(
        isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        size: 28,
        color: isSaved ? savedColor : baseColor,
      ),
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

class UploadProgressList extends ConsumerWidget {
  const UploadProgressList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(postUploadProvider);

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: Column(
        children: tasks.map((task) => UploadTaskItem(task: task)).toList(),
      ),
    );
  }
}

class UploadTaskItem extends ConsumerWidget {
  final UploadTask task;

  const UploadTaskItem({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = task.progress.clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final isUploading = task.status == 'uploading';
    final isSuccess = task.status == 'success';
    final isFailed = task.status == 'failed';
    final statusColor = isFailed
        ? Colors.red
        : isSuccess
            ? Colors.green
            : Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black26
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[300],
            ),
            child: task.thumbnail != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.file(task.thumbnail!, fit: BoxFit.cover),
                  )
                : Icon(_kindIcon(), size: 20, color: Colors.grey[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _statusText(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    if (isFailed || isSuccess)
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                        onPressed: () {
                          ref
                              .read(postUploadProvider.notifier)
                              .dismissTask(task.id);
                        },
                      )
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _kindLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  color: statusColor,
                  backgroundColor: statusColor.withOpacity(0.15),
                ),
                if (task.errorMessage != null && task.errorMessage!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      task.errorMessage!,
                      style: const TextStyle(fontSize: 10, color: Colors.red),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (isUploading)
                  Text(
                    'در حال آپلود... $percent%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (task.status == 'success') return 'پست با موفقیت ارسال شد';
    if (task.status == 'failed') return 'ارسال پست ناموفق بود';
    return 'در حال ارسال پست';
  }

  String _kindLabel() {
    switch (task.kind) {
      case 'image':
        return 'نوع پست: تصویر';
      case 'video':
        return 'نوع پست: ویدیو';
      case 'music':
        return 'نوع پست: موزیک';
      default:
        return 'نوع پست: متنی';
    }
  }

  IconData _kindIcon() {
    switch (task.kind) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'music':
        return Icons.music_note_rounded;
      default:
        return Icons.subject_rounded;
    }
  }
}
