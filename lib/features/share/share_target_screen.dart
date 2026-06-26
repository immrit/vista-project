import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/share_receiver_service.dart';
import '../chat/screens/new_message_screen.dart';
import '../posts/screens/AddPost.dart';
import '../stories/presentation/screens/story_editor_screen.dart';
import '../stories/core/story_enums.dart';
import 'package:Vista/core/theme/app_theme.dart';

/// Bottom Sheet که بعد از انتخاب ویستا در Share Sheet نمایش داده می‌شود
/// کاربر انتخاب می‌کند: پیام / پست / استوری
Future<void> showShareTargetSheet(
  BuildContext context,
  SharedContent content,
) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ShareTargetSheet(content: content),
  );
}

class ShareTargetSheet extends ConsumerStatefulWidget {
  final SharedContent content;
  const ShareTargetSheet({super.key, required this.content});

  @override
  ConsumerState<ShareTargetSheet> createState() => _ShareTargetSheetState();
}

class _ShareTargetSheetState extends ConsumerState<ShareTargetSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceVariant : Colors.white;
    final surfaceColor = isDark ? AppColors.darkBorder : const Color(0xFFF2F2F7);
    final textColor = isDark ? Colors.white : AppColors.darkSurfaceVariant;
    final subtitleColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF6D6D72);

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white38 : Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.info],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'اشتراک‌گذاری در ویستا',
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getSubtitle(),
                          style: TextStyle(
                            fontFamily: 'Vazirmatn',
                            fontSize: 13,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Preview thumbnail برای عکس/ویدیو
            if (widget.content.hasFiles && widget.content.isMedia)
              _buildMediaPreview(surfaceColor),

            const SizedBox(height: 8),
            Divider(
              color: surfaceColor,
              thickness: 1,
              height: 1,
            ),
            const SizedBox(height: 8),

            // گزینه‌ها
            _buildOption(
              context: context,
              icon: Icons.send_rounded,
              gradient: const LinearGradient(
                colors: [AppColors.info, AppColors.primary],
              ),
              title: 'ارسال پیام',
              subtitle: 'برای یک نفر یا گروه بفرست',
              surfaceColor: surfaceColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              onTap: () => _navigateToMessage(context),
            ),

            if (widget.content.isMedia || widget.content.isText)
              _buildOption(
                context: context,
                icon: Icons.grid_on_rounded,
                gradient: const LinearGradient(
                  colors: [AppColors.accent, Color(0xFFF97316)],
                ),
                title: 'ایجاد پست',
                subtitle: 'در صفحه پروفایلت منتشر کن',
                surfaceColor: surfaceColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                onTap: () => _navigateToPost(context),
              ),

            if (widget.content.isMedia)
              _buildOption(
                context: context,
                icon: Icons.auto_awesome_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFA855F7), AppColors.accent],
                ),
                title: 'ایجاد استوری',
                subtitle: '۲۴ ساعت برای همه نمایش داده می‌شود',
                surfaceColor: surfaceColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                onTap: () => _navigateToStory(context),
              ),

            const SizedBox(height: 12),

            // دکمه لغو
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'انصراف',
                    style: TextStyle(
                      fontFamily: 'Vazirmatn',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),

            // Safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(Color surfaceColor) {
    final file = File(widget.content.filePaths.first);
    final isMulti = widget.content.filePaths.length > 1;

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: widget.content.isImage
                ? Image.file(
                    file,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: double.infinity,
                    height: 120,
                    color: surfaceColor,
                    child: const Icon(
                      Icons.videocam_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
          ),
          if (isMulti)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.content.filePaths.length} فایل',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Vazirmatn',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required LinearGradient gradient,
    required String title,
    required String subtitle,
    required Color surfaceColor,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Vazirmatn',
                          fontSize: 12,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: subtitleColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getSubtitle() {
    if (widget.content.isText) return 'متن';
    if (widget.content.isImage) {
      return widget.content.isMultiple
          ? '${widget.content.filePaths.length} تصویر'
          : 'یک تصویر';
    }
    if (widget.content.isVideo) {
      return widget.content.isMultiple
          ? '${widget.content.filePaths.length} ویدیو'
          : 'یک ویدیو';
    }
    return 'فایل';
  }

  void _navigateToMessage(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NewMessageScreen(sharedContent: widget.content),
      ),
    );
  }

  void _navigateToPost(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddPublicPostScreen(
          preloadedFiles: widget.content.filePaths.map((p) => File(p)).toList(),
          preloadedText: widget.content.text,
        ),
      ),
    );
  }

  void _navigateToStory(BuildContext context) {
    if (!widget.content.hasFiles) return;
    Navigator.of(context).pop();

    final file = File(widget.content.filePaths.first);
    final mediaType = widget.content.isVideo
        ? StoryMediaType.video
        : StoryMediaType.image;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoryEditorScreen(
          mediaFile: file,
          mediaType: mediaType,
        ),
      ),
    );
  }
}
