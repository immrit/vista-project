import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:Vista/features/profile/providers/user_profile_provider.dart';
import 'package:Vista/utils/comments_bottom_sheet.dart'; // for getDirection
import 'package:Vista/core/theme/app_theme.dart';

class CommentInputField extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyingToCommentId;
  final String? replyingToUsername;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;
  final bool isSubmitting;
  final ValueChanged<String>? onChanged;
  final Widget? mentionListWidget;

  const CommentInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    this.replyingToCommentId,
    this.replyingToUsername,
    required this.onCancelReply,
    required this.onSubmit,
    this.isSubmitting = false,
    this.onChanged,
    this.mentionListWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserProfile = ref.watch(currentUserProfileProvider).value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // لیست منشن‌ها (در صورت وجود)
            if (mentionListWidget != null) ...[
              mentionListWidget!,
              const SizedBox(height: 8),
            ],

            // نوار نشان‌دهنده حالت ریپلای
            if (replyingToCommentId != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'در حال پاسخ به ${replyingToUsername ?? "کاربر"}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onCancelReply,
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // فیلد ورودی کامنت
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // آواتار کاربر جاری
                CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: currentUserProfile?.avatarUrl != null &&
                          currentUserProfile!.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(
                          currentUserProfile.avatarUrl!)
                      : const AssetImage('lib/utils/images/default-avatar.jpg')
                          as ImageProvider,
                ),

                const SizedBox(width: 12),

                // فیلد متن
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 40,
                      maxHeight: 120,
                    ),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textDirection: getDirection(controller.text),
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        hintText: replyingToCommentId != null
                            ? 'پاسخ خود را بنویسید...'
                            : 'نظر خود را بنویسید...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // دکمه ارسال
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: InkWell(
                    onTap: (controller.text.trim().isNotEmpty && !isSubmitting)
                        ? onSubmit
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: controller.text.trim().isNotEmpty &&
                                !isSubmitting
                            ? const Color(
                                0xFF007AFF) // Same blue for both themes
                            : theme.colorScheme.outline.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: controller.text.trim().isNotEmpty &&
                                      !isSubmitting
                                  ? Colors.white
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
