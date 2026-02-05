import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders text with clickable #hashtags.
///
/// - Supports Persian + Latin hashtags: `#([\u0600-\u06FF\w_]+)`
/// - Calls [onHashtagTap] with the normalized tag (without leading '#').
/// - Disposes gesture recognizers to avoid leaks.
class HashtagRichText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final ValueChanged<String>? onHashtagTap;

  const HashtagRichText({
    super.key,
    required this.text,
    this.style,
    this.hashtagStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.onHashtagTap,
  });

  @override
  State<HashtagRichText> createState() => _HashtagRichTextState();
}

class _HashtagRichTextState extends State<HashtagRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _resetRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    _resetRecognizers();

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    final tagStyle = widget.hashtagStyle ??
        baseStyle.copyWith(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        );

    final text = widget.text;
    final reg = RegExp(r'#([\u0600-\u06FF\w_]+)', unicode: true);

    final spans = <InlineSpan>[];
    var start = 0;

    for (final m in reg.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start), style: baseStyle));
      }

      final raw = m.group(1) ?? '';
      final tag = raw.trim();
      final show = '#$tag';
      final rec = TapGestureRecognizer()
        ..onTap = () {
          if (tag.isEmpty) return;
          widget.onHashtagTap?.call(tag);
        };
      _recognizers.add(rec);

      spans.add(
        TextSpan(
          text: show,
          style: tagStyle,
          recognizer: rec,
        ),
      );

      start = m.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return RichText(
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      text: TextSpan(children: spans),
    );
  }
}

