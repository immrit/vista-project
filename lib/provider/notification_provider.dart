import 'dart:convert';
import '../security/logging_utility.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../model/notificationModel.dart';
import '../utils/const.dart';
import '../services/local_notification_center.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    LocalNotificationCenter.plugin;

final userIdProvider = Provider<String?>((ref) {
  return supabase.auth.currentUser?.id;
});

const int _kPageSize = 20;

enum FollowRequestActionState { success, alreadyHandled, failed }

class FollowRequestActionResult {
  const FollowRequestActionResult(this.state, this.message);

  final FollowRequestActionState state;
  final String message;

  bool get isSuccess => state == FollowRequestActionState.success;
}

bool notificationTypeMatchesFilter(
    String notificationType, String? filterType) {
  if (filterType == null || filterType == 'all') return true;

  final canonicalType = NotificationModel.canonicalType(notificationType);
  final canonicalFilter = NotificationModel.canonicalType(filterType);

  switch (canonicalFilter) {
    case 'follow':
      return canonicalType == 'follow' ||
          canonicalType == 'follow_request' ||
          canonicalType == 'follow_request_accepted';
    case 'comment':
      return canonicalType == 'comment';
    case 'comment_reply':
      return canonicalType == 'comment_reply';
    case 'follow_request':
      return canonicalType == 'follow_request';
    case 'daily_suggestion_digest':
      return canonicalType == 'daily_suggestion_digest' ||
          canonicalType == 'suggest_follow' ||
          canonicalType == 'suggest_post';
    default:
      return canonicalType == canonicalFilter;
  }
}

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  static const bool _showRealtimeLocalNotifications = false;

  NotificationsNotifier(this._ref) : super([]) {
    _userId = _ref.read(userIdProvider);
    if (_userId != null) {
      fetchNotifications(refresh: true);
      _subscribeToNotificationRealtime();
    }
    // گوش دادن به تغییر کاربر:
    _ref.listen<String?>(userIdProvider, (prev, next) {
      if (prev != next) {
        _userId = next;
        _unsubscribe();
        state = [];
        _page = 0;
        _hasMore = true;
        if (_userId != null) {
          fetchNotifications(refresh: true);
          _subscribeToNotificationRealtime();
        }
      }
    });
  }

  final Ref _ref;
  RealtimeChannel? _channel;
  String? _userId;

  int _page = 0;
  bool _isFetching = false;
  bool _hasMore = true;
  bool _isDisposed = false; // ✅ Flag برای چک کردن dispose

  bool get hasMore => _hasMore;
  bool get isFetching => _isFetching;

  /// بارگیری (پایه، رفرش یا اولین بار)
  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isFetching || _isDisposed) return; // ✅ چک کردن dispose
    _isFetching = true;

    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo('⚠️ کاربر لاگین نشده، اعلان‌ها بارگیری نمی‌شوند');
      if (!_isDisposed) {
        state = [];
      }
      _isFetching = false;
      _hasMore = false;
      return;
    }

    if (refresh && !_isDisposed) {
      _page = 0;
      _hasMore = true;
      state = [];
      logInfo('🔄 شروع رفرش اعلان‌ها...');
    }

    try {
      final from = _page * _kPageSize;
      final to = from + _kPageSize - 1;

      logInfo('📡 درخواست اعلان‌ها از $from تا $to');

      final response = await supabase
          .from('notifications')
          .select(
              '*, sender:profiles!notifications_sender_id_fkey(username, full_name, avatar_url, is_verified, verification_type)')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      // ✅ چک کردن dispose بعد از async operation
      if (_isDisposed) {
        logInfo('⚠️ Notifier disposed, skipping state update');
        return;
      }

      final notifications = (response as List)
          .map((item) => NotificationModel.fromMap(item))
          .toList();

      logInfo('📥 ${notifications.length} اعلان دریافت شد');

      if (refresh) {
        state = notifications;
        logInfo('✅ اعلان‌ها رفرش شدند');
      } else {
        // تکراری اضافه نشود
        final existingIds = state.map((n) => n.id).toSet();
        final newNotifications =
            notifications.where((n) => !existingIds.contains(n.id)).toList();
        state = [...state, ...newNotifications];
        logInfo('➕ ${newNotifications.length} اعلان جدید اضافه شد');
      }

      if (notifications.length < _kPageSize) {
        _hasMore = false;
        logInfo('📄 آخرین صفحه اعلان‌ها بارگیری شد');
      } else {
        _hasMore = true;
        _page++;
        logInfo('📄 صفحه بعدی آماده: $_page');
      }
    } catch (e) {
      print("❌ خطا در واکشی اعلان‌ها: $e");
      if (refresh && !_isDisposed) {
        state = [];
        logInfo('🔄 لیست اعلان‌ها پاک شد به دلیل خطا');
      }
      _hasMore = false;
    } finally {
      _isFetching = false;
    }
  }

  /// بارگیری صفحه بعد (برای لیزی لودینگ)
  Future<void> fetchMore() async {
    if (_hasMore && !_isFetching) {
      await fetchNotifications();
    }
  }

  /// پشتیبانی کامل از ریل تایم (افزودن اعلان جدید بالای لیست)
  void _subscribeToNotificationRealtime() {
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;
    _unsubscribe();

    _channel = supabase.channel('public:notifications').onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: (payload) async {
            // ✅ چک کردن dispose قبل از پردازش
            if (_isDisposed) {
              logInfo('⚠️ Notifier disposed, ignoring realtime notification');
              return;
            }

            try {
              final newData = payload.newRecord;
              logInfo('🔔 اعلان جدید دریافت شد: ${newData['type']}');

              // دریافت اطلاعات کامل فرستنده
              final senderData = await supabase
                  .from('profiles')
                  .select(
                      'username, full_name, avatar_url, is_verified, verification_type')
                  .eq('id', newData['sender_id'])
                  .single();

              // ✅ چک کردن dispose بعد از async operation
              if (_isDisposed) {
                logInfo('⚠️ Notifier disposed during realtime processing');
                return;
              }

              // ترکیب اطلاعات اعلان با پروفایل
              final completeData = {...newData, 'sender': senderData};
              final notif = NotificationModel.fromMap(completeData);

              // بررسی تکراری نبودن اعلان
              if (!state.any((n) => n.id == notif.id)) {
                state = [notif, ...state];
                if (_showRealtimeLocalNotifications) {
                  await _showLocalNotification(notif);
                }
                logInfo('✅ اعلان جدید به لیست اضافه شد: ${notif.type}');
              } else {
                logInfo('⚠️ اعلان تکراری نادیده گرفته شد: ${notif.id}');
              }
            } catch (e) {
              logInfo('❌ خطا در پردازش اعلان ریل تایم: $e');

              // ✅ چک کردن dispose قبل از fallback
              if (_isDisposed) return;

              // در صورت خطا، اعلان ساده را اضافه کن
              try {
                final notif = NotificationModel.fromMap(payload.newRecord);
                if (!state.any((n) => n.id == notif.id)) {
                  state = [notif, ...state];
                  if (_showRealtimeLocalNotifications) {
                    await _showLocalNotification(notif);
                  }
                }
              } catch (fallbackError) {
                logInfo('❌ خطا در fallback اعلان: $fallbackError');
              }
            }
          },
        )..subscribe();
  }

  void _unsubscribe() {
    if (_channel != null) {
      try {
        supabase.removeChannel(_channel!);
      } catch (_) {}
      _channel = null;
    }
  }

  /// فیلتر کردن لینک‌ها از متن
  String _filterLinksFromText(String text) {
    if (text.isEmpty) return text;

    // فیلتر کردن لینک‌های Vista و پست‌های اشتراکی
    String filteredText = text;

    // حذف لینک‌های Vista
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*vista[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*post/[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*coffevista[^\s]*'), '');
    filteredText =
        filteredText.replaceAll(RegExp(r'https?://[^\s]*arvan[^\s]*'), '');

    // حذف لینک‌های عمومی
    filteredText = filteredText.replaceAll(RegExp(r'https?://[^\s]*'), '');

    // حذف metadata های پست‌های اشتراکی
    filteredText = filteredText.replaceAll(RegExp(r'🖼️ آواتار:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🎥 ویدیو:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🏷️ تگ‌ها:.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'🔗.*'), '');
    filteredText = filteredText.replaceAll(RegExp(r'📝 پست از.*'), '');

    return filteredText.trim();
  }

  // نمایش نوتیفیکیشن لوکال
  Future<void> _showLocalNotification(NotificationModel notif) async {
    String? title, body;
    final senderUsername = notif.username.isNotEmpty ? notif.username : 'کاربر';
    final notificationType = NotificationModel.canonicalType(notif.type);

    switch (notificationType) {
      case 'like':
        title = 'لایک جدید';
        body = '$senderUsername پست شما را لایک کرد';
        break;
      case 'comment':
        title = 'نظر جدید';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'comment_reply':
        title = 'پاسخ به نظر شما';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'follow':
        title = 'دنبال‌کننده جدید';
        body = '$senderUsername شما را دنبال کرد';
        break;
      case 'follow_request':
        title = 'درخواست دنبال کردن';
        body = '$senderUsername درخواست دنبال کردن داد';
        break;
      case 'follow_request_accepted':
        title = 'درخواست پذیرفته شد';
        body = '$senderUsername درخواست دنبال کردن شما را پذیرفت';
        break;
      case 'message':
      case 'new_message':
        title = 'پیام جدید';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'reaction':
      case 'message_reaction':
        title = 'واکنش جدید';
        body = '$senderUsername به پیام شما واکنش نشان داد';
        break;
      case 'mention':
        title = 'منشن جدید';
        body = '$senderUsername شما را منشن کرد';
        break;
      case 'suggest_follow':
        title = 'پیشنهاد دنبال‌کردن';
        body = notif.content.isNotEmpty
            ? notif.content
            : 'چند کاربر جدید برای دنبال‌کردن پیشنهاد شد';
        break;
      case 'suggest_post':
        title = 'پیشنهاد پست';
        body = notif.content.isNotEmpty
            ? notif.content
            : 'یک پست جدید پیشنهادی برای شما آماده است';
        break;
      case 'daily_suggestion_digest':
        title = 'پیشنهادهای امروز';
        body = notif.content.isNotEmpty
            ? notif.content
            : 'پیشنهادهای روزانه شما آماده است';
        break;
      default:
        title = 'اعلان';
        body = notif.content;
    }

    // ✅ ساخت payload کامل
    final payloadMap = notif.toPayloadJson();
    final payloadJson = jsonEncode(payloadMap);

    // 🔍 DEBUG: چاپ اطلاعات کامل
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📢 نمایش Local Notification:');
    print('   Type: ${notif.type}');
    print('   ID: ${notif.id}');
    print('   Sender: ${notif.senderId}');
    print('   PostID: ${notif.postId}');
    print('   CommentID: ${notif.commentId}');
    print('   ConversationID: ${notif.conversationId}');
    print('   Payload JSON: $payloadJson');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'social_notify',
          'فعالیت‌های اجتماعی',
          channelDescription: 'اعلان رویدادهای اجتماعی',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payloadJson, // ✅ JSON کامل
    );
  }

  @override
  void dispose() {
    _isDisposed = true; // ✅ علامت‌گذاری dispose
    _unsubscribe();
    super.dispose();
  }

  Future<void> deleteAllNotifications() async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      if (!_isDisposed) {
        state = [];
      }
      return;
    }
    try {
      await supabase.from('notifications').delete().eq('recipient_id', userId);
      if (!_isDisposed) {
        state = [];
      }
    } catch (e) {
      print("خطا در حذف اعلان‌ها: $e");
    }
  }

  Future<void> markAllAsRead() async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);

      if (!_isDisposed) {
        state = [
          for (final notification in state)
            if (!notification.isRead)
              notification.copyWith(isRead: true)
            else
              notification
        ];
      }
    } catch (e) {
      logInfo('خطا در علامت‌گذاری اعلان‌ها به عنوان خوانده شده: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('recipient_id', userId);

      if (!_isDisposed) {
        state = [
          for (final notification in state)
            if (notification.id == notificationId)
              notification.copyWith(isRead: true)
            else
              notification
        ];
      }
    } catch (e) {
      logInfo('خطا در خوانده‌شدن اعلان: $e');
    }
  }

  /// ریفِرش دستی (مثلاً برای pull to refresh)
  Future<void> refresh() async {
    await fetchNotifications(refresh: true);
  }

  /// حذف یک اعلان به صورت تکی (از دیتابیس و استیت)
  Future<void> removeNotification(String notificationId) async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);
      if (!_isDisposed) {
        state = state.where((n) => n.id != notificationId).toList();
      }
    } catch (e) {
      logInfo('خطا در حذف اعلان: $e');
    }
  }

  /// حذف اعلان follow_request با شناسه
  Future<void> removeFollowRequestById(String notificationId) async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    try {
      final notif = state.firstWhere(
        (n) =>
            n.id == notificationId &&
            NotificationModel.canonicalType(n.type) == 'follow_request',
        orElse: () => NotificationModel.empty(),
      );
      if (notif.id.isEmpty) return;
      await supabase.from('notifications').delete().eq('id', notificationId);
      if (!_isDisposed) {
        state = state.where((n) => n.id != notificationId).toList();
      }
    } catch (e) {
      logInfo('خطا در حذف اعلان درخواست دنبال کردن: $e');
    }
  }

  Future<void> _cleanupFollowRequestNotifications({
    required String requesterId,
    required String recipientId,
    String? notificationId,
  }) async {
    if (_isDisposed) return;

    final idsToDelete = <String>{};
    if (notificationId != null && notificationId.isNotEmpty) {
      idsToDelete.add(notificationId);
    }

    try {
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', recipientId)
          .eq('sender_id', requesterId)
          .eq('type', 'follow_request');

      for (final row in (response as List<dynamic>)) {
        final id = row['id']?.toString();
        if (id != null && id.isNotEmpty) {
          idsToDelete.add(id);
        }
      }

      if (idsToDelete.isNotEmpty) {
        await supabase
            .from('notifications')
            .delete()
            .inFilter('id', idsToDelete.toList(growable: false));
      }
    } catch (e) {
      logInfo('خطا در پاکسازی اعلان‌های follow request: $e');
      if (notificationId != null && notificationId.isNotEmpty) {
        try {
          await supabase
              .from('notifications')
              .delete()
              .eq('id', notificationId);
          idsToDelete.add(notificationId);
        } catch (_) {}
      }
    }

    if (!_isDisposed) {
      state = state.where((n) {
        if (idsToDelete.contains(n.id)) return false;

        final isMatchingPair =
            NotificationModel.canonicalType(n.type) == 'follow_request' &&
                n.senderId == requesterId &&
                n.recipientId == recipientId;
        return !isMatchingPair;
      }).toList(growable: false);
    }
  }

  Future<FollowRequestActionResult> respondToFollowRequest({
    required String requesterId,
    required bool accept,
    String? notificationId,
  }) async {
    if (_isDisposed) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'سیستم اعلان در دسترس نیست',
      );
    }

    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'ابتدا وارد حساب کاربری شوید',
      );
    }
    if (requesterId.isEmpty) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'شناسه درخواست نامعتبر است',
      );
    }
    if (requesterId == userId) {
      return const FollowRequestActionResult(
        FollowRequestActionState.failed,
        'شما نمی‌توانید درخواست خودتان را مدیریت کنید',
      );
    }

    try {
      final request = await supabase
          .from('follow_requests')
          .select('id, status')
          .eq('requester_id', requesterId)
          .eq('recipient_id', userId)
          .maybeSingle();

      if (request == null) {
        await _cleanupFollowRequestNotifications(
          requesterId: requesterId,
          recipientId: userId,
          notificationId: notificationId,
        );
        return const FollowRequestActionResult(
          FollowRequestActionState.alreadyHandled,
          'این درخواست قبلا مدیریت شده است',
        );
      }

      final requestId = request['id']?.toString();
      if (requestId == null || requestId.isEmpty) {
        return const FollowRequestActionResult(
          FollowRequestActionState.failed,
          'شناسه درخواست معتبر نیست',
        );
      }

      final status = (request['status'] as String? ?? '').toLowerCase().trim();
      if (status != 'pending') {
        await _cleanupFollowRequestNotifications(
          requesterId: requesterId,
          recipientId: userId,
          notificationId: notificationId,
        );
        return FollowRequestActionResult(
          FollowRequestActionState.alreadyHandled,
          'این درخواست در وضعیت "$status" قرار دارد',
        );
      }

      if (accept) {
        await supabase.from('follows').upsert(
          {
            'follower_id': requesterId,
            'following_id': userId,
            'created_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'follower_id,following_id',
        );

        final updated = await supabase
            .from('follow_requests')
            .update({'status': 'accepted'})
            .eq('id', requestId)
            .eq('status', 'pending')
            .select('id')
            .maybeSingle();

        if (updated == null) {
          await _cleanupFollowRequestNotifications(
            requesterId: requesterId,
            recipientId: userId,
            notificationId: notificationId,
          );
          return const FollowRequestActionResult(
            FollowRequestActionState.alreadyHandled,
            'این درخواست قبلا مدیریت شده است',
          );
        }

        try {
          await supabase.from('notifications').insert({
            'recipient_id': requesterId,
            'sender_id': userId,
            'type': 'follow_request_accepted',
            'content': 'درخواست دنبال کردن شما پذیرفته شد',
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });
        } catch (_) {}
      } else {
        final updated = await supabase
            .from('follow_requests')
            .update({'status': 'rejected'})
            .eq('id', requestId)
            .eq('status', 'pending')
            .select('id')
            .maybeSingle();

        if (updated == null) {
          await _cleanupFollowRequestNotifications(
            requesterId: requesterId,
            recipientId: userId,
            notificationId: notificationId,
          );
          return const FollowRequestActionResult(
            FollowRequestActionState.alreadyHandled,
            'این درخواست قبلا مدیریت شده است',
          );
        }
      }

      await _cleanupFollowRequestNotifications(
        requesterId: requesterId,
        recipientId: userId,
        notificationId: notificationId,
      );

      return FollowRequestActionResult(
        FollowRequestActionState.success,
        accept ? 'درخواست با موفقیت پذیرفته شد' : 'درخواست رد شد',
      );
    } catch (e) {
      return FollowRequestActionResult(
        FollowRequestActionState.failed,
        'خطا در پردازش درخواست: $e',
      );
    }
  }

  /// اضافه کردن اعلان جدید از FCM Push Notification
  void addNotificationFromPush(RemoteMessage message) {
    if (_isDisposed) return; // ✅ چک کردن dispose
    try {
      final notification = NotificationModel.fromFCM(message);

      // بررسی تکراری نبودن اعلان
      if (!state.any((n) => n.id == notification.id)) {
        // اضافه کردن به ابتدای لیست (جدیدترین اول)
        state = [notification, ...state];
        logInfo('✅ اعلان جدید از FCM اضافه شد: ${notification.type}');
      } else {
        logInfo('⚠️ اعلان FCM تکراری نادیده گرفته شد: ${notification.id}');
      }
    } catch (e) {
      logInfo('❌ خطا در اضافه کردن اعلان از FCM: $e');
    }
  }

  /// بررسی وضعیت اتصال و تلاش مجدد در صورت نیاز
  Future<void> checkConnectionAndRetry() async {
    if (_isDisposed) return; // ✅ چک کردن dispose
    try {
      final userId = _userId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;

      // تست اتصال با یک درخواست ساده
      await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .limit(1);

      // ✅ چک کردن dispose بعد از async operation
      if (_isDisposed) return;

      // اگر اتصال برقرار است و لیست خالی است، اعلان‌ها را بارگیری کن
      if (state.isEmpty) {
        await fetchNotifications(refresh: true);
      }
    } catch (e) {
      logInfo('❌ خطا در بررسی اتصال: $e');
    }
  }
}

// پروایدر اصلی (autoDispose برای آزاد شدن منابع در صورت خروج از صفحه)
final notificationsProvider = StateNotifierProvider.autoDispose<
    NotificationsNotifier, List<NotificationModel>>(
  (ref) => NotificationsNotifier(ref),
);

// استیت پروایدرها و پراوایدرهای کمکی:

/// وضعیت لودینگ اعلان (برای نشون‌دادن شرمر یا progress)
final notificationsLoadingProvider = StateProvider<bool>((ref) => false);

/// آیا اعلان خوانده نشده وجود دارد؟
final hasNewNotificationProvider = Provider.autoDispose<bool>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.any((n) => !n.isRead);
});

/// تعداد اعلان‌های خوانده نشده
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((notification) => !notification.isRead).length;
});

/// تعداد اعلان‌ها بر اساس نوع (تب‌ها)
final notificationCountByTypeProvider =
    Provider.family<int, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') return notifications.length;
  return notifications
      .where((notification) => notificationTypeMatchesFilter(
            notification.type,
            type,
          ))
      .length;
});

/// فیلتر بر اساس نوع
final filteredNotificationsProvider =
    Provider.family<List<NotificationModel>, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') return notifications;
  return notifications
      .where((notification) => notificationTypeMatchesFilter(
            notification.type,
            type,
          ))
      .toList();
});

final unreadNotificationCountByFilterProvider =
    Provider.family<int, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') {
    return notifications.where((n) => !n.isRead).length;
  }
  return notifications
      .where((n) => !n.isRead && notificationTypeMatchesFilter(n.type, type))
      .length;
});
