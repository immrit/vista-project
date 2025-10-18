import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/provider.dart';
import '../../model/ProfileModel.dart';
import '../../view/util/const.dart';

/// ویجت بهینه شده برای نمایش آواتار و اطلاعات پروفایل با کشینگ
class ProfileAvatar extends ConsumerWidget {
  final String userId;
  final double? size;
  final bool showOnlineStatus;
  final bool showDisplayName;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    required this.userId,
    this.size = 40,
    this.showOnlineStatus = false,
    this.showDisplayName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));

    if (profile == null) {
      return _buildLoadingAvatar(context);
    }

    return _buildProfileAvatar(context, profile);
  }

  Widget _buildLoadingAvatar(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).disabledColor.withOpacity(0.1),
      ),
      child: Icon(
        Icons.person_rounded,
        size: size! * 0.5,
        color: Theme.of(context).disabledColor,
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context, ProfileModel? profile) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size! / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: profile?.avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profile!.avatarUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              _buildDefaultAvatar(context),
                          errorWidget: (context, url, error) =>
                              _buildDefaultAvatar(context),
                        )
                      : _buildDefaultAvatar(context),
                ),
              ),
              // Online status not available in ProfileModel
              // if (showOnlineStatus && profile?.isOnline == true)
              //   Positioned(
              //     right: 2,
              //     bottom: 2,
              //     child: Container(
              //       width: size! * 0.3,
              //       height: size! * 0.3,
              //       decoration: BoxDecoration(
              //         color: Colors.green,
              //         shape: BoxShape.circle,
              //         border: Border.all(
              //           color: theme.scaffoldBackgroundColor,
              //           width: 2,
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),
          if (showDisplayName && profile != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.username.trim().isNotEmpty
                  ? profile.username
                  : profile.fullName.trim().isNotEmpty
                      ? profile.fullName
                      : 'کاربر ناشناس',
              style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildDefaultAvatar(BuildContext context) {
    return Image.asset(
      defaultAvatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            Icons.person_rounded,
            color: Theme.of(context).primaryColor,
            size: size! * 0.5,
          ),
        );
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
                color: theme.disabledColor.withOpacity(0.1),
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
                      color: theme.disabledColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 12,
                    decoration: BoxDecoration(
                      color: theme.disabledColor.withOpacity(0.05),
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
                  // Online status not available in ProfileModel
                  // if (showOnlineStatus && profile?.isOnline == true)
                  //   Row(
                  //     children: [
                  //       Container(
                  //         width: 8,
                  //         height: 8,
                  //         decoration: BoxDecoration(
                  //           color: Colors.green,
                  //           shape: BoxShape.circle,
                  //         ),
                  //       ),
                  //       const SizedBox(width: 6),
                  //       Text(
                  //         'آنلاین',
                  //         style: theme.textTheme.bodySmall?.copyWith(
                  //           color: Colors.green,
                  //           fontWeight: FontWeight.w500,
                  //         ),
                  //       ),
                  //     ],
                  //   )
                  // else if (showLastOnline && profile?.lastOnline != null)
                  //   Text(
                  //     'آخرین فعالیت: ${_formatLastOnline(profile!.lastOnline!)}',
                  //     style: theme.textTheme.bodySmall?.copyWith(
                  //       color: theme.hintColor,
                  //     ),
                  //   )
                  // else
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
