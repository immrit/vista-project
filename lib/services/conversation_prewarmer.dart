import 'dart:async';
import '../model/conversation_model.dart';
import 'background_message_loader.dart';

class ConversationPrewarmer {
  static final ConversationPrewarmer _instance =
      ConversationPrewarmer._internal();
  factory ConversationPrewarmer() => _instance;
  ConversationPrewarmer._internal();

  final Set<String> _prewarmedConversations = {};
  Timer? _prewarmTimer;

  /// Pre-warm کردن مکالمات محتمل
  void prewarmRecentConversations(
    List<ConversationModel> conversations,
    String userId,
  ) {
    if (conversations.isEmpty) return;

    // لغو timer قبلی
    _prewarmTimer?.cancel();

    // تأخیر برای جلوگیری از تداخل با UI
    _prewarmTimer = Timer(const Duration(seconds: 2), () async {
      try {
        final toPrewarm = conversations.take(3).where((conv) {
          return !_prewarmedConversations.contains(conv.id);
        }).toList();

        for (final conversation in toPrewarm) {
          print('🔥 Pre-warming conversation: ${conversation.id}');

          await BackgroundMessageLoader().loadMessagesInBackground(
            conversationId: conversation.id,
            userId: userId,
            limit: 20,
          );

          _prewarmedConversations.add(conversation.id);
          await Future.delayed(const Duration(milliseconds: 400));
        }

        if (toPrewarm.isNotEmpty) {
          print('✅ Pre-warmed ${toPrewarm.length} conversations');
        }
      } catch (e) {
        print('⚠️ Prewarm error: $e');
      }
    });
  }

  void dispose() {
    _prewarmTimer?.cancel();
    _prewarmedConversations.clear();
  }
}

