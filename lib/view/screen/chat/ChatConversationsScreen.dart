import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../model/channel_model.dart';
import '../../../model/conversation_model.dart';
import '../../../provider/channel_provider.dart';
import '../../../provider/chat_provider.dart';

import '../../../provider/combined_chat_provider.dart';
import '../channel/ChannelScreen.dart';
import '../channel/CreateChannelScreen.dart';
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

    // همگام‌سازی فوری با سرور و کش در ابتدای نمایش صفحه
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔄 درخواست اولیه مکالمات');
      await _syncConversations();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  // متد جدید برای همگام‌سازی مکالمات
  Future<void> _syncConversations() async {
    try {
      // نمایش فوری کش
      final cachedConversations =
          await ref.read(chatServiceProvider).getCachedConversations();
      if (cachedConversations.isNotEmpty) {
        // این خط را اصلاح کنید:
        // ref.read(conversationsProvider.notifier).state = AsyncValue.data(cachedConversations);
        // به جای آن invalidate کنید تا provider دوباره اجرا شود:
        ref.invalidate(conversationsProvider);
      }

      // دریافت اطلاعات جدید از سرور
      await ref.refresh(conversationsStreamProvider);

      // بروزرسانی وضعیت پیام‌های خوانده نشده
      await ref.read(chatServiceProvider).updateUnreadMessages();
    } catch (e) {
      print('❌ خطا در همگام‌سازی مکالمات: $e');
    }
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
    super.build(context);

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
                  onConversationSelected: _navigateToChat,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateOptions(context),
          ),
        ],
      ),
      body: _buildCombinedList(),
    );
  }

  Widget _buildCombinedList() {
    return Consumer(
      builder: (context, ref, child) {
        final conversationsAsync = ref.watch(combinedConversationsProvider);
        final channelsAsync = ref.watch(channelsProvider);

        return RefreshIndicator(
          onRefresh: () async {
            await _syncConversations();
            ref.refresh(channelsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // بخش کانال‌ها
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'کانال‌ها',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateChannelScreen(),
                          ),
                        ),
                        child: const Text('ایجاد کانال'),
                      ),
                    ],
                  ),
                ),
              ),
              channelsAsync.when(
                data: (channels) => channels.isEmpty
                    ? const SliverToBoxAdapter(child: SizedBox())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildChannelItem(channels[index]),
                          childCount: channels.length,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Center(child: Text('خطا: $error')),
                ),
              ),

              // جداکننده
              const SliverToBoxAdapter(
                child: Divider(thickness: 1.5),
              ),

              // بخش گفتگوها
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: const [
                      Text(
                        'گفتگوها',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              conversationsAsync.when(
                data: (conversations) => conversations.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Center(child: Text('گفتگویی وجود ندارد')),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildConversationItem(
                            context,
                            conversations[index],
                            onTap: () => _navigateToChat(conversations[index]),
                          ),
                          childCount: conversations.length,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => SliverToBoxAdapter(
                  child: Center(child: Text('خطا: $error')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('گفتگوی جدید'),
              onTap: () {
                Navigator.pop(context);
                // نمایش دیالوگ انتخاب کاربر برای گفتگو
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('ایجاد کانال'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreateChannelScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelItem(ChannelModel channel) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: channel.avatarUrl != null
            ? CachedNetworkImageProvider(channel.avatarUrl!)
            : null,
        child: channel.avatarUrl == null
            ? Text(channel.name[0].toUpperCase())
            : null,
      ),
      title: Text(channel.name),
      subtitle: Text(channel.lastMessage ?? 'کانال خالی'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (channel.lastMessageTime != null)
            Text(
              _formatMessageTime(channel.lastMessageTime!),
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 4),
          if (!channel.isSubscribed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'عضویت',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: () => _navigateToChannel(channel),
    );
  }

  void _navigateToChannel(ChannelModel channel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChannelScreen(channel: channel),
      ),
    );
  }

  // متد جداگانه برای مسیریابی به صفحه چت
  void _navigateToChat(ConversationModel conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          otherUserName: conversation.otherUserName ?? 'کاربر',
          otherUserAvatar: conversation.otherUserAvatar ??
              'assets/images/default_avatar.png',
          otherUserId: conversation.otherUserId ?? '',
        ),
      ),
    ).then((_) => _syncConversations()); // همگام‌سازی پس از بازگشت
  }

  Widget _buildConversationItem(
      BuildContext context, ConversationModel conversation,
      {required VoidCallback onTap}) {
    return Dismissible(
      key: Key(conversation.id),
      direction: DismissDirection.endToStart,
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
        onTap: onTap,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundImage: conversation.otherUserAvatar != null &&
                      conversation.otherUserAvatar!.isNotEmpty
                  ? NetworkImage(conversation.otherUserAvatar!)
                  : const AssetImage('assets/images/default_avatar.png')
                      as ImageProvider,
              radius: 28,
            ),

            // نشانگر وضعیت آنلاین (زیر نقطه قرمز)
            Positioned(
              right: -2,
              bottom: -2,
              child: Consumer(
                builder: (context, ref, child) {
                  final isOnlineAsync = ref.watch(
                      userOnlineStatusStreamProvider(
                          conversation.otherUserId ?? ''));
                  return isOnlineAsync.when(
                    data: (isOnline) => isOnline
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ),
          ],
        ),
        title: Text(
          conversation.otherUserName ?? 'کاربر',
          style: TextStyle(
            fontWeight: conversation.hasUnreadMessages
                ? FontWeight.bold
                : FontWeight.normal,
            color: conversation.hasUnreadMessages
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
        ),
        subtitle: Text(
          conversation.lastMessage ?? 'گفتگوی جدید',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: conversation.hasUnreadMessages
                ? FontWeight.bold
                : FontWeight.normal,
            color: conversation.hasUnreadMessages
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
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
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                  fontWeight: conversation.hasUnreadMessages
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            const SizedBox(height: 4),
            if (conversation.hasUnreadMessages)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // ...existing trailing menu...
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

class ChannelSearchDelegate extends SearchDelegate<ChannelModel> {
  final WidgetRef ref;
  final Function(ChannelModel) onChannelSelected;

  ChannelSearchDelegate({
    required this.ref,
    required this.onChannelSelected,
  });

  @override
  String get searchFieldLabel => 'جستجو در کانال‌ها...';

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
      onPressed: () => close(context, ChannelModel.empty()),
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
        final channelsAsync = ref.watch(channelsProvider);

        return channelsAsync.when(
          data: (channels) {
            final filteredChannels = channels
                .where((channel) =>
                    channel.name.toLowerCase().contains(query.toLowerCase()) ||
                    (channel.description
                            ?.toLowerCase()
                            .contains(query.toLowerCase()) ??
                        false))
                .toList();

            if (filteredChannels.isEmpty) {
              return const Center(
                child: Text('هیچ کانالی با این مشخصات یافت نشد'),
              );
            }

            return ListView.builder(
              itemCount: filteredChannels.length,
              itemBuilder: (context, index) {
                final channel = filteredChannels[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: channel.avatarUrl != null
                        ? CachedNetworkImageProvider(channel.avatarUrl!)
                        : null,
                    child: channel.avatarUrl == null
                        ? Text(channel.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(channel.name),
                  subtitle: Text(channel.description ?? ''),
                  onTap: () {
                    onChannelSelected(channel);
                    close(context, channel);
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('خطا در جستجو')),
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
