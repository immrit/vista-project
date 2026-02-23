import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../utils/rich_text_parser.dart';
import '../domain/telegram_emoji_lookup.dart';
import 'telegram_emoji_inline.dart';

class TelegramEmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool useTelegramEmoji;

  const TelegramEmojiText(
    this.text, {
    super.key,
    this.style,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.useTelegramEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style ?? DefaultTextStyle.of(context).style;
    if (!useTelegramEmoji || text.isEmpty) {
      return Text(
        text,
        style: effectiveStyle,
        textDirection: textDirection,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final spans = _buildInlineSpans(
      source: text,
      baseStyle: effectiveStyle,
      useTelegramEmoji: useTelegramEmoji,
      onTap: null,
    );

    return RichText(
      textDirection: textDirection,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: effectiveStyle,
        children: spans,
      ),
    );
  }
}

class TelegramEmojiRichText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;
  final Color mentionColor;
  final Color hashtagColor;
  final Function(String)? onLinkTap;
  final Function(String)? onMentionTap;
  final Function(String)? onHashtagTap;
  final TextDirection textDirection;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool useTelegramEmoji;

  const TelegramEmojiRichText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.linkColor = Colors.blue,
    this.mentionColor = Colors.blue,
    this.hashtagColor = Colors.blue,
    this.onLinkTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.textDirection = TextDirection.rtl,
    this.textAlign = TextAlign.right,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.useTelegramEmoji = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!useTelegramEmoji || text.isEmpty) {
      return RichText(
        textDirection: textDirection,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        text: RichTextParser.buildRichText(
          text: text,
          baseStyle: baseStyle,
          linkColor: linkColor,
          mentionColor: mentionColor,
          hashtagColor: hashtagColor,
          onLinkTap: onLinkTap,
          onMentionTap: onMentionTap,
          onHashtagTap: onHashtagTap,
        ),
      );
    }

    final parsed = RichTextParser.parse(text);
    final spans = <InlineSpan>[];
    for (final token in parsed) {
      switch (token.type) {
        case TextType.url:
          spans.addAll(
            _buildInlineSpans(
              source: token.text,
              baseStyle: baseStyle.copyWith(
                color: linkColor,
                decoration: TextDecoration.underline,
              ),
              useTelegramEmoji: useTelegramEmoji,
              onTap: () async {
                if (onLinkTap != null && token.value != null) {
                  onLinkTap!(token.value!);
                  return;
                }
                final raw = token.value ?? token.text;
                final uri = Uri.parse(
                  raw.startsWith('http') ? raw : 'https://$raw',
                );
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          );
          break;
        case TextType.mention:
          spans.addAll(
            _buildInlineSpans(
              source: token.text,
              baseStyle: baseStyle.copyWith(
                color: mentionColor,
                fontWeight: FontWeight.bold,
              ),
              useTelegramEmoji: useTelegramEmoji,
              onTap: () {
                if (onMentionTap != null && token.value != null) {
                  onMentionTap!(token.value!);
                }
              },
            ),
          );
          break;
        case TextType.hashtag:
          spans.addAll(
            _buildInlineSpans(
              source: token.text,
              baseStyle: baseStyle.copyWith(color: hashtagColor),
              useTelegramEmoji: useTelegramEmoji,
              onTap: () {
                if (onHashtagTap != null && token.value != null) {
                  onHashtagTap!(token.value!);
                }
              },
            ),
          );
          break;
        case TextType.text:
          spans.addAll(
            _buildInlineSpans(
              source: token.text,
              baseStyle: baseStyle,
              useTelegramEmoji: useTelegramEmoji,
              onTap: null,
            ),
          );
          break;
      }
    }

    return RichText(
      textDirection: textDirection,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }
}

List<InlineSpan> _buildInlineSpans({
  required String source,
  required TextStyle baseStyle,
  required bool useTelegramEmoji,
  required VoidCallback? onTap,
}) {
  if (source.isEmpty) return const <InlineSpan>[];

  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  final lookup = TelegramEmojiLookup.instance;
  final emojiSize = ((baseStyle.fontSize ?? 14) * 1.18).clamp(12.0, 36.0);

  void flushBuffer() {
    if (buffer.isEmpty) return;
    final textChunk = buffer.toString();
    buffer.clear();
    spans.add(
      TextSpan(
        text: textChunk,
        style: baseStyle,
        recognizer:
            onTap == null ? null : (TapGestureRecognizer()..onTap = onTap),
      ),
    );
  }

  for (final grapheme in source.characters) {
    final hasEmojiAsset = useTelegramEmoji && lookup.hasAsset(grapheme);
    if (!hasEmojiAsset) {
      buffer.write(grapheme);
      continue;
    }
    flushBuffer();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: TelegramEmojiInline(
          emoji: grapheme,
          size: emojiSize,
          fallbackStyle: baseStyle,
        ),
      ),
    );
  }

  flushBuffer();
  return spans;
}
