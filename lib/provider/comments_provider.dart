import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
import '/model/ProfileModel.dart';
// import '/model/notificationModel.dart';
import '../model/CommentModel.dart';
import '../model/UserModel.dart';
import '../features/auth/providers/auth_controller.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../services/comment_repository.dart';
import 'comment_provider.dart';
// Import security provider

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';

export '../features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

class CommentService {
  final CommentRepository _commentRepository = CommentRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  Future<CommentModel> addComment({
    required String postId,
    required String content,
    required String userId,
    String? parentCommentId,
    List<String>? mentionedUserIds,
  }) async {
    final comment = await _commentRepository.addComment(
      postId: postId,
      content: content,
      parentCommentId: parentCommentId,
    );

    final mentions = mentionedUserIds
        ?.map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (mentions != null && mentions.isNotEmpty) {
      await _commentRepository.addMentions(
        commentId: comment.id,
        userIds: mentions,
      );
    }

    return comment;
  }

  Future<List<CommentModel>> getComments(String postId) {
    return _commentRepository.getCommentsWithReplies(postId: postId);
  }

  Future<void> deleteComment(String commentId) {
    return _commentRepository.deleteComment(commentId);
  }

  Future<CommentModel> updateComment(String commentId, String content) {
    return _commentRepository.updateComment(
      commentId: commentId,
      content: content,
    );
  }

  Future<List<UserModel>> searchMentionableUsers(String query) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final profiles = await _profileRepository.searchProfiles(
      query: normalizedQuery,
      limit: 10,
    );
    return profiles.map(_profileToUser).toList(growable: false);
  }

  Future<void> addMentions({
    required String commentId,
    required List<String> mentionedUserIds,
  }) {
    return _commentRepository.addMentions(
      commentId: commentId,
      userIds: mentionedUserIds,
    );
  }
}

final commentServiceProvider = Provider<CommentService>((ref) {
  return CommentService();
});

final searchMentionableUsersProvider =
    FutureProvider.family<List<UserModel>, String>((ref, query) {
  return ref.read(commentServiceProvider).searchMentionableUsers(query);
});

class CommentsNotifier extends StateNotifier<List<CommentModel>> {
  final Ref _ref;
  final CommentService _commentService;
  final GoPostsRepository _postsRepository = GoPostsRepository();

  CommentsNotifier(this._ref, this._commentService) : super([]);

  Future<void> loadComments(String postId) async {
    final comments = await _commentService.getComments(postId);
    state = comments;
  }

  Future<void> addComment({
    required String postId,
    required String content,
    required String postOwnerId,
    required List<String> mentionedUserIds,
    String? parentCommentId,
    required WidgetRef ref,
  }) async {
    final userId = await TokenStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      throw StateError('User is not authenticated');
    }

    final comment = await _commentService.addComment(
      postId: postId,
      content: content,
      userId: userId,
      parentCommentId: parentCommentId,
      mentionedUserIds: mentionedUserIds,
    );

    state = [comment, ...state];
    await _ref.read(commentsProvider(postId).notifier).refreshComments();
  }

  Future<String> getPostOwnerId(String postId) async {
    final post = await _postsRepository.getPost(postId);
    return post.userId;
  }

  Future<void> deleteComment(
    String commentId,
    String postId,
    WidgetRef ref,
  ) async {
    await _commentService.deleteComment(commentId);
    state = state.where((comment) => comment.id != commentId).toList();
    await _ref.read(commentsProvider(postId).notifier).refreshComments();
  }

  Future<void> updateComment({
    required String commentId,
    required String postId,
    required String content,
  }) async {
    final updated = await _commentService.updateComment(commentId, content);
    state = [
      for (final comment in state)
        if (comment.id == commentId) updated else comment,
    ];
    await _ref.read(commentsProvider(postId).notifier).refreshComments();
  }
}

final commentNotifierProvider =
    StateNotifierProvider<CommentsNotifier, List<CommentModel>>((ref) {
  return CommentsNotifier(ref, ref.read(commentServiceProvider));
});

UserModel _profileToUser(ProfileModel profile) {
  return UserModel.fromMap(profile.toMap());
}
