import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      state = [];
      _isFetching = false;
      _hasMore = false;
      return;
    }

    if (refresh) {
      _page = 0;
      _hasMore = true;
      state = [];
    }

    try {
      final from = _page * _kPageSize;
      final to = from + _kPageSize - 1;
      final response = await supabase
          .from('notifications')
          .select(
              '*, sender:profiles!notifications_sender_id_fkey(username, avatar_url, is_verified, verification_type)')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .range(from, to);

      final notifications = (response as List)
          .map((item) => NotificationModel.fromMap(item))
          .toList();

      if (refresh) {
        state = notifications;
      } else {
        // تکراری اضافه نشود
        final existingIds = state.map((n) => n.id).toSet();
        state = [
          ...state,
          ...notifications.where((n) => !existingIds.contains(n.id))
        ];
      }

      if (notifications.length < _kPageSize) {
        _hasMore = false;
      } else {
        _hasMore = true;
        _page++;
      }
    } catch (e) {
      print("خطا در واکشی اعلان‌ها: $e");
      if (refresh) state = [];
      _hasMore = false;
    }
    _isFetching = false;
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
            final newData = payload.newRecord as Map<String, dynamic>;
            var notif = NotificationModel.fromMap(newData);
            try {
              final senderData = await supabase
                  .from('profiles')
                  .select(
                      'username, avatar_url, is_verified, verification_type')
                  .eq('id', newData['sender_id'])
                  .single();

              // ترکیب اطلاعات اعلان با پروفایل
              final completeData = {...newData, 'sender': senderData};

              var notif = NotificationModel.fromMap(completeData);
              if (!state.any((n) => n.id == notif.id)) {
                state = [notif, ...state];
                await _showLocalNotification(notif);
              }
            } catch (e) {
              print('خطا در دریافت اطلاعات فرستنده: $e');
            }

            if (!state.any((n) => n.id == notif.id)) {
              // برای اطمینان، پروفایل کامل را دوباره بگیر
              if (notif.username == null || notif.avatarUrl == null) {
                try {
                  final sender = await supabase
                      .from('profiles')
                      .select(
                          'username, avatar_url, is_verified, verification_type')
                      .eq('id', notif.senderId)
                      .maybeSingle();
                  if (sender != null) {
                    notif = notif.copyWith(
                      username: sender['username'] ?? notif.username,
                      avatarUrl: sender['avatar_url'] ?? notif.avatarUrl,
                      userIsVerified:
                          sender['is_verified'] ?? notif.userIsVerified,
                      verificationType:
                          sender['verification_type'] ?? notif.verificationType,
                    );
                  }
                } catch (_) {}
              }
              state = [notif, ...state];
              await _showLocalNotification(notif);
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

  // نمایش نوتیفیکیشن لوکال
  Future<void> _showLocalNotification(NotificationModel notif) async {
    String? title, body;
    final senderUsername = notif.username ?? 'کاربر';
    switch (notif.type) {
      case 'like':
        title = 'لایک جدید';
        body = '$senderUsername پست شما را لایک کرد';
        break;
      case 'comment':
        title = 'نظر جدید';
        body = '$senderUsername: ${notif.content ?? ""}';
        break;
      case 'reply_comment':
        title = 'پاسخ به نظر شما';
        body = '$senderUsername: ${notif.content ?? ""}';
        break;
      case 'follow':
        title = 'دنبال‌کننده جدید';
        body = '$senderUsername شما را دنبال کرد';
        break;
      default:
        title = 'اعلان';
        body = notif.content ?? '';
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
      print('خطا در علامت‌گذاری اعلان‌ها به عنوان خوانده شده: $e');
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
      print('خطا در خوانده‌شدن اعلان: $e');
    }
  }

  /// ریفِرش دستی (مثلاً برای pull to refresh)
  Future<void> refresh() async {
    await fetchNotifications(refresh: true);
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
