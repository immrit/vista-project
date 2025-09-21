import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../provider/notification_provider.dart';

/// Provider برای دسترسی به PushNotificationService
final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

class PushNotificationService {
  final Ref ref;
  PushNotificationService(this.ref);

  final _firebaseMessaging = FirebaseMessaging.instance;
  final _supabase = Supabase.instance.client;
  final _flutterLocalNotifications = FlutterLocalNotificationsPlugin();

  /// این متغیر لیست اعلان‌های دریافتی رو نگه میداره
  final List<RemoteMessage> _notifications = [];
  List<RemoteMessage> get notifications => _notifications;

  /// مقداردهی اولیه سرویس
  Future<void> init(BuildContext context) async {
    try {
      // بررسی اینکه Firebase initialize شده یا نه
      if (Firebase.apps.isEmpty) {
        print(
          '⚠️ Firebase not initialized, skipping PushNotificationService init',
        );
        return;
      }

      // درخواست اجازه دسترسی به نوتیفیکیشن (iOS / Android 13+)
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // مقداردهی flutter_local_notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOSInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iOSInit,
      );

      await _flutterLocalNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            try {
              final data = jsonDecode(details.payload!) as Map<String, dynamic>;

              // هندل پاسخ سریع
              if (details.actionId == 'reply' && details.input != null) {
                final conversationId = data['conversation_id'];
                if (conversationId != null &&
                    conversationId.toString().isNotEmpty) {
                  handleQuickReply(conversationId.toString(), details.input!);
                }
              } else {
                // هندل ناوبری عادی
                handleNotificationNavigation(context, data);
              }
            } catch (e) {
              print('❌ خطا در پردازش payload نوتیفیکیشن: $e');
            }
          }
        },
      );

      // گرفتن و ذخیره توکن FCM در سوپابیس
      await _saveFcmToken();

      // گوش دادن به پیام‌ها در فورگراند
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _notifications.add(message);
        _showNotification(message);

        // اضافه کردن اعلان به notificationsProvider
        _addNotificationToProvider(message);
      });

      // وقتی کاربر روی نوتیفیکیشن در بک‌گراند کلیک می‌کنه
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        handleNotificationNavigation(context, message.data);
      });

      // اگر اپ از حالت بسته با نوتیف باز شد
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        handleNotificationNavigation(context, initialMessage.data);
      }
    } catch (e) {
      print('❌ خطا در راه‌اندازی PushNotificationService: $e');
    }
  }

  /// ذخیره توکن FCM در جدول profiles
  Future<void> _saveFcmToken() async {
    try {
      // بررسی اینکه Firebase initialize شده یا نه
      if (Firebase.apps.isEmpty) {
        print('⚠️ Firebase not initialized, skipping FCM token save');
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        final user = _supabase.auth.currentUser;
        if (user != null) {
          await _supabase
              .from("profiles")
              .update({"fcm_token": token})
              .eq("id", user.id);
          print('✅ FCM Token با موفقیت در سوپابیس ذخیره شد');
        } else {
          print('⚠️ کاربر لاگین نشده، FCM Token ذخیره نشد');
        }
      } else {
        print('⚠️ FCM Token دریافت نشد');
      }
    } catch (e) {
      print('❌ خطا در ذخیره FCM Token: $e');
    }
  }

  /// نمایش نوتیفیکیشن لوکال در فورگراند
  Future<void> _showNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    // تعیین نوع کانال بر اساس نوع اعلان
    String channelId = 'default_channel_id';
    String channelName = 'عمومی';
    String channelDescription = 'اعلان‌های عمومی';
    List<AndroidNotificationAction>? actions;

    final type = data['type'];
    if (type == 'chat_message') {
      channelId = 'chat_messages';
      channelName = 'پیام‌های چت';
      channelDescription = 'اعلان پیام‌های جدید چت';

      // اضافه کردن دکمه پاسخ سریع برای چت
      actions = [
        AndroidNotificationAction(
          'reply',
          'پاسخ',
          inputs: [AndroidNotificationActionInput()],
          showsUserInterface: true,
        ),
      ];
    } else if (type == 'like' ||
        type == 'new_comment' ||
        type == 'comment_reply' ||
        type == 'follow') {
      channelId = 'social_notify';
      channelName = 'اعلان اجتماعی';
      channelDescription = 'اعلان‌های اجتماعی (لایک، کامنت، دنبال‌کننده و ...)';
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      actions: actions,
    );

    const iOSDetails = DarwinNotificationDetails();

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    // استفاده از محتوای FCM data یا notification body
    final title = data['title'] ?? notification?.title ?? 'اعلان جدید';
    String body =
        data['message'] ?? data['content'] ?? notification?.body ?? '';

    await _flutterLocalNotifications.show(
      message.hashCode,
      title,
      _shorten(body),
      platformDetails,
      payload: jsonEncode(message.data),
    );
  }

  /// کوتاه کردن متن طولانی
  String _shorten(String text, [int maxLength = 80]) {
    if (text.length <= maxLength) return text;
    return "${text.substring(0, maxLength)}...";
  }

  /// هدایت کاربر به صفحات مرتبط بر اساس دیتای ارسالی سرور
  void handleNotificationNavigation(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    // لاگ امن: از چاپ کامل دیتای اعلان خودداری کنید
    try {
      final keys = data.keys.take(6).join(',');
      debugPrint("🔀 [Navigation] هدایت بر اساس اعلان؛ کلیدها: $keys");
    } catch (_) {}
    final openScreen = data["open_screen"];

    switch (openScreen) {
      case "chat":
        final conversationId = data["conversation_id"];
        if (conversationId != null && conversationId.toString().isNotEmpty) {
          Navigator.pushNamed(context, "/chat", arguments: conversationId);
        }
        break;

      case "post":
        final postId = data["post_id"];
        if (postId != null && postId.toString().isNotEmpty) {
          Navigator.pushNamed(
            context,
            "/post-detail",
            arguments: {'postId': postId},
          );
        }
        break;

      case "profile":
        final followerId = data["follower_id"];
        if (followerId != null && followerId.toString().isNotEmpty) {
          Navigator.pushNamed(
            context,
            "/profile",
            arguments: {'username': '', 'userId': followerId},
          );
        }
        break;

      default:
        debugPrint("⚠ اعلان با صفحه‌ی مقصد ناشناخته دریافت شد: $openScreen");
        break;
    }
  }

  /// هندل پاسخ سریع به اعلان چت
  Future<void> handleQuickReply(String conversationId, String replyText) async {
    try {
      // ارسال پیام به سرور
      // اینجا باید ChatService یا سرویس مربوطه را فراخوانی کنید
      print('📱 پاسخ سریع ارسال شد: $replyText به چت $conversationId');

      // TODO: پیاده‌سازی ارسال پیام به سرور
      // await ChatService().sendMessage(
      //   conversationId: conversationId,
      //   content: replyText,
      // );
    } catch (e) {
      print('❌ خطا در ارسال پاسخ سریع: $e');
    }
  }

  /// اضافه کردن اعلان به notificationsProvider
  void _addNotificationToProvider(RemoteMessage message) {
    try {
      // استفاده از ref.read برای دسترسی به notificationsProvider
      final notifier = ref.read(notificationsProvider.notifier);
      notifier.addNotificationFromPush(message);
      print('✅ اعلان با موفقیت به provider اضافه شد');
    } catch (e) {
      print('❌ خطا در اضافه کردن اعلان به provider: $e');
      print('Stack trace: ${StackTrace.current}');
    }
  }
}
