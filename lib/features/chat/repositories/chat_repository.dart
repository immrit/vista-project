// lib/features/chat/repositories/chat_repository.dart
//
// این فایل یک Interface (قرارداد) برای Repository چت است.
// تمام عملیات مربوط به چت اینجا تعریف شده و Implementation جداست.
// این pattern به ما کمک می‌کنه که:
// 1. تست‌نویسی راحت‌تر بشه (می‌تونیم Mock بسازیم)
// 2. اگه بعداً خواستیم backend عوض کنیم، فقط Implementation رو عوض می‌کنیم
// 3. کد تمیزتر و قابل فهم‌تر بشه

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../model/message_model.dart';
import '../../../model/conversation_model.dart';
import '../domain/message_payload.dart';

/// نتیجه عملیات با قابلیت نمایش خطای کاربرپسند
class ChatResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const ChatResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  /// ساخت نتیجه موفق
  factory ChatResult.success(T data) => ChatResult._(
        data: data,
        isSuccess: true,
      );

  /// ساخت نتیجه ناموفق
  factory ChatResult.failure(String error) => ChatResult._(
        error: error,
        isSuccess: false,
      );

  R fold<R>(R Function(T data) onSuccess, R Function(String error) onFailure) {
    if (isSuccess) {
      return onSuccess(data as T);
    } else {
      return onFailure(error!);
    }
  }
}

/// وضعیت بارگذاری پیام‌ها
enum LoadingState {
  initial,
  loading,
  loaded,
  loadingMore,
  error,
}

/// Repository اصلی برای مدیریت تمام عملیات چت
///
/// این Interface مشخص می‌کنه که چه عملیاتی روی چت قابل انجامه.
/// Implementation واقعی در `ChatRepositoryImpl` هست.
abstract class ChatRepository {
  // ═══════════════════════════════════════════════════════════════════
  // 📂 CONVERSATIONS - لیست مکالمات
  // ═══════════════════════════════════════════════════════════════════

  /// دریافت لیست مکالمات (یکبار)
  ///
  /// اول از Cache می‌خونه، بعد Server رو sync می‌کنه
  Future<ChatResult<List<ConversationModel>>> getConversations();

  /// Stream مکالمات (Real-time)
  ///
  /// این Stream همیشه اول Cache رو emit می‌کنه (سریع)
  /// بعد Server رو چک می‌کنه و در صورت تغییر، دوباره emit می‌کنه
  Stream<List<ConversationModel>> watchConversations();

  /// ساخت مکالمه جدید با یک کاربر
  ///
  /// اگه مکالمه قبلاً وجود داشته باشه، همون رو برمی‌گردونه
  Future<ChatResult<ConversationModel>> createConversation(String otherUserId);

  /// حذف یک مکالمه
  ///
  /// این متد هم از Cache و هم از Server حذف می‌کنه
  Future<ChatResult<void>> deleteConversation(String conversationId);

  /// آرشیو کردن مکالمه (Toggle)
  Future<ChatResult<void>> toggleArchiveConversation(String conversationId);

  /// Pin کردن مکالمه (Toggle)
  Future<ChatResult<void>> togglePinConversation(String conversationId);

  /// Mute کردن مکالمه (Toggle)
  Future<ChatResult<void>> toggleMuteConversation(String conversationId);

  /// پاکسازی همه پیام‌های یک مکالمه
  /// [forEveryone] اگه true باشه، برای طرف مقابل هم پاک میشه
  Future<ChatResult<void>> clearConversation(
    String conversationId, {
    bool forEveryone = false,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 💬 MESSAGES - پیام‌ها
  // ═══════════════════════════════════════════════════════════════════

  /// دریافت پیام‌های یک مکالمه (یکبار)
  ///
  /// [limit]: تعداد پیام (پیش‌فرض 50)
  /// [beforeMessageId]: برای Pagination - پیام‌های قبل از این ID
  Future<ChatResult<List<MessageModel>>> getMessages(
    String conversationId, {
    int limit = 50,
    String? beforeMessageId,
  });

  /// Stream پیام‌های یک مکالمه (Real-time)
  ///
  /// این Stream:
  /// 1. اول Cache رو emit می‌کنه (سریع)
  /// 2. Server رو sync می‌کنه
  /// 3. به تغییرات Real-time گوش میده
  Stream<List<MessageModel>> watchMessages(String conversationId);

  /// سیستم جدید: همه‌چیز در MessagePayload کپسوله شده است
  Future<ChatResult<MessageModel>> sendMessage(MessagePayload payload);

  /// Create an optimistic pending upload message in local cache.
  Future<ChatResult<MessageModel>> createPendingMessage({
    required String conversationId,
    required String content,
    required String localId,
    required String attachmentType,
    String? attachmentFileName,
    String? attachmentMimeType,
    int? attachmentSizeBytes,
    String? audioTitle,
    String? audioArtist,
    String? audioAlbum,
    String? localFilePath,
    int? duration,
  });

  /// Update upload progress for a pending local message.
  Future<ChatResult<void>> updateUploadProgress(
      String localId, double progress);

  /// Replace/merge pending upload message with server-confirmed message.
  Future<ChatResult<void>> markUploadSucceeded(
      String localId, MessageModel serverMessage);

  /// Mark pending upload message as failed and keep it in chat list.
  Future<ChatResult<void>> markUploadFailed(
    String localId, {
    String? errorMessage,
  });

  /// حذف پیام
  /// [forEveryone] اگه true باشه، برای همه حذف میشه
  Future<ChatResult<void>> deleteMessage(
    String messageId, {
    bool forEveryone = false,
  });

  /// ویرایش پیام
  Future<ChatResult<void>> editMessage(String messageId, String newContent);

  /// جستجو در پیام‌ها
  Future<ChatResult<List<MessageModel>>> searchMessages(
    String conversationId,
    String query,
  );

  /// ✅ بارگذاری پیام‌های بیشتر (Pagination)
  ///
  /// این متد برای Infinite Scroll استفاده میشه
  /// [oldestMessageDate]: تاریخ قدیمی‌ترین پیامی که داریم
  /// [limit]: تعداد پیام برای بارگذاری (پیش‌فرض 50)
  Future<ChatResult<List<MessageModel>>> loadMoreMessages({
    required String conversationId,
    required DateTime oldestMessageDate,
    int limit = 50,
  });

  // ═══════════════════════════════════════════════════════════════════
  // 😀 REACTIONS - واکنش‌ها
  // ═══════════════════════════════════════════════════════════════════

  /// Toggle کردن Reaction
  /// اگه قبلاً این emoji رو داده، حذف میشه
  /// اگه emoji دیگه‌ای داده بود، عوض میشه
  Future<ChatResult<void>> toggleReaction({
    required String messageId,
    required String conversationId,
    required String emoji,
  });

  /// دریافت Reactions یک پیام
  Stream<Map<String, List<String>>> watchReactions(String messageId);

  // ═══════════════════════════════════════════════════════════════════
  // ⌨️ TYPING INDICATOR - در حال نوشتن
  // ═══════════════════════════════════════════════════════════════════

  /// ارسال سیگنال "دارم تایپ می‌کنم"
  Future<void> sendTypingIndicator(String conversationId);

  /// Stream وضعیت تایپ کردن طرف مقابل
  Stream<bool> watchTypingStatus(String conversationId, String userId);

  // ═══════════════════════════════════════════════════════════════════
  // 🔄 SYNC & REFRESH
  // ═══════════════════════════════════════════════════════════════════

  /// Refresh کردن لیست مکالمات از Server
  Future<void> refreshConversations();

  /// Refresh کردن پیام‌های یک مکالمه از Server
  Future<void> refreshMessages(String conversationId);

  /// Sync کردن پیام‌های pending (که هنوز ارسال نشدن)
  Future<void> syncPendingMessages();

  // ═══════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP - پاکسازی
  // ═══════════════════════════════════════════════════════════════════

  /// بستن همه connection ها و آزاد کردن حافظه
  ///
  /// ⚠️ مهم: این متد باید حتماً وقتی از صفحه چت خارج میشیم صدا زده بشه
  void dispose();

  /// پاک کردن کل کش
  Future<void> clearAllCache();

  /// پاک کردن Cache یک مکالمه
  Future<void> clearConversationCache(String conversationId);

  /// پاک کردن تعداد پیام‌های خوانده‌نشده
  Future<void> resetUnreadCount(String conversationId);

  /// بررسی اینکه آیا کاربر بلاک شده است یا خیر
  Future<bool> isUserBlocked(String userId);

  /// رفع مسدودیت کاربر
  Future<void> unblockUser(String userId);

  /// بررسی اینکه آیا کاربر جاری توسط کاربر دیگر بلاک شده است یا خیر
  Future<bool> isCurrentUserBlockedBy(String userId);

  /// تنظیم مکالمه فعال فعلی (برای جلوگیری از افزایش unreadCount)
  void setActiveConversation(String? conversationId);

  /// ✅ پردازش پیام دریافتی از نوتیفیکیشن (Optimistic Save)
  ///
  /// این متد پیام را از payload نوتیفیکیشن استخراج کرده و فوراً در دیتابیس ذخیره می‌کند
  /// تا هنگام باز شدن صفحه چت، پیام قبلاً موجود باشد.
  Future<void> handleNotificationMessage(Map<String, dynamic> payload);

  /// وضعیت اتصال ریل‌تایم (برای بهینه‌سازی Polling)
  Stream<RealtimeSubscribeStatus> get realtimeStatus;

  Future<void> markMessagesAsSeen(String conversationId);
}
