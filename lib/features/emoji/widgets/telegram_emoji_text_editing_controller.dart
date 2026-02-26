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

    // While composing (IME), use default rendering to keep composition stable.
    if (!useTelegramEmoji ||
        text.isEmpty ||
        (withComposing &&
            value.composing.isValid &&
            !value.composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: effectiveStyle,
        withComposing: withComposing,
      );
    }

    final lookup = TelegramEmojiLookup.instance;
    final spans = <InlineSpan>[];
    final plainBuffer = StringBuffer();
    final emojiSize =
        ((effectiveStyle.fontSize ?? 14) * 1.18).clamp(12.0, 36.0);

    void flushBuffer() {
      if (plainBuffer.isEmpty) return;
      spans.add(
        TextSpan(
          text: plainBuffer.toString(),
          style: effectiveStyle,
        ),
      );
      plainBuffer.clear();
    }

    for (final grapheme in text.characters) {
      if (!lookup.hasAsset(grapheme)) {
        plainBuffer.write(grapheme);
        continue;
      }

      flushBuffer();
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: TelegramEmojiInline(
            emoji: grapheme,
            size: emojiSize,
            fallbackStyle: effectiveStyle,
          ),
        ),
      );
    }

    flushBuffer();

    return TextSpan(
      style: effectiveStyle,
      children: spans,
    );
  }
}
