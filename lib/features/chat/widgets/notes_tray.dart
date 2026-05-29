import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_note_provider.dart';
import '../../profile/data/models/profile_note_model.dart';
import '../providers/chat_notes_provider.dart';
import '../providers/chat_action_controller.dart';
import '../../profile/widgets/note_input_sheet.dart';
import '../../../provider/optimized_conversations_provider.dart';
import '../../../widgets/profile_avatar_widget.dart'; // Assume this exists for caching

class NotesTray extends ConsumerWidget {
  const NotesTray({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentUserNoteAsync = ref.watch(currentUserNoteProvider);
    final otherNotesAsync = ref.watch(chatNotesProvider);

    return Container(
      height: 120, // ارتفاع ثابت برای سینی یادداشت‌ها
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // آیتم اول: یادداشت خود کاربر (Your Note)
          _buildYourNoteItem(context, ref, currentUserNoteAsync, isDark),
          const SizedBox(width: 16),

          // آیتم‌های دیگر کاربران
          otherNotesAsync.when(
            data: (notesMap) {
              if (notesMap.isEmpty) return const SizedBox.shrink();

              // فقط یادداشت‌های منقضی نشده را فیلتر و لیست می‌کنیم
              final activeNotes = notesMap.entries
                  .where((e) => !e.value.isExpired)
                  .toList();

              if (activeNotes.isEmpty) return const SizedBox.shrink();

              return Row(
                children: activeNotes.map((entry) {
                  final userId = entry.key;
                  final note = entry.value;

                  // پیدا کردن اطلاعات کاربر از لیست مکالمات
                  final conversations =
                      ref.watch(optimizedConversationsProvider).conversations;
                  final matches = conversations
                      .where((c) => c.otherUserId == userId)
                      .toList(growable: false);
                  if (matches.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final conversation = matches.first;

                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _NoteTrayItem(
                      conversationId: conversation.id,
                      userId: userId,
                      note: note,
                      username: conversation.otherUserName ?? 'ناشناس',
                      avatarUrl: conversation.otherUserAvatar ?? '',
                      isDark: isDark,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildYourNoteItem(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ProfileNoteModel?> noteAsync,
    bool isDark,
  ) {
    final note = noteAsync.valueOrNull;
    final hasActiveNote = note != null && !note.isExpired;
    final isLoading = noteAsync.isLoading;

    return GestureDetector(
      onTap: () async {
        await NoteInputSheet.show(
          context,
          currentNote: hasActiveNote ? note.content : null,
        );
      },
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            // همان ساختار دقیق _NoteTrayItem برای یکپارچگی بصری
            SizedBox(
              height: 82,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // آواتار — موقعیت یکسان با _NoteTrayItem
                  Positioned(
                    top: 18,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        border: Border.all(
                          color: isDark
                              ? Colors.grey[700]!
                              : Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 32,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                  ),

                  // حباب یادداشت — موقعیت یکسان با _NoteTrayItem
                  Positioned(
                    top: 0,
                    child: hasActiveNote
                        ? _TopThoughtBubble(
                            text: note.content,
                            isDark: isDark,
                            isCurrentUser: true,
                          )
                        : _EmptyThoughtBubble(
                            isDark: isDark,
                            isLoading: isLoading,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasActiveNote ? 'یادداشت شما' : 'یادداشت',
              style: TextStyle(
                fontSize: 10.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// یک حباب خالی برای اضافه کردن یادداشت (شبیه دکمه اینستاگرام)
class _EmptyThoughtBubble extends StatelessWidget {
  final bool isDark;
  final bool isLoading;

  const _EmptyThoughtBubble({required this.isDark, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 65),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]?.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: isLoading
          ? SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            )
          : Icon(
              Icons.add,
              size: 16,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
    );
  }
}

class _NoteTrayItem extends ConsumerWidget {
  final String conversationId;
  final String userId;
  final ProfileNoteModel note;
  final String username;
  final String avatarUrl;
  final bool isDark;

  const _NoteTrayItem({
    required this.conversationId,
    required this.userId,
    required this.note,
    required this.username,
    required this.avatarUrl,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openReplySheet() => _showNoteReplySheet(context, ref);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: openReplySheet,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            SizedBox(
              height: 82,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Positioned(
                    top: 18,
                    child: ProfileAvatar(
                      userId: userId,
                      size: 64,
                      imageUrl: avatarUrl,
                      showOnlineStatus: false,
                      onTap: openReplySheet,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: openReplySheet,
                      child: _TopThoughtBubble(
                        text: note.content,
                        isDark: isDark,
                        isCurrentUser: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openReplySheet,
              child: Text(
                username,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNoteReplySheet(BuildContext context, WidgetRef ref) async {
    final sent = await showNoteQuickReplyBottomSheet(
      context,
      conversationId: conversationId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      noteContent: note.content,
    );

    if (sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاسخ شما ارسال شد')),
      );
    }
  }

}

Future<bool> showNoteQuickReplyBottomSheet(
  BuildContext context, {
  required String conversationId,
  required String userId,
  required String username,
  required String avatarUrl,
  required String noteContent,
}) async {
  final theme = Theme.of(context);
  final sent = await showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: theme.scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _NoteQuickReplySheet(
      conversationId: conversationId,
      userId: userId,
      username: username,
      avatarUrl: avatarUrl,
      noteContent: noteContent,
    ),
  );
  return sent == true;
}

class _NoteQuickReplySheet extends ConsumerStatefulWidget {
  const _NoteQuickReplySheet({
    required this.conversationId,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.noteContent,
  });

  final String conversationId;
  final String userId;
  final String username;
  final String avatarUrl;
  final String noteContent;

  @override
  ConsumerState<_NoteQuickReplySheet> createState() =>
      _NoteQuickReplySheetState();
}

class _NoteQuickReplySheetState extends ConsumerState<_NoteQuickReplySheet> {
  late final TextEditingController _replyController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  TextDirection _resolveTextDirection(BuildContext context, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Directionality.of(context);

    for (final rune in trimmed.runes) {
      final char = String.fromCharCode(rune);
      if (RegExp(r'[\u0600-\u06FF]').hasMatch(char)) return TextDirection.rtl;
      if (RegExp(r'[A-Za-z]').hasMatch(char)) return TextDirection.ltr;
    }

    return Directionality.of(context);
  }

  Future<void> _submitQuickReply() async {
    final replyText = _replyController.text.trim();
    if (replyText.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final actionController = ref.read(chatActionControllerProvider.notifier);
    final conversationsNotifier =
        ref.read(optimizedConversationsProvider.notifier);

    final result = await actionController.sendMessage(
      conversationId: widget.conversationId,
      content: replyText,
      replyToMessageId: 'note:${widget.userId}',
      replyToContent: widget.noteContent,
      replyToSenderName: 'یادداشت ${widget.username}',
      replyToKind: 'note',
    );

    if (!mounted) return;
    if (result.isSuccess) {
      conversationsNotifier.refresh();
      Navigator.of(context, rootNavigator: true).pop(true);
      return;
    }

    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'خطا در ارسال پاسخ')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color;
    final secondaryColor = theme.textTheme.bodySmall?.color;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProfileAvatar(
                  userId: widget.userId,
                  size: 48,
                  imageUrl: widget.avatarUrl,
                  showOnlineStatus: false,
                ),
                title: Text(
                  widget.username,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                subtitle: Text(
                  'یادداشت فعال',
                  style: TextStyle(color: secondaryColor),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.noteContent,
                    textDirection:
                        _resolveTextDirection(context, widget.noteContent),
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _replyController,
                textInputAction: TextInputAction.send,
                minLines: 1,
                maxLines: 4,
                onFieldSubmitted: (_) => _submitQuickReply(),
                decoration: InputDecoration(
                  hintText: 'پاسخ شما به این یادداشت...',
                  prefixIcon: const Icon(Icons.reply_rounded),
                  filled: true,
                  fillColor: theme.cardColor.withValues(alpha: 0.7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _submitQuickReply,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_isSending ? 'درحال ارسال...' : 'ارسال'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// یک حباب افقی کوچک که در مرکز آواتار (از بالا) قرار می‌گیرد
class _TopThoughtBubble extends StatelessWidget {
  final String text;
  final bool isDark;
  final bool isCurrentUser;

  const _TopThoughtBubble({
    required this.text,
    required this.isDark,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 65), // عرض بسیار کوچک
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800]?.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
          width: 0.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          height: 1.2,
          color: isDark ? Colors.white : Colors.black87,
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
