import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../model/publicPostModel.dart';
import '../../../provider/provider.dart';
import '../../../services/current_user_service.dart';
import '../../../services/smart_share_service.dart';
import '../../../utils/comments_bottom_sheet.dart';
import '../../../utils/directional_navigation.dart';
import '../../../utils/user_friendly_error_utils.dart';
import '../../../utils/premium_features_helper.dart';
import '../../../widgets/verification_badge_icon.dart';
import '../../../widgets/skeleton_loading.dart';
import '../data/go_posts_repository.dart';
import '../providers/saved_posts_provider.dart';
import '../widgets/double_tap_like_overlay.dart';
import '../widgets/hashtag_rich_text.dart';
import '../widgets/post_image_carousel.dart';
import '../widgets/post_action_buttons.dart';
import '../widgets/post_moderation_banner.dart';
import '../widgets/standard_edit_post_dialog.dart';
import 'package:Vista/features/posts/navigation/content_routes.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'package:Vista/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SavedPostsScreen extends ConsumerStatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  ConsumerState<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends ConsumerState<SavedPostsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent * 0.75;
    if (_scrollController.position.pixels >= threshold) {
      ref.read(savedPostsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(savedPostsProvider.notifier).refresh();
    await ref.read(savedPostIdsProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(savedPostsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'پست‌های ذخیره‌شده',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            directionalBackIcon(context, ios: true),
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // شمارنده پست‌های ذخیره‌شده
          if (!state.isLoading && state.posts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${state.posts.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _buildBody(state, isDark),
      ),
    );
  }

  Widget _buildBody(SavedPostsState state, bool isDark) {
    // حالت لودینگ اولیه
    if (state.isLoading && state.posts.isEmpty) {
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        itemBuilder: (_, __) => const PostCardSkeleton(),
      );
    }

    // حالت خطا
    if (state.error != null && state.posts.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded,
                      size: 56,
                      color: isDark ? Colors.grey[500] : Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'خطا در دریافت اطلاعات',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'اتصال اینترنت را بررسی کنید',
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _onRefresh,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // حالت خالی
    if (state.posts.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_border_rounded,
                      size: 44,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'هنوز پستی ذخیره نکرده‌اید',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'پست‌هایی که دوست دارید\nاینجا ذخیره می‌شوند',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // لیست پست‌ها
    return ListView.separated(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: state.posts.length + 1,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: isDark ? Colors.white12 : Colors.black12,
      ),
      itemBuilder: (context, index) {
        if (index == state.posts.length) {
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          if (!state.hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'همه پست‌های ذخیره‌شده نمایش داده شدند',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        return _SavedPostItem(post: state.posts[index]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST ITEM - دقیقاً مشابه _ThreadPostItem در فید اصلی
// ─────────────────────────────────────────────────────────────────────────────

String _getTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'همین الان';
  if (diff.inMinutes < 60) return '${diff.inMinutes}د';
  if (diff.inHours < 24) return '${diff.inHours}س';
  if (diff.inDays < 7) return '${diff.inDays}ر';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}ه';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}م';
  return '${(diff.inDays / 365).floor()}س';
}

class _SavedPostItem extends ConsumerWidget {
  final PublicPostModel post;

  const _SavedPostItem({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final hasImage = post.imageUrl != null && post.imageUrl!.isNotEmpty;

    final isLiked =
        ref.watch(likeStateProvider.select((map) => map[post.id])) ??
            post.isLiked;
    final likeCount =
        post.likeCount + (isLiked != post.isLiked ? (isLiked ? 1 : -1) : 0);

    final currentUserId =
        ref.watch(activeUserProvider)?.id ?? CurrentUserService.cachedUserId;

    final isSaved = ref.watch(
      savedPostIdsProvider.select(
        (async) => async.maybeWhen(
          data: (ids) => ids.contains(post.id),
          orElse: () => true,
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        ContentNavigation.pushPostDetail(context, postId: post.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── آواتار ───
                GestureDetector(
                  onTap: () => ContentNavigation.pushProfile(
                    context,
                    userId: post.userId,
                    username: post.username,
                  ),
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

                // ─── محتوا ───
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // هدر: نام + badge + زمان | (بدون دکمه follow در saved)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: GestureDetector(
                                    onTap: () => ContentNavigation.pushProfile(
                                      context,
                                      userId: post.userId,
                                      username: post.username,
                                    ),
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
                                builder: (_) =>
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
                        const SizedBox(height: 10),
                      ],

                      // تصویر پست
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: DoubleTapLikeOverlay(
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
                            child: post.hasMultipleImages
                                ? SizedBox(
                                    height: 280,
                                    child: PostImageCarousel(
                                      imageUrls: post.galleryImages,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  )
                                : ConstrainedBox(
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
                                              strokeWidth: 2),
                                        ),
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
                        ),

                      const SizedBox(height: 12),

                      // ردیف اکشن‌ها
                      Row(
                        children: [
                          // لایک
                          PostLikeButton(
                            isLiked: isLiked,
                            likeCount: likeCount,
                            showCount: !post.hideLikeCount,
                            iconSize: 19,
                            gap: 4,
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
                          const SizedBox(width: 14),

                          // کامنت
                          PostCommentButton(
                            commentCount: post.commentCount,
                            showCount: !post.hideCommentCount,
                            iconSize: 19,
                            gap: 4,
                            onTap: () {
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

                          // ذخیره (bookmark) - با قابلیت unsave مستقیم
                          PostSaveButton(
                            isSaved: isSaved,
                            iconSize: 19,
                            onTap: () async {
                              final ok = await ref
                                  .read(savedPostIdsProvider.notifier)
                                  .toggle(post.id, post: post);

                              if (!ok && context.mounted) {
                                UserFriendlyErrorUtils.showErrorSnackBar(
                                  context,
                                  'خطا در تغییر وضعیت ذخیره',
                                );
                              } else if (context.mounted && isSaved) {
                                // اگر unsave کرد یه تایید کوتاه نشون بده
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'از پست‌های ذخیره‌شده حذف شد'),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.all(12),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    duration: const Duration(seconds: 2),
                                    action: SnackBarAction(
                                      label: 'بازگردانی',
                                      onPressed: () {
                                        ref
                                            .read(savedPostIdsProvider.notifier)
                                            .toggle(post.id, post: post);
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 14),

                          // اشتراک‌گذاری
                          InkWell(
                            onTap: () => SmartShareService()
                                .showShareOptions(post, context),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 3,
                              ),
                              child: Image.asset(
                                'lib/utils/images/component/send.png',
                                width: 19,
                                height: 19,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),

                          const Spacer(),

                          // منو سه‌نقطه
                          _buildPostMenu(context, ref, isDark, currentUserId),
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

  Widget _buildPostMenu(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    String? currentUserId,
  ) {
    final profileAsync = ref.watch(profileProvider);
    final isCurrentUserPost = post.userId == currentUserId;

    return profileAsync.when(
      data: (profile) {
        final isBlueTick = profile != null &&
            profile['is_verified'] == true &&
            profile['verification_type'] == 'blueTick';

        return PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          color: isDark ? AppColors.darkSurface : Colors.white,
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
              // کپی متن
              const PopupMenuItem<String>(
                value: 'copy',
                child: Row(children: [
                  Icon(Icons.content_copy, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('کپی متن'),
                ]),
              ),
              // حذف از ذخیره‌شده‌ها
              const PopupMenuItem<String>(
                value: 'unsave',
                child: Row(children: [
                  Icon(Icons.bookmark_remove_outlined,
                      color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('حذف از ذخیره‌شده‌ها'),
                ]),
              ),
              // گزارش
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(children: [
                  Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('گزارش پست'),
                ]),
              ),
            ];

            if (isCurrentUserPost || isBlueTick) {
              items.add(const PopupMenuItem<String>(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('حذف پست'),
                ]),
              ));
            }

            final currentUserProfile = ref.read(currentUserProfileProvider);
            final hasPremiumEdit = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;

            if (isBlueTick || hasPremiumEdit) {
              items.add(PopupMenuItem<String>(
                value: 'edit',
                child: Row(children: [
                  Icon(
                    isBlueTick ? Icons.admin_panel_settings : Icons.edit,
                    size: 20,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(isBlueTick ? 'ویرایش ناظر' : 'ویرایش پست'),
                ]),
              ));
            }

            return items;
          },
          onSelected: (value) =>
              _handleMenuAction(context, ref, value, isDark, isCurrentUserPost),
        );
      },
      loading: () => const SizedBox(width: 34, height: 34),
      error: (_, __) => const SizedBox(width: 34, height: 34),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String value,
    bool isDark,
    bool isCurrentUserPost,
  ) {
    switch (value) {
      case 'copy':
        if (post.content.isNotEmpty) {
          Clipboard.setData(ClipboardData(text: post.content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('متن کپی شد'),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }

      case 'unsave':
        ref.read(savedPostIdsProvider.notifier).toggle(post.id, post: post);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('از پست‌های ذخیره‌شده حذف شد'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'بازگردانی',
              onPressed: () {
                ref
                    .read(savedPostIdsProvider.notifier)
                    .toggle(post.id, post: post);
              },
            ),
          ),
        );

      case 'report':
        _showReportDialog(context, ref);

      case 'delete':
        _showDeleteDialog(context, ref);

      case 'edit':
        showStandardEditDialog(
          context: context,
          ref: ref,
          post: post,
          onSuccess: () {
            ref.read(savedPostsProvider.notifier).refresh();
          },
        );
    }
  }

  void _showReportDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('گزارش پست'),
        content: const Text('آیا می‌خواهید این پست را گزارش دهید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(goPostsRepositoryProvider).reportPost(
                      postId: post.id,
                      reportedUserId: post.userId,
                      reason: 'inappropriate_content',
                    );
                if (ctx.mounted) {
                  UserFriendlyErrorUtils.showSuccessSnackBar(
                      ctx, 'گزارش شما ثبت شد');
                }
              } catch (e) {
                if (ctx.mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(ctx, e);
                }
              }
            },
            child: const Text('گزارش'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف پست'),
        content:
            const Text('آیا مطمئن هستید که می‌خواهید این پست را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(goPostsRepositoryProvider).deletePost(post.id);
                ref
                    .read(savedPostsProvider.notifier)
                    .removePostLocally(post.id);
                ref
                    .read(savedPostIdsProvider.notifier)
                    .toggle(post.id, post: post);
                if (ctx.mounted) {
                  UserFriendlyErrorUtils.showSuccessSnackBar(ctx, 'پست حذف شد');
                }
              } catch (e) {
                if (ctx.mounted) {
                  UserFriendlyErrorUtils.showErrorSnackBar(ctx, e);
                }
              }
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}
