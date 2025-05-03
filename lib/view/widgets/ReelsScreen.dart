import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:math' as math;

import '../../main.dart';
import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
import '../util/widgets.dart';
import 'ReelsVideoPlayer.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  final List<PublicPostModel> posts;
  final int initialIndex;

  const ReelsScreen({
    Key? key,
    required this.posts,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _isLoading = false;
  late SupabaseService _supabaseService;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _supabaseService = SupabaseService(supabase);
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

    // برای لود کردن پست‌های بیشتر
    await ref.read(publicPostsProvider.notifier).loadMorePosts();

    setState(() {
      _isLoading = false;
    });
  }

  void _likePost(PublicPostModel post) async {
    try {
      await _supabaseService.toggleLike(
        postId: post.id,
        ownerId: post.userId,
        ref: ref,
      );
    } catch (e) {
      print('خطا در لایک کردن پست: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در لایک کردن پست')),
      );
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
    // استفاده از ویجت موجود برای نمایش کامنت‌ها
    showCommentsBottomSheet(context, post.id, ref);
  }

  @override
  Widget build(BuildContext context) {
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
                  child: Text(
                    'این پست ویدیو ندارد',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return ReelsVideoPlayer(
                post: post,
                isActive: index == _currentIndex,
                onLike: () => _likePost(post),
                onComment: () => _showComments(post),
                onShare: () => _sharePost(post),
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
