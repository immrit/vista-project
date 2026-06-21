import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum TextType { text, url, mention, hashtag }

class ParsedTextSpan {
  final String text;
  final TextType type;
  final String? value; // The actual URL or username/tag

  ParsedTextSpan({
    required this.text,
    required this.type,
    this.value,
  });
}

class RichTextParser {
  static final _urlRegex = RegExp(
    r'((https?:www\.)|(https?:\/\/)|(www\.))[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9]{1,6}(\/[-a-zA-Z0-9()@:%_\+.~#?&\/=]*)?',
    caseSensitive: false,
  );

  static final _mentionRegex = RegExp(r'@[a-zA-Z0-9_]+');
  static final _hashtagRegex =
      RegExp(r'#[a-zA-Z0-9_\u0600-\u06FF]+'); // Includes Persian char support

  // LRU parse cache \u2014 bubble rebuilds (read receipt, status change) hit the same text.
  static final _parseCache = <String, List<ParsedTextSpan>>{};
  static const _maxCacheEntries = 256;

  /// Parses text and returns a list of ParsedTextSpan
  static List<ParsedTextSpan> parse(String text) {
    final hit = _parseCache[text];
    if (hit != null) return hit;
    final result = _doParse(text);
    if (_parseCache.length >= _maxCacheEntries) {
      _parseCache.remove(_parseCache.keys.first);
    }
    _parseCache[text] = result;
    return result;
  }

  static List<ParsedTextSpan> _doParse(String text) {
    final List<ParsedTextSpan> spans = [];
    final matches = <_TextMatch>[];

    // Find all matches
    _urlRegex.allMatches(text).forEach((m) {
      matches.add(_TextMatch(m.start, m.end, TextType.url, m.group(0)!));
    });

    _mentionRegex.allMatches(text).forEach((m) {
      matches.add(_TextMatch(m.start, m.end, TextType.mention, m.group(0)!));
    });

    _hashtagRegex.allMatches(text).forEach((m) {
      matches.add(_TextMatch(m.start, m.end, TextType.hashtag, m.group(0)!));
    });

    // Sort matches by start index
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Handle overlaps (prioritize URLs, then mentions, then hashtags - though they shouldn't usually overlap in valid syntax)
    // For simplicity, we'll just skip overlapping matches that come later
    final List<_TextMatch> uniqueMatches = [];
    int lastEnd = 0;
    for (var m in matches) {
      if (m.start >= lastEnd) {
        uniqueMatches.add(m);
        lastEnd = m.end;
      }
    }

    // Build spans
    int currentIndex = 0;
    for (var m in uniqueMatches) {
      if (m.start > currentIndex) {
        spans.add(ParsedTextSpan(
          text: text.substring(currentIndex, m.start),
          type: TextType.text,
        ));
      }

      spans.add(ParsedTextSpan(
        text: text.substring(m.start, m.end),
        type: m.type,
        value: m.text,
      ));

      currentIndex = m.end;
    }

    if (currentIndex < text.length) {
      spans.add(ParsedTextSpan(
        text: text.substring(currentIndex),
        type: TextType.text,
      ));
    }

    return spans;
  }

  /// Builds a TextSpan with clickable links
  static TextSpan buildRichText({
    required String text,
    required TextStyle baseStyle,
    Color linkColor = Colors.blue,
    Color mentionColor = Colors.blue,
    Color hashtagColor = Colors.blue,
    Function(String)? onLinkTap,
    Function(String)? onMentionTap,
    Function(String)? onHashtagTap,
  }) {
    final spans = parse(text);
    return TextSpan(
      children: spans.map((span) {
        switch (span.type) {
          case TextType.url:
            return TextSpan(
              text: span.text,
              style: baseStyle.copyWith(
                  color: linkColor, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()
                ..onTap = () async {
                  if (onLinkTap != null) {
                    onLinkTap(span.value!);
                  } else {
                    final url = span.value!;
                    final uri = Uri.parse(
                        url.startsWith('http') ? url : 'https://$url');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  }
                },
            );
          case TextType.mention:
            return TextSpan(
              text: span.text,
              style: baseStyle.copyWith(
                  color: mentionColor, fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  if (onMentionTap != null) onMentionTap(span.value!);
                },
            );
          case TextType.hashtag:
            return TextSpan(
              text: span.text,
              style: baseStyle.copyWith(color: hashtagColor),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  if (onHashtagTap != null) onHashtagTap(span.value!);
                },
            );
          case TextType.text:
            return TextSpan(text: span.text, style: baseStyle);
        }
      }).toList(),
    );
  }
}

class _TextMatch {
  final int start;
  final int end;
  final TextType type;
  final String text;

  _TextMatch(this.start, this.end, this.type, this.text);
}
