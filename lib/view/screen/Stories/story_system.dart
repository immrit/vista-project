// story_system.dart
import 'dart:async';
import 'dart:io';
import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../provider/uploadStoryImage.dart';
import '../../../util/const.dart';

// در ابتدای فایل (بعد از importها) اضافه کنید:
String timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);
  if (difference.inSeconds < 60) return 'همین الان';
  if (difference.inMinutes < 60) return '${difference.inMinutes} دقیقه پیش';
  if (difference.inHours < 24) return '${difference.inHours} ساعت پیش';
  return '${difference.inDays} روز پیش';
}

/// مدل‌های داده
@immutable
class StoryUser {
  final String id;
  final String username;
  final String? profileImageUrl;
  final DateTime? lastStoryDate;
  final List<AppStoryContent> stories;
  final bool isVerified;
  final bool isViewed; // فیلد جدید

  const StoryUser({
    required this.id,
    required this.username,
    this.profileImageUrl,
    this.lastStoryDate,
    this.stories = const [],
    this.isVerified = false,
    this.isViewed = false, // مقدار پیش‌فرض false
  });

  StoryUser copyWith({
    List<AppStoryContent>? stories,
    DateTime? lastStoryDate,
    bool? isVerified,
    bool? isViewed, // اضافه کردن isViewed
  }) {
    return StoryUser(
      id: id,
      username: username,
      profileImageUrl: profileImageUrl,
      stories: stories ?? this.stories,
      lastStoryDate: lastStoryDate ?? this.lastStoryDate,
      isVerified: isVerified ?? this.isVerified,
      isViewed: isViewed ?? this.isViewed, // به‌روزرسانی isViewed
    );
  }
}

class AppStoryContent {
  final String? id;
  final String mediaUrl;
  final DateTime createdAt;
  final Duration duration;
  final String? userId;
  final bool isViewed;

  const AppStoryContent({
    this.id,
    required this.mediaUrl,
    required this.createdAt,
    required this.userId,
    this.duration = const Duration(seconds: 7),
    this.isViewed = false,
  });
  AppStoryContent copyWith({
    String? id,
    String? userId,
    String? mediaUrl,
    DateTime? createdAt,
    bool? isViewed,
  }) {
    return AppStoryContent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      createdAt: createdAt ?? this.createdAt,
      isViewed: isViewed ?? this.isViewed,
    );
  }
}

enum MediaType { image, video }

class Story {
  final String id;
  final String userId;
  final String mediaUrl;
  final String? caption;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isViewed;
  final String mediaType;
  final int viewsCount;

  Story({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    this.caption,
    required this.createdAt,
    required this.expiresAt,
    this.isViewed = false,
    required this.mediaType,
    this.viewsCount = 0,
  });

  factory Story.fromMap(Map map) {
    return Story(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      mediaUrl: map['media_url'] ?? '',
      caption: map['caption'],
      createdAt:
          DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
      expiresAt: DateTime.parse(map['expires_at'] ??
          DateTime.now().add(const Duration(hours: 24)).toIso8601String()),
      mediaType: map['media_type'] ?? 'image',
      viewsCount: map['views_count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'media_url': mediaUrl,
      'caption': caption,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'media_type': mediaType,
      'views_count': viewsCount,
    };
  }
}

/// سرویس Supabase
class StoryService {
  final SupabaseClient _client;
  static final _uuid = const Uuid();

  StoryService() : _client = supabase;

  Future<List<String>> fetchFollowingIds() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      final response = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      return List<String>.from(response.map((row) => row['following_id']));
    } catch (e) {
      print('Error fetching following IDs: $e');
      return [];
    }
  }

  Future<List<StoryUser>> fetchActiveUsers() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');

      // موازی‌سازی درخواست‌ها
      final (followingIds, storiesResponse, viewsResponse) = await (
        fetchFollowingIds(),
        _client.from('stories').select('''
        id,
        user_id,
        profiles!inner(username, avatar_url, is_verified),
        media_url,
        created_at
      ''').order('created_at', ascending: false).limit(100),
        _client
            .from('story_views')
            .select('story_id, is_viewed')
            .eq('viewer_id', currentUserId),
      ).wait;

      final viewsMap = <String, bool>{};
      for (final view in viewsResponse) {
        viewsMap[view['story_id'] as String] = view['is_viewed'] as bool;
      }

      final usersMap = <String, StoryUser>{};
      for (final item in storiesResponse) {
        final userId = item['user_id'] as String;
        if (!(userId == currentUserId || followingIds.contains(userId))) {
          continue;
        }

        final storyId = item['id'] as String;
        final isViewed = viewsMap[storyId] ?? false;

        final story = AppStoryContent(
          id: storyId,
          userId: userId,
          mediaUrl: item['media_url'] as String,
          createdAt: DateTime.parse(item['created_at'] as String),
          isViewed: isViewed,
        );

        usersMap.update(
          userId,
          (user) => user.copyWith(stories: [...user.stories, story]),
          ifAbsent: () => StoryUser(
            id: userId,
            username: item['profiles']['username'] as String,
            profileImageUrl: item['profiles']['avatar_url'] as String?,
            lastStoryDate: DateTime.parse(item['created_at'] as String),
            isVerified: item['profiles']['is_verified'] as bool? ?? false,
            stories: [story],
          ),
        );
      }

      final currentUserStories = usersMap[currentUserId];
      final otherUsersStories =
          usersMap.values.where((user) => user.id != currentUserId).toList();

      return [
        if (currentUserStories != null) currentUserStories,
        ...otherUsersStories,
      ];
    } catch (e) {
      print('Error fetching active users: $e');
      rethrow;
    }
  }

  Future<void> uploadImageStory(File imageFile) async {
    try {
      _validateImageFile(imageFile);
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final imageUrl =
          await StoryImageUploadService.uploadStoryImage(imageFile);
      if (imageUrl == null) throw Exception('Failed to upload image');

      final storyId = _uuid.v4();
      await _client.from('stories').insert({
        'id': storyId,
        'user_id': userId,
        'media_url': imageUrl,
        'media_type': 'image',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      }).select();

      print('Story created with ID: $storyId');
    } catch (e) {
      print('Error uploading story: $e');
      rethrow;
    }
  }

  void _validateImageFile(File file) {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif'];
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !allowedTypes.contains(mimeType)) {
      throw Exception('فقط مجاز به آپلود تصویر (JPEG, PNG, GIF) هستید');
    }
    final sizeInMB = file.lengthSync() / (1024 * 1024);
    if (sizeInMB > 15) {
      throw Exception('حداکثر سایز فایل ۱۵ مگابایت است');
    }
  }

  Future trackStoryView(String storyId) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';
      // بررسی اینکه آیا این بازدید قبلاً ثبت شده است یا خیر
      final existingView = await supabase
          .from('story_views')
          .select()
          .eq('story_id', storyId)
          .eq('viewer_id', userId)
          .maybeSingle();
      if (existingView != null) {
        debugPrint('This story view is already tracked');
        return; // اگر قبلاً ثبت شده، دیگر تکرار نکن
      }
      // ثبت بازدید جدید با is_viewed = TRUE
      await supabase.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': userId,
        'viewed_at': DateTime.now().toIso8601String(),
        'is_viewed': true, // اضافه کردن این فیلد
      });
      debugPrint('Story view tracked successfully');
    } catch (e) {
      debugPrint('Error tracking story view: $e');
      throw 'Failed to track story view';
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');
      await _client
          .from('stories')
          .delete()
          .eq('id', storyId)
          .eq('user_id', currentUserId);
      print('Story deleted: $storyId');
    } catch (e) {
      print('Error deleting story: $e');
      rethrow;
    }
  }

  Future<void> reportStory(String storyId, String reason) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw Exception('User not authenticated');
      await _client.from('story_reports').insert({
        'story_id': storyId,
        'reporter_id': currentUserId,
        'reason': reason,
        'reported_at': DateTime.now().toIso8601String(),
      });
      print('Story reported: $storyId');
    } catch (e) {
      print('Error reporting story: $e');
      rethrow;
    }
  }
}

/// Riverpod Providers
final storyServiceProvider = Provider((ref) => StoryService());
final storyUsersProvider = FutureProvider.autoDispose((ref) {
  final service = ref.watch(storyServiceProvider);
  return service.fetchActiveUsers();
});
final currentStoryProvider = StateProvider((ref) => null);

/// ویجت‌ها
class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(storyUsersProvider);

    return SizedBox(
      height: 100,
      child: storiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(error: err.toString()),
        data: (users) => ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: users.length + 1,
          itemBuilder: (ctx, index) {
            if (index == 0) return const _AddStoryButton();
            return StoryRing(user: users[index - 1]);
          },
        ),
      ),
    );
  }
}

class StoryRing extends ConsumerWidget {
  final StoryUser user;

  const StoryRing({super.key, required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final ringColor = isDarkMode ? Colors.grey[800] : Colors.grey[300];
    final seenColor = isDarkMode ? Colors.white : Colors.white;

    // بررسی اینکه آیا حداقل یک استوری دیده نشده است
    final hasUnseenStories = user.stories.any((story) => !story.isViewed);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          InkWell(
            onTap: () => _navigateToStoryScreen(context, user, ref),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: hasUnseenStories
                    ? const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF8E44AD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: Border.all(
                  color: hasUnseenStories ? Colors.transparent : seenColor,
                  width: 1,
                ),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: CircleAvatar(
                  backgroundImage: (user.profileImageUrl == null ||
                          user.profileImageUrl!.isEmpty)
                      ? const AssetImage(defaultAvatarUrl)
                      : CachedNetworkImageProvider(user.profileImageUrl!)
                          as ImageProvider,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                user.username,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.fade,
                maxLines: 1,
                softWrap: false,
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, color: Colors.blue, size: 14),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToStoryScreen(
      BuildContext context, StoryUser user, WidgetRef ref) {
    if (user.stories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هیچ استوری برای نمایش وجود ندارد')),
      );
      return;
    }

    final storiesAsync = ref.read(storyUsersProvider);
    storiesAsync.whenData((allUsers) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryPlayerScreen(
            initialUser: user,
            users: allUsers,
          ),
        ),
      );
    });
  }
}

class _AddStoryButton extends ConsumerWidget {
  const _AddStoryButton();

  Future<void> _handleImageUpload(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      try {
        final service = ref.read(storyServiceProvider);
        await service.uploadImageStory(File(pickedFile.path));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('استوری با موفقیت اضافه شد')),
          );
          ref.invalidate(storyUsersProvider); // بروزرسانی UI
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () => _handleImageUpload(context, ref),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 30),
            ),
            const Text('افزودن استوری'),
          ],
        ),
      ),
    );
  }
}

class StoryPlayerScreen extends ConsumerStatefulWidget {
  final StoryUser initialUser;
  final List<StoryUser> users;

  const StoryPlayerScreen({
    required this.initialUser,
    required this.users,
    super.key,
  });

  @override
  ConsumerState createState() => _StoryPlayerScreenState();
}

class _StoryPlayerScreenState extends ConsumerState<StoryPlayerScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  Timer? _progressTimer;
  bool _isDisposed = false;
  int _currentUserIndex = 0; // شاخص کاربر فعلی
  int _currentStoryIndex = 0; // شاخص استوری فعلی
  final Set<String> _trackedStoryViews = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    _currentUserIndex = widget.users.indexOf(widget.initialUser);
    _currentStoryIndex = 0;

    _pageController = PageController(initialPage: _getGlobalStoryIndex());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isDisposed) {
        _handleNextStory();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _startStoryTimer();
        _trackCurrentStory();
      }
    });
  }

  void _startStoryTimer() {
    _animationController.reset();
    _animationController.forward();
  }

  void _pauseOrResumeAnimation() {
    if (_animationController.isAnimating) {
      _animationController.stop();
    } else {
      _animationController.forward();
    }
  }

  void _handleNextStory() {
    final currentUser = widget.users[_currentUserIndex];

    if (_currentStoryIndex < currentUser.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
      });
      _startStoryTimer();
    } else if (_currentUserIndex < widget.users.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _startStoryTimer();
    } else {
      Navigator.pop(context);
      return;
    }

    _pageController.animateToPage(
      _getGlobalStoryIndex(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _trackCurrentStory();
  }

  void _handlePreviousStory() {
    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
      });
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        final previousUser = widget.users[_currentUserIndex];
        _currentStoryIndex = previousUser.stories.length - 1;
      });
    } else {
      return;
    }

    _pageController.animateToPage(
      _getGlobalStoryIndex(),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _startStoryTimer();
    _trackCurrentStory();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = widget.users[_currentUserIndex];
    final currentStory = _getCurrentStory();
    final isCurrentUserStory =
        currentStory.userId == supabase.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (details) {
          final screenWidth = MediaQuery.of(context).size.width;
          final tapPosition = details.globalPosition.dx;

          if (tapPosition < screenWidth * 0.35) {
            _handlePreviousStory();
          } else if (tapPosition > screenWidth * 0.65) {
            _handleNextStory();
          } else {
            _pauseOrResumeAnimation();
          }
        },
        child: Stack(
          children: [
            // Story Content
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                if (!_isDisposed) {
                  _updateIndicesFromGlobalIndex(index);
                  _startStoryTimer();
                  _trackCurrentStory();
                }
              },
              itemCount: _getTotalStoryCount(),
              itemBuilder: (context, index) {
                final story = _getStoryByGlobalIndex(index);
                return Hero(
                  tag: 'story-${story.id}',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: story.mediaUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.black,
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.error, color: Colors.white),
                        ),
                        cacheKey: story
                            .mediaUrl, // اضافه کردن cacheKey برای بهبود عملکرد
                      ),
                    ],
                  ),
                );
              },
            ),
            // Header Section with Progress Bar
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: StoryProgressBar(
                      controller: _animationController,
                      activeIndex: _currentStoryIndex,
                      itemCount: currentUser.stories.length,
                      activeColor: Colors.white,
                      passiveColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // User Info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white38, width: 1),
                          ),
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                                    builder: (context) => ProfileScreen(
                                          userId: currentUser.id,
                                          username: currentUser.username,
                                        ))),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  (currentUser.profileImageUrl == null ||
                                          currentUser.profileImageUrl!.isEmpty)
                                      ? const AssetImage(defaultAvatarUrl)
                                      : CachedNetworkImageProvider(
                                              currentUser.profileImageUrl!)
                                          as ImageProvider,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    currentUser.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (currentUser.isVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 14,
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                timeAgo(_getCurrentStory().createdAt),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                          ),
                          onSelected: (value) async {
                            final storyService = ref.read(storyServiceProvider);
                            final currentStory = _getCurrentStory();
                            if (value == 'delete') {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('حذف استوری'),
                                  content: const Text(
                                      'آیا از حذف این استوری مطمئن هستید؟'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('خیر'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('بله'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await storyService
                                      .deleteStory(currentStory.id!);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('استوری حذف شد')),
                                    );
                                    ref.invalidate(
                                        storyUsersProvider); // بروزرسانی UI
                                    Navigator.pop(
                                        context); // بستن صفحه پخش استوری
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'خطا در حذف استوری: ${e.toString()}')),
                                    );
                                  }
                                }
                              }
                            }
                          },
                          itemBuilder: (context) {
                            if (currentStory.userId ==
                                supabase.auth.currentUser?.id) {
                              return const [
                                PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Text('حذف استوری'),
                                ),
                              ];
                            } else {
                              return const [
                                PopupMenuItem<String>(
                                  value: 'report',
                                  child: Text('گزارش استوری'),
                                ),
                              ];
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Views button at bottom center (only for current user's story)
            if (isCurrentUserStory)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    if (currentStory.id != null) {
                      _showViewersBottomSheet(context, currentStory.id!);
                    }
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.remove_red_eye,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'مشاهده بازدیدها',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getGlobalStoryIndex() {
    int globalIndex = 0;
    for (int i = 0; i < _currentUserIndex; i++) {
      globalIndex += widget.users[i].stories.length;
    }
    globalIndex += _currentStoryIndex;
    return globalIndex;
  }

  int _getTotalStoryCount() {
    return widget.users.fold(0, (sum, user) => sum + user.stories.length);
  }

  AppStoryContent _getStoryByGlobalIndex(int globalIndex) {
    int currentIndex = 0;
    for (final user in widget.users) {
      if (currentIndex + user.stories.length > globalIndex) {
        return user.stories[globalIndex - currentIndex];
      }
      currentIndex += user.stories.length;
    }
    throw Exception('Invalid global index');
  }

  void _updateIndicesFromGlobalIndex(int globalIndex) {
    int currentIndex = 0;
    for (int i = 0; i < widget.users.length; i++) {
      final user = widget.users[i];
      if (currentIndex + user.stories.length > globalIndex) {
        setState(() {
          _currentUserIndex = i;
          _currentStoryIndex = globalIndex - currentIndex;
        });
        return;
      }
      currentIndex += user.stories.length;
    }
    throw Exception('Invalid global index');
  }

  void _trackCurrentStory() async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return;
    final currentStory = _getCurrentStory();
    if (currentStory.id == null || currentStory.userId == currentUserId) return;

    final viewKey = '${currentStory.id}-$currentUserId';
    if (_trackedStoryViews.contains(viewKey)) {
      return;
    }

    try {
      _trackedStoryViews.add(viewKey);

      // Track the story view in the database
      await supabase.from('story_views').insert({
        'story_id': currentStory.id,
        'viewer_id': currentUserId,
        'viewed_at': DateTime.now().toIso8601String(),
        'is_viewed': true,
      });

      debugPrint('Story view tracked: ${currentStory.id}');

      // Update the state using the provider
      ref.read(storyUsersProvider);
    } catch (e) {
      debugPrint('Error tracking story view: $e');
    }
  }

  AppStoryContent _getCurrentStory() {
    final currentUser = widget.users[_currentUserIndex];
    return currentUser.stories[_currentStoryIndex];
  }

  @override
  void dispose() {
    _isDisposed = true;
    _progressTimer?.cancel();
    _animationController.dispose();
    _pageController.dispose();
    _trackedStoryViews.clear();
    super.dispose();
  }

  void _startTimer() {
    _animationController.reset();
    _animationController.forward();

    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!_animationController.isAnimating) {
        _animationController.forward();
      }
    });
  }

  void _handleAnimationProgress() {
    if (!mounted) return;

    final progress = _animationController.value;
    if (progress >= 1.0) {
      _handleNextStory();
    }
  }

  void _showViewersBottomSheet(BuildContext context, String storyId) {
    // Pause story animation when showing bottom sheet
    _animationController.stop();

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.black
          : Colors.white,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => StoryViewersBottomSheet(
          storyId: storyId,
          scrollController: scrollController,
          onDismiss: () {
            // Resume story animation when bottom sheet is closed
            Navigator.pop(context);
            _animationController.forward();
          },
        ),
      ),
    ).whenComplete(() {
      // Resume story animation when bottom sheet is closed
      if (!_isDisposed && mounted) {
        _animationController.forward();
      }
    });
  }
}

class StoryProgressBar extends StatelessWidget {
  final AnimationController controller;
  final int activeIndex;
  final int itemCount;
  final Color activeColor;
  final Color passiveColor;

  const StoryProgressBar({
    super.key,
    required this.controller,
    required this.activeIndex,
    required this.itemCount,
    required this.activeColor,
    required this.passiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        itemCount,
        (index) => Expanded(
          child: ValueListenableBuilder<double>(
            valueListenable: controller,
            builder: (context, value, child) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _getProgressValue(index),
                    backgroundColor: passiveColor,
                    valueColor: AlwaysStoppedAnimation(activeColor),
                    minHeight: 2.5,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _getProgressValue(int index) {
    if (index < activeIndex) return 1.0;
    if (index > activeIndex) return 0.0;
    return controller.value;
  }
}

class CloseStoryButton extends StatelessWidget {
  const CloseStoryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Positioned(
        top: MediaQuery.of(context).padding.top,
        right: 8,
        child: IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.white,
            size: 28,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;

  const _ErrorView({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 10),
          Text('خطا در دریافت داده‌ها',
              style: Theme.of(context).textTheme.titleMedium),
          Text(error, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

// Add this class to the same file or create a new one
class StoryViewersBottomSheet extends StatelessWidget {
  final String storyId;
  final ScrollController scrollController;
  final VoidCallback onDismiss;

  const StoryViewersBottomSheet({
    required this.storyId,
    required this.scrollController,
    required this.onDismiss,
    super.key,
  });

  // در _fetchStoryViews
  Future<List<Map<String, dynamic>>> _fetchStoryViews(String storyId) async {
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];
    final response = await supabase
        .from('story_views')
        .select('''
        viewer_id,
        viewed_at,
        profiles:viewer_id(
          username,
          avatar_url
        )
      ''')
        .eq('story_id', storyId)
        .neq('viewer_id', currentUserId) // Don't show story owner
        .order('viewed_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

// در StoryViewersBottomSheet
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _fetchStoryViews(storyId).asStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('خطا: ${snapshot.error}'));
        }
        final views = snapshot.data ?? [];
        final viewCount = views.length;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[900]
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle bar and close button
              Stack(
                alignment: Alignment.center,
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[900]
                          : Colors.white,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                  ),
                  // Close button
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onDismiss,
                    ),
                  ),
                ],
              ),
              // Title with view count
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'بازدیدها ($viewCount)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Viewers list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: views.length,
                  itemBuilder: (context, index) {
                    final view = views[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          view['profiles']['avatar_url'] ?? defaultAvatarUrl,
                        ),
                      ),
                      title:
                          Text(view['profiles']['username'] ?? 'کاربر ناشناس'),
                      subtitle:
                          Text(_getTimeAgo(DateTime.parse(view['viewed_at']))),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }
}
