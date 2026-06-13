import 'package:flutter/material.dart';

import '../screens/modern_chat_screen.dart';

/// Lightweight route for opening chat — avoids heavy default Material transition
/// work on the conversations screen.
class ChatScreenRoute extends PageRouteBuilder<void> {
  ChatScreenRoute({required this.args})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              ModernChatScreen(args: args),
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

  final ChatScreenArgs args;
}
