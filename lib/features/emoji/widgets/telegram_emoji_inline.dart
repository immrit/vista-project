import 'package:flutter/material.dart';

import '../domain/telegram_emoji_lookup.dart';

class TelegramEmojiInline extends StatelessWidget {
  final String emoji;
  final double size;
  final TextStyle? fallbackStyle;

  const TelegramEmojiInline({
    super.key,
    required this.emoji,
    required this.size,
    this.fallbackStyle,
  });

  @override
  Widget build(BuildContext context) {
    final path = TelegramEmojiLookup.instance.assetPathFor(emoji);
    if (path == null || path.isEmpty) {
      return Text(
        emoji,
        style: fallbackStyle ??
            TextStyle(
              fontSize: size,
              height: 1.0,
            ),
      );
    }

    return Image.asset(
      path,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, _, __) {
        return Text(
          emoji,
          style: fallbackStyle ??
              TextStyle(
                fontSize: size,
                height: 1.0,
              ),
        );
      },
    );
  }
}
