import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/post_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  void _loadMorePosts() {
    final currentPage = ref.read(currentPageProvider);
    ref.read(currentPageProvider.notifier).state = currentPage + 1;
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(postsWithEngagementProvider(_currentPage));
    final cachedPosts = ref.watch(cachedPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('خانه'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(currentPageProvider.notifier).state = 0;
          ref.read(cachedPostsProvider.notifier).clearPosts();
        },
        child: postsAsync.when(
          data: (posts) {
            // اضافه کردن پست‌های جدید به کش
            if (posts.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(cachedPostsProvider.notifier).addPosts(posts);
              });
            }

            final allPosts = cachedPosts.isEmpty ? posts : cachedPosts;

            if (allPosts.isEmpty) {
              return const Center(
                child: Text(
                  'هیچ پستی یافت نشد',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            return ListView.builder(
              controller: _scrollController,
              itemCount: allPosts.length + 1, // +1 برای نشان دادن loading
              itemBuilder: (context, index) {
                if (index == allPosts.length) {
                  // نشان دادن loading در انتهای لیست
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final post = allPosts[index];
                return PostCard(post: post);
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'خطا در بارگذاری پست‌ها: $error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(postsWithEngagementProvider(_currentPage));
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostCard({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final likeCount = post['like_count'] ?? 0;
    final commentCount = post['comment_count'] ?? 0;
    final engagementScore = post['engagement_score'] ?? 0;
    final content = post['content'] ?? '';
    final createdAt = post['created_at'] ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // محتوای پست
            Text(
              content,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),

            // آمار تعامل
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text('$likeCount'),
                const SizedBox(width: 16),
                Image.asset(
                  'lib/view/util/images/component/comment.png',
                  width: 20,
                  height: 20,
                  color: Colors.blue,
                ),
                const SizedBox(width: 4),
                Text('$commentCount'),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'امتیاز: $engagementScore',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // تاریخ ایجاد
            Text(
              'تاریخ: ${_formatDate(createdAt)}',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date is String) {
      return DateTime.parse(date).toString().substring(0, 16);
    } else if (date is DateTime) {
      return date.toString().substring(0, 16);
    }
    return 'نامشخص';
  }
}
