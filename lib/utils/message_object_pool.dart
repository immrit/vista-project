import '../model/message_model.dart';

/// ✅ Object Pooling System - الهام‌گرفته از تلگرام
/// برای کاهش GC pressure و بهبود performance
class MessageObjectPool {
  static final MessageObjectPool _instance = MessageObjectPool._internal();
  factory MessageObjectPool() => _instance;
  MessageObjectPool._internal();

  final List<MessageModel> _pool = [];
  final int _maxPoolSize = 50;

  /// ✅ دریافت object از pool
  MessageModel obtain({
    required String id,
    required String conversationId,
    required String senderId,
    required String content,
    required DateTime createdAt,
    String? attachmentUrl,
    String? attachmentType,
    String? attachmentFileName,
    bool isRead = false,
    bool isSent = true,
    bool isDelivered = false,
    bool isSeen = false,
    String? senderName,
    String? senderAvatar,
    required bool isMe,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderName,
    bool isPending = false,
    bool? isFailed,
    String? localId,
    int retryCount = 0,
    String? errorMessage,
    DateTime? lastRetryTime,
    Map<String, DateTime>? typingUsers,
    Map<String, List<String>> reactions = const {},
  }) {
    if (_pool.isNotEmpty) {
      final obj = _pool.removeLast();
      // استفاده از copyWith برای به‌روزرسانی فیلدها
      return obj.copyWith(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        attachmentUrl: attachmentUrl,
        attachmentType: attachmentType,
        attachmentFileName: attachmentFileName,
        isRead: isRead,
        isSent: isSent,
        isDelivered: isDelivered,
        isSeen: isSeen,
        senderName: senderName,
        senderAvatar: senderAvatar,
        isMe: isMe,
        replyToMessageId: replyToMessageId,
        replyToContent: replyToContent,
        replyToSenderName: replyToSenderName,
        isPending: isPending,
        isFailed: isFailed,
        localId: localId,
        retryCount: retryCount,
        errorMessage: errorMessage,
        lastRetryTime: lastRetryTime,
        typingUsers: typingUsers,
        reactions: reactions,
      );
    }

    // اگر pool خالی است، object جدید ایجاد کن
    return MessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
      attachmentFileName: attachmentFileName,
      isRead: isRead,
      isSent: isSent,
      isDelivered: isDelivered,
      isSeen: isSeen,
      senderName: senderName,
      senderAvatar: senderAvatar,
      isMe: isMe,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
      isPending: isPending,
      isFailed: isFailed,
      localId: localId,
      retryCount: retryCount,
      errorMessage: errorMessage,
      lastRetryTime: lastRetryTime,
      typingUsers: typingUsers,
      reactions: reactions,
    );
  }

  /// ✅ برگرداندن object به pool
  void recycle(MessageModel message) {
    if (_pool.length < _maxPoolSize) {
      _pool.add(message);
    }
  }

  /// ✅ Batch recycling
  void recycleAll(List<MessageModel> messages) {
    for (final message in messages) {
      recycle(message);
    }
  }

  void clear() {
    _pool.clear();
  }

  int get poolSize => _pool.length;
}

