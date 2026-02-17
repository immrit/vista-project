import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../domain/entities/entities.dart';
import '../../core/story_enums.dart';
import '../../../../widgets/verification_badge_icon.dart';

/// هدر استوری
class StoryHeader extends StatelessWidget {
  final StoryUser user;
  final Story story;
  final VoidCallback onClose;
  final VoidCallback onOptions;

  const StoryHeader({
    super.key,
    required this.user,
    required this.story,
    required this.onClose,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // آواتار و نام
          GestureDetector(
            onTap: () => _openProfile(context),
            child: Row(
              children: [
                // آواتار
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: user.avatarUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 24),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.person,
                                  color: Colors.white, size: 24),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 24),
                          ),
                  ),
                ),
                const SizedBox(width: 10),

                // نام و زمان
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (user.isVerified || user.isPremium) ...[
                          const SizedBox(width: 4),
                          VerificationBadgeIcon(
                            isVerified: user.isVerified,
                            verificationType: user.verificationType,
                            role: user.isPremium ? 'premium' : null,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _getTimeAgo(story.createdAt),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        if (story.privacyType ==
                            StoryPrivacyType.closeFriends) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, color: Colors.white, size: 10),
                                SizedBox(width: 2),
                                Text(
                                  'دوستان نزدیک',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // دکمه منو
          IconButton(
            onPressed: onOptions,
            icon: const Icon(Icons.more_vert, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // دکمه بستن
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    // تنظیم زبان فارسی برای timeago
    timeago.setLocaleMessages('fa', timeago.FaMessages());
    return timeago.format(dateTime, locale: 'fa');
  }

  void _openProfile(BuildContext context) {
    Navigator.pushNamed(
      context,
      '/profile',
      arguments: {
        'userId': user.id,
        'username': user.username,
      },
    );
  }
}
