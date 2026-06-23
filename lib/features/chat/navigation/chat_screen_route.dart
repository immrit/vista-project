import 'package:flutter/material.dart';

import '../screens/modern_chat_screen.dart';

/// Uses the app's default PageTransitionsTheme (Cupertino slide) for a
/// native-feeling transition, but with a longer duration than the 300ms
/// MaterialPageRoute default. The extra time turns the "snappy/dry" slide into
/// a softer, Telegram-like glide while keeping the iOS edge back-swipe, page
/// parallax and RTL awareness. Tune these to taste.
class ChatScreenRoute extends MaterialPageRoute<void> {
  ChatScreenRoute({required this.args})
      : super(
          builder: (context) => ModernChatScreen(args: args),
        );

  final ChatScreenArgs args;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 340);
}
