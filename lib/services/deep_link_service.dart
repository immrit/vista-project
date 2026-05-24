import '../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/services/group_service.dart';

// Provider برای مدیریت وضعیت deep link
final deepLinkProvider =
    StateNotifierProvider<DeepLinkNotifier, String?>((ref) {
  return DeepLinkNotifier();
});

class DeepLinkNotifier extends StateNotifier<String?> {
  DeepLinkNotifier() : super(null);

  void setDeepLink(String? link) {
    state = link;
  }
}

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _subscription;

  // شروع گوش دادن به deep links
  Future<void> initDeepLinks(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // گوش دادن به deep links در حال اجرا
      _subscription = _appLinks.uriLinkStream.listen((Uri uri) {
        handleDeepLink(uri, navigatorKey);
      }, onError: (err) {
        logInfo('Deep link error: $err');
      });

      // بررسی deep link اولیه (اگر اپ از طریق deep link باز شده)
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          handleDeepLink(initialUri, navigatorKey);
        }
      } catch (e) {
        logInfo('Error getting initial URI: $e');
      }
    } catch (e) {
      logInfo('Error initializing deep links: $e');
    }
  }

  // متوقف کردن گوش دادن به deep links
  void dispose() {
    _subscription?.cancel();
  }

  // پردازش deep link
  void handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    // امن‌سازی لاگ: از چاپ کل URI خودداری کنید
    final safe =
        'scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}, segments=${uri.pathSegments.length}';
    logInfo('Received deep link (safe): $safe');

    final scheme = uri.scheme;
    final host = uri.host;
    final path = uri.path;
    final pathSegments = uri.pathSegments;

    // فقط پشتیبانی از https://cafevista.ir
    if (scheme == 'https' && host == 'cafevista.ir') {
      // پردازش مسیرهای مختلف
      if (path.startsWith('/post/') && pathSegments.length >= 2) {
        final postId = pathSegments[1];
        logInfo('Navigating to post: $postId');
        _navigateToPost(postId, navigatorKey);
      } else if (path.startsWith('/profile/') && pathSegments.length >= 2) {
        final username = pathSegments[1];
        logInfo('Navigating to profile: $username');
        _navigateToProfile(username, navigatorKey);
      } else if (path.startsWith('/group/') && pathSegments.length >= 2) {
        final code = pathSegments[1];
        logInfo('Navigating to group via invite: $code');
        Future.microtask(() => _handleGroupInvite(code, navigatorKey));
      } else if (path == '/feed') {
        logInfo('Navigating to feed');
        _navigateToFeed(navigatorKey);
      } else {
        logInfo('Unsupported path: $path');
      }
      return;
    }

    logInfo('Unsupported deep link: $uri');
  }

  // Navigation مشترک برای پست‌ها
  void _navigateToPost(String postId, GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.pushNamed(
      '/post-detail',
      arguments: {'postId': postId},
    );
  }

  // Navigation مشترک برای پروفایل‌ها
  void _navigateToProfile(
      String username, GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.pushNamed(
      '/profile',
      arguments: {'username': username},
    );
  }

  // Navigation مشترک برای فید
  void _navigateToFeed(GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.pushNamed('/feed');
  }

  Future<void> _handleGroupInvite(
      String inviteCode, GlobalKey<NavigatorState> navigatorKey) async {
    try {
      final service = GroupService();
      final conversationId = await service.joinByInvite(inviteCode);
      final info = await service.fetchGroupInfo(conversationId);

      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'otherUserId': '',
          'username': info?['name'] as String? ?? 'گروه',
          'avatarUrl': info?['image'] as String?,
        },
      );
    } catch (e) {
      logInfo('Group invite error: $e');
    }
  }

  // تست deep link (برای development)
  void testDeepLink(String url, GlobalKey<NavigatorState> navigatorKey) {
    final uri = Uri.parse(url);
    handleDeepLink(uri, navigatorKey);
  }
}

// کلاس helper برای navigation
class DeepLinkNavigator {
  static void navigateToPost(BuildContext context, String postId) {
    Navigator.of(context).pushNamed(
      '/post-detail',
      arguments: {'postId': postId},
    );
  }

  static void navigateToProfile(BuildContext context, String username) {
    Navigator.of(context).pushNamed(
      '/profile',
      arguments: {'username': username},
    );
  }

  static void navigateToFeed(BuildContext context) {
    Navigator.of(context).pushNamed('/feed');
  }
}
