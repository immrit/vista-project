import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../model/ProfileModel.dart';
import '../../../utils/const.dart';
import '../../../widgets/verification_badge_icon.dart';
import '../../stories/presentation/providers/story_providers.dart';
import '../../stories/domain/entities/entities.dart';

/// ویجت هدر پروفایل - طراحی Instagram/Threads
class ProfileHeaderWidget extends ConsumerWidget {
  final ProfileModel profile;
  final bool isCurrentUser;
  final bool isPrivate;

  const ProfileHeaderWidget({
    super.key,
    required this.profile,
    required this.isCurrentUser,
    this.isPrivate = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar & Stats Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Story Ring
              _ProfileAvatar(
                profile: profile,
                isDark: isDark,
              ),
              const SizedBox(width: 24),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(
                      count: _formatCount(profile.postsCount),
                      label: 'پست',
                      textColor: textColor,
                      subtitleColor: subtitleColor!,
                    ),
                    _StatItem(
                      count: _formatCount(profile.followersCount),
                      label: 'دنبال‌کننده',
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () => _navigateToFollowers(context),
                    ),
                    _StatItem(
                      count: _formatCount(profile.followingCount),
                      label: 'دنبال‌شونده',
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      onTap: () => _navigateToFollowing(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name & Username & Bio
          _ProfileBioSection(
            profile: profile,
            isPrivate: isPrivate,
            textColor: textColor,
            subtitleColor: subtitleColor,
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _navigateToFollowers(BuildContext context) {
    Navigator.pushNamed(context, '/followers', arguments: profile.id);
  }

  void _navigateToFollowing(BuildContext context) {
    Navigator.pushNamed(context, '/following', arguments: profile.id);
  }
}

/// آواتار پروفایل با حلقه استوری
class _ProfileAvatar extends ConsumerWidget {
  final ProfileModel profile;
  final bool isDark;

  const _ProfileAvatar({
    required this.profile,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeStoriesAsync = ref.watch(activeStoriesProvider);

    return activeStoriesAsync.when(
      data: (users) {
        final storyUserIndex = users.indexWhere((u) => u.id == profile.id);
        final hasStories = storyUserIndex != -1;
        final storyUser = hasStories ? users[storyUserIndex] : null;
        final hasUnseenStories = storyUser?.hasUnseenStories ?? false;

        return GestureDetector(
          onTap: hasStories
              ? () => _openStoryViewer(context, users, storyUserIndex)
              : null,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: hasStories
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: hasUnseenStories
                        ? const LinearGradient(
                            colors: [
                              Color(0xFFE040FB),
                              Color(0xFFFF5722),
                              Color(0xFFFFEB3B),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: hasUnseenStories ? null : Colors.grey[400],
                  )
                : null,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.black : Colors.white,
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                backgroundImage: profile.avatarUrl != null
                    ? CachedNetworkImageProvider(profile.avatarUrl!)
                    : const AssetImage(defaultAvatarUrl) as ImageProvider,
              ),
            ),
          ),
        );
      },
      loading: () => _buildSimpleAvatar(),
      error: (_, __) => _buildSimpleAvatar(),
    );
  }

  Widget _buildSimpleAvatar() {
    return CircleAvatar(
      radius: 44,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      backgroundImage: profile.avatarUrl != null
          ? CachedNetworkImageProvider(profile.avatarUrl!)
          : const AssetImage(defaultAvatarUrl) as ImageProvider,
    );
  }

  void _openStoryViewer(
      BuildContext context, List<StoryUser> users, int initialIndex) {
    final selectedUser = users[initialIndex];
    int initialStoryIndex = selectedUser.stories.indexWhere((s) => !s.isViewed);
    if (initialStoryIndex == -1) initialStoryIndex = 0;

    Navigator.pushNamed(
      context,
      '/story/view',
      arguments: {
        'users': users,
        'initialIndex': initialIndex,
        'initialStoryIndex': initialStoryIndex,
      },
    );
  }
}

/// آیتم آمار (پست، دنبال‌کننده، دنبال‌شونده)
class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  final Color textColor;
  final Color subtitleColor;
  final VoidCallback? onTap;

  const _StatItem({
    required this.count,
    required this.label,
    required this.textColor,
    required this.subtitleColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// بخش بیوگرافی پروفایل
class _ProfileBioSection extends StatefulWidget {
  final ProfileModel profile;
  final bool isPrivate;
  final Color textColor;
  final Color subtitleColor;

  const _ProfileBioSection({
    required this.profile,
    required this.isPrivate,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  State<_ProfileBioSection> createState() => _ProfileBioSectionState();
}

class _ProfileBioSectionState extends State<_ProfileBioSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasBio = widget.profile.bio != null && widget.profile.bio!.isNotEmpty;
    final bioText = widget.profile.bio ?? '';
    final isLongBio = bioText.length > 150;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name with verification badge
        Row(
          children: [
            Flexible(
              child: Text(
                widget.profile.fullName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.profile.isVerified) ...[
              const SizedBox(width: 4),
              _buildVerificationBadge(),
            ],
            if (widget.isPrivate) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.lock_outline,
                size: 14,
                color: widget.subtitleColor,
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),

        // Username
        Text(
          '@${widget.profile.username}',
          style: TextStyle(
            fontSize: 14,
            color: widget.subtitleColor,
          ),
        ),

        // Bio
        if (hasBio) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: isLongBio
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            child: Text(
              _isExpanded || !isLongBio
                  ? bioText
                  : '${bioText.substring(0, 150)}...',
              style: TextStyle(
                fontSize: 14,
                color: widget.textColor,
                height: 1.4,
              ),
            ),
          ),
          if (isLongBio)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? 'کمتر' : 'بیشتر',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildVerificationBadge() {
    return VerificationBadgeIcon(
      isVerified: widget.profile.isVerified,
      verificationType: widget.profile.verificationType,
      role: widget.profile.role,
      size: 16,
    );
  }
}
