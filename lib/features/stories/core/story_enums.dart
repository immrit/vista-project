/// Enums و Constants مربوط به سیستم استوری Vista
library;

/// نوع رسانه استوری
enum StoryMediaType {
  image,
  video,
}

/// تنظیمات حریم خصوصی استوری
enum StoryPrivacyType {
  everyone, // همه
  contacts, // مخاطبین
  closeFriends, // دوستان نزدیک
  custom, // سفارشی
}

/// مدت زمان استوری
enum StoryDuration {
  hours24(24, 'free'), // ۲۴ ساعت - رایگان
  hours48(48, 'premium'); // ۴۸ ساعت - پریمیوم

  final int hours;
  final String tier;
  const StoryDuration(this.hours, this.tier);
}

/// نوع واکنش به استوری
enum StoryReactionType {
  like('❤️'),
  love('😍'),
  laugh('😂'),
  wow('😮'),
  sad('😢'),
  angry('😠'),
  fire('🔥'),
  clap('👏'),
  think('🤔');

  final String emoji;
  const StoryReactionType(this.emoji);
}

/// نوع تعامل استوری
enum StoryInteractionType {
  reaction,
  reply,
  poll,
  quiz,
  link,
  location,
  mention,
  hashtag,
}

/// وضعیت آپلود استوری
enum StoryUploadStatus {
  idle,
  compressing,
  uploading,
  processing,
  completed,
  error,
}

/// تنظیمات دسترسی پاسخ به استوری
enum StoryReplyPermission {
  everyone, // همه
  following, // فقط کسانی که فالو می‌کنید
  off, // غیرفعال
}

extension StoryReplyPermissionX on StoryReplyPermission {
  String get persianTitle {
    switch (this) {
      case StoryReplyPermission.everyone:
        return 'همه';
      case StoryReplyPermission.following:
        return 'فقط دنبال‌شده‌ها';
      case StoryReplyPermission.off:
        return 'غیرفعال';
    }
  }
}

/// Constants
class StoryConstants {
  StoryConstants._();

  // محدودیت‌ها
  static const int maxVideoLengthSeconds = 60;
  static const int maxImageSizeMB = 15;
  static const int maxVideoSizeMB = 100;
  static const int defaultStoryDurationSeconds = 7;

  // محدودیت Highlights
  static const int freeHighlightsLimit = 20;
  static const int premiumHighlightsLimit = 100;

  // کش
  static const int maxCachedStories = 50;
  static const Duration cacheExpiration = Duration(hours: 24);

  // انیمیشن
  static const Duration progressAnimationDuration = Duration(seconds: 7);
  static const Duration transitionDuration = Duration(milliseconds: 300);

  // رنگ‌های گرادیان حلقه استوری
  static const List<int> unseenGradientColors = [
    0xFF4A90E2,
    0xFF8E44AD,
  ];

  static const List<int> seenGradientColors = [
    0xFF9E9E9E,
    0xFFBDBDBD,
  ];

  // Premium Color
  static const int premiumColor = 0xFF8774E1;
}
