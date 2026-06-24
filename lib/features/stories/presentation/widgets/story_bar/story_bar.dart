import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../domain/entities/entities.dart';
import '../../../utils/story_preloader.dart';
import '../../providers/story_providers.dart';
import '../../../../../widgets/verification_badge_icon.dart';

const String _defaultAvatarAsset = 'lib/utils/images/default-avatar.jpg';

/// نوار استوری‌ها با مرتب‌سازی هوشمند
/// - استوری‌های دیده‌نشده اول
/// - استوری‌های دیده‌شده آخر
/// - حلقه گرادیانت برای دیده‌نشده، خاکستری برای دیده‌شده
class StoryBar extends ConsumerStatefulWidget {
  const StoryBar({super.key});

  @override
  ConsumerState<StoryBar> createState() => _StoryBarState();
}

class _StoryBarState extends ConsumerState<StoryBar>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh stories and seen state from server when app comes to foreground
      ref.invalidate(activeStoriesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storiesAsync = ref.watch(activeStoriesProvider);

    return SizedBox(
      height: 115,
      child: storiesAsync.when(
        loading: () => _buildLoadingState(),
        error: (error, _) => _buildErrorState(context, error.toString(), ref),
        data: (users) => _buildStoryList(context, _sortStories(users), ref),
      ),
    );
  }

  /// ✅ مرتب‌سازی هوشمند استوری‌ها
  /// 1. فیلتر استوری‌های منقضی (>24 ساعت)
  /// 2. کاربران با استوری دیده‌نشده اول
  /// 3. کاربران با همه استوری دیده‌شده آخر
  List<StoryUser> _sortStories(List<StoryUser> users) {
    final now = DateTime.now();

    // فیلتر و مرتب‌سازی
    final List<StoryUser> processedUsers = users
        .map((user) {
          // فیلتر استوری‌های منقضی
          final validStories = user.stories.where((story) {
            return story.expiresAt.isAfter(now);
          }).toList();

          return user.copyWith(stories: validStories);
        })
        .where((user) => user.stories.isNotEmpty) // حذف کاربران بدون استوری
        .toList();

    // مرتب‌سازی: دیده‌نشده اول، دیده‌شده آخر
    processedUsers.sort((a, b) {
      final aHasUnseen = a.hasUnseenStories;
      final bHasUnseen = b.hasUnseenStories;

      if (aHasUnseen && !bHasUnseen) return -1;
      if (!aHasUnseen && bHasUnseen) return 1;

      // اگر هر دو یکسان بودند، بر اساس آخرین استوری مرتب کن
      final aLastStory =
          a.stories.isNotEmpty ? a.stories.last.createdAt : DateTime(0);
      final bLastStory =
          b.stories.isNotEmpty ? b.stories.last.createdAt : DateTime(0);
      return bLastStory.compareTo(aLastStory); // جدیدتر اول
    });

    return processedUsers;
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
                  color: Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
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
    final uploadState = ref.watch(storyUploadProvider);

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: users.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          if (uploadState.isUploading) {
            return const _StoryUploadStatusWidget();
          }
          return AddStoryButton(
            onTap: () => _openStoryCreation(context),
          );
        }
        return _AnimatedStoryRing(
          key: ValueKey(users[index - 1].id),
          user: users[index - 1],
          allUsers: users,
          onTap: () => _openStoryViewer(context, users, index - 1, ref: ref),
        );
      },
    );
  }

  void _openStoryCreation(BuildContext context) {
    Navigator.pushNamed(context, '/story/create');
  }

  void _openStoryViewer(
      BuildContext context, List<StoryUser> users, int initialIndex,
      {WidgetRef? ref}) {
    final selectedUser = users[initialIndex];
    // Find first unseen story, accounting for session-seen state.
    final sessionSeen = ref?.read(sessionSeenStoriesProvider) ?? const {};
    int initialStoryIndex = selectedUser.stories.indexWhere(
      (s) => !s.isViewed && !sessionSeen.contains(s.id),
    );
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

/// ✅ حلقه استوری با انیمیشن تغییر رنگ + آپدیت آنی پس از مشاهده
class _AnimatedStoryRing extends ConsumerStatefulWidget {
  final StoryUser user;
  final List<StoryUser> allUsers;
  final VoidCallback onTap;

  const _AnimatedStoryRing({
    super.key,
    required this.user,
    required this.allUsers,
    required this.onTap,
  });

  @override
  ConsumerState<_AnimatedStoryRing> createState() => _AnimatedStoryRingState();
}

class _AnimatedStoryRingState extends ConsumerState<_AnimatedStoryRing>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late AnimationController _spinController;
  late Animation<double> _colorAnimation;
  bool _wasUnseen = true;
  bool _isLoadingStory = false;

  @override
  void initState() {
    super.initState();
    _wasUnseen = widget.user.hasUnseenStories;
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _spinController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _colorAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleTap() async {
    if (_isLoadingStory) return;

    setState(() {
      _isLoadingStory = true;
      _spinController.repeat();
    });

    try {
      final sessionSeen = ref.read(sessionSeenStoriesProvider);
      int initialStoryIndex = widget.user.stories.indexWhere(
        (s) => !s.isViewed && !sessionSeen.contains(s.id),
      );
      if (initialStoryIndex == -1) initialStoryIndex = 0;

      final firstStory = widget.user.stories[initialStoryIndex];
      await StoryPreloader.preloadStory(context, firstStory);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingStory = false;
          _spinController.stop();
        });
        widget.onTap();
      }
    }
  }

  @override
  void didUpdateWidget(_AnimatedStoryRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    // انیمیشن تغییر از unseen به seen
    if (_wasUnseen && !widget.user.hasUnseenStories) {
      _animController.forward();
      _wasUnseen = false;
    } else if (!_wasUnseen && widget.user.hasUnseenStories) {
      _animController.reverse();
      _wasUnseen = true;
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the session-seen set for optimistic ring updates after viewing.
    final sessionSeen = ref.watch(sessionSeenStoriesProvider);
    final effectiveUser = widget.user.copyWith(
      stories: widget.user.stories.map((s) {
        if (!s.isViewed && sessionSeen.contains(s.id)) {
          return s.copyWith(isViewed: true);
        }
        return s;
      }).toList(),
    );

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasUnseenStories = effectiveUser.hasUnseenStories;

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: GestureDetector(
            onTap: effectiveUser.stories.isEmpty ? null : _handleTap,
            child: Column(
              children: [
                _buildAnimatedRing(isDarkMode, hasUnseenStories),
                const SizedBox(height: 4),
                _buildUsername(isDarkMode, hasUnseenStories),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedRing(bool isDarkMode, bool hasUnseenStories) {
    // ✅ گرادیانت برای دیده‌نشده (رنگ‌های جذاب)، خاکستری برای دیده‌شده
    final gradientColors = hasUnseenStories
        ? const [
            Color(0xFF6366F1), // Indigo (برند Vista)
            Color(0xFF8B5CF6), // Violet
            Color(0xFFEC4899), // Pink
          ]
        : [
            isDarkMode ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
            isDarkMode ? const Color(0xFF303030) : const Color(0xFFBDBDBD),
          ];

    if (_isLoadingStory) {
      return SizedBox(
        width: 74,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 74,
              height: 74,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  hasUnseenStories ? const Color(0xFF6366F1) : (isDarkMode ? Colors.white54 : Colors.black54),
                ),
                strokeWidth: 2.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black : Colors.white,
                shape: BoxShape.circle,
              ),
              child: _buildAvatar(),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 74,
      height: 74, // Slightly larger to accommodate thinner ring visual
      padding: const EdgeInsets.all(2.0), // Thinner ring
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: hasUnseenStories
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6)
                      .withValues(alpha: 0.3), // Vista violet shadow
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.white,
          shape: BoxShape.circle,
        ),
        child: _buildAvatar(),
      ),
    );
  }

  Widget _buildUsername(bool isDarkMode, bool hasUnseenStories) {
    return SizedBox(
      width: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.user.username,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    hasUnseenStories ? FontWeight.bold : FontWeight.normal,
                color: hasUnseenStories
                    ? (isDarkMode ? Colors.white : Colors.black)
                    : (isDarkMode ? Colors.white60 : Colors.black45),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.user.isVerified || widget.user.isPremium) ...[
            const SizedBox(width: 2),
            VerificationBadgeIcon(
              isVerified: widget.user.isVerified,
              verificationType: widget.user.verificationType,
              role: widget.user.isPremium ? 'premium' : null,
              size: 12,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return CircleAvatar(
      backgroundImage:
          (widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty)
              ? const AssetImage(_defaultAvatarAsset) as ImageProvider
              : CachedNetworkImageProvider(widget.user.avatarUrl!),
    );
  }
}

/// وضعیت آپلود استوری
class _StoryUploadStatusWidget extends StatelessWidget {
  const _StoryUploadStatusWidget();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // حلقه در حال چرخش
              SizedBox(
                width: 74,
                height: 74,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              // آواتار
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                ),
                child: Icon(
                  Icons.upload_rounded,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'در حال آپلود...',
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.white60 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}

/// دکمه اضافه کردن استوری - مونوکروم
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
                  color: isDarkMode ? Colors.white38 : Colors.black26,
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // برند
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 20,
                      color: Colors.white,
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
