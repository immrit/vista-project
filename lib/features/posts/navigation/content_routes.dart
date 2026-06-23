import 'package:flutter/material.dart';

import '../../profile/data/profile_repository.dart';
import '../screens/PostDetailPage.dart';
import '../screens/profileScreen.dart';

/// Lightweight route for opening a user profile without heavy Material transitions.
class ProfileRoute extends PageRouteBuilder<void> {
  ProfileRoute({
    required this.userId,
    required this.username,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ProfileScreen(
            userId: userId,
            username: username,
          ),
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );

  final String userId;
  final String username;
}

/// Lightweight route for post detail — keeps feed/list screens responsive.
class PostDetailRoute extends PageRouteBuilder<void> {
  PostDetailRoute({required this.postId})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              PostDetailsPage(postId: postId),
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.92, end: 1).animate(curved),
              child: child,
            );
          },
        );

  final String postId;
}

/// Central navigation helpers for profile and post detail hot paths.
abstract final class ContentNavigation {
  static Future<void> pushProfile(
    BuildContext context, {
    required String userId,
    required String username,
  }) {
    return Navigator.push<void>(
      context,
      ProfileRoute(userId: userId, username: username),
    );
  }

  static Future<void> pushPostDetail(
    BuildContext context, {
    required String postId,
  }) {
    return Navigator.push<void>(
      context,
      PostDetailRoute(postId: postId),
    );
  }

  /// Open a profile from a bare `@username` (e.g. a tapped mention). Resolves
  /// the user id first, then routes; silently no-ops if the username can't be
  /// resolved so a bad mention never throws on the read path.
  static Future<void> pushProfileByUsername(
    BuildContext context, {
    required String username,
  }) async {
    final clean = username.replaceFirst(RegExp(r'^@+'), '').trim();
    if (clean.isEmpty) return;

    String userId = '';
    try {
      final data =
          await ProfileRepository().fetchProfileByUsername(clean.toLowerCase());
      userId = (data['user_id'] ?? data['id'] ?? '').toString();
    } catch (_) {
      // Resolution is best-effort; fall through and let ProfileScreen retry by
      // username if it supports that, otherwise just abort.
    }

    if (!context.mounted) return;
    if (userId.isEmpty) return;

    await Navigator.push<void>(
      context,
      ProfileRoute(userId: userId, username: clean),
    );
  }
}
