import '../security/logging_utility.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/chat/services/group_service.dart';

// Provider Ø¨Ø±Ø§ÛŒ Ù…Ø¯ÛŒØ±ÛŒØª ÙˆØ¶Ø¹ÛŒØª deep link
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

  // Ø´Ø±ÙˆØ¹ Ú¯ÙˆØ´ Ø¯Ø§Ø¯Ù† Ø¨Ù‡ deep links
  Future<void> initDeepLinks(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // Ú¯ÙˆØ´ Ø¯Ø§Ø¯Ù† Ø¨Ù‡ deep links Ø¯Ø± Ø­Ø§Ù„ Ø§Ø¬Ø±Ø§
      _subscription = _appLinks.uriLinkStream.listen((Uri uri) {
        handleDeepLink(uri, navigatorKey);
      }, onError: (err) {
        logInfo('Deep link error: $err');
      });

      // Ø¨Ø±Ø±Ø³ÛŒ deep link Ø§ÙˆÙ„ÛŒÙ‡ (Ø§Ú¯Ø± Ø§Ù¾ Ø§Ø² Ø·Ø±ÛŒÙ‚ deep link Ø¨Ø§Ø² Ø´Ø¯Ù‡)
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

  // Ù…ØªÙˆÙ‚Ù Ú©Ø±Ø¯Ù† Ú¯ÙˆØ´ Ø¯Ø§Ø¯Ù† Ø¨Ù‡ deep links
  void dispose() {
    _subscription?.cancel();
  }

  // Ù¾Ø±Ø¯Ø§Ø²Ø´ deep link
  void handleDeepLink(Uri uri, GlobalKey<NavigatorState> navigatorKey) {
    // Ø§Ù…Ù†â€ŒØ³Ø§Ø²ÛŒ Ù„Ø§Ú¯: Ø§Ø² Ú†Ø§Ù¾ Ú©Ù„ URI Ø®ÙˆØ¯Ø¯Ø§Ø±ÛŒ Ú©Ù†ÛŒØ¯
    final safe =
        'scheme=${uri.scheme}, host=${uri.host}, path=${uri.path}, segments=${uri.pathSegments.length}';
    logInfo('Received deep link (safe): $safe');

    final scheme = uri.scheme;
    final host = uri.host;
    final path = uri.path;
    final pathSegments = uri.pathSegments;

    if (scheme == 'vista') {
      if (host == 'group' && pathSegments.isNotEmpty) {
        final code = pathSegments.first;
        logInfo('Navigating to group via vista scheme invite');
        Future.microtask(() => _handleGroupInvite(code, navigatorKey));
      } else if (host == 'post' && pathSegments.isNotEmpty) {
        final postId = pathSegments.first;
        logInfo('Navigating to post via vista scheme');
        _navigateToPost(postId, navigatorKey);
      } else if (host == 'profile' && pathSegments.isNotEmpty) {
        final username = pathSegments.first;
        logInfo('Navigating to profile via vista scheme');
        _navigateToProfile(username, navigatorKey);
      } else {
        logInfo('Unsupported vista scheme host: $host');
      }
      return;
    }

    // ÙÙ‚Ø· Ù¾Ø´ØªÛŒØ¨Ø§Ù†ÛŒ Ø§Ø² https://cafevista.ir
    if (scheme == 'https' && (host == 'cafevista.ir' || host == 'vista.me')) {
      // Ù¾Ø±Ø¯Ø§Ø²Ø´ Ù…Ø³ÛŒØ±Ù‡Ø§ÛŒ Ù…Ø®ØªÙ„Ù
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

  // Navigation Ù…Ø´ØªØ±Ú© Ø¨Ø±Ø§ÛŒ Ù¾Ø³Øªâ€ŒÙ‡Ø§
  void _navigateToPost(String postId, GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.pushNamed(
      '/post-detail',
      arguments: {'postId': postId},
    );
  }

  // Navigation Ù…Ø´ØªØ±Ú© Ø¨Ø±Ø§ÛŒ Ù¾Ø±ÙˆÙØ§ÛŒÙ„â€ŒÙ‡Ø§
  void _navigateToProfile(
      String username, GlobalKey<NavigatorState> navigatorKey) {
    navigatorKey.currentState?.pushNamed(
      '/profile',
      arguments: {'username': username},
    );
  }

  // Navigation Ù…Ø´ØªØ±Ú© Ø¨Ø±Ø§ÛŒ ÙÛŒØ¯
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
          'username': info?['name'] as String? ?? 'Ú¯Ø±ÙˆÙ‡',
          'avatarUrl': info?['image'] as String?,
        },
      );
    } catch (e) {
      logInfo('Group invite error: $e');
    }
  }

  // ØªØ³Øª deep link (Ø¨Ø±Ø§ÛŒ development)
  void testDeepLink(String url, GlobalKey<NavigatorState> navigatorKey) {
    final uri = Uri.parse(url);
    handleDeepLink(uri, navigatorKey);
  }
}

// Ú©Ù„Ø§Ø³ helper Ø¨Ø±Ø§ÛŒ navigation
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
