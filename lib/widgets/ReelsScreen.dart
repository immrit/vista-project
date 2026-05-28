import '../../security/logging_utility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// removed unused imports

import '../../model/publicPostModel.dart';
import '../../features/posts/data/go_posts_repository.dart';
import '../../provider/provider.dart';
import '../../services/smart_share_service.dart';
import 'ReelsVideoPlayer.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  final List<PublicPostModel> posts;
  final int initialIndex;
  final Map<String, Duration>
      initialPositions; // اضافه کردن پارامتر موقعیت‌های اولیه

  const ReelsScreen({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.initialPositions = const {}, // مقدار پیش‌فرض خالی
  });

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  late List<PublicPostModel> _reels;
  int _currentIndex = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  final GoPostsRepository _postsRepository = GoPostsRepository();
  // Post action service is read on demand.

  @override
  bool get wantKeepAlive => true; // برای حفظ وضعیت ویدیوها در هنگام اسکرول

  @override
  void initState() {
    super.initState();
    _reels = List<PublicPostModel>.from(widget.posts);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    // Post actions are provided by postActionsServiceProvider.

    // لاگ کردن موقعیت‌های اولیه برای دیباگ
    if (widget.initialPositions.isNotEmpty) {
      logInfo('Initial positions: ${widget.initialPositions}');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == _reels.length - 1) {
      _loadMorePosts();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final lastOffset = _reels.isNotEmpty
          ? _reels.last.createdAt.toUtc().toIso8601String()
          : 0;
      final fetched =
          await _postsRepository.getFeed(limit: 20, offset: lastOffset);
      final reels = fetched
          .where((post) => post.videoUrl != null && post.videoUrl!.isNotEmpty)
          .toList();

      if (reels.isEmpty) {
        _hasMore = false;
      } else {
        final existingIds = _reels.map((p) => p.id).toSet();
        final newUnique =
            reels.where((p) => !existingIds.contains(p.id)).toList();
        if (newUnique.isEmpty) {
          _hasMore = false;
        } else {
          setState(() {
            _reels.addAll(newUnique);
          });
        }
      }
    } catch (e) {
      logInfo('خطا در بارگذاری پست‌های بیشتر: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری پست‌های بیشتر')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sharePost(PublicPostModel post) {
    // استفاده از قابلیت جدید اشتراک‌گذاری تصویری
    SmartShareService().showShareOptions(post, context);
  }

  void _showComments(PublicPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25.0),
              topRight: Radius.circular(25.0),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'نظرات',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(),
              // اینجا کامپوننت نمایش کامنت‌ها را قرار دهید
              Expanded(
                child: commentsList(post.id, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // کامپوننت نمایش کامنت‌ها - این متد را بر اساس نیاز خود پیاده‌سازی کنید
  Widget commentsList(String postId, ScrollController controller) {
    // این بخش می‌تواند از یک FutureBuilder یا ConsumerWidget استفاده کند
    // که کامنت‌ها را از سوپابیس می‌خواند
    return Center(
      child: Text('در حال بارگذاری نظرات...'),
    );
  }

  // ذخیره موقعیت پخش فعلی ویدیو در provider
  void _saveVideoPosition(String postId, Duration position) {
    if (postId.isNotEmpty) {
      ref.read(videoPositionProvider(postId).notifier).state = position;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // لازم برای AutomaticKeepAliveClientMixin

    return SafeArea(
      bottom: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // صفحه اصلی ریلز با اسکرول عمودی
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: _reels.length,
              itemBuilder: (context, index) {
                final post = _reels[index];
                if (post.videoUrl == null || post.videoUrl!.isEmpty) {
                  // اگر ویدیو نداشت، یک صفحه خالی یا خطا نمایش دهید
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_off,
                            color: Colors.white70, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'این پست ویدیو ندارد',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }

                // موقعیت اولیه ویدیو را پاس می‌دهیم (اگر وجود داشته باشد)
                Duration? initialPosition;
                final postId = post.id;

                if (widget.initialPositions.containsKey(postId)) {
                  initialPosition = widget.initialPositions[postId];
                  print(
                      'بارگذاری ویدیو $postId با موقعیت اولیه: $initialPosition');
                }

                return ReelsVideoPlayer(
                  post: post,
                  isActive: index == _currentIndex,
                  onLike: () {
                    // این تابع فقط برای آگاهی ReelsScreen از تغییر لایک است
                    // اینجا نباید عملیات لایک دوباره انجام شود
                    // می‌توانید وضعیت پست را از provider بخوانید و UI را آپدیت کنید
                    setState(() {
                      // آپدیت UI صفحه ReelsScreen در صورت نیاز
                    });
                  },
                  onComment: () => _showComments(post),
                  onShare: () => _sharePost(post),
                  initialPosition: initialPosition, // پاس دادن موقعیت اولیه
                  onPositionChanged: (position) {
                    // ذخیره موقعیت فعلی برای استفاده بعدی
                    _saveVideoPosition(postId, position);
                  },
                  // احترام به تنظیم کاربر برای پخش خودکار
                  autoPlayInFeed: ref.watch(autoPlayProvider),
                );
              },
            ),
            // دکمه بازگشت
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            // نشانگر لودینگ
            if (_isLoading)
              Positioned(
                bottom: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
