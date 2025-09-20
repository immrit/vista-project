import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/CommentModel.dart';

class CommentRepository {
  final SupabaseClient _client;

  CommentRepository(this._client);

  // دریافت کامنت‌های یک پست
  Future<List<CommentModel>> getComments({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .eq('parent_comment_id', 'null')
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit - 1);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌ها: $e');
    }
  }

  // دریافت پاسخ‌های یک کامنت
  Future<List<CommentModel>> getReplies(String parentCommentId) async {
    try {
      // اول، دریافت همه پاسخ‌های مستقیم برای این کامنت
      final response = await _client
          .from('comments')
          .select('''
          *,
          profiles:user_id (
            username,
            avatar_url,
            is_verified,
            verification_type
          )
        ''')
          .eq('parent_comment_id', parentCommentId)
          .order('created_at', ascending: true);

      // تبدیل پاسخ‌ها به مدل CommentModel
      List<CommentModel> replies =
          (response as List).map((data) => CommentModel.fromMap(data)).toList();

      // برای هر پاسخ، پاسخ‌های آن را نیز دریافت می‌کنیم (برای پاسخ‌های تو در تو)
      for (int i = 0; i < replies.length; i++) {
        final nestedReplies = await getReplies(replies[i].id);
        if (nestedReplies.isNotEmpty) {
          replies[i] = replies[i].copyWith(replies: nestedReplies);
        }
      }

      return replies;
    } catch (e) {
      print('Error fetching replies: $e');
      throw Exception('خطا در دریافت پاسخ‌ها: $e');
    }
  }

  // اضافه کردن کامنت جدید
  Future<CommentModel> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      final response = await _client.from('comments').insert({
        'post_id': postId,
        'user_id': userId,
        'owner_id': userId,
        'content': content,
        'parent_comment_id': parentCommentId,
      }).select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''').single();

      return CommentModel.fromMap(response);
    } catch (e) {
      throw Exception('خطا در ارسال کامنت: $e');
    }
  }

  // حذف کامنت
  Future<void> deleteComment(String commentId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      await _client
          .from('comments')
          .delete()
          .eq('id', commentId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('خطا در حذف کامنت: $e');
    }
  }

  // ویرایش کامنت
  Future<CommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      final response = await _client
          .from('comments')
          .update({'content': content})
          .eq('id', commentId)
          .eq('user_id', userId)
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .single();

      return CommentModel.fromMap(response);
    } catch (e) {
      throw Exception('خطا در ویرایش کامنت: $e');
    }
  }

  // شمارش کامنت‌های یک پست - ساده شده برای v2.9.0
  Future<int> getCommentsCount(String postId) async {
    try {
      final response =
          await _client.from('comments').select('id').eq('post_id', postId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // جستجو در کامنت‌ها
  Future<List<CommentModel>> searchComments({
    required String postId,
    required String query,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .ilike('content', '%$query%')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در جستجو: $e');
    }
  }

  // دریافت کامنت‌های اخیر کاربر
  Future<List<CommentModel>> getUserRecentComments({
    required String userId,
    int limit = 10,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌های کاربر: $e');
    }
  }

  // دریافت کامنت‌ها با pagination بهبود یافته
  Future<({List<CommentModel> comments, bool hasMore})>
      getCommentsWithPagination({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      // دریافت یک آیتم اضافی برای بررسی hasMore
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .isFilter('parent_comment_id', null)
          .order('created_at', ascending: false)
          .range(page * limit, (page + 1) * limit); // یک آیتم اضافی

      final allResults =
          (response as List).map((data) => CommentModel.fromMap(data)).toList();

      // بررسی hasMore
      final hasMore = allResults.length > limit;
      final comments = hasMore ? allResults.take(limit).toList() : allResults;

      return (comments: comments, hasMore: hasMore);
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌ها: $e');
    }
  }

  // دریافت آخرین کامنت‌های یک پست
  Future<List<CommentModel>> getLatestComments(String postId,
      {int limit = 5}) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت آخرین کامنت‌ها: $e');
    }
  }

  // بررسی اینکه آیا کاربر کامنتی داده یا نه
  Future<bool> hasUserCommented({
    required String postId,
    required String userId,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .limit(1);

      return (response as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // دریافت کامنت با شناسه
  Future<CommentModel?> getCommentById(String commentId) async {
    try {
      final response = await _client.from('comments').select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''').eq('id', commentId).single();

      return CommentModel.fromMap(response);
    } catch (e) {
      return null;
    }
  }

  // تبدیل کامنت به thread (اضافه کردن پاسخ‌ها)
  Future<List<CommentModel>> getCommentThread(String commentId) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .or('id.eq.$commentId,parent_comment_id.eq.$commentId')
          .order('created_at', ascending: true);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت thread کامنت: $e');
    }
  }

  Future<List<CommentModel>> getCommentsWithReplies({
    required String postId,
    int page = 0,
    int limit = 1000, // مقدار بزرگ برای گرفتن همه کامنت‌ها
  }) async {
    try {
      final response = await _client.from('comments').select('''
      *,
      profiles:user_id (
        username,
        avatar_url,
        is_verified,
        verification_type
      )
    ''').eq('post_id', postId).order('created_at', ascending: false);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌ها: $e');
    }
  }

  // دریافت کامنت‌های یک پست به همراه تعداد پاسخ‌ها
  Future<List<CommentModel>> getCommentsWithRepliesCount({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    try {
      // ابتدا کامنت‌های اصلی را دریافت کنیم
      final mainComments = await getComments(
        postId: postId,
        page: page,
        limit: limit,
      );

      // سپس برای هر کامنت، تعداد پاسخ‌ها را دریافت کنیم
      for (int i = 0; i < mainComments.length; i++) {
        final repliesCount = await _getRepliesCount(mainComments[i].id);
        // می‌توانید این اطلاعات را در مدل ذخیره کنید
        // یا آن را به عنوان metadata نگه دارید
      }

      return mainComments;
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌ها همراه تعداد پاسخ: $e');
    }
  }

  // متد کمکی برای شمارش پاسخ‌ها
  Future<int> _getRepliesCount(String commentId) async {
    try {
      final response = await _client
          .from('comments')
          .select('id')
          .eq('parent_comment_id', commentId);

      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // دریافت کامنت‌های محبوب (اگر فیلد likes داشته باشید)
  Future<List<CommentModel>> getPopularComments({
    required String postId,
    int limit = 10,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .isFilter('parent_comment_id', null)
          // .order('likes_count', ascending: false) // اگر فیلد likes دارید
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌های محبوب: $e');
    }
  }

  // تنظیم وضعیت پین کامنت (اگر فیلد is_pinned داشته باشید)
  Future<bool> pinComment(String commentId, bool isPinned) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('کاربر وارد نشده است');
      }

      await _client
          .from('comments')
          .update({'is_pinned': isPinned}).eq('id', commentId);

      return true;
    } catch (e) {
      return false;
    }
  }

  // دریافت کامنت‌های پین شده
  Future<List<CommentModel>> getPinnedComments(String postId) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .eq('is_pinned', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌های پین شده: $e');
    }
  }

  // دریافت کامنت‌های تو در تو
  Future<List<CommentModel>> getNestedComments(String postId) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .neq('parent_comment_id', 'null')
          .order('created_at', ascending: true);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌های تو در تو: $e');
    }
  }

  // دریافت کامنت‌ها بر اساس بازه زمانی
  Future<List<CommentModel>> getCommentsByDateRange({
    required String postId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            profiles:user_id (
              username,
              avatar_url,
              is_verified,
              verification_type
            )
          ''')
          .eq('post_id', postId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: true);

      return (response as List)
          .map((data) => CommentModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('خطا در دریافت کامنت‌ها بر اساس بازه زمانی: $e');
    }
  }

  Future<CommentModel?> getCurrentUserProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('profiles')
          .select('*, verification_type, is_verified')
          .eq('id', userId)
          .single();

      return CommentModel.fromMap(response);
    } catch (e) {
      print('Error getting current user profile: $e');
      return null;
    }
  }
}
