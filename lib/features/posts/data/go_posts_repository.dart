import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../model/publicPostModel.dart';
import '../../../services/device_id_service.dart';
import '../../../services/orphaned_media_cleanup_service.dart';
import '../../../services/system_status_service.dart';
import '../../auth/providers/auth_controller.dart';

final goPostsRepositoryProvider = Provider<GoPostsRepository>((ref) {
  return GoPostsRepository();
});

class LikeResult {
  final bool isLiked;
  final int likeCount;

  const LikeResult({
    required this.isLiked,
    required this.likeCount,
  });

  factory LikeResult.fromJson(Map<String, dynamic> json) {
    return LikeResult(
      isLiked: json['is_liked'] as bool? ?? false,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class HashtagSuggestion {
  final String tag;
  final int usageCount;

  const HashtagSuggestion({
    required this.tag,
    required this.usageCount,
  });

  factory HashtagSuggestion.fromJson(Map<String, dynamic> json) {
    return HashtagSuggestion(
      tag: json['tag']?.toString() ?? '',
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'tag': tag,
        'usage_count': usageCount,
      };
}

class GoPostsRepository {
  static String get _backendUrl => EnvConfig.apiBaseUrl;

  late final Dio _dio;

  GoPostsRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
        'X-Device-ID': DeviceIdService.id,
      },
    ));
  }

  Future<void> _ensureFeedEnabled() {
    return SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.feed,
    );
  }

  Future<List<PublicPostModel>> getFeed({
    int limit = 15,
    dynamic offset = 0,
  }) async {
    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/feed',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _authOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<List<PublicPostModel>> getFollowingFeed({
    int limit = 15,
    dynamic offset = 0,
  }) async {
    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/feed/following',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _authOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<PublicPostModel> getPost(String postId) async {
    final response = await _dio.get(
      '/posts/$postId',
      options: await _authOptions(),
    );
    return _postFromGo(_asMap(response.data));
  }

  Future<List<PublicPostModel>> getUserPosts({
    required String userId,
    int limit = 15,
    dynamic offset = 0,
  }) async {
    final response = await _dio.get(
      '/users/$userId/posts',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _optionalAuthOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<List<PublicPostModel>> getSavedPosts({
    required int limit,
    required dynamic offset,
  }) async {
    final response = await _dio.get(
      '/me/saved',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _authOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<List<PublicPostModel>> exploreFeed({
    int limit = 15,
    dynamic offset = 0,
    bool debug = false,
  }) async {
    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/explore',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (debug) 'debug': 'true',
      },
      options: await _optionalAuthOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<List<PublicPostModel>> searchPostsByHashtag({
    required String hashtag,
    int limit = 15,
    dynamic offset = 0,
  }) async {
    final cleanTag = Uri.encodeComponent(hashtag.replaceAll('#', '').trim());
    if (cleanTag.isEmpty) return const [];
    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/posts/hashtag/$cleanTag',
      queryParameters: {'limit': limit, 'offset': offset},
      options: await _optionalAuthOptions(),
    );
    return _parsePostList(response.data);
  }

  Future<List<HashtagSuggestion>> getTrendingHashtags({
    int limit = 20,
    int days = 30,
  }) async {
    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/hashtags/trending',
      queryParameters: {'limit': limit, 'days': days},
      options: await _optionalAuthOptions(),
    );
    return _parseHashtagSuggestions(response.data);
  }

  Future<List<HashtagSuggestion>> searchHashtags({
    required String keyword,
    int limit = 20,
  }) async {
    final cleanKeyword = keyword.replaceAll('#', '').trim();
    if (cleanKeyword.isEmpty) return const [];

    await _ensureFeedEnabled();
    final response = await _dio.get(
      '/hashtags/search',
      queryParameters: {'q': cleanKeyword, 'limit': limit},
      options: await _optionalAuthOptions(),
    );
    return _parseHashtagSuggestions(response.data);
  }

  Future<PublicPostModel> createPost({
    required String content,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    String? musicUrl,
    String? musicTitle,
    int? musicStartMs,
    int? musicEndMs,
    List<String>? tags,
    bool hideLikeCount = false,
    bool hideCommentCount = false,
  }) async {
    await SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.posts,
      forceRefresh: true,
    );
    final gallery = imageUrls?.where((u) => u.trim().isNotEmpty).toList();
    final response = await _dio.post(
      '/posts',
      data: {
        'content': content,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
        if (gallery != null && gallery.isNotEmpty) 'image_urls': gallery,
        if (videoUrl != null && videoUrl.isNotEmpty) 'video_url': videoUrl,
        if (musicUrl != null && musicUrl.isNotEmpty) 'music_url': musicUrl,
        if (musicTitle != null && musicTitle.isNotEmpty)
          'music_title': musicTitle,
        if (musicStartMs != null) 'music_start_ms': musicStartMs,
        if (musicEndMs != null) 'music_end_ms': musicEndMs,
        'tags': tags ?? const <String>[],
        'hide_like_count': hideLikeCount,
        'hide_comment_count': hideCommentCount,
      },
      options: await _authOptions(),
    );
    return _postFromGo(_asMap(response.data));
  }

  /// Tag users on a post (Instagram-style). Author only; fires `post_mention`
  /// notification + push for each tagged user. No-op when [userIds] is empty.
  Future<void> addPostMentions({
    required String postId,
    required List<String> userIds,
  }) async {
    final normalizedIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) return;

    await _dio.post(
      '/posts/$postId/mentions',
      data: {'user_ids': normalizedIds},
      options: await _authOptions(),
    );
  }

  Future<PublicPostModel> updatePost({
    required String postId,
    String? content,
    bool? hideLikeCount,
    bool? hideCommentCount,
  }) async {
    final payload = <String, dynamic>{};
    if (content != null) payload['content'] = content;
    if (hideLikeCount != null) payload['hide_like_count'] = hideLikeCount;
    if (hideCommentCount != null) {
      payload['hide_comment_count'] = hideCommentCount;
    }

    if (payload.isEmpty) {
      throw ArgumentError('At least one field must be provided for updatePost');
    }

    final response = await _dio.patch(
      '/posts/$postId',
      data: payload,
      options: await _authOptions(),
    );
    return _postFromGo(_asMap(response.data));
  }

  Future<PublicPostModel> updateEngagementVisibility({
    required String postId,
    bool? hideLikeCount,
    bool? hideCommentCount,
  }) async {
    if (hideLikeCount == null && hideCommentCount == null) {
      throw ArgumentError(
        'At least one visibility flag must be provided',
      );
    }
    return updatePost(
      postId: postId,
      hideLikeCount: hideLikeCount,
      hideCommentCount: hideCommentCount,
    );
  }

  Future<Set<String>> getSavedPostIds({
    int limit = 500,
    dynamic offset = 0,
  }) async {
    final ids = <String>{};
    dynamic cursor = offset;
    const pageSize = 30;

    while (ids.length < limit) {
      final page = await getSavedPosts(limit: pageSize, offset: cursor);
      if (page.isEmpty) break;
      ids.addAll(page.map((post) => post.id).where((id) => id.isNotEmpty));
      cursor = page.last.createdAt.toUtc().toIso8601String();
      if (page.length < pageSize) break;
    }

    return ids;
  }

  Future<bool> toggleSave(String postId) async {
    final response = await _dio.post(
      '/posts/save/$postId',
      options: await _authOptions(),
    );
    final data = _asMap(response.data);
    return data['is_saved'] as bool? ?? false;
  }

  Future<bool> setSaved(String postId, bool shouldSave) async {
    var isSaved = await toggleSave(postId);
    if (isSaved == shouldSave) return isSaved;

    isSaved = await toggleSave(postId);
    if (isSaved != shouldSave) {
      throw StateError('Could not sync saved state for post $postId');
    }
    return isSaved;
  }

  Future<LikeResult> toggleLike({
    required String postId,
    required String ownerId,
  }) async {
    final response = await _dio.post(
      '/posts/like/$postId',
      data: {'owner_id': ownerId},
      options: await _authOptions(),
    );
    return LikeResult.fromJson(_asMap(response.data));
  }

  Future<String> followUserQuick({required String targetUserId}) async {
    final response = await _dio.post(
      '/me/follow',
      data: {'target_user_id': targetUserId},
      options: await _authOptions(),
    );
    final data = _asMap(response.data);
    return data['status'] as String? ?? 'none';
  }

  Future<void> unfollowUser({required String targetUserId}) async {
    await _dio.post(
      '/me/unfollow',
      data: {'target_user_id': targetUserId},
      options: await _authOptions(),
    );
  }

  Future<void> reportPost({
    required String postId,
    required String reportedUserId,
    required String reason,
    String? additionalDetails,
  }) async {
    await _dio.post(
      '/posts/report',
      data: {
        'post_id': postId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        if (additionalDetails != null && additionalDetails.isNotEmpty)
          'additional_details': additionalDetails,
      },
      options: await _authOptions(),
    );
  }

  /// Submits an appeal/justification for a post that Vista moderation removed
  /// or edited. Backend guards ownership + moderated-state and rejects
  /// duplicate pending appeals (HTTP 409).
  Future<void> appealPost({
    required String postId,
    required String reason,
  }) async {
    await _dio.post(
      '/posts/appeal',
      data: {
        'post_id': postId,
        'reason': reason,
      },
      options: await _authOptions(),
    );
  }

  Future<void> trackFeedEvent({
    required String postId,
    required String eventType,
  }) async {
    if (postId.isEmpty || eventType.isEmpty) return;
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    try {
      await _dio.post(
        '/feed/event',
        data: {'post_id': postId, 'event_type': eventType},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      // Feed analytics must never block the user action itself.
    }
  }

  Future<void> deletePost(String postId) async {
    PublicPostModel? existingPost;
    try {
      existingPost = await getPost(postId);
    } catch (_) {}

    await _dio.delete(
      '/posts/$postId',
      options: await _authOptions(),
    );

    if (existingPost != null) {
      await OrphanedMediaCleanupService.enqueueUrls(
        [
          existingPost.imageUrl,
          existingPost.videoUrl,
          existingPost.musicUrl,
        ],
        source: 'post_delete',
        reason: 'post_deleted',
      );
    }
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<Options> _optionalAuthOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      return Options();
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  List<PublicPostModel> _parsePostList(dynamic data) {
    final map = _asMap(data);
    final rawPosts = map['posts'];
    if (rawPosts is! List) return const [];

    return rawPosts
        .whereType<Map>()
        .map((item) => _postFromGo(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  List<HashtagSuggestion> _parseHashtagSuggestions(dynamic data) {
    final map = _asMap(data);
    final rawItems = map['hashtags'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((item) => HashtagSuggestion.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.tag.isNotEmpty)
        .toList(growable: false);
  }

  PublicPostModel _postFromGo(Map<String, dynamic> raw) {
    final author = raw['author'] is Map
        ? (raw['author'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final fullName = (author['full_name'] ?? raw['full_name'] ?? '').toString();
    final username =
        (author['username'] ?? raw['username'] ?? fullName).toString();
    final avatarUrl =
        (author['avatar_url'] ?? raw['avatar_url'] ?? '').toString();
    final isVerified =
        author['is_verified'] as bool? ?? raw['is_verified'] as bool? ?? false;

    final profiles = <String, dynamic>{
      'username': username.isNotEmpty ? username : 'Unknown',
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'verification_type':
          author['verification_type'] ?? raw['verification_type'],
      if (author['role'] != null || raw['role'] != null)
        'role': author['role'] ?? raw['role'],
    };

    return PublicPostModel.fromMap({
      ...raw,
      'profiles': profiles,
      'username': profiles['username'],
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'is_verified': isVerified,
      'verification_type': profiles['verification_type'],
      'hashtags': raw['tags'] ?? raw['hashtags'] ?? const [],
      'tags': raw['tags'] ?? raw['hashtags'] ?? const [],
      'title': raw['music_title'] ?? raw['title'],
    });
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
