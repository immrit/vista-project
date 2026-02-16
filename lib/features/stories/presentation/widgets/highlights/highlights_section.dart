import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../domain/entities/entities.dart';
import '../../../domain/repositories/i_story_repository.dart';
import '../../providers/story_providers.dart';
import '../../../core/story_enums.dart';
import '../../../../../utils/premium_features_helper.dart';
import '../../../../../utils/user_friendly_error_utils.dart';
import '../../../../../provider/provider.dart';

/// نمایش Highlights در پروفایل
class HighlightsSection extends ConsumerWidget {
  final String userId;
  final bool isOwnProfile;

  const HighlightsSection({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlightsAsync = ref.watch(userHighlightsProvider(userId));

    return highlightsAsync.when(
      loading: () => _buildLoadingState(),
      error: (error, _) => const SizedBox.shrink(),
      data: (highlights) => _buildHighlightsList(context, ref, highlights),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 50,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsList(
    BuildContext context,
    WidgetRef ref,
    List<StoryHighlight> highlights,
  ) {
    if (highlights.isEmpty && !isOwnProfile) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: highlights.length + (isOwnProfile ? 1 : 0),
        itemBuilder: (context, index) {
          if (isOwnProfile && index == 0) {
            return _buildAddHighlightButton(context, ref, highlights.length);
          }

          final highlightIndex = isOwnProfile ? index - 1 : index;
          return _buildHighlightItem(context, highlights[highlightIndex]);
        },
      ),
    );
  }

  Widget _buildAddHighlightButton(
      BuildContext context, WidgetRef ref, int currentCount) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => _onAddHighlight(context, ref, currentCount),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode ? Colors.white38 : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.add,
                  size: 28,
                  color: isDarkMode ? Colors.white70 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'جدید',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onAddHighlight(
      BuildContext context, WidgetRef ref, int currentCount) async {
    // بررسی محدودیت
    if (currentCount >= StoryConstants.freeHighlightsLimit) {
      // بررسی پریمیوم بودن
      dynamic currentProfile;
      try {
        currentProfile = await ref.read(currentUserProfileProvider.future);
      } catch (_) {
        currentProfile = ref.read(currentUserProfileProvider).valueOrNull;
      }
      if (!context.mounted) return;
      final isPremium = (currentProfile?.hasGoldBadge ?? false) ||
          (currentProfile?.hasBlueBadge ?? false);

      if (!isPremium) {
        PremiumFeaturesHelper.showPremiumPromptDialog(
          context,
          feature: 'هایلایت‌های نامحدود',
        );
        return;
      }
    }

    if (!context.mounted) return;
    _showCreateHighlightDialog(context);
  }

  void _showCreateHighlightDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateHighlightSheet(userId: userId),
    );
  }

  Widget _buildHighlightItem(BuildContext context, StoryHighlight highlight) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () => _openHighlight(context, highlight),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: highlight.defaultCover != null
                    ? CachedNetworkImage(
                        imageUrl: highlight.defaultCover!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        ),
                        errorWidget: (context, url, error) =>
                            _buildDefaultIcon(isDarkMode),
                      )
                    : _buildDefaultIcon(isDarkMode),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                highlight.title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultIcon(bool isDarkMode) {
    return Container(
      color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image,
          color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
    );
  }

  void _openHighlight(BuildContext context, StoryHighlight highlight) {
    if (highlight.stories.isEmpty) return;

    Navigator.pushNamed(
      context,
      '/story/view',
      arguments: {
        'users': [
          StoryUser(
            id: userId,
            username: '',
            stories: highlight.stories,
          ),
        ],
        'initialIndex': 0,
      },
    );
  }
}

/// دیالوگ ایجاد هایلایت
class _CreateHighlightSheet extends ConsumerStatefulWidget {
  final String userId;

  const _CreateHighlightSheet({required this.userId});

  @override
  ConsumerState<_CreateHighlightSheet> createState() =>
      _CreateHighlightSheetState();
}

class _CreateHighlightSheetState extends ConsumerState<_CreateHighlightSheet> {
  final TextEditingController _titleController = TextEditingController();
  final Set<String> _selectedStoryIds = {};
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // هندل
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // هدر
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textColor),
                ),
                const Spacer(),
                Text(
                  'هایلایت جدید',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed:
                      _selectedStoryIds.isEmpty ? null : _createHighlight,
                  child: Text(
                    'ایجاد',
                    style: TextStyle(
                      color: _selectedStoryIds.isEmpty
                          ? Colors.grey
                          : Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // نام هایلایت
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'نام هایلایت',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // لیست استوری‌ها
          Expanded(
            child: _buildStoriesList(),
          ),

          // لودینگ
          if (_isLoading) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildStoriesList() {
    final storiesAsync = ref.watch(userStoriesProvider(widget.userId));

    return storiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          UserFriendlyErrorUtils.getUserFriendlyMessage(error),
          textDirection: TextDirection.rtl,
        ),
      ),
      data: (stories) {
        if (stories.isEmpty) {
          return const Center(
            child: Text('استوری‌ای برای انتخاب وجود ندارد'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: stories.length,
          itemBuilder: (context, index) {
            final story = stories[index];
            final isSelected = _selectedStoryIds.contains(story.id);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedStoryIds.remove(story.id);
                  } else {
                    _selectedStoryIds.add(story.id);
                  }
                });
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: story.media.thumbnailUrl ?? story.media.url,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 3),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_circle,
                            color: Colors.white, size: 32),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createHighlight() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً نام هایلایت را وارد کنید')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(storyRepositoryProvider);
      final result = await repository.createHighlight(
        HighlightCreateParams(
          title: _titleController.text,
          storyIds: _selectedStoryIds.toList(),
        ),
      );

      result.fold(
        (error) {
          UserFriendlyErrorUtils.showErrorSnackBar(context, error);
        },
        (highlight) {
          ref.invalidate(userHighlightsProvider(widget.userId));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هایلایت ایجاد شد')),
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
