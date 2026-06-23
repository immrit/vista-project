import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../chat/utils/chat_text_direction.dart';

/// Renders text with clickable #hashtags.
///
/// - Supports Persian + Latin hashtags: `#([\u0600-\u06FF\w_]+)`
/// - Calls [onHashtagTap] with the normalized tag (without leading '#').
/// - Disposes gesture recognizers to avoid leaks.
/// - Optionally shows [readMoreLabel] when [maxLines] truncates the text.
class HashtagRichText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? hashtagStyle;
  final TextStyle? mentionStyle;
  final TextStyle? readMoreStyle;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow overflow;
  final String? readMoreLabel;
  final ValueChanged<String>? onHashtagTap;
  final ValueChanged<String>? onMentionTap;
  final VoidCallback? onReadMoreTap;

  const HashtagRichText({
    super.key,
    required this.text,
    this.style,
    this.hashtagStyle,
    this.mentionStyle,
    this.readMoreStyle,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.readMoreLabel,
    this.onHashtagTap,
    this.onMentionTap,
    this.onReadMoreTap,
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

  List<InlineSpan> _buildSpans(
    TextStyle baseStyle,
    TextStyle tagStyle,
    TextStyle mentionStyle,
  ) {
    final text = widget.text;
    // One pass over both entity kinds so order is preserved. Mentions only
    // trigger at a word boundary (start or after whitespace) so emails like
    // `a@b` are not mistaken for mentions.
    final reg = RegExp(
      r'(?<![^\s\n])@([\u0600-\u06FF\w_]+)|#([\u0600-\u06FF\w_]+)',
      unicode: true,
    );

    final spans = <InlineSpan>[];
    var start = 0;

    for (final m in reg.allMatches(text)) {
      if (m.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, m.start), style: baseStyle),
        );
      }

      final mention = m.group(1);
      final hashtag = m.group(2);

      if (mention != null) {
        final username = mention.trim();
        final rec = TapGestureRecognizer()
          ..onTap = () {
            if (username.isEmpty) return;
            widget.onMentionTap?.call(username);
          };
        _recognizers.add(rec);
        spans.add(
          TextSpan(text: '@$username', style: mentionStyle, recognizer: rec),
        );
      } else {
        final tag = (hashtag ?? '').trim();
        final rec = TapGestureRecognizer()
          ..onTap = () {
            if (tag.isEmpty) return;
            widget.onHashtagTap?.call(tag);
          };
        _recognizers.add(rec);
        spans.add(
          TextSpan(text: '#$tag', style: tagStyle, recognizer: rec),
        );
      }

      start = m.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return spans;
  }

  bool _didExceedMaxLines({
    required double maxWidth,
    required TextDirection direction,
    required TextStyle baseStyle,
  }) {
    final maxLines = widget.maxLines;
    if (maxLines == null || widget.text.isEmpty) return false;

    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: baseStyle),
      textDirection: direction,
      textAlign: widget.textAlign,
      maxLines: maxLines,
    )..layout(maxWidth: maxWidth);

    return painter.didExceedMaxLines;
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
    final mentionStyle = widget.mentionStyle ??
        baseStyle.copyWith(
          color: Colors.blue,
          fontWeight: FontWeight.w600,
        );
    final direction = widget.textDirection ??
        resolveChatTextDirection(
          widget.text,
          fallback: Directionality.of(context),
        );
    final readMoreLabel = widget.readMoreLabel;
    final showReadMore = readMoreLabel != null && readMoreLabel.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isOverflowing = showReadMore &&
            maxWidth.isFinite &&
            _didExceedMaxLines(
              maxWidth: maxWidth,
              direction: direction,
              baseStyle: baseStyle,
            );
        final readMoreStyle = widget.readMoreStyle ??
            baseStyle.copyWith(
              color: baseStyle.color?.withValues(alpha: 0.65) ?? Colors.grey,
              fontWeight: FontWeight.w600,
            );

        final spans = _buildSpans(baseStyle, tagStyle, mentionStyle);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            RichText(
              textDirection: direction,
              textAlign: widget.textAlign,
              maxLines: widget.maxLines,
              overflow: isOverflowing ? TextOverflow.clip : widget.overflow,
              text: TextSpan(children: spans),
            ),
            if (isOverflowing)
              Align(
                alignment: direction == TextDirection.rtl
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onReadMoreTap,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      readMoreLabel,
                      style: readMoreStyle,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
