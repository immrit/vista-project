import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Models
import '../../../model/publicPostModel.dart';

// Import Providers
import '../../../provider/provider.dart';
import '../../../provider/personalized_feed_provider.dart';

// Import Screens (for navigation)
import 'PostDetailPage.dart';
import 'profileScreen.dart';

import 'package:Vista/features/posts/widgets/standard_edit_post_dialog.dart';
import 'package:flutter/services.dart';
import '../../../services/smart_share_service.dart';
import '../../../services/vista_node_service.dart';
import 'package:Vista/utils/premium_features_helper.dart';
import 'package:Vista/utils/comments_bottom_sheet.dart';
import '../widgets/post_action_buttons.dart';
import '../widgets/hashtag_rich_text.dart';
import 'package:Vista/features/search/screens/searchPage.dart';

// -----------------------------------------------------------------------------
// SCREEN
// -----------------------------------------------------------------------------

/// Tracks which author ids are currently being followed (in-flight) from the feed UI.
final _feedFollowLoadingProvider = StateProvider<Set<String>>((ref) => <String>{});

class ExploreFeedScreen extends ConsumerStatefulWidget {
  const ExploreFeedScreen({super.key});

  @override
  ConsumerState<ExploreFeedScreen> createState() => _ExploreFeedScreenState();
}

class _ExploreFeedScreenState extends ConsumerState<ExploreFeedScreen> {
  @override
  void initState() {
    super.initState();
    // Logic to hide/show AppBar on scroll (Snap behavior is handled by SliverAppBar,
    // but extra logic can be added here if needed for bottom bars etc.)
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: backgroundColor,
                foregroundColor: textColor,
                floating: true,
                snap: true,
                pinned: true, // Keep the tab bar pinned
                elevation: 0,
                title: Image.asset(
                  isDark
                      ? 'lib/utils/images/logo/logo-white.png'
                      : 'lib/utils/images/logo/black-logo.png',
                  height: 35,
                  fit: BoxFit.cover,
                ),
                centerTitle: true,
                bottom: TabBar(
                  indicatorColor: textColor,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: textColor,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                  tabs: const [
                    Tab(text: "برای شما"),
                    Tab(text: "دنبالکنندگان"),
                  ],
                ),
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
          return const Center(child: Text('پستی یافت نشد'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(personalizedFeedProvider.notifier).refreshPosts(),
          child: ListView.builder(
            cacheExtent: 1000, // Optimize rendering
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                notifier.loadMorePosts();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطا در بارگذاری: $err')),
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
          return const Center(child: Text('پستی از دنبال‌شدگان یافت نشد'));
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.read(fetchFollowingPostsProvider.notifier).refreshPosts(),
          child: ListView.builder(
            cacheExtent: 1000,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length + (notifier.hasMorePosts() ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == posts.length) {
                notifier.loadMorePosts();
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('خطا: $err')),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGETS
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// WIDGETS
// -----------------------------------------------------------------------------

/// آیتم لیست پست (دقیقاً مشابه پروفایل با منطق منوی publicPosts)
class _ThreadPostItem extends ConsumerWidget {
  final PublicPostModel post;
  final bool isForYou;

  const _ThreadPostItem({required this.post, required this.isForYou});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final followStatus = post.authorFollowStatus;
    final shouldShowFollowButton = isForYou &&
        currentUserId != null &&
        post.userId.isNotEmpty &&
        post.userId != currentUserId &&
        (followStatus == 'none' || followStatus == 'requested');

    final followLoading = ref.watch(_feedFollowLoadingProvider);
    final isFollowBusy = followLoading.contains(post.userId);

    // استفاده از GestureDetector به جای InkWell برای حذف افکت ریپل از کل پست
    return GestureDetector(
      behavior: HitTestBehavior.opaque, // اطمینان از کلیک‌پذیری کل محدوده
      onTap: () {
        VistaNodeService.trackFeedEvent(
          postId: post.id,
          eventType: 'open',
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailsPage(postId: post.id)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
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
                // محتوای پست
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
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (post.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified,
                                      size: 14, color: Colors.blue),
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
                                          visualDensity:
                                              VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(
                                            fontFamily: 'Vazirmatn',
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text('درخواست شد'),
                                          ),
                                        ),
                                      )
                                    : FilledButton(
                                        onPressed: isFollowBusy
                                            ? null
                                            : () async {
                                                final targetId = post.userId;
                                                if (targetId.isEmpty ||
                                                    targetId ==
                                                        currentUserId) {
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
                                                          supabaseServiceProvider)
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
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            'خطا در دنبال کردن: $e'),
                                                      ),
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
                                          visualDensity:
                                              VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(
                                            fontFamily: 'Vazirmatn',
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
                                            : const Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text('دنبال کردن'),
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
                        Directionality(
                          textDirection: _getTextDirection(post.content),
                          child: HashtagRichText(
                            text: post.content,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: isDark ? Colors.white70 : Colors.black87,
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
                        const SizedBox(height: 10),
                      ],

                      // تصویر پست
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 280,
                              minWidth: double.infinity,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: post.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 180,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 180,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // دکمه‌های اکشن - دقیقاً مشابه پروفایل
                      Row(
                        children: [
                          // دکمه لایک
                          Consumer(
                            builder: (context, ref, child) {
                              final isLiked =
                                  ref.watch(likeStateProvider)[post.id] ??
                                      post.isLiked;
                              final likeCount = post.likeCount +
                                  (isLiked != post.isLiked
                                      ? (isLiked ? 1 : -1)
                                      : 0);

                              return PostLikeButton(
                                isLiked: isLiked,
                                likeCount: likeCount,
                                onTap: () async {
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
                                  } catch (_) {
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
                          const SizedBox(width: 16),
                          // دکمه کامنت
                          PostCommentButton(
                            commentCount: post.commentCount,
                            onTap: () {
                              VistaNodeService.trackFeedEvent(
                                postId: post.id,
                                eventType: 'comment',
                              );
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
                          // دکمه اشتراک‌گذاری
                          GestureDetector(
                            onTap: () {
                              VistaNodeService.trackFeedEvent(
                                postId: post.id,
                                eventType: 'share',
                              );
                              SmartShareService()
                                  .showShareOptions(post, context);
                            },
                            child: Image.asset(
                              'lib/utils/images/component/send.png',
                              width: 20,
                              height: 20,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          // منو (سه نقطه) - با همان استایل پروفایل (Container)
                          _buildPostActions(context, ref, post, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- Logic from publicPosts.dart regarding Menu ---
  Widget _buildPostActions(
      BuildContext context, WidgetRef ref, PublicPostModel post, bool isDark) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (profile) {
        final isBlueTick = profile != null &&
            profile['is_verified'] == true &&
            profile['verification_type'] == 'blueTick';

        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
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
              VistaNodeService.trackFeedEvent(
                postId: post.id,
                eventType: 'not_interested',
              );
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
                    .read(supabaseServiceProvider)
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطا در حذف: $e')),
                  );
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
    final firstChar = text.trim().isNotEmpty ? text.trim()[0] : '';
    final persianRegex = RegExp(r'[\u0600-\u06FF]');
    return persianRegex.hasMatch(firstChar)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }
}
