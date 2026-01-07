import '../entities/story.dart';
import '../entities/story_user.dart';
import '../entities/story_highlight.dart';
import '../../core/story_enums.dart';

/// پارامترهای آپلود استوری
class StoryUploadParams {
  final dynamic mediaFile; // File یا Uint8List
  final StoryMediaType mediaType;
  final String? caption;
  final StoryDuration duration;
  final StoryPrivacyType privacyType;
  final List<String>? allowedUserIds;
  final List<String>? excludedUserIds;
  final StoryPoll? poll;
  final StoryLink? link;
  final StoryLocation? location;
  final List<StoryMention>? mentions;
  final String? musicUrl;
  final String? filter;

  const StoryUploadParams({
    required this.mediaFile,
    required this.mediaType,
    this.caption,
    this.duration = StoryDuration.hours24,
    this.privacyType = StoryPrivacyType.everyone,
    this.allowedUserIds,
    this.excludedUserIds,
    this.poll,
    this.link,
    this.location,
    this.mentions,
    this.musicUrl,
    this.filter,
  });
}

/// پارامترهای ایجاد Highlight
class HighlightCreateParams {
  final String title;
  final List<String> storyIds;
  final String? coverUrl;

  const HighlightCreateParams({
    required this.title,
    required this.storyIds,
    this.coverUrl,
  });
}

/// نتیجه عملیات (Either Pattern ساده)
class StoryResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const StoryResult._({this.data, this.error, required this.isSuccess});

  factory StoryResult.success(T data) =>
      StoryResult._(data: data, isSuccess: true);
  factory StoryResult.failure(String error) =>
      StoryResult._(error: error, isSuccess: false);

  R fold<R>(R Function(String error) onFailure, R Function(T data) onSuccess) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    }
    return onFailure(error ?? 'Unknown error');
  }
}

/// Interface اصلی Repository استوری
abstract class IStoryRepository {
  // ========== دریافت استوری‌ها ==========

  /// دریافت استوری‌های کاربران (فالو شده + خود کاربر)
  Future<StoryResult<List<StoryUser>>> getActiveStories();

  /// دریافت استوری‌های یک کاربر خاص
  Future<StoryResult<List<Story>>> getUserStories(String userId);

  /// دریافت یک استوری با ID
  Future<StoryResult<Story>> getStoryById(String storyId);

  // ========== مدیریت استوری ==========

  /// آپلود استوری جدید
  Future<StoryResult<Story>> uploadStory(StoryUploadParams params);

  /// حذف استوری
  Future<StoryResult<void>> deleteStory(String storyId);

  /// ویرایش استوری (caption و privacy)
  Future<StoryResult<Story>> editStory({
    required String storyId,
    String? caption,
    StoryPrivacyType? privacyType,
  });

  // ========== تعاملات ==========

  /// ثبت بازدید استوری
  Future<StoryResult<void>> trackView(String storyId);

  /// دریافت لیست بازدیدکنندگان
  Future<StoryResult<List<StoryView>>> getStoryViews(String storyId);

  /// واکنش به استوری
  Future<StoryResult<void>> reactToStory(
      String storyId, StoryReactionType reaction);

  /// حذف واکنش
  Future<StoryResult<void>> removeReaction(String storyId);

  /// پاسخ به استوری
  Future<StoryResult<void>> replyToStory(String storyId, String message);

  /// رأی به نظرسنجی
  Future<StoryResult<void>> voteOnPoll(String storyId, String optionId);

  /// گزارش استوری
  Future<StoryResult<void>> reportStory(String storyId, String reason);

  // ========== Highlights ==========

  /// دریافت Highlights یک کاربر
  Future<StoryResult<List<StoryHighlight>>> getUserHighlights(String userId);

  /// ایجاد Highlight جدید
  Future<StoryResult<StoryHighlight>> createHighlight(
      HighlightCreateParams params);

  /// ویرایش Highlight
  Future<StoryResult<StoryHighlight>> editHighlight({
    required String highlightId,
    String? title,
    String? coverUrl,
    List<String>? storyIds,
  });

  /// حذف Highlight
  Future<StoryResult<void>> deleteHighlight(String highlightId);

  /// دریافت تعداد Highlights کاربر
  Future<StoryResult<int>> getHighlightCount(String userId);

  // ========== حریم خصوصی ==========

  /// دریافت لیست دوستان نزدیک
  Future<StoryResult<List<String>>> getCloseFriends();

  /// به‌روزرسانی لیست دوستان نزدیک
  Future<StoryResult<void>> updateCloseFriends(List<String> userIds);
}

/// مدل بازدیدکننده استوری
class StoryView {
  final String viewerId;
  final String? viewerUsername;
  final String? viewerAvatarUrl;
  final bool isVerified;
  final DateTime viewedAt;
  final StoryReactionType? reaction;

  const StoryView({
    required this.viewerId,
    this.viewerUsername,
    this.viewerAvatarUrl,
    this.isVerified = false,
    required this.viewedAt,
    this.reaction,
  });

  factory StoryView.fromMap(Map<String, dynamic> map) {
    return StoryView(
      viewerId: map['viewer_id'] ?? '',
      viewerUsername: map['profiles']?['username'],
      viewerAvatarUrl: map['profiles']?['avatar_url'],
      isVerified: map['profiles']?['is_verified'] ?? false,
      viewedAt:
          DateTime.parse(map['viewed_at'] ?? DateTime.now().toIso8601String()),
      reaction: map['reaction'] != null
          ? StoryReactionType.values.firstWhere(
              (r) => r.name == map['reaction'],
              orElse: () => StoryReactionType.like,
            )
          : null,
    );
  }
}
