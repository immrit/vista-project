import 'dart:math';

class UploadObjectKeyService {
  static final Random _random = Random.secure();

  static String buildChatObjectKey({
    required String conversationId,
    required String folder,
    required String userId,
    String? extension,
  }) {
    final safeConversation = _sanitizeSegment(conversationId, fallback: 'chat');
    final safeFolder = _sanitizeSegment(folder, fallback: 'files');
    final safeUser = _sanitizeSegment(userId, fallback: 'user');
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rand = _random.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0');
    final safeExt = _normalizeExtension(extension);
    return 'chat/$safeUser/$safeConversation/$safeFolder/${ts}_$rand$safeExt';
  }

  static String _sanitizeSegment(String value, {required String fallback}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (sanitized.isEmpty) return fallback;
    return sanitized;
  }

  static String _normalizeExtension(String? extension) {
    if (extension == null) return '.bin';
    final cleaned = extension
        .trim()
        .replaceFirst('.', '')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleaned.isEmpty) return '.bin';
    return '.$cleaned';
  }
}
