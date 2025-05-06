import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math' as math;

import '../../main.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
import 'ReelsVideoPlayer.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  final List<PublicPostModel> posts;
  final int initialIndex;
  final Map<String, Duration>
      initialPositions; // اضافه کردن پارامتر موقعیت‌های اولیه

  const ReelsScreen({
    Key? key,
    required this.posts,
    this.initialIndex = 0,
    this.initialPositions = const {}, // مقدار پیش‌فرض خالی
  }) : super(key: key);

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with AutomaticKeepAliveClientMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isLoading = false;
  late SupabaseService _supabaseService;

  @override
  bool get wantKeepAlive => true; // برای حفظ وضعیت ویدیوها در هنگام اسکرول

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _supabaseService = SupabaseService(supabase);

    // لاگ کردن موقعیت‌های اولیه برای دیباگ
    if (widget.initialPositions.isNotEmpty) {
      print('Initial positions: ${widget.initialPositions}');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (index == widget.posts.length - 1) {
      _loadMorePosts();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // برای لود کردن پست‌های بیشتر
      await ref.read(publicPostsProvider.notifier).loadMorePosts();
    } catch (e) {
      print('خطا در بارگذاری پست‌های بیشتر: $e');
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

  Future<void> _likeReel(PublicPostModel reel) async {
    try {
      // Optimistic update - بروزرسانی فوری UI
      final updatedReel = reel.copyWith(
        isLiked: !reel.isLiked,
        likeCount: reel.isLiked ? reel.likeCount - 1 : reel.likeCount + 1,
      );

      // بروزرسانی state محلی
      setState(() {
        final index = widget.posts.indexWhere((post) => post.id == reel.id);
        if (index != -1) {
          widget.posts[index] = updatedReel;
        }
      });

      // بروزرسانی state عمومی
      ref.read(publicPostsProvider.notifier).updatePost(updatedReel);

      // ارسال درخواست به سرور
      await ref.read(supabaseServiceProvider).toggleLike(
            postId: reel.id!,
            ownerId: reel.userId!,
            ref: ref,
          );
    } catch (e) {
      // در صورت خطا، برگرداندن تغییرات
      final revertedReel = reel.copyWith(
        isLiked: reel.isLiked,
        likeCount: reel.likeCount,
      );

      setState(() {
        final index = widget.posts.indexWhere((post) => post.id == reel.id);
        if (index != -1) {
          widget.posts[index] = revertedReel;
        }
      });

      ref.read(publicPostsProvider.notifier).updatePost(revertedReel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطا در ثبت لایک')),
        );
      }
    }
  }

  void _sharePost(PublicPostModel post) {
    String shareText = "ویدیوی جالب از ${post.username}";
    if (post.title != null && post.title!.isNotEmpty) {
      shareText += ": ${post.title}";
    }

    Share.share('$shareText\n\nاین ویدیو را در اپلیکیشن ما مشاهده کنید!');
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
                child: commentsList(post.id!, controller),
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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // صفحه اصلی ریلز با اسکرول عمودی
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: widget.posts.length,
            itemBuilder: (context, index) {
              final post = widget.posts[index];
              if (post.videoUrl == null || post.videoUrl!.isEmpty) {
                // اگر ویدیو نداشت، یک صفحه خالی یا خطا نمایش دهید
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, color: Colors.white70, size: 48),
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
              final postId = post.id ?? '';

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
              );
            },
          ),

          // دکمه بازگشت
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
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
    );
  }
}
