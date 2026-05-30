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
import 'PostDetailPage.dart';
import 'notificationScreen.dart';
import 'profileScreen.dart';

import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:flutter/services.dart';
import '../../../services/smart_share_service.dart';
import '../../../services/current_user_service.dart';
import 'package:Vista/utils/premium_features_helper.dart';
import 'package:Vista/utils/comments_bottom_sheet.dart';
import 'package:Vista/services/system_ui_bar_service.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../widgets/post_action_buttons.dart';
import '../widgets/hashtag_rich_text.dart';
import '../providers/saved_posts_provider.dart';
import '../data/go_posts_repository.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import '../../../widgets/verification_badge_icon.dart';
import 'package:Vista/features/stories/stories.dart';
import 'package:Vista/core/theme/app_theme.dart';
import '../../../widgets/skeleton_loading.dart';
import '../widgets/double_tap_like_overlay.dart';
import 'package:Vista/l10n/generated/app_localizations.dart';

// -----------------------------------------------------------------------------
// SCREEN
// -----------------------------------------------------------------------------

/// Tracks which author ids are currently being followed (in-flight) from the feed UI.
final _feedFollowLoadingProvider =
    StateProvider<Set<String>>((ref) => <String>{});

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
            child: _FeedEmptyState(
              title: AppLocalizations.of(context)?.noPostsReady ??
                  'هنوز پستی برای شما آماده نشده',
              subtitle: AppLocalizations.of(context)?.followToPersonalize ??
                  'با دنبال‌کردن کاربران جدید، فید شما سریع‌تر شخصی‌سازی می‌شود.',
              actionLabel:
                  AppLocalizations.of(context)?.searchUsers ?? 'جستجوی کاربران',
              onAction: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SearchPage()),
                );
              },
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(personalizedFeedProvider.notifier).refreshPosts(),
          child: ListView.builder(
            scrollCacheExtent: ScrollCacheExtent.pixels(1000),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                notifier.loadMorePosts();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final post = posts[index];
              return Column(
                children: [
                  _ThreadPostItem(post: post, isForYou: true),
                  const Divider(height: 0.5, thickness: 0.5),
                ],
              );
            },
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
            child: _FeedEmptyState(
              title: AppLocalizations.of(context)?.noFollowingPosts ??
                  'پستی از دنبال‌شده‌ها پیدا نشد',
              subtitle: AppLocalizations.of(context)?.followMorePeople ??
                  'افراد بیشتری را دنبال کنید یا کمی بعد دوباره بررسی کنید.',
              actionLabel:
                  AppLocalizations.of(context)?.refreshFeed ?? 'تازه‌سازی فید',
              onAction: () =>
                  ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
          child: ListView.builder(
            scrollCacheExtent: ScrollCacheExtent.pixels(1000),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                notifier.loadMorePosts();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final post = posts[index];
              return Column(
                children: [
                  _ThreadPostItem(post: post, isForYou: false),
                  const Divider(height: 0.5, thickness: 0.5),
                ],
              );
            },
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
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).viewPadding.bottom + 110,
      ),
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

  const _ThreadPostItem({required this.post, required this.isForYou});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final isLiked = ref.watch(likeStateProvider)[post.id] ?? post.isLiked;
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

    final followLoading = ref.watch(_feedFollowLoadingProvider);
    final isFollowBusy = followLoading.contains(post.userId);
    final savedPostIdsAsync = ref.watch(savedPostIdsProvider);
    final isSaved = savedPostIdsAsync.maybeWhen(
      data: (ids) => ids.contains(post.id),
      orElse: () => false,
    );

    // استفاده از GestureDetector به جای InkWell برای حذف افکت ریپل از کل پست
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(ref.read(goPostsRepositoryProvider).trackFeedEvent(
              postId: post.id,
              eventType: 'open',
            ));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailsPage(postId: post.id)),
        );
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                            userId: post.userId, username: post.username),
                      ),
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

                      // متن پست
                      if (post.content.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          alignment: _getTextDirection(post.content) ==
                                  TextDirection.rtl
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Directionality(
                            textDirection: _getTextDirection(post.content),
                            child: HashtagRichText(
                              text: post.content,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.4,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.9),
                              ),
                              hashtagStyle: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              onHashtagTap: (tag) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        SearchPage(initialHashtag: '#$tag'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── تصویر تمام‌عرض ──────────────────────────────────────
          if (hasImage) ...[
            const SizedBox(height: 10),
            DoubleTapLikeOverlay(
              isAlreadyLiked: isLiked,
              onDoubleTap: () async {
                if (isLiked) return;
                ref
                    .read(likeStateProvider.notifier)
                    .updateLikeState(post.id, true);
                try {
                  await ref
                      .read(postActionsServiceProvider)
                      .toggleLike(
                        postId: post.id,
                        ownerId: post.userId,
                        ref: ref,
                      );
                } catch (_) {
                  if (context.mounted) {
                    ref
                        .read(likeStateProvider.notifier)
                        .updateLikeState(post.id, false);
                  }
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 260,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 180,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          ],

          // ── دکمه‌های اکشن ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 12),
            child: Row(
              children: [
                PostLikeButton(
                  isLiked: isLiked,
                  likeCount: likeCount,
                  onTap: () async {
                    ref
                        .read(likeStateProvider.notifier)
                        .updateLikeState(post.id, !isLiked);
                    try {
                      await ref
                          .read(postActionsServiceProvider)
                          .toggleLike(
                            postId: post.id,
                            ownerId: post.userId,
                            ref: ref,
                          );
                    } catch (_) {
                      if (context.mounted) {
                        ref
                            .read(likeStateProvider.notifier)
                            .updateLikeState(post.id, isLiked);
                      }
                    }
                  },
                ),
                const SizedBox(width: 16),
                PostCommentButton(
                  commentCount: post.commentCount,
                  onTap: () {
                    unawaited(ref
                        .read(goPostsRepositoryProvider)
                        .trackFeedEvent(
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
                const SizedBox(width: 16),
                PostSaveButton(
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
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    unawaited(ref
                        .read(goPostsRepositoryProvider)
                        .trackFeedEvent(
                          postId: post.id,
                          eventType: 'share',
                        ));
                    SmartShareService().showShareOptions(post, context);
                  },
                  child: Image.asset(
                    'lib/utils/images/component/send.png',
                    width: 20,
                    height: 20,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
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
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          // آیکون دقیقاً مشابه پروفایل با کانتینر
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.more_horiz,
              size: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
            final hasPremiumEdit = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;

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
              _showReportDialog(context, ref);
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
            }
          },
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش پست'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پست را گزارش دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('گزارش شما ثبت شد')),
              );
            },
            child: const Text('گزارش', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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

  TextDirection _getTextDirection(String text) {
    if (text.isEmpty) return TextDirection.rtl;
    final cleanedText = text.replaceAll(RegExp(r'[^\w\u0600-\u06FF]'), '');
    if (cleanedText.isEmpty) return TextDirection.rtl;
    final firstChar = cleanedText[0];
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(firstChar)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}
