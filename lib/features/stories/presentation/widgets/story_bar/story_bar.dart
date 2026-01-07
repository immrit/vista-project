import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../domain/entities/entities.dart';
import '../../providers/story_providers.dart';
import '../../../../../utils/const.dart';

/// نوار استوری‌ها در بالای صفحه اصلی
class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(activeStoriesProvider);

    return SizedBox(
      height: 110,
      child: storiesAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, _) => _buildErrorState(context, error.toString(), ref),
        data: (users) => _buildStoryList(context, users, ref),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(BuildContext context, String error, WidgetRef ref) {
    // در حالت خطا فقط دکمه اضافه کردن استوری نمایش می‌دهیم
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          AddStoryButton(
            onTap: () => _openStoryCreation(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryList(
      BuildContext context, List<StoryUser> users, WidgetRef ref) {
    // Check upload status
    final uploadState = ref.watch(storyUploadProvider);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: users.length + 1, // +1 for Add Button or Upload status
      itemBuilder: (context, index) {
        if (index == 0) {
          if (uploadState.isUploading) {
            return const _StoryUploadStatusWidget();
          }
          return AddStoryButton(
            onTap: () => _openStoryCreation(context),
          );
        }
        return StoryRing(
          user: users[index - 1],
          allUsers: users,
          onTap: () => _openStoryViewer(context, users, index - 1),
        );
      },
    );
  }

  void _openStoryCreation(BuildContext context) {
    Navigator.pushNamed(context, '/story/create');
  }

  void _openStoryViewer(
      BuildContext context, List<StoryUser> users, int initialIndex) {
    // Smart Navigation: Find first unseen story
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

class _StoryUploadStatusWidget extends StatelessWidget {
  const _StoryUploadStatusWidget();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Spinning gradient ring
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                ),
              ),
              // Avatar placeholder
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey,
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'در حال آپلود...',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// حلقه استوری کاربر
class StoryRing extends StatelessWidget {
  final StoryUser user;
  final List<StoryUser> allUsers;
  final VoidCallback onTap;

  const StoryRing({
    super.key,
    required this.user,
    required this.allUsers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasUnseenStories = user.hasUnseenStories;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: GestureDetector(
        onTap: user.stories.isEmpty ? null : onTap,
        child: Column(
          children: [
            // حلقه استوری
            Container(
              width: 73,
              height: 73,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnseenStories
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF4A90E2),
                          Color(0xFF8E44AD),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasUnseenStories
                    ? null
                    : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: _buildAvatar(),
              ),
            ),
            const SizedBox(height: 4),
            // نام کاربر
            SizedBox(
              width: 70,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      user.username,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasUnseenStories
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: hasUnseenStories
                            ? (isDarkMode ? Colors.white : Colors.black)
                            : (isDarkMode ? Colors.white70 : Colors.black54),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.verified,
                      color: _getVerificationColor(user),
                      size: 12,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getVerificationColor(StoryUser user) {
    switch (user.verificationType) {
      case StoryVerificationType.gold:
        return Colors.amber;
      case StoryVerificationType.blue:
        return Colors.blue;
      case StoryVerificationType.black:
        return Colors.white; // Or Colors.grey[300] for dark theme
      case StoryVerificationType.none:
      default:
        // Fallback to legacy logic
        return user.isPremium ? Colors.amber : Colors.blue;
    }
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      backgroundImage: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
          ? const AssetImage(defaultAvatarUrl) as ImageProvider
          : CachedNetworkImageProvider(user.avatarUrl!),
    );
  }
}

/// دکمه اضافه کردن استوری
class AddStoryButton extends StatelessWidget {
  final VoidCallback onTap;

  const AddStoryButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? Colors.white38 : Colors.grey[300]!,
                  width: 1.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 20,
                      color: isDarkMode ? Colors.black : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 74,
              child: Text(
                'استوری جدید',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
