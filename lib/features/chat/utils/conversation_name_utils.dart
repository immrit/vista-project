const String genericConversationUserLabel = 'کاربر';
const String unknownConversationUserLabel = 'کاربر ناشناس';

bool isUnknownConversationName(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) return true;
  final lower = normalized.toLowerCase();
  return normalized == genericConversationUserLabel ||
      normalized == unknownConversationUserLabel ||
      lower == 'vista user' ||
      lower == 'unknown user' ||
      lower == 'unknown';
}

String? sanitizeConversationName(String? raw) {
  final normalized = raw?.trim() ?? '';
  if (isUnknownConversationName(normalized)) return null;
  if (normalized.toUpperCase() == 'VISTA USER') return null;
  return normalized.isEmpty ? null : normalized;
}

String resolveConversationDisplayName(String? raw) {
  return sanitizeConversationName(raw) ?? unknownConversationUserLabel;
}
