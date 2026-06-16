import 'package:flutter/widgets.dart';

/// Chat UI always uses English-style LTR layout regardless of app locale.
const TextDirection kChatLayoutTextDirection = TextDirection.ltr;

TextDirection resolveChatTextDirection(
  String? text, {
  TextDirection fallback = kChatLayoutTextDirection,
}) {
  return kChatLayoutTextDirection;
}
