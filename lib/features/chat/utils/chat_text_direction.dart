import 'package:flutter/widgets.dart';

TextDirection resolveChatTextDirection(
  String? text, {
  TextDirection fallback = TextDirection.ltr,
}) {
  final value = text?.trim();
  if (value == null || value.isEmpty) return fallback;

  for (final codePoint in value.runes) {
    if (_isRtlCodePoint(codePoint)) return TextDirection.rtl;
    if (_isLtrCodePoint(codePoint)) return TextDirection.ltr;
  }

  return fallback;
}

bool _isRtlCodePoint(int codePoint) {
  return (codePoint >= 0x0590 && codePoint <= 0x08FF) ||
      (codePoint >= 0xFB1D && codePoint <= 0xFDFF) ||
      (codePoint >= 0xFE70 && codePoint <= 0xFEFF);
}

bool _isLtrCodePoint(int codePoint) {
  return (codePoint >= 0x0041 && codePoint <= 0x005A) ||
      (codePoint >= 0x0061 && codePoint <= 0x007A) ||
      (codePoint >= 0x00C0 && codePoint <= 0x024F) ||
      (codePoint >= 0x0370 && codePoint <= 0x052F);
}
