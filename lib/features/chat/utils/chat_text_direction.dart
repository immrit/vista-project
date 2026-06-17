import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show Bidi;

/// Layout direction for the chat list itself (bubbles, avatars, timestamps).
/// Chat layout is always LTR (avatar-left or avatar-right based on isMe).
const TextDirection kChatLayoutTextDirection = TextDirection.ltr;

/// Per-message content direction — detects if the message text is primarily RTL.
/// Persian/Arabic → RTL; Latin/mixed starts with Latin → LTR.
TextDirection resolveChatTextDirection(
  String? text, {
  TextDirection fallback = TextDirection.rtl,
}) {
  if (text == null || text.trim().isEmpty) return fallback;
  return Bidi.detectRtlDirectionality(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}
