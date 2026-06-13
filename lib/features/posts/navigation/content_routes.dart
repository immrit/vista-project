import 'package:flutter/material.dart';

import '../screens/PostDetailPage.dart';
import '../screens/profileScreen.dart';

/// Lightweight route for opening a user profile without heavy Material transitions.
class ProfileRoute extends PageRouteBuilder<void> {
  ProfileRoute({
    required this.userId,
    required this.username,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(
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
}
