// lib/features/chat/models/moderation_reason.dart
//
// مدل‌های سیستم مدیریت کاربران (بلاک و گزارش)
//
// این فایل شامل:
// ✅ دلایل گزارش کاربر
// ✅ وضعیت‌های بلاک
// ✅ مدل گزارش کامل
//

/// دلایل گزارش کاربر
enum ModerationReason {
  inappropriateContent('inappropriate_content', 'محتوای نامناسب', '🚫'),
  harassment('harassment', 'آزار و اذیت', '⚠️'),
  spam('spam', 'اسپم و تبلیغات', '📢'),
  impersonation('impersonation', 'جعل هویت', '👤'),
  scam('scam', 'کلاهبرداری', '💰'),
  violentContent('violent_content', 'محتوای خشونت‌آمیز', '🔪'),
  hateSpeech('hate_speech', 'سخنان نفرت‌انگیز', '💢'),
  selfHarm('self_harm', 'خودآزاری', '🆘'),
  childSafety('child_safety', 'ایمنی کودکان', '👶'),
  intellectualProperty('intellectual_property', 'نقض حق نشر', '©️'),
  misinformation('misinformation', 'اطلاعات نادرست', '❌'),
  other('other', 'سایر موارد', '📝');

  final String value;
  final String label;
  final String emoji;

  const ModerationReason(this.value, this.label, this.emoji);

  /// تبدیل از String به Enum
  static ModerationReason fromValue(String value) {
    return ModerationReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => ModerationReason.other,
    );
  }

  /// دریافت توضیحات تکمیلی
  String get description {
    switch (this) {
      case ModerationReason.inappropriateContent:
        return 'محتوای غیراخلاقی، توهین‌آمیز یا نامناسب';
      case ModerationReason.harassment:
        return 'آزار، تهدید یا مزاحمت مکرر';
      case ModerationReason.spam:
        return 'ارسال پیام‌های تکراری یا تبلیغات ناخواسته';
      case ModerationReason.impersonation:
        return 'جعل هویت و سوءاستفاده از نام دیگران';
      case ModerationReason.scam:
        return 'تلاش برای کلاهبرداری یا فریب کاربران';
      case ModerationReason.violentContent:
        return 'محتوای حاوی خشونت یا تهدید';
      case ModerationReason.hateSpeech:
        return 'سخنان نفرت‌انگیز علیه گروه‌های خاص';
      case ModerationReason.selfHarm:
        return 'محتوای تشویق به خودآزاری یا خودکشی';
      case ModerationReason.childSafety:
        return 'محتوای خطرناک برای کودکان';
      case ModerationReason.intellectualProperty:
        return 'نقض حقوق مالکیت معنوی یا کپی‌رایت';
      case ModerationReason.misinformation:
        return 'انتشار اطلاعات نادرست یا گمراه‌کننده';
      case ModerationReason.other:
        return 'دلایل دیگری که در فهرست نیست';
    }
  }

  /// سطح اولویت (1-5، 5 بحرانی‌تر)
  int get priorityLevel {
    switch (this) {
      case ModerationReason.childSafety:
      case ModerationReason.selfHarm:
        return 5; // بحرانی
      case ModerationReason.violentContent:
      case ModerationReason.scam:
        return 4; // بسیار مهم
      case ModerationReason.harassment:
      case ModerationReason.hateSpeech:
        return 3; // مهم
      case ModerationReason.inappropriateContent:
      case ModerationReason.impersonation:
        return 2; // متوسط
      case ModerationReason.spam:
      case ModerationReason.intellectualProperty:
      case ModerationReason.misinformation:
      case ModerationReason.other:
        return 1; // کم
    }
  }

  /// آیا نیاز به بررسی فوری دارد؟
  bool get requiresImmediateReview => priorityLevel >= 4;
}

/// وضعیت بلاک کاربر
enum BlockStatus {
  notBlocked('not_blocked', 'بلاک نشده', '✅'),
  blockedByMe('blocked_by_me', 'من بلاک کردم', '🚫'),
  blockedMe('blocked_me', 'من بلاک شدم', '⛔'),
  mutualBlock('mutual_block', 'بلاک متقابل', '🔒');

  final String value;
  final String label;
  final String emoji;

  const BlockStatus(this.value, this.label, this.emoji);

  static BlockStatus fromValue(String value) {
    return BlockStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => BlockStatus.notBlocked,
    );
  }

  /// آیا می‌توان پیام فرستاد؟
  bool get canSendMessage => this == BlockStatus.notBlocked;

  /// آیا می‌توان مسدودیت را برداشت؟
  bool get canUnblock =>
      this == BlockStatus.blockedByMe || this == BlockStatus.mutualBlock;
}

/// مدل گزارش کاربر
class ModerationReport {
  final String id;
  final String reporterId; // کاربری که گزارش می‌کند
  final String reportedUserId; // کاربر گزارش‌شده
  final ModerationReason reason;
  final String? additionalInfo;
  final List<String>? evidenceUrls; // لینک‌های اسکرین‌شات یا مدارک
  final DateTime createdAt;
  final String? conversationId; // اگر از چت گزارش شده
  final String? messageId; // اگر پیام خاصی گزارش شده
  final ReportStatus status;
  final String? reviewerId; // کاربری که گزارش را بررسی کرده
  final DateTime? reviewedAt;
  final String? reviewNotes;

  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    this.additionalInfo,
    this.evidenceUrls,
    required this.createdAt,
    this.conversationId,
    this.messageId,
    this.status = ReportStatus.pending,
    this.reviewerId,
    this.reviewedAt,
    this.reviewNotes,
  });

  /// تبدیل از JSON
  factory ModerationReport.fromJson(Map<String, dynamic> json) {
    return ModerationReport(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      reason: ModerationReason.fromValue(json['reason'] as String),
      additionalInfo: json['additional_info'] as String?,
      evidenceUrls: (json['evidence_urls'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      conversationId: json['conversation_id'] as String?,
      messageId: json['message_id'] as String?,
      status: ReportStatus.fromValue(json['status'] as String? ?? 'pending'),
      reviewerId: json['reviewer_id'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewNotes: json['review_notes'] as String?,
    );
  }

  /// تبدیل به JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'reported_user_id': reportedUserId,
      'reason': reason.value,
      'additional_info': additionalInfo,
      'evidence_urls': evidenceUrls,
      'created_at': createdAt.toIso8601String(),
      'conversation_id': conversationId,
      'message_id': messageId,
      'status': status.value,
      'reviewer_id': reviewerId,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'review_notes': reviewNotes,
    };
  }

  /// اعتبارسنجی گزارش
  bool get isValid {
    // حداقل باید دلیل و کاربر گزارش‌شده مشخص باشد
    if (reportedUserId.isEmpty) return false;

    // اگر دلیل "سایر" است، باید توضیحات اضافی داده شود
    if (reason == ModerationReason.other &&
        (additionalInfo == null || additionalInfo!.trim().isEmpty)) {
      return false;
    }

    // حداقل طول توضیحات (در صورت وجود)
    if (additionalInfo != null && additionalInfo!.trim().length < 10) {
      return false;
    }

    return true;
  }

  /// کپی با تغییرات
  ModerationReport copyWith({
    String? id,
    String? reporterId,
    String? reportedUserId,
    ModerationReason? reason,
    String? additionalInfo,
    List<String>? evidenceUrls,
    DateTime? createdAt,
    String? conversationId,
    String? messageId,
    ReportStatus? status,
    String? reviewerId,
    DateTime? reviewedAt,
    String? reviewNotes,
  }) {
    return ModerationReport(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reason: reason ?? this.reason,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      evidenceUrls: evidenceUrls ?? this.evidenceUrls,
      createdAt: createdAt ?? this.createdAt,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      status: status ?? this.status,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNotes: reviewNotes ?? this.reviewNotes,
    );
  }
}

/// وضعیت گزارش
enum ReportStatus {
  pending('pending', 'در انتظار بررسی', '⏳'),
  underReview('under_review', 'در حال بررسی', '🔍'),
  resolved('resolved', 'حل شده', '✅'),
  dismissed('dismissed', 'رد شده', '❌'),
  actionTaken('action_taken', 'اقدام انجام شد', '⚡');

  final String value;
  final String label;
  final String emoji;

  const ReportStatus(this.value, this.label, this.emoji);

  static ReportStatus fromValue(String value) {
    return ReportStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ReportStatus.pending,
    );
  }
}

/// اطلاعات کاربر مسدود شده
class BlockedUserInfo {
  final String userId;
  final String? username;
  final String? fullName;
  final String? avatarUrl;
  final DateTime blockedAt;
  final String? reason; // دلیل بلاک (اختیاری)
  final bool isMuted; // آیا قبل از بلاک، mute شده بود؟

  const BlockedUserInfo({
    required this.userId,
    this.username,
    this.fullName,
    this.avatarUrl,
    required this.blockedAt,
    this.reason,
    this.isMuted = false,
  });

  factory BlockedUserInfo.fromJson(Map<String, dynamic> json) {
    return BlockedUserInfo(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      blockedAt: DateTime.parse(json['blocked_at'] as String),
      reason: json['reason'] as String?,
      isMuted: json['is_muted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'blocked_at': blockedAt.toIso8601String(),
      'reason': reason,
      'is_muted': isMuted,
    };
  }

  /// نام نمایشی کاربر
  String get displayName => fullName ?? username ?? 'کاربر';
}
