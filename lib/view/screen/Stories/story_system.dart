// story_system.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:Vista/view/screen/PublicPosts/profileScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:mime/mime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../main.dart';
import '../../../provider/uploadStoryImage.dart';
import '../../../util/const.dart';
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
      requestFullMetadata: true, // این خط برای دریافت متادیتاهای EXIF ضروری است
    );

    if (pickedFile != null) {
      if (!context.mounted) return;

      // خواندن EXIF برای تشخیص جهت تصویر
      final bytes = await pickedFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        // تصحیح جهت تصویر قبل از ویرایش
        img.Image correctedImage;
        if (originalImage.exif.imageIfd.orientation == 6) {
          correctedImage = img.copyRotate(originalImage, angle: 90);
        } else if (originalImage.exif.imageIfd.orientation == 3) {
          correctedImage = img.copyRotate(originalImage, angle: 180);
        } else if (originalImage.exif.imageIfd.orientation == 8) {
          correctedImage = img.copyRotate(originalImage, angle: 270);
        } else {
          correctedImage = originalImage;
        }

        // ذخیره تصویر تصحیح شده
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_corrected.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(correctedImage));

        // باز کردن صفحه ویرایشگر با تصویر تصحیح شده
        final editedImage = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(
            builder: (_) => ImageEditorScreen(imagePath: tempFile.path),
          ),
        );

        // ادامه روند قبلی...
        if (editedImage != null && context.mounted) {
          try {
            // Decode کردن تصویر
            final editedImg = img.decodeImage(editedImage);
            if (editedImg == null) {
              throw Exception('تصویر ویرایش‌شده نامعتبر است');
            }
            // چرخش 180 درجه
            final rotatedImage = img.copyRotate(editedImg, angle: 180);
            // اعمال flip افقی برای اصلاح تغییر مکان چپ/راست
            final fixedImage = img.flipHorizontal(rotatedImage);
            final fixedBytes = Uint8List.fromList(img.encodeJpg(fixedImage));

            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/edited_story.jpg');
            await tempFile.writeAsBytes(fixedBytes);

            final service = ref.read(storyServiceProvider);
            await service.uploadImageStory(tempFile);

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('استوری با موفقیت اضافه شد')),
              );
              ref.invalidate(storyUsersProvider);
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  bool _isDisposed = false;
  bool _isLoading = true;
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  final Set<String> _trackedStoryViews = {};
  final Set<String> _preloadedImages = {};

  // افزودن سیستم مدیریت حافظه
  final _imageCache = <String, Uint8List>{};
  static const _maxCachedImages = 5;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    _initialize();
    _preloadNextStoryImage();
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

  Future<void> _preloadCurrentStoryImage() async {
    final story = _getCurrentStory();
    if (story.mediaUrl.isEmpty || _preloadedImages.contains(story.mediaUrl)) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final file =
          await CustomCacheManager.instance.getSingleFile(story.mediaUrl);
      final bytes = await file.readAsBytes();
      _addToImageCache(story.mediaUrl, bytes);

      if (!_isDisposed) {
        _preloadedImages.add(story.mediaUrl);
        setState(() => _isLoading = false);
        _startStoryTimer();
        _trackCurrentStory();
      }
    } catch (e) {
      debugPrint('Error preloading image: $e');
      if (!_isDisposed) {
        setState(() => _isLoading = false);
      }
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
    _pageController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _handleTapDown,
        onLongPress: () => _animationController.stop(),
        onLongPressUp: () => _animationController.forward(),
        child: Stack(
          children: [
            _buildPageView(),
            _buildProgressBar(),
            _buildHeader(),
            if (_isLoading) _buildLoadingIndicator(),
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

  void _showViewers(String storyId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => StoryViewersBottomSheet(
          storyId: storyId,
          scrollController: scrollController,
          onDismiss: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }

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

    if (dx < screenWidth * 0.3) {
      _handlePreviousStory();
    } else if (dx > screenWidth * 0.7) {
      _handleNextStory();
    } else {
      _showStoryOptions();
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
                    _showViewers(story.id!);
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
    );
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
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: _showStoryOptions,
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
        stalePeriod: const Duration(hours: 24), // کاهش زمان نگهداری کش
        maxNrOfCacheObjects: 50, // محدود کردن تعداد تصاویر کش شده
        repo: JsonCacheInfoRepository(databaseName: key),
        fileService: HttpFileService(),
      ),
    );
    return _instance!;
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
