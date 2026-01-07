import 'package:flutter/material.dart';

import '../../domain/entities/entities.dart';
import '../../core/story_enums.dart';

/// اکشن‌های پایین استوری
class StoryActions extends StatefulWidget {
  final Story story;
  final bool isOwnStory;
  final Function(String message)? onReply;
  final Function(StoryReactionType reaction)? onReact;
  final VoidCallback? onViewers;

  const StoryActions({
    super.key,
    required this.story,
    required this.isOwnStory,
    this.onReply,
    this.onReact,
    this.onViewers,
  });

  @override
  State<StoryActions> createState() => _StoryActionsState();
}

class _StoryActionsState extends State<StoryActions> {
  final TextEditingController _replyController = TextEditingController();
  bool _showReactions = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isOwnStory) {
      return _buildOwnerActions();
    }
    return _buildViewerActions();
  }

  Widget _buildOwnerActions() {
    return GestureDetector(
      onTap: widget.onViewers,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.visibility, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '${widget.story.viewsCount} بازدید',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildViewerActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // واکنش‌ها
        if (_showReactions) _buildReactionPicker(),

        // فیلد پاسخ
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'پاسخ به ${widget.story.userId}...',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            widget.onReply?.call(value);
                            _replyController.clear();
                          }
                        },
                      ),
                    ),
                    // دکمه ارسال
                    IconButton(
                      onPressed: () {
                        if (_replyController.text.isNotEmpty) {
                          widget.onReply?.call(_replyController.text);
                          _replyController.clear();
                        }
                      },
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // دکمه واکنش
            GestureDetector(
              onTap: () => setState(() => _showReactions = !_showReactions),
              onLongPress: () => _quickReact(StoryReactionType.like),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('❤️', style: TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactionPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: StoryReactionType.values.map((reaction) {
          return GestureDetector(
            onTap: () => _quickReact(reaction),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _quickReact(StoryReactionType reaction) {
    widget.onReact?.call(reaction);
    setState(() => _showReactions = false);
  }
}
