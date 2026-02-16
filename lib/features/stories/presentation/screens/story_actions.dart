import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/entities.dart';
import '../../core/story_enums.dart';

/// سطح حریم خصوصی استوری
enum StoryPrivacyLevel {
  everyone, // همه (عمومی)
  closeFriends, // دوستان نزدیک
  onlyMe, // فقط من
}

extension StoryPrivacyLevelX on StoryPrivacyLevel {
  String get persianTitle {
    switch (this) {
      case StoryPrivacyLevel.everyone:
        return 'همه';
      case StoryPrivacyLevel.closeFriends:
        return 'دوستان نزدیک';
      case StoryPrivacyLevel.onlyMe:
        return 'فقط من';
    }
  }

  String get persianDescription {
    switch (this) {
      case StoryPrivacyLevel.everyone:
        return 'همه دنبال‌کنندگان می‌توانند ببینند';
      case StoryPrivacyLevel.closeFriends:
        return 'فقط لیست دوستان نزدیک';
      case StoryPrivacyLevel.onlyMe:
        return 'فقط خودت می‌توانی ببینی';
    }
  }

  IconData get icon {
    switch (this) {
      case StoryPrivacyLevel.everyone:
        return Icons.public;
      case StoryPrivacyLevel.closeFriends:
        return Icons.star;
      case StoryPrivacyLevel.onlyMe:
        return Icons.lock;
    }
  }

  Color get iconColor {
    switch (this) {
      case StoryPrivacyLevel.everyone:
        return Colors.white;
      case StoryPrivacyLevel.closeFriends:
        return Colors.green;
      case StoryPrivacyLevel.onlyMe:
        return Colors.grey;
    }
  }
}

/// اکشن‌های پایین استوری با دکمه حریم خصوصی
class StoryActions extends StatefulWidget {
  final Story story;
  final bool isOwnStory;
  final String? storyOwnerUsername;
  final StoryReplyPermission replyPermission;
  final bool canReply;
  final bool isPreUpload; // ✅ حالت قبل از آپلود
  final StoryPrivacyLevel initialPrivacy;
  final Function(String message)? onReply;
  final Function(StoryReactionType reaction)? onReact;
  final VoidCallback? onViewers;
  final VoidCallback? onPost; // ✅ دکمه پست
  final Function(StoryPrivacyLevel)? onPrivacyChanged; // ✅ تغییر حریم خصوصی

  const StoryActions({
    super.key,
    required this.story,
    required this.isOwnStory,
    this.storyOwnerUsername,
    this.replyPermission = StoryReplyPermission.everyone,
    this.canReply = true,
    this.isPreUpload = false,
    this.initialPrivacy = StoryPrivacyLevel.everyone,
    this.onReply,
    this.onReact,
    this.onViewers,
    this.onPost,
    this.onPrivacyChanged,
  });

  @override
  State<StoryActions> createState() => _StoryActionsState();
}

class _StoryActionsState extends State<StoryActions> {
  final TextEditingController _replyController = TextEditingController();
  bool _showReactions = false;
  late StoryPrivacyLevel _selectedPrivacy;

  @override
  void initState() {
    super.initState();
    _selectedPrivacy = widget.initialPrivacy;
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ حالت قبل از آپلود - نمایش دکمه‌های پست و حریم خصوصی
    if (widget.isPreUpload) {
      return _buildPreUploadActions();
    }

    if (widget.isOwnStory) {
      return _buildOwnerActions();
    }
    return _buildViewerActions();
  }

  /// ✅ اکشن‌های قبل از آپلود با دکمه حریم خصوصی
  Widget _buildPreUploadActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ✅ دکمه حریم خصوصی
          _buildPrivacyButton(),

          // ✅ دکمه پست (ارسال)
          _buildPostButton(),
        ],
      ),
    );
  }

  /// ✅ دکمه حریم خصوصی با آیکون قفل
  Widget _buildPrivacyButton() {
    return GestureDetector(
      onTap: _showPrivacyBottomSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedPrivacy.icon,
              color: _selectedPrivacy.iconColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _selectedPrivacy.persianTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white70,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ دکمه پست
  Widget _buildPostButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        widget.onPost?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.send_rounded,
              color: Colors.black,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'انتشار',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ نمایش BottomSheet حریم خصوصی
  void _showPrivacyBottomSheet() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _PrivacyBottomSheet(
        selectedPrivacy: _selectedPrivacy,
        onSelect: (privacy) {
          setState(() => _selectedPrivacy = privacy);
          widget.onPrivacyChanged?.call(privacy);
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildOwnerActions() {
    return GestureDetector(
      onTap: widget.onViewers,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
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
    final ownerDisplayName =
        (widget.storyOwnerUsername?.trim().isNotEmpty ?? false)
            ? widget.storyOwnerUsername!.trim()
            : 'کاربر';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showReactions) _buildReactionPicker(),
        if (!widget.canReply)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _replyPermissionLabel(),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textDirection: TextDirection.rtl,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        enabled: widget.canReply,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _replyHint(ownerDisplayName),
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (value) {
                          if (widget.canReply && value.trim().isNotEmpty) {
                            widget.onReply?.call(value.trim());
                            _replyController.clear();
                          }
                        },
                      ),
                    ),
                    IconButton(
                      onPressed: widget.canReply
                          ? () {
                              final text = _replyController.text.trim();
                              if (text.isNotEmpty) {
                                widget.onReply?.call(text);
                                _replyController.clear();
                              }
                            }
                          : null,
                      icon: Icon(
                        Icons.send,
                        color: widget.canReply ? Colors.white : Colors.white38,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _showReactions = !_showReactions),
              onLongPress: () => _quickReact(StoryReactionType.like),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
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

  String _replyHint(String ownerDisplayName) {
    if (widget.canReply) {
      return 'پاسخ به $ownerDisplayName...';
    }

    switch (widget.replyPermission) {
      case StoryReplyPermission.off:
        return 'پاسخ‌دادن غیرفعال است';
      case StoryReplyPermission.following:
        return 'فقط دنبال‌شده‌ها می‌توانند پاسخ دهند';
      case StoryReplyPermission.everyone:
        return 'پاسخ‌دادن در دسترس نیست';
    }
  }

  String _replyPermissionLabel() {
    switch (widget.replyPermission) {
      case StoryReplyPermission.off:
        return 'اجازه پاسخ این استوری غیرفعال است';
      case StoryReplyPermission.following:
        return 'فقط افرادی که صاحب استوری دنبال می‌کند مجاز هستند';
      case StoryReplyPermission.everyone:
        return 'ارسال پاسخ ممکن نیست';
    }
  }

  Widget _buildReactionPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
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
    HapticFeedback.lightImpact();
    widget.onReact?.call(reaction);
    setState(() => _showReactions = false);
  }
}

/// ✅ BottomSheet انتخاب حریم خصوصی
class _PrivacyBottomSheet extends StatelessWidget {
  final StoryPrivacyLevel selectedPrivacy;
  final Function(StoryPrivacyLevel) onSelect;

  const _PrivacyBottomSheet({
    required this.selectedPrivacy,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // هندل
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // عنوان
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'چه کسانی ببینند؟',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // گزینه‌ها
            ...StoryPrivacyLevel.values.map((privacy) {
              final isSelected = privacy == selectedPrivacy;
              return _buildPrivacyOption(privacy, isSelected);
            }),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacyOption(StoryPrivacyLevel privacy, bool isSelected) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(privacy);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // آیکون
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: privacy.iconColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                privacy.icon,
                color: privacy.iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // متن
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    privacy.persianTitle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    privacy.persianDescription,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // تیک انتخاب
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
