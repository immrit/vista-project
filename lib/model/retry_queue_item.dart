// lib/model/retry_queue_item.dart
//
// مدل آیتم صف ارسال مجدد
//

import 'package:equatable/equatable.dart';
import '../features/chat/domain/message_payload.dart';

/// نوع عملیات
enum RetryOperationType {
  sendMessage,
  uploadFile,
  deleteMessage,
  editMessage,
  toggleReaction,
}

/// وضعیت آیتم
enum RetryItemStatus {
  pending, // در انتظار ارسال
  sending, // در حال ارسال
  failed, // ارسال ناموفق
  completed, // ارسال موفق
  cancelled, // لغو شده
}

/// اولویت ارسال
enum RetryPriority {
  high, // پیام‌های متنی
  medium, // ویرایش و حذف
  low, // آپلود فایل
}

/// آیتم صف ارسال مجدد
class RetryQueueItem extends Equatable {
  /// شناسه یکتا
  final String id;

  /// نوع عملیات
  final RetryOperationType type;

  /// وضعیت
  final RetryItemStatus status;

  /// اولویت
  final RetryPriority priority;

  /// شناسه مکالمه
  final String conversationId;

  /// داده‌های عملیات (JSON serializable)
  final Map<String, dynamic> payload;

  /// زمان ایجاد
  final DateTime createdAt;

  /// زمان آخرین تلاش
  final DateTime? lastAttemptAt;

  /// تعداد تلاش‌ها
  final int attemptCount;

  /// حداکثر تعداد تلاش
  final int maxAttempts;

  /// پیام خطا (در صورت وجود)
  final String? errorMessage;

  const RetryQueueItem({
    required this.id,
    required this.type,
    required this.status,
    required this.priority,
    required this.conversationId,
    required this.payload,
    required this.createdAt,
    this.lastAttemptAt,
    this.attemptCount = 0,
    this.maxAttempts = 5,
    this.errorMessage,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🏭 FACTORY CONSTRUCTORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// ساخت آیتم برای ارسال پیام
  factory RetryQueueItem.sendMessage(MessagePayload payload,
      {required String id}) {
    return RetryQueueItem(
      id: id,
      type: RetryOperationType.sendMessage,
      status: RetryItemStatus.pending,
      priority: payload.attachmentUrl != null
          ? RetryPriority.low
          : RetryPriority.high,
      conversationId: payload.conversationId,
      payload: {
        'content': payload.content,
        'attachment_url': payload.attachmentUrl,
        'attachment_type': payload.attachmentType,
        'attachment_file_name': payload.attachmentFileName,
        'attachment_mime_type': payload.attachmentMimeType,
        'attachment_size_bytes': payload.attachmentSizeBytes,
        'audio_title': payload.audioTitle,
        'audio_artist': payload.audioArtist,
        'audio_album': payload.audioAlbum,
        'media_group_id': payload.mediaGroupId,
        'duration': payload.duration,
        'reply_to_message_id': payload.replyToMessageId,
        'reply_to_content': payload.replyToContent,
        'reply_to_sender_name': payload.replyToSenderName,
      },
      createdAt: DateTime.now(),
    );
  }

  /// ساخت آیتم برای آپلود فایل
  factory RetryQueueItem.uploadFile({
    required String id,
    required String conversationId,
    required String filePath,
    required String fileName,
    required String fileType,
    int? fileSize,
  }) {
    return RetryQueueItem(
      id: id,
      type: RetryOperationType.uploadFile,
      status: RetryItemStatus.pending,
      priority: RetryPriority.low,
      conversationId: conversationId,
      payload: {
        'file_path': filePath,
        'file_name': fileName,
        'file_type': fileType,
        'file_size': fileSize,
      },
      createdAt: DateTime.now(),
      maxAttempts: 3, // فایل‌ها کمتر retry میشن
    );
  }

  /// ساخت آیتم برای حذف پیام
  factory RetryQueueItem.deleteMessage({
    required String id,
    required String conversationId,
    required String messageId,
  }) {
    return RetryQueueItem(
      id: id,
      type: RetryOperationType.deleteMessage,
      status: RetryItemStatus.pending,
      priority: RetryPriority.medium,
      conversationId: conversationId,
      payload: {
        'message_id': messageId,
      },
      createdAt: DateTime.now(),
    );
  }

  /// ساخت آیتم برای ویرایش پیام
  factory RetryQueueItem.editMessage({
    required String id,
    required String conversationId,
    required String messageId,
    required String newContent,
  }) {
    return RetryQueueItem(
      id: id,
      type: RetryOperationType.editMessage,
      status: RetryItemStatus.pending,
      priority: RetryPriority.medium,
      conversationId: conversationId,
      payload: {
        'message_id': messageId,
        'new_content': newContent,
      },
      createdAt: DateTime.now(),
    );
  }

  /// ساخت آیتم برای toggle reaction
  factory RetryQueueItem.toggleReaction({
    required String id,
    required String conversationId,
    required String messageId,
    required String emoji,
  }) {
    return RetryQueueItem(
      id: id,
      type: RetryOperationType.toggleReaction,
      status: RetryItemStatus.pending,
      priority: RetryPriority.medium,
      conversationId: conversationId,
      payload: {
        'message_id': messageId,
        'emoji': emoji,
      },
      createdAt: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎯 HELPER GETTERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// آیا قابل retry هست؟
  bool get canRetry =>
      status != RetryItemStatus.completed &&
      status != RetryItemStatus.cancelled &&
      attemptCount < maxAttempts;

  /// آیا منقضی شده؟
  bool get isExpired {
    final expiryDuration = switch (type) {
      RetryOperationType.sendMessage => const Duration(hours: 24),
      RetryOperationType.uploadFile => const Duration(hours: 1),
      _ => const Duration(hours: 12),
    };
    return DateTime.now().difference(createdAt) > expiryDuration;
  }

  /// آیا پیام متنی هست؟
  bool get isTextMessage =>
      type == RetryOperationType.sendMessage &&
      payload['attachment_url'] == null;

  /// متن توضیح وضعیت
  String get statusText {
    switch (status) {
      case RetryItemStatus.pending:
        return 'در انتظار ارسال';
      case RetryItemStatus.sending:
        return 'در حال ارسال...';
      case RetryItemStatus.failed:
        return 'ارسال ناموفق';
      case RetryItemStatus.completed:
        return 'ارسال شد';
      case RetryItemStatus.cancelled:
        return 'لغو شد';
    }
  }

  /// متن توضیح نوع
  String get typeText {
    switch (type) {
      case RetryOperationType.sendMessage:
        return 'ارسال پیام';
      case RetryOperationType.uploadFile:
        return 'آپلود فایل';
      case RetryOperationType.deleteMessage:
        return 'حذف پیام';
      case RetryOperationType.editMessage:
        return 'ویرایش پیام';
      case RetryOperationType.toggleReaction:
        return 'واکنش';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📋 COPY & SERIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  RetryQueueItem copyWith({
    String? id,
    RetryOperationType? type,
    RetryItemStatus? status,
    RetryPriority? priority,
    String? conversationId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    int? attemptCount,
    int? maxAttempts,
    String? errorMessage,
  }) {
    return RetryQueueItem(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      conversationId: conversationId ?? this.conversationId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// تبدیل به JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'status': status.name,
      'priority': priority.name,
      'conversation_id': conversationId,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'attempt_count': attemptCount,
      'max_attempts': maxAttempts,
      'error_message': errorMessage,
    };
  }

  /// ساخت از JSON
  factory RetryQueueItem.fromJson(Map<String, dynamic> json) {
    return RetryQueueItem(
      id: json['id'] as String,
      type: RetryOperationType.values.byName(json['type'] as String),
      status: RetryItemStatus.values.byName(json['status'] as String),
      priority: RetryPriority.values.byName(json['priority'] as String),
      conversationId: json['conversation_id'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.parse(json['last_attempt_at'] as String)
          : null,
      attemptCount: json['attempt_count'] as int? ?? 0,
      maxAttempts: json['max_attempts'] as int? ?? 5,
      errorMessage: json['error_message'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        status,
        priority,
        conversationId,
        payload,
        createdAt,
        lastAttemptAt,
        attemptCount,
        maxAttempts,
        errorMessage,
      ];

  @override
  String toString() {
    return 'RetryQueueItem(id: $id, type: ${type.name}, status: ${status.name}, '
        'attempts: $attemptCount/$maxAttempts)';
  }
}
