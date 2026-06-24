import 'package:flutter/material.dart';

import '../screens/modern_chat_screen.dart';

/// Chat push route.
///
/// Uses the app's default page transition (Cupertino slide via the global
/// PageTransitionsTheme) at the standard MaterialPageRoute duration — the exact
/// same feel as the rest of the app (e.g. the Nearby screen), which already
/// reads as smooth. A previous 420/340ms override made the chat push feel
/// draggy and gave the first (heavy) list build a wider window to stutter in.
/// Edge back-swipe, parallax and RTL awareness come from the theme builder.
class ChatScreenRoute extends MaterialPageRoute<void> {
  ChatScreenRoute({required this.args})
      : super(
          builder: (context) => ModernChatScreen(args: args),
        );

  final ChatScreenArgs args;
}
