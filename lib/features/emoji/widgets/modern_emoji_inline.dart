import 'package:flutter/material.dart';

import '../domain/modern_emoji_lookup.dart';

class ModernEmojiInline extends StatelessWidget {
  final String emoji;
  final double size;
  final TextStyle? fallbackStyle;

  const ModernEmojiInline({
    super.key,
    required this.emoji,
    required this.size,
    this.fallbackStyle,
  });

  @override
  Widget build(BuildContext context) {
    final path = ModernEmojiLookup.instance.assetPathFor(emoji);
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
