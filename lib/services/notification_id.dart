/// Stable 31-bit FNV-1a identifier for Android local notifications.
///
/// Dart's Object/String hashCode is intentionally not stable across isolates
/// or process runs, while background FCM display and foreground cancellation
/// may execute in different isolates. This function must remain deterministic.
int stableNotificationId(String key) {
  var hash = 0x811c9dc5;
  for (final unit in key.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final positive = hash & 0x7fffffff;
  return positive == 0 ? 1 : positive;
}

int stableConversationNotificationId(String conversationId) =>
    stableNotificationId('chat:$conversationId');

bool isAtOrBeforeReadWatermark(DateTime messageCreatedAt, DateTime readAt) =>
    !messageCreatedAt.toUtc().isAfter(readAt.toUtc());

bool shouldClearLatestChatNotification(
  DateTime? latestMessageAt,
  DateTime readAt,
) =>
    latestMessageAt == null ||
    isAtOrBeforeReadWatermark(latestMessageAt, readAt);

bool isChatMessageOlderThanLatestNotification(
  DateTime messageCreatedAt,
  DateTime? latestMessageAt,
) =>
    latestMessageAt != null &&
    messageCreatedAt.toUtc().isBefore(latestMessageAt.toUtc());
