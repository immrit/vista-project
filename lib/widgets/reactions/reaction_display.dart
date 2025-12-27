import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../provider/reaction_provider.dart';

import '../../model/message_reaction_ui.dart';

class ReactionDisplay extends ConsumerWidget {
  final Map<String, List<String>> reactions;
  final String currentUserId;
  final String messageId;
  final String conversationId;
  final bool isMyMessage;
  final VoidCallback? onTap; // نمایش لیست کامل کسانی که reaction داده‌اند

  const ReactionDisplay({
    required this.reactions,
    required this.currentUserId,
    required this.messageId,
    required this.conversationId,
    required this.isMyMessage,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // تبدیل reactions به UI model و مرتب‌سازی
    final reactionsList = reactions.entries.map((entry) {
      return MessageReactionUI(
        emoji: entry.key,
        userIds: entry.value,
        hasCurrentUser: entry.value.contains(currentUserId),
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        right: isMyMessage ? 8 : 0,
        left: isMyMessage ? 0 : 8,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMyMessage ? WrapAlignment.end : WrapAlignment.start,
        children: reactionsList.map((reaction) {
          return InkWell(
            onTap: () async {
              HapticFeedback.lightImpact();

              // ✅ استفاده از toggleReaction از MessageNotifier برای optimistic update
              try {
                final reactionService = ref.read(reactionServiceProvider);
                await reactionService.toggleReaction(
                  messageId: messageId,
                  conversationId: conversationId,
                  emoji: reaction.emoji,
                );
              } catch (e) {
                // Fallback or log error
                debugPrint('Error toggling reaction: $e');
              }
            },
            onLongPress: onTap, // Long press برای نمایش لیست کامل
            borderRadius: BorderRadius.circular(12),
            child: _ReactionChip(
              emoji: reaction.emoji,
              count: reaction.count,
              isReactedByMe: reaction.hasCurrentUser,
              isDark: isDark,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ✅ Chip نمایش هر reaction
class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isReactedByMe;
  final bool isDark;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isReactedByMe,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isReactedByMe
            ? (isDark
                ? Colors.blue.withOpacity(0.25)
                : Colors.blue.withOpacity(0.15))
            : (isDark
                ? Colors.grey.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReactedByMe
              ? (isDark
                  ? Colors.blue.withOpacity(0.5)
                  : Colors.blue.withOpacity(0.4))
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isReactedByMe
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: isReactedByMe ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Text(
              emoji,
              style: const TextStyle(
                fontSize: 14,
                height: 1.0,
              ),
            ),
          ),
          if (count > 1) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isReactedByMe ? FontWeight.bold : FontWeight.w600,
                height: 1.2,
                color: isReactedByMe
                    ? (isDark ? Colors.blue[300] : Colors.blue[700])
                    : (isDark ? Colors.white70 : Colors.grey[700]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
