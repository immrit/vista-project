import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../view/widgets/VideoPlayerConfig.dart';
// import '/model/notificationModel.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/services/profile_note_service.dart';
import '../features/posts/data/go_posts_repository.dart';
import '../features/stories/data/repositories/story_repository.dart';
import '../services/comment_repository.dart';
import 'notification_provider.dart' as go_notifications;
// Import security provider

export 'security_provider.dart';
export '../features/auth/providers/auth_controller.dart';

export '../features/profile/providers/profile_controller.dart';
// profileProvider and profileUpdateProvider moved to profile_controller.dart

final deleteNoteProvider =
    FutureProvider.family<void, dynamic>((ref, noteId) async {
  await ProfileNoteService().deleteNote();
});
final isLoadingProvider = StateProvider<bool>((ref) => false);
final isRedirectingProvider = StateProvider<bool>((ref) => false);

class ReportService {
  final GoPostsRepository _postsRepository = GoPostsRepository();
  final CommentRepository _commentRepository = CommentRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? reportedUserId,
    String? additionalDetails,
    WidgetRef? ref,
  }) async {
    final normalizedType = contentType.trim().toLowerCase();

    switch (normalizedType) {
      case 'post':
      case 'posts':
        await _postsRepository.reportPost(
          postId: contentId,
          reportedUserId: reportedUserId ?? '',
          reason: reason,
          additionalDetails: additionalDetails,
        );
        return;
      case 'comment':
      case 'comments':
        await _commentRepository.reportComment(
          commentId: contentId,
          reason: reason,
          additionalDetails: additionalDetails,
        );
        return;
      case 'profile':
      case 'user':
      case 'users':
        await _profileRepository.reportProfile(
          userId: reportedUserId ?? contentId,
          reason: reason,
          additionalDetails: additionalDetails,
        );
        return;
      default:
        throw ArgumentError('Unsupported report content type: $contentType');
    }
  }
}

final reportServiceProvider = Provider<ReportService>((ref) {
  return ReportService();
});

class ReportCommentService {
  final CommentRepository _commentRepository = CommentRepository();

  Future<void> reportComment({
    required String commentId,
    String? reporterId,
    String? reportedUserId,
    required String reason,
    String? additionalDetails,
  }) {
    return _commentRepository.reportComment(
      commentId: commentId,
      reason: reason,
      additionalDetails: additionalDetails,
    );
  }
}

final reportCommentServiceProvider = Provider<ReportCommentService>((ref) {
  return ReportCommentService();
});

class ReportProfileService {
  final ProfileRepository _profileRepository = ProfileRepository();

  Future<void> reportProfile({
    String? reportedUserId,
    String? userId,
    String? reporterId,
    required String reason,
    String? additionalDetails,
  }) async {
    final targetUserId = reportedUserId ?? userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      throw ArgumentError('reportedUserId is required');
    }

    await _profileRepository.reportProfile(
      userId: targetUserId,
      reason: reason,
      additionalDetails: additionalDetails,
    );
  }
}

final reportProfileServiceProvider = Provider<ReportProfileService>((ref) {
  return ReportProfileService();
});

class StoryControllerNotifier extends StateNotifier<int> {
  StoryControllerNotifier() : super(0);

  void nextStory() => state++;
  void previousStory() => state--;
  void setCurrentIndex(int index) => state = index;

  void reset() => state = 0;
}

final storyControllerProvider =
    StateNotifierProvider<StoryControllerNotifier, int>(
  (ref) => StoryControllerNotifier(),
);

final viewsCountProvider =
    FutureProvider.family<int, String>((ref, storyId) async {
  final result = await StoryRepository().getStoryViews(storyId);
  return result.fold((_) => 0, (views) => views.length);
});

final hasNewNotificationProvider = FutureProvider<bool>((ref) async {
  final notifications = ref.watch(go_notifications.notificationsProvider);
  return notifications.any((notification) => !notification.isRead);
});
final likeStateProvider =
    StateNotifierProvider<LikeStateNotifier, Map<String, bool>>((ref) {
  return LikeStateNotifier();
});

class LikeStateNotifier extends StateNotifier<Map<String, bool>> {
  LikeStateNotifier() : super({});

  void updateLikeState(String postId, bool isLiked) {
    state = {...state, postId: isLiked};
  }

  bool isPostLiked(String postId) {
    return state[postId] ?? false;
  }
}
