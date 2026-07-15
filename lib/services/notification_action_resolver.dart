import '../model/notificationModel.dart';

enum NotificationActionType {
  openChat,
  openPost,
  openPostComments,
  openCommentReply,
  openProfile,
  openSuggestedFollow,
  openSuggestedPost,
  openSuggestionDigest,
  openDeepLink,
  openNotifications,
}

class NotificationNavigationAction {
  const NotificationNavigationAction({
    required this.type,
    this.postId,
    this.commentId,
    this.parentCommentId,
    this.userId,
    this.deeplink,
  });

  final NotificationActionType type;
  final String? postId;
  final String? commentId;
  final String? parentCommentId;
  final String? userId;
  final String? deeplink;
}

class NotificationActionResolver {
  const NotificationActionResolver._();

  static NotificationNavigationAction resolve(NotificationModel notification) {
    final type = NotificationModel.canonicalType(notification.type);

    switch (type) {
      case 'message':
      case 'reaction':
        return const NotificationNavigationAction(
          type: NotificationActionType.openChat,
        );
      case 'like':
        return NotificationNavigationAction(
          type: NotificationActionType.openPost,
          postId: notification.postId,
        );
      case 'comment':
        return NotificationNavigationAction(
          type: NotificationActionType.openPostComments,
          postId: notification.postId,
          commentId: notification.commentId,
        );
      case 'comment_reply':
        return NotificationNavigationAction(
          type: NotificationActionType.openCommentReply,
          postId: notification.postId,
          commentId: notification.commentId,
          parentCommentId: notification.parentCommentId,
        );
      case 'follow':
      case 'follow_request':
      case 'follow_request_accepted':
        return NotificationNavigationAction(
          type: NotificationActionType.openProfile,
          userId: notification.senderId,
        );
      case 'mention':
        if (notification.postId != null && notification.postId!.isNotEmpty) {
          return NotificationNavigationAction(
            type: NotificationActionType.openPost,
            postId: notification.postId,
          );
        }
        if (notification.deeplink != null &&
            notification.deeplink!.isNotEmpty) {
          return NotificationNavigationAction(
            type: NotificationActionType.openDeepLink,
            deeplink: notification.deeplink,
          );
        }
        return const NotificationNavigationAction(
          type: NotificationActionType.openNotifications,
        );
      case 'suggest_follow':
        return NotificationNavigationAction(
          type: NotificationActionType.openSuggestedFollow,
          userId: notification.followerId ?? notification.senderId,
        );
      case 'suggest_post':
        if (notification.postId == null || notification.postId!.isEmpty) {
          final deeplink = notification.deeplink;
          if (deeplink != null && deeplink.isNotEmpty) {
            return NotificationNavigationAction(
              type: NotificationActionType.openDeepLink,
              deeplink: deeplink,
            );
          }
        }
        return NotificationNavigationAction(
          type: NotificationActionType.openSuggestedPost,
          postId: notification.postId,
        );
      case 'daily_suggestion_digest':
        return const NotificationNavigationAction(
          type: NotificationActionType.openSuggestionDigest,
        );
      default:
        final deeplink = notification.deeplink;
        if (deeplink != null && deeplink.isNotEmpty) {
          return NotificationNavigationAction(
            type: NotificationActionType.openDeepLink,
            deeplink: deeplink,
          );
        }
        return const NotificationNavigationAction(
          type: NotificationActionType.openNotifications,
        );
    }
  }
}
