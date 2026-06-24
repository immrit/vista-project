import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../../../../security/logging_utility.dart';
import '../../../../services/device_id_service.dart';
import '../../../../services/system_status_service.dart';
import '../../../auth/providers/auth_controller.dart';
import '../../core/story_enums.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/i_story_repository.dart';
import '../services/story_upload_service.dart';

class StoryRepository implements IStoryRepository {
  StoryRepository() {
    _dio = Dio(
      BaseOptions(
        baseUrl: '$_backendUrl/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'X-Device-ID': DeviceIdService.id,
        },
      ),
    );
  }

  late final Dio _dio;

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  @override
  Future<StoryResult<List<StoryUser>>> getActiveStories() async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.stories,
      );
      final response =
          await _dio.get('/stories/active', options: await _authOptions());
      final users = _asList(_asMap(response.data)['users']);
      final mapped = users
          .whereType<Map>()
          .map((raw) {
            final map = raw.cast<String, dynamic>();
            final stories = _asList(map['stories'])
                .whereType<Map>()
                .map((story) => _storyFromGo(story.cast<String, dynamic>()))
                .where((story) => !story.isExpired)
                .toList(growable: false);
            return StoryUser.fromMap(map, stories: stories);
          })
          .where((user) => user.stories.isNotEmpty)
          .toList(growable: false);
      return StoryResult.success(mapped);
    } catch (e, st) {
      logError('Failed to load Go stories', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت استوری‌ها');
    }
  }

  @override
  Future<StoryResult<List<Story>>> getUserStories(String userId) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.stories,
      );
      final response = await _dio.get('/stories/users/$userId',
          options: await _authOptions());
      final stories = _asList(_asMap(response.data)['stories'])
          .whereType<Map>()
          .map((item) => _storyFromGo(item.cast<String, dynamic>()))
          .where((story) => !story.isExpired)
          .toList(growable: false);
      return StoryResult.success(stories);
    } catch (e, st) {
      logError('Failed to load user stories', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت استوری‌های کاربر');
    }
  }

  @override
  Future<StoryResult<Story>> getStoryById(String storyId) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.stories,
      );
      final response =
          await _dio.get('/stories/$storyId', options: await _authOptions());
      return StoryResult.success(_storyFromGo(_asMap(response.data)));
    } catch (e, st) {
      logError('Failed to load story', error: e, stackTrace: st);
      return StoryResult.failure('استوری یافت نشد');
    }
  }

  @override
  Future<StoryResult<Story>> uploadStory(StoryUploadParams params) async {
    try {
      await SystemStatusService.instance.ensureFeatureEnabled(
        SystemFeature.stories,
        forceRefresh: true,
      );
      final uploadResult = await StoryUploadService.uploadMedia(
        mediaFile: params.mediaFile,
        type: params.mediaType,
      );
      if (uploadResult == null) {
        return StoryResult.failure('خطا در آپلود رسانه');
      }

      final response = await _dio.post(
        '/stories',
        data: {
          'media_url': uploadResult.url,
          'media_type': params.mediaType.name,
          if (uploadResult.thumbnailUrl != null)
            'thumbnail_url': uploadResult.thumbnailUrl,
          if (params.caption != null) 'caption': params.caption,
          'duration_type': params.duration.name,
          'privacy_type': _privacyToGo(params.privacyType),
          'allowed_user_ids': params.allowedUserIds ?? const <String>[],
          'excluded_user_ids': params.excludedUserIds ?? const <String>[],
          'interactive_elements': (params.interactiveElements ?? const [])
              .map((element) => element.toJson())
              .toList(growable: false),
          if (params.musicUrl != null) 'music_url': params.musicUrl,
        },
        options: await _authOptions(),
      );
      return StoryResult.success(_storyFromGo(_asMap(response.data)));
    } catch (e, st) {
      logError('Failed to create story', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ایجاد استوری');
    }
  }

  @override
  Future<StoryResult<void>> deleteStory(String storyId) async {
    try {
      await _dio.delete('/stories/$storyId', options: await _authOptions());
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to delete story', error: e, stackTrace: st);
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
      final response = await _dio.patch(
        '/stories/$storyId',
        data: {
          if (caption != null) 'caption': caption,
          if (privacyType != null) 'privacy_type': _privacyToGo(privacyType),
        },
        options: await _authOptions(),
      );
      return StoryResult.success(_storyFromGo(_asMap(response.data)));
    } catch (e, st) {
      logError('Failed to edit story', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ویرایش استوری');
    }
  }

  @override
  Future<StoryResult<void>> trackView(String storyId) async {
    try {
      await _dio.post('/stories/$storyId/view', options: await _authOptions());
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to track story view', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ثبت بازدید');
    }
  }

  @override
  Future<StoryResult<List<StoryView>>> getStoryViews(String storyId, {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get('/stories/$storyId/views',
          queryParameters: {'limit': limit, 'offset': offset},
          options: await _authOptions());
      final views = _asList(_asMap(response.data)['views'])
          .whereType<Map>()
          .map((item) => StoryView.fromMap(item.cast<String, dynamic>()))
          .toList(growable: false);
      return StoryResult.success(views);
    } catch (e, st) {
      logError('Failed to load story views', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت بازدیدها');
    }
  }

  @override
  Future<StoryResult<void>> reactToStory(
    String storyId,
    StoryReactionType reaction,
  ) async {
    try {
      await _dio.post(
        '/stories/$storyId/reaction',
        data: {'reaction': reaction.name},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to react to story', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ثبت واکنش');
    }
  }

  @override
  Future<StoryResult<void>> removeReaction(String storyId) async {
    try {
      await _dio.delete('/stories/$storyId/reaction',
          options: await _authOptions());
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to remove story reaction', error: e, stackTrace: st);
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
      await _dio.post(
        '/stories/$storyId/reply',
        data: {
          'message': message.trim(),
          if (replyMeta != null && replyMeta.isNotEmpty) 'metadata': replyMeta,
        },
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } on DioException catch (e, st) {
      logError('Failed to reply to story', error: e, stackTrace: st);
      final msg = _dioErrorMessage(e) ?? 'خطا در ارسال پاسخ';
      return StoryResult.failure(msg);
    } catch (e, st) {
      logError('Failed to reply to story', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ارسال پاسخ');
    }
  }

  String? _dioErrorMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString();
      }
    }
    return null;
  }

  @override
  Future<StoryResult<void>> reportStory(String storyId, String reason) async {
    try {
      await _dio.post(
        '/stories/$storyId/report',
        data: {'reason': reason},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to report story', error: e, stackTrace: st);
      return StoryResult.failure('خطا در گزارش استوری');
    }
  }

  @override
  Future<StoryResult<void>> voteOnPoll({
    required String storyId,
    required String elementId,
    required int optionIndex,
  }) async {
    try {
      await _dio.post(
        '/stories/$storyId/poll/$elementId/vote',
        data: {'option_index': optionIndex},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to vote on poll', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ثبت رای');
    }
  }

  @override
  Future<StoryResult<StoryPollResult>> getPollResults({
    required String storyId,
    required String elementId,
  }) async {
    try {
      final response = await _dio.get(
        '/stories/$storyId/poll/$elementId',
        options: await _authOptions(),
      );
      final data = _asMap(response.data);
      final total = data['total_votes'] as int? ?? 0;
      return StoryResult.success(
        StoryPollResult(
          storyId: data['story_id'] ?? storyId,
          elementId: data['element_id'] ?? elementId,
          question:
              '', // Go backend doesn't store the question string in votes table
          totalVotes: total,
          userOptionIndex: data['user_option'] as int?,
          options: ((data['options'] as List?)?.cast<int>() ?? const [])
              .asMap()
              .entries
              .map((e) {
            final count = e.value;
            final percentage = total > 0 ? (count / total) * 100 : 0.0;
            return StoryPollOptionResult(
              optionIndex: e.key,
              text: '',
              votes: count,
              percentage: percentage,
            );
          }).toList(),
        ),
      );
    } catch (e, st) {
      logError('Failed to get poll results', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت نتایج نظرسنجی');
    }
  }

  @override
  Future<StoryResult<void>> submitQuestionAnswer({
    required String storyId,
    required String elementId,
    required String answer,
  }) async {
    try {
      await _dio.post(
        '/stories/$storyId/question/$elementId/answer',
        data: {'answer': answer.trim()},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to answer question', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ثبت پاسخ');
    }
  }

  @override
  Future<StoryResult<List<StoryQuestionAnswer>>> getStoryQuestionAnswers(
    String storyId,
  ) async {
    try {
      final response = await _dio.get(
        '/stories/$storyId/questions/answers',
        options: await _authOptions(),
      );
      final list = _asList(_asMap(response.data)['answers']);
      final answers = list
          .whereType<Map>()
          .map((item) =>
              StoryQuestionAnswer.fromMap(item.cast<String, dynamic>()))
          .toList(growable: false);
      return StoryResult.success(answers);
    } catch (e, st) {
      logError('Failed to load question answers', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت پاسخ‌ها');
    }
  }

  @override
  Future<StoryResult<List<StoryHighlight>>> getUserHighlights(
    String userId,
  ) async {
    try {
      final response = await _dio.get(
        '/highlights/users/$userId',
        options: await _authOptions(),
      );
      final list = _asList(_asMap(response.data)['highlights']);
      final highlights = list
          .whereType<Map>()
          .map((item) => StoryHighlight.fromMap(item.cast<String, dynamic>()))
          .toList(growable: false);
      return StoryResult.success(highlights);
    } catch (e, st) {
      logError('Failed to load highlights', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت هایلایت‌ها');
    }
  }

  @override
  Future<StoryResult<StoryHighlight>> createHighlight(
    HighlightCreateParams params,
  ) async {
    try {
      final response = await _dio.post(
        '/highlights',
        data: {
          'title': params.title.trim(),
          if (params.coverUrl != null) 'cover_url': params.coverUrl,
          'story_ids': params.storyIds,
        },
        options: await _authOptions(),
      );
      return StoryResult.success(StoryHighlight.fromMap(_asMap(response.data)));
    } catch (e, st) {
      logError('Failed to create highlight', error: e, stackTrace: st);
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
      final response = await _dio.patch(
        '/highlights/$highlightId',
        data: {
          if (title != null) 'title': title.trim(),
          if (coverUrl != null) 'cover_url': coverUrl,
          if (storyIds != null) 'story_ids': storyIds,
        },
        options: await _authOptions(),
      );
      return StoryResult.success(StoryHighlight.fromMap(_asMap(response.data)));
    } catch (e, st) {
      logError('Failed to edit highlight', error: e, stackTrace: st);
      return StoryResult.failure('خطا در ویرایش هایلایت');
    }
  }

  @override
  Future<StoryResult<void>> deleteHighlight(String highlightId) async {
    try {
      await _dio.delete(
        '/highlights/$highlightId',
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to delete highlight', error: e, stackTrace: st);
      return StoryResult.failure('خطا در حذف هایلایت');
    }
  }

  @override
  Future<StoryResult<int>> getHighlightCount(String userId) async {
    try {
      final response = await _dio.get(
        '/highlights/users/$userId/count',
        options: await _authOptions(),
      );
      final count = _asMap(response.data)['count'] as int? ?? 0;
      return StoryResult.success(count);
    } catch (e, st) {
      logError('Failed to load highlight count', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت تعداد هایلایت');
    }
  }

  @override
  Future<StoryResult<List<StoryUser>>> getFriends({String? query}) async {
    try {
      final userId = await TokenStorage.getUserId();
      if (userId == null || userId.isEmpty) {
        return StoryResult.failure('کاربر احراز هویت نشده است');
      }
      final response = await _dio.get(
        '/profiles/following/$userId',
        queryParameters: {'limit': 100, 'offset': 0},
        options: await _authOptions(),
      );
      final rawProfiles = _asList(_asMap(response.data)['profiles']);
      final normalizedQuery = query?.trim().toLowerCase();
      final friends = rawProfiles
          .whereType<Map>()
          .map((item) => StoryUser.fromMap(item.cast<String, dynamic>()))
          .where((user) =>
              normalizedQuery == null ||
              normalizedQuery.isEmpty ||
              user.username.toLowerCase().contains(normalizedQuery))
          .toList(growable: false);
      return StoryResult.success(friends);
    } catch (e, st) {
      logError('Failed to load story friends', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت دوستان');
    }
  }

  @override
  Future<StoryResult<List<String>>> getCloseFriends() async {
    try {
      final response = await _dio.get(
        '/me/close-friends', // This route is under /v1/me, so it needs adjusting since baseUrl is /v1. E.g. _dio.get('/me/close-friends') resolves to /v1/me/close-friends
        options: await _authOptions(),
      );
      final friends = _stringList(response.data);
      return StoryResult.success(friends);
    } catch (e, st) {
      logError('Failed to get close friends', error: e, stackTrace: st);
      return StoryResult.failure('خطا در دریافت دوستان نزدیک');
    }
  }

  @override
  Future<StoryResult<void>> updateCloseFriends(List<String> userIds) async {
    try {
      await _dio.put(
        '/me/close-friends',
        data: {'friend_ids': userIds},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to update close friends', error: e, stackTrace: st);
      return StoryResult.failure('خطا در بروزرسانی دوستان نزدیک');
    }
  }

  @override
  Future<StoryResult<StoryReplyPermission>> getStoryReplyPermission({
    String? userId,
  }) async {
    // This endpoint is for managing the current user's own settings.
    // Use getStoryReplyAccess(storyId) to check a specific story owner's permission.
    try {
      final response = await _dio.get(
        '/me/story-settings',
        options: await _authOptions(),
      );
      final permission = _asMap(response.data)['reply_permission']?.toString();
      return StoryResult.success(_parseReplyPermission(permission));
    } catch (e, st) {
      logError('Failed to get story reply permission',
          error: e, stackTrace: st);
      return StoryResult.success(StoryReplyPermission.everyone);
    }
  }

  /// Checks whether the current viewer can reply to [storyId].
  /// Uses the backend-computed [viewer_can_reply] from the story data when
  /// available, or falls back to the dedicated /reply-access endpoint.
  @override
  Future<StoryResult<({bool canReply, StoryReplyPermission permission})>>
      getStoryReplyAccess(String storyId) async {
    try {
      final response = await _dio.get(
        '/stories/$storyId/reply-access',
        options: await _authOptions(),
      );
      final data = _asMap(response.data);
      final canReply = data['can_reply'] == true;
      final perm = _parseReplyPermission(data['reply_permission']?.toString());
      return StoryResult.success((canReply: canReply, permission: perm));
    } catch (e, st) {
      logError('Failed to get story reply access', error: e, stackTrace: st);
      return StoryResult.success(
          (canReply: true, permission: StoryReplyPermission.everyone));
    }
  }

  @override
  Future<StoryResult<void>> updateStoryReplyPermission(
    StoryReplyPermission permission,
  ) async {
    try {
      await _dio.patch(
        '/me/story-settings',
        data: {'reply_permission': _serializeReplyPermission(permission)},
        options: await _authOptions(),
      );
      return StoryResult.success(null);
    } catch (e, st) {
      logError('Failed to update story reply permission',
          error: e, stackTrace: st);
      return StoryResult.failure('خطا در بروزرسانی تنظیمات پاسخ استوری');
    }
  }

  StoryReplyPermission _parseReplyPermission(String? val) {
    switch (val) {
      case 'none':
        return StoryReplyPermission.off;
      case 'followers':
      case 'close_friends':
        return StoryReplyPermission.following;
      default:
        return StoryReplyPermission.everyone;
    }
  }

  String _serializeReplyPermission(StoryReplyPermission perm) {
    switch (perm) {
      case StoryReplyPermission.off:
        return 'none';
      case StoryReplyPermission.following:
        return 'followers';
      default:
        return 'everyone';
    }
  }

  @override
  Future<StoryResult<bool>> canReplyToStory({
    required String storyId,
    required String ownerId,
  }) async {
    // Delegate to the dedicated reply-access endpoint which checks
    // reply_permission + follow relationship server-side.
    final result = await getStoryReplyAccess(storyId);
    return result.fold(
      (_) => StoryResult.success(false),
      (access) => StoryResult.success(access.canReply),
    );
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Story _storyFromGo(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    map['privacy_type'] = _privacyFromGo(map['privacy_type']?.toString());
    map['allowed_user_ids'] = _stringList(map['allowed_user_ids']);
    map['excluded_user_ids'] = _stringList(map['excluded_user_ids']);
    // viewer_can_reply is computed server-side and returned in the response
    return Story.fromMap(map, isViewed: map['is_viewed'] == true);
  }

  String _privacyToGo(StoryPrivacyType privacyType) {
    switch (privacyType) {
      case StoryPrivacyType.closeFriends:
        return 'close_friends';
      case StoryPrivacyType.contacts:
        return 'followers';
      case StoryPrivacyType.custom:
        return 'custom';
      case StoryPrivacyType.everyone:
        return 'everyone';
    }
  }

  String _privacyFromGo(String? value) {
    switch (value) {
      case 'close_friends':
        return StoryPrivacyType.closeFriends.name;
      case 'followers':
        return StoryPrivacyType.contacts.name;
      case 'custom':
        return StoryPrivacyType.custom.name;
      default:
        return StoryPrivacyType.everyone.name;
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    return const <dynamic>[];
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }
}
