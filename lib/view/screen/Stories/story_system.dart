// story_system.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../provider/uploadStoryImage.dart';
import '../../../util/const.dart';
import '../PublicPosts/profileScreen.dart';
import 'story_editor.dart';

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
      ''').order('created_at'), // حذف descending برای نمایش قدیمی به جدید
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

      // مرتب‌سازی استوری‌های هر کاربر بر اساس زمان
      for (var user in usersMap.values) {
        user.stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
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
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    final mimeType = lookupMimeType(file.path);
    if (mimeType == null || !allowedTypes.contains(mimeType)) {
      throw Exception('فقط مجاز به آپلود تصویر (JPEG, PNG, GIF, WEBP) هستید');
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

    return Column(
      children: [
        storiesAsync.when(
          loading: () => _buildLoadingStoryBar(),
          error: (err, _) => _buildErrorStoryBar(context, err.toString(), ref),
          data: (users) => _buildStoryList(context, users),
        ),
      ],
    );
  }

  Widget _buildLoadingStoryBar() {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5, // تعداد آیتم‌های اسکلتون
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
      ),
    );
  }

  Widget _buildErrorStoryBar(
      BuildContext context, String error, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: _ErrorView(
        error: error,
        onRetry: () => ref.refresh(storyUsersProvider),
      ),
    );
  }

  Widget _buildStoryList(BuildContext context, List<StoryUser> users) {
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: users.length + 1,
        itemBuilder: (ctx, index) {
          if (index == 0) return const _AddStoryButton();
          return StoryRing(user: users[index - 1]);
        },
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
    final seenColor = isDarkMode ? Colors.white38 : Colors.grey[300]!;

    // بررسی استوری‌های دیده نشده
    final hasUnseenStories = user.stories.any((story) => !story.isViewed);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _navigateToStoryScreen(context, user, ref),
            child: Container(
              width: 73,
              height: 73,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasUnseenStories
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF4A90E2),
                          Color.fromARGB(255, 98, 152, 213),
                          Color.fromARGB(255, 129, 171, 220),
                          Color.fromARGB(255, 174, 130, 193),
                          Color.fromARGB(255, 138, 107, 151),
                          Color(0xFF8E44AD),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: hasUnseenStories ? null : seenColor.withOpacity(0.2),
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Hero(
                  tag: 'story_avatar_${user.id}',
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
          ),
          const SizedBox(height: 4),
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
                          ? isDarkMode
                              ? Colors.white
                              : Colors.black
                          : isDarkMode
                              ? Colors.white70
                              : Colors.black54,
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
                    color: Colors.blue,
                    size: 12,
                  ),
                ],
              ],
            ),
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
      maxHeight: 1920,
      requestFullMetadata: true,
    );

    if (pickedFile != null && context.mounted) {
      try {
        // مستقیماً از فایل انتخاب شده استفاده می‌کنیم بدون چرخش
        File imageFile = File(pickedFile.path);

        if (context.mounted) {
          final editedImage = await Navigator.push<Uint8List>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StoryEditorScreen(initialImagePath: imageFile.path),
            ),
          );

          if (editedImage != null && context.mounted) {
            final finalFile =
                File('${(await getTemporaryDirectory()).path}/final_story.png');
            await finalFile.writeAsBytes(editedImage);

            final service = ref.read(storyServiceProvider);
            await service.uploadImageStory(finalFile);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('استوری با موفقیت اضافه شد')),
              );
              ref.invalidate(storyUsersProvider);
            }
          }
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: GestureDetector(
        onTap: () => _handleImageUpload(context, ref),
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
            Container(
              width: 74,
              child: Text(
                'افزودن استوری',
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  bool _isDisposed = false;
  bool _isLoading = true;
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  final Set<String> _trackedStoryViews = {};
  final Set<String> _preloadedImages = {};
  final _loadingCache = <String, bool>{};
  final _imageCache = <String, Uint8List>{};
  static const _maxCachedImages = 8; // افزایش تعداد تصاویر کش شده

  // افزودن سیستم مدیریت حافظه

  bool _isPaused = false; // اضافه کردن متغیر جدید
  final DraggableScrollableController _dragController =
      DraggableScrollableController();
  bool _isViewersVisible = false;

  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _initialize();
    _preloadStories(); // روش جدید پیش‌بارگذاری

    _preloadNextStoryImage();

    // اضافه کردن listener برای کنترلر
    _dragController.addListener(_onDragUpdate);
  }

  Future<void> _preloadStories() async {
    // پیش‌بارگذاری استوری فعلی
    await _preloadCurrentStoryImage();

    // پیش‌بارگذاری استوری بعدی
    await _preloadNextStoryImage();

    // پیش‌بارگذاری استوری کاربر بعدی (اگر وجود داشته باشد)
    if (_currentUserIndex < widget.users.length - 1) {
      final nextUser = widget.users[_currentUserIndex + 1];
      if (nextUser.stories.isNotEmpty) {
        await _preloadSpecificStory(nextUser.stories.first);
      }
    }
  }

  // پیش‌بارگذاری یک استوری خاص
  Future<void> _preloadSpecificStory(AppStoryContent story) async {
    if (story.mediaUrl.isEmpty ||
        _preloadedImages.contains(story.mediaUrl) ||
        _loadingCache[story.mediaUrl] == true) {
      return;
    }

    _loadingCache[story.mediaUrl] = true;
    try {
      // استفاده از سیستم کش شخصی‌سازی شده
      final file = await CustomCacheManager.instance.getSingleFile(
        story.mediaUrl,
        headers: {
          'Cache-Control': 'max-age=86400'
        }, // اضافه کردن هدر برای بهبود کش
      );

      final bytes = await file.readAsBytes();
      _addToImageCache(story.mediaUrl, bytes);
      _preloadedImages.add(story.mediaUrl);
      _loadingCache[story.mediaUrl] = false;
    } catch (e) {
      _loadingCache[story.mediaUrl] = false;
      debugPrint('خطا در پیش‌بارگذاری تصویر: $e');
    }
  }

  // بهبود روش پیش‌بارگذاری استوری فعلی
  Future<void> _preloadCurrentStoryImage() async {
    final story = _getCurrentStory();
    if (story.mediaUrl.isEmpty ||
        _preloadedImages.contains(story.mediaUrl) ||
        _loadingCache[story.mediaUrl] == true) {
      setState(() => _isLoading = false);
      _startStoryTimer();
      return;
    }

    setState(() => _isLoading = true);
    _loadingCache[story.mediaUrl] = true;

    try {
      // استفاده از CustomCacheManager با قابلیت نمایش پیشرفت دانلود
      final file = await CustomCacheManager.instance.getSingleFile(
        story.mediaUrl,
        headers: {'Cache-Control': 'max-age=86400'},
      );

      final bytes = await file.readAsBytes();
      _addToImageCache(story.mediaUrl, bytes);

      if (!_isDisposed) {
        _preloadedImages.add(story.mediaUrl);
        _loadingCache[story.mediaUrl] = false;
        setState(() => _isLoading = false);
        _startStoryTimer();
        _trackCurrentStory();
      }
    } catch (e) {
      _loadingCache[story.mediaUrl] = false;
      debugPrint('خطا در بارگذاری تصویر: $e');
      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
          _hasError = true; // متغیر جدید برای نشان دادن خطا
        });
      }
    }
  }

  // افزودن متغیر برای نمایش خطا
  bool _hasError = false;

  // بازنویسی نمایش نشانگر بارگذاری
  Widget _buildLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            LoadingAnimationWidget.staggeredDotsWave(
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 16),
            const Text(
              'در حال بارگذاری...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // افزودن نمایش خطا
  Widget _buildErrorView() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Colors.black,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: Colors.red[600],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'خطا در بارگذاری استوری',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'ممکن است اتصال اینترنت شما قطع باشد یا فایل استوری در دسترس نباشد.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      side: BorderSide(
                        color:
                            isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'بازگشت',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _preloadCurrentStoryImage();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'تلاش مجدد',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _initialize() {
    _currentUserIndex = widget.users.indexOf(widget.initialUser);
    _pageController = PageController(initialPage: _getGlobalStoryIndex());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..addStatusListener(_handleAnimationStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) {
        _preloadCurrentStoryImage();
      }
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_isDisposed) {
      _handleNextStory();
    }
  }

  Future<void> _preloadNextStoryImage() async {
    final nextStory = _getNextStory();
    if (nextStory?.mediaUrl == null ||
        _preloadedImages.contains(nextStory!.mediaUrl)) {
      return;
    }

    try {
      await precacheImage(
          CachedNetworkImageProvider(nextStory.mediaUrl), context);
      if (!_isDisposed) {
        _preloadedImages.add(nextStory.mediaUrl);
      }
    } catch (e) {
      debugPrint('Error preloading next image: $e');
    }
  }

  AppStoryContent? _getNextStory() {
    final currentUser = widget.users[_currentUserIndex];
    if (_currentStoryIndex < currentUser.stories.length - 1) {
      return currentUser.stories[_currentStoryIndex + 1];
    } else if (_currentUserIndex < widget.users.length - 1) {
      return widget.users[_currentUserIndex + 1].stories.first;
    }
    return null;
  }

  void _startStoryTimer() {
    if (_isLoading) return;
    _animationController.reset();
    _animationController.forward();
  }

  void _cleanupResources() {
    _preloadedImages.clear();
    _trackedStoryViews.clear();
    // _animationController.dispose();
    // _pageController.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _animationController.dispose();
    _pageController.dispose();
    _clearImageCache();
    _cleanupResources();
    _preloadedImages.clear();
    _trackedStoryViews.clear();
    _dragController.removeListener(_onDragUpdate);
    _dragController.dispose();
    super.dispose();
  }

  void _clearImageCache() {
    _imageCache.clear();
  }

  void _addToImageCache(String url, Uint8List bytes) {
    if (_imageCache.length >= _maxCachedImages) {
      _imageCache.remove(_imageCache.keys.first);
    }
    _imageCache[url] = bytes;
  }

  void _onDragUpdate() {
    if (!mounted) return;

    final extent = _dragController.size;
    if (extent > 0) {
      if (!_isPaused) {
        setState(() => _isPaused = true);
        _animationController.stop();
      }
    } else {
      if (_isViewersVisible) {
        setState(() => _isViewersVisible = false);
      }
      if (_isPaused && mounted) {
        setState(() => _isPaused = false);
        _animationController.forward();
      }
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (details.primaryDelta! < -20 && !_isViewersVisible && mounted) {
      setState(() {
        _isViewersVisible = true;
        _isPaused = true; // متوقف کردن تایمر استوری
      });
      _animationController.stop();

      // نمایش BottomSheet با StoryViewersBottomSheet
      // showModalBottomSheet(
      //   context: context,
      //   isScrollControlled: true,
      //   backgroundColor: Colors.transparent,
      //   builder: (context) => StoryViewersBottomSheet(
      //     storyId: _getCurrentStory().id!,
      //     scrollController: ScrollController(),
      //     onDismiss: () {
      //       setState(() {
      //         _isViewersVisible = false;
      //         _isPaused = false; // شروع دوباره تایمر استوری
      //       });
      //       _animationController.forward();
      //     },
      //   ),
      // );
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Story Content
            GestureDetector(
              onTapDown: _handleTapDown,
              onLongPress: () {
                _animationController.stop();
                setState(() => _isPaused = true);
              },
              onLongPressUp: () {
                if (!_isPaused) {
                  _animationController.forward();
                }
              },
              onVerticalDragUpdate: _handleVerticalDrag,
              onVerticalDragEnd: _handleVerticalDragEnd,
              child: Stack(
                children: [
                  _buildPageView(),
                  _buildProgressBar(),
                  _buildHeader(),
                  if (_isLoading) _buildLoadingIndicator(),
                  if (_isPaused && !_isViewersVisible)
                    const Center(
                      child: Icon(
                        Icons.pause_circle_outline,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  // Lottie animation as swipe up indicator
                  if (!_isViewersVisible)
                    Positioned(
                      bottom: 30,
                      left: 0,
                      right: 0,
                      child: _buildSwipeUpIndicator(),
                    ),
                ],
              ),
            ),

            // Viewers Panel
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: _isViewersVisible
                  ? 0
                  : -MediaQuery.of(context).size.height * 0.7,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.7,
              child: _buildViewersPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeUpIndicator() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.keyboard_arrow_up_rounded,
          color: Colors.white.withOpacity(0.8),
          size: 30,
        ),
        const SizedBox(height: 4),
        Text(
          'بالا بکشید تا بازدیدکنندگان را ببینید',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // void _handleVerticalDrag(DragUpdateDetails details) {
  //   if (details.primaryDelta! < -20 && !_isViewersVisible && mounted) {
  //     setState(() {
  //       _isViewersVisible = true;
  //       _isPaused = true;
  //       _animationController.stop();
  //     });
  //   } else if (details.primaryDelta! > 20 && _isViewersVisible && mounted) {
  //     setState(() {
  //       _isViewersVisible = false;
  //       _isPaused = false;
  //       _animationController.forward();
  //     });
  //   }
  // }

  void _handleVerticalDragEnd(DragEndDetails details) {
    // اگر سرعت کشیدن به سمت بالا زیاد باشد، پنل را نمایش می‌دهیم
    if (details.velocity.pixelsPerSecond.dy < -300 && !_isViewersVisible) {
      setState(() {
        _isViewersVisible = true;
        _isPaused = true;
        _animationController.stop();
      });
    }

    // اگر سرعت کشیدن به سمت پایین زیاد باشد، پنل را مخفی می‌کنیم
    else if (details.velocity.pixelsPerSecond.dy > 300 && _isViewersVisible) {
      setState(() {
        _isViewersVisible = false;
        _isPaused = false;
        _animationController.forward();
      });
    }
  }

  Widget _buildViewersPanel() {
    final story = _getCurrentStory();
    if (story.id == null || story.userId != supabase.auth.currentUser?.id) {
      return const SizedBox(); // فقط برای استوری‌های خود کاربر نمایش داده شود
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF303030);
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Container(
        color: backgroundColor,
        child: Column(
          children: [
            // Handle and Title
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: backgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle indicator
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchStoryViews(story.id!),
                    builder: (context, snapshot) {
                      final viewCount = snapshot.data?.length ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.remove_red_eye_outlined,
                            size: 20,
                            color: textColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'بازدیدکنندگان استوری ($viewCount)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // Viewers List
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchStoryViews(story.id!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red[400],
                            size: 36,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'خطا در دریافت بازدیدکنندگان',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'لطفاً مجدداً تلاش کنید',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {}); // برای اجرای مجدد FutureBuilder
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('تلاش مجدد'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDarkMode
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.05),
                              foregroundColor: textColor,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final views = snapshot.data ?? [];

                  if (views.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off_outlined,
                            size: 48,
                            color: subtitleColor.withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'هنوز کسی استوری شما را ندیده است',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'به زودی بازدیدها نمایش داده خواهند شد',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: views.length,
                    itemBuilder: (context, index) {
                      final view = views[index];
                      return InkWell(
                        onTap: () {
                          // بستن صفحه استوری
                          Navigator.of(context).pop();

                          // به جای استفاده از Named Route، از MaterialPageRoute استفاده می‌کنیم
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              userId: view['viewer_id'],
                              username: view['profiles']['username'] ?? 'کاربر',
                            ),
                          ));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Profile Image
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: CachedNetworkImage(
                                    imageUrl: view['profiles']['avatar_url'] ??
                                        defaultAvatarUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.person,
                                          color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.error,
                                          color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // User Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          view['profiles']['username'] ??
                                              'کاربر ناشناس',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                        if ((view['profiles']['is_verified'] ??
                                                false) ==
                                            true) ...[
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.verified,
                                            color: Colors.blue,
                                            size: 14,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeAgo(
                                          DateTime.parse(view['viewed_at'])),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // دکمه‌ی عملیات
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    // بستن صفحه استوری
                                    Navigator.of(context).pop();

                                    // به جای استفاده از Named Route، از MaterialPageRoute استفاده می‌کنیم
                                    Navigator.of(context)
                                        .push(MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                        userId: view['viewer_id'],
                                        username: view['profiles']
                                                ['username'] ??
                                            'کاربر',
                                      ),
                                    ));
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Bottom button to close
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isViewersVisible = false;
                      _isPaused = false;
                      _animationController.forward();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: textColor.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    minimumSize: const Size(double.infinity, 45),
                  ),
                  child: const Text('بستن و ادامه استوری'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteStory(String storyId) async {
    try {
      // نمایش دیالوگ تایید
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('حذف استوری'),
          content: const Text('آیا از حذف این استوری اطمینان دارید؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('انصراف'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('حذف'),
            ),
          ],
        ),
      );

      if (shouldDelete ?? false) {
        final service = ref.read(storyServiceProvider);
        await service.deleteStory(storyId);

        if (!mounted) return;

        // بستن صفحه استوری
        Navigator.of(context).pop();

        // نمایش پیام موفقیت
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('استوری با موفقیت حذف شد')),
        );

        // به‌روزرسانی لیست استوری‌ها
        ref.invalidate(storyUsersProvider);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در حذف استوری: $e')),
      );
    }
  }

  Future<void> _shareStory(AppStoryContent story) async {
    try {
      final url = story.mediaUrl;
      await Share.share(
        'مشاهده استوری در اپلیکیشن\n$url',
        subject: 'اشتراک‌گذاری استوری',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('خطا در اشتراک‌گذاری استوری'),
        ),
      );
    }
  }

  void _handleStoryNavigation(bool forward) {
    if (_isLoading) return;

    if (forward) {
      _handleNextStory();
    } else {
      _handlePreviousStory();
    }
  }

// اضافه کردن متد برای تشخیص double tap
  DateTime? _lastTapTime;

  void _handleDoubleTap(TapDownDetails details) {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 300)) {
      // Double tap detected
      final screenWidth = MediaQuery.of(context).size.width;
      final dx = details.globalPosition.dx;

      if (dx < screenWidth * 0.5) {
        _handleStoryNavigation(false);
      } else {
        _handleStoryNavigation(true);
      }
    }
    _lastTapTime = now;
  }

  // void _showViewers(String storyId) {
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     isScrollControlled: true,
  //     builder: (context) => DraggableScrollableSheet(
  //       initialChildSize: 0.6,
  //       minChildSize: 0.3,
  //       maxChildSize: 0.8,
  //       builder: (context, scrollController) => StoryViewersBottomSheet(
  //         storyId: storyId,
  //         scrollController: scrollController,
  //         onDismiss: () => Navigator.pop(context),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _getTotalStoryCount(),
      itemBuilder: (context, index) {
        final story = _getStoryByGlobalIndex(index);
        return Hero(
          tag: 'story-${story.id}',
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading ? 0.0 : 1.0,
            child: CachedNetworkImage(
              imageUrl: story.mediaUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.black),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error, color: Colors.white),
              ),
              cacheManager: CustomCacheManager.instance,
            ),
          ),
        );
      },
    );
  }

  // Add these methods

  void _handleTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.globalPosition.dx;
    final dy = details.globalPosition.dy;

    // تعریف محدوده آیکون های هدر
    final headerHeight = 100.0; // ارتفاع تقریبی هدر
    final isInHeaderArea =
        dy <= headerHeight + MediaQuery.of(context).padding.top;

    // اگر کلیک در ناحیه هدر بود، نباید به استوری بعدی برود
    if (isInHeaderArea) {
      return;
    }

    if (dx < screenWidth * 0.3) {
      _handlePreviousStory();
    } else if (dx > screenWidth * 0.7) {
      _handleNextStory();
    } else {
      setState(() {
        _isPaused = !_isPaused;
        if (_isPaused) {
          _animationController.stop();
        } else {
          _animationController.forward();
        }
      });
    }
  }

  void _handlePreviousStory() {
    if (_isLoading) return;

    if (_currentStoryIndex > 0) {
      setState(() {
        _currentStoryIndex--;
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _preloadCurrentStoryImage();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = widget.users[_currentUserIndex].stories.length - 1;
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _preloadCurrentStoryImage();
    }
  }

  void _handleNextStory() {
    if (_isLoading) return;

    final currentUser = widget.users[_currentUserIndex];
    if (_currentStoryIndex < currentUser.stories.length - 1) {
      setState(() {
        _currentStoryIndex++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _preloadCurrentStoryImage();
      _preloadNextStoryImage();
    } else if (_currentUserIndex < widget.users.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
      _preloadCurrentStoryImage();
      _preloadNextStoryImage();
    } else {
      Navigator.pop(context);
    }
  }

  void _showStoryOptions() {
    // استپ کردن انیمیشن قبل از نمایش باتم شیت
    _animationController.stop();

    final story = _getCurrentStory();
    final isOwner = story.userId == supabase.auth.currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (isOwner) ...[
                ListTile(
                  leading: const Icon(Icons.remove_red_eye),
                  title: const Text('مشاهده‌کنندگان'),
                  onTap: () {
                    Navigator.pop(context);
                    // _showViewers(story.id!);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('حذف استوری',
                      style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteStory(story.id!);
                  },
                ),
              ] else ...[
                ListTile(
                  leading: const Icon(Icons.report),
                  title: const Text('گزارش استوری'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(story.id!);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('اشتراک‌گذاری'),
                onTap: () {
                  Navigator.pop(context);
                  _shareStory(story);
                },
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // شروع مجدد انیمیشن بعد از بسته شدن باتم شیت
      // فقط اگر استوری در حالت pause نباشد
      if (!_isPaused) {
        _animationController.forward();
      }
    });
  }

  void _showReportDialog(String storyId) {
    final reasons = [
      'محتوای نامناسب',
      'محتوای خشونت‌آمیز',
      'محتوای اسپم',
      'نقض حق نشر',
      'سایر موارد'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش استوری'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () async {
                    Navigator.pop(context);
                    await _reportStory(storyId, reason);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _reportStory(String storyId, String reason) async {
    try {
      final service = ref.read(storyServiceProvider);
      await service.reportStory(storyId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('گزارش شما با موفقیت ثبت شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در ثبت گزارش: $e')),
        );
      }
    }
  }

  void _trackCurrentStory() async {
    final story = _getCurrentStory();
    if (story.id == null || story.userId == supabase.auth.currentUser?.id) {
      return;
    }

    final viewKey = '${story.id}-${supabase.auth.currentUser?.id}';
    if (_trackedStoryViews.contains(viewKey)) return;

    try {
      _trackedStoryViews.add(viewKey);
      await ref.read(storyServiceProvider).trackStoryView(story.id!);
    } catch (e) {
      debugPrint('Error tracking story view: $e');
    }
  }

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
        .neq('viewer_id', currentUserId)
        .order('viewed_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  AppStoryContent _getCurrentStory() {
    return widget.users[_currentUserIndex].stories[_currentStoryIndex];
  }

  int _getTotalStoryCount() {
    return widget.users.fold(0, (sum, user) => sum + user.stories.length);
  }

  int _getGlobalStoryIndex() {
    int index = 0;
    for (int i = 0; i < _currentUserIndex; i++) {
      index += widget.users[i].stories.length;
    }
    return index + _currentStoryIndex;
  }

  AppStoryContent _getStoryByGlobalIndex(int globalIndex) {
    int index = globalIndex;
    for (final user in widget.users) {
      if (index < user.stories.length) {
        return user.stories[index];
      }
      index -= user.stories.length;
    }
    throw Exception('Invalid global story index');
  }

  Widget _buildProgressBar() {
    final currentUser = widget.users[_currentUserIndex];
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: StoryProgressBar(
            controller: _animationController,
            activeIndex: _currentStoryIndex,
            itemCount: currentUser.stories.length,
            activeColor: Colors.white,
            passiveColor: Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final currentUser = widget.users[_currentUserIndex];
    return Positioned(
      top: 40, // Move header below progress bar
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: currentUser.profileImageUrl != null
                    ? CachedNetworkImageProvider(currentUser.profileImageUrl!)
                    : const AssetImage(defaultAvatarUrl) as ImageProvider,
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (currentUser.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              color: Colors.blue, size: 14),
                        ],
                      ],
                    ),
                    Text(
                      timeAgo(_getCurrentStory().createdAt),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              // تغییر در آیکون more_vert
              GestureDetector(
                onTap: () {
                  _showStoryOptions();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Add this class for custom cache management
class CustomCacheManager {
  static const key = 'storyImageCache';
  static CacheManager? _instance;

  static CacheManager get instance {
    _instance ??= CacheManager(
      Config(
        key,
        stalePeriod: const Duration(hours: 6), // کاهش زمان نگهداری کش
        maxNrOfCacheObjects: 100, // افزایش تعداد ایتم‌های کش شده
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
  }

  // روش برای پاک کردن کش استوری‌های قدیمی
  static Future<void> clearOldCache() async {
    await instance.emptyCache();
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
        (index) {
          final isActive = index == activeIndex;
          final isCompleted = index < activeIndex;

          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color:
                    isCompleted ? activeColor : passiveColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: isActive
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedBuilder(
                          animation: controller,
                          builder: (context, child) {
                            return Row(
                              children: [
                                Container(
                                  width:
                                      constraints.maxWidth * controller.value,
                                  decoration: BoxDecoration(
                                    color: activeColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    )
                  : const SizedBox(),
            ),
          );
        },
      ),
    );
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
  final VoidCallback? onRetry;

  const _ErrorView({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
            const SizedBox(height: 8),
            Text(
              'خطا در بارگذاری استوری‌ها',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'لطفاً اتصال اینترنت خود را بررسی کنید',
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('تلاش مجدد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// // Add this class to the same file or create a new one
// class StoryViewersBottomSheet extends StatelessWidget {
//   final String storyId;
//   final ScrollController scrollController;
//   final VoidCallback onDismiss;

//   const StoryViewersBottomSheet({
//     required this.storyId,
//     required this.scrollController,
//     required this.onDismiss,
//     super.key,
//   });

//   // در _fetchStoryViews
//   Future<List<Map<String, dynamic>>> _fetchStoryViews(String storyId) async {
//     final currentUserId = supabase.auth.currentUser?.id;
//     if (currentUserId == null) return [];
//     final response = await supabase
//         .from('story_views')
//         .select('''
//         viewer_id,
//         viewed_at,
//         profiles:viewer_id(
//           username,
//           avatar_url
//         )
//       ''')
//         .eq('story_id', storyId)
//         .neq('viewer_id', currentUserId) // Don't show story owner
//         .order('viewed_at', ascending: false);
//     return List<Map<String, dynamic>>.from(response);
//   }

// // در StoryViewersBottomSheet
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<List<Map<String, dynamic>>>(
//       stream: _fetchStoryViews(storyId).asStream(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }
//         if (snapshot.hasError) {
//           return Center(child: Text('خطا: ${snapshot.error}'));
//         }
//         final views = snapshot.data ?? [];
//         final viewCount = views.length;

//         return Container(
//           decoration: BoxDecoration(
//             color: Theme.of(context).brightness == Brightness.dark
//                 ? Colors.grey[900]
//                 : Colors.white,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
//           ),
//           child: Column(
//             children: [
//               // Handle bar and close button
//               Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   // Handle bar
//                   Container(
//                     margin: const EdgeInsets.symmetric(vertical: 8),
//                     width: 40,
//                     height: 4,
//                     decoration: BoxDecoration(
//                       color: Theme.of(context).brightness == Brightness.dark
//                           ? Colors.grey[900]
//                           : Colors.white,
//                       borderRadius:
//                           const BorderRadius.vertical(top: Radius.circular(16)),
//                     ),
//                   ),
//                   // Close button
//                   Positioned(
//                     right: 8,
//                     top: 8,
//                     child: IconButton(
//                       icon: const Icon(Icons.close),
//                       onPressed: onDismiss,
//                     ),
//                   ),
//                 ],
//               ),
//               // Title with view count
//               Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Text(
//                   'بازدیدها ($viewCount)',
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//               // Viewers list
//               Expanded(
//                 child: ListView.builder(
//                   controller: scrollController,
//                   itemCount: views.length,
//                   itemBuilder: (context, index) {
//                     final view = views[index];
//                     return ListTile(
//                       leading: CircleAvatar(
//                         backgroundImage: CachedNetworkImageProvider(
//                           view['profiles']['avatar_url'] ?? defaultAvatarUrl,
//                         ),
//                       ),
//                       title:
//                           Text(view['profiles']['username'] ?? 'کاربر ناشناس'),
//                       subtitle:
//                           Text(_getTimeAgo(DateTime.parse(view['viewed_at']))),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   String _getTimeAgo(DateTime dateTime) {
//     final now = DateTime.now();
//     final difference = now.difference(dateTime);

//     if (difference.inMinutes < 1) {
//       return 'همین الان';
//     } else if (difference.inHours < 1) {
//       return '${difference.inMinutes} دقیقه پیش';
//     } else if (difference.inDays < 1) {
//       return '${difference.inHours} ساعت پیش';
//     } else {
//       return '${difference.inDays} روز پیش';
//     }
//   }
// }
