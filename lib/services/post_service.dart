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
      print('خطا در دریافت پست‌ها: $e');
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
      print('خطا در دریافت پست‌ها: $e');
      rethrow;
    }
  }

  /// دریافت پست‌ها با امتیاز تعامل (روش جایگزین با کوئری پیچیده)
  Future<List<Map<String, dynamic>>> getPostsWithEngagementComplex({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // ابتدا پست‌ها را دریافت می‌کنیم
      final postsResponse = await _supabase
          .from('posts')
          .select('*')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final posts = List<Map<String, dynamic>>.from(postsResponse);
      final List<Map<String, dynamic>> postsWithEngagement = [];

      // برای هر پست، تعداد لایک و کامنت را دریافت می‌کنیم
      for (final post in posts) {
        final postId = post['id'];

        // دریافت تعداد لایک‌ها
        final likesResponse =
            await _supabase.from('likes').select('id').eq('post_id', postId);

        // دریافت تعداد کامنت‌ها
        final commentsResponse =
            await _supabase.from('comments').select('id').eq('post_id', postId);

        final likeCount = likesResponse.length;
        final commentCount = commentsResponse.length;
        final engagementScore = likeCount + commentCount;

        postsWithEngagement.add({
          ...post,
          'like_count': likeCount,
          'comment_count': commentCount,
          'engagement_score': engagementScore,
        });
      }

      // مرتب‌سازی بر اساس امتیاز تعامل
      postsWithEngagement.sort((a, b) => (b['engagement_score'] as int)
          .compareTo(a['engagement_score'] as int));

      return postsWithEngagement;
    } catch (e) {
      print('خطا در دریافت پست‌ها: $e');
      rethrow;
    }
  }
}
