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

// اضافه کردن متغیر برای جستجو
  final String _searchQuery = '';
  List<ConversationModel> _filteredConversations = [];

// اضافه کردن متد برای فیلتر کردن گفتگوها
  void _filterConversations(
      List<ConversationModel> conversations, String query) {
    if (query.isEmpty) {
      _filteredConversations = conversations;
    } else {
      _filteredConversations = conversations
          .where((conversation) =>
              conversation.otherUserName
                      ?.toLowerCase()
                      .contains(query.toLowerCase()) ==
                  true ||
              (conversation.lastMessage
                      ?.toLowerCase()
                      .contains(query.toLowerCase()) ??
                  false))
          .toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('پیام‌ها'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                  context: context,
                  delegate: ChatSearchDelegate(
                      ref: ref,
                      onConversationSelected: (conversation) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              conversationId: conversation.id,
                              otherUserName:
                                  conversation.otherUserName ?? 'کاربر',
                              otherUserAvatar: conversation.otherUserAvatar,
                              otherUserId: conversation.otherUserId ?? '',
                            ),
                          ),
                        );
                      }));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(conversationsProvider);
        },
        child: conversationsAsync.when(
            data: (conversations) {
              // حالت بدون مکالمه
              if (conversations.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        'هنوز گفتگویی شروع نکرده‌اید',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'برای شروع گفتگو، به صفحه کاربران بروید و با کاربر مورد نظر چت کنید',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                          ),
                        ),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // ناوبری به صفحه کاربران
                        },
                        icon: Icon(Icons.people),
                        label: Text('مشاهده کاربران'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart, // فقط از راست به چپ (برای RTL)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('حذف گفتگو'),
              content: const Text('آیا از حذف این گفتگو اطمینان دارید؟'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('انصراف'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('حذف'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        // حذف گفتگو
        ref
            .read(messageNotifierProvider.notifier)
            .deleteConversation(conversation.id);

        // نمایش پیام موفقیت‌آمیز
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('گفتگو با موفقیت حذف شد'),
            action: SnackBarAction(
              label: 'بازگرداندن',
              onPressed: () {
                // در اینجا می‌توانید منطق بازگرداندن گفتگو را پیاده‌سازی کنید
                ref.refresh(conversationsProvider);
              },
            ),
          ),
        );
      },
      child: ListTile(
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
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
            // منوی بیشتر
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('حذف گفتگو'),
                      content:
                          const Text('آیا از حذف این گفتگو اطمینان دارید؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('انصراف'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style:
                              TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('حذف'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(messageNotifierProvider.notifier)
                        .deleteConversation(conversation.id);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('گفتگو با موفقیت حذف شد')),
                      );
                    }
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('حذف گفتگو', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
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

class ChatSearchDelegate extends SearchDelegate<ConversationModel> {
  final WidgetRef ref;
  final Function(ConversationModel) onConversationSelected;

  ChatSearchDelegate({
    required this.ref,
    required this.onConversationSelected,
  });

  @override
  String get searchFieldLabel => 'جستجو در گفتگوها...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, ConversationModel.empty());
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, child) {
        final conversationsAsync = ref.watch(conversationsProvider);

        return conversationsAsync.when(
          data: (conversations) {
            final filteredConversations = conversations
                .where((conversation) =>
                    conversation.otherUserName
                            ?.toLowerCase()
                            .contains(query.toLowerCase()) ==
                        true ||
                    (conversation.lastMessage
                            ?.toLowerCase()
                            .contains(query.toLowerCase()) ??
                        false))
                .toList();

            if (filteredConversations.isEmpty) {
              return const Center(
                child: Text('موردی یافت نشد'),
              );
            }

            return ListView.builder(
              itemCount: filteredConversations.length,
              itemBuilder: (context, index) {
                final conversation = filteredConversations[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: conversation.otherUserAvatar != null &&
                            conversation.otherUserAvatar!.isNotEmpty
                        ? NetworkImage(conversation.otherUserAvatar!)
                        : const AssetImage('assets/images/default_avatar.png')
                            as ImageProvider,
                  ),
                  title: Text(conversation.otherUserName ?? 'کاربر'),
                  subtitle: conversation.lastMessage != null
                      ? Text(
                          conversation.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : const Text('گفتگوی جدید'),
                  onTap: () {
                    onConversationSelected(conversation);
                    close(context, conversation);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('خطا در دریافت اطلاعات')),
        );
      },
    );
  }
}
