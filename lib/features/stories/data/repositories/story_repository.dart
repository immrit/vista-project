import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/const.dart';
import '../../../../security/logging_utility.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../../core/story_enums.dart';
import '../services/story_upload_service.dart';

/// پیاده‌سازی Repository استوری با Supabase
class StoryRepository implements IStoryRepository {
  final SupabaseClient _client;

  StoryRepository() : _client = supabase;

  // ========== دریافت استوری‌ها ==========

  @override
  Future<StoryResult<List<StoryUser>>> getActiveStories() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // دریافت لیست فالو شده‌ها (جدول follows)
      final followingResponse = await _client
          .from('follows')
          .select('following_id')
          .eq('follower_id', currentUserId);

      final followingIds = List<String>.from(
        followingResponse.map((row) => row['following_id']),
      );

      // دریافت استوری‌ها با query ساده‌تر
      final storiesResponse = await _client.from('stories').select('''
        id,
        user_id,
        media_url,
        media_type,
        thumbnail_url,
        caption,
        created_at,
        expires_at,
        profiles!inner(username, avatar_url, is_verified, role, verification_type)
      ''').order('created_at', ascending: true);

      // دریافت بازدیدهای کاربر فعلی
      Set<String> viewedStoryIds = {};
      try {
        final viewsResponse = await _client
            .from('story_views')
            .select('story_id')
            .eq('viewer_id', currentUserId);
        viewedStoryIds = Set<String>.from(
          viewsResponse.map((row) => row['story_id'] as String),
        );
      } catch (_) {
        // جدول story_views ممکن است وجود نداشته باشد
      }

      // گروه‌بندی بر اساس کاربر
      final usersMap = <String, StoryUser>{};

      for (final item in storiesResponse) {
        final storyUserId = item['user_id'] as String;

        // فقط استوری‌های خود کاربر و فالو شده‌ها
        if (storyUserId != currentUserId &&
            !followingIds.contains(storyUserId)) {
          continue;
        }

        final storyId = item['id'] as String;
        final isViewed = viewedStoryIds.contains(storyId);

        final story = Story.fromMap(item, isViewed: isViewed);

        // Skip expired stories
        if (story.isExpired) continue;

        final profile = item['profiles'] as Map<String, dynamic>;

        usersMap.update(
          storyUserId,
          (user) => user.copyWith(
            stories: [...user.stories, story],
          ),
          ifAbsent: () => StoryUser.fromMap({
            'user_id': storyUserId,
            'username': profile['username'],
            'avatar_url': profile['avatar_url'],
            'is_verified': profile['is_verified'],
            'role': profile['role'],
            'verification_type': profile['verification_type'],
            'last_story_at': story.createdAt.toIso8601String(),
          }, stories: [
            story
          ]),
        );
      }

      // مرتب‌سازی: کاربر فعلی اول، سپس بر اساس استوری‌های دیده نشده
      final sortedUsers = usersMap.values.toList()
        ..sort((a, b) {
          if (a.id == currentUserId) return -1;
          if (b.id == currentUserId) return 1;
          if (a.hasUnseenStories && !b.hasUnseenStories) return -1;
          if (!a.hasUnseenStories && b.hasUnseenStories) return 1;
          return (b.lastStoryAt ?? DateTime(0))
              .compareTo(a.lastStoryAt ?? DateTime(0));
        });

      return StoryResult.success(sortedUsers);
    } catch (e) {
      logInfo('خطا در دریافت استوری‌ها: $e');
      return StoryResult.failure('خطا در دریافت استوری‌ها');
    }
  }

  @override
  Future<StoryResult<List<Story>>> getUserStories(String userId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;

      final response = await _client
          .from('stories')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      // دریافت وضعیت بازدید
      Set<String> viewedIds = {};
      if (currentUserId != null) {
        final viewsResponse = await _client
            .from('story_views')
            .select('story_id')
            .eq('viewer_id', currentUserId);
        viewedIds = Set.from(viewsResponse.map((r) => r['story_id']));
      }

      final stories = response
          .map((item) =>
              Story.fromMap(item, isViewed: viewedIds.contains(item['id'])))
          .where((s) => !s.isExpired)
          .toList();

      return StoryResult.success(stories);
    } catch (e) {
      logInfo('خطا در دریافت استوری‌های کاربر: $e');
      return StoryResult.failure('خطا در دریافت استوری‌ها');
    }
  }

  @override
  Future<StoryResult<Story>> getStoryById(String storyId) async {
    try {
      final response =
          await _client.from('stories').select('*').eq('id', storyId).single();

      return StoryResult.success(Story.fromMap(response));
    } catch (e) {
      logInfo('خطا در دریافت استوری: $e');
      return StoryResult.failure('استوری یافت نشد');
    }
  }

  // ========== مدیریت استوری ==========

  @override
  Future<StoryResult<Story>> uploadStory(StoryUploadParams params) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // آپلود رسانه
      final uploadResult = await StoryUploadService.uploadMedia(
        mediaFile: params.mediaFile,
        type: params.mediaType,
      );

      if (uploadResult == null) {
        return StoryResult.failure('خطا در آپلود رسانه');
      }

      // محاسبه زمان انقضا
      final expiresAt =
          DateTime.now().add(Duration(hours: params.duration.hours));

      // ذخیره در دیتابیس
      final storyData = {
        'user_id': currentUserId,
        'media_url': uploadResult.url,
        'media_type': params.mediaType.name,
        'thumbnail_url': uploadResult.thumbnailUrl,
        'caption': params.caption,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'duration_type': params.duration.name,
        'privacy_type': params.privacyType.name,
        // 'allowed_user_ids': params.allowedUserIds, // Column missing in DB
        // 'excluded_user_ids': params.excludedUserIds, // Column missing in DB
        // 'poll': params.poll?.toMap(), // Column missing/Legacy
        // 'link': params.link?.toMap(), // Column missing/Legacy
        // 'location': params.location?.toMap(), // Column missing/Legacy
        // 'mentions': params.mentions?.map((m) => m.toMap()).toList(), // Column missing/Legacy
        // 'music_url': params.musicUrl, // Column likely missing/Legacy
        'interactive_elements':
            params.interactiveElements?.map((e) => e.toJson()).toList(),
      };

      final response =
          await _client.from('stories').insert(storyData).select().single();

      logInfo('استوری ایجاد شد: ${response['id']}');

      return StoryResult.success(Story.fromMap(response));
    } catch (e) {
      logInfo('خطا در ایجاد استوری: $e');
      return StoryResult.failure('خطا در ایجاد استوری');
    }
  }

  @override
  Future<StoryResult<void>> deleteStory(String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // دریافت URL رسانه
      final storyResponse = await _client
          .from('stories')
          .select('media_url, thumbnail_url')
          .eq('id', storyId)
          .eq('user_id', currentUserId)
          .single();

      // حذف از S3
      if (storyResponse['media_url'] != null) {
        await StoryUploadService.deleteMedia(storyResponse['media_url']);
      }
      if (storyResponse['thumbnail_url'] != null) {
        await StoryUploadService.deleteMedia(storyResponse['thumbnail_url']);
      }

      // حذف از دیتابیس
      final deletedStory = await _client
          .from('stories')
          .delete()
          .eq('id', storyId)
          .eq('user_id', currentUserId)
          .select('id')
          .maybeSingle();

      if (deletedStory == null) {
        return StoryResult.failure(
            'حذف استوری انجام نشد. ممکن است استوری وجود نداشته باشد.');
      }

      logInfo('استوری حذف شد: $storyId');
      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در حذف استوری: $e');
      return StoryResult.failure('خطا در حذف استوری');
    }
  }

  @override
  Future<StoryResult<Story>> editStory({
    required String storyId,
    String? caption,
    StoryPrivacyType? privacyType,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final updateData = <String, dynamic>{};
      if (caption != null) updateData['caption'] = caption;
      if (privacyType != null) updateData['privacy_type'] = privacyType.name;

      if (updateData.isEmpty) {
        return StoryResult.failure('هیچ تغییری مشخص نشده است');
      }

      final response = await _client
          .from('stories')
          .update(updateData)
          .eq('id', storyId)
          .eq('user_id', currentUserId)
          .select()
          .single();

      return StoryResult.success(Story.fromMap(response));
    } catch (e) {
      logInfo('خطا در ویرایش استوری: $e');
      return StoryResult.failure('خطا در ویرایش استوری');
    }
  }

  // ========== تعاملات ==========

  @override
  Future<StoryResult<void>> trackView(String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // بررسی بازدید قبلی
      final existingView = await _client
          .from('story_views')
          .select()
          .eq('story_id', storyId)
          .eq('viewer_id', currentUserId)
          .maybeSingle();

      if (existingView != null) {
        return StoryResult.success(null);
      }

      await _client.from('story_views').insert({
        'story_id': storyId,
        'viewer_id': currentUserId,
        'viewed_at': DateTime.now().toIso8601String(),
      });

      // افزایش شمارنده بازدید (اگر تابع وجود داشته باشد)
      try {
        await _client
            .rpc('increment_story_views', params: {'story_id': storyId});
      } catch (e) {
        // تابع ممکن است در دیتابیس وجود نداشته باشد، نادیده می‌گیریم
        // چون رکورد بازدید در جدول story_views ثبت شده است
        logInfo('RPC increment_story_views skipped: $e');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت بازدید: $e');
      return StoryResult.failure('خطا در ثبت بازدید');
    }
  }

  @override
  Future<StoryResult<List<StoryView>>> getStoryViews(String storyId) async {
    try {
      final response = await _client.from('story_views').select('''
            viewer_id,
            viewed_at,
            profiles!inner(username, avatar_url, is_verified)
          ''').eq('story_id', storyId).order('viewed_at', ascending: false);

      final views = response.map((item) => StoryView.fromMap(item)).toList();

      return StoryResult.success(views);
    } catch (e) {
      logInfo('خطا در دریافت بازدیدکنندگان: $e');
      return StoryResult.failure('خطا در دریافت بازدیدکنندگان');
    }
  }

  @override
  Future<StoryResult<void>> reactToStory(
      String storyId, StoryReactionType reaction) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      /* await _client.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': currentUserId,
        // 'reaction': reaction.name, // Column missing
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'story_id, viewer_id'); */

      // Fallback: Just ensure view is recorded without reaction
      await _client.from('story_views').upsert({
        'story_id': storyId,
        'viewer_id': currentUserId,
        'viewed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'story_id, viewer_id');

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت واکنش: $e');
      return StoryResult.failure('خطا در ثبت واکنش');
    }
  }

  @override
  Future<StoryResult<void>> removeReaction(String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      /* await _client
          .from('story_views')
          .update({'reaction': null})
          .eq('story_id', storyId)
          .eq('viewer_id', currentUserId); */

      logInfo('Reaction removal skipped: Column missing');

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در حذف واکنش: $e');
      return StoryResult.failure('خطا در حذف واکنش');
    }
  }

  @override
  Future<StoryResult<void>> replyToStory(String storyId, String message) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) {
        return StoryResult.failure('متن پاسخ نمی‌تواند خالی باشد');
      }

      final rpcResult = await _client.rpc('send_story_reply', params: {
        'p_story_id': storyId,
        'p_message': trimmedMessage,
      });

      if (rpcResult == null) {
        return StoryResult.failure('ارسال پاسخ انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ارسال پاسخ: $e');
      return StoryResult.failure('خطا در ارسال پاسخ');
    }
  }

  @override
  Future<StoryResult<void>> voteOnPoll(String storyId, String optionId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final voteResult = await _client
          .from('story_poll_votes')
          .upsert({
            'story_id': storyId,
            'user_id': currentUserId,
            'option_id': optionId,
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'story_id, user_id')
          .select('story_id')
          .maybeSingle();

      if (voteResult == null) {
        return StoryResult.failure('ثبت رای انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت رای: $e');
      return StoryResult.failure('خطا در ثبت رای');
    }
  }

  @override
  Future<StoryResult<void>> reportStory(String storyId, String reason) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final reportResult = await _client
          .from('story_reports')
          .insert({
            'story_id': storyId,
            'reporter_id': currentUserId,
            'reason': reason,
            'reported_at': DateTime.now().toIso8601String(),
          })
          .select('story_id')
          .maybeSingle();

      if (reportResult == null) {
        return StoryResult.failure('ثبت گزارش انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت گزارش: $e');
      return StoryResult.failure('خطا در ثبت گزارش');
    }
  }

  // ========== Highlights ==========

  @override
  Future<StoryResult<List<StoryHighlight>>> getUserHighlights(
      String userId) async {
    try {
      final response = await _client
          .from('story_highlights')
          .select('*')
          .eq('user_id', userId)
          .order('order', ascending: true);

      final highlights = <StoryHighlight>[];

      for (final item in response) {
        final storyIds = List<String>.from(item['story_ids'] ?? []);

        // دریافت استوری‌های مربوطه
        final storiesResult = await _getStoriesByIds(storyIds);

        highlights.add(StoryHighlight.fromMap(
          item,
          stories: storiesResult,
        ));
      }

      return StoryResult.success(highlights);
    } catch (e) {
      logInfo('خطا در دریافت هایلایت‌ها: $e');
      return StoryResult.failure('خطا در دریافت هایلایت‌ها');
    }
  }

  Future<List<Story>> _getStoriesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      // استفاده از RPC function برای جلوگیری از محدودیت‌های Supabase
      final response =
          await _client.from('stories').select('*').inFilter('id', ids);

      return response.map((item) => Story.fromMap(item)).toList();
    } catch (e) {
      logInfo('خطا در دریافت استوری‌ها با ID: $e');
      return [];
    }
  }

  @override
  Future<StoryResult<StoryHighlight>> createHighlight(
      HighlightCreateParams params) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final response = await _client
          .from('story_highlights')
          .insert({
            'user_id': currentUserId,
            'title': params.title,
            'cover_url': params.coverUrl,
            'story_ids': params.storyIds,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return StoryResult.success(StoryHighlight.fromMap(response));
    } catch (e) {
      logInfo('خطا در ایجاد هایلایت: $e');
      return StoryResult.failure('خطا در ایجاد هایلایت');
    }
  }

  @override
  Future<StoryResult<StoryHighlight>> editHighlight({
    required String highlightId,
    String? title,
    String? coverUrl,
    List<String>? storyIds,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (title != null) updateData['title'] = title;
      if (coverUrl != null) updateData['cover_url'] = coverUrl;
      if (storyIds != null) updateData['story_ids'] = storyIds;

      final response = await _client
          .from('story_highlights')
          .update(updateData)
          .eq('id', highlightId)
          .eq('user_id', currentUserId)
          .select()
          .single();

      return StoryResult.success(StoryHighlight.fromMap(response));
    } catch (e) {
      logInfo('خطا در ویرایش هایلایت: $e');
      return StoryResult.failure('خطا در ویرایش هایلایت');
    }
  }

  @override
  Future<StoryResult<void>> deleteHighlight(String highlightId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      await _client
          .from('story_highlights')
          .delete()
          .eq('id', highlightId)
          .eq('user_id', currentUserId);

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در حذف هایلایت: $e');
      return StoryResult.failure('خطا در حذف هایلایت');
    }
  }

  @override
  Future<StoryResult<int>> getHighlightCount(String userId) async {
    try {
      final response = await _client
          .from('story_highlights')
          .select('id')
          .eq('user_id', userId);

      return StoryResult.success(response.length);
    } catch (e) {
      logInfo('خطا در دریافت تعداد هایلایت: $e');
      return StoryResult.failure('خطا در دریافت تعداد هایلایت');
    }
  }

  // ========== حریم خصوصی ==========

  @override
  Future<StoryResult<List<StoryUser>>> getFriends({String? query}) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // دریافت لیست فالووینگ
      final followingResponse = await _client
          .from('follows')
          .select('following_id, profiles!following_id(*)')
          .eq('follower_id', currentUserId);

      // تبدیل به لیست StoryUser
      final friends = followingResponse.map((item) {
        final profile = item['profiles'] as Map<String, dynamic>;
        final userId = item['following_id'] as String;

        return StoryUser.fromMap({
          'user_id': userId,
          'username': profile['username'],
          'avatar_url': profile['avatar_url'],
          'is_verified': profile['is_verified'] ?? false,
          'role': profile['role'],
          'verification_type': profile['verification_type'],
          'last_story_at': null, // مهم نیست
        }, stories: []);
      }).toList();

      // فیلتر جستجو
      if (query != null && query.isNotEmpty) {
        final lowerQuery = query.toLowerCase();
        return StoryResult.success(friends
            .where((u) => u.username.toLowerCase().contains(lowerQuery))
            .toList());
      }

      return StoryResult.success(friends);
    } catch (e) {
      logInfo('خطا در دریافت لیست دوستان: $e');
      return StoryResult.failure('خطا در دریافت لیست دوستان');
    }
  }

  @override
  Future<StoryResult<List<String>>> getCloseFriends() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final response = await _client
          .from('close_friends')
          .select('friend_id')
          .eq('user_id', currentUserId);

      final friendIds = List<String>.from(
        response.map((row) => row['friend_id']),
      );

      return StoryResult.success(friendIds);
    } catch (e) {
      logInfo('خطا در دریافت دوستان نزدیک: $e');
      return StoryResult.failure('خطا در دریافت دوستان نزدیک');
    }
  }

  @override
  Future<StoryResult<void>> updateCloseFriends(List<String> userIds) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      // حذف همه و اضافه مجدد
      await _client.from('close_friends').delete().eq('user_id', currentUserId);

      if (userIds.isNotEmpty) {
        final insertData = userIds
            .map((friendId) => {
                  'user_id': currentUserId,
                  'friend_id': friendId,
                  'created_at': DateTime.now().toIso8601String(),
                })
            .toList();

        await _client.from('close_friends').insert(insertData);
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در به‌روزرسانی دوستان نزدیک: $e');
      return StoryResult.failure('خطا در به‌روزرسانی دوستان نزدیک');
    }
  }

  @override
  Future<StoryResult<StoryReplyPermission>> getStoryReplyPermission({
    String? userId,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final targetUserId = userId ?? currentUserId;
      final rpcResult = await _client.rpc(
        'get_story_reply_permission',
        params: {'p_user_id': targetUserId},
      );

      final rawPermission = rpcResult is String ? rpcResult : null;
      final permission = StoryReplyPermission.values.firstWhere(
        (item) => item.name == rawPermission,
        orElse: () => StoryReplyPermission.everyone,
      );

      return StoryResult.success(permission);
    } catch (e) {
      logInfo('خطا در دریافت تنظیمات پاسخ استوری: $e');
      return StoryResult.failure('خطا در دریافت تنظیمات پاسخ استوری');
    }
  }

  @override
  Future<StoryResult<void>> updateStoryReplyPermission(
      StoryReplyPermission permission) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final rpcResult =
          await _client.rpc('set_story_reply_permission', params: {
        'p_permission': permission.name,
      });

      if (rpcResult == false) {
        return StoryResult.failure('به‌روزرسانی تنظیمات پاسخ استوری انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در به‌روزرسانی تنظیمات پاسخ استوری: $e');
      return StoryResult.failure('خطا در به‌روزرسانی تنظیمات پاسخ استوری');
    }
  }

  @override
  Future<StoryResult<bool>> canReplyToStory({
    required String storyId,
    required String ownerId,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      if (currentUserId == ownerId) {
        return StoryResult.success(false);
      }

      final rpcResult = await _client.rpc('can_reply_to_story', params: {
        'p_story_id': storyId,
        'p_owner_id': ownerId,
      });

      if (rpcResult is bool) {
        return StoryResult.success(rpcResult);
      }

      if (rpcResult is num) {
        return StoryResult.success(rpcResult != 0);
      }

      if (rpcResult is String) {
        final normalized = rpcResult.toLowerCase().trim();
        if (normalized == 'true' || normalized == 't' || normalized == '1') {
          return StoryResult.success(true);
        }
        if (normalized == 'false' || normalized == 'f' || normalized == '0') {
          return StoryResult.success(false);
        }
      }

      final permissionResult = await getStoryReplyPermission(userId: ownerId);
      if (!permissionResult.isSuccess || permissionResult.data == null) {
        return StoryResult.success(false);
      }

      final permission = permissionResult.data!;
      if (permission == StoryReplyPermission.off) {
        return StoryResult.success(false);
      }

      if (permission == StoryReplyPermission.everyone) {
        return StoryResult.success(true);
      }

      final followRelation = await _client
          .from('follows')
          .select('follower_id')
          .eq('follower_id', ownerId)
          .eq('following_id', currentUserId)
          .maybeSingle();
      return StoryResult.success(followRelation != null);
    } catch (e) {
      logInfo('خطا در بررسی اجازه پاسخ به استوری: $e');
      return StoryResult.failure('خطا در بررسی اجازه پاسخ به استوری');
    }
  }
}
