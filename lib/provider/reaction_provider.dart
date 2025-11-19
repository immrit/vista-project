import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/message_reaction_service.dart';

// سرویس ری‌اکشن
final reactionServiceProvider = Provider<MessageReactionService>((ref) {
  final service = MessageReactionService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ری‌اکشن‌های یک پیام خاص
final messageReactionsProvider = FutureProvider.family<Map<String, List<String>>, String>(
  (ref, messageId) async {
    final service = ref.watch(reactionServiceProvider);
    return await service.getMessageReactionsSummary(messageId);
  },
);

// استیت کنترل نمایش selector ری‌اکشن
final reactionSelectorProvider = StateProvider.family<bool, String>(
  (ref, messageId) => false,
);













