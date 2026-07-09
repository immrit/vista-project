import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../model/ProfileModel.dart';
import '../../../../utils/const.dart';
import '../../chat/screens/modern_chat_screen.dart';
import '../data/models/profile_note_model.dart';
import 'note_input_sheet.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// باتم‌شیت نمایش متن کامل وضعیت
class NoteViewerSheet extends ConsumerWidget {
  final ProfileNoteModel note;
  final ProfileModel userProfile;
  final bool isCurrentUser;

  const NoteViewerSheet({
    super.key,
    required this.note,
    required this.userProfile,
    required this.isCurrentUser,
  });

  /// نمایش باتم‌شیت
  static Future<void> show(
    BuildContext context, {
    required ProfileNoteModel note,
    required ProfileModel userProfile,
    required bool isCurrentUser,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => NoteViewerSheet(
        note: note,
        userProfile: userProfile,
        isCurrentUser: isCurrentUser,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkSurfaceVariant : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final noteTextDirection = _resolveTextDirection(context, note.content);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 8),

            // Header with User Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        isDark ? Colors.grey[800] : Colors.grey[200],
                    backgroundImage: userProfile.avatarUrl != null
                        ? CachedNetworkImageProvider(userProfile.avatarUrl!)
                        : const AssetImage(defaultAvatarUrl) as ImageProvider,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProfile.username,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      ...[
                        const SizedBox(height: 2),
                        Text(
                          _getTimeAgo(note.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  if (isCurrentUser)
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: textColor,
                      onPressed: () {
                        // Close this sheet and open input sheet for editing
                        Navigator.pop(context);
                        _showEditSheet(context, ref);
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Full Note Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                note.content,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
                textDirection: noteTextDirection,
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons (if not current user)
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModernChatScreen(
                                args: ChatScreenArgs(
                                  conversationId: '',
                                  otherUserId: note.userId,
                                  otherUserName: userProfile.username,
                                  otherUserAvatar: userProfile.avatarUrl,
                                  initialReplyContent: note.content,
                                  initialReplySenderName:
                                      userProfile.username,
                                  initialReplySenderId: note.userId,
                                  initialReplyFromNote: true,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.reply_rounded, size: 20),
                        label: const Text('پاسخ دادن'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) async {
    final result =
        await NoteInputSheet.show(context, currentNote: note.content);

    if (result == true) {
      // Refresh logic is already handled in ProfileScreen via provider invalidation
      // but if we are viewing this from another place, we might need provider refresh here
      // Since ProfileScreen watches the provider, it will update automatically.
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inHours > 0) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقیقه پیش';
    } else {
      return 'لحظاتی پیش';
    }
  }

  TextDirection _resolveTextDirection(BuildContext context, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Directionality.of(context);

    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(char)) {
        return TextDirection.rtl;
      }
      if (RegExp(r'[A-Za-z]').hasMatch(char)) {
        return TextDirection.ltr;
      }
    }

    return Directionality.of(context);
  }
}
