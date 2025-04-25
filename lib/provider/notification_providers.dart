import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../model/notificationModel.dart';
import '../../../main.dart';

class NotificationsNotifier extends StateNotifier<List<NotificationModel>> {
  NotificationsNotifier() : super([]) {
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final response = await supabase
          .from('notifications')
          .select(
              '*, sender:profiles!notifications_sender_id_fkey(username, avatar_url, is_verified, verification_type)')
          .eq('recipient_id', userId)
          .order('created_at', ascending: false);

      final notifications =
          response.map((item) => NotificationModel.fromMap(item)).toList();

      state = notifications;
    } catch (e) {
      print("خطا در دریافت اعلان‌ها: $e");
    }
  }

  Future<void> deleteAllNotifications() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('recipient_id', userId)
          .eq('is_read', false);

      // به‌روزرسانی وضعیت در state
      state = state
          .map((notification) => notification.copyWith(isRead: true))
          .toList();
    } catch (e) {
      print('خطا در علامت‌گذاری اعلان‌ها به عنوان خوانده شده: $e');
    }
  }
}

// پروایدر برای مدیریت اعلان‌ها
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
        (ref) {
  return NotificationsNotifier();
});

// پروایدر برای وضعیت بارگذاری
final notificationsLoadingProvider = StateProvider<bool>((ref) => true);

// پروایدر برای بررسی وجود اعلان‌های جدید
final hasNewNotificationProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final userId = supabase.auth.currentUser?.id;
  if (userId == null) return false;

  final response = await supabase
      .from('notifications')
      .select('id')
      .eq('recipient_id', userId)
      .eq('is_read', false)
      .limit(1);

  return response.isNotEmpty;
});

// پروایدر برای تعداد اعلان‌های خوانده نشده
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(notificationsProvider);
  return notifications.where((notification) => !notification.isRead).length;
});

// پروایدر برای تعداد اعلان‌های هر تب
final notificationCountByTypeProvider =
    Provider.family<int, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);

  if (type == null || type == 'all') {
    return notifications.length;
  }

  return notifications
      .where((notification) => notification.type == type)
      .length;
});

// پروایدر برای فیلتر کردن اعلان‌ها بر اساس نوع
final filteredNotificationsProvider =
    Provider.family<List<NotificationModel>, String?>((ref, type) {
  final notifications = ref.watch(notificationsProvider);

  if (type == null || type == 'all') {
    return notifications;
  }

  return notifications
      .where((notification) => notification.type == type)
      .toList();
});
