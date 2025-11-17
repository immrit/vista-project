import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../provider/telegram_style_chat_provider.dart';
import '../../../widgets/optimized_chat_input.dart';
import '../../../widgets/optimized_message_list.dart';
import '../../../widgets/performance_monitor.dart';
import '../../../main.dart';

/// ✅ Telegram-style Chat Screen
/// استفاده از تمام بهینه‌سازی‌های تلگرام
class TelegramStyleChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;

  const TelegramStyleChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  ConsumerState<TelegramStyleChatScreen> createState() =>
      _TelegramStyleChatScreenState();
}

class _TelegramStyleChatScreenState
    extends ConsumerState<TelegramStyleChatScreen> {
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(
      telegramStyleChatScreenProvider({
        'conversationId': widget.conversationId,
        'otherUserId': widget.otherUserId,
      }),
    );

    final currentUserId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat'),
        actions: [
          // Performance Monitor (optional)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.speed),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: const PerformanceMonitor(showDetails: true),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Loading Indicator (فقط برای disk/server load)
          if (chatState.isLoadingFromDisk || chatState.isLoadingFromServer)
            const LinearProgressIndicator(minHeight: 2),

          // ✅ Message List
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildPlaceholder(chatState.currentPhase)
                : OptimizedMessageList(
                    messages: chatState.messages,
                    currentUserId: currentUserId,
                    onMessageTap: (message) {
                      // Handle message tap
                    },
                    onLoadMore: () {
                      ref
                          .read(telegramStyleChatScreenProvider({
                            'conversationId': widget.conversationId,
                            'otherUserId': widget.otherUserId,
                          }).notifier)
                          .loadMoreMessages();
                    },
                  ),
          ),

          // ✅ Input Area
          OptimizedChatInput(
            onSendMessage: (content) {
              ref
                  .read(telegramStyleChatScreenProvider({
                    'conversationId': widget.conversationId,
                    'otherUserId': widget.otherUserId,
                  }).notifier)
                  .sendMessage(content: content);
            },
            onAttachmentTap: () {
              // Handle attachment
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(LoadPhase phase) {
    String message;

    switch (phase) {
      case LoadPhase.placeholder:
        message = 'در حال بارگذاری...';
        break;
      case LoadPhase.diskCache:
        message = 'بارگذاری از حافظه...';
        break;
      case LoadPhase.serverFetch:
        message = 'دریافت پیام‌های جدید...';
        break;
      default:
        message = 'هنوز پیامی وجود ندارد';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (phase != LoadPhase.complete)
            const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

