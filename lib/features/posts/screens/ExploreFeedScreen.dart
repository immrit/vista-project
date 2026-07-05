import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:badges/badges.dart' as badges;
import 'package:connectivity_plus/connectivity_plus.dart';

// Import Models
import '../../../model/publicPostModel.dart';

// Import Providers
import '../../../provider/provider.dart';
import '../../../provider/personalized_feed_provider.dart';
import '../../../provider/notification_provider.dart';

// Import Screens (for navigation)
import 'package:Vista/features/posts/navigation/content_routes.dart';
import 'notificationScreen.dart';
import 'package:Vista/features/posts/screens/AddPost.dart';

import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:flutter/services.dart';
import '../../../services/smart_share_service.dart';
import '../../../services/current_user_service.dart';
import 'package:Vista/utils/premium_features_helper.dart';
import 'package:Vista/utils/widgets.dart' show ReportDialog;
import 'package:Vista/utils/comments_bottom_sheet.dart';
import 'package:Vista/services/system_ui_bar_service.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../widgets/post_action_buttons.dart';
import '../widgets/upload_progress_overlay.dart';
import '../widgets/post_moderation_banner.dart';
import '../widgets/post_feed_video.dart';
import '../services/reels_viewer_launcher.dart';
import '../widgets/hashtag_rich_text.dart';
import '../providers/saved_posts_provider.dart';
import '../data/go_posts_repository.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import '../../../widgets/verification_badge_icon.dart';
import 'package:Vista/features/stories/stories.dart';
import 'package:Vista/core/theme/app_theme.dart';
import '../../../widgets/skeleton_loading.dart';
import '../widgets/double_tap_like_overlay.dart';
import '../widgets/post_image_carousel.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';
import '../widgets/dwell_detector.dart';

// -----------------------------------------------------------------------------
// SCREEN
// -----------------------------------------------------------------------------

/// Tracks which author ids are currently being followed (in-flight) from the feed UI.
final _feedFollowLoadingProvider =
    StateProvider<Set<String>>((ref) => <String>{});

const double _feedContentTopPadding = 8;
const double _homeBottomNavReservedHeight = 110;

EdgeInsets _feedListPadding(BuildContext context) {
  return EdgeInsets.only(
    top: _feedContentTopPadding,
    bottom: MediaQuery.of(context).viewPadding.bottom +
        _homeBottomNavReservedHeight,
  );
}

class ExploreFeedScreen extends ConsumerStatefulWidget {
  const ExploreFeedScreen({super.key});

  @override
  ConsumerState<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends ConsumerState<ExploreFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    unawaited(_initConnectivityStatus());
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_handleConnectivityChange);
  }

  Future<void> _initConnectivityStatus() async {
    final results = await _connectivity.checkConnectivity();
    if (!mounted) return;
    _handleConnectivityChange(results);
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final isOffline =
        results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    if (!mounted || _isOffline == isOffline) return;
    setState(() {
      _isOffline = isOffline;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: bgColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: bgColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
    SystemUiBarService.sync(overlayStyle);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgColor,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 90.0),
          child: Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: null,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const AddPublicPostScreen()),
                );
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              highlightElevation: 0,
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 32),
            ),
          ),
        ),
        body: Column(
          children: [
            _FeedConnectionBanner(
              isOffline: _isOffline,
              onRetry: _initConnectivityStatus,
            ),
            Expanded(
              child: NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: bgColor,
                      foregroundColor: textColor,
                      floating: true,
                      snap: true,
                      pinned: true,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      systemOverlayStyle: overlayStyle,
                      title: Image.asset(
                        isDark
                            ? 'lib/utils/images/logo/logo-white.png'
                            : 'lib/utils/images/logo/black-logo.png',
                        height: 35,
                        fit: BoxFit.cover,
                      ),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          tooltip: 'اعلان‌ها',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotificationsPage(),
                              ),
                            );
                          },
                          icon: _buildNotificationBadge(iconColor: textColor),
                        ),
                      ],
                      bottom: TabBar(
                        indicatorColor: AppColors.primary,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 2.5,
                        labelColor: AppColors.primary,
                        unselectedLabelColor:
                            theme.colorScheme.onSurfaceVariant,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        unselectedLabelStyle: const TextStyle(
                            fontWeight: FontWeight.normal, fontSize: 15),
                        tabs: [
                          Tab(
                              text: AppLocalizations.of(context)?.forYou ??
                                  "برای شما"),
                          Tab(
                              text: AppLocalizations.of(context)?.following ??
                                  "دنبال شده‌ها"),
                        ],
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: StoryBar(),
                    ),
                  ];
                },
                body: const TabBarView(
                  children: [
                    _ForYouTab(),
                    _FollowingTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  Widget _buildNotificationBadge({required Color iconColor}) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return badges.Badge(
      showBadge: unreadCount > 0,
      badgeStyle: const badges.BadgeStyle(
        badgeColor: Colors.red,
        padding: EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      ),
      badgeContent: Text(
        unreadCount > 99 ? '99+' : unreadCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      position: badges.BadgePosition.topEnd(top: -8, end: -8),
      child: Icon(
        Icons.notifications_none_rounded,
        color: iconColor,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TABS
// -----------------------------------------------------------------------------

class _ForYouTab extends ConsumerWidget {
  const _ForYouTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استفاده از پرووایدر اصلی (engagementPostsProvider) که لاجیک لایک/کامنت صحیح دارد
    final feedAsync = ref.watch(personalizedFeedProvider);
    final notifier = ref.read(personalizedFeedProvider.notifier);

    return feedAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _RefreshableFeedState(
            onRefresh: () =>
                ref.read(personalizedFeedProvider.notifier).refreshPosts(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UploadProgressOverlay(),
                _FeedEmptyState(
                  title: AppLocalizations.of(context)?.noPostsReady ??
                      'هنوز پستی برای شما آماده نشده',
                  subtitle:
                      AppLocalizations.of(context)?.followToPersonalize ??
                          'با دنبال‌کردن کاربران جدید، فید شما سریع‌تر شخصی‌سازی می‌شود.',
                  actionLabel: AppLocalizations.of(context)?.searchUsers ??
                      'جستجوی کاربران',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchPage()),
                    );
                  },
                ),
              ],
            ),
          );
        }
        final reelsPlaylist = ReelsViewerLauncher.videoPlaylist(posts);

        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(personalizedFeedProvider.notifier).refreshPosts(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 480) {
                if (notifier.hasMorePosts()) {
                  notifier.loadMorePosts();
                }
              }
              return false;
            },
            child: ListView.builder(
              scrollCacheExtent: ScrollCacheExtent.pixels(1000),
              padding: _feedListPadding(context),
              // +1 for the pinned upload-progress card at index 0.
              itemCount:
                  1 + posts.length + (notifier.hasMorePosts() ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const UploadProgressOverlay();
                }
                final postIndex = index - 1;
                if (postIndex == posts.length) {
                  // P2: a failed *page* fetch keeps the loaded feed and shows
                  // an inline retry row here, never a full-screen error.
                  if (notifier.loadMoreError != null) {
                    return _LoadMoreRetryRow(
                      onRetry: () => notifier.retryLoadMore(),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final post = posts[postIndex];
                // P1: isolate each row's painting so one row repaint doesn't
                // invalidate the whole list layer during scroll.
                return RepaintBoundary(
                  child: DwellDetector(
                    key: ValueKey<String>(post.id),
                    itemKey: post.id,
                    onView: () {
                      unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'view',
                              ));
                    },
                    onDwell: () {
                      unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'dwell',
                              ));
                    },
                    child: Column(
                      children: [
                        _ThreadPostItem(
                          post: post,
                          isForYou: true,
                          reelsPlaylist: reelsPlaylist,
                        ),
                        const Divider(height: 0.5, thickness: 0.5),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const _FeedLoadingState(),
      error: (err, stack) => _RefreshableFeedState(
        onRefresh: () =>
            ref.read(personalizedFeedProvider.notifier).refreshPosts(),
        child: _FeedErrorState(
          message: AppLocalizations.of(context)?.loadSuggestedFailed ??
              'بارگذاری پست‌های پیشنهادی ناموفق بود.',
          onRetry: () =>
              ref.read(personalizedFeedProvider.notifier).refreshPosts(),
        ),
      ),
    );
  }
}

class _FollowingTab extends ConsumerWidget {
  const _FollowingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // استفاده از پرووایدر اصلی (fetchFollowingPostsProvider)
    final feedAsync = ref.watch(fetchFollowingPostsProvider);
    final notifier = ref.read(fetchFollowingPostsProvider.notifier);

    return feedAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return _RefreshableFeedState(
            onRefresh: () =>
                ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const UploadProgressOverlay(),
                _FeedEmptyState(
                  title: AppLocalizations.of(context)?.noFollowingPosts ??
                      'پستی از دنبال‌شده‌ها پیدا نشد',
                  subtitle: AppLocalizations.of(context)?.followMorePeople ??
                      'افراد بیشتری را دنبال کنید یا کمی بعد دوباره بررسی کنید.',
                  actionLabel: AppLocalizations.of(context)?.refreshFeed ??
                      'تازه‌سازی فید',
                  onAction: () => ref
                      .read(fetchFollowingPostsProvider.notifier)
                      .refreshPosts(),
                ),
              ],
            ),
          );
        }
        final reelsPlaylist = ReelsViewerLauncher.videoPlaylist(posts);

        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 480) {
                if (notifier.hasMorePosts()) {
                  notifier.loadMorePosts();
                }
              }
              return false;
            },
            child: ListView.builder(
              scrollCacheExtent: ScrollCacheExtent.pixels(1000),
              padding: _feedListPadding(context),
              // +1 for the pinned upload-progress card at index 0.
              itemCount:
                  1 + posts.length + (notifier.hasMorePosts() ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const UploadProgressOverlay();
                }
                final postIndex = index - 1;
                if (postIndex == posts.length) {
                  // P2: a failed *page* fetch keeps the loaded feed and shows
                  // an inline retry row here, never a full-screen error.
                  if (notifier.loadMoreError != null) {
                    return _LoadMoreRetryRow(
                      onRetry: () => notifier.retryLoadMore(),
                    );
                  }
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
                }

                final post = posts[postIndex];
                // P1: isolate each row's painting so one row repaint doesn't
                // invalidate the whole list layer during scroll.
                return RepaintBoundary(
                  child: DwellDetector(
                    key: ValueKey<String>(post.id),
                    itemKey: post.id,
                    onView: () {
                      unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'view',
                              ));
                    },
                    onDwell: () {
                      unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'dwell',
                              ));
                    },
                    child: Column(
                      children: [
                        _ThreadPostItem(
                          post: post,
                          isForYou: false,
                          reelsPlaylist: reelsPlaylist,
                        ),
                        const Divider(height: 0.5, thickness: 0.5),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
      loading: () => const _FeedLoadingState(),
      error: (err, stack) => _RefreshableFeedState(
        onRefresh: () =>
            ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
        child: _FeedErrorState(
          message: AppLocalizations.of(context)?.loadFollowingFailed ??
              'بارگذاری پست‌های دنبال‌شده ناموفق بود.',
          onRetry: () =>
              ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
        ),
      ),
    );
  }
}

class _RefreshableFeedState extends StatelessWidget {
  const _RefreshableFeedState({
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class _FeedLoadingState extends StatelessWidget {
  const _FeedLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: _feedListPadding(context),
      itemBuilder: (_, __) => const PostCardSkeleton(),
      separatorBuilder: (_, __) => const Divider(height: 0.5, thickness: 0.5),
      itemCount: 4,
    );
  }
}

class _FeedEmptyState extends StatelessWidget {
  const _FeedEmptyState({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dynamic_feed_rounded,
                color: colorScheme.primary, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _FeedErrorState extends StatelessWidget {
  const _FeedErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRetry,
                child:
                    Text(AppLocalizations.of(context)?.retry ?? 'تلاش مجدد')),
          ],
        ),
      ),
    );
  }
}

/// Inline footer shown when a *pagination* (load-more) request fails. Unlike
/// [_FeedErrorState] it never replaces the loaded feed — it sits at the list
/// bottom and lets the user retry just the next page (§3.2/§8.3).
class _LoadMoreRetryRow extends StatelessWidget {
  const _LoadMoreRetryRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Colors.orange),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'بارگذاری پست‌های بیشتر ناموفق بود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context)?.retry ?? 'تلاش مجدد'),
          ),
        ],
      ),
    );
  }
}

class _FeedConnectionBanner extends StatelessWidget {
  const _FeedConnectionBanner({
    required this.isOffline,
    required this.onRetry,
  });

  final bool isOffline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: isOffline ? 42 : 0,
      width: double.infinity,
      padding: isOffline
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : EdgeInsets.zero,
      color: Colors.orange.shade700,
      child: isOffline
          ? Row(
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.noInternetConnection ??
                        'اتصال اینترنت برقرار نیست',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  ),
                  child: Text(
                      AppLocalizations.of(context)?.recheck ?? 'بررسی مجدد'),
                ),
              ],
            )
          : null,
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// WIDGETS
// -----------------------------------------------------------------------------

/// آیتم لیست پست با اکشن‌های استاندارد فید
class _ThreadPostItem extends ConsumerWidget {
  final PublicPostModel post;
  final bool isForYou;
  final List<PublicPostModel> reelsPlaylist;

  const _ThreadPostItem({
    required this.post,
    required this.isForYou,
    required this.reelsPlaylist,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final hasVideo = post.hasVideo;
    final isLiked =
        ref.watch(likeStateProvider.select((map) => map[post.id])) ??
            post.isLiked;
    final likeCount =
        post.likeCount + (isLiked != post.isLiked ? (isLiked ? 1 : -1) : 0);
    final currentUserId =
        ref.watch(activeUserProvider)?.id ?? CurrentUserService.cachedUserId;

    final followStatus = post.authorFollowStatus;
    final shouldShowFollowButton = isForYou &&
        currentUserId != null &&
        post.userId.isNotEmpty &&
        post.userId != currentUserId &&
        (followStatus == 'none' || followStatus == 'requested');

    final isFollowBusy = ref.watch(
      _feedFollowLoadingProvider.select((ids) => ids.contains(post.userId)),
    );
    final isSaved = ref.watch(savedPostIdsProvider.select((async) => async
        .maybeWhen(data: (ids) => ids.contains(post.id), orElse: () => false)));

    // استفاده از GestureDetector به جای InkWell برای حذف افکت ریپل از کل پست
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(ref.read(goPostsRepositoryProvider).trackFeedEvent(
              postId: post.id,
              eventType: 'open',
            ));
        ContentNavigation.pushPostDetail(context, postId: post.id);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── هدر + متن (با padding معمولی) ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // آواتار کاربر
                GestureDetector(
                  onTap: () {
                    ContentNavigation.pushProfile(
                      context,
                      userId: post.userId,
                      username: post.username,
                    );
                  },
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    backgroundImage: post.avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(post.avatarUrl)
                        : null,
                    child: post.avatarUrl.isEmpty
                        ? Icon(Icons.person,
                            size: 22,
                            color: isDark ? Colors.grey[400] : Colors.grey[600])
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // اطلاعات کاربر + متن پست
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // هدر: نام کاربر و زمان
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    post.username,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: colorScheme.onSurface,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (post.isVerified) ...[
                                  const SizedBox(width: 4),
                                  VerificationBadgeIcon(
                                    isVerified: post.isVerified,
                                    verificationType: post.verificationType,
                                    role: post.profiles?['role']?.toString(),
                                    size: 14,
                                  ),
                                ],
                                const SizedBox(width: 6),
                                Text(
                                  '• ${_getTimeAgo(post.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (shouldShowFollowButton)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: SizedBox(
                                width: 112,
                                height: 28,
                                child: followStatus == 'requested'
                                    ? OutlinedButton(
                                        onPressed: null,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          side: BorderSide(
                                            color: isDark
                                                ? Colors.white24
                                                : Colors.black26,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                                AppLocalizations.of(context)
                                                        ?.requested ??
                                                    'درخواست شد'),
                                          ),
                                        ),
                                      )
                                    : FilledButton(
                                        onPressed: isFollowBusy
                                            ? null
                                            : () async {
                                                final targetId = post.userId;
                                                if (targetId.isEmpty ||
                                                    targetId == currentUserId) {
                                                  return;
                                                }
                                                ref
                                                    .read(
                                                        _feedFollowLoadingProvider
                                                            .notifier)
                                                    .update((s) =>
                                                        {...s, targetId});
                                                try {
                                                  final status = await ref
                                                      .read(
                                                          postActionsServiceProvider)
                                                      .followUserQuick(
                                                          targetUserId:
                                                              targetId);
                                                  ref
                                                      .read(
                                                          personalizedFeedProvider
                                                              .notifier)
                                                      .setAuthorFollowStatus(
                                                          targetId, status);
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    UserFriendlyErrorUtils
                                                        .showErrorSnackBar(
                                                      context,
                                                      e,
                                                    );
                                                  }
                                                } finally {
                                                  ref
                                                      .read(
                                                          _feedFollowLoadingProvider
                                                              .notifier)
                                                      .update((s) {
                                                    final next = {...s};
                                                    next.remove(targetId);
                                                    return next;
                                                  });
                                                }
                                              },
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                        child: isFollowBusy
                                            ? const SizedBox(
                                                height: 14,
                                                width: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                      AppLocalizations.of(
                                                                  context)
                                                              ?.follow ??
                                                          'دنبال کردن'),
                                                ),
                                              ),
                                      ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      PostModerationBanner(post: post),

                      // متن پست
                      if (post.content.isNotEmpty) ...[
                        HashtagRichText(
                          text: post.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color: colorScheme.onSurface.withValues(alpha: 0.9),
                          ),
                          hashtagStyle: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 6,
                          readMoreLabel: 'بیشتر...',
                          onReadMoreTap: () {
                            ContentNavigation.pushPostDetail(
                              context,
                              postId: post.id,
                            );
                          },
                          onHashtagTap: (tag) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SearchPage(initialHashtag: '#$tag'),
                              ),
                            );
                          },
                          onMentionTap: (username) {
                            ContentNavigation.pushProfileByUsername(
                              context,
                              username: username,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── تصویر (هم‌سبک پروفایل) ─────────────────────────────
          if (hasImage) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    minWidth: double.infinity,
                  ),
                  child: DoubleTapLikeOverlay(
                    isAlreadyLiked: isLiked,
                    onDoubleTap: () async {
                      if (isLiked) return;
                      ref
                          .read(likeStateProvider.notifier)
                          .updateLikeState(post.id, true);
                      try {
                        await ref.read(postActionsServiceProvider).toggleLike(
                              postId: post.id,
                              ownerId: post.userId,
                              ref: ref,
                            );
                        unawaited(
                            ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                  postId: post.id,
                                  eventType: 'like',
                                ));
                      } catch (_) {
                        if (context.mounted) {
                          ref
                              .read(likeStateProvider.notifier)
                              .updateLikeState(post.id, false);
                        }
                      }
                    },
                    child: post.hasMultipleImages
                        ? SizedBox(
                            height: 280,
                            child: PostImageCarousel(
                              imageUrls: post.galleryImages,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: post.imageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            // P1: decode at display size, not full source res, to
                            // stop image-cache thrash / GC pauses while scrolling.
                            memCacheWidth: (MediaQuery.of(context).size.width *
                                    MediaQuery.of(context).devicePixelRatio)
                                .round(),
                            placeholder: (_, __) => Container(
                              height: 180,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 180,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],

          // ── ویدیو (هم‌سبک پروفایل) ─────────────────────────────
          if (hasVideo && !hasImage) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DoubleTapLikeOverlay(
                isAlreadyLiked: isLiked,
                onDoubleTap: () async {
                  if (isLiked) return;
                  ref
                      .read(likeStateProvider.notifier)
                      .updateLikeState(post.id, true);
                  try {
                    await ref.read(postActionsServiceProvider).toggleLike(
                          postId: post.id,
                          ownerId: post.userId,
                          ref: ref,
                        );
                    unawaited(
                        ref.read(goPostsRepositoryProvider).trackFeedEvent(
                              postId: post.id,
                              eventType: 'like',
                            ));
                  } catch (_) {
                    if (context.mounted) {
                      ref
                          .read(likeStateProvider.notifier)
                          .updateLikeState(post.id, false);
                    }
                  }
                },
                child: PostFeedVideo(
                  post: post,
                  maxHeight: 280,
                  borderRadius: BorderRadius.circular(14),
                  reelsPlaylist: reelsPlaylist,
                ),
              ),
            ),
          ],

          // ── دکمه‌های اکشن ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                PostLikeButton(
                  isLiked: isLiked,
                  likeCount: likeCount,
                  showCount: !post.hideLikeCount,
                  iconSize: 19,
                  gap: 4,
                  onTap: () async {
                    final willLike = !isLiked;
                    ref
                        .read(likeStateProvider.notifier)
                        .updateLikeState(post.id, willLike);
                    try {
                      await ref.read(postActionsServiceProvider).toggleLike(
                            postId: post.id,
                            ownerId: post.userId,
                            ref: ref,
                          );
                      if (willLike) {
                        unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'like',
                              ),
                        );
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ref
                            .read(likeStateProvider.notifier)
                            .updateLikeState(post.id, isLiked);
                      }
                    }
                  },
                ),
                const SizedBox(width: 14),
                PostCommentButton(
                  commentCount: post.commentCount,
                  showCount: !post.hideCommentCount,
                  iconSize: 19,
                  gap: 4,
                  onTap: () {
                    unawaited(
                        ref.read(goPostsRepositoryProvider).trackFeedEvent(
                              postId: post.id,
                              eventType: 'comment',
                            ));
                    showCommentsBottomSheet2(
                      context,
                      postId: post.id,
                      postTitle: post.content.isNotEmpty
                          ? post.content.substring(
                              0,
                              post.content.length > 30
                                  ? 30
                                  : post.content.length)
                          : 'پست',
                    );
                  },
                ),
                const SizedBox(width: 14),
                PostSaveButton(
                  isSaved: isSaved,
                  iconSize: 19,
                  onTap: () async {
                    final wasSaved = isSaved;
                    final ok = await ref
                        .read(savedPostIdsProvider.notifier)
                        .toggle(post.id, post: post);
                    if (ok && !wasSaved) {
                      unawaited(
                          ref.read(goPostsRepositoryProvider).trackFeedEvent(
                                postId: post.id,
                                eventType: 'save',
                              ));
                    }
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('خطا در ذخیره پست'),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 14),
                // Share button with proper tap area
                InkWell(
                  onTap: () {
                    unawaited(
                        ref.read(goPostsRepositoryProvider).trackFeedEvent(
                              postId: post.id,
                              eventType: 'share',
                            ));
                    SmartShareService().showShareOptions(post, context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                    child: Image.asset(
                      'lib/utils/images/component/send.png',
                      width: 19,
                      height: 19,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                const Spacer(),
                _buildPostActions(context, ref, post, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Post actions menu logic ---
  Widget _buildPostActions(
      BuildContext context, WidgetRef ref, PublicPostModel post, bool isDark) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        final isBlueTick = profile != null &&
            profile['is_verified'] == true &&
            profile['verification_type'] == 'blueTick';

        final currentUserId = ref.watch(activeUserProvider)?.id ??
            CurrentUserService.cachedUserId;
        final isCurrentUserPost = post.userId == currentUserId;

        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          color: isDark ? AppColors.darkSurface : Colors.white,
          icon: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.more_horiz,
              size: 20,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          itemBuilder: (context) {
            final items = <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text('گزارش پست'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'copy',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('کپی متن'),
                  ],
                ),
              ),
            ];

            // Personalization control (Twitter/Threads style): "show less like this"
            items.add(const PopupMenuItem<String>(
              value: 'not_interested',
              child: Row(
                children: [
                  Icon(Icons.remove_circle_outline,
                      color: Colors.grey, size: 20),
                  SizedBox(width: 8),
                  Text('مهم نیست / کمتر نشون بده'),
                ],
              ),
            ));

            if (isCurrentUserPost || isBlueTick) {
              items.add(const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('حذف پست'),
                  ],
                ),
              ));
            }

            // منطق نمایش گزینه ویرایش
            final currentUserProfile = ref.read(currentUserProfileProvider);
            final canManagePrivacy = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                  currentUserProfile.value!,
                ) &&
                isCurrentUserPost;
            final hasPremiumEdit = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;

            if (isCurrentUserPost) {
              if (canManagePrivacy) {
                items.add(PopupMenuItem<String>(
                  value: 'toggle_like_count',
                  child: Row(
                    children: [
                      Icon(
                        post.hideLikeCount
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.hideLikeCount
                            ? 'نمایش تعداد لایک'
                            : 'مخفی کردن تعداد لایک',
                      ),
                    ],
                  ),
                ));
                items.add(PopupMenuItem<String>(
                  value: 'toggle_comment_count',
                  child: Row(
                    children: [
                      Icon(
                        post.hideCommentCount
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                        color: Colors.deepPurple,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        post.hideCommentCount
                            ? 'نمایش تعداد کامنت'
                            : 'مخفی کردن تعداد کامنت',
                      ),
                    ],
                  ),
                ));
              } else {
                items.add(const PopupMenuItem<String>(
                  value: 'privacy_locked',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('کنترل آمار لایک/کامنت'),
                      Spacer(),
                      Icon(Icons.workspace_premium,
                          size: 18, color: Colors.amber),
                    ],
                  ),
                ));
              }
            }

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
                    const SizedBox(width: 8),
                    Text(isBlueTick ? 'ویرایش ناظر' : 'ویرایش پست'),
                  ],
                ),
              ));
            } else if (isCurrentUserPost) {
              items.add(const PopupMenuItem<String>(
                value: 'edit_locked',
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('ویرایش پست'),
                    Spacer(),
                    Icon(Icons.workspace_premium,
                        size: 18, color: Colors.amber),
                  ],
                ),
              ));
            }

            return items;
          },
          onSelected: (value) async {
            if (value == 'report') {
              // Real report flow (reason picker + POST /posts/report) — the
              // old local dialog only showed a fake success snackbar.
              showDialog(
                context: context,
                builder: (_) => ReportDialog(post: post),
              );
            } else if (value == 'copy') {
              await Clipboard.setData(ClipboardData(text: post.content));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('متن پست کپی شد'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            } else if (value == 'not_interested') {
              unawaited(ref.read(goPostsRepositoryProvider).trackFeedEvent(
                    postId: post.id,
                    eventType: 'not_interested',
                  ));
              // ignore: unused_result
              ref.refresh(personalizedFeedProvider);
            } else if (value == 'delete') {
              _showDeleteConfirmation(context, ref, post);
            } else if (value == 'edit') {
              if (isBlueTick && !isCurrentUserPost) {
                showStandardEditDialog(
                  context: context,
                  ref: ref,
                  post: post,
                  onSuccess: () {
                    // رفرش کردن پرووایدرها
                    // ignore: unused_result
                    ref.refresh(personalizedFeedProvider);
                    // ignore: unused_result
                    ref.refresh(fetchFollowingPostsProvider);
                  },
                );
              } else {
                showStandardEditDialog(
                  context: context,
                  ref: ref,
                  post: post,
                  onSuccess: () {
                    // ignore: unused_result
                    ref.refresh(personalizedFeedProvider);
                    // ignore: unused_result
                    ref.refresh(fetchFollowingPostsProvider);
                  },
                );
              }
            } else if (value == 'edit_locked') {
              PremiumFeaturesHelper.showPremiumPromptDialog(context,
                  feature: 'ویرایش پست');
            } else if (value == 'privacy_locked') {
              PremiumFeaturesHelper.showPremiumPromptDialog(
                context,
                feature: 'مخفی‌سازی آمار لایک و کامنت',
              );
            } else if (value == 'toggle_like_count' ||
                value == 'toggle_comment_count') {
              final currentProfile = ref.read(currentUserProfileProvider).value;
              if (currentProfile == null ||
                  !PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                    currentProfile,
                  )) {
                PremiumFeaturesHelper.showPremiumPromptDialog(
                  context,
                  feature: 'مخفی‌سازی آمار لایک و کامنت',
                );
                return;
              }

              try {
                final hideLike =
                    value == 'toggle_like_count' ? !post.hideLikeCount : null;
                final hideComment = value == 'toggle_comment_count'
                    ? !post.hideCommentCount
                    : null;

                await ref
                    .read(goPostsRepositoryProvider)
                    .updateEngagementVisibility(
                      postId: post.id,
                      hideLikeCount: hideLike,
                      hideCommentCount: hideComment,
                    );

                // ignore: unused_result
                ref.refresh(personalizedFeedProvider);
                // ignore: unused_result
                ref.refresh(fetchFollowingPostsProvider);

                if (context.mounted) {
                  final updatedLikeHidden = hideLike ?? post.hideLikeCount;
                  final updatedCommentHidden =
                      hideComment ?? post.hideCommentCount;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'آمار لایک: ${updatedLikeHidden ? 'مخفی' : 'نمایش'} | '
                        'کامنت: ${updatedCommentHidden ? 'مخفی' : 'نمایش'}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(context, e);
                }
              }
            }
          },
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, WidgetRef ref, PublicPostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف پست'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پست را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(postActionsServiceProvider)
                    .deletePost(ref, post.id);
                // Refresh feeds
                // ignore: unused_result
                ref.refresh(personalizedFeedProvider);
                // ignore: unused_result
                ref.refresh(fetchFollowingPostsProvider);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('پست حذف شد')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(context, e);
                }
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Helper methods from ProfileScreen
  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
