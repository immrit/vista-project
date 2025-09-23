import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../model/conversation_model.dart';
import '../../services/user_profile_service.dart';
import '../util/time_utils.dart';
import '../../main.dart';

/// ویجت برای نمایش یک آیتم مکالمه با enrichment خودکار
class EnrichedConversationListItem extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const EnrichedConversationListItem({
    super.key,
    required this.conversation,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<EnrichedConversationListItem> createState() =>
      _EnrichedConversationListItemState();
}

class _EnrichedConversationListItemState
    extends State<EnrichedConversationListItem> {
  ConversationModel? _enrichedConversation;
  bool _isEnriching = false;
  final UserProfileService _userProfileService = UserProfileService();

  StreamSubscription<Map<String, Map<String, String?>>>?
      _profileUpdatesSubscription;

  @override
  void initState() {
    super.initState();

    // 1) Try memory cache immediately to avoid flicker
    final cached = _userProfileService.getCachedProfile(
      widget.conversation.otherUserId ?? '',
    );
    if (cached != null && widget.conversation.otherUserName == null) {
      _enrichedConversation = widget.conversation.copyWith(
        otherUserName: cached['username'] ?? cached['full_name'],
        otherUserAvatar: cached['avatar_url'],
      );
    }

    // 2) Listen to real-time profile updates
    _profileUpdatesSubscription = _userProfileService.profileUpdates.listen(
      (updates) {
        final userId = widget.conversation.otherUserId;
        if (userId != null && updates.containsKey(userId)) {
          final updatedProfile = updates[userId];
          if (updatedProfile != null && mounted) {
            setState(() {
              _enrichedConversation =
                  (_enrichedConversation ?? widget.conversation).copyWith(
                otherUserName:
                    updatedProfile['username'] ?? updatedProfile['full_name'],
                otherUserAvatar: updatedProfile['avatar_url'],
              );
            });
          }
        }
      },
    );

    // 3) Then ensure enrichment (no-op if already enriched)
    _enrichConversation();
  }

  Future<void> _enrichConversation() async {
    if (_enrichedConversation != null || _isEnriching) return;

    setState(() {
      _isEnriching = true;
    });

    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId != null) {
        final enriched = await _userProfileService
            .enrichConversationWithUserData(widget.conversation, currentUserId);

        if (mounted) {
          setState(() {
            _enrichedConversation = enriched;
            _isEnriching = false;
          });
        }
      }
    } catch (e) {
      print('⚠️ Error enriching conversation ${widget.conversation.id}: $e');
      if (mounted) {
        setState(() {
          _isEnriching = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _profileUpdatesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final conversation = _enrichedConversation ?? widget.conversation;

    // تشخیص نام و آواتار کاربر دیگر
    String displayName = 'در حال بارگذاری...';
    String? avatarUrl;

    if (conversation.otherUserName?.isNotEmpty == true) {
      displayName = conversation.otherUserName!;
      avatarUrl = conversation.otherUserAvatar;
    } else {
      // اگر اطلاعات کاربر موجود نیست، منتظر enrichment بمان
      displayName = 'در حال بارگذاری...';
      avatarUrl = null;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _buildAvatar(displayName, avatarUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.lastMessageTime != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            TimeUtils.formatMessageTime(
                                conversation.lastMessageTime!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: conversation.formattedLastMessage != null
                              ? Text(
                                  conversation.formattedLastMessage!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: conversation.unreadCount > 0
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : conversation.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildAvatar(String displayName, String? avatarUrl) {
    if (avatarUrl?.isNotEmpty == true) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
        onBackgroundImageError: (_, __) {},
        child: avatarUrl.isEmpty
            ? Text(displayName.isNotEmpty ? displayName[0] : 'U')
            : null,
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.blue.shade100,
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
}
