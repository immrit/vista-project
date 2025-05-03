import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../main.dart'; // اضافه کردن import

import '../../model/publicPostModel.dart';
import '../../provider/provider.dart';
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
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onLikePost(PublicPostModel post) async {
    try {
      await ref.read(supabaseServiceProvider).toggleLike(
            postId: post.id!,
            ownerId: post.userId!,
            ref: ref,
          );
    } catch (e) {
      print('خطا در لایک پست: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در لایک پست')),
        );
      }
    }
  }

  void _onCommentPost(PublicPostModel post) {
    // نمایش دیالوگ نظر
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('نظرات',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // اینجا می‌توانید لیست نظرات را نمایش دهید
              Expanded(
                child: Center(
                  child: Text('بخش نظرات به زودی فعال می‌شود'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSharePost(PublicPostModel post) {
    final url = post.videoUrl ?? 'https://yourdomain.com/post/${post.id}';
    Share.share('این پست را ببینید: $url');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'ریلز',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.posts.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          return ReelsVideoPlayer(
            post: post,
            isActive: index == _currentIndex,
            onLike: () => _onLikePost(post),
            onComment: () => _onCommentPost(post),
            onShare: () => _onSharePost(post),
          );
        },
      ),
    );
  }
}
