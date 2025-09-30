import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/typing_service.dart';

/// Provider برای مدیریت نشانگر تایپ کردن
final typingServiceProvider = Provider<TypingService>((ref) {
  final typingService = TypingService();
  ref.onDispose(() {
    typingService.dispose();
  });
  return typingService;
});

/// Provider برای وضعیت تایپ کردن در یک مکالمه خاص
final typingUsersProvider =
    StreamProvider.family<Set<String>, String>((ref, conversationId) {
  final typingService = ref.watch(typingServiceProvider);
  return typingService.getTypingStream(conversationId);
});

/// Provider برای دریافت کاربران در حال تایپ
final currentTypingUsersProvider =
    Provider.family<Set<String>, String>((ref, conversationId) {
  final typingService = ref.watch(typingServiceProvider);
  return typingService.getTypingUsers(conversationId);
});

/// Provider برای شروع تایپ کردن
final startTypingProvider =
    Provider.family<void Function(String), String>((ref, conversationId) {
  return (userId) {
    final typingService = ref.read(typingServiceProvider);
    typingService.startTyping(conversationId, userId);
  };
});

/// Provider برای متوقف کردن تایپ کردن
final stopTypingProvider =
    Provider.family<void Function(String), String>((ref, conversationId) {
  return (userId) {
    final typingService = ref.read(typingServiceProvider);
    typingService.stopTyping(conversationId, userId);
  };
});
