import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/post_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final int _currentPage = 0;

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

            // محاسبه تعداد تبلیغات و ایندکس‌های آن‌ها
            final adInterval = 5; // هر 5 پست یک تبلیغ
            final adCount = (allPosts.length / adInterval).floor();
            final totalItemCount =
                allPosts.length + adCount + 1; // +1 برای loading

            return ListView.builder(
              controller: _scrollController,
              itemCount: totalItemCount,
              itemBuilder: (context, index) {
                // بررسی ایندکس loading
                if (index == totalItemCount - 1) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // محاسبه ایندکس واقعی پست
                final postIndex = _getPostIndex(index, adInterval);
                if (postIndex >= allPosts.length) {
                  return const SizedBox.shrink();
                }

                final post = allPosts[postIndex];
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

  /// بررسی اینکه آیا ایندکس مربوط به تبلیغ است یا نه
  bool _isAdIndex(int index, int adInterval) {
    // تبلیغات در ایندکس‌های 5, 11, 17, ... نمایش داده می‌شوند
    return (index + 1) % (adInterval + 1) == 0;
  }

  /// محاسبه ایندکس واقعی پست با در نظر گیری تبلیغات
  int _getPostIndex(int index, int adInterval) {
    // تعداد تبلیغات قبل از این ایندکس
    final adsBefore = (index + 1) ~/ (adInterval + 1);
    return index - adsBefore;
  }
}

class PostCard extends StatelessWidget {
  final Map<String, dynamic> post;

  const PostCard({super.key, required this.post});

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
