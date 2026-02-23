// lib/services/telegram_read_receipt_service.dart
//
// سرویس مدیریت وضعیت خوانده شدن پیام‌ها - به سبک ویستا
//
// ویژگی‌ها:
// ✅ Real-time وضعیت تحویل و خوانده شدن
// ✅ Batch marking برای بهینه‌سازی
// ✅ Auto-mark هنگام مشاهده پیام
// ✅ رعایت تنظیمات حریم خصوصی
// ✅ انیمیشن تیک‌ها
//

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// وضعیت تحویل پیام - مثل ویستا
enum MessageDeliveryStatus {
  pending, // ⏳ در انتظار ارسال (ساعت)
  sent, // ✓ ارسال شده به سرور (یک تیک خاکستری)
  delivered, // ✓✓ تحویل به دستگاه گیرنده (دو تیک خاکستری)
  read, // ✓✓ خوانده شده (دو تیک آبی)
  failed, // ❌ خطا در ارسال
}

/// اطلاعات کامل وضعیت پیام
class MessageStatusInfo {
  final String messageId;
  final MessageDeliveryStatus status;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  const MessageStatusInfo({
    required this.messageId,
    required this.status,
    this.sentAt,
    this.deliveredAt,
    this.seenAt,
  });

  MessageStatusInfo copyWith({
    MessageDeliveryStatus? status,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? seenAt,
  }) {
    return MessageStatusInfo(
      messageId: messageId,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      seenAt: seenAt ?? this.seenAt,
    );
  }
}

/// Callback برای آپدیت وضعیت آخرین پیام در لیست مکالمات
typedef LastMessageStatusCallback = void Function(
  String conversationId,
  MessageDeliveryStatus status,
);

/// سرویس مدیریت Read Receipts - Telegram Style
class TelegramReadReceiptService {
  static final TelegramReadReceiptService _instance =
      TelegramReadReceiptService._internal();
  factory TelegramReadReceiptService() => _instance;
  TelegramReadReceiptService._internal();

  final _supabase = Supabase.instance.client;

  // استریم‌های Real-time
  final _statusUpdatesController =
      StreamController<Map<String, MessageStatusInfo>>.broadcast();

  // ✅ Callback برای آپدیت لیست مکالمات
  LastMessageStatusCallback? onLastMessageStatusChanged;

  // کش وضعیت پیام‌ها
  final Map<String, MessageStatusInfo> _statusCache = {};

  // ✅ کش آخرین پیام هر مکالمه
  final Map<String, String> _lastMessageIds = {};

  // Subscription‌های فعال
  final Map<String, RealtimeChannel> _conversationChannels = {};

  // صف پیام‌هایی که باید خوانده شوند (برای batch)
  final Set<String> _pendingReadQueue = {};
  Timer? _batchReadTimer;
  String? _currentConversationId;

  // تنظیمات
  static const Duration _batchDelay = Duration(milliseconds: 300);
  static const int _maxBatchSize = 50;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// استریم به‌روزرسانی‌های وضعیت
  Stream<Map<String, MessageStatusInfo>> get statusUpdates =>
      _statusUpdatesController.stream;

  // ═══════════════════════════════════════════════════════════════════════════
  // 🎧 REAL-TIME LISTENING
  // ═══════════════════════════════════════════════════════════════════════════

  /// شروع گوش دادن به تغییرات یک مکالمه
  void startListening(String conversationId) {
    if (_conversationChannels.containsKey(conversationId)) return;

    _currentConversationId = conversationId;

    final channel = _supabase
        .channel('read_receipts_v2:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: _handleMessageUpdate,
        )
        .subscribe();

    _conversationChannels[conversationId] = channel;
    debugPrint('📡 ReadReceipt: Listening to $conversationId');
  }

  /// پردازش آپدیت پیام
  void _handleMessageUpdate(PostgresChangePayload payload) {
    try {
      final data = payload.newRecord;
      final messageId = data['id'] as String;
      final senderId = data['sender_id'] as String?;
      final conversationId = data['conversation_id'] as String?;

      // فقط پیام‌های خودم را بررسی کن (برای نمایش تیک)
      if (senderId != _currentUserId) return;

      final isSent = data['is_sent'] as bool? ?? false;
      final isDelivered = data['is_delivered'] as bool? ?? false;
      final isSeen = data['is_seen'] as bool? ?? false;

      final deliveredAtStr = data['delivered_at'] as String?;
      final seenAtStr = data['seen_at'] as String?;

      MessageDeliveryStatus status;
      if (isSeen) {
        status = MessageDeliveryStatus.read;
      } else if (isDelivered) {
        status = MessageDeliveryStatus.delivered;
      } else if (isSent) {
        status = MessageDeliveryStatus.sent;
      } else {
        status = MessageDeliveryStatus.pending;
      }

      final statusInfo = MessageStatusInfo(
        messageId: messageId,
        status: status,
        deliveredAt: deliveredAtStr != null
            ? DateTime.parse(deliveredAtStr).toLocal()
            : null,
        seenAt: seenAtStr != null ? DateTime.parse(seenAtStr).toLocal() : null,
      );

      _statusCache[messageId] = statusInfo;
      _statusUpdatesController.add({messageId: statusInfo});

      // ✅ اگر این آخرین پیام مکالمه است، callback را صدا بزن
      if (conversationId != null) {
        final lastMessageId = _lastMessageIds[conversationId];
        if (lastMessageId == messageId && onLastMessageStatusChanged != null) {
          onLastMessageStatusChanged!(conversationId, status);
          debugPrint(
              '📬 Last message status updated: $conversationId -> $status');
        }
      }

      debugPrint('📬 Status update: $messageId -> $status');
    } catch (e) {
      debugPrint('❌ Error handling message update: $e');
    }
  }

  /// توقف گوش دادن به یک مکالمه
  void stopListening(String conversationId) {
    final channel = _conversationChannels.remove(conversationId);
    if (channel != null) {
      _supabase.removeChannel(channel);
      debugPrint('📴 ReadReceipt: Stopped listening to $conversationId');
    }

    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
      _flushPendingReads();
    }
  }

  /// ✅ ثبت آخرین پیام یک مکالمه (برای sync با لیست مکالمات)
  void setLastMessageId(String conversationId, String messageId) {
    _lastMessageIds[conversationId] = messageId;
    debugPrint('📌 Set last message: $conversationId -> $messageId');
  }

  /// ✅ دریافت آخرین پیام یک مکالمه
  String? getLastMessageId(String conversationId) {
    return _lastMessageIds[conversationId];
  }

  // کش تنظیمات حریم خصوصی
  bool? _sendReadReceiptsEnabled;
  DateTime? _settingsLastChecked;
  static const Duration _settingsCacheDuration = Duration(minutes: 5);

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔐 PRIVACY SETTINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// بررسی اینکه آیا کاربر فعلی اجازه ارسال Read Receipt دارد
  Future<bool> _canSendReadReceipts() async {
    final userId = _currentUserId;
    if (userId == null) return false;

    // استفاده از کش
    final now = DateTime.now();
    if (_sendReadReceiptsEnabled != null &&
        _settingsLastChecked != null &&
        now.difference(_settingsLastChecked!) < _settingsCacheDuration) {
      return _sendReadReceiptsEnabled!;
    }

    try {
      final settings = await _supabase
          .from('user_settings')
          .select('send_read_receipts')
          .eq('user_id', userId)
          .maybeSingle();

      _sendReadReceiptsEnabled =
          settings?['send_read_receipts'] as bool? ?? true;
      _settingsLastChecked = now;

      return _sendReadReceiptsEnabled!;
    } catch (e) {
      debugPrint('❌ Error checking read receipt settings: $e');
      // On error: prefer last known value; otherwise default to enabled.
      if (_sendReadReceiptsEnabled != null) return _sendReadReceiptsEnabled!;
      return true;
    }
  }

  /// رفرش کردن تنظیمات
  void invalidateSettingsCache() {
    _sendReadReceiptsEnabled = null;
    _settingsLastChecked = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ MARKING MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  /// علامت‌گذاری پیام به عنوان تحویل داده شده
  Future<void> markAsDelivered(String messageId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'delivered_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId)
          .neq('sender_id', userId); // فقط پیام‌های دریافتی

      debugPrint('✅ Marked as delivered: $messageId');
    } catch (e) {
      debugPrint('❌ Error marking as delivered: $e');
    }
  }

  /// علامت‌گذاری پیام به عنوان خوانده شده (با batch)
  void markAsRead(String messageId) {
    _pendingReadQueue.add(messageId);
    _scheduleBatchRead();
  }

  /// زمان‌بندی batch read
  void _scheduleBatchRead() {
    _batchReadTimer?.cancel();
    _batchReadTimer = Timer(_batchDelay, _flushPendingReads);
  }

  /// اجرای batch read
  Future<void> _flushPendingReads() async {
    if (_pendingReadQueue.isEmpty) return;

    final userId = _currentUserId;
    if (userId == null) return;

    // ✅ بررسی تنظیمات حریم خصوصی
    final canSend = await _canSendReadReceipts();
    if (!canSend) {
      debugPrint('🔒 Read receipts disabled by user settings');
      _pendingReadQueue.clear();
      return;
    }

    final messageIds = _pendingReadQueue.take(_maxBatchSize).toList();
    _pendingReadQueue.removeAll(messageIds);

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'is_seen': true,
            'delivered_at': now,
            'seen_at': now,
          })
          .inFilter('id', messageIds)
          .neq('sender_id', userId)
          .eq('is_seen', false);

      debugPrint('✅ Batch marked as read: ${messageIds.length} messages');

      // اگر هنوز پیام در صف هست، ادامه بده
      if (_pendingReadQueue.isNotEmpty) {
        _scheduleBatchRead();
      }
    } catch (e) {
      debugPrint('❌ Error in batch mark as read: $e');
      // برگرداندن به صف برای تلاش مجدد
      _pendingReadQueue.addAll(messageIds);
    }
  }

  /// علامت‌گذاری همه پیام‌های یک مکالمه
  Future<void> markAllAsRead(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    // ✅ بررسی تنظیمات حریم خصوصی
    final canSend = await _canSendReadReceipts();
    if (!canSend) {
      debugPrint('🔒 Read receipts disabled by user settings');
      return;
    }

    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase
          .from('messages')
          .update({
            'is_delivered': true,
            'is_seen': true,
            'delivered_at': now,
            'seen_at': now,
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_seen', false);

      debugPrint('✅ All messages marked as read in $conversationId');
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
    }
  }

  /// علامت‌گذاری پیام‌های قابل مشاهده در صفحه
  void markVisibleMessagesAsRead(List<String> messageIds) {
    for (final id in messageIds) {
      markAsRead(id);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📊 STATUS QUERIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// دریافت وضعیت کش شده
  MessageStatusInfo? getCachedStatus(String messageId) {
    return _statusCache[messageId];
  }

  /// دریافت وضعیت از سرور
  Future<MessageStatusInfo?> getMessageStatus(String messageId) async {
    // اول از کش
    if (_statusCache.containsKey(messageId)) {
      return _statusCache[messageId];
    }

    try {
      final response = await _supabase
          .from('messages')
          .select(
              'id, is_sent, is_delivered, is_seen, created_at, delivered_at, seen_at')
          .eq('id', messageId)
          .maybeSingle();

      if (response == null) return null;

      final status = _parseStatusFromData(response);
      _statusCache[messageId] = status;
      return status;
    } catch (e) {
      debugPrint('❌ Error getting message status: $e');
      return null;
    }
  }

  /// دریافت وضعیت چندین پیام
  Future<Map<String, MessageStatusInfo>> getMessagesStatus(
    List<String> messageIds,
  ) async {
    if (messageIds.isEmpty) return {};

    final results = <String, MessageStatusInfo>{};
    final uncachedIds = <String>[];

    // اول از کش
    for (final id in messageIds) {
      if (_statusCache.containsKey(id)) {
        results[id] = _statusCache[id]!;
      } else {
        uncachedIds.add(id);
      }
    }

    // سپس از سرور
    if (uncachedIds.isNotEmpty) {
      try {
        final response = await _supabase
            .from('messages')
            .select(
                'id, is_sent, is_delivered, is_seen, created_at, delivered_at, seen_at')
            .inFilter('id', uncachedIds);

        for (final data in response as List) {
          final status = _parseStatusFromData(data);
          _statusCache[status.messageId] = status;
          results[status.messageId] = status;
        }
      } catch (e) {
        debugPrint('❌ Error getting messages status: $e');
      }
    }

    return results;
  }

  MessageStatusInfo _parseStatusFromData(Map<String, dynamic> data) {
    final messageId = data['id'] as String;
    final isSent = data['is_sent'] as bool? ?? false;
    final isDelivered = data['is_delivered'] as bool? ?? false;
    final isSeen = data['is_seen'] as bool? ?? false;

    MessageDeliveryStatus status;
    if (isSeen) {
      status = MessageDeliveryStatus.read;
    } else if (isDelivered) {
      status = MessageDeliveryStatus.delivered;
    } else if (isSent) {
      status = MessageDeliveryStatus.sent;
    } else {
      status = MessageDeliveryStatus.pending;
    }

    final createdAtStr = data['created_at'] as String?;
    final deliveredAtStr = data['delivered_at'] as String?;
    final seenAtStr = data['seen_at'] as String?;

    return MessageStatusInfo(
      messageId: messageId,
      status: status,
      sentAt:
          createdAtStr != null ? DateTime.parse(createdAtStr).toLocal() : null,
      deliveredAt: deliveredAtStr != null
          ? DateTime.parse(deliveredAtStr).toLocal()
          : null,
      seenAt: seenAtStr != null ? DateTime.parse(seenAtStr).toLocal() : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🔢 UNREAD COUNT
  // ═══════════════════════════════════════════════════════════════════════════

  /// دریافت تعداد پیام‌های خوانده نشده در یک مکالمه
  Future<int> getUnreadCount(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    try {
      final response = await _supabase
          .from('messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_seen', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// استریم تعداد خوانده نشده‌ها
  Stream<int> watchUnreadCount(String conversationId) {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((messages) {
          return messages
              .where((m) =>
                  m['sender_id'] != userId &&
                  (m['is_seen'] == false || m['is_seen'] == null))
              .length;
        });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🧹 CLEANUP
  // ═══════════════════════════════════════════════════════════════════════════

  /// پاکسازی کش
  void clearCache() {
    _statusCache.clear();
  }

  /// آزادسازی منابع
  void dispose() {
    _batchReadTimer?.cancel();
    _flushPendingReads();

    for (final channel in _conversationChannels.values) {
      _supabase.removeChannel(channel);
    }
    _conversationChannels.clear();

    _statusUpdatesController.close();
    _statusCache.clear();

    debugPrint('🔴 TelegramReadReceiptService disposed');
  }
}
