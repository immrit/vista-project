import '../../../model/message_model.dart';

/// Limits how many messages are mounted in the chat list at once.
/// Older messages stay in DB/provider; scrolling up expands the window.
class ChatMessageRenderWindow {
  const ChatMessageRenderWindow._();

  static const int initialCap = 280;
  static const int maxCap = 520;
  static const int expandStep = 40;

  static int clampCap(int value) {
    if (value < initialCap) return initialCap;
    if (value > maxCap) return maxCap;
    return value;
  }

  static int expandCap(int current) {
    return clampCap(current + expandStep);
  }

  /// Ensures [messageIndex] (newest-first list) is inside the render window.
  static int capToIncludeIndex(int messageIndex) {
    return clampCap(messageIndex + 12);
  }

  /// Newest messages first — keep the head of the list.
  static List<MessageModel> clip(List<MessageModel> messages, int cap) {
    final limit = clampCap(cap);
    if (messages.length <= limit) return messages;
    return messages.sublist(0, limit);
  }

  static bool shouldKeepAliveMessage(MessageModel message) {
    final rawType = message.attachmentType;
    final attachmentType =
        rawType == null ? '' : rawType.trim().toLowerCase();
    if (attachmentType == 'image' ||
        attachmentType == 'video' ||
        attachmentType == 'voice' ||
        attachmentType == 'audio' ||
        attachmentType == 'gif' ||
        attachmentType == 'file' ||
        attachmentType == 'document') {
      return true;
    }
    final url = message.attachmentUrl?.trim() ?? '';
    return url.isNotEmpty;
  }

  static bool shouldKeepAliveMessages(List<MessageModel> messages) {
    for (final message in messages) {
      if (shouldKeepAliveMessage(message)) return true;
    }
    return false;
  }
}
