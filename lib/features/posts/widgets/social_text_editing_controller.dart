import 'package:flutter/material.dart';

/// A [TextEditingController] that live-highlights `#hashtags` and `@mentions`
/// inside the compose field — the same affordance Instagram / X / Threads use.
///
/// Tokens are colored with [highlightColor] and rendered semi-bold while the
/// user types, so they immediately read as "entities" rather than plain text.
/// The matching rule mirrors [hashtag_rich_text.dart] and the tag extractor in
/// `AddPost`, so what the user sees while typing equals what is highlighted in
/// the feed afterwards.
class SocialTextEditingController extends TextEditingController {
  SocialTextEditingController({
    super.text,
    Color? highlightColor,
  }) : _highlightColor = highlightColor;

  Color? _highlightColor;

  /// Accent used for `#`/`@` tokens. Updated from the host widget so the color
  /// can follow the active theme (light/dark) without recreating the
  /// controller (which would lose selection/composing state).
  set highlightColor(Color? value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    // Re-layout the field with the new token color.
    notifyListeners();
  }

  // `#tag` and `@mention`. Supports Persian + Latin letters, digits, '_'.
  // Requires at least one char after the trigger so a lone '#'/'@' stays plain.
  static final RegExp _entityRegex = RegExp(
    r'[#@][؀-ۿ\w_]+',
    unicode: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final accent = _highlightColor ?? Theme.of(context).colorScheme.primary;
    final entityStyle = base.copyWith(
      color: accent,
      fontWeight: FontWeight.w600,
    );

    final value = text;
    if (value.isEmpty) {
      return TextSpan(style: base, text: value);
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _entityRegex.allMatches(value)) {
      if (match.start > start) {
        spans.add(TextSpan(text: value.substring(start, match.start)));
      }
      spans.add(TextSpan(text: match.group(0), style: entityStyle));
      start = match.end;
    }
    if (start < value.length) {
      spans.add(TextSpan(text: value.substring(start)));
    }

    return TextSpan(style: base, children: spans);
  }
}
