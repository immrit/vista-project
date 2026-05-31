import '../../../security/logging_utility.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../model/publicPostModel.dart';
import 'package:Vista/utils/widgets.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import 'profileScreen.dart';
import '../../../model/CommentModel.dart';
import '../../../model/UserModel.dart';
import '../../../provider/provider.dart';
import '../../../utils/user_friendly_error_utils.dart';
import 'package:Vista/features/posts/widgets/post_music_bubble.dart';
import '../../../utils/premium_features_helper.dart';
import '../../../services/smart_share_service.dart';
import '../../../services/current_user_service.dart';
import '../../profile/data/profile_repository.dart';
import '../providers/saved_posts_provider.dart';
import '../data/go_posts_repository.dart';
import '../widgets/standard_edit_post_dialog.dart';
import 'package:Vista/widgets/verification_badge_icon.dart';

class PostDetailsPage extends ConsumerStatefulWidget {
  const PostDetailsPage({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends ConsumerState<PostDetailsPage> {
  late TextEditingController commentController;
  final List<UserModel> mentionedUsers = [];
  String? replyToCommentId;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    commentController = TextEditingController();
  }

  // Loading widget
  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('در حال بارگذاری پست...'),
        ],
      ),
    );
  }

// یک متد برای جلب userId از پایگاه داده بر اساس username
  Future<String?> getUserIdByUsername(String username) async {
    final profile = await ProfileRepository().fetchProfileByUsername(username);
    final id = profile['id'] ?? profile['user_id'];
    return id?.toString();
  }

  TextDirection getDirectionality(String content) {
    return content.startsWith('@') ? TextDirection.ltr : TextDirection.rtl;
  }

  Widget _buildPostImages(PublicPostModel post) {
    if (post.imageUrl == null || post.imageUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: FutureBuilder<Size>(
        future: _getImageDimensions(post.imageUrl!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.error_outline, size: 40, color: Colors.grey),
              ),
            );
          }

          final size = snapshot.data!;
          return GestureDetector(
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
              tag: 'post_image_${post.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: size.width > 0 && size.height > 0 ? size.width / size.height : 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    child: _buildImageWithRetry(post.imageUrl!),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<Size> _getImageDimensions(String imageUrl) async {
    final Completer<Size> completer = Completer();
    final ImageProvider imageProvider = CachedNetworkImageProvider(imageUrl);

    imageProvider.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              if (!completer.isCompleted) {
                completer.complete(Size(
                  info.image.width.toDouble(),
                  info.image.height.toDouble(),
                ));
              }
            },
            onError: (dynamic exception, StackTrace? stackTrace) {
              if (!completer.isCompleted) {
                completer.completeError(exception);
              }
            },
          ),
        );

    return completer.future;
  }

  Widget _buildPostDetails(BuildContext context, PublicPostModel post) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostCard(post),
          const SizedBox(height: 16),
          _buildCommentsSection(),
        ],
      ),
    );
  }

  Widget _buildPostContent(String content, BuildContext context) {
    final pattern = RegExp(
      r'#[\w\u0600-\u06FF]+', // Simplified regex for hashtags only
      multiLine: true,
      unicode: true,
    );

    List<TextSpan> spans = [];
    int start = 0;

    for (Match match in pattern.allMatches(content)) {
      // Add text before hashtag
      if (match.start > start) {
        spans.add(TextSpan(
          text: content.substring(start, match.start),
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            height: 1.5,
          ),
        ));
      }

      // Add hashtag
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(
            color: Colors.blue,
            fontWeight: FontWeight.w500,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchPage(
                    initialHashtag: match.group(0)!,
                  ),
                ),
              );
            },
        ),
      );

      start = match.end;
    }

    // Add remaining text
    if (start < content.length) {
      spans.add(TextSpan(
        text: content.substring(start),
        style: TextStyle(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
          height: 1.5,
        ),
      ));
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RichText(
        textAlign: TextAlign.right,
        text: TextSpan(
          children: spans,
        ),
      ),
    );
  }

  Widget _buildPostCard(PublicPostModel post) {
    return Card(
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(post),
            const SizedBox(height: 10),
            Directionality(
              textDirection: getDirectionality(post.content),
              child: _buildPostContent(post.content, context),
            ),
            // نمایش هشتگ‌ها
            if (post.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: post.hashtags
                    .map<Widget>(
                      (String tag) => GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchPage(
                                initialHashtag: '#$tag',
                              ),
                            ),
                          );
                        },
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            _buildPostImages(post),
            const SizedBox(height: 10),
            _buildLikeRow(post),
            if (post.musicUrl != null && post.musicUrl!.isNotEmpty)
              PostMusicBubble(
                postId: post.id,
                musicUrl: post.musicUrl!,
                createdAt: post.createdAt,
                title: _resolveMusicTitle(post),
                artist: post.username,
                avatarUrl: post.avatarUrl,
                margin: const EdgeInsets.symmetric(vertical: 16),
              ),
          ],
        ),
      ),
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

  Widget _buildPostHeader(PublicPostModel post) {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: post.avatarUrl.isEmpty
              ? const AssetImage('lib/utils/images/default-avatar.jpg')
              : CachedNetworkImageProvider(post.avatarUrl),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    post.username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 5),
                  if (post.isVerified) _buildVerificationBadge(post)
                ],
              ),
              Text(
                _formatDate(post.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        _buildPostActionsMenu(post),
      ],
    );
  }

  Widget _buildPostActionsMenu(PublicPostModel post) {
    return Consumer(
      builder: (context, ref, child) {
        final profileAsync = ref.watch(profileProvider);
        final currentUserId = ref.watch(activeUserProvider)?.id ??
            CurrentUserService.cachedUserId;
        final isCurrentUserPost = post.userId == currentUserId;

        return profileAsync.when(
          data: (profile) {
            // استفاده از Helper برای بررسی دسترسی
            final currentUserProfile = ref.read(currentUserProfileProvider);
            final canEditPost = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
                isCurrentUserPost;
            final canManagePrivacy = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                  currentUserProfile.value!,
                ) &&
                isCurrentUserPost;

            return PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) async {
                switch (value) {
                  case 'delete':
                    // مدیران (تیک آبی) می‌توانند همه پست‌ها را حذف کنند، کاربران عادی فقط پست خودشان
                    final isBlueTickForDelete = profile != null &&
                        profile['is_verified'] == true &&
                        profile['verification_type'] == 'blueTick';
                    if (isCurrentUserPost || isBlueTickForDelete) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('حذف پست'),
                          content:
                              const Text('آیا از حذف این پست اطمینان دارید؟'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('انصراف'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('حذف'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        try {
                          await ref
                              .read(postActionsServiceProvider)
                              .deletePost(ref, post.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('پست با موفقیت حذف شد')),
                            );
                            Navigator.of(context).pop(); // Close detail page
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('خطا در حذف پست')),
                            );
                          }
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('شما نمی‌توانید این پست را حذف کنید'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    break;
                  case 'edit':
                    if (canEditPost) {
                      showStandardEditDialog(
                        context: context,
                        ref: ref,
                        post: post,
                        onSuccess: () {
                          ref.invalidate(postProvider(widget.postId));
                        },
                      );
                    } else {
                      // نمایش دیالوگ پریمیوم اگر دسترسی ندارد
                      if (isCurrentUserPost) {
                        PremiumFeaturesHelper.showPremiumPromptDialog(
                          context,
                          feature: 'ویرایش پست',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('شما مجوز ویرایش این پست را ندارید'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                    break;
                  case 'report':
                    if (!isCurrentUserPost) {
                      showDialog(
                        context: context,
                        builder: (context) => ReportDialog(post: post),
                      );
                    }
                    break;
                  case 'copy':
                    await Clipboard.setData(ClipboardData(text: post.content));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('متن پست کپی شد')),
                      );
                    }
                    break;
                  case 'privacy_locked':
                    PremiumFeaturesHelper.showPremiumPromptDialog(
                      context,
                      feature: 'مخفی‌سازی آمار لایک و کامنت',
                    );
                    break;
                  case 'toggle_like_count':
                  case 'toggle_comment_count':
                    final profile = ref.read(currentUserProfileProvider).value;
                    if (profile == null ||
                        !PremiumFeaturesHelper.canManagePostEngagementPrivacy(
                          profile,
                        )) {
                      PremiumFeaturesHelper.showPremiumPromptDialog(
                        context,
                        feature: 'مخفی‌سازی آمار لایک و کامنت',
                      );
                      break;
                    }
                    try {
                      final hideLike = value == 'toggle_like_count'
                          ? !post.hideLikeCount
                          : null;
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
                      ref.invalidate(postProvider(widget.postId));
                      if (context.mounted) {
                        final updatedLike = hideLike ?? post.hideLikeCount;
                        final updatedComment =
                            hideComment ?? post.hideCommentCount;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'آمار لایک: ${updatedLike ? 'مخفی' : 'نمایش'} | '
                              'کامنت: ${updatedComment ? 'مخفی' : 'نمایش'}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('خطا در بروزرسانی تنظیمات پست')),
                        );
                      }
                    }
                    break;
                }
              },
              itemBuilder: (context) {
                final items = <PopupMenuItem<String>>[];

                // گزینه گزارش برای پست‌های دیگران
                if (!isCurrentUserPost) {
                  items.add(
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('گزارش پست'),
                        ],
                      ),
                    ),
                  );
                }

                // گزینه کپی برای همه
                items.add(
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('کپی متن'),
                      ],
                    ),
                  ),
                );

                // گزینه حذف برای صاحب پست یا مدیران (تیک آبی)
                final isBlueTickForDelete = profile != null &&
                    profile['is_verified'] == true &&
                    profile['verification_type'] == 'blueTick';
                if (isCurrentUserPost || isBlueTickForDelete) {
                  items.add(
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف پست'),
                        ],
                      ),
                    ),
                  );
                }

                // گزینه ویرایش برای صاحب پست (با یا بدون دسترسی)
                if (isCurrentUserPost) {
                  items.add(
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            canEditPost ? Icons.edit : Icons.lock_outline,
                            size: 20,
                            color: canEditPost ? Colors.blue : Colors.grey,
                          ),
                          const SizedBox(width: 12),
                          const Text('ویرایش پست'),
                          if (!canEditPost) ...[
                            const Spacer(),
                            Icon(
                              Icons.workspace_premium,
                              size: 18,
                              color: Colors.amber.shade600,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );

                  if (canManagePrivacy) {
                    items.add(
                      PopupMenuItem<String>(
                        value: 'toggle_like_count',
                        child: Row(
                          children: [
                            Icon(
                              post.hideLikeCount
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
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
                      ),
                    );
                    items.add(
                      PopupMenuItem<String>(
                        value: 'toggle_comment_count',
                        child: Row(
                          children: [
                            Icon(
                              post.hideCommentCount
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
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
                      ),
                    );
                  } else {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'privacy_locked',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, color: Colors.grey),
                            SizedBox(width: 8),
                            Text('کنترل آمار لایک/کامنت'),
                            Spacer(),
                            Icon(Icons.workspace_premium, color: Colors.amber),
                          ],
                        ),
                      ),
                    );
                  }
                }

                return items;
              },
            );
          },
          loading: () => PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (context) => [
              PopupMenuItem(
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
          ),
          error: (_, __) => PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            itemBuilder: (context) => [
              PopupMenuItem(
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
          ),
        );
      },
    );
  }

  Widget _buildVerificationBadge(PublicPostModel profile) {
    return VerificationBadgeIcon(
      isVerified: profile.isVerified,
      verificationType: profile.verificationType,
      role: profile.profiles?['role']?.toString(),
      size: 16,
    );
  }

  String _formatDate(DateTime date) {
    final jalaliDate = Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  Widget _buildLikeRow(PublicPostModel post) {
    final savedPostIdsAsync = ref.watch(savedPostIdsProvider);
    final isSaved = savedPostIdsAsync.maybeWhen(
      data: (ids) => ids.contains(post.id),
      orElse: () => false,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite_rounded : Icons.favorite_border,
            size: 19,
            color:
                post.isLiked ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          onPressed: () async {
            setState(() {
              post.isLiked = !post.isLiked;
              post.likeCount += post.isLiked ? 1 : -1;
            });
            await ref.read(postActionsServiceProvider).toggleLike(
                  postId: post.id,
                  ownerId: post.userId,
                  ref: ref,
                );
          },
        ),
        if (!post.hideLikeCount) Text('${post.likeCount}'),
        const SizedBox(width: 12),
        // دکمه کامنت با آیکون سفارشی
        GestureDetector(
          onTap: () {
            // اضافه کردن منطق نمایش کامنت‌ها
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Image.asset(
              'lib/utils/images/component/comment.png',
              width: 19,
              height: 19,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
        if (!post.hideCommentCount) Text('${post.commentCount}'),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: isSaved ? Theme.of(context).colorScheme.primary : null,
          ),
          onPressed: () async {
            final ok = await ref
                .read(savedPostIdsProvider.notifier)
                .toggle(post.id, post: post);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('خطا در ذخیره پست')),
              );
            }
          },
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () => SmartShareService().showShareOptions(post, context),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final commentsAsyncValue = ref.watch(commentsProvider(widget.postId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // هدر مدرن
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'نظرات',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: isDark ? Colors.grey[800] : Colors.grey[300],
        ),
        const SizedBox(height: 8),
        commentsAsyncValue.when(
          data: (comments) => comments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: isDark ? Colors.grey[700] : Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'هنوز نظری ثبت نشده',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اولین نفری باش که نظر میدی!',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[600] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildCommentTree(comments),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'خطا در بارگذاری نظرات',
                style: TextStyle(color: Colors.red[400]),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentTree(List<CommentModel> comments) {
    // ساختاردهی ریپلای‌ها در نقشه
    Map<String, CommentModel> commentMap = {
      for (var comment in comments) comment.id: comment
    };

    for (var comment in comments) {
      if (comment.parentCommentId != null) {
        var parent = commentMap[comment.parentCommentId!];
        if (parent != null) {
          parent.replies.add(comment);
        }
      }
    }

    // فقط کامنت‌های والد را نمایش دهید
    return Column(
      children: comments
          .where((comment) => comment.parentCommentId == null)
          .expand(_buildTree)
          .toList(),
    );
  }

  List<Widget> _buildTree(CommentModel comment) {
    return [
      _buildCommentItem(comment),
      if (comment.replies.isNotEmpty)
        ExpansionTile(
          title: Text(
            'نمایش ${comment.replies.length} پاسخ',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 13,
            ),
          ),
          children: comment.replies.expand(_buildTree).toList(),
        ),
    ];
  }

  Widget _buildCommentItem(CommentModel comment) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId =
        ref.watch(activeUserProvider)?.id ?? CurrentUserService.cachedUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // آواتار
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: comment.userId,
                      username: comment.username,
                    ),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: comment.avatarUrl.isEmpty
                    ? const AssetImage('lib/utils/images/default-avatar.jpg')
                    : CachedNetworkImageProvider(comment.avatarUrl)
                        as ImageProvider,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
            ),
            const SizedBox(width: 12),

            // محتوای کامنت
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // هدر (نام کاربری و زمان)
                  Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: comment.userId,
                                  username: comment.username,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            comment.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (comment.isVerified)
                        _buildVerificationBadgeComment(comment),
                      const SizedBox(width: 8),
                      Text(
                        _getTimeAgoComment(comment.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // متن کامنت
                  Directionality(
                    textDirection: getDirectionality(comment.content),
                    child: Text(
                      comment.content,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // دکمه‌های اکشن
                  Row(
                    children: [
                      // دکمه پاسخ
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            replyToCommentId = comment.id;
                            commentController.text = '@${comment.username} ';
                            commentController.selection =
                                TextSelection.fromPosition(
                              TextPosition(
                                  offset: commentController.text.length),
                            );
                          });
                        },
                        child: Text(
                          'پاسخ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.blue[300] : Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // منوی اکشن
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.more_horiz,
                          size: 18,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (context) => [
                          if (comment.userId != currentUserId)
                            const PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag,
                                      color: Colors.orange, size: 18),
                                  SizedBox(width: 8),
                                  Text('گزارش'),
                                ],
                              ),
                            ),
                          if (comment.userId == currentUserId)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                  SizedBox(width: 8),
                                  Text('حذف'),
                                ],
                              ),
                            ),
                        ],
                        onSelected: (value) {
                          if (value == 'report') {
                            if (currentUserId != null) {
                              _showReportDialog(
                                  context, ref, comment, currentUserId);
                            }
                          } else if (value == 'delete') {
                            _deleteComment(
                                context, ref, comment.id, widget.postId);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgoComment(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      // برای تاریخ‌های قدیمی‌تر از یک هفته، تاریخ جلالی نمایش بده
      final jalaliDate = Jalali.fromDateTime(dateTime.toLocal());
      return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'همین الان';
    }
  }

  Widget _buildVerificationBadgeComment(CommentModel profile) {
    return VerificationBadgeIcon(
      isVerified: profile.isVerified,
      verificationType: profile.verificationType,
      role: profile.role,
      size: 16,
    );
  }

  void _sendComment() async {
    final content = commentController.text.trim();
    final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

    if (content.isEmpty) return;

    try {
      final notifier = ref.read(commentNotifierProvider.notifier);
      final postOwnerId = await notifier.getPostOwnerId(widget.postId);

      await notifier.addComment(
        postId: widget.postId,
        content: content,
        postOwnerId: postOwnerId,
        mentionedUserIds: mentionedUserIds,
        parentCommentId: replyToCommentId,
        ref: ref,
      );

      commentController.clear();
      replyToCommentId = null;
      mentionedUsers.clear();
      ref.invalidate(commentsProvider(widget.postId));
      UserFriendlyErrorUtils.showSuccessSnackBar(
          context, 'نظر با موفقیت ثبت شد');
    } catch (e) {
      UserFriendlyErrorUtils.showErrorSnackBar(context, e);
    }
  }

  Widget _buildCommentInputArea(
      BuildContext context, List<UserModel> mentionNotifier) {
    return SafeArea(
      child: Container(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mentionNotifier.isNotEmpty)
                  _buildMentionList(mentionNotifier),
                _buildTextField(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMentionList(List<UserModel> mentionNotifier) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mentionNotifier.length,
        itemBuilder: (context, index) {
          final user = mentionNotifier[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _onMentionTap(user),
              child: Chip(
                avatar: CircleAvatar(
                  backgroundImage: user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(user.avatarUrl!)
                      : const AssetImage('lib/utils/images/default-avatar.jpg'),
                ),
                label: Text(user.username),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: commentController,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        labelText: 'کامنت خود را بنویسید...',
        suffixIcon: IconButton(
          icon: const Icon(Icons.send),
          onPressed: _sendComment,
        ),
      ),
      onChanged: _onTextChanged,
    );
  }

  void _onTextChanged(String text) {
    // بررسی وجود @ در متن
    final atIndex = text.lastIndexOf('@');

    // اگر @ پیدا نشد یا بعد از آن کاراکتری وجود ندارد
    if (atIndex == -1 || atIndex == text.length - 1) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
      return;
    }

    // استخراج بخش مرتبط با منشن
    final mentionPart = text.substring(atIndex + 1);

    // اگر بخش منشن خالی است، لیست را پاک کنید
    if (mentionPart.trim().isEmpty) {
      ref.read(mentionNotifierProvider.notifier).clearMentions();
    } else {
      // جستجوی کاربران قابل منشن
      ref
          .read(mentionNotifierProvider.notifier)
          .searchMentionableUsers(mentionPart);
    }
  }

  void _onMentionTap(UserModel user) {
    final currentText = commentController.text;
    final mentionPart = currentText.split('@').last;
    final newText =
        currentText.replaceFirst('@$mentionPart', '@${user.username} ');

    commentController.text = newText;
    commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: newText.length),
    );

    if (!mentionedUsers.any((u) => u.id == user.id)) {
      mentionedUsers.add(user);
    }

    ref.read(mentionNotifierProvider.notifier).clearMentions();
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref,
    String commentId,
    String postId,
  ) async {
    try {
      await ref
          .read(commentNotifierProvider.notifier)
          .deleteComment(commentId, postId, ref);
      ref.invalidate(commentsProvider(postId));

      if (mounted) {
        UserFriendlyErrorUtils.showSuccessSnackBar(
            context, 'کامنت با موفقیت حذف شد');
      }
    } catch (e) {
      if (mounted) {
        UserFriendlyErrorUtils.showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _showReportDialog(BuildContext context, WidgetRef ref,
      CommentModel comment, String currentUserId) async {
    String selectedReason = '';
    TextEditingController additionalDetailsController = TextEditingController();

    final confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            return AlertDialog(
              title: const Text('گزارش تخلف'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('لطفاً دلیل گزارش را انتخاب کنید:'),
                    ...[
                      'محتوای نامناسب',
                      'هرزنگاری',
                      'توهین آمیز',
                      'اسپم',
                      'محتوای تبلیغاتی',
                      'سایر موارد'
                    ].map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) {
                          setState(() {
                            selectedReason = value!;
                          });
                        },
                      );
                    }),
                    if (selectedReason == 'سایر موارد')
                      TextField(
                        controller: additionalDetailsController,
                        decoration: const InputDecoration(
                          hintText: 'جزئیات بیشتر را وارد کنید',
                        ),
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyLarge?.color,
                  ),
                  child: const Text('لغو'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  child: const Text('گزارش'),
                  onPressed: () {
                    if (selectedReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لطفاً دلیل گزارش را انتخاب کنید'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      try {
        await ref.read(reportCommentServiceProvider).reportComment(
              commentId: comment.id,
              reporterId: currentUserId,
              reason: selectedReason,
              additionalDetails: selectedReason == 'سایر موارد'
                  ? additionalDetailsController.text.trim()
                  : null,
            );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('کامنت با موفقیت گزارش شد.'),
          ),
        );
      } catch (e) {
        logInfo('خطا در گزارش تخلف: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطا در گزارش کامنت.'),
          ),
        );
      }
    }
  }

  Widget _buildImageWithRetry(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      },
      errorWidget: (context, url, error) {
        return GestureDetector(
          onTap: () {
            setState(() {}); // Trigger rebuild to retry loading
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'برای بارگذاری مجدد کلیک کنید',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final postAsyncValue = ref.watch(postProvider(widget.postId));
    final mentionNotifier = ref.watch(mentionNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('جزئیات پست'),
      ),
      resizeToAvoidBottomInset: true,
      body: postAsyncValue.when(
        data: (post) {
          // ✅ بررسی پست حذف شده یا null
          // ignore: unnecessary_null_comparison
          if (post == null) {
            return _buildDeletedPostView(context);
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildPostDetails(context, post),
              ],
            ),
          );
        },
        loading: () => _buildLoadingWidget(),
        error: (error, _) => _buildDeletedPostView(context),
      ),
      bottomNavigationBar: postAsyncValue.when(
        data: (post) {
          // ignore: unnecessary_null_comparison
          return post != null
              ? _buildCommentInputArea(context, mentionNotifier)
              : null;
        },
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }

  /// ✅ ویجت اختصاصی و زیبا برای پست حذف شده
  Widget _buildDeletedPostView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // آیکون
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                size: 64,
                color: isDark ? Colors.white54 : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),

            // متن اصلی
            Text(
              'این پست در دسترس نیست',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // توضیحات فرعی
            Text(
              'ممکن است لینک اشتباه باشد یا توسط نویسنده حذف شده باشد.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // دکمه بازگشت
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('بازگشت'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
