import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/provider.dart';
import '../../model/ProfileModel.dart';
import 'package:Vista/utils/const.dart';
import 'package:Vista/features/stories/presentation/providers/story_providers.dart';
import 'package:Vista/features/stories/domain/entities/story_user.dart';

/// ویجت بهینه شده برای نمایش آواتار و اطلاعات پروفایل با کشینگ
/// ✅ قابلیت نمایش حلقه استوری به صورت خودکار
class ProfileAvatar extends ConsumerWidget {
  final String userId;
  final double? size;
  final bool showOnlineStatus;
  final bool showDisplayName;
  final VoidCallback? onTap;
  final String? imageUrl; // اضافه شده برای استفاده در فید وقتی عکس رو داریم

  const ProfileAvatar({
    super.key,
    required this.userId,
    this.size = 40,
    this.showOnlineStatus = false,
    this.showDisplayName = false,
    this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. دریافت وضعیت استوری کاربر
    final storiesAsync = ref.watch(activeStoriesProvider);
    final storyUser = storiesAsync.valueOrNull?.firstWhere(
        (u) => u.id == userId,
        orElse: () => StoryUser(
            id: userId,
            username: 'unknown',
            stories: [])); // اگر پیدا نشد، یک ابجکت خالی

    final hasStories = storyUser != null && storyUser.stories.isNotEmpty;
    final hasUnseenStories = storyUser?.hasUnseenStories ?? false;

    // 2. دریافت اطلاعات پروفایل (اگر imageUrl پاس داده نشده باشد)
    final profile =
        imageUrl != null ? null : ref.watch(userProfileProvider(userId));

    if (imageUrl == null && profile == null) {
      return _buildLoadingAvatar(context, size!);
    }

    final avatarUrl = imageUrl ?? profile?.avatarUrl;
    final displayName = profile != null
        ? (profile.username.isNotEmpty ? profile.username : profile.fullName)
        : '';

    return GestureDetector(
      onTap: () {
        if (hasStories) {
          _openStoryViewer(context, storiesAsync.value!, storyUser);
        } else {
          onTap?.call();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAvatarWithRing(
              context, avatarUrl, hasStories, hasUnseenStories),
          if (showDisplayName && displayName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarWithRing(BuildContext context, String? avatarUrl,
      bool hasStories, bool hasUnseenStories) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // اگر استوری ندارد، نمایش ساده
    if (!hasStories) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: ClipOval(
          child: _buildImage(context, avatarUrl),
        ),
      );
    }

    // تنظیمات حلقه استوری مشابه _AnimatedStoryRing
    final gradientColors = hasUnseenStories
        ? const [
            Color(0xFF962FBF), // Purple
            Color(0xFFD62976), // Pink
            Color(0xFFFA7E1E), // Orange
            Color(0xFFFEDA75), // Yellow
          ]
        : [
            isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
            isDarkMode ? const Color(0xFF303030) : const Color(0xFFBDBDBD),
          ];

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size! * 0.08), // فاصله حلقه تا عکس
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: hasUnseenStories
            ? [
                BoxShadow(
                  color: const Color(0xFFD62976)
                      .withValues(alpha: 0.2), // Colored shadow
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Container(
        padding: EdgeInsets.all(size! * 0.05), // بوردر سفید/مشکی داخلی
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: _buildImage(context, avatarUrl),
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, String? url) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(context, size!),
        errorWidget: (context, url, error) =>
            _buildDefaultAvatar(context, size!),
      );
    }
    return _buildDefaultAvatar(context, size!);
  }

  Widget _buildLoadingAvatar(BuildContext context, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).disabledColor.withValues(alpha: 0.1),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.5,
        color: Theme.of(context).disabledColor,
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context, double size) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: Icon(
            Icons.person_rounded,
            color: Theme.of(context).primaryColor,
            size: size * 0.5,
          ),
        );
      },
    );
  }

  void _openStoryViewer(
      BuildContext context, List<StoryUser> allUsers, StoryUser currentUser) {
    // پیدا کردن ایندکس کاربر در لیست کل استوری‌ها
    final userIndex = allUsers.indexWhere((u) => u.id == currentUser.id);
    if (userIndex == -1) return;

    // پیدا کردن اولین استوری دیده نشده
    int initialStoryIndex = currentUser.stories.indexWhere((s) => !s.isViewed);
    if (initialStoryIndex == -1) initialStoryIndex = 0;

    Navigator.pushNamed(
      context,
      '/story/view',
      arguments: {
        'users': allUsers,
        'initialIndex': userIndex,
        'initialStoryIndex': initialStoryIndex,
      },
    );
  }
}

/// ویجت برای نمایش اطلاعات پروفایل کامل
class ProfileInfoCard extends ConsumerWidget {
  final String userId;
  final bool showAvatar;
  final bool showOnlineStatus;
  final bool showLastOnline;
  final double avatarSize;

  const ProfileInfoCard({
    super.key,
    required this.userId,
    this.showAvatar = true,
    this.showOnlineStatus = true,
    this.showLastOnline = true,
    this.avatarSize = 60,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));

    if (profile == null) {
      return _buildLoadingCard(context);
    }

    return _buildProfileCard(context, profile);
  }

  Widget _buildLoadingCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.disabledColor.withValues(alpha: 0.1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, ProfileModel? profile) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (showAvatar) ...[
              ProfileAvatar(
                userId: userId,
                size: avatarSize,
                showOnlineStatus: showOnlineStatus,
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (profile?.username ?? '').trim().isNotEmpty
                        ? profile!.username
                        : (profile?.fullName ?? '').trim().isNotEmpty
                            ? profile!.fullName
                            : 'کاربر ناشناس',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'اطلاعات آنلاین در دسترس نیست',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
