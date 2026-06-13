import 'package:flutter/material.dart';

import '../domain/modern_emoji_lookup.dart';
import 'modern_emoji_inline.dart';

/// TextEditingController that renders supported emojis using Modern assets
/// inside EditableText/TextField.
class ModernEmojiTextEditingController extends TextEditingController {
  ModernEmojiTextEditingController({
    super.text,
    this.useModernEmoji = true,
  });

  bool useModernEmoji;

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
