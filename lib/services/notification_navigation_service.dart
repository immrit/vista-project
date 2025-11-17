import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../model/notificationModel.dart';

class NotificationNavigationService {
  /// هدایت به صفحه مناسب بر اساس نوع اعلان
  static Future<void> handleNotificationNavigation({
    required BuildContext context,
    required NotificationModel notification,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🧭 handleNotificationNavigation:');
    print('   Type: ${notification.type}');
    print('   ID: ${notification.id}');
    print('   PostID: ${notification.postId}');
    print('   CommentID: ${notification.commentId}');
    print('   ConversationID: ${notification.conversationId}');
    print('   SenderID: ${notification.senderId}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // ✅ علامت‌گذاری به عنوان خوانده شده
      try {
        await _markAsRead(notification.id);
        print('✅ اعلان به عنوان خوانده شده علامت‌گذاری شد');
      } catch (e) {
        print('⚠️ خطا در علامت‌گذاری خوانده شده: $e');
      }

      // ✅ Navigation بر اساس نوع
      switch (notification.type) {
        case 'message':
        case 'new_message':
          print('📬 نوع پیام - شروع navigation به چت');
          print('   ConversationID: ${notification.conversationId}');
          await _navigateToChat(context, notification);
          break;

        case 'like':
        case 'post_like':
          print('❤️ نوع لایک - navigation به پست');
          await _navigateToPost(context, notification.postId);
          break;

        case 'comment':
        case 'post_comment':
          print('💬 نوع کامنت - navigation به کامنت‌ها');
          await _navigateToPostComments(
            context,
            notification.postId,
            notification.commentId,
          );
          break;

        case 'reply_comment':
          print('↩️ نوع پاسخ کامنت - navigation به کامنت‌ها');
          await _navigateToCommentReply(
            context,
            notification.postId,
            notification.commentId,
            notification.parentCommentId,
          );
          break;

        case 'follow':
        case 'follow_request':
        case 'follow_request_accepted':
          print('👤 نوع follow - navigation به پروفایل');
          await _navigateToProfile(context, notification.senderId);
          break;

        case 'reaction':
        case 'message_reaction':
          print('😊 نوع reaction - navigation به چت');
          await _navigateToChat(context, notification);
          break;

        case 'mention':
          if (notification.postId != null) {
            print('📝 نوع mention - navigation به پست');
            await _navigateToPost(context, notification.postId);
          } else {
            print('⚠️ Mention بدون postId - navigation به اعلان‌ها');
            await _navigateToNotifications(context);
          }
          break;

        default:
          print('⚠️ نوع ناشناخته: ${notification.type}');
          await _navigateToNotifications(context);
      }
      print('✅ Navigation completed');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      print('❌ خطا در navigation اعلان:');
      print('   Error: $e');
      print('   Stack: $stack');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _navigateToNotifications(context);
    }
  }

  /// علامت‌گذاری اعلان به عنوان خوانده شده
  static Future<void> _markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);
    } catch (e) {
      print('⚠️ خطا در mark as read: $e');
    }
  }

  /// هدایت به پست
  static Future<void> _navigateToPost(
    BuildContext context,
    String? postId,
  ) async {
    if (postId == null || postId.isEmpty) {
      await _navigateToNotifications(context);
      return;
    }

    try {
      // بررسی موجود بودن route
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // باز کردن جزئیات پست
      Navigator.of(context).pushNamed(
        '/post-detail',
        arguments: {'postId': postId},
      );

      print('✅ هدایت به پست: $postId');
    } catch (e) {
      print('❌ خطا در navigation به پست: $e');
      await _navigateToNotifications(context);
    }
  }

  /// هدایت به کامنت‌های پست
  static Future<void> _navigateToPostComments(
    BuildContext context,
    String? postId,
    String? commentId,
  ) async {
    if (postId == null || postId.isEmpty) {
      await _navigateToNotifications(context);
      return;
    }

    try {
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // اگر ID کامنت خاص داریم
      if (commentId != null && commentId.isNotEmpty) {
        Navigator.of(context).pushNamed(
          '/post-detail',
          arguments: {
            'postId': postId,
            'highlightCommentId': commentId, // برای هایلایت کردن کامنت
          },
        );
      } else {
        Navigator.of(context).pushNamed(
          '/post-detail',
          arguments: {'postId': postId},
        );
      }

      print('✅ هدایت به کامنت‌ها: post=$postId, comment=$commentId');
    } catch (e) {
      print('❌ خطا در navigation به کامنت‌ها: $e');
      await _navigateToPost(context, postId);
    }
  }

  /// هدایت به پاسخ کامنت
  static Future<void> _navigateToCommentReply(
    BuildContext context,
    String? postId,
    String? commentId,
    String? parentCommentId,
  ) async {
    // برای reply، به صفحه کامنت‌ها می‌ریم و کامنت پدر رو هایلایت می‌کنیم
    await _navigateToPostComments(context, postId, parentCommentId ?? commentId);
  }

  /// هدایت به پروفایل کاربر
  static Future<void> _navigateToProfile(
    BuildContext context,
    String? userId,
  ) async {
    if (userId == null || userId.isEmpty) {
      await _navigateToNotifications(context);
      return;
    }

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // اگر خودش بود، به پروفایل شخصی برود
      if (userId == currentUserId) {
        Navigator.of(context).pushNamed('/profile');
      } else {
        Navigator.of(context).pushNamed(
          '/profile',
          arguments: {'username': '', 'userId': userId},
        );
      }

      print('✅ هدایت به پروفایل: $userId');
    } catch (e) {
      print('❌ خطا در navigation به پروفایل: $e');
      await _navigateToNotifications(context);
    }
  }

  /// هدایت به چت
  static Future<void> _navigateToChat(
    BuildContext context,
    NotificationModel notification,
  ) async {
    print('🔍 _navigateToChat:');
    print('   ConversationID: ${notification.conversationId}');
    print('   SenderID: ${notification.senderId}');

    // چک کردن conversationId
    if (notification.conversationId != null &&
        notification.conversationId!.isNotEmpty) {
      print('✅ استفاده از conversationId از payload');
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'conversationId': notification.conversationId,
          'otherUserId': notification.senderId,
          'username': notification.username,
          'avatarUrl': notification.avatarUrl,
        },
      );
      print('✅ Navigation به چت با conversation_id: ${notification.conversationId}');
      return;
    }

    // اگر conversationId نداشتیم، از senderId استفاده می‌کنیم
    final userId = notification.senderId;
    if (userId.isEmpty) {
      print('❌ ConversationID و SenderID هر دو خالی هستند!');
      await _navigateToNotifications(context);
      return;
    }

    print('🔄 ConversationID خالی است - تلاش برای یافتن conversation با sender_id...');
    try {
      // پیدا کردن conversationId از userId
      final conversationResponse = await supabase
          .from('conversations')
          .select('id')
          .or('user1_id.eq.$userId,user2_id.eq.$userId')
          .limit(1)
          .maybeSingle();

      final conversationId = conversationResponse?['id'] as String?;

      if (conversationId == null || conversationId.isEmpty) {
        print('❌ Conversation یافت نشد برای userId: $userId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مکالمه پیدا نشد')),
        );
        await _navigateToNotifications(context);
        return;
      }

      print('✅ Conversation پیدا شد: $conversationId');

      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // باز کردن چت با کاربر
      Navigator.of(context).pushNamed(
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': userId,
          'username': notification.username,
          'avatarUrl': notification.avatarUrl,
        },
      );

      print('✅ هدایت به چت: $userId (conversation: $conversationId)');
    } catch (e) {
      print('❌ خطا در navigation به چت: $e');
      await _navigateToNotifications(context);
    }
  }

  /// هدایت به صفحه اعلان‌ها (پیش‌فرض)
  static Future<void> _navigateToNotifications(BuildContext context) async {
    try {
      final currentRoute = ModalRoute.of(context)?.settings.name;

      if (currentRoute != '/home') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/home',
          (route) => false,
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      // اگر route برای notifications وجود دارد
      // Navigator.of(context).pushNamed('/notifications');
      print('✅ هدایت به صفحه اعلان‌ها');
    } catch (e) {
      print('❌ خطا در navigation به اعلان‌ها: $e');
    }
  }

  /// پردازش payload از Local Notification
  static Future<void> handleLocalNotificationPayload({
    required BuildContext context,
    required String payload,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🎯 handleLocalNotificationPayload شروع شد');
    print('   Raw Payload: $payload');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      print('✅ Payload decoded:');
      data.forEach((key, value) {
        print('   $key: $value');
      });

      // استفاده از fromPayloadJson برای ساخت NotificationModel
      final notification = NotificationModel.fromPayloadJson(data);

      print('✅ NotificationModel created:');
      print('   Type: ${notification.type}');
      print('   ID: ${notification.id}');
      print('   PostID: ${notification.postId}');
      print('   CommentID: ${notification.commentId}');
      print('   ConversationID: ${notification.conversationId}');
      print('   SenderID: ${notification.senderId}');

      await handleNotificationNavigation(
        context: context,
        notification: notification,
      );
      print('✅ Navigation completed');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      print('❌ خطا در handleLocalNotificationPayload:');
      print('   Error: $e');
      print('   Stack: $stack');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _navigateToNotifications(context);
    }
  }

  /// پردازش payload از FCM
  static Future<void> handleFCMPayload({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 پردازش FCM Payload');
    print('   Data: $data');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final notification = NotificationModel.fromFCM(
        RemoteMessage(data: data),
      );
      
      print('✅ NotificationModel created from FCM:');
      print('   Type: ${notification.type}');
      print('   ID: ${notification.id}');
      print('   ConversationID: ${notification.conversationId}');
      print('   SenderID: ${notification.senderId}');
      print('   PostID: ${notification.postId}');
      print('   CommentID: ${notification.commentId}');
      
      await handleNotificationNavigation(
        context: context,
        notification: notification,
      );
    } catch (e, stack) {
      print('❌ خطا در پردازش FCM Payload:');
      print('   Error: $e');
      print('   Stack: $stack');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _navigateToNotifications(context);
    }
  }
}

