// lib/features/chat/widgets/reactions_detail_sheet.dart

import 'package:flutter/material.dart';
import '../theme/chat_theme.dart';
import 'improved_animated_message_bubble.dart';

/// Shows a DraggableScrollableSheet with per-emoji tab breakdown of reactions.
Future<void> showReactionsDetailSheet({
  required BuildContext context,
  required List<MessageReaction> reactions,
  required ChatTheme theme,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReactionsDetailSheet(reactions: reactions, theme: theme),
  );
}

class _ReactionsDetailSheet extends StatefulWidget {
  final List<MessageReaction> reactions;
  final ChatTheme theme;

  const _ReactionsDetailSheet({
    required this.reactions,
    required this.theme,
  });

  @override
  State<_ReactionsDetailSheet> createState() => _ReactionsDetailSheetState();
}

class _ReactionsDetailSheetState extends State<_ReactionsDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // "all" tab + one tab per distinct emoji
  late final List<String?> _tabs; // null = "همه"

  @override
  void initState() {
    super.initState();
    final emojis = widget.reactions.map((r) => r.emoji).toSet().toList();
    _tabs = [null, ...emojis];
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<MessageReaction> _reactionsForTab(String? emoji) {
    if (emoji == null) return widget.reactions;
    return widget.reactions.where((r) => r.emoji == emoji).toList();
  }

  int _countForTab(String? emoji) {
    if (emoji == null) {
      return widget.reactions.fold(0, (sum, r) => sum + r.count);
    }
    return widget.reactions
        .where((r) => r.emoji == emoji)
        .fold(0, (sum, r) => sum + r.count);
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.theme.isDark
        ? const Color(0xFF1C1C2E)
        : const Color(0xFFF5F5F5);

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.theme.dividerColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  'واکنش‌ها',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: widget.theme.textColor,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: widget.theme.sendButtonColor,
                labelColor: widget.theme.sendButtonColor,
                unselectedLabelColor:
                    widget.theme.secondaryTextColor,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: _tabs.map((emoji) {
                  final count = _countForTab(emoji);
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emoji ?? 'همه',
                          style: const TextStyle(fontSize: 15),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          count.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((emoji) {
                    final list = _reactionsForTab(emoji);
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'هیچ واکنشی وجود ندارد',
                          style: TextStyle(
                            color: widget.theme.secondaryTextColor,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final reaction = list[index];
                        return _ReactionUserTile(
                          reaction: reaction,
                          theme: widget.theme,
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReactionUserTile extends StatelessWidget {
  final MessageReaction reaction;
  final ChatTheme theme;

  const _ReactionUserTile({required this.reaction, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (reaction.reactors.isEmpty) {
      return ListTile(
        leading: Text(reaction.emoji, style: const TextStyle(fontSize: 22)),
        title: Text(
          '${reaction.count} نفر',
          style: TextStyle(color: theme.textColor, fontSize: 14),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: reaction.reactors.map((reactor) {
        return ListTile(
          leading: CircleAvatar(
            radius: 18,
            backgroundImage:
                reactor.userAvatar != null && reactor.userAvatar!.isNotEmpty
                    ? NetworkImage(reactor.userAvatar!)
                    : null,
            child:
                reactor.userAvatar == null || reactor.userAvatar!.isEmpty
                    ? Text(
                        (reactor.userName?.isNotEmpty == true
                            ? reactor.userName![0]
                            : '?'),
                        style: const TextStyle(fontSize: 14),
                      )
                    : null,
          ),
          title: Text(
            reactor.userName ?? reactor.userId,
            style: TextStyle(color: theme.textColor, fontSize: 14),
          ),
          trailing: Text(reaction.emoji, style: const TextStyle(fontSize: 18)),
        );
      }).toList(),
    );
  }
}
