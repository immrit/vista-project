import 'package:flutter_test/flutter_test.dart';
import 'package:Vista/model/notificationModel.dart';
import 'package:Vista/services/notification_action_resolver.dart';

NotificationModel _notification({
  String type = 'suggest_post',
  String? postId,
  String? deeplink,
}) {
  return NotificationModel(
    id: 'notification-1',
    senderId: 'sender-1',
    recipientId: 'recipient-1',
    content: 'پست پیشنهادی:متن پست',
    createdAt: DateTime.utc(2026, 7, 13),
    type: type,
    username: 'suggested_user',
    fullName: 'Suggested User',
    userIsVerified: false,
    postId: postId,
    isRead: false,
    verificationType: VerificationType.none,
    deeplink: deeplink,
  );
}

void main() {
  group('NotificationActionResolver suggested post', () {
    test('opens the persisted post id when available', () {
      final action = NotificationActionResolver.resolve(
        _notification(postId: 'post-1', deeplink: '/posts/fallback'),
      );

      expect(action.type, NotificationActionType.openSuggestedPost);
      expect(action.postId, 'post-1');
    });

    test('falls back to deeplink for legacy rows without post id', () {
      final action = NotificationActionResolver.resolve(
        _notification(deeplink: '/posts/post-legacy'),
      );

      expect(action.type, NotificationActionType.openDeepLink);
      expect(action.deeplink, '/posts/post-legacy');
    });
  });
}
