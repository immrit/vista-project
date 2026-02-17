import 'dart:convert';

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

      final rpcUsers = await _tryGetActiveStoriesViaRpc(
        currentUserId: currentUserId,
      );
      if (rpcUsers != null) {
        return StoryResult.success(rpcUsers);
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
        interactive_elements,
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
      final storyData = <String, dynamic>{
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
      };
      storyData['interactive_elements'] =
          (params.interactiveElements ?? const [])
              .map((e) => e.toJson())
              .toList(growable: false);

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

      try {
        await _client.rpc('track_story_view', params: {
          'p_story_id': storyId,
        });
        return StoryResult.success(null);
      } catch (e) {
        logInfo('RPC track_story_view fallback to legacy: $e');
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
      try {
        final rpcResult = await _client.rpc(
          'get_story_views_with_reactions',
          params: {'p_story_id': storyId},
        );

        final list = _asList(rpcResult);
        if (list != null) {
          final views = list
              .map((item) {
                final map = _asMap(item);
                if (map == null) return null;

                return StoryView(
                  viewerId: map['viewer_id']?.toString() ?? '',
                  viewerUsername: map['username']?.toString(),
                  viewerAvatarUrl: map['avatar_url']?.toString(),
                  isVerified: _asBool(map['is_verified']),
                  verificationType: map['verification_type']?.toString(),
                  role: map['role']?.toString(),
                  viewedAt: DateTime.tryParse(
                        map['viewed_at']?.toString() ?? '',
                      ) ??
                      DateTime.now(),
                  reaction: _parseStoryReaction(map['reaction']?.toString()),
                );
              })
              .whereType<StoryView>()
              .toList();

          return StoryResult.success(views);
        }
      } catch (e) {
        logInfo('RPC get_story_views_with_reactions fallback to legacy: $e');
      }

      final response = await _client.from('story_views').select('''
            viewer_id,
            viewed_at,
            profiles!inner(username, avatar_url, is_verified, verification_type, role)
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

      try {
        await _client.rpc('set_story_reaction', params: {
          'p_story_id': storyId,
          'p_reaction': reaction.name,
        });
        return StoryResult.success(null);
      } catch (e) {
        logInfo('RPC set_story_reaction fallback to legacy: $e');
      }

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

      try {
        await _client.rpc('remove_story_reaction', params: {
          'p_story_id': storyId,
        });
        return StoryResult.success(null);
      } catch (e) {
        logInfo('RPC remove_story_reaction fallback to legacy: $e');
      }

      logInfo('Reaction removal skipped: Column missing');

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در حذف واکنش: $e');
      return StoryResult.failure('خطا در حذف واکنش');
    }
  }

  @override
  Future<StoryResult<void>> replyToStory(
    String storyId,
    String message, {
    Map<String, dynamic>? replyMeta,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) {
        return StoryResult.failure('متن پاسخ نمی‌تواند خالی باشد');
      }

      final params = <String, dynamic>{
        'p_story_id': storyId,
        'p_message': trimmedMessage,
      };
      if (replyMeta != null && replyMeta.isNotEmpty) {
        params['p_reply_meta'] = replyMeta;
      }

      final rpcResult = await _client.rpc('send_story_reply', params: params);

      if (rpcResult == null) {
        return StoryResult.failure('ارسال پاسخ انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ارسال پاسخ: $e');
      return StoryResult.failure(
        _mapStoryRpcError(
          e,
          fallback: 'خطا در ارسال پاسخ',
        ),
      );
    }
  }

  @override
  Future<StoryResult<void>> voteOnPoll({
    required String storyId,
    required String elementId,
    required int optionIndex,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final voteResult = await _client.rpc('vote_story_poll', params: {
        'p_story_id': storyId,
        'p_element_id': elementId,
        'p_option_index': optionIndex,
      });

      if (voteResult == null) {
        return StoryResult.failure('ثبت رای انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت رای: $e');
      return StoryResult.failure(
        _mapStoryRpcError(
          e,
          fallback: 'خطا در ثبت رای',
        ),
      );
    }
  }

  @override
  Future<StoryResult<StoryPollResult>> getPollResults({
    required String storyId,
    required String elementId,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final rpcResult = await _client.rpc('get_story_poll_results', params: {
        'p_story_id': storyId,
        'p_element_id': elementId,
      });

      if (rpcResult == null) {
        return StoryResult.failure('دریافت نتایج نظرسنجی انجام نشد');
      }

      final payload = _asMap(rpcResult);
      if (payload == null) {
        return StoryResult.failure('فرمت نتایج نظرسنجی نامعتبر است');
      }

      return StoryResult.success(StoryPollResult.fromMap(payload));
    } catch (e) {
      logInfo('خطا در دریافت نتایج نظرسنجی: $e');
      return StoryResult.failure(
        _mapStoryRpcError(
          e,
          fallback: 'خطا در دریافت نتایج نظرسنجی',
        ),
      );
    }
  }

  @override
  Future<StoryResult<void>> submitQuestionAnswer({
    required String storyId,
    required String elementId,
    required String answer,
  }) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final trimmedAnswer = answer.trim();
      if (trimmedAnswer.isEmpty) {
        return StoryResult.failure('پاسخ نمی‌تواند خالی باشد');
      }

      final rpcResult =
          await _client.rpc('submit_story_question_answer', params: {
        'p_story_id': storyId,
        'p_element_id': elementId,
        'p_answer': trimmedAnswer,
      });

      if (rpcResult == null) {
        return StoryResult.failure('ثبت پاسخ انجام نشد');
      }

      return StoryResult.success(null);
    } catch (e) {
      logInfo('خطا در ثبت پاسخ سوال: $e');
      return StoryResult.failure(
        _mapStoryRpcError(
          e,
          fallback: 'خطا در ثبت پاسخ سوال',
        ),
      );
    }
  }

  @override
  Future<StoryResult<List<StoryQuestionAnswer>>> getStoryQuestionAnswers(
      String storyId) async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }

      final rpcResult = await _client
          .rpc('get_story_question_answers', params: {'p_story_id': storyId});

      final list = _asList(rpcResult);
      if (list == null) {
        return StoryResult.success(const []);
      }

      final answers = list
          .map((item) {
            final map = _asMap(item);
            if (map == null) return null;
            return StoryQuestionAnswer.fromMap(map);
          })
          .whereType<StoryQuestionAnswer>()
          .toList();

      return StoryResult.success(answers);
    } catch (e) {
      logInfo('خطا در دریافت پاسخ‌های سوال: $e');
      return StoryResult.failure(
        _mapStoryRpcError(
          e,
          fallback: 'خطا در دریافت پاسخ‌های سوال',
        ),
      );
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

  Future<List<StoryUser>?> _tryGetActiveStoriesViaRpc({
    required String currentUserId,
  }) async {
    try {
      final rpcResult = await _client.rpc(
        'get_active_stories_feed',
        params: {'p_limit': 500},
      );

      final rows = _asList(rpcResult);
      if (rows == null) return null;

      final usersMap = <String, StoryUser>{};

      for (final rawRow in rows) {
        final row = _asMap(rawRow);
        if (row == null) continue;

        final storyUserId = row['user_id']?.toString() ?? '';
        if (storyUserId.isEmpty) continue;

        final storyMap = <String, dynamic>{
          'id': row['id'],
          'user_id': storyUserId,
          'media_url': row['media_url'],
          'media_type': row['media_type'],
          'thumbnail_url': row['thumbnail_url'],
          'caption': row['caption'],
          'created_at': row['created_at'],
          'expires_at': row['expires_at'],
          'interactive_elements': row['interactive_elements'],
          'views_count': row['views_count'] ?? 0,
          'reactions_count': row['reactions_count'] ?? 0,
        };

        final story = Story.fromMap(
          storyMap,
          isViewed: _asBool(row['is_viewed']),
        );
        if (story.isExpired) continue;

        final profileMap = <String, dynamic>{
          'user_id': storyUserId,
          'username': row['username']?.toString() ?? '',
          'avatar_url': row['avatar_url'],
          'is_verified': _asBool(row['is_verified']),
          'role': row['role'],
          'verification_type': row['verification_type'],
          'last_story_at': story.createdAt.toIso8601String(),
        };

        usersMap.update(
          storyUserId,
          (existing) => existing.copyWith(
            stories: [...existing.stories, story],
          ),
          ifAbsent: () => StoryUser.fromMap(profileMap, stories: [story]),
        );
      }

      final sortedUsers = usersMap.values.toList()
        ..sort((a, b) {
          if (a.id == currentUserId) return -1;
          if (b.id == currentUserId) return 1;
          if (a.hasUnseenStories && !b.hasUnseenStories) return -1;
          if (!a.hasUnseenStories && b.hasUnseenStories) return 1;
          return (b.lastStoryAt ?? DateTime(0))
              .compareTo(a.lastStoryAt ?? DateTime(0));
        });

      return sortedUsers;
    } catch (e) {
      logInfo('RPC get_active_stories_feed fallback to legacy: $e');
      return null;
    }
  }

  StoryReactionType? _parseStoryReaction(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final reaction in StoryReactionType.values) {
      if (reaction.name.toLowerCase() == normalized) {
        return reaction;
      }
    }
    return null;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == 't' || normalized == '1';
    }
    return false;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<dynamic>? _asList(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _mapStoryRpcError(
    Object error, {
    required String fallback,
  }) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('story_not_found')) {
      return 'استوری مورد نظر یافت نشد';
    }
    if (raw.contains('question_answer_already_submitted')) {
      return 'پاسخ شما قبلا ثبت شده است';
    }
    if (raw.contains('not_story_owner')) {
      return 'فقط صاحب استوری به این بخش دسترسی دارد';
    }
    if (raw.contains('question_sticker_not_found')) {
      return 'سوال مورد نظر یافت نشد';
    }
    if (raw.contains('poll_sticker_not_found')) {
      return 'نظرسنجی مورد نظر یافت نشد';
    }
    if (raw.contains('poll_vote_locked')) {
      return 'رای شما قبلا ثبت شده و قابل تغییر نیست';
    }
    if (raw.contains('invalid_poll_option')) {
      return 'گزینه انتخابی معتبر نیست';
    }
    if (raw.contains('question_answer_empty')) {
      return 'پاسخ نمی‌تواند خالی باشد';
    }
    if (raw.contains('empty_story_reply_message')) {
      return 'متن پاسخ نمی‌تواند خالی باشد';
    }
    if (raw.contains('story_expired')) {
      return 'این استوری منقضی شده است';
    }
    if (raw.contains('story_reply_not_allowed')) {
      return 'ارسال پاسخ برای این استوری مجاز نیست';
    }
    if (raw.contains('authentication_required')) {
      return 'برای انجام این عملیات باید وارد شوید';
    }
    return fallback;
  }
}
