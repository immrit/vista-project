import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../model/conversation_model.dart';
import '../../../provider/Chat_provider.dart.dart';

import 'ChatScreen.dart';

class ChatConversationsScreen extends ConsumerStatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  ConsumerState<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState
    extends ConsumerState<ChatConversationsScreen> {
  @override
  void initState() {
    super.initState();
    // تنظیم متن‌های فارسی برای timeago
    timeago.setLocaleMessages('fa', timeago.FaMessages());
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پیام‌ها'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(conversationsProvider);
        },
        child: conversationsAsync.when(
            data: (conversations) {
              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/empty_chat.png', // تصویر خالی بودن چت
                        width: 150,
                        height: 150,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'هنوز پیامی ندارید!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'با دوستان خود گفتگو کنید',
                        style: TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conversation = conversations[index];
                  return _buildConversationItem(context, conversation);
                },
              );
            },
            loading: () => Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: Theme.of(context).primaryColor,
                    size: 50,
                  ),
                ),
            error: (error, stack) {
              print(error);
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text('خطا: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(conversationsProvider),
                      child: const Text('تلاش مجدد'),
                    ),
                  ],
                ),
              );
            }),
      ),
    );
  }

  Widget _buildConversationItem(
      BuildContext context, ConversationModel conversation) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              otherUserName: conversation.otherUserName ?? 'کاربر',
              otherUserAvatar: conversation.otherUserAvatar,
              otherUserId: conversation.otherUserId ?? '',
            ),
          ),
        ).then((_) {
          // بروزرسانی لیست مکالمات پس از بازگشت
          ref.refresh(conversationsProvider);
        });
      },
      leading: CircleAvatar(
        backgroundImage: conversation.otherUserAvatar != null &&
                conversation.otherUserAvatar!.isNotEmpty
            ? NetworkImage(conversation.otherUserAvatar!)
            : const AssetImage('assets/images/default_avatar.png')
                as ImageProvider,
        radius: 28,
      ),
      title: Text(
        conversation.otherUserName ?? 'کاربر',
        style: TextStyle(
          fontWeight: conversation.hasUnreadMessages
              ? FontWeight.bold
              : FontWeight.normal,
        ),
      ),
      subtitle: conversation.lastMessage != null
          ? Text(
              conversation.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: conversation.hasUnreadMessages
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: conversation.hasUnreadMessages
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            )
          : const Text('گفتگوی جدید',
              style: TextStyle(fontStyle: FontStyle.italic)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageTime != null)
            Text(
              _formatMessageTime(conversation.lastMessageTime!),
              style: TextStyle(
                fontSize: 12,
                color: conversation.hasUnreadMessages
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
            ),
          const SizedBox(height: 4),
          if (conversation.hasUnreadMessages)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Text(
                '',
                style: TextStyle(fontSize: 8),
              ),
            ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 7) {
      // نمایش تاریخ به سبک Y/M/D
      return '${time.year}/${time.month}/${time.day}';
    } else {
      return timeago.format(time, locale: 'fa');
    }
  }
}
