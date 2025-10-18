import '../security/logging_utility.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../../model/notificationModel.dart';
import '../../../main.dart';

final userIdProvider = Provider<String?>((ref) {
  return supabase.auth.currentUser?.id;
});

const int _kPageSize = 20;

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
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

  bool get hasMore => _hasMore;
  bool get isFetching => _isFetching;

  /// بارگیری (پایه، رفرش یا اولین بار)
  Future<void> fetchNotifications({bool refresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      logInfo('⚠️ کاربر لاگین نشده، اعلان‌ها بارگیری نمی‌شوند');
      state = [];
      _isFetching = false;
      _hasMore = false;
      return;
    }

    if (refresh) {
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
      if (refresh) {
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

              // ترکیب اطلاعات اعلان با پروفایل
              final completeData = {...newData, 'sender': senderData};
              final notif = NotificationModel.fromMap(completeData);

              // بررسی تکراری نبودن اعلان
              if (!state.any((n) => n.id == notif.id)) {
                state = [notif, ...state];
                await _showLocalNotification(notif);
                logInfo('✅ اعلان جدید به لیست اضافه شد: ${notif.type}');
              } else {
                logInfo('⚠️ اعلان تکراری نادیده گرفته شد: ${notif.id}');
              }
            } catch (e) {
              logInfo('❌ خطا در پردازش اعلان ریل تایم: $e');
              // در صورت خطا، اعلان ساده را اضافه کن
              try {
                final notif = NotificationModel.fromMap(payload.newRecord);
                if (!state.any((n) => n.id == notif.id)) {
                  state = [notif, ...state];
                  await _showLocalNotification(notif);
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
    switch (notif.type) {
      case 'like':
        title = 'لایک جدید';
        body = '$senderUsername پست شما را لایک کرد';
        break;
      case 'comment':
        title = 'نظر جدید';
        body = '$senderUsername: ${_filterLinksFromText(notif.content)}';
        break;
      case 'reply_comment':
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
      default:
        title = 'اعلان';
        body = notif.content;
    }
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'social_notifications',
          'اعلان‌های شبکه اجتماعی',
          channelDescription: 'اعلان رویدادهای اجتماعی',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: notif.id.toString(),
    );
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> deleteAllNotifications() async {
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) {
      state = [];
      return;
    }
    try {
      await supabase.from('notifications').delete().eq('recipient_id', userId);
      state = [];
    } catch (e) {
      print("خطا در حذف اعلان‌ها: $e");
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);

      state = [
        for (final notification in state)
          if (!notification.isRead)
            notification.copyWith(isRead: true)
          else
            notification
      ];
    } catch (e) {
      logInfo('خطا در علامت‌گذاری اعلان‌ها به عنوان خوانده شده: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _userId ?? supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('recipient_id', userId);

      state = [
        for (final notification in state)
          if (notification.id == notificationId)
            notification.copyWith(isRead: true)
          else
            notification
      ];
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
    try {
      await supabase.from('notifications').delete().eq('id', notificationId);
      state = state.where((n) => n.id != notificationId).toList();
    } catch (e) {
      logInfo('خطا در حذف اعلان: $e');
    }
  }

  /// حذف اعلان follow_request با شناسه
  Future<void> removeFollowRequestById(String notificationId) async {
    try {
      final notif = state.firstWhere(
        (n) => n.id == notificationId && n.type == 'follow_request',
        orElse: () => NotificationModel.empty(),
      );
      if (notif.id.isEmpty) return;
      await supabase.from('notifications').delete().eq('id', notificationId);
      state = state.where((n) => n.id != notificationId).toList();
    } catch (e) {
      logInfo('خطا در حذف اعلان درخواست دنبال کردن: $e');
    }
  }

  /// اضافه کردن اعلان جدید از FCM Push Notification
  void addNotificationFromPush(RemoteMessage message) {
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
    try {
      final userId = _userId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;

      // تست اتصال با یک درخواست ساده
      await supabase
          .from('notifications')
          .select('id')
          .eq('recipient_id', userId)
          .limit(1);

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
      .where((notification) => notification.type == type)
      .length;
});

/// فیلتر بر اساس نوع
final filteredNotificationsProvider =
    Provider.family<List<NotificationModel>, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);
  if (type == null || type == 'all') return notifications;
  return notifications
      .where((notification) => notification.type == type)
      .toList();
});
