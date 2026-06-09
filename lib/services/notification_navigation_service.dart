import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:Vista/utils/env_config.dart';
import 'package:http/http.dart' as http;
import '../model/notificationModel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/providers/auth_controller.dart' show TokenStorage;
import '../features/chat/providers/chat_providers.dart';
import '../utils/const.dart';
import 'notification_action_resolver.dart';

class NotificationNavigationService {
  static bool _isHandlingTap = false;
  static DateTime? _lastHandledAt;

  static NavigatorState? _resolveNavigator([BuildContext? fallbackContext]) {
    final keyedNavigator = navigatorKey.currentState;
    if (keyedNavigator != null) return keyedNavigator;
    if (fallbackContext == null) return null;
    try {
      return Navigator.of(fallbackContext, rootNavigator: true);
    } catch (_) {
      try {
        return Navigator.of(fallbackContext);
      } catch (_) {
        return null;
      }
    }
  }

  static BuildContext? _resolveContext([BuildContext? fallbackContext]) {
    return navigatorKey.currentContext ?? fallbackContext;
  }

  static Future<void> _ensureRootOnHome([BuildContext? fallbackContext]) async {
    final navigator = _resolveNavigator(fallbackContext);
    if (navigator == null) return;

    final routeName =
        ModalRoute.of(_resolveContext(fallbackContext) ?? navigator.context)
            ?.settings
            .name;
    if (routeName == '/home') return;

    navigator.pushNamedAndRemoveUntil('/home', (route) => false);
    await Future.delayed(const Duration(milliseconds: 350));
  }

  static bool _canHandleTap() {
    final now = DateTime.now();
    final last = _lastHandledAt;
    if (_isHandlingTap) return false;
    if (last != null && now.difference(last) < const Duration(milliseconds: 350)) {
      return false;
    }
    _isHandlingTap = true;
    _lastHandledAt = now;
    return true;
  }

  static void _releaseTapLock() {
    _isHandlingTap = false;
  }

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

    if (!_canHandleTap()) {
      print('⏳ Navigation ignored (tap lock)');
      return;
    }

    try {
      // ✅ علامت‌گذاری به عنوان خوانده شده
      try {
        await _markAsRead(notification.id);
        print('✅ اعلان به عنوان خوانده شده علامت‌گذاری شد');
      } catch (e) {
        print('⚠️ خطا در علامت‌گذاری خوانده شده: $e');
      }

      // ✅ Resolve action then execute (coordinator style)
      final action = NotificationActionResolver.resolve(notification);
      print('🧩 Resolved action: ${action.type}');

      switch (action.type) {
        case NotificationActionType.openChat:
          print('📬 navigation به چت');
          await _navigateToChat(context, notification);
          break;
        case NotificationActionType.openPost:
          print('❤️ navigation به پست');
          await _navigateToPost(context, action.postId ?? notification.postId);
          break;
        case NotificationActionType.openPostComments:
          print('💬 navigation به کامنت‌ها');
          await _navigateToPostComments(
            context,
            action.postId ?? notification.postId,
            action.commentId ?? notification.commentId,
          );
          break;
        case NotificationActionType.openCommentReply:
          print('↩️ navigation به پاسخ کامنت');
          await _navigateToCommentReply(
            context,
            action.postId ?? notification.postId,
            action.commentId ?? notification.commentId,
            action.parentCommentId ?? notification.parentCommentId,
          );
          break;
        case NotificationActionType.openProfile:
          print('👤 navigation به پروفایل');
          await _navigateToProfile(context, action.userId ?? notification.senderId);
          break;
        case NotificationActionType.openSuggestedFollow:
          await _navigateToSuggestedFollow(context, notification);
          break;
        case NotificationActionType.openSuggestedPost:
          await _navigateToSuggestedPost(context, notification);
          break;
        case NotificationActionType.openSuggestionDigest:
          await _navigateToSuggestionDigest(context, notification);
          break;
        case NotificationActionType.openDeepLink:
          await _navigateByDeepLink(
            context,
            action.deeplink ?? notification.deeplink ?? '',
          );
          break;
        case NotificationActionType.openNotifications:
          await _navigateToNotifications(context);
          break;
      }
      print('✅ Navigation completed');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e, stack) {
      print('❌ خطا در navigation اعلان:');
      print('   Error: $e');
      print('   Stack: $stack');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      await _navigateToNotifications(context);
    } finally {
      _releaseTapLock();
    }
  }

  /// علامت‌گذاری اعلان به عنوان خوانده شده
  static Future<void> _markAsRead(String notificationId) async {
    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) return;
      final baseUrl = EnvConfig.apiBaseUrl;
      await http.post(
        Uri.parse(
          '$baseUrl/v1/notifications/${Uri.encodeComponent(notificationId)}/read',
        ),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
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
      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;
      navigator.pushNamed(
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
      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;

      // اگر ID کامنت خاص داریم
      if (commentId != null && commentId.isNotEmpty) {
        navigator.pushNamed(
          '/post-detail',
          arguments: {
            'postId': postId,
            'highlightCommentId': commentId, // برای هایلایت کردن کامنت
          },
        );
      } else {
        navigator.pushNamed(
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
    await _navigateToPostComments(
        context, postId, parentCommentId ?? commentId);
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
      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;
      navigator.pushNamed(
        '/profile',
        arguments: {
          'username': '',
          'userId': userId,
        },
      );

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
      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;

      navigator.pushNamed(
        '/chat',
        arguments: {
          'conversationId': notification.conversationId,
          'otherUserId': notification.senderId,
          'username': notification.username,
          'avatarUrl': notification.avatarUrl,
        },
      );
      print(
          '✅ Navigation به چت با conversation_id: ${notification.conversationId}');
      return;
    }

    // اگر conversationId نداشتیم، از senderId استفاده می‌کنیم
    final userId = notification.senderId;
    if (userId.isEmpty) {
      print('❌ ConversationID و SenderID هر دو خالی هستند!');
      await _navigateToNotifications(context);
      return;
    }

    print(
        '🔄 ConversationID خالی است - تلاش برای یافتن conversation با sender_id...');
    try {
      // پیدا کردن conversationId از userId
      final providerContext = _resolveContext(context) ?? context;
      final container = ProviderScope.containerOf(providerContext, listen: false);
      final result = await container
          .read(chatRepositoryProvider)
          .createConversation(userId);
      final conversationId = result.data?.id;

      if (conversationId == null || conversationId.isEmpty) {
        print('❌ Conversation یافت نشد برای userId: $userId');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('مکالمه پیدا نشد')),
        );
        await _navigateToNotifications(context);
        return;
      }

      print('✅ Conversation پیدا شد: $conversationId');

      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;

      // باز کردن چت با کاربر
      navigator.pushNamed(
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
      await _ensureRootOnHome(context);

      // اگر route برای notifications وجود دارد
      // Navigator.of(context).pushNamed('/notifications');
      print('✅ هدایت به صفحه اعلان‌ها');
    } catch (e) {
      print('❌ خطا در navigation به اعلان‌ها: $e');
    }
  }

  static Future<void> _navigateByDeepLink(
    BuildContext context,
    String deeplink,
  ) async {
    try {
      final uri = Uri.tryParse(deeplink);
      if (uri == null) {
        await _navigateToNotifications(context);
        return;
      }

      if (uri.scheme == 'vista') {
        switch (uri.host) {
          case 'chat':
            final conversationId = uri.pathSegments.isNotEmpty
                ? uri.pathSegments.first
                : uri.queryParameters['conversationId'];
            if (conversationId != null && conversationId.isNotEmpty) {
              await _navigateToChatDirectly(
                context,
                conversationId,
                const <String, dynamic>{},
              );
              return;
            }
            break;
          case 'post':
            final postId = uri.pathSegments.isNotEmpty
                ? uri.pathSegments.first
                : uri.queryParameters['postId'];
            if (postId != null && postId.isNotEmpty) {
              await _navigateToPost(context, postId);
              return;
            }
            break;
          case 'profile':
          case 'user':
            final userId = uri.pathSegments.isNotEmpty
                ? uri.pathSegments.first
                : uri.queryParameters['userId'];
            if (userId != null && userId.isNotEmpty) {
              await _navigateToProfile(context, userId);
              return;
            }
            break;
          case 'notifications':
            await _navigateToNotifications(context);
            return;
        }
      }

      if (uri.path.contains('/chat')) {
        final conversationId = uri.queryParameters['conversationId'] ??
            (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null);
        if (conversationId != null && conversationId.isNotEmpty) {
          await _navigateToChatDirectly(
            context,
            conversationId,
            const <String, dynamic>{},
          );
          return;
        }
      }

      if (uri.path.contains('/post')) {
        final postId = uri.queryParameters['postId'] ??
            (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null);
        if (postId != null && postId.isNotEmpty) {
          await _navigateToPost(context, postId);
          return;
        }
      }

      await _navigateToNotifications(context);
    } catch (_) {
      await _navigateToNotifications(context);
    }
  }

  static Future<void> _navigateToSuggestedFollow(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final metadata = notification.metadata ?? const {};
    final userId = metadata['user_id']?.toString() ??
        metadata['suggested_user_id']?.toString() ??
        notification.senderId;
    if (userId.isNotEmpty) {
      await _navigateToProfile(context, userId);
      return;
    }
    await _navigateToNotifications(context);
  }

  static Future<void> _navigateToSuggestedPost(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final metadata = notification.metadata ?? const {};
    final postId =
        metadata['post_id']?.toString() ?? notification.postId?.toString();
    if (postId != null && postId.isNotEmpty) {
      await _navigateToPost(context, postId);
      return;
    }
    await _navigateToNotifications(context);
  }

  static Future<void> _navigateToSuggestionDigest(
    BuildContext context,
    NotificationModel notification,
  ) async {
    final metadata = notification.metadata ?? const {};
    final suggestions = metadata['suggestions'];
    if (suggestions is List && suggestions.isNotEmpty) {
      final first = suggestions.first;
      if (first is Map) {
        final type = first['type']?.toString();
        if (type == 'user') {
          final userId = first['user_id']?.toString();
          if (userId != null && userId.isNotEmpty) {
            await _navigateToProfile(context, userId);
            return;
          }
        } else if (type == 'post') {
          final postId = first['post_id']?.toString();
          if (postId != null && postId.isNotEmpty) {
            await _navigateToPost(context, postId);
            return;
          }
        }
      }
    }
    if (notification.deeplink != null && notification.deeplink!.isNotEmpty) {
      await _navigateByDeepLink(context, notification.deeplink!);
      return;
    }
    await _navigateToNotifications(context);
  }

  /// مدیریت کلیک روی نوتیفیکیشن‌های داخلی (Local)
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

      // استفاده از همان تابع handleFCMPayload که هوشمند است
      await handleFCMPayload(context: context, data: data);

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

  /// 🚀 مدیریت کلیک روی نوتیفیکیشن (چه از فایربیس، چه لوکال)
  static Future<void> handleFCMPayload({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔔 Handling Notification Payload:');
    data.forEach((key, value) {
      print('   $key: $value');
    });
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      // ۱. استخراج هوشمند conversation_id
      String? conversationId;

      // حالت اول: دیتای فلت (ساختار جدید ما)
      if (data.containsKey('conversation_id')) {
        conversationId = data['conversation_id']?.toString();
        print('✅ conversation_id پیدا شد (flat structure): $conversationId');
      }
      // حالت دوم: دیتای تو در تو (برای سازگاری با نسخه‌های احتمالی دیگر)
      else if (data.containsKey('data')) {
        final nestedData = data['data'];
        if (nestedData is Map) {
          conversationId = nestedData['conversation_id']?.toString();
          print(
              '✅ conversation_id پیدا شد (nested structure): $conversationId');
        } else if (nestedData is String) {
          try {
            final parsed = jsonDecode(nestedData);
            if (parsed is Map) {
              conversationId = parsed['conversation_id']?.toString();
              print(
                  '✅ conversation_id پیدا شد (nested JSON string): $conversationId');
            }
          } catch (_) {}
        }
      }

      // ۲. اگر ID پیدا شد و نوع پیام چت است، برو به صفحه چت
      final type = NotificationModel.canonicalType(data['type']?.toString());
      if (conversationId != null &&
          conversationId.isNotEmpty &&
          (type == 'chat_message' || type == 'message')) {
        await _navigateToChatDirectly(context, conversationId, data);
        return;
      }

      // ۳. اگر conversation_id نداشتیم یا نوع پیام چت نبود، از روش قدیمی استفاده کن
      print(
          '⚠️ conversation_id پیدا نشد یا نوع پیام چت نیست - استفاده از روش قدیمی');
      final notification = NotificationModel.fromFCM(
        RemoteMessage(data: data),
      );

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

  /// 🧭 نویگیشن مستقیم به صفحه چت (بدون استفاده از route)
  static Future<void> _navigateToChatDirectly(
    BuildContext context,
    String conversationId,
    Map<String, dynamic> data,
  ) async {
    print('🚀 Navigating to ChatScreen with ID: $conversationId');

    try {
      // ✅ 0. Optimistic Save: ذخیره پیام در دیتابیس قبل از نویگیشن
      // این کار باعث می‌شود به محض باز شدن چت، پیام در آنجا باشد
      try {
        print('⏳ Starting optimistic save for notification message...');
        final providerContext = _resolveContext(context) ?? context;
        final container = ProviderScope.containerOf(providerContext);
        await container
            .read(chatRepositoryProvider)
            .handleNotificationMessage(data);
      } catch (e) {
        print('⚠️ Optimistic save warning (non-fatal): $e');
      }

      // استخراج اطلاعات فرستنده برای نمایش سریع
      final senderName = data['sender_name']?.toString() ??
          data['title']?.toString() ??
          'کاربر';
      final senderAvatar =
          data['sender_avatar']?.toString() ?? data['avatar_url']?.toString();
      final senderId = data['sender_id']?.toString() ?? '';

      // اگر senderId خالی بود، باید از conversationId استفاده کنیم تا اطلاعات را بگیریم
      // اما فعلاً با همان اطلاعات موجود کار می‌کنیم

      // هدایت به صفحه چت
      // استفاده از ChatScreen قدیمی (چون در route استفاده می‌شود)
      await _ensureRootOnHome(context);
      final navigator = _resolveNavigator(context);
      if (navigator == null) return;

      // استفاده از route برای سازگاری با سیستم موجود
      navigator.pushNamed(
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': senderId.isNotEmpty ? senderId : null,
          'username': senderName,
          'avatarUrl': senderAvatar,
        },
      );

      print('✅ Navigation به چت با conversation_id: $conversationId');
    } catch (e, stack) {
      print('❌ خطا در navigation مستقیم به چت:');
      print('   Error: $e');
      print('   Stack: $stack');
      await _navigateToNotifications(context);
    }
  }
}
