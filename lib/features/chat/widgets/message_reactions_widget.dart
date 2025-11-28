// lib/features/chat/widgets/message_reactions_widget.dart
//
// نمایش واکنش‌های پیام و bottom sheet انتخاب واکنش
//

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message_reaction.dart';
import '../services/message_reactions_service.dart';
import '../theme/chat_theme.dart';

/// Provider برای سرویس reactions
final messageReactionsServiceProvider = Provider((ref) {
  return MessageReactionsService();
});

/// نمایش واکنش‌های زیر پیام
class MessageReactionsWidget extends ConsumerWidget {
  final String messageId;
  final List<MessageReaction> reactions;
  final bool isMine;
  final VoidCallback? onReactionTap;

  const MessageReactionsWidget({
    super.key,
    required this.messageId,
    required this.reactions,
    required this.isMine,
    this.onReactionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final service = ref.read(messageReactionsServiceProvider);
    final currentUserId = service.getCurrentUserId() ?? '';

    final summaries = ReactionSummary.groupReactions(reactions, currentUserId);

    return Container(
      margin: EdgeInsets.only(
        top: 4,
        left: isMine ? 0 : 48,
        right: isMine ? 48 : 0,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: summaries.map((summary) {
          return _ReactionChip(
            summary: summary,
            onTap: () => _showReactionDetails(context, summary),
            onLongPress: () async {
              HapticFeedback.mediumImpact();
              // اگر واکنش خودمون باشه، حذفش کن
              if (summary.hasCurrentUser) {
                await ref.read(messageReactionsServiceProvider).toggleReaction(
                  messageId: messageId,
                  emoji: summary.emoji,
                );
              }
            },
          );
        }).toList(),
      ),
    );
  }

  void _showReactionDetails(BuildContext context, ReactionSummary summary) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReactionDetailsSheet(summary: summary),
    );
  }
}

/// چیپ واکنش
class _ReactionChip extends StatelessWidget {
  final ReactionSummary summary;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ReactionChip({
    required this.summary,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: summary.hasCurrentUser
              ? theme.sendButtonColor.withOpacity(0.15)
              : theme.inputBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: summary.hasCurrentUser
                ? theme.sendButtonColor.withOpacity(0.3)
                : theme.dividerColor,
            width: summary.hasCurrentUser ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.emoji,
              style: const TextStyle(fontSize: 14),
            ),
            if (summary.count > 1) ...[
              const SizedBox(width: 4),
              Text(
                '${summary.count}',
                style: TextStyle(
                  color: summary.hasCurrentUser
                      ? theme.sendButtonColor
                      : theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: summary.hasCurrentUser
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// صفحه جزئیات واکنش (کی واکنش داده)
class _ReactionDetailsSheet extends StatelessWidget {
  final ReactionSummary summary;

  const _ReactionDetailsSheet({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 16),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  summary.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Text(
                  '${summary.count} نفر',
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // List
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: summary.reactions.length,
              itemBuilder: (context, index) {
                final reaction = summary.reactions[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.sendButtonColor.withOpacity(0.1),
                    backgroundImage: reaction.userAvatar != null
                        ? NetworkImage(reaction.userAvatar!)
                        : null,
                    child: reaction.userAvatar == null
                        ? Text(
                            reaction.userName[0].toUpperCase(),
                            style: TextStyle(
                              color: theme.sendButtonColor,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  title: Text(
                    reaction.userName,
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    _formatTime(reaction.createdAt),
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'هم‌اکنون';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    return '${diff.inDays} روز پیش';
  }
}

/// Reaction Picker - انتخابگر واکنش
class ReactionPickerSheet extends ConsumerWidget {
  final String messageId;
  final VoidCallback? onReactionAdded;

  const ReactionPickerSheet({
    super.key,
    required this.messageId,
    this.onReactionAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String messageId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => ReactionPickerSheet(messageId: messageId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.chatTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Grid of reactions
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: ReactionType.defaults.map((emoji) {
              return _ReactionButton(
                emoji: emoji,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  try {
                    await ref.read(messageReactionsServiceProvider).toggleReaction(
                      messageId: messageId,
                      emoji: emoji,
                    );
                    onReactionAdded?.call();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('خطا: $e'),
                          backgroundColor: theme.errorColor,
                        ),
                      );
                    }
                  }
                },
              );
            }).toList(),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.emoji,
    required this.onTap,
  });

  @override
  State<_ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<_ReactionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.chatTheme;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: theme.inputBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor,
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

