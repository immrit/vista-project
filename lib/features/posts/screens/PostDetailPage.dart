import '../../../security/logging_utility.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../../services/smart_share_service.dart';
import '../../../model/publicPostModel.dart';
import 'package:Vista/utils/widgets.dart';
import 'package:Vista/features/search/screens/searchPage.dart';
import '../../../utils/const.dart';
import 'profileScreen.dart';
import 'publicPosts.dart' as public_posts;
import '../../../model/CommentModel.dart';
import '../../../model/UserModel.dart';
import '../../../provider/provider.dart';
import '../../../model/MusicModel.dart';
import '../../../provider/MusicProvider.dart';
import 'MusicWaveform.dart';
import '../../../utils/premium_features_helper.dart';

// Provider برای مدیریت پست جزئیات
final postDetailProvider =
    FutureProvider.family<PublicPostModel?, String>((ref, postId) async {
  try {
    final response = await supabase.from('posts').select('''
          *,
          profiles!posts_user_id_fkey (
            id,
            username,
            full_name,
            avatar_url,
            is_verified,
            verification_type
          ),
          likes!posts_likes_post_id_fkey (user_id),
          comments!posts_comments_post_id_fkey (id)
        ''').eq('id', postId).maybeSingle();

    if (response == null) {
      return null; // پست یافت نشد
    }

    // محاسبه مقادیر مشتق‌شده برای مدل پست
    final profile = response['profiles'] as Map<String, dynamic>? ?? {};
    final likes = response['likes'] as List<dynamic>? ?? [];
    final likeCount = likes.length;
    final isLiked =
        likes.any((like) => like['user_id'] == supabase.auth.currentUser?.id);
    final comments = response['comments'] as List<dynamic>? ?? [];
    final commentCount = comments.length;

    return PublicPostModel.fromMap({
      ...response,
      'like_count': likeCount,
      'is_liked': isLiked,
      'comment_count': commentCount,
      'username': profile['username'] ?? profile['full_name'] ?? 'Unknown',
      'avatar_url': profile['avatar_url'] ?? '',
      'is_verified': profile['is_verified'] ?? false,
      'verification_type': profile['verification_type'],
    });
  } catch (e) {
    logInfo('Error fetching post: $e');
    throw Exception('خطا در بارگذاری پست: $e');
  }
});

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
  final bool _isRetrying = false;

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

  // سیستم اشتراک‌گذاری هوشمند
  void _sharePost(PublicPostModel post) {
    // استفاده از قابلیت جدید اشتراک‌گذاری تصویری
    SmartShareService().showShareOptions(post, context);
  }

  // مدیریت خطا و retry
  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری پست',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isRetrying ? null : onRetry,
            icon: _isRetrying
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isRetrying ? 'در حال تلاش...' : 'تلاش مجدد'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
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
    // فرض کنید از Supabase برای جلب userId استفاده می‌کنید
    final response = await supabase
        .from('profiles')
        .select('id')
        .eq('username', username)
        .single();

    if (response['id'] != null) {
      return response['id'];
    } else {
      return null; // اگر کاربر یافت نشد
    }
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

          double screenWidth = MediaQuery.of(context).size.width - 20;
          double imageRatio = snapshot.data!.width / snapshot.data!.height;
          double displayHeight = screenWidth / imageRatio;

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWithRetry(post.imageUrl!),
            ),
          );
        },
      ),
    );
  }

  void _showZoomableImage(BuildContext context, String imageUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black.withOpacity(0.9),
          child: Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                alignment: Alignment.center,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.error_outline,
                          size: 50,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 10,
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // اضافه کردن دکمه دانلود
              // Positioned(
              //   top: MediaQuery.of(context).padding.top + 10,
              //   left: 10,
              //   child: IconButton(
              //     icon: const Icon(
              //       Icons.download,
              //       color: Colors.white,
              //       size: 30,
              //     ),
              //     onPressed: () {
              //       // اینجا کد دانلود عکس را اضافه کنید
              //       ScaffoldMessenger.of(context).showSnackBar(
              //         const SnackBar(
              //           content: Text('دانلود تصویر شروع شد'),
              //           duration: Duration(seconds: 2),
              //         ),
              //       );
              //     },
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Size> _getImageDimensions(String imageUrl) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.network(imageUrl);

    image.image.resolve(const ImageConfiguration()).addListener(
          ImageStreamListener(
            (ImageInfo info, bool _) {
              completer.complete(Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              ));
            },
            onError: (dynamic exception, StackTrace? stackTrace) {
              completer.completeError(exception);
            },
          ),
        );

    return completer.future;
  }

  Widget _buildSingleImage(String imageUrl) {
    return GestureDetector(
      onTap: () => _showImageDialog(context, imageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWithRetry(imageUrl),
      ),
    );
  }

  Widget _buildMultipleImages(List<String> images) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, index) {
        return Container(
          width: 200,
          margin: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => _showImageDialog(context, images[index]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildImageWithRetry(images[index]),
            ),
          ),
        );
      },
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Stack(
            children: [
              InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostDetails(BuildContext context, dynamic post) {
    final jalaliDate = Jalali.fromDateTime(post.createdAt.toLocal());
    final formattedDate =
        '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPostCard(post, formattedDate),
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

  Widget _buildPostCard(dynamic post, String formattedDate) {
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
                    .map(
                      (tag) => GestureDetector(
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
                    .toList(),
              ),
            ],
            _buildPostImages(post),
            const SizedBox(height: 10),
            _buildLikeRow(post),
            if (post.musicUrl != null && post.musicUrl!.isNotEmpty)
              Consumer(
                builder: (context, ref, child) {
                  final isPlaying = ref.watch(isPlayingProvider);
                  final currentlyPlaying =
                      ref.watch(currentlyPlayingProvider).value;
                  final isThisPlaying =
                      currentlyPlaying?.musicUrl == post.musicUrl;
                  final position = ref.watch(musicPositionProvider);
                  final duration = ref.watch(musicDurationProvider);

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 16.0),
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
                          ref
                              .read(musicPlayerProvider.notifier)
                              .togglePlayPause();
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
                          ref
                              .read(musicPlayerProvider.notifier)
                              .playMusic(music);
                        }
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(dynamic post) {
    return Row(
      children: [
        CircleAvatar(
          backgroundImage: post.avatarUrl.isEmpty
              ? const AssetImage('lib/view/util/images/default-avatar.jpg')
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

  Widget _buildPostActionsMenu(dynamic post) {
    return Consumer(
      builder: (context, ref, child) {
        final profileAsync = ref.watch(profileProvider);
        final currentUserId = supabase.auth.currentUser?.id;
        final isCurrentUserPost = post.userId == currentUserId;

        return profileAsync.when(
          data: (profile) {
            // استفاده از Helper برای بررسی دسترسی
            final currentUserProfile = ref.read(currentUserProfileProvider);
            final canEditPost = currentUserProfile.value != null &&
                PremiumFeaturesHelper.canEditPost(currentUserProfile.value!) &&
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
                              .read(supabaseServiceProvider)
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
                      // Use the same edit dialog from publicPosts.dart
                      public_posts.showEditPostDialog(context, ref, post);
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
        child: const Icon(Icons.verified, color: Colors.black, size: 16),
      );
    } else {
      return const SizedBox.shrink(); // در صورت نداشتن تیک، چیزی نمایش نمی‌دهیم
    }
  }

  String _formatDate(DateTime date) {
    final jalaliDate = Jalali.fromDateTime(date.toLocal());
    return '${jalaliDate.year}/${jalaliDate.month}/${jalaliDate.day}';
  }

  Widget _buildLikeRow(dynamic post) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        IconButton(
          icon: Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            color: post.isLiked ? Colors.red : null,
          ),
          onPressed: () async {
            setState(() {
              post.isLiked = !post.isLiked;
              post.likeCount += post.isLiked ? 1 : -1;
            });
            await ref.read(supabaseServiceProvider).toggleLike(
                  postId: post.id,
                  ownerId: post.userId,
                  ref: ref,
                );
          },
        ),
        Text('${post.likeCount}'),
        const SizedBox(width: 16),
        // دکمه کامنت با آیکون سفارشی
        GestureDetector(
          onTap: () {
            // اضافه کردن منطق نمایش کامنت‌ها
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Image.asset(
              'lib/view/util/images/component/comment.png',
              width: 20,
              height: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
        ),
        Text('${post.commentCount ?? 0}'),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final commentsAsyncValue = ref.watch(commentsProvider(widget.postId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              'نظرات:',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: Colors.grey, height: 1, endIndent: 75, indent: 25),
        const SizedBox(height: 10),
        commentsAsyncValue.when(
          data: (comments) => comments.isEmpty
              ? const Center(child: Text('هنوز کامنتی وجود ندارد'))
              : _buildCommentTree(comments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('خطا در بارگذاری کامنت‌ها: $error')),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هدر کامنت
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: comment.avatarUrl.isEmpty
                      ? const AssetImage(
                          'lib/view/util/images/default-avatar.jpg')
                      : CachedNetworkImageProvider(comment.avatarUrl)
                          as ImageProvider,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            comment.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 5),
                          if (comment.isVerified)
                            _buildVerificationBadgeComment(comment),
                        ],
                      ),
                      Text(
                        _formatDate(comment.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // آیکون‌های اکشن
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  itemBuilder: (context) => [
                    if (comment.userId != supabase.auth.currentUser?.id)
                      PopupMenuItem(
                        value: 'report',
                        child: const Row(
                          children: [
                            Icon(Icons.flag, color: Colors.orange),
                            SizedBox(width: 8),
                            Text(
                              'گزارش',
                            ),
                          ],
                        ),
                        onTap: () {
                          _showReportDialog(context, ref, comment,
                              supabase.auth.currentUser!.id);
                          Navigator.of(context).pop();
                        },
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: const Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف'),
                        ],
                      ),
                      onTap: () {
                        _deleteComment(context, ref, comment.id, widget.postId);
                        // Navigator.of(context).pop();
                      },
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'reply') {
                      setState(() {
                        replyToCommentId = comment.id;
                      });
                    }
                  },
                ),
              ],
            ),

            // متن کامنت
            const SizedBox(height: 10),
            Directionality(
              textDirection: getDirectionality(comment.content),
              child: RichText(
                text: TextSpan(
                  children: _buildCommentTextSpans(
                      comment, theme.brightness == Brightness.dark),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            // گزینه ریپلای
            TextButton(
              onPressed: () {
                setState(() {
                  replyToCommentId = comment.id;
                  commentController.text = '@${comment.username} ';
                  commentController.selection = TextSelection.fromPosition(
                    TextPosition(offset: commentController.text.length),
                  );
                });
              },
              child: const Text('پاسخ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationBadgeComment(CommentModel profile) {
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
        child: const Icon(Icons.verified, color: Colors.black, size: 16),
      );
    } else {
      return const SizedBox.shrink(); // در صورت نداشتن تیک، چیزی نمایش نمی‌دهیم
    }
  }

  void _sendComment() async {
    final content = commentController.text.trim();
    final mentionedUserIds = mentionedUsers.map((user) => user.id).toList();

    if (content.isNotEmpty) {
      try {
        await ref.read(commentNotifierProvider.notifier).addComment(
            postId: widget.postId,
            content: content,
            postOwnerId: supabase.auth.currentUser!.id,
            mentionedUserIds: mentionedUserIds,
            parentCommentId: replyToCommentId,
            ref: ref);
        commentController.clear();
        replyToCommentId = null;
        mentionedUsers.clear();
        ref.invalidate(commentsProvider(widget.postId));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ارسال کامنت: $e')),
        );
      }
    }
  }

  Widget _buildCommentInputArea(
      BuildContext context, List<UserModel> mentionNotifier) {
    return Container(
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
                  backgroundImage:
                      user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(user.avatarUrl!)
                          : const AssetImage(
                              'lib/view/util/images/default-avatar.jpg'),
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
          .deleteComment(commentId, ref);
      ref.invalidate(commentsProvider(postId));

      // به دلیل زمان‌بری احتمالی async، از `mounted` برای چک وضعیت ویجت استفاده کنید
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('کامنت با موفقیت حذف شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در حذف کامنت: $e')),
        );
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

  List<TextSpan> _buildCommentTextSpans(CommentModel comment, bool isDarkMode) {
    final List<TextSpan> spans = [];
    final mentionRegex = RegExp(r'@(\w+)');

    final matches = mentionRegex.allMatches(comment.content);
    int lastIndex = 0;

    for (final match in matches) {
      // متن قبل از منشن
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: comment.content.substring(lastIndex, match.start),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        );
      }

      // استایل منشن
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(
            color: Colors.blue.shade400,
            fontWeight: FontWeight.bold,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final username = match.group(1); // استخراج نام کاربری
              if (username != null) {
                // دریافت userId از پایگاه داده یا API بر اساس username
                final userId = await getUserIdByUsername(username);
                if (userId != null) {
                  // ناوبری به پروفایل کاربر
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(
                        username: username,
                        userId: userId,
                      ),
                    ),
                  );
                }
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    // متن باقی مانده
    if (lastIndex < comment.content.length) {
      spans.add(
        TextSpan(
          text: comment.content.substring(lastIndex),
          style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87, fontSize: 15),
        ),
      );
    }

    return spans;
  }

  Widget _buildImageWithRetry(String imageUrl) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
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
