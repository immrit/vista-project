import 'package:Vista/services/notification_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('conversation notification IDs are deterministic', () {
    const conversation = '11111111-2222-4333-8444-555555555555';
    expect(
      stableConversationNotificationId(conversation),
      stableConversationNotificationId(conversation),
    );
    expect(stableConversationNotificationId(conversation), greaterThan(0));
  });

  test('different conversations use different notification IDs', () {
    expect(
      stableConversationNotificationId('conversation-a'),
      isNot(stableConversationNotificationId('conversation-b')),
    );
  });

  test('social notification IDs are stable across delivery retries', () {
    expect(
      stableNotificationId('social:notification-1'),
      stableNotificationId('social:notification-1'),
    );
    expect(
      stableNotificationId('social:notification-1'),
      isNot(stableNotificationId('social:notification-2')),
    );
  });

  test('read watermark suppresses only old chat notifications', () {
    final readAt = DateTime.utc(2026, 7, 14, 10);
    expect(isAtOrBeforeReadWatermark(DateTime.utc(2026, 7, 14, 9), readAt),
        isTrue);
    expect(isAtOrBeforeReadWatermark(readAt, readAt), isTrue);
    expect(isAtOrBeforeReadWatermark(DateTime.utc(2026, 7, 14, 11), readAt),
        isFalse);
  });

  test('an old clear never removes a newer chat notification', () {
    final readAt = DateTime.utc(2026, 7, 14, 10);
    expect(shouldClearLatestChatNotification(null, readAt), isTrue);
    expect(
      shouldClearLatestChatNotification(DateTime.utc(2026, 7, 14, 9), readAt),
      isTrue,
    );
    expect(
      shouldClearLatestChatNotification(DateTime.utc(2026, 7, 14, 11), readAt),
      isFalse,
    );
  });

  test('out-of-order older messages never overwrite the latest notification',
      () {
    final latest = DateTime.utc(2026, 7, 14, 11);
    expect(
      isChatMessageOlderThanLatestNotification(
        DateTime.utc(2026, 7, 14, 10),
        latest,
      ),
      isTrue,
    );
    expect(isChatMessageOlderThanLatestNotification(latest, latest), isFalse);
    expect(
      isChatMessageOlderThanLatestNotification(
        DateTime.utc(2026, 7, 14, 12),
        latest,
      ),
      isFalse,
    );
  });
}
