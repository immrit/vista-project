import 'package:flutter/material.dart';

import '../domain/telegram_emoji_lookup.dart';
import 'telegram_emoji_inline.dart';

/// TextEditingController that renders supported emojis using Telegram assets
/// inside EditableText/TextField.
class TelegramEmojiTextEditingController extends TextEditingController {
  TelegramEmojiTextEditingController({
    super.text,
    this.useTelegramEmoji = true,
  });

  bool useTelegramEmoji;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;

    // Due to Flutter IME issues where WidgetSpan replaces surrogate pairs and
    // breaks the length synchronization, we must use the native text rendering
    // inside the TextField. This prevents issues like Enter key converting emojis
    // into question marks.
    return super.buildTextSpan(
      context: context,
      style: effectiveStyle,
      withComposing: withComposing,
    );
  }
}
