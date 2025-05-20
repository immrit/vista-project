import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../model/conversation_model.dart';
import '../../../provider/chat_provider.dart';

import 'ChatScreen.dart';

class ChatConversationsScreen extends ConsumerStatefulWidget {
  const ChatConversationsScreen({super.key});

  @override
  ConsumerState<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState
    extends ConsumerState<ChatConversationsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print('🚀 شروع صفحه مکالمات');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔄 درخواست اولیه مکالمات');
      ref.refresh(conversationsStreamProvider);
    });
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
    print('🏗️ ساخت مجدد صفحه مکالمات');
    // استفاده از conversationsProvider برای نمایش سریع‌تر کش
    final conversationsAsync = ref.watch(conversationsProvider);

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
                              otherUserAvatar: conversation.otherUserAvatar ??
                                  'lib/view/util/images/default-avatar.jpg',
                              otherUserId: conversation.otherUserId ?? '',
                            ),
                          ),
                        );
                      }));
            },
          ),
        ],
      ),
      body: conversationsAsync.when(
        data: (conversations) {
          print('📋 نمایش ${conversations.length} مکالمه');
          if (conversations.isEmpty) {
            return const Center(
              child: Text('هنوز مکالمه‌ای ندارید'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              print('🔄 بروزرسانی دستی لیست');
              ref.invalidate(conversationsProvider);
              ref.invalidate(conversationsStreamProvider);
            },
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return _buildConversationItem(context, conversation);
              },
            ),
          );
        },
        loading: () {
          print('⌛ در حال بارگذاری مکالمات');
          return ChatListShimmer();
        },
        error: (error, stack) {
          print('❌ خطا در نمایش مکالمات: $error');
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('خطا در دریافت مکالمات'),
                ElevatedButton(
                  onPressed: () {
                    print('🔄 تلاش مجدد');
                    ref.invalidate(conversationsProvider);
                    ref.invalidate(conversationsStreamProvider);
                  },
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        },
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
                      ? Colors.grey
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
                // شمارنده پیام‌های خوانده‌نشده
                if (conversation.unreadCount != null &&
                    conversation.unreadCount! > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${conversation.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
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
                child: Text('هیچ مکالمه‌ای با این مشخصات یافت نشد'),
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
          loading: () => ChatListShimmer(),
          error: (_, __) => const Center(child: Text('خطا در دریافت اطلاعات')),
        );
      },
    );
  }
}

class ChatListShimmer extends StatelessWidget {
  const ChatListShimmer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 10,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
