import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/providers/profile_note_provider.dart';
import '../../profile/data/models/profile_note_model.dart';
import '../../../provider/optimized_conversations_provider.dart';

/// Provider که لیست آیدی افرادی که کاربر با آن‌ها مکالمه دارد را استخراج می‌کند
final _chatUserIdsProvider = Provider<List<String>>((ref) {
  final state = ref.watch(optimizedConversationsProvider);
  final userIds = <String>{};
  
  for (final conv in state.conversations) {
    if (!conv.isGroup && conv.otherUserId != null && conv.otherUserId!.isNotEmpty) {
      userIds.add(conv.otherUserId!);
    }
  }
  
  return userIds.toList();
});

/// Provider که وضعیت (Note) افراد حاضر در لیست چت را دریافت می‌کند
final chatNotesProvider = FutureProvider<Map<String, ProfileNoteModel>>((ref) async {
  final userIds = ref.watch(_chatUserIdsProvider);
  
  if (userIds.isEmpty) {
    return {};
  }
  
  // محدود کردن به ۲۰ نفر اول برای جلوگیری از سنگین شدن ریکوئست
  final limitedIds = userIds.take(20).toList();
  
  // فراخوانی سرویس نوت برای گرفتن وضعیت این افراد
  return ref.watch(profileNotesMapProvider(limitedIds).future);
});
