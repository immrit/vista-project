import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../provider/chat_provider.dart' as legacy_chat;

// Import necessary providers if they exist in valid locations
// Assuming similar structure to TelegramProfileScreen imports

class ChatProfileDetails extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatProfileDetails({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  ConsumerState<ChatProfileDetails> createState() => _ChatProfileDetailsState();
}

class _ChatProfileDetailsState extends ConsumerState<ChatProfileDetails>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Providers (using legacy imports as per original file)
    final userProfileAsync =
        ref.watch(legacy_chat.userProfileProvider(widget.otherUserId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildSliverAppBar(context, theme, isDark),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildActionButtons(theme, isDark),
                const Divider(height: 1),
                _buildUserInfo(theme, isDark, userProfileAsync),
                const SizedBox(height: 16),
                _buildMediaTabs(theme, isDark),
              ],
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMediaGrid(isDark), // Media
                _buildEmptyTab("فایل"), // Files
                _buildEmptyTab("صدا"), // Voice
                _buildEmptyTab("لینک"), // Links
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(
      BuildContext context, ThemeData theme, bool isDark) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: isDark ? Colors.white : Colors.black,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.otherUserAvatar != null)
              CachedNetworkImage(
                imageUrl: widget.otherUserAvatar!,
                fit: BoxFit.cover,
              )
            else
              Container(
                color: isDark ? Colors.white10 : Colors.black12,
                child: Center(
                    child: Text(widget.otherUserName[0],
                        style: const TextStyle(fontSize: 80))),
              ),
            // Gradient for text visibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black12,
                    Colors.transparent,
                    Colors.black54,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Text(
                widget.otherUserName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(Icons.search, "جستجو", theme),
          _buildActionButton(Icons.notifications_none, "بی‌صدا", theme),
          _buildActionButton(Icons.block, "مسدود", theme, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, ThemeData theme,
      {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: theme.cardColor,
          child: Icon(icon, color: color ?? theme.iconTheme.color),
        ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  Widget _buildUserInfo(
      ThemeData theme, bool isDark, AsyncValue userProfileAsync) {
    return userProfileAsync.when(
      data: (data) {
        final bio = data?['bio'] as String?;
        final username = data?['username'] as String?;
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (bio != null) ...[
                Text("بیوگرافی",
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 4),
                Text(bio, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
              ],
              if (username != null) ...[
                Text("نام کاربری",
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 4),
                Text("@$username", style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildMediaTabs(ThemeData theme, bool isDark) {
    return TabBar(
      controller: _tabController,
      labelColor: isDark ? Colors.white : Colors.black,
      unselectedLabelColor: Colors.grey,
      indicatorColor: isDark ? Colors.white : Colors.black,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: "رسانه"),
        Tab(text: "فایل"),
        Tab(text: "صدا"),
        Tab(text: "لینک"),
      ],
    );
  }

  Widget _buildMediaGrid(bool isDark) {
    final mediaAsync =
        ref.watch(legacy_chat.sharedMediaProvider(widget.conversationId));

    return mediaAsync.when(
      data: (messages) {
        final media = messages
            .where((m) =>
                m.attachmentUrl != null &&
                (m.attachmentType == 'image' || m.attachmentType == 'video'))
            .toList();

        if (media.isEmpty) {
          return const Center(child: Text("بدون رسانه"));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: media.length,
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: media[index].attachmentUrl!,
              fit: BoxFit.cover,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text("خطا")),
    );
  }

  Widget _buildEmptyTab(String title) {
    return Center(child: Text("بدون $title"));
  }
}
