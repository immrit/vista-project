import '../security/logging_utility.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// دریافت پست‌ها با امتیاز تعامل (با استفاده از VIEW)
  Future<List<Map<String, dynamic>>> getPostsWithEngagement({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('posts_with_engagement')
          .select('*')
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      logInfo('خطا در دریافت پست‌ها: $e');
      rethrow;
    }
  }

  /// دریافت پست‌ها با امتیاز تعامل (بدون VIEW - کوئری مستقیم)
  Future<List<Map<String, dynamic>>> getPostsWithEngagementDirect({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response =
          await _supabase.rpc('get_posts_with_engagement', params: {
        'limit_count': limit,
        'offset_count': offset,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      logInfo('خطا در دریافت پست‌ها: $e');
      rethrow;
    }
  }

  /// دریافت پست‌ها با امتیاز تعامل (روش جایگزین با کوئری بهینه‌سازی شده)
  Future<List<Map<String, dynamic>>> getPostsWithEngagementComplex({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // استفاده از کوئری JOIN بهینه‌سازی شده برای جلوگیری از N+1 query
      final response =
          await _supabase.rpc('get_posts_with_engagement_optimized', params: {
        'limit_count': limit,
        'offset_count': offset,
      });

      final posts = List<Map<String, dynamic>>.from(response);

      // مرتب‌سازی بر اساس امتیاز تعامل
      posts.sort((a, b) {
        final bScore = b['engagement_score'] as int?;
        final aScore = a['engagement_score'] as int?;
        return (bScore ?? 0).compareTo(aScore ?? 0);
      });

      return posts;
    } catch (e) {
      logInfo('خطا در دریافت پست‌ها با روش بهینه‌سازی شده: $e');
      // fallback به روش قدیمی در صورت عدم وجود RPC function
      return await _getPostsWithBatchQueries(limit: limit, offset: offset);
    }
  }

  /// روش کمکی برای دریافت پست‌ها با کوئری‌های دسته‌ای (batch queries)
  Future<List<Map<String, dynamic>>> _getPostsWithBatchQueries({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // دریافت پست‌ها
      final postsResponse = await _supabase
          .from('posts')
          .select('id, content, created_at, user_id, media_url, media_type')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      if (posts.isEmpty) return [];

      // دریافت همه لایک‌ها و کامنت‌ها در یک کوئری دسته‌ای
      final postIds = posts.map((p) => p['id']).toList();

      final [likesResponse, commentsResponse] = await Future.wait([
        _supabase.from('likes').select('post_id').inFilter('post_id', postIds),
        _supabase
            .from('comments')
            .select('post_id')
            .inFilter('post_id', postIds),
      ]);

      // شمارش لایک‌ها و کامنت‌ها برای هر پست
      final likeCounts = <String, int>{};
      final commentCounts = <String, int>{};

      for (final like in likesResponse) {
        final postId = like['post_id'] as String;
        likeCounts[postId] = (likeCounts[postId] ?? 0) + 1;
      }

      for (final comment in commentsResponse) {
        final postId = comment['post_id'] as String;
        commentCounts[postId] = (commentCounts[postId] ?? 0) + 1;
      }

      // ترکیب داده‌ها
      final postsWithEngagement = posts.map((post) {
        final postId = post['id'] as String;
        final likeCount = likeCounts[postId] ?? 0;
        final commentCount = commentCounts[postId] ?? 0;
        final engagementScore = likeCount + commentCount;

        return {
          ...post,
          'like_count': likeCount,
          'comment_count': commentCount,
          'engagement_score': engagementScore,
        };
      }).toList();

      // مرتب‌سازی بر اساس امتیاز تعامل
      postsWithEngagement.sort((a, b) => (b['engagement_score'] as int)
          .compareTo(a['engagement_score'] as int));

      return postsWithEngagement;
    } catch (e) {
      logInfo('خطا در دریافت پست‌ها با روش دسته‌ای: $e');
      rethrow;
    }
  }

  /// دریافت هشتگ‌های ترند
  Future<List<String>> getTrendingTags({int limit = 10}) async {
    try {
      final response = await _supabase.rpc('get_trending_tags', params: {
        'limit_count': limit,
      });

      if (response == null) return [];

      final List<dynamic> data = response as List<dynamic>;
      return data.map((tag) => tag['tag'] as String).toList();
    } catch (e) {
      logInfo('خطا در دریافت هشتگ‌های ترند: $e');
      return [];
    }
  }
}
