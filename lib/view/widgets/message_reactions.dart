import 'package:flutter/material.dart';

class MessageReactions extends StatelessWidget {
  final List<String> reactions;
  final Function(String) onReactionTap;
  final bool isMe;

  const MessageReactions({
    super.key,
    required this.reactions,
    required this.onReactionTap,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // شمارش reactions
    final reactionCounts = <String, int>{};
    for (final reaction in reactions) {
      reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
    }

    // حداکثر 3 reaction نمایش دهیم
    final displayReactions = reactionCounts.entries.take(3).toList();

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        left: isMe ? 8 : 64,
        right: isMe ? 64 : 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: displayReactions.map((entry) {
          final emoji = entry.key;
          final count = entry.value;

          return GestureDetector(
            onTap: () => onReactionTap(emoji),
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF3A3A3A) : Colors.grey[300]!,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    emoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 4),
                    Text(
                      count.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Widget برای اضافه کردن reaction جدید
class AddReactionButton extends StatelessWidget {
  final Function() onTap;

  const AddReactionButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.add_reaction_rounded,
          size: 18,
          color: theme.primaryColor,
        ),
      ),
    );
  }
}

// Bottom sheet برای انتخاب emoji reaction
class ReactionPickerSheet extends StatelessWidget {
  final Function(String) onReactionSelected;

  const ReactionPickerSheet({
    super.key,
    required this.onReactionSelected,
  });

  static const List<String> commonReactions = [
    '❤️', '👍', '👎', '😄', '😢', '😮', '👏', '🔥', '💯', '🎉',
    '💔', '🤔', '😅', '😂', '😍', '🥰', '😘', '😉', '😎', '🤗',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'انتخاب واکنش',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          // Reactions grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: commonReactions.length,
              itemBuilder: (context, index) {
                final emoji = commonReactions[index];
                return GestureDetector(
                  onTap: () {
                    onReactionSelected(emoji);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

