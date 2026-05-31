import 'package:dio/dio.dart';
import 'package:Vista/utils/env_config.dart';

import '../features/auth/providers/auth_controller.dart';
import '../model/CommentModel.dart';
import 'system_status_service.dart';

class CommentPage {
  final List<CommentModel> comments;
  final bool hasMore;

  const CommentPage({
    required this.comments,
    required this.hasMore,
  });
}

class CommentRepository {
  final Map<String, String> _commentPostCache = {};
  late final Dio _dio;

  CommentRepository() {
    _dio = Dio(BaseOptions(
      baseUrl: '$_backendUrl/v1',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  static String get _backendUrl => EnvConfig.apiBaseUrl;

  Future<List<CommentModel>> getComments({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    final pageResult = await getCommentsWithPagination(
      postId: postId,
      page: page,
      limit: limit,
    );
    return pageResult.comments
        .where((comment) => comment.parentCommentId == null)
        .toList(growable: false);
  }

  Future<List<CommentModel>> getReplies(String parentCommentId) async {
    final postId = _commentPostCache[parentCommentId] ??
        (await getCommentById(parentCommentId))?.postId;
    if (postId == null || postId.isEmpty) return const [];

    final comments = await _fetchGoComments(postId: postId);
    return comments
        .where((comment) => comment.parentCommentId == parentCommentId)
        .toList(growable: false);
  }

  Future<CommentModel> addComment({
    required String postId,
    required String content,
    String? parentCommentId,
  }) async {
    await SystemStatusService.instance.ensureFeatureEnabled(
      SystemFeature.comments,
      forceRefresh: true,
    );
    final response = await _dio.post(
      '/comments',
      data: {
        'post_id': postId,
        'content': content,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parent_comment_id': parentCommentId,
      },
      options: await _authOptions(),
    );
    return _cacheComment(CommentModel.fromMap(_asMap(response.data)));
  }

  Future<void> deleteComment(String commentId) async {
    await _dio.delete('/comments/$commentId', options: await _authOptions());
  }

  Future<CommentModel> updateComment({
    required String commentId,
    required String content,
  }) async {
    final response = await _dio.patch(
      '/comments/$commentId',
      data: {'content': content},
      options: await _authOptions(),
    );
    return _cacheComment(CommentModel.fromMap(_asMap(response.data)));
  }

  Future<void> reportComment({
    required String commentId,
    required String reason,
    String? additionalDetails,
  }) async {
    await _dio.post(
      '/comments/$commentId/report',
      data: {
        'reason': reason,
        if (additionalDetails != null && additionalDetails.trim().isNotEmpty)
          'additional_details': additionalDetails.trim(),
      },
      options: await _authOptions(),
    );
  }

  Future<void> addMentions({
    required String commentId,
    required List<String> userIds,
  }) async {
    final normalizedIds = userIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (normalizedIds.isEmpty) return;

    await _dio.post(
      '/comments/$commentId/mentions',
      data: {'user_ids': normalizedIds},
      options: await _authOptions(),
    );
  }

  Future<int> getCommentsCount(String postId) async {
    final response = await _dio.get(
      '/comments',
      queryParameters: {'post_id': postId, 'count': 'true'},
      options: await _authOptions(),
    );
    return (_asMap(response.data)['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<CommentModel>> searchComments({
    required String postId,
    required String query,
  }) async {
    final normalized = query.toLowerCase();
    final comments = await _fetchGoComments(postId: postId);
    return comments
        .where((comment) => comment.content.toLowerCase().contains(normalized))
        .toList(growable: false);
  }

  Future<List<CommentModel>> getUserRecentComments({
    required String userId,
    int limit = 10,
  }) async {
    return const [];
  }

  Future<({List<CommentModel> comments, bool hasMore})>
      getCommentsWithPagination({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    final result = await _fetchGoCommentsPage(
      postId: postId,
      limit: limit,
      offset: page * limit,
    );
    return (comments: result.comments, hasMore: result.hasMore);
  }

  Future<List<CommentModel>> getLatestComments(
    String postId, {
    int limit = 5,
  }) async {
    final comments = await _fetchGoComments(postId: postId, limit: limit);
    return comments.take(limit).toList(growable: false);
  }

  Future<bool> hasUserCommented({
    required String postId,
    required String userId,
  }) async {
    final comments = await _fetchGoComments(postId: postId);
    return comments.any((comment) => comment.userId == userId);
  }

  Future<CommentModel?> getCommentById(String commentId) async {
    try {
      final response = await _dio.get(
        '/comments/$commentId',
        options: await _authOptions(),
      );
      return _cacheComment(CommentModel.fromMap(_asMap(response.data)));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<CommentModel>> getCommentThread(String commentId) async {
    final comment = await getCommentById(commentId);
    if (comment == null || comment.postId.isEmpty) return const [];

    final comments = await _fetchGoComments(postId: comment.postId);
    final relatedIds = <String>{comment.id};
    var parentId = comment.parentCommentId;
    while (parentId != null && parentId.isNotEmpty) {
      relatedIds.add(parentId);
      String? nextParentId;
      for (final item in comments) {
        if (item.id == parentId) {
          nextParentId = item.parentCommentId;
          break;
        }
      }
      parentId = nextParentId;
    }

    var changed = true;
    while (changed) {
      changed = false;
      for (final item in comments) {
        if (item.parentCommentId != null &&
            relatedIds.contains(item.parentCommentId) &&
            relatedIds.add(item.id)) {
          changed = true;
        }
      }
    }

    return comments
        .where((item) => relatedIds.contains(item.id))
        .toList(growable: false);
  }

  Future<List<CommentModel>> getCommentsWithReplies({
    required String postId,
    int page = 0,
    int limit = 1000,
  }) async {
    return _fetchGoComments(
      postId: postId,
      limit: limit,
      offset: page * limit,
    );
  }

  Future<List<CommentModel>> getCommentsWithRepliesCount({
    required String postId,
    int page = 0,
    int limit = 20,
  }) async {
    return getComments(postId: postId, page: page, limit: limit);
  }

  Future<List<CommentModel>> getPopularComments({
    required String postId,
    int limit = 10,
  }) async {
    return getLatestComments(postId, limit: limit);
  }

  Future<bool> pinComment(String commentId, bool isPinned) async {
    return false;
  }

  Future<List<CommentModel>> getPinnedComments(String postId) async {
    return const [];
  }

  Future<List<CommentModel>> getNestedComments(String postId) async {
    final comments = await _fetchGoComments(postId: postId);
    return comments
        .where((comment) => comment.parentCommentId != null)
        .toList(growable: false);
  }

  Future<List<CommentModel>> getCommentsByDateRange({
    required String postId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final comments = await _fetchGoComments(postId: postId);
    return comments.where((comment) {
      return !comment.createdAt.isBefore(startDate) &&
          !comment.createdAt.isAfter(endDate);
    }).toList(growable: false);
  }

  Future<CommentModel?> getCurrentUserProfile() async {
    return null;
  }

  Future<List<CommentModel>> _fetchGoComments({
    required String postId,
    int limit = 1000,
    int offset = 0,
  }) async {
    final page = await _fetchGoCommentsPage(
      postId: postId,
      limit: limit,
      offset: offset,
    );
    return page.comments;
  }

  Future<CommentPage> _fetchGoCommentsPage({
    required String postId,
    int limit = 1000,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/comments',
      queryParameters: {
        'post_id': postId,
        'limit': limit,
        'offset': offset,
      },
      options: await _authOptions(),
    );
    final data = _asMap(response.data);
    final rawComments = data['comments'];
    if (rawComments is! List) {
      return const CommentPage(comments: [], hasMore: false);
    }

    final comments = rawComments
        .whereType<Map>()
        .map((item) => _cacheComment(
              CommentModel.fromMap(item.cast<String, dynamic>()),
            ))
        .toList(growable: false);

    return CommentPage(
      comments: comments,
      hasMore: data['has_more'] as bool? ?? false,
    );
  }

  CommentModel _cacheComment(CommentModel comment) {
    if (comment.id.isNotEmpty && comment.postId.isNotEmpty) {
      _commentPostCache[comment.id] = comment.postId;
    }
    return comment;
  }

  Future<Options> _authOptions() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('User is not authenticated');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }
}
