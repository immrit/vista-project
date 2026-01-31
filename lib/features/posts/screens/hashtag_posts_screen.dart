// lib/features/posts/screens/hashtag_posts_screen.dart
//
// صفحه نمایش پست‌های یک هشتگ
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../model/publicPostModel.dart';
import '../../../utils/const.dart';

/// Provider for fetching posts by hashtag
final hashtagPostsProvider =
    FutureProvider.family<List<PublicPostModel>, String>((ref, hashtag) async {
  // Normalize hashtag - remove # if present
  final tag = hashtag.startsWith('#') ? hashtag.substring(1) : hashtag;

  debugPrint('🔍 Searching posts with hashtag: $tag');

  try {
    // Option 1: Use contains operator for array
    // The 'cs' (contains) operator should work with arrays
    // Format: hashtags @> '["tag"]' (PostgreSQL array contains)
    final response = await supabase
        .from('posts')
        .select('''
          *,
          profiles:user_id(
            id,
            username,
            full_name,
            avatar_url,
            is_verified,
            verification_type
          )
        ''')
        .contains('hashtags', [tag]) // Use contains with array
        .order('created_at', ascending: false)
        .limit(50);

    debugPrint('✅ Found ${(response as List).length} posts');
    return response.map((e) => PublicPostModel.fromMap(e)).toList();
  } catch (e, stack) {
    debugPrint('❌ Error fetching hashtag posts: $e');
    debugPrint('Stack: $stack');

    // Try alternative: search in content for #tag
    try {
      debugPrint('🔄 Trying fallback: searching in content');
      final fallbackResponse = await supabase
          .from('posts')
          .select('''
            *,
            profiles:user_id(
              id,
              username,
              full_name,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .ilike('content', '%#$tag%')
          .order('created_at', ascending: false)
          .limit(50);

      debugPrint('✅ Fallback found ${(fallbackResponse as List).length} posts');
      return fallbackResponse.map((e) => PublicPostModel.fromMap(e)).toList();
    } catch (fallbackError) {
      debugPrint('❌ Fallback also failed: $fallbackError');
      rethrow;
    }
  }
});

/// صفحه پست‌های هشتگ
class HashtagPostsScreen extends ConsumerWidget {
  final String hashtag;

  const HashtagPostsScreen({
    super.key,
    required this.hashtag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(hashtagPostsProvider(hashtag));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTag = hashtag.startsWith('#') ? hashtag : '#$hashtag';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: Text(
          displayTag,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: postsAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.tag,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'پستی با این هشتگ یافت نشد',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(hashtagPostsProvider(hashtag));
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return _PostGridItem(post: post, allPosts: posts, index: index);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'خطا در بارگذاری',
                style:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(hashtagPostsProvider(hashtag)),
                child: const Text('تلاش مجدد'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// آیتم گرید پست
class _PostGridItem extends StatelessWidget {
  final PublicPostModel post;
  final List<PublicPostModel> allPosts;
  final int index;

  const _PostGridItem({
    required this.post,
    required this.allPosts,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.imageUrl;

    return GestureDetector(
      onTap: () {
        // Navigate to post detail using the existing route
        Navigator.pushNamed(
          context,
          '/post/detail',
          arguments: {'post': post, 'posts': allPosts, 'initialIndex': index},
        );
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image
          if (imageUrl != null && imageUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey[300],
              ),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            )
          else
            Container(
              color: Colors.grey[300],
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    post.content.length > 50
                        ? '${post.content.substring(0, 50)}...'
                        : post.content,
                    style: const TextStyle(fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

          // Video indicator
          if (post.hasVideo)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
